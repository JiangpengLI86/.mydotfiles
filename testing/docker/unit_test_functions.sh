#!/usr/bin/env bash
# Unit tests for pure/isolated shell functions.
# Runs entirely offline - no network, no apt, no sudo required.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ============================================================
# Minimal assertion framework
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
CURRENT_GROUP=""

begin_group() {
	CURRENT_GROUP="$1"
	echo ""
	echo "--- ${CURRENT_GROUP} ---"
}

pass() {
	local name="$1"
	PASS_COUNT=$((PASS_COUNT + 1))
	echo "  PASS: ${name}"
}

fail() {
	local name="$1"
	local reason="${2:-}"
	FAIL_COUNT=$((FAIL_COUNT + 1))
	echo "  FAIL: ${name}${reason:+ -- ${reason}}"
}

assert_eq() {
	local name="$1"
	local expected="$2"
	local actual="$3"
	if [ "$expected" = "$actual" ]; then
		pass "$name"
	else
		fail "$name" "expected=$(printf '%q' "$expected") actual=$(printf '%q' "$actual")"
	fi
}

assert_exit_zero() {
	local name="$1"
	shift
	local rc=0
	"$@" >/dev/null 2>&1 || rc=$?
	if [ "$rc" -eq 0 ]; then
		pass "$name"
	else
		fail "$name" "command exited $rc (expected 0)"
	fi
}

assert_exit_nonzero() {
	local name="$1"
	shift
	local rc=0
	"$@" >/dev/null 2>&1 || rc=$?
	if [ "$rc" -ne 0 ]; then
		pass "$name"
	else
		fail "$name" "command exited 0 (expected non-zero)"
	fi
}

assert_file_contains() {
	local name="$1"
	local file="$2"
	local pattern="$3"
	if grep -qF "$pattern" "$file" 2>/dev/null; then
		pass "$name"
	else
		fail "$name" "pattern not found: $(printf '%q' "$pattern")"
	fi
}

assert_file_not_contains() {
	local name="$1"
	local file="$2"
	local pattern="$3"
	if ! grep -qF "$pattern" "$file" 2>/dev/null; then
		pass "$name"
	else
		fail "$name" "pattern unexpectedly found: $(printf '%q' "$pattern")"
	fi
}

assert_file_content_eq() {
	local name="$1"
	local file="$2"
	local expected="$3"
	local actual
	actual="$(cat "$file")"
	assert_eq "$name" "$expected" "$actual"
}

# ============================================================
# Source setup scripts
# Set color vars to empty strings since scripts reference them
# without guarding, and we don't want escape codes in test output.
# ============================================================

export RED='' GREEN='' YELLOW='' BOLD='' RESET=''
# Prevent install_basic_packages.sh from attempting any apt operations.
export CAN_USE_APT=false
export SUDO=""
# HOME must be set for bashrc helpers that reference ~/.bashrc
export HOME="${HOME:-/root}"

# We source from REPO_ROOT so relative paths inside scripts resolve.
cd "$REPO_ROOT"
# shellcheck source=../../setup_scripts/bashrc_helpers.sh
source ./setup_scripts/bashrc_helpers.sh
# shellcheck source=../../setup_scripts/install_basic_packages.sh
source ./setup_scripts/install_basic_packages.sh

# ============================================================
# version_gte: copied from install_neovim.sh install_tree_sitter_cli()
# It is defined as a nested function there and cannot be sourced
# directly. Copied here verbatim; if the source changes, update here.
# TODO: consider promoting version_gte to a top-level utility function.
# ============================================================
version_gte() {
	local lhs="$1"
	local rhs="$2"
	[ "$(printf '%s\n%s\n' "$lhs" "$rhs" | sort -V | head -n1)" = "$rhs" ]
}

# ============================================================
# Tests
# ============================================================

TMP="$(mktemp -d /tmp/unit-tests.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# ------------------------------------------------------------------
begin_group "strip_managed_block_from_file"
# ------------------------------------------------------------------

INPUT="$TMP/strip_input"
OUTPUT="$TMP/strip_output"

