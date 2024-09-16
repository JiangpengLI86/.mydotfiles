source ./install_basic_packages.sh # For is_installed and install_packages functions

# Install the neovim text editor
install_neovim() {

	# Add PPA to the system =================================================

	# Since neovim's package is not the newest in the ubuntu repository, we need to add a personal package archive (PPA).
	echo -e "${BOLD}${YELLOW} Adding the neovim PPA to the system...${RESET}"

	# To be able to use add-apt-repository, we need to ensure software-properties-common is installed.
	dependencies=("software-properties-common")
	install_packages "${dependencies[@]}"

	# Add the PPA
	sudo apt-get-repository ppa:neovim-ppa/unstable
	sudo apt-get update

	# Install neovim =========================================================
	echo -e "${BOLD}${YELLOW} Installing neovim text editor...${RESET}"
	sudo apt-get install neovim

	echo -e "${BOLD}${GREEN} Neovim installed successfully.${RESET}"
}
