# Check whether the script is run as root, if not, ask for sudo permission
ensure_sudo() {
	if [[ "$EUID" -ne 0 ]]; then
		echo -e "${BOLD}${YELLOW}This script requires root privileges. Asking for sudo...${RESET}"
		# Re-run the script as root and preserve the original arguments.
		exec sudo -E bash "$0" "$@"
	fi
}
