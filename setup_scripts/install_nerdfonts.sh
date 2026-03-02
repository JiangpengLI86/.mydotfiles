# Install Nerd Fonts
install_nerd_fonts() {

	echo -e "${BOLD}${YELLOW}Configuring Nerd Fonts...${RESET}"

	if ! require_commands curl tar xz fc-cache; then
		echo -e "${BOLD}${RED}Missing essential tools for Nerd Fonts install (curl/tar/xz/fc-cache).${RESET}"
		echo -e "${BOLD}${RED}Install required packages first or rerun setup with sudo/root.${RESET}"
		return 1
	fi

	mkdir -p "$HOME/.local/share/fonts/" # Create the directory if it does not exist
	local font_glob="$HOME/.local/share/fonts/CaskaydiaMonoNerdFont*"

	if compgen -G "${font_glob}.ttf" >/dev/null || compgen -G "${font_glob}.otf" >/dev/null; then
		echo -e "${BOLD}${GREEN}Nerd Fonts CascadiaMono Nerd Font already installed. Skipping download.${RESET}"
		return 0
	fi

	# Download the resources to the specified directory
	echo -e "${BOLD}${YELLOW}Downloading Nerd Fonts CascadiaMono Nerd Font...${RESET}"
	curl -Lo "$HOME/.local/share/fonts/CascadiaMono.tar.xz" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.tar.xz

	# Extract the files
	echo -e "${BOLD}${YELLOW}Extracting Nerd Fonts CascadiaMono Nerd Font...${RESET}"
	tar -xf "$HOME/.local/share/fonts/CascadiaMono.tar.xz" -C "$HOME/.local/share/fonts/"

	# Clean up the downloaded files
	echo -e "${BOLD}${YELLOW}Cleaning up...${RESET}"
	rm "$HOME/.local/share/fonts/CascadiaMono.tar.xz"

	# Update the font cache
	echo -e "${BOLD}${YELLOW}Updating font cache...${RESET}"
	fc-cache -f -v

	# List the installed fonts
	# echo -e "${BOLD}${YELLOW}Installed fonts:${RESET}"
	# fc-list | grep "CaskaydiaMonoNerdFont"

	echo -e "${BOLD}${GREEN}Nerd Fonts CascadiaMono Nerd Font has been successfully installed.${RESET}"
}