# Block in the middle
printf '%s\n' "line_before" "START" "inside" "END" "line_after" >"$INPUT"
strip_managed_block_from_file "$INPUT" "START" "END" "$OUTPUT"
assert_file_contains     "strip: keeps lines before block"  "$OUTPUT" "line_before"
assert_file_not_contains "strip: removes start marker"      "$OUTPUT" "START"
assert_file_not_contains "strip: removes block content"     "$OUTPUT" "inside"
assert_file_not_contains "strip: removes end marker"        "$OUTPUT" "END"
assert_file_contains     "strip: keeps lines after block"   "$OUTPUT" "line_after"

# No block present - file passes through unchanged
printf '%s\n' "aaa" "bbb" >"$INPUT"
strip_managed_block_from_file "$INPUT" "NO_START" "NO_END" "$OUTPUT"
assert_file_content_eq "strip: no block - file unchanged" "$OUTPUT" "$(printf '%s\n' "aaa" "bbb")"

# Block at very start
printf '%s\n' "START" "inner" "END" "after" >"$INPUT"
strip_managed_block_from_file "$INPUT" "START" "END" "$OUTPUT"
assert_file_not_contains "strip: block at start - marker removed"  "$OUTPUT" "START"
assert_file_not_contains "strip: block at start - inner removed"   "$OUTPUT" "inner"
assert_file_contains     "strip: block at start - after kept"      "$OUTPUT" "after"

# Block at very end
printf '%s\n' "before" "START" "inner" "END" >"$INPUT"
strip_managed_block_from_file "$INPUT" "START" "END" "$OUTPUT"
assert_file_contains     "strip: block at end - before kept"   "$OUTPUT" "before"
assert_file_not_contains "strip: block at end - inner removed" "$OUTPUT" "inner"

# ------------------------------------------------------------------
begin_group "trim_trailing_blank_lines_from_file"
# ------------------------------------------------------------------

INPUT="$TMP/trail_input"
OUTPUT="$TMP/trail_output"

# Trailing blanks removed
printf '%s\n' "hello" "" "" >"$INPUT"
trim_trailing_blank_lines_from_file "$INPUT" "$OUTPUT"
assert_file_content_eq "trim_trailing: removes trailing blanks" "$OUTPUT" "hello"

# No trailing blanks - unchanged
printf '%s\n' "hello" "world" >"$INPUT"
trim_trailing_blank_lines_from_file "$INPUT" "$OUTPUT"
assert_file_content_eq "trim_trailing: no trailing blanks - unchanged" "$OUTPUT" "$(printf '%s\n' "hello" "world")"

# Empty file stays empty
: >"$INPUT"
trim_trailing_blank_lines_from_file "$INPUT" "$OUTPUT"
assert_file_content_eq "trim_trailing: empty file stays empty" "$OUTPUT" ""

# Interior blank lines are preserved
printf '%s\n' "a" "" "b" "" >"$INPUT"
trim_trailing_blank_lines_from_file "$INPUT" "$OUTPUT"
assert_file_content_eq "trim_trailing: interior blanks preserved" "$OUTPUT" "$(printf '%s\n' "a" "" "b")"

# ------------------------------------------------------------------
begin_group "trim_surrounding_blank_lines_from_file"
# ------------------------------------------------------------------

INPUT="$TMP/surr_input"
OUTPUT="$TMP/surr_output"

# Leading and trailing blanks removed
printf '%s\n' "" "content" "" >"$INPUT"
trim_surrounding_blank_lines_from_file "$INPUT" "$OUTPUT"
assert_file_content_eq "trim_surrounding: removes leading+trailing blanks" "$OUTPUT" "content"

# Interior blank lines preserved
printf '%s\n' "" "a" "" "b" "" >"$INPUT"
trim_surrounding_blank_lines_from_file "$INPUT" "$OUTPUT"
assert_file_content_eq "trim_surrounding: interior blanks preserved" "$OUTPUT" "$(printf '%s\n' "a" "" "b")"

# All-blank file produces empty output
printf '%s\n' "" "" >"$INPUT"
trim_surrounding_blank_lines_from_file "$INPUT" "$OUTPUT"
assert_file_content_eq "trim_surrounding: all-blank becomes empty" "$OUTPUT" ""

