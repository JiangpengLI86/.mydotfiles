source ./setup_scripts/install_basic_packages.sh # For helpers and install_packages functions

install_nvm_and_node() {
	local nvm_version="v0.40.1"
	local had_nounset=false
	export NVM_DIR="$HOME/.nvm"

	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		echo -e "${BOLD}${YELLOW} Installing nvm...${RESET}"
		curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
	fi

	# nvm internals are not fully nounset-safe; setup.sh uses `set -u`.
	if [[ $- == *u* ]]; then
		had_nounset=true
		set +u
	fi

	# shellcheck disable=SC1090
	source "$NVM_DIR/nvm.sh"

	echo -e "${BOLD}${YELLOW} Installing latest LTS Node.js with nvm...${RESET}"
	nvm install --lts
	nvm use --lts
	nvm alias default 'lts/*' >/dev/null 2>&1 || nvm alias default node >/dev/null 2>&1 || true

	if [ "$had_nounset" = true ]; then
		set -u
	fi

	echo -e "${BOLD}${GREEN} nvm and Node.js installed successfully.${RESET}"
}

ensure_npm_for_mason() {
	if command -v npm >/dev/null 2>&1 && npm --version >/dev/null 2>&1; then
		echo -e "${BOLD}${YELLOW} npm is already available for Mason.${RESET}"
		return 0
	fi

	echo -e "${BOLD}${YELLOW} npm not found; installing Node.js LTS via nvm for Mason...${RESET}"
	install_nvm_and_node

	if command -v npm >/dev/null 2>&1 && npm --version >/dev/null 2>&1; then
		echo -e "${BOLD}${GREEN} npm is now available for Mason.${RESET}"
		return 0
	fi

	echo -e "${BOLD}${RED} Failed to provide npm required by Mason.${RESET}"
	return 1
}

