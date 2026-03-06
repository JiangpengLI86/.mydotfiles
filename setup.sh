#!/bin/bash
# Run this script to setup the development environment.
# Run with: bash setup.sh

set -euo pipefail # Exit on errors, unset variables, and pipeline failures.

# Default values for variables ================================
USE_COPILOT=false
BASIC_PACKAGES=("build-essential" "wget" "curl" "git" "python3" "python3-venv" "make" "stow" "fontconfig" "unzip" "tar" "bzip2" "xz-utils")
STOW_TARGETS=("tmux" "nvim" "yazi" "inputrc" "condarc")

# Import functions ================================
source ./setup_scripts/ensure_sudo.sh            # For ensure_sudo() function
source ./setup_scripts/help_messages.sh          # For usage() function
source ./setup_scripts/install_basic_packages.sh # For install_packages() function
source ./setup_scripts/install_nerdfonts.sh      # For install_nerd_fonts() function
source ./setup_scripts/install_yazi.sh           # For install_yazi() function
source ./setup_scripts/install_lazygit.sh        # For install_lazygit() function
source ./setup_scripts/install_neovim.sh         # For install_neovim() function
source ./setup_scripts/install_tmux.sh           # For install_tmux() function
source ./setup_scripts/install_vscode_cli.sh     # For install_vscode_cli() function
source ./setup_scripts/install_miniconda.sh      # For install_miniconda() function
source ./setup_scripts/config_bashrc.sh          # For config_bashrc() function

# Color variables for better readability ================================
export RED='\e[31m'
export GREEN='\e[32m'
export YELLOW='\e[33m'
export BOLD='\e[1m'
export RESET='\e[0m' # Reset color and formatting

# Check if the script is called in root directory of this project ================================
if [[ $(basename "$PWD") != ".mydotfiles" ]]; then
	echo -e "${RED}Please run this script in the root directory of the project.${RESET}"
	exit 1
fi

# Parse command-line arguments ================================
while (($#)); do # Parse remaining positional arguments safely with nounset enabled.
	case $1 in
	--use-copilot)
		USE_COPILOT=true
		;; # Each match ends with a double semicolon.
	-h | --help)
		usage
		exit 0
		;;
	*) # This * means "anything else"
		echo "Unknown option: $1"
		usage
		exit 1
		;;
	esac
	shift # Shift is a bash built-in that moves all the positional parameters down by one. Then $2 becomes $1, $3 becomes $2, and so on.
done

# Detect privilege mode (apt-enabled vs non-sudo fallback) ================================
ensure_sudo

# Update package list ================================
apt_update_if_possible

# Install basic packages ================================
install_packages "${BASIC_PACKAGES[@]}"
verify_essential_prerequisites

if [ "${SETUP_TEST_EXIT_AFTER_PREREQS:-0}" = "1" ]; then
	echo -e "${BOLD}${YELLOW}SETUP_TEST_EXIT_AFTER_PREREQS=1 set. Stopping after prerequisite checks.${RESET}"
	exit 0
fi

# Ensure Rust stable toolchain is installed/updated for all source builds ================================
echo -e "${BOLD}${YELLOW}Ensuring Rust stable toolchain...${RESET}"
bash ./setup_scripts/update_rust_stable.sh --yes
if [ -s "$HOME/.cargo/env" ]; then
	# shellcheck source=/dev/null
	source "$HOME/.cargo/env"
else
	export PATH="$HOME/.cargo/bin:$PATH"
fi
# Force cargo/rustc invocations in this setup run to use stable.
export RUSTUP_TOOLCHAIN=stable

# Installation of Miniconda ================================
install_miniconda

# Installation of nerdfonts ================================
install_nerd_fonts

# Installation of Yazi ================================
install_yazi

# Installation of lazygit ================================
install_lazygit

# Installation of Neovim ================================
install_neovim "$USE_COPILOT"

# Installation of Tmux ================================
install_tmux

# Installation of VS Code CLI ================================
install_vscode_cli

# Additional Configuration of .bashrc ================================
config_bashrc

# Stow the targets directories ================================
echo -e "${BOLD}${YELLOW}Stowing directories...${RESET}"
if ! require_commands stow; then
	echo -e "${BOLD}${RED}GNU Stow is required for dotfile symlinks. Install it first or rerun with sudo/root.${RESET}"
	exit 1
fi

for target in "${STOW_TARGETS[@]}"; do
	stow "$target"
done
echo -e "${BOLD}${GREEN}Stowing completed!${RESET}"

echo -e "${BOLD}${GREEN}Setup completed successfully!${RESET}"