# No surrounding blanks - unchanged
printf '%s\n' "x" "y" >"$INPUT"
trim_surrounding_blank_lines_from_file "$INPUT" "$OUTPUT"
assert_file_content_eq "trim_surrounding: no blanks - unchanged" "$OUTPUT" "$(printf '%s\n' "x" "y")"

# ------------------------------------------------------------------
begin_group "upsert_mydotfiles_bashrc_block"
# ------------------------------------------------------------------

FAKE_HOME="$TMP/fake_home"
mkdir -p "$FAKE_HOME"
FAKE_BASHRC="$FAKE_HOME/.bashrc"
BLOCK_A_START="# >>> test block A >>>"
BLOCK_A_END="# <<< test block A <<<"
BLOCK_B_START="# >>> test block B >>>"
BLOCK_B_END="# <<< test block B <<<"

# Insert into empty bashrc
: >"$FAKE_BASHRC"
upsert_mydotfiles_bashrc_block "$FAKE_BASHRC" \
	"$BLOCK_A_START" "$BLOCK_A_END" \
	"$(printf '%s\nexport MY_VAR=hello\n%s' "$BLOCK_A_START" "$BLOCK_A_END")" \
	"test block A"
assert_file_contains "upsert: outer envelope start written" "$FAKE_BASHRC" "$MYDOTFILES_BASHRC_MANAGED_START"
assert_file_contains "upsert: outer envelope end written"   "$FAKE_BASHRC" "$MYDOTFILES_BASHRC_MANAGED_END"
assert_file_contains "upsert: inner block content written"  "$FAKE_BASHRC" "MY_VAR=hello"

# Update: call again with different content - old content replaced, outer envelope appears once
upsert_mydotfiles_bashrc_block "$FAKE_BASHRC" \
	"$BLOCK_A_START" "$BLOCK_A_END" \
	"$(printf '%s\nexport MY_VAR=world\n%s' "$BLOCK_A_START" "$BLOCK_A_END")" \
	"test block A"
assert_file_contains     "upsert: updated content present"  "$FAKE_BASHRC" "MY_VAR=world"
assert_file_not_contains "upsert: old content removed"      "$FAKE_BASHRC" "MY_VAR=hello"
# Outer envelope should appear exactly once
OUTER_COUNT="$(grep -cF "$MYDOTFILES_BASHRC_MANAGED_START" "$FAKE_BASHRC")"
assert_eq "upsert: outer start appears exactly once" "1" "$OUTER_COUNT"

# Two different inner blocks coexist in the same outer envelope
upsert_mydotfiles_bashrc_block "$FAKE_BASHRC" \
	"$BLOCK_B_START" "$BLOCK_B_END" \
	"$(printf '%s\nexport OTHER_VAR=123\n%s' "$BLOCK_B_START" "$BLOCK_B_END")" \
	"test block B"
assert_file_contains "upsert: block A still present after B added" "$FAKE_BASHRC" "MY_VAR=world"
assert_file_contains "upsert: block B content present"            "$FAKE_BASHRC" "OTHER_VAR=123"
OUTER_COUNT="$(grep -cF "$MYDOTFILES_BASHRC_MANAGED_START" "$FAKE_BASHRC")"
assert_eq "upsert: outer start still appears exactly once" "1" "$OUTER_COUNT"

# Existing content before the managed block is preserved
: >"$FAKE_BASHRC"
printf '%s\n' "# existing line" >"$FAKE_BASHRC"
upsert_mydotfiles_bashrc_block "$FAKE_BASHRC" \
	"$BLOCK_A_START" "$BLOCK_A_END" \
	"$(printf '%s\nexport FOO=bar\n%s' "$BLOCK_A_START" "$BLOCK_A_END")" \
	"test block A"
assert_file_contains "upsert: pre-existing bashrc content preserved" "$FAKE_BASHRC" "# existing line"
assert_file_contains "upsert: new block added after existing content" "$FAKE_BASHRC" "FOO=bar"

# ------------------------------------------------------------------
begin_group "require_commands"
# ------------------------------------------------------------------

