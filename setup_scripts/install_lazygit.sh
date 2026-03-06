# Install lazygit from the official GitHub binary release.

LAZYGIT_BLOCK_START="# >>> mydotfiles lazygit block >>>"
LAZYGIT_BLOCK_END="# <<< mydotfiles lazygit block <<<"

lazygit_download_arch() {
	local arch
	arch="$(uname -m)"

	case "$arch" in
	x86_64 | amd64)
		echo "linux_x86_64"
		;;
	aarch64 | arm64)
		echo "linux_arm64"
		;;
	armv7l)
		echo "linux_armv6"
		;;
	i386 | i686)
		echo "linux_32-bit"
		;;
	*)
		echo -e "${BOLD}${RED}Unsupported architecture for lazygit installer: ${arch}${RESET}" >&2
		return 1
		;;
	esac
}

configure_lazygit_shell_shortcut() {
	local bashrc_path="$HOME/.bashrc"
	local lazygit_bin='$HOME/.local/bin/lazygit'
	local tmp_file

	if ! touch "$bashrc_path"; then
		echo -e "${BOLD}${RED}Unable to access ${bashrc_path} for lazygit shortcut configuration.${RESET}" >&2
		return 1
	fi

	if [ ! -w "$bashrc_path" ]; then
		echo -e "${BOLD}${RED}${bashrc_path} is not writable; cannot configure lazygit shortcut.${RESET}" >&2
		return 1
	fi

	if grep -qF "$LAZYGIT_BLOCK_START" "$bashrc_path"; then
		echo -e "${BOLD}${YELLOW}Updating lazygit shortcut block in bashrc...${RESET}"
		tmp_file="$(mktemp "${TMPDIR:-/tmp}/bashrc.lazygit.XXXXXX")"
		awk -v start="$LAZYGIT_BLOCK_START" -v end="$LAZYGIT_BLOCK_END" '
			index($0, start) { skip = 1; next }
			index($0, end)   { skip = 0; next }
			!skip            { print }
		' "$bashrc_path" >"$tmp_file" || {
			rm -f "$tmp_file"
			return 1
		}
		mv "$tmp_file" "$bashrc_path" || return 1
	else
		echo -e "${BOLD}${YELLOW}Adding lazygit shortcut block to bashrc...${RESET}"
	fi

	cat >>"$bashrc_path" <<EOF
$LAZYGIT_BLOCK_START
alias lg="$lazygit_bin"
$LAZYGIT_BLOCK_END
EOF

	echo -e "${BOLD}${GREEN}lazygit shortcut block is configured in bashrc.${RESET}"
	return 0
}

install_lazygit() {
	local lazygit_arch
	local download_url
	local archive_path
	local tmp_dir
	local extracted_lazygit_path
	local target_lazygit_path="$HOME/.local/bin/lazygit"
	local existing_lazygit_path
	local installed_version

	echo -e "${BOLD}${YELLOW}Installing lazygit...${RESET}"

	if ! require_commands curl tar install uname mktemp grep sed head; then
		echo -e "${BOLD}${RED}Missing essential tools for lazygit install.${RESET}" >&2
		return 1
	fi

	lazygit_arch="$(lazygit_download_arch)" || return 1
	download_url="$(github_latest_asset_url "jesseduffield/lazygit" "lazygit_.*_${lazygit_arch}\\.tar\\.gz$" || true)"
	if [ -z "$download_url" ]; then
		echo -e "${BOLD}${RED}Unable to resolve latest lazygit download URL.${RESET}" >&2
		return 1
	fi

	archive_path="$(mktemp "${TMPDIR:-/tmp}/lazygit.XXXXXX.tar.gz")"
	tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lazygit.XXXXXX")"
	trap 'rm -rf "$tmp_dir" "$archive_path"' RETURN

	echo -e "${BOLD}${YELLOW}Downloading latest lazygit from ${download_url}${RESET}"
	curl -fL "$download_url" -o "$archive_path"

	tar -xzf "$archive_path" -C "$tmp_dir" lazygit
	extracted_lazygit_path="$tmp_dir/lazygit"
	if [ ! -f "$extracted_lazygit_path" ]; then
		echo -e "${BOLD}${RED}Downloaded lazygit archive did not contain the expected lazygit binary.${RESET}" >&2
		return 1
	fi

	ensure_local_bin_on_path
	existing_lazygit_path="$(command -v lazygit 2>/dev/null || true)"
	if [ -n "$existing_lazygit_path" ]; then
		echo -e "${BOLD}${YELLOW}Existing lazygit detected at ${existing_lazygit_path}; overwriting managed binary at ${target_lazygit_path}.${RESET}"
	fi
	install -m 0755 "$extracted_lazygit_path" "$target_lazygit_path"

	configure_lazygit_shell_shortcut || return 1

	installed_version="$("$target_lazygit_path" --version 2>/dev/null | head -n1 || true)"
	if [ -n "$installed_version" ]; then
		echo -e "${BOLD}${GREEN}${installed_version} installed at ${target_lazygit_path}.${RESET}"
	else
		echo -e "${BOLD}${GREEN}lazygit installed at ${target_lazygit_path}.${RESET}"
	fi
}
