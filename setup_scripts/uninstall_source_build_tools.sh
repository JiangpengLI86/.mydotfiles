#!/usr/bin/env bash
# Safely uninstall source-built tools managed by this repo:
# - yazi installed under /opt/yazi
# - tree-sitter CLI installed via cargo (~/.cargo/bin/tree-sitter)
#
# Usage:
#   bash setup_scripts/uninstall_source_build_tools.sh
#   bash setup_scripts/uninstall_source_build_tools.sh --yes
#   bash setup_scripts/uninstall_source_build_tools.sh --check

set -euo pipefail

BOLD='\e[1m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
RESET='\e[0m'

AUTO_APPROVE=false
CHECK_ONLY=false

if [ "$EUID" -ne 0 ]; then
	SUDO="sudo"
else
	SUDO=""
fi

if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
	USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
	USER_HOME="$HOME"
fi

if [ -z "${USER_HOME:-}" ]; then
	echo -e "${RED}Unable to determine target user home directory.${RESET}"
	exit 1
fi

YAZI_INSTALL_DIR="/opt/yazi"
YAZI_PATH_LINE='export PATH=$PATH:/opt/yazi/target/release'
YAZI_WRAPPER_START="# >>> yazi shell wrapper >>>"
YAZI_WRAPPER_END="# <<< yazi shell wrapper <<<"

BASHRC_PATH="${USER_HOME}/.bashrc"
CARGO_TREE_SITTER="${USER_HOME}/.cargo/bin/tree-sitter"
SYSTEM_TREE_SITTER="/usr/local/bin/tree-sitter"

usage() {
	cat <<'EOF'
Usage: uninstall_source_build_tools.sh [options]

Options:
  -y, --yes    Run without interactive confirmation.
  --check      Show managed install status only.
  -h, --help   Show this help message.
EOF
}

while (($#)); do
	case "$1" in
	-y | --yes)
		AUTO_APPROVE=true
		;;
	--check)
		CHECK_ONLY=true
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo -e "${RED}Unknown option: $1${RESET}"
		usage
		exit 1
		;;
	esac
	shift
done

print_status() {
	echo -e "${BOLD}${YELLOW}Managed source-build status:${RESET}"

	if [ -x "${YAZI_INSTALL_DIR}/target/release/yazi" ]; then
		echo "  yazi binary: present (${YAZI_INSTALL_DIR}/target/release/yazi)"
	else
		echo "  yazi binary: not found"
	fi

	if [ ! -e "$BASHRC_PATH" ]; then
		echo "  yazi PATH entry in .bashrc: file not found (${BASHRC_PATH})"
	elif [ ! -r "$BASHRC_PATH" ]; then
		echo "  yazi PATH entry in .bashrc: cannot read file (${BASHRC_PATH})"
	elif grep -qF "$YAZI_PATH_LINE" "$BASHRC_PATH" 2>/dev/null; then
		echo "  yazi PATH entry in .bashrc: present"
	else
		echo "  yazi PATH entry in .bashrc: not found"
	fi

	if [ ! -e "$BASHRC_PATH" ]; then
		echo "  yazi wrapper block in .bashrc: file not found (${BASHRC_PATH})"
	elif [ ! -r "$BASHRC_PATH" ]; then
		echo "  yazi wrapper block in .bashrc: cannot read file (${BASHRC_PATH})"
	elif grep -qF "$YAZI_WRAPPER_START" "$BASHRC_PATH" 2>/dev/null; then
		echo "  yazi wrapper block in .bashrc: present"
	else
		echo "  yazi wrapper block in .bashrc: not found"
	fi

	if [ -x "$CARGO_TREE_SITTER" ]; then
		echo "  cargo tree-sitter binary: present ($CARGO_TREE_SITTER)"
	else
		echo "  cargo tree-sitter binary: not found"
	fi

	if [ -L "$SYSTEM_TREE_SITTER" ] && [ "$(readlink "$SYSTEM_TREE_SITTER")" = "$CARGO_TREE_SITTER" ]; then
		echo "  /usr/local/bin/tree-sitter symlink to cargo binary: present"
	else
		echo "  /usr/local/bin/tree-sitter symlink to cargo binary: not found"
	fi
}

remove_yazi_wrapper_block() {
	local file_path="$1"
	local tmp_file
	tmp_file="$(mktemp)"

	awk -v start="$YAZI_WRAPPER_START" -v end="$YAZI_WRAPPER_END" '
	index($0, start) { skip = 1; next }
	index($0, end)   { skip = 0; next }
	!skip            { print }
	' "$file_path" >"$tmp_file"

	cat "$tmp_file" >"$file_path"
	rm -f "$tmp_file"
}

print_status

if [ "$CHECK_ONLY" = true ]; then
	exit 0
fi

if [ "$AUTO_APPROVE" != true ]; then
	if [ ! -t 0 ]; then
		echo -e "${RED}Non-interactive shell detected. Re-run with --yes to proceed.${RESET}"
		exit 1
	fi

	read -r -p "Uninstall managed source-built tools now? [y/N] " answer
	case "$answer" in
	y | Y | yes | YES)
		;;
	*)
		echo -e "${YELLOW}Canceled.${RESET}"
		exit 0
		;;
	esac
fi

changes=0

if [ -d "$YAZI_INSTALL_DIR" ]; then
	echo -e "${BOLD}${YELLOW}Removing ${YAZI_INSTALL_DIR}...${RESET}"
	$SUDO rm -rf "$YAZI_INSTALL_DIR"
	changes=$((changes + 1))
fi

if [ -f "$BASHRC_PATH" ] && [ ! -w "$BASHRC_PATH" ]; then
	echo -e "${BOLD}${YELLOW}Skipping ${BASHRC_PATH} edits (file is not writable).${RESET}"
elif [ -f "$BASHRC_PATH" ] && grep -qF "$YAZI_PATH_LINE" "$BASHRC_PATH" 2>/dev/null; then
	echo -e "${BOLD}${YELLOW}Removing yazi PATH line from ${BASHRC_PATH}...${RESET}"
	sed -i '\|^export PATH=\$PATH:/opt/yazi/target/release$|d' "$BASHRC_PATH"
	changes=$((changes + 1))
fi

if [ -f "$BASHRC_PATH" ] && [ -w "$BASHRC_PATH" ] && grep -qF "$YAZI_WRAPPER_START" "$BASHRC_PATH" 2>/dev/null; then
	echo -e "${BOLD}${YELLOW}Removing yazi wrapper block from ${BASHRC_PATH}...${RESET}"
	remove_yazi_wrapper_block "$BASHRC_PATH"
	changes=$((changes + 1))
fi

if [ -f "$CARGO_TREE_SITTER" ]; then
	echo -e "${BOLD}${YELLOW}Removing cargo tree-sitter binary...${RESET}"
	rm -f "$CARGO_TREE_SITTER"
	changes=$((changes + 1))
fi

if [ -L "$SYSTEM_TREE_SITTER" ] && [ "$(readlink "$SYSTEM_TREE_SITTER")" = "$CARGO_TREE_SITTER" ]; then
	echo -e "${BOLD}${YELLOW}Removing ${SYSTEM_TREE_SITTER} symlink to cargo binary...${RESET}"
	$SUDO rm -f "$SYSTEM_TREE_SITTER"
	changes=$((changes + 1))
fi

if [ "$changes" -eq 0 ]; then
	echo -e "${BOLD}${YELLOW}No managed source-built artifacts found to remove.${RESET}"
else
	echo -e "${BOLD}${GREEN}Uninstall completed.${RESET}"
	echo "You can reinstall with: bash setup.sh"
fi