assert_exit_zero    "require_commands: bash exists"               require_commands bash
assert_exit_zero    "require_commands: multiple real commands"    require_commands bash sh true
assert_exit_nonzero "require_commands: nonexistent command fails" require_commands __nonexistent_cmd_xyz__
assert_exit_nonzero "require_commands: mixed real+fake fails"     require_commands bash __nonexistent_cmd_xyz__

# ------------------------------------------------------------------
begin_group "ensure_bashrc_line"
# ------------------------------------------------------------------

ELINE_BASHRC="$TMP/eline_bashrc"
: >"$ELINE_BASHRC"

# Override HOME so ensure_bashrc_line writes to our test file
(
	export HOME="$TMP/eline_home"
	mkdir -p "$HOME"
	cp "$ELINE_BASHRC" "$HOME/.bashrc"

	ensure_bashrc_line 'export TEST_LINE=1'
	assert_file_contains "ensure_bashrc_line: line added" "$HOME/.bashrc" 'export TEST_LINE=1'

	# Call again - should not duplicate
	ensure_bashrc_line 'export TEST_LINE=1'
	LINE_COUNT="$(grep -cF 'export TEST_LINE=1' "$HOME/.bashrc")"
	assert_eq "ensure_bashrc_line: idempotent (no duplicate)" "1" "$LINE_COUNT"

	# Different line is added
	ensure_bashrc_line 'export OTHER_LINE=2'
	assert_file_contains "ensure_bashrc_line: different line added" "$HOME/.bashrc" 'export OTHER_LINE=2'
	assert_file_contains "ensure_bashrc_line: first line still present" "$HOME/.bashrc" 'export TEST_LINE=1'
)

# ------------------------------------------------------------------
begin_group "version_gte"
# ------------------------------------------------------------------

assert_exit_zero    "version_gte: equal versions"        version_gte "1.0.0" "1.0.0"
assert_exit_zero    "version_gte: lhs greater"           version_gte "2.0.0" "1.0.0"
assert_exit_zero    "version_gte: patch greater"         version_gte "0.26.1" "0.26.0"
assert_exit_zero    "version_gte: minor greater"         version_gte "0.27.0" "0.26.1"
assert_exit_zero    "version_gte: meets minimum exactly" version_gte "0.26.1" "0.26.1"
assert_exit_nonzero "version_gte: lhs less (patch)"     version_gte "0.26.0" "0.26.1"
assert_exit_nonzero "version_gte: lhs less (minor)"     version_gte "0.25.9" "0.26.1"
assert_exit_nonzero "version_gte: lhs much smaller"     version_gte "0.1.0" "1.0.0"

# ------------------------------------------------------------------
begin_group "setup.sh argument parsing"
# ------------------------------------------------------------------

# --help exits 0
(
	cd "$REPO_ROOT"
	# Temporarily rename the dir to .mydotfiles so the directory check passes;
	# the script checks basename of PWD.
	SETUP_TMP="$TMP/dot_mydotfiles_setup"
	mkdir -p "$SETUP_TMP"
	cp -r . "$SETUP_TMP/"
	# We can't rename PWD; instead run setup.sh with --help before it reaches
	# the directory check (it parses args after sourcing, but the dir check
	# comes before arg parsing actually, so we call help another way):
	# The usage() function is defined in help_messages.sh; just check it exits 0.
	assert_exit_zero "setup.sh --help exits 0" bash setup.sh --help
) 2>/dev/null || true
# Since PWD is .mydotfiles, --help should work
cd "$REPO_ROOT"
assert_exit_zero "setup.sh --help exits 0" bash setup.sh --help

# Unknown flag exits non-zero
assert_exit_nonzero "setup.sh unknown flag exits non-zero" bash setup.sh --unknown-flag-xyz

# Wrong directory: run setup.sh from /tmp - should fail with directory check
assert_exit_nonzero "setup.sh wrong directory exits non-zero" \
	bash -c 'cd /tmp && bash '"$REPO_ROOT"'/setup.sh'

# ============================================================
# Summary
# ============================================================

echo ""
echo "==========================================="
echo "Unit test results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "==========================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
	echo "UNIT_TESTS_FAILED"
	exit 1
fi

echo "UNIT_TESTS_OK"
