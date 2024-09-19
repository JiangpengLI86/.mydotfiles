source ./setup_scripts/install_basic_packages.sh # For is_installed and install_packages functions

# Install the neovim text editor
install_neovim() {

	# Add PPA to the system =================================================

	# Since neovim's package is not the newest in the ubuntu repository, we need to add a personal package archive (PPA).
	echo -e "${BOLD}${YELLOW} Adding the neovim PPA to the system...${RESET}"

	# To be able to use add-apt-repository, we need to ensure software-properties-common is installed.
	dependencies=("software-properties-common")
	install_packages "${dependencies[@]}"

	wait

	# Add the PPA
	$SUDO add-apt-repository -y ppa:neovim-ppa/unstable
	$SUDO apt-get update

	# Install neovim =========================================================
	echo -e "${BOLD}${YELLOW} Installing neovim text editor...${RESET}"
	$SUDO apt-get install -y neovim

	# Configure whether copilot is used here ================================
	local use_copilot=$1

	if [ $use_copilot == true ]; then
		echo -e "${BOLD}${YELLOW} Copilot plugin will be installed in Neovim (Only used this in a trusted environment!)${RESET}"

		# Just let the nvim config folder intact, the LazyVim package manager will install the copilot plugin automatically.

		# Install the nvm package manager and then install nodejs, which is required by the copilot plugin.
		echo -e "${BOLD}${YELLOW} Installing nvm package manager and nodejs required by copilot plugin...${RESET}"

		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

		wait

		source ~/.nvm/nvm.sh
		source ~/.bashrc
		nvm install node

		wait

		echo -e "${BOLD}${GREEN} nvm and nodejs installed successfully.${RESET}"

	else
		echo -e "${BOLD}${YELLOW} Copilot plugin will not be installed in Neovim.${RESET}"

		echo -e "${BOLD}${YELLOW} Removing the copilot installation instructions from the nvim/.config/nvim/...${RESET}"

		# Remove all lines from ./nvim/.config/nvim/lua/config/lazy.lua that contains the word "copilot"
		sed -i '/copilot/d' ./nvim/.config/nvim/lua/config/lazy.lua # sed: stream editor; -i: in-place editing; /pattern/d: delete lines matching the pattern

		# Remove all lines from ./nvim/.config/nvim/lazy-lock.json that contains the word "copilot"
		sed -i '/copilot/d' ./nvim/.config/nvim/lazy-lock.json

		# Remove the file ./nvim/.config/nvim/lua/plugins/copilot.lua
		rm -f ./nvim/.config/nvim/lua/plugins/copilot.lua
	fi

	# Installing dependencies of nvim plugin ================================

	echo -e "${BOLD}${YELLOW} Installing dependencies of neovim plugin...${RESET}"
	# Installation of nvm
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

	echo -e "${BOLD}${GREEN} Neovim installed successfully.${RESET}"
}
