install_uv() {
	local installer_path
	local uv_bin="$HOME/.local/bin/uv"
	local uvx_bin="$HOME/.local/bin/uvx"

	if [ -x "$uv_bin" ] && [ -x "$uvx_bin" ]; then
		echo -e "${BOLD}${YELLOW}uv is already installed at ${uv_bin}.${RESET}"
		return
	fi

	require_commands curl mktemp sh
	ensure_local_bin_on_path
	installer_path="$(mktemp /tmp/uv-installer.XXXXXX.sh)"
	trap 'rm -f "$installer_path"' RETURN
	curl --proto '=https' --tlsv1.2 -fsSL https://astral.sh/uv/install.sh -o "$installer_path"
	UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 sh "$installer_path"
	"$uv_bin" --version
	"$uvx_bin" --version
}
