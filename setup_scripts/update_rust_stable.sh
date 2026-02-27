#!/usr/bin/env bash
# Safely update the Rust stable toolchain on demand.
#
# Usage:
#   bash setup_scripts/update_rust_stable.sh
#   bash setup_scripts/update_rust_stable.sh --yes
#   bash setup_scripts/update_rust_stable.sh --check

set -euo pipefail

BOLD='\e[1m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
RESET='\e[0m'

AUTO_APPROVE=false
CHECK_ONLY=false

usage() {
	cat <<'EOF'
Usage: update_rust_stable.sh [options]

Options:
  -y, --yes    Run without interactive confirmation.
  --check      Show current Rust status and rustup check output only.
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

if ! command -v rustup >/dev/null 2>&1; then
	echo -e "${RED}rustup is not installed. Install Rust first: https://rustup.rs${RESET}"
	exit 1
fi

get_default_toolchain() {
	rustup toolchain list | awk '/\(default\)/ {print $1; exit}'
}

default_toolchain="$(get_default_toolchain)"
default_channel="${default_toolchain%%-*}"

echo -e "${BOLD}${YELLOW}Current Rust status:${RESET}"
if rustc +stable --version >/dev/null 2>&1; then
	echo "  $(rustc +stable --version)"
else
	echo "  stable toolchain: not installed"
fi

if cargo +stable --version >/dev/null 2>&1; then
	echo "  $(cargo +stable --version)"
fi

if [ -n "$default_toolchain" ]; then
	echo "  default toolchain: $default_toolchain"
else
	echo "  default toolchain: (not set)"
fi

if [ "$CHECK_ONLY" = true ]; then
	echo -e "${BOLD}${YELLOW}Running rustup check...${RESET}"
	rustup check
	exit 0
fi

if [ "$AUTO_APPROVE" != true ]; then
	if [ ! -t 0 ]; then
		echo -e "${RED}Non-interactive shell detected. Re-run with --yes to proceed.${RESET}"
		exit 1
	fi

	read -r -p "Update Rust stable toolchain now? [y/N] " answer
	case "$answer" in
	y | Y | yes | YES)
		;;
	*)
		echo -e "${YELLOW}Canceled.${RESET}"
		exit 0
		;;
	esac
fi

echo -e "${BOLD}${YELLOW}Updating rustup...${RESET}"
rustup self update

echo -e "${BOLD}${YELLOW}Installing/updating Rust stable toolchain...${RESET}"
rustup toolchain install stable --profile default

echo -e "${BOLD}${YELLOW}Ensuring standard stable components...${RESET}"
rustup component add rustfmt clippy --toolchain stable

echo -e "${BOLD}${YELLOW}Verifying Rust toolchain status...${RESET}"
rustup check
echo "  $(rustc +stable --version)"
echo "  $(cargo +stable --version)"

if [ "$default_channel" != "stable" ] && [ -n "$default_toolchain" ]; then
	echo -e "${BOLD}${YELLOW}Note:${RESET} default toolchain remains ${default_toolchain} (unchanged)."
fi

echo -e "${BOLD}${GREEN}Rust stable toolchain update completed.${RESET}"
