#!/bin/bash
# Run this script to setup the development environment.
# Run with: sudo bash setup.sh

# Default values for variables ================================
USE_COPILOT=false
BASIC_PACKAGES = ("build-essential" "wget" "curl" "git" "neovim" "python3" "make" "stow")
STOW_TARGETS = ("tmux" "nvim" "yazi" "inputrc")

# Import functions ================================
source ./setup_scripts/ensure_sudo.sh # For ensure_sudo() function
source ./setup_scripts/help_messages.sh  # For usage() function
source ./setup_scripts/install_basic_packages.sh # For install_packages() function
source ./setup_scripts/install_nerdfonts.sh # For install_nerd_fonts() function
source ./setup_scripts/install_yazi.sh # For install_yazi() function
source ./setup_scripts/install_neovim.sh # For install_neovim() function
source ./setup_scripts/install_tmux.sh # For install_tmux() function
source ./setup_scripts/config_bashrc.sh # For config_bashrc() function

# Color variables for better readability ================================
export RED='\e[31m'
export GREEN='\e[32m'
export YELLOW='\e[33m'
export BOLD='\e[1m'
export RESET='\e[0m'  # Reset color and formatting

# Check if the script is run as root ================================
ensure_sudo

# Check if the script is called in root directory of this project ================================
if [[ $(basename "$PWD") != ".mydotfiles" ]]; then
  echo -e "${RED}Please run this script in the root directory of the project.${RESET}"
  exit 1
fi

# Parse command-line arguments ================================
while [[ "$1" != "" ]]; do # $1 is a positional parameter in bash, representing the first argument passed to the script.
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

# Update package list ================================
echo -e "${BOLD}${YELLOW}Updating package list...${RESET}"
apt-get update

# Install basic packages ================================
install_packages "${BASIC_PACKAGES[@]}"

# Installation of nerdfonts ================================
install_nerd_fonts

# Installation of Yazi ================================
install_yazi

# Installation of Neovim ================================
install_neovim "$USE_COPILOT"

# Installation of Tmux ================================
install_tmux

# Additional Configuration of .bashrc ================================
config_bashrc

# Stow the targets directories ================================
echo -e "${BOLD}${YELLOW}Stowing directories...${RESET}"
for target in "${STOW_TARGETS[@]}"; do
  stow "$target"
done
echo -e "${BOLD}${GREEN}Stowing completed!${RESET}"

echo -e "${BOLD}${GREEN}Setup completed successfully!${RESET}"
