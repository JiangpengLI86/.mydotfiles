#!/bin/bash

# Default values for variables ================================
USE_COPILOT=false
BASIC_PACKAGES = ("build-essential" "wget" "curl" "git" "neovim" "python3" "make")

# Import functions ================================
source ./setup_scripts/help_messages.sh  # For usage() function
source ./setup_scripts/install_basic_packages.sh # For install_packages() function
source ./setup_scripts/install_yazi.sh # For install_yazi() function
source ./setup_scripts/install_neovim.sh # For install_neovim() function

# Color variables for better readability ================================
export RED='\e[31m'
export GREEN='\e[32m'
export YELLOW='\e[33m'
export BOLD='\e[1m'
export RESET='\e[0m'  # Reset color and formatting

# Parse command-line arguments ================================
while [[ "$1" != "" ]]; do # $1 is a positional parameter in bash, representing the first argument passed to the script.
  case $1 in
  --use-copilot)
    USE_COPILOT=true
    ;; # Each match ends with a double semicolon.
  -h | --help)
    usage
    exit
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
sudo apt-get update

# Installation of nerdfonts ================================


# Install basic packages ================================
install_packages "${BASIC_PACKAGES[@]}"

# Installation of Yazi ================================
install_yazi

# Installation of Neovim ================================
install_neovim

# Installation of Tmux ================================
















echo "All packages are installed!"
