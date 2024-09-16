# Function to check if a package is installed
is_installed() {
	# dpkg -s returns 0 if the package is installed
	# and 1 if it is not installed
	# &>/dev/null redirects both stdout and stderr to /dev/null
	# so that the output is not shown
	dpkg -s "$1" &>/dev/null
	return $?
}

# Install packages only if they are not installed
install_packages() {
	local to_install=()
	local already_installed=()

	for package in "$@"; do
		if is_installed "$package"; then
			already_installed+=("$package")
		else
			to_install+=("$package")
		fi
	done

	# Show already installed packages
	# [...] is a test command in Bash. It is used to evaluate expressions inside it.
	# already_installed[@] refers to all elements
	# ${#already_installed[@]} returns the number of elements in the array
	# -gt stands for greater than
	if [ "${#already_installed[@]}" -gt 0 ]; then
		echo -e "${BOLD}${YELLOW}The following packages are already installed:${RESET} ${GREEN}${already_installed[*]}${RESET}"
	fi

	# Install the packages that are not already installed
	if [ "${#to_install[@]}" -gt 0 ]; then
		echo -e "${BOLD}${YELLOW}Installing the following packages:${RESET} ${GREEN}${to_install[*]}${RESET}"
		sudo apt-get install -y "${to_install[@]}"
	else
		echo -e "${BOLD}${GREEN}All packages installed successfully.${RESET}"
	fi
}
