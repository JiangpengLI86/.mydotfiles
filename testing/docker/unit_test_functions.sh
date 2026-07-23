#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/mydotfiles-unit.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

export RED='' GREEN='' YELLOW='' BOLD='' RESET=''
export CAN_USE_APT=false
export SUDO=""

cd "$REPO_ROOT"
# shellcheck source=../../setup_scripts/install_basic_packages.sh
source ./setup_scripts/install_basic_packages.sh
# shellcheck source=../../setup_scripts/config_bashrc.sh
source ./setup_scripts/config_bashrc.sh

require_commands bash sh true
if require_commands __missing_mydotfiles_test_command__; then
	echo "require_commands accepted a missing command" >&2
	exit 1
fi

bashrc_path="$TEST_DIR/bashrc"
printf '%s\n' \
	"# user content" \
	"# >>> mydotfiles managed blocks >>>" \
	"old managed content" \
	"# <<< mydotfiles managed blocks <<<" \
	'export PATH="$HOME/.local/bin:$PATH"' >"$bashrc_path"
config_bashrc "$bashrc_path"
config_bashrc "$bashrc_path"
if [ "$(grep -cF 'source "$HOME/.config/mydotfiles/bashrc.sh"' "$bashrc_path")" -ne 1 ]; then
	echo "config_bashrc duplicated the source line" >&2
	exit 1
fi
if grep -qF "old managed content" "$bashrc_path" || ! grep -qF "# user content" "$bashrc_path"; then
	echo "config_bashrc did not migrate the legacy block cleanly" >&2
	exit 1
fi

mkdir -p "$TEST_DIR/home" "$TEST_DIR/bin"
for command_name in code lazygit; do
	printf '#!/bin/sh\n' >"$TEST_DIR/bin/$command_name"
	chmod +x "$TEST_DIR/bin/$command_name"
done
if ! (
	export HOME="$TEST_DIR/home"
	export PATH="$TEST_DIR/bin:/usr/bin:/bin"
	ssh-add() { return 0; }
	source ./bash/.config/mydotfiles/bashrc.sh
	[ "$(command -v code)" = "$TEST_DIR/bin/code" ] &&
		[ "$(command -v lazygit)" = "$TEST_DIR/bin/lazygit" ]
); then
	echo "shell config masked a system code or lazygit command" >&2
	exit 1
fi

bash setup.sh --help >/dev/null
if bash setup.sh --unknown-flag >/dev/null 2>&1; then
	echo "setup.sh accepted an unknown flag" >&2
	exit 1
fi
if (cd /tmp && bash "$REPO_ROOT/setup.sh" >/dev/null 2>&1); then
	echo "setup.sh accepted the wrong working directory" >&2
	exit 1
fi

echo "UNIT_TESTS_OK"
