# Check whether the script is run as root, if not, ask for sudo permission
ensure_sudo() {
	if [[ "$EUID" -ne 0 ]]; then
		echo "${BOLD}{$RED}This script requires root privileges. Asking for sudo...${RESET}"
		# The exec command replaces the current process with the sudo command,
		# rather than running sudo as a child process if we are using "sudo $0 $@"
		exec sudo "$0" "$@" # Rerun the script with sudo
	fi
}
