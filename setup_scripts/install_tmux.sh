source ./setup_scripts/install_basic_packages.sh # For helpers and install_packages functions

tmux_download_arch() {
	case "$(uname -m)" in
	x86_64 | amd64) echo "x86_64" ;;
	aarch64 | arm64) echo "arm64" ;;
	*)
		echo -e "${BOLD}${YELLOW}No tmux prebuilt configured for architecture $(uname -m).${RESET}" >&2
		return 1
		;;
	esac
}

install_tmux_prebuilt() (
	local arch
	local asset_url
	local archive
	local extract_dir
	local extracted_tmux

	arch="$(tmux_download_arch)" || return 1
	require_commands curl tar install mktemp || return 1
	asset_url="$(github_latest_asset_url "tmux/tmux-builds" "/tmux-.*-linux-${arch}\\.tar\\.gz$" || true)"
	[ -n "$asset_url" ] || return 1

	archive="$(mktemp /tmp/tmux-prebuilt.XXXXXX.tar.gz)"
	extract_dir="$(mktemp -d /tmp/tmux-prebuilt.XXXXXX)"
	trap 'rm -rf "$archive" "$extract_dir"' EXIT
	echo -e "${BOLD}${YELLOW}Installing tmux from prebuilt static release...${RESET}"
	curl -fL "$asset_url" -o "$archive" || return 1
	tar -xzf "$archive" -C "$extract_dir" || return 1
	extracted_tmux="$(find "$extract_dir" -type f -name tmux -perm /111 | head -n1)"
	if [ -z "$extracted_tmux" ]; then
		echo -e "${BOLD}${RED}Downloaded tmux archive did not contain an executable.${RESET}" >&2
		return 1
	fi
	ensure_local_bin_on_path
	install -m 0755 "$extracted_tmux" "$HOME/.local/bin/tmux"
	"$HOME/.local/bin/tmux" -V >/dev/null
)

install_tmux_source_dependencies() {
	if ! can_use_apt; then
		echo -e "${BOLD}${RED}Tmux source fallback requires package-manager build dependencies.${RESET}" >&2
		return 1
	fi
	install_packages build-essential bison pkg-config libevent-dev libncurses-dev
	require_commands curl tar make cc bison pkg-config
	if ! pkg-config --exists libevent ncursesw; then
		echo -e "${BOLD}${RED}Tmux source dependencies are unavailable after package installation.${RESET}" >&2
		return 1
	fi
}

install_tmux_from_source() (
	local asset_url
	local archive
	local extract_dir
	local source_dir

	install_tmux_source_dependencies || return 1
	asset_url="$(github_latest_asset_url "tmux/tmux" "/tmux-[0-9A-Za-z._-]+\\.tar\\.gz$")"
	if [ -z "$asset_url" ]; then
		echo -e "${BOLD}${RED}Failed to resolve latest tmux source tarball URL from GitHub releases.${RESET}"
		return 1
	fi

	echo -e "${BOLD}${YELLOW}Building tmux from source...${RESET}"
	archive="$(mktemp /tmp/tmux-source.XXXXXX.tar.gz)"
	extract_dir="$(mktemp -d /tmp/tmux-source.XXXXXX)"
	trap 'rm -rf "$archive" "$extract_dir"' EXIT
	curl -fL "$asset_url" -o "$archive"
	tar -xzf "$archive" -C "$extract_dir"
	source_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
	if [ -z "$source_dir" ]; then
		echo -e "${BOLD}${RED}Failed to locate extracted tmux source directory.${RESET}"
		return 1
	fi

	(
		cd "$source_dir"
		./configure --prefix="$HOME/.local"
		make -j"$(nproc)"
		make install
	)

	"$HOME/.local/bin/tmux" -V >/dev/null
)

# Install the tmux terminal multiplexer
install_tmux() {
	local tmux_path

	echo -e "${BOLD}${YELLOW}Installing tmux...${RESET}"
	ensure_local_bin_on_path

	if command -v tmux >/dev/null 2>&1 && tmux -V >/dev/null 2>&1; then
		tmux_path="$(command -v tmux)"
		link_local_bin "$tmux_path" tmux
		echo -e "${BOLD}${YELLOW}tmux already installed at ${tmux_path}.${RESET}"
		return 0
	fi

	if ! install_tmux_prebuilt; then
		echo -e "${BOLD}${YELLOW}Falling back to a tmux source build...${RESET}"
		install_tmux_from_source
	fi

	echo -e "${BOLD}${GREEN}tmux successfully installed.${RESET}"
}
