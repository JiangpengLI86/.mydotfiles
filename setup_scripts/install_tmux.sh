source ./setup_scripts/install_basic_packages.sh # For helpers and install_packages functions

has_yacc_or_bison() {
	command -v yacc >/dev/null 2>&1 || command -v bison >/dev/null 2>&1
}

tmux_build_local_ncurses() {
	local prefix="$HOME/.local"
	local src_root="$HOME/.local/src"
	local build_root="$HOME/.local/build"
	local version="6.5"
	local tarball="$build_root/ncurses-${version}.tar.gz"
	local source_dir="$src_root/ncurses-${version}"
	local url="https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${version}.tar.gz"

	if PKG_CONFIG_PATH="$prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" pkg-config --exists ncursesw; then
		return 0
	fi

	echo -e "${BOLD}${YELLOW}Building ncurses locally for tmux...${RESET}"
	mkdir -p "$src_root" "$build_root"
	curl -fL "$url" -o "$tarball"
	rm -rf "$source_dir"
	tar -xzf "$tarball" -C "$src_root"

	(
		cd "$source_dir"
		./configure --prefix="$prefix" --with-shared --with-termlib --enable-pc-files --with-pkg-config-libdir="$prefix/lib/pkgconfig"
		make -j"$(nproc)"
		make install
	)
}

tmux_build_local_libevent() {
	local prefix="$HOME/.local"
	local src_root="$HOME/.local/src"
	local build_root="$HOME/.local/build"
	local version="2.1.12-stable"
	local tarball="$build_root/libevent-${version}.tar.gz"
	local source_dir="$src_root/libevent-${version}"
	local url="https://github.com/libevent/libevent/releases/download/release-${version}/libevent-${version}.tar.gz"

	if PKG_CONFIG_PATH="$prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" pkg-config --exists libevent; then
		return 0
	fi

	echo -e "${BOLD}${YELLOW}Building libevent locally for tmux...${RESET}"
	mkdir -p "$src_root" "$build_root"
	curl -fL "$url" -o "$tarball"
	rm -rf "$source_dir"
	tar -xzf "$tarball" -C "$src_root"

	(
		cd "$source_dir"
		./configure --prefix="$prefix" --disable-openssl
		make -j"$(nproc)"
		make install
	)
}

install_tmux_from_source() {
	local prefix="$HOME/.local"
	local src_root="$HOME/.local/src"
	local build_root="$HOME/.local/build"
	local asset_url
	local tmux_tarball
	local tmux_extract_root
	local tmux_source_dir

	require_commands curl tar make cc pkg-config || {
		echo -e "${BOLD}${RED}Missing essential build tools for tmux source build.${RESET}"
		echo -e "${BOLD}${RED}Install build-essential, bison, and pkg-config (or rerun with sudo/root).${RESET}"
		return 1
	}

	if ! has_yacc_or_bison; then
		echo -e "${BOLD}${RED}tmux source build requires yacc (or bison), but neither was found.${RESET}"
		echo -e "${BOLD}${RED}Install bison (or a yacc implementation), then rerun setup.${RESET}"
		return 1
	fi

	mkdir -p "$prefix" "$src_root" "$build_root"
	ensure_local_bin_on_path

	tmux_build_local_ncurses
	tmux_build_local_libevent

	asset_url="$(github_latest_asset_url "tmux/tmux" "/tmux-[0-9A-Za-z._-]+\\.tar\\.gz$")"
	if [ -z "$asset_url" ]; then
		echo -e "${BOLD}${RED}Failed to resolve latest tmux source tarball URL from GitHub releases.${RESET}"
		return 1
	fi

	echo -e "${BOLD}${YELLOW}Building tmux from source...${RESET}"
	tmux_tarball="$(mktemp /tmp/tmux.XXXXXX.tar.gz)"
	tmux_extract_root="$(mktemp -d /tmp/tmux-src.XXXXXX)"
	curl -fL "$asset_url" -o "$tmux_tarball"
	tar -xzf "$tmux_tarball" -C "$tmux_extract_root"
	rm -f "$tmux_tarball"

	tmux_source_dir="$(find "$tmux_extract_root" -mindepth 1 -maxdepth 1 -type d | head -n1)"
	if [ -z "$tmux_source_dir" ]; then
		rm -rf "$tmux_extract_root"
		echo -e "${BOLD}${RED}Failed to locate extracted tmux source directory.${RESET}"
		return 1
	fi

	(
		cd "$tmux_source_dir"
		PKG_CONFIG_PATH="$prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
			CPPFLAGS="-I$prefix/include" \
			LDFLAGS="-Wl,-rpath,$prefix/lib -L$prefix/lib" \
			./configure --prefix="$prefix"
		make -j"$(nproc)"
		make install
	)

	rm -rf "$tmux_extract_root"

	if ! command -v tmux >/dev/null 2>&1; then
		echo -e "${BOLD}${RED}tmux installation completed but binary is not on PATH.${RESET}"
		return 1
	fi

	return 0
}

# Install the tmux terminal multiplexer
install_tmux() {
	echo -e "${BOLD}${YELLOW}Installing tmux...${RESET}"

	if command -v tmux >/dev/null 2>&1; then
		echo -e "${BOLD}${YELLOW}tmux already installed at $(command -v tmux).${RESET}"
		return 0
	fi

	if can_use_apt; then
		install_packages tmux
	else
		install_tmux_from_source
	fi

	echo -e "${BOLD}${GREEN}tmux successfully installed.${RESET}"
}
