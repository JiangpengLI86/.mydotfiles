source ./setup_scripts/install_basic_packages.sh # For shared install helpers

install_nvm_and_node() {
	local nvm_version="v0.40.1"
	local had_nounset=false
	local nvm_installer
	local node_command
	local node_command_path
	export NVM_DIR="$HOME/.nvm"

	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		echo -e "${BOLD}${YELLOW}Installing nvm...${RESET}"
		nvm_installer="$(mktemp)"
		curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" -o "$nvm_installer"
		PROFILE=/dev/null bash "$nvm_installer"
		rm -f "$nvm_installer"
	fi

	if [[ $- == *u* ]]; then
		had_nounset=true
		set +u
	fi
	# shellcheck disable=SC1090
	source "$NVM_DIR/nvm.sh"
	nvm install --lts
	nvm use --lts
	nvm alias default 'lts/*' >/dev/null
	for node_command in node npm npx corepack; do
		node_command_path="$(command -v "$node_command" 2>/dev/null || true)"
		[ -z "$node_command_path" ] || link_local_bin "$node_command_path" "$node_command"
	done
	if [ "$had_nounset" = true ]; then
		set -u
	fi
}

ensure_npm_for_mason() {
	local node_command
	local node_command_path

	if command -v npm >/dev/null 2>&1 && npm --version >/dev/null 2>&1; then
		for node_command in node npm npx corepack; do
			node_command_path="$(command -v "$node_command" 2>/dev/null || true)"
			[ -z "$node_command_path" ] || link_local_bin "$node_command_path" "$node_command"
		done
		return
	fi
	install_nvm_and_node
}

install_neovim_prebuilt() {
	local arch nvim_arch glibc_version
	local source_repo="neovim/neovim"
	local target_dir="$HOME/.local/opt/nvim"
	local archive

	arch="$(uname -m)"
	case "$arch" in
	x86_64 | amd64) nvim_arch="x86_64" ;;
	aarch64 | arm64) nvim_arch="arm64" ;;
	*)
		echo -e "${BOLD}${RED}Unsupported architecture for Neovim: ${arch}.${RESET}"
		return 1
		;;
	esac

	glibc_version="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}' || true)"
	if [ -n "$glibc_version" ] && [ "$(printf '%s\n%s\n' "$glibc_version" "2.34" | sort -V | head -n1)" = "$glibc_version" ] && [ "$glibc_version" != "2.34" ]; then
		source_repo="neovim/neovim-releases"
	fi

	archive="$(mktemp /tmp/nvim-linux.XXXXXX.tar.gz)"
	curl -fL "https://github.com/${source_repo}/releases/latest/download/nvim-linux-${nvim_arch}.tar.gz" -o "$archive"
	rm -rf "$target_dir"
	mkdir -p "$target_dir"
	tar -xzf "$archive" --strip-components=1 -C "$target_dir"
	rm -f "$archive"

	ensure_local_bin_on_path
	ln -sfn "$target_dir/bin/nvim" "$HOME/.local/bin/nvim"
	hash -r
	nvim --version >/dev/null
}

configure_copilot_flag() {
	local marker="$HOME/.config/mydotfiles/enable-copilot"
	mkdir -p "$(dirname "$marker")"
	if [ "$1" = true ]; then
		touch "$marker"
	else
		rm -f "$marker"
	fi
}

install_neovim() {
	local use_copilot="$1"
	local nvim_path

	if command -v nvim >/dev/null 2>&1 && nvim --version >/dev/null 2>&1; then
		nvim_path="$(command -v nvim)"
		link_local_bin "$nvim_path" nvim
		echo -e "${BOLD}${YELLOW}Neovim already installed at ${nvim_path}.${RESET}"
	else
		install_neovim_prebuilt
	fi

	configure_copilot_flag "$use_copilot"
	if [ "$use_copilot" = true ]; then
		install_nvm_and_node
	fi
	ensure_npm_for_mason
	cargo install tree-sitter-cli --locked --no-default-features
	link_local_bin "$HOME/.cargo/bin/tree-sitter" tree-sitter

	echo -e "${BOLD}${GREEN}Neovim installed successfully.${RESET}"
}
