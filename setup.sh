#!/bin/bash
# Run this script to setup the development environment.
# Run with: bash setup.sh

set -euo pipefail # Exit on errors, unset variables, and pipeline failures.

# Default values for variables ================================
USE_COPILOT=false
BASIC_PACKAGES=("build-essential" "wget" "curl" "git" "python3" "python3-venv" "make" "stow" "fontconfig" "unzip" "tar" "bzip2" "xz-utils")
STOW_TARGETS=("bash" "tmux" "nvim" "yazi" "inputrc" "condarc" "codex" "claude" "gemini")
FAILED_STEPS=()
PASSED_STEPS=()

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

# Run an independent install step, capturing failures without aborting ================================
run_step() {
	local step_name="$1"
	shift
	local rc=0
	echo ""
	echo -e "${BOLD}${YELLOW}--- Running: ${step_name} ---${RESET}"
	# Run in a subshell with set -e explicitly active so errexit semantics are
	# preserved inside the step (unguarded failures abort the step, not silently
	# ignored as they would be if called inside a && / || list). set +e in the
	# parent prevents a failing subshell from aborting the whole script.
	set +e
	( set -e; "$@" )
	rc=$?
	set -e
	# Propagate signal-induced exits (exit code > 128) so Ctrl+C and other
	# signals abort the whole script rather than silently continuing.
	if [ "$rc" -gt 128 ]; then
		exit "$rc"
	fi
	if [ "$rc" -eq 0 ]; then
		PASSED_STEPS+=("$step_name")
		echo -e "${BOLD}${GREEN}--- Passed: ${step_name} ---${RESET}"
	else
		FAILED_STEPS+=("$step_name")
		echo -e "${BOLD}${RED}--- FAILED: ${step_name} (exit code $rc) ---${RESET}"
	fi
}

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
run_step "Rust toolchain" bash ./setup_scripts/update_rust_stable.sh
# Source cargo env regardless — if rust was already installed it works;
# if the step failed, subsequent steps needing cargo will fail on their own.
if [ -s "$HOME/.cargo/env" ]; then
	# shellcheck source=/dev/null
	source "$HOME/.cargo/env"
else
	export PATH="$HOME/.cargo/bin:$PATH"
fi
# Force cargo/rustc invocations in this setup run to use stable.
export RUSTUP_TOOLCHAIN=stable

# Independent installations ================================
run_step "Miniconda"     install_miniconda
run_step "Nerd Fonts"    install_nerd_fonts
run_step "Yazi"          install_yazi
run_step "Lazygit"       install_lazygit
run_step "Neovim"        install_neovim "$USE_COPILOT"
run_step "Tmux"          install_tmux
run_step "VS Code CLI"   install_vscode_cli
run_step "Bashrc config" config_bashrc

# Stow the target directories ================================
stow_dotfiles() {
	if ! require_commands stow; then
		echo -e "${BOLD}${RED}GNU Stow is required for dotfile symlinks. Install it first or rerun with sudo/root.${RESET}"
		return 1
	fi
	# Pre-create AI assistant config directories to prevent stow tree-folding.
	# These tools write runtime data (auth, sessions, history) here, so we need
	# real directories with per-file symlinks rather than a single directory symlink.
	mkdir -p "$HOME/.config/mydotfiles" "$HOME/.codex/skills" "$HOME/.claude" "$HOME/.gemini"

	# Remove any pre-existing real files that would conflict with stow symlinks.
	# On a fresh machine these won't exist; on an existing machine they get replaced
	# by symlinks pointing back into this repo (content is already captured here).
	for conflict_file in \
		"$HOME/.codex/config.toml" \
		"$HOME/.claude/settings.json" \
		"$HOME/.gemini/settings.json"; do
		if [ -f "$conflict_file" ] && [ ! -L "$conflict_file" ]; then
			rm "$conflict_file"
		fi
	done
	echo -e "${BOLD}${YELLOW}Stowing directories...${RESET}"
	for target in "${STOW_TARGETS[@]}"; do
		stow "$target"
	done
	echo -e "${BOLD}${GREEN}Stowing completed!${RESET}"
}
run_step "GNU Stow symlinks" stow_dotfiles
run_step "Yazi packages" env PATH="$HOME/.local/bin:$PATH" ya pkg install

# Summary ================================
echo ""
echo -e "${BOLD}========== Setup Summary ==========${RESET}"
if [ "${#PASSED_STEPS[@]}" -gt 0 ]; then
	echo -e "${GREEN}Passed:${RESET}"
	for step in "${PASSED_STEPS[@]}"; do
		echo -e "  ${GREEN}✓${RESET} $step"
	done
fi
if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
	echo ""
	echo -e "${RED}Failed:${RESET}"
	for step in "${FAILED_STEPS[@]}"; do
		echo -e "  ${RED}✗${RESET} $step"
	done
	echo ""
	echo -e "${BOLD}${RED}Setup completed with ${#FAILED_STEPS[@]} failure(s).${RESET}"
	exit 1
else
	echo ""
	echo -e "${BOLD}${GREEN}Setup completed successfully!${RESET}"
fi