install_neovim_prebuilt() {
	local arch
	local nvim_arch
	local download_url
	local install_root="$HOME/.local/opt"
	local target_dir="$install_root/nvim"
	local tmp_tar
	local extracted_dir

	arch="$(uname -m)"
	case "$arch" in
	x86_64 | amd64)
		nvim_arch="x86_64"
		;;
	aarch64 | arm64)
		nvim_arch="arm64"
		;;
	*)
		echo -e "${BOLD}${RED}Unsupported architecture for Neovim prebuilt install: ${arch}.${RESET}"
		return 1
		;;
	esac

	require_commands curl tar || {
		echo -e "${BOLD}${RED}Missing essential download/extract tools for non-sudo Neovim install.${RESET}"
		return 1
	}

	download_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${nvim_arch}.tar.gz"
	echo -e "${BOLD}${YELLOW}Installing Neovim from prebuilt release (${nvim_arch})...${RESET}"

	tmp_tar="$(mktemp /tmp/nvim-linux.XXXXXX.tar.gz)"
	curl -fL "$download_url" -o "$tmp_tar"

	mkdir -p "$install_root"
	rm -rf "$target_dir"
	mkdir -p "$target_dir"
	tar -xzf "$tmp_tar" -C "$target_dir"
	rm -f "$tmp_tar"

	extracted_dir="$(find "$target_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
	if [ -z "$extracted_dir" ] || [ ! -x "$extracted_dir/bin/nvim" ]; then
		echo -e "${BOLD}${RED}Failed to locate nvim binary after extraction.${RESET}"
		return 1
	fi

	ensure_local_bin_on_path
	ln -sf "$extracted_dir/bin/nvim" "$HOME/.local/bin/nvim"

	if ! command -v nvim >/dev/null 2>&1; then
		echo -e "${BOLD}${RED}nvim is still not on PATH after local installation.${RESET}"
		return 1
	fi
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

	resolve_c_compiler() {
		local compiler

		if [ -n "${CC:-}" ] && command -v "${CC}" >/dev/null 2>&1; then
			command -v "${CC}"
			return 0
		fi

		for compiler in cc gcc clang; do
			if command -v "$compiler" >/dev/null 2>&1; then
				command -v "$compiler"
				return 0
			fi
		done

		return 1
	}

	has_libclang() {
		local libclang_path
		local llvm_libdir
		local candidate

		libclang_path="${LIBCLANG_PATH:-}"
		if [ -n "$libclang_path" ] && find "$libclang_path" -maxdepth 2 -type f -name 'libclang.so*' 2>/dev/null | grep -q .; then
			return 0
		fi

		if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -q 'libclang\.so'; then
			return 0
		fi

		if command -v llvm-config >/dev/null 2>&1; then
			llvm_libdir="$(llvm-config --libdir 2>/dev/null || true)"
			if [ -n "$llvm_libdir" ] && find "$llvm_libdir" -maxdepth 1 -type f -name 'libclang.so*' 2>/dev/null | grep -q .; then
				return 0
			fi
		fi

		if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W -f='${db:Status-Abbrev}\n' 'libclang*-dev' 2>/dev/null | grep -q '^ii '; then
			return 0
		fi

		for candidate in \
			"/usr/lib/llvm-"*/lib/libclang.so* \
			"/usr/lib/"*/libclang.so* \
			"/usr/lib64/libclang.so*" \
			"/usr/local/lib/libclang.so*" \
			"/lib/"*/libclang.so* \
			"/lib64/libclang.so*"; do
			if [ -e "$candidate" ]; then
				return 0
			fi
		done

		if find "$HOME/.local" -type f -name 'libclang.so*' 2>/dev/null | grep -q .; then
			return 0
		fi

		return 1
	}

	remove_local_tree_sitter_binary() {
		local tree_sitter_bin="$1"

		case "$tree_sitter_bin" in
		"$HOME/.cargo/bin/tree-sitter" | "$HOME/.local/bin/tree-sitter")
			rm -f "$tree_sitter_bin"
			;;
		esac
	}

	cleanup_incompatible_treesitter_parsers() {
		local parser_dir
		local parser_so
		local ldd_output
		local removed_any=false

		if ! command -v ldd >/dev/null 2>&1; then
			return 0
		fi

		for parser_dir in "$HOME/.local/share/nvim/site/parser" "$HOME/.local/share/nvim/lazy/nvim-treesitter/parser"; do
			[ -d "$parser_dir" ] || continue
			for parser_so in "$parser_dir"/*.so; do
				[ -e "$parser_so" ] || continue
				ldd_output="$(ldd "$parser_so" 2>&1 || true)"
				if printf '%s\n' "$ldd_output" | grep -Eq 'GLIBC_[0-9]+\.[0-9]+|not found'; then
					rm -f "$parser_so"
					removed_any=true
				fi
			done
		done

		if [ "$removed_any" = true ]; then
			echo -e "${BOLD}${YELLOW} Removed incompatible nvim treesitter parser binaries; they will be rebuilt locally.${RESET}"
		fi
	}

	ensure_tree_sitter_on_path() {
		local cargo_bin="$1"

		# Keep cargo at highest precedence, even if nvm rewrites PATH later.
		touch ~/.bashrc
		sed -i '/^export PATH="\$HOME\/\.cargo\/bin:\$PATH"$/d' ~/.bashrc
		echo 'export PATH="$HOME/.cargo/bin:$PATH"' >>~/.bashrc
		export PATH="$HOME/.cargo/bin:$PATH"

		if [ -x "$cargo_bin" ]; then
			ensure_local_bin_on_path
			ln -sf "$cargo_bin" "$HOME/.local/bin/tree-sitter"
		fi
	}

	cleanup_incompatible_treesitter_parsers

	if [ -x "$cargo_tree_sitter" ] && tree_sitter_meets_minimum "$cargo_tree_sitter"; then
		ensure_tree_sitter_on_path "$cargo_tree_sitter"
		echo -e "${BOLD}${YELLOW} tree-sitter CLI ${min_tree_sitter_version}+ is already installed via cargo.${RESET}"
		return 0
	fi
	if [ -x "$cargo_tree_sitter" ] && ! tree_sitter_meets_minimum "$cargo_tree_sitter"; then
		remove_local_tree_sitter_binary "$cargo_tree_sitter"
	fi

	if command -v tree-sitter >/dev/null 2>&1; then
		local current_tree_sitter
		current_tree_sitter="$(command -v tree-sitter)"
		if tree_sitter_meets_minimum "$current_tree_sitter"; then
			echo -e "${BOLD}${YELLOW} tree-sitter CLI ${min_tree_sitter_version}+ is already installed.${RESET}"
			return 0
		fi
		remove_local_tree_sitter_binary "$current_tree_sitter"
		echo -e "${BOLD}${YELLOW} Existing tree-sitter does not meet LazyVim requirement (>= ${min_tree_sitter_version}) or is not runnable.${RESET}"
	fi

	if can_use_apt && command -v apt-cache >/dev/null 2>&1 && apt-cache show tree-sitter-cli >/dev/null 2>&1; then
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

	if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
		if can_use_apt; then
			echo -e "${BOLD}${YELLOW}Rust toolchain missing; installing rustc/cargo via apt...${RESET}"
			install_packages rustc cargo
		else
			echo -e "${BOLD}${RED}Rust toolchain (cargo/rustc) is required but not installed, and sudo/root is unavailable.${RESET}"
			return 1
		fi
	fi

	if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
		echo -e "${BOLD}${RED}Failed to provide cargo/rustc required for tree-sitter build.${RESET}"
		return 1
	fi

	# Build from source with cargo to satisfy version requirements.
	echo -e "${BOLD}${YELLOW} Installing tree-sitter CLI via cargo...${RESET}"
	configure_local_cargo_build_env

	local c_compiler
	c_compiler="$(resolve_c_compiler || true)"
	if [ -z "$c_compiler" ] && can_use_apt; then
		echo -e "${BOLD}${YELLOW} C compiler missing; installing build-essential...${RESET}"
		install_packages build-essential
		c_compiler="$(resolve_c_compiler || true)"
	fi

	if [ -z "$c_compiler" ]; then
		echo -e "${BOLD}${RED}A C compiler (cc/gcc/clang) is required to build tree-sitter-cli in non-sudo mode.${RESET}"
		echo -e "${BOLD}${RED}Install build-essential (or clang), or provide tree-sitter ${min_tree_sitter_version}+ on PATH and rerun.${RESET}"
		return 1
	fi
	export CC="$c_compiler"

	if can_use_apt; then
		# bindgen requires libclang to be present when building from source
		install_packages "libclang-dev"
	elif ! has_libclang; then
		echo -e "${BOLD}${RED}libclang is required to build tree-sitter-cli, but it was not found and sudo/root is unavailable.${RESET}"
		return 1
	fi

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
		configure_local_cargo_build_env
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

	touch ~/.bashrc
	# Clear only the exact managed flag to keep setup idempotent.
	sed -i '/^export ENABLE_COPILOT=1$/d' ~/.bashrc

	if [ "$use_copilot" = true ]; then
		echo "$copilot_flag" >>~/.bashrc
		echo -e "${BOLD}${YELLOW} Copilot support enabled for Neovim.${RESET}"
	else
		echo -e "${BOLD}${YELLOW} Copilot support disabled for Neovim.${RESET}"
	fi
}

# Install the neovim text editor
install_neovim() {
	local use_copilot="$1"

	if command -v nvim >/dev/null 2>&1; then
		echo -e "${BOLD}${YELLOW}Neovim already installed at $(command -v nvim).${RESET}"
	elif can_use_apt; then
		# Since neovim's package is not the newest in the ubuntu repository, use the unstable PPA.
		echo -e "${BOLD}${YELLOW}Adding the neovim PPA to the system...${RESET}"

		install_packages "software-properties-common"

		if ! grep -Rq "ppa.launchpadcontent.net/neovim-ppa/unstable" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
			$SUDO add-apt-repository -y ppa:neovim-ppa/unstable
		fi
		$SUDO apt-get update

		echo -e "${BOLD}${YELLOW}Installing neovim text editor...${RESET}"
		$SUDO apt-get install -y neovim
	else
		install_neovim_prebuilt
	fi

	configure_copilot_flag "$use_copilot"

	if [ "$use_copilot" = true ]; then
		install_nvm_and_node
	fi

	ensure_npm_for_mason
	install_tree_sitter_cli

	echo -e "${BOLD}${GREEN}Neovim installed successfully.${RESET}"
}
