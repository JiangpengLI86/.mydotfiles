# Install the VS Code CLI binary from official Microsoft download endpoints.

VSCODE_CLI_BLOCK_START="# >>> mydotfiles vscode cli block >>>"
VSCODE_CLI_BLOCK_END="# <<< mydotfiles vscode cli block <<<"

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

configure_vscode_cli_shell_shortcut() {
	local bashrc_path="$HOME/.bashrc"
	local cli_bin_dir="$HOME/.local/opt/vscode-cli/bin"
	local tmp_file

	if ! touch "$bashrc_path"; then
		echo -e "${BOLD}${RED}Unable to access ${bashrc_path} for VS Code CLI shortcut configuration.${RESET}" >&2
		return 1
	fi

	if [ ! -w "$bashrc_path" ]; then
		echo -e "${BOLD}${RED}${bashrc_path} is not writable; cannot configure VS Code CLI shortcut.${RESET}" >&2
		return 1
	fi

	if grep -qF "$VSCODE_CLI_BLOCK_START" "$bashrc_path"; then
		echo -e "${BOLD}${YELLOW}Updating VS Code CLI shortcut block in bashrc...${RESET}"
		tmp_file="$(mktemp "${TMPDIR:-/tmp}/bashrc.vscode-cli.XXXXXX")"
		awk -v start="$VSCODE_CLI_BLOCK_START" -v end="$VSCODE_CLI_BLOCK_END" '
			index($0, start) { skip = 1; next }
			index($0, end)   { skip = 0; next }
			!skip            { print }
		' "$bashrc_path" >"$tmp_file" || {
			rm -f "$tmp_file"
			return 1
		}
		mv "$tmp_file" "$bashrc_path" || return 1
	else
		echo -e "${BOLD}${YELLOW}Adding VS Code CLI shortcut block to bashrc...${RESET}"
	fi

	cat >>"$bashrc_path" <<EOF

$VSCODE_CLI_BLOCK_START
# Prefer the mydotfiles-managed VS Code CLI over any system-provided code binary.
if [ -d "$cli_bin_dir" ]; then
	case ":\$PATH:" in
	*:"$cli_bin_dir":*) ;;
	*) export PATH="$cli_bin_dir:\$PATH" ;;
	esac
fi
alias code="$cli_bin_dir/code"
$VSCODE_CLI_BLOCK_END

EOF

	echo -e "${BOLD}${GREEN}VS Code CLI shortcut block is configured in bashrc.${RESET}"
	return 0
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

	system_code_path="$(command -v code 2>/dev/null || true)"

	# Ensure this setup shell resolves our managed code binary before any system one.
	case ":$PATH:" in
	*:"$cli_bin_dir":*) ;;
	*) export PATH="$cli_bin_dir:$PATH" ;;
	esac

	if [ -n "$system_code_path" ] && [ "$system_code_path" != "$cli_bin_dir/code" ]; then
		echo -e "${BOLD}${YELLOW}Detected system-level code at ${system_code_path}; preferring ${cli_bin_dir}/code.${RESET}"
	fi

	configure_vscode_cli_shell_shortcut || return 1

	installed_version="$("$cli_bin_dir/code" --version 2>/dev/null | head -n1 || true)"
	if [ -n "$installed_version" ]; then
		echo -e "${BOLD}${GREEN}VS Code CLI ${installed_version} installed at ${cli_bin_dir}/code.${RESET}"
	else
		echo -e "${BOLD}${GREEN}VS Code CLI installed at ${cli_bin_dir}/code.${RESET}"
	fi
}
