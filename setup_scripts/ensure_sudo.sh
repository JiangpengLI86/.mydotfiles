# Detect whether apt-based installation is available.
# This script no longer hard-requires root. It will use apt when running as root
# or when sudo authentication succeeds, and otherwise continue in non-sudo mode.
ensure_sudo() {
	export CAN_USE_APT=false
	export SUDO=""

	if ! command -v apt-get >/dev/null 2>&1; then
		echo -e "${BOLD}${YELLOW}apt-get not found. Skipping apt-based installs.${RESET}"
		return 0
	fi

	if [[ "$EUID" -eq 0 ]]; then
		export CAN_USE_APT=true
		echo -e "${BOLD}${GREEN}Running as root. apt-based installs are enabled.${RESET}"
		return 0
	fi

	if ! command -v sudo >/dev/null 2>&1; then
		echo -e "${BOLD}${YELLOW}sudo is not available. Continuing in non-sudo mode.${RESET}"
		return 0
	fi

	# Prefer a non-interactive check first for CI/non-interactive environments.
	if sudo -n true >/dev/null 2>&1; then
		export SUDO="sudo"
		export CAN_USE_APT=true
		echo -e "${BOLD}${GREEN}sudo access detected. apt-based installs are enabled.${RESET}"
		return 0
	fi

	if [ ! -t 0 ]; then
		echo -e "${BOLD}${YELLOW}sudo requires a terminal for authentication here. Continuing in non-sudo mode.${RESET}"
		return 0
	fi

	echo -e "${BOLD}${YELLOW}sudo is available. Attempting authentication for apt-based installs...${RESET}"
	if sudo -v; then
		export SUDO="sudo"
		export CAN_USE_APT=true
		echo -e "${BOLD}${GREEN}sudo authentication successful. apt-based installs are enabled.${RESET}"
	else
		echo -e "${BOLD}${YELLOW}sudo authentication failed. Continuing in non-sudo mode.${RESET}"
	fi
}
