# Check whether the script is run as root, if not, ask for sudo permission
ensure_sudo() {
	if [[ "$EUID" -ne 0 ]]; then
		echo "${BOLD}{$RED}This script requires root privileges. Asking for sudo...${RESET}"
		# The exec command replaces the current process with the sudo command,
		# rather than running sudo as a child process if we are using "sudo $0 $@"
		# Check if the script is being run using 'bash'
		if [[ "$0" == "bash" ]]; then
		    # If the script was invoked with 'bash', include 'bash' in the sudo command
		    exec sudo bash "$0" "$@"
		else
		    # If it's running directly, just use sudo with the full script path
		    SCRIPT_PATH="$(realpath "$0")"
		    exec sudo bash "$SCRIPT_PATH" "$@"
		fi
	fi
}
