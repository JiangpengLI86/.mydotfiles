# Install the VS Code CLI binary from official Microsoft download endpoints.

vscode_cli_download_os() {
	local arch
	arch="$(uname -m)"

	case "$arch" in
	x86_64 | amd64)
		echo "cli-alpine-x64"
		;;
	aarch64 | arm64)
		echo "cli-alpine-arm64"
		;;
	armv7l)
		echo "cli-linux-armhf"
		;;
	*)
		echo -e "${BOLD}${RED}Unsupported architecture for VS Code CLI installer: ${arch}${RESET}" >&2
		return 1
		;;
	esac
}

install_vscode_cli() {
	local cli_os
	local download_url
	local tmp_dir
	local archive_path
	local extracted_code_path
	local cli_root_dir="$HOME/.local/opt/vscode-cli"
	local cli_bin_dir="$cli_root_dir/bin"
	local system_code_path
	local installed_version

	echo -e "${BOLD}${YELLOW}Installing VS Code CLI...${RESET}"

	if ! require_commands curl tar install uname mktemp; then
		echo -e "${BOLD}${RED}Missing essential tools for VS Code CLI install.${RESET}" >&2
		return 1
	fi

	cli_os="$(vscode_cli_download_os)" || return 1
	download_url="https://code.visualstudio.com/sha/download?build=stable&os=${cli_os}"
	archive_path="$(mktemp "${TMPDIR:-/tmp}/vscode-cli.XXXXXX.tar.gz")"
	system_code_path="$(command -v code 2>/dev/null || true)"

	echo -e "${BOLD}${YELLOW}Downloading latest VS Code CLI binary from ${download_url}${RESET}"
	curl -fL "$download_url" -o "$archive_path"

	tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/vscode-cli.XXXXXX")"
	trap 'rm -rf "$tmp_dir" "$archive_path"' RETURN

	tar -xzf "$archive_path" -C "$tmp_dir"
	extracted_code_path="$tmp_dir/code"

	if [ ! -f "$extracted_code_path" ]; then
		echo -e "${BOLD}${RED}Downloaded VS Code CLI archive did not contain the expected code binary.${RESET}" >&2
		return 1
	fi

	mkdir -p "$cli_bin_dir"
	install -m 0755 "$extracted_code_path" "$cli_bin_dir/code"
	link_local_bin "$cli_bin_dir/code" code

	if [ -n "$system_code_path" ] && [ "$system_code_path" != "$HOME/.local/bin/code" ]; then
		echo -e "${BOLD}${YELLOW}Detected code at ${system_code_path}; preferring ~/.local/bin/code.${RESET}"
	fi

	installed_version="$("$cli_bin_dir/code" --version 2>/dev/null | head -n1 || true)"
	if [ -n "$installed_version" ]; then
		echo -e "${BOLD}${GREEN}VS Code CLI ${installed_version} installed at ${cli_bin_dir}/code.${RESET}"
	else
		echo -e "${BOLD}${GREEN}VS Code CLI installed at ${cli_bin_dir}/code.${RESET}"
	fi
}
