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
	local min_tree_sitter_version="0.26.1"
	local cargo_tree_sitter="$HOME/.cargo/bin/tree-sitter"

	if [ -s "$HOME/.cargo/env" ]; then
		# Ensure cargo-installed binaries are available even in non-login shells.
		source "$HOME/.cargo/env"
	fi

	get_tree_sitter_version() {
		local tree_sitter_bin="$1"
		local version_output
		local parsed_version

		if [ ! -x "$tree_sitter_bin" ]; then
			return 1
		fi

		version_output="$("$tree_sitter_bin" --version 2>/dev/null || true)"
		if [ -z "$version_output" ]; then
			return 1
		fi

		parsed_version="$(printf '%s\n' "$version_output" | sed -nE 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n1)"
		if [ -z "$parsed_version" ]; then
			return 1
		fi

		printf '%s\n' "$parsed_version"
		return 0
	}

	version_gte() {
		local lhs="$1"
		local rhs="$2"
		[ "$(printf '%s\n%s\n' "$lhs" "$rhs" | sort -V | head -n1)" = "$rhs" ]
	}

	tree_sitter_meets_minimum() {
		local tree_sitter_bin="$1"
		local detected_version

		detected_version="$(get_tree_sitter_version "$tree_sitter_bin" || true)"
		if [ -z "$detected_version" ]; then
			return 1
		fi

		version_gte "$detected_version" "$min_tree_sitter_version"
	}

	ensure_tree_sitter_on_path() {
		local cargo_bin="$1"

		# Keep cargo at highest precedence, even if nvm rewrites PATH later.
		touch ~/.bashrc
		sed -i '/^export PATH="\$HOME\/\.cargo\/bin:\$PATH"$/d' ~/.bashrc
		echo 'export PATH="$HOME/.cargo/bin:$PATH"' >>~/.bashrc
		export PATH="$HOME/.cargo/bin:$PATH"

		if [ -x "$cargo_bin" ]; then
			$SUDO ln -sf "$cargo_bin" /usr/local/bin/tree-sitter
		fi
	}

	if [ -x "$cargo_tree_sitter" ] && tree_sitter_meets_minimum "$cargo_tree_sitter"; then
		ensure_tree_sitter_on_path "$cargo_tree_sitter"
		echo -e "${BOLD}${YELLOW} tree-sitter CLI ${min_tree_sitter_version}+ is already installed via cargo.${RESET}"
		return 0
	fi

	if command -v tree-sitter >/dev/null 2>&1; then
		local current_tree_sitter
		current_tree_sitter="$(command -v tree-sitter)"
		if tree_sitter_meets_minimum "$current_tree_sitter"; then
			echo -e "${BOLD}${YELLOW} tree-sitter CLI ${min_tree_sitter_version}+ is already installed.${RESET}"
			return 0
		fi
		echo -e "${BOLD}${YELLOW} Existing tree-sitter does not meet LazyVim requirement (>= ${min_tree_sitter_version}) or is not runnable.${RESET}"
	fi

	if apt-cache show tree-sitter-cli >/dev/null 2>&1; then
		echo -e "${BOLD}${YELLOW} Installing tree-sitter-cli from apt...${RESET}"
		install_packages "tree-sitter-cli"
		if command -v tree-sitter >/dev/null 2>&1; then
			local apt_tree_sitter
			apt_tree_sitter="$(command -v tree-sitter)"
			if tree_sitter_meets_minimum "$apt_tree_sitter"; then
				local apt_tree_sitter_version
				apt_tree_sitter_version="$(get_tree_sitter_version "$apt_tree_sitter")"
				echo -e "${BOLD}${GREEN} tree-sitter CLI installed via apt (version ${apt_tree_sitter_version}).${RESET}"
				return 0
			fi
			local apt_detected_version
			apt_detected_version="$(get_tree_sitter_version "$apt_tree_sitter" || true)"
			if [ -n "$apt_detected_version" ]; then
				echo -e "${BOLD}${YELLOW} apt tree-sitter version ${apt_detected_version} is below required ${min_tree_sitter_version}; switching to cargo build.${RESET}"
			else
				echo -e "${BOLD}${YELLOW} apt tree-sitter binary is not runnable; switching to cargo build.${RESET}"
			fi
		fi
	fi

	# Build from source with cargo to satisfy version requirements and avoid prebuilt libc mismatches.
	if command -v cargo >/dev/null 2>&1; then
		echo -e "${BOLD}${YELLOW} Installing tree-sitter CLI via cargo...${RESET}"
		# bindgen requires libclang to be present when building from source
		install_packages "libclang-dev"
		local cargo_install_ok=false

		if cargo install tree-sitter-cli --locked --force; then
			cargo_install_ok=true
		elif command -v rustup >/dev/null 2>&1; then
			echo -e "${BOLD}${YELLOW} cargo install failed; updating Rust toolchain and retrying...${RESET}"
			rustup update stable
			rustup default stable
			if [ -s "$HOME/.cargo/env" ]; then
				source "$HOME/.cargo/env"
			fi
			if cargo install tree-sitter-cli --locked --force; then
				cargo_install_ok=true
			fi
		fi

		if [ "$cargo_install_ok" = true ] && tree_sitter_meets_minimum "$cargo_tree_sitter"; then
			ensure_tree_sitter_on_path "$cargo_tree_sitter"
			if command -v tree-sitter >/dev/null 2>&1 && tree_sitter_meets_minimum "$(command -v tree-sitter)"; then
				local cargo_tree_sitter_version
				cargo_tree_sitter_version="$(get_tree_sitter_version "$cargo_tree_sitter")"
				echo -e "${BOLD}${GREEN} tree-sitter CLI installed via cargo (version ${cargo_tree_sitter_version}).${RESET}"
				return 0
			fi
		fi
	fi

	if command -v tree-sitter >/dev/null 2>&1; then
		local final_tree_sitter
		final_tree_sitter="$(command -v tree-sitter)"
		if tree_sitter_meets_minimum "$final_tree_sitter"; then
			local final_tree_sitter_version
			final_tree_sitter_version="$(get_tree_sitter_version "$final_tree_sitter")"
			echo -e "${BOLD}${GREEN} tree-sitter CLI ready (version ${final_tree_sitter_version}).${RESET}"
			return 0
		fi
	fi

	echo -e "${BOLD}${RED} Failed to install tree-sitter CLI ${min_tree_sitter_version}+ required by LazyVim.${RESET}"
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

	configure_copilot_flag "$use_copilot"

	if [ "$use_copilot" = true ]; then
		install_nvm_and_node
	fi

	install_tree_sitter_cli

	echo -e "${BOLD}${GREEN}Neovim installed successfully.${RESET}"
}
