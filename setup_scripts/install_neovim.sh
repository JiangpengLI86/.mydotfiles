source ./setup_scripts/install_basic_packages.sh # For is_installed and install_packages functions

install_nvm_and_node() {
	local nvm_version="v0.40.1"
	export NVM_DIR="$HOME/.nvm"

	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		echo -e "${BOLD}${YELLOW} Installing nvm...${RESET}"
		curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
	fi

	# shellcheck disable=SC1090
	source "$NVM_DIR/nvm.sh"

	echo -e "${BOLD}${YELLOW} Installing latest LTS Node.js with nvm...${RESET}"
	nvm install --lts
	nvm use --lts
	nvm alias default 'lts/*'

	echo -e "${BOLD}${GREEN} nvm and Node.js installed successfully.${RESET}"
}

install_tree_sitter_cli() {
	local cargo_tree_sitter="$HOME/.cargo/bin/tree-sitter"

	if [ -s "$HOME/.cargo/env" ]; then
		# Ensure cargo-installed binaries are available even in non-login shells.
		source "$HOME/.cargo/env"
	fi

	ensure_tree_sitter_on_path() {
		local cargo_bin="$1"

		if ! grep -qF 'export PATH="$HOME/.cargo/bin:$PATH"' ~/.bashrc; then
			echo 'export PATH="$HOME/.cargo/bin:$PATH"' >>~/.bashrc
		fi
		export PATH="$HOME/.cargo/bin:$PATH"

		if [ ! -x "$cargo_bin" ]; then
			return
		fi

		local path_tree_sitter
		path_tree_sitter="$(command -v tree-sitter 2>/dev/null || true)"

		if [ -z "$path_tree_sitter" ]; then
			$SUDO ln -sf "$cargo_bin" /usr/local/bin/tree-sitter
			return
		fi

		if [ "$path_tree_sitter" != "$cargo_bin" ]; then
			if ! "$path_tree_sitter" --version >/dev/null 2>&1; then
				$SUDO ln -sf "$cargo_bin" /usr/local/bin/tree-sitter
			fi
		fi
	}

	if [ -x "$cargo_tree_sitter" ] && "$cargo_tree_sitter" --version >/dev/null 2>&1; then
		ensure_tree_sitter_on_path "$cargo_tree_sitter"
		echo -e "${BOLD}${YELLOW} tree-sitter CLI is already installed.${RESET}"
		return 0
	fi

	if command -v tree-sitter >/dev/null 2>&1 && tree-sitter --version >/dev/null 2>&1; then
		echo -e "${BOLD}${YELLOW} tree-sitter CLI is already installed.${RESET}"
		return 0
	fi

	echo -e "${BOLD}${YELLOW} Installing tree-sitter CLI...${RESET}"

	# Try apt first (preferred on Ubuntu).
	if $SUDO apt-get install -y tree-sitter-cli && tree-sitter --version >/dev/null 2>&1; then
		echo -e "${BOLD}${GREEN} tree-sitter CLI installed via apt.${RESET}"
		return 0
	fi

	# Fallback: build from source with cargo for better libc compatibility.
	if command -v cargo >/dev/null 2>&1; then
		# bindgen requires libclang to be present when building from source
		install_packages "libclang-dev"
		local cargo_install_ok=false

		if cargo install tree-sitter-cli --locked; then
			cargo_install_ok=true
		elif command -v rustup >/dev/null 2>&1; then
			echo -e "${BOLD}${YELLOW} cargo install failed; updating Rust toolchain and retrying...${RESET}"
			rustup update stable
			rustup default stable
			if [ -s "$HOME/.cargo/env" ]; then
				source "$HOME/.cargo/env"
			fi
			if cargo install tree-sitter-cli --locked; then
				cargo_install_ok=true
			fi
		fi

		if [ "$cargo_install_ok" = true ] && "$cargo_tree_sitter" --version >/dev/null 2>&1; then
			ensure_tree_sitter_on_path "$cargo_tree_sitter"
			# If an incompatible npm-installed binary shadows PATH, remove it.
			if command -v npm >/dev/null 2>&1 && command -v tree-sitter >/dev/null 2>&1; then
				if ! tree-sitter --version >/dev/null 2>&1; then
					npm uninstall -g tree-sitter-cli || true
				fi
			fi
			echo -e "${BOLD}${GREEN} tree-sitter CLI installed via cargo.${RESET}"
			return 0
		fi
	fi

	# Last fallback: npm global package.
	if command -v npm >/dev/null 2>&1; then
		npm install -g tree-sitter-cli
		if tree-sitter --version >/dev/null 2>&1; then
			echo -e "${BOLD}${GREEN} tree-sitter CLI installed via npm.${RESET}"
			return 0
		fi
	fi

	echo -e "${BOLD}${RED} Failed to install a working tree-sitter CLI.${RESET}"
	return 1
}

configure_copilot_flag() {
	local use_copilot="$1"
	local copilot_flag='export ENABLE_COPILOT=1'

	# Clear only the exact managed flag to keep setup idempotent.
	sed -i '/^export ENABLE_COPILOT=1$/d' ~/.bashrc

	if [ "$use_copilot" = true ]; then
		echo "$copilot_flag" >> ~/.bashrc
		echo -e "${BOLD}${YELLOW} Copilot support enabled for Neovim.${RESET}"
	else
		echo -e "${BOLD}${YELLOW} Copilot support disabled for Neovim.${RESET}"
	fi
}

# Install the neovim text editor
install_neovim() {
	local use_copilot="$1"

	# Since neovim's package is not the newest in the ubuntu repository, use the unstable PPA.
	echo -e "${BOLD}${YELLOW}Adding the neovim PPA to the system...${RESET}"

	dependencies=("software-properties-common")
	install_packages "${dependencies[@]}"

	if ! grep -Rq "ppa.launchpadcontent.net/neovim-ppa/unstable" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
		$SUDO add-apt-repository -y ppa:neovim-ppa/unstable
	fi
	$SUDO apt-get update

	echo -e "${BOLD}${YELLOW}Installing neovim text editor...${RESET}"
	$SUDO apt-get install -y neovim

	install_tree_sitter_cli

	configure_copilot_flag "$use_copilot"

	if [ "$use_copilot" = true ]; then
		install_nvm_and_node
	fi

	echo -e "${BOLD}${GREEN}Neovim installed successfully.${RESET}"
}
