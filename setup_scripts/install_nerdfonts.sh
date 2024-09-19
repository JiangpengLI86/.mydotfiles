# Install Nerd Fonts
install_nerd_fonts() {

	echo -e "${BOLD}${YELLOW}Configuring Nerd Fonts...${RESET}"

	mkdir -p "$HOME/.local/share/fonts/" # Create the directory if it doesn't exist

	# Download the resources to the specified directory
	echo -e "${BOLD}${YELLOW}Downloading Nerd Fonts CascadiaMono Nerd Font...${RESET}"
	curl -Lo $HOME/.local/share/fonts/CascadiaMono.tar.xz https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.tar.xz
	
	wait

	# Extract the files
	echo -e "${BOLD}${YELLOW}Extracting Nerd Fonts CascadiaMono Nerd Font...${RESET}"
	tar -xf $HOME/.local/share/fonts/CascadiaMono.tar.xz -C $HOME/.local/share/fonts/
	
	wait

	# Clean up the downloaded files
	echo -e "${BOLD}${YELLOW}Cleaning up...${RESET}"
	rm $HOME/.local/share/fonts/CascadiaMono.tar.xz

	# Update the font cache
	echo -e "${BOLD}${YELLOW}Updating font cache...${RESET}"
	fc-cache -f -v

	# List the installed fonts
	# echo -e "${BOLD}${YELLOW}Installed fonts:${RESET}"
	# fc-list | grep "CaskaydiaMonoNerdFont"

	# wait

	echo -e "${BOLD}${GREEN}Nerd Fonts CascadiaMono Nerd Font has been successfully installed.${RESET}"
}
