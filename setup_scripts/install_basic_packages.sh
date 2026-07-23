# Function to check if a package is installed
is_installed() {
	# dpkg -s returns 0 if the package is installed
	# and 1 if it is not installed
	# &>/dev/null redirects both stdout and stderr to /dev/null
	# so that the output is not shown
	dpkg -s "$1" &>/dev/null
	return $?
}

can_use_apt() {
	[ "${CAN_USE_APT:-false}" = true ]
}

apt_update_if_possible() {
	if can_use_apt; then
		echo -e "${BOLD}${YELLOW}Updating package list...${RESET}"
		$SUDO apt-get update
	else
		echo -e "${BOLD}${YELLOW}Skipping apt update (no root/sudo access).${RESET}"
	fi
}

ensure_local_bin_on_path() {
	export PATH="$HOME/.local/bin:$PATH"
	mkdir -p "$HOME/.local/bin"
}

link_local_bin() {
	local source_path="$1"
	local command_name="${2:-${source_path##*/}}"
	local target_path="$HOME/.local/bin/$command_name"

	if [ ! -x "$source_path" ]; then
		echo -e "${BOLD}${RED}Cannot expose missing executable: ${source_path}${RESET}" >&2
		return 1
	fi
	ensure_local_bin_on_path
	[ "$source_path" = "$target_path" ] || ln -sfn "$source_path" "$target_path"
}

require_commands() {
	local missing=()
	local cmd
	for cmd in "$@"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
		fi
	done

	if [ "${#missing[@]}" -gt 0 ]; then
		echo -e "${BOLD}${RED}Missing required commands:${RESET} ${missing[*]}"
		return 1
	fi
	return 0
}

github_latest_asset_url() {
	local repo="$1"
	local asset_regex="$2"
	local api_url="https://api.github.com/repos/${repo}/releases/latest"

	curl -fsSL "$api_url" |
		grep -Eo '"browser_download_url":[[:space:]]*"[^"]+"' |
		sed -E 's/^"browser_download_url":[[:space:]]*"//; s/"$//' |
		grep -E "$asset_regex" |
		head -n1
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
		if can_use_apt; then
			echo -e "${BOLD}${YELLOW}Installing the following packages:${RESET} ${GREEN}${to_install[*]}${RESET}"
			$SUDO apt-get install -y "${to_install[@]}"
			echo -e "${BOLD}${GREEN}All requested apt packages installed successfully.${RESET}"
		else
			echo -e "${BOLD}${YELLOW}Cannot install apt packages without root/sudo. Missing packages:${RESET} ${to_install[*]}"
			echo -e "${BOLD}${YELLOW}Continuing. If a later step requires one of these, setup will fail with a clear error.${RESET}"
		fi
	else
		echo -e "${BOLD}${GREEN}All packages installed successfully.${RESET}"
	fi
}

verify_essential_prerequisites() {
	local missing=()
	local cmd
	local essential_commands=(
		cc
		wget
		curl
		git
		python3
		make
		stow
		fc-cache
		unzip
		tar
		bzip2
		xz
	)

	for cmd in "${essential_commands[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
		fi
	done

	if command -v python3 >/dev/null 2>&1; then
		if ! python3 -m venv --help >/dev/null 2>&1; then
			missing+=("python3-venv(module)")
		fi
	fi

	if [ "${#missing[@]}" -gt 0 ]; then
		echo -e "${BOLD}${RED}Missing essential commands/prerequisites:${RESET} ${missing[*]}"
		echo -e "${BOLD}${RED}Install required packages manually or rerun with sudo/root.${RESET}"
		return 1
	fi

	echo -e "${BOLD}${GREEN}All essential prerequisites are available.${RESET}"
	return 0
}
