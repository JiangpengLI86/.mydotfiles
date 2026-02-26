source ./setup_scripts/install_basic_packages.sh # For is_installed and install_package functions

YAZI_WRAPPER_START="# >>> yazi shell wrapper >>>"
YAZI_WRAPPER_END="# <<< yazi shell wrapper <<<"

yazi_shell_wrapper=$(cat << 'EOF'
    # >>> yazi shell wrapper >>>
    function yy() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
    # <<< yazi shell wrapper <<<
EOF
)

# Install the terminal file manager yazi
install_yazi() {
	echo -e "${BOLD}${YELLOW}Installing yazi...${RESET}"

	dependencies=("file" "fd-find" "ripgrep" "fzf")

	install_packages "${dependencies[@]}"

	# Build yazi from source ================================================
	local yazi_src_dir="$HOME/.local/src/yazi"
	local yazi_install_dir="/opt/yazi"
	local yazi_repo="https://github.com/sxyazi/yazi.git"

	# Install Rust only if missing.
	if [ -s "$HOME/.cargo/env" ]; then
		# Ensure cargo is on PATH if Rust was previously installed.
		source "$HOME/.cargo/env"
	fi
	if ! command -v cargo >/dev/null 2>&1; then
		curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	fi

	# Ensure that the `rustup` binary is available in the current shell
	source "$HOME/.cargo/env"

	# Keep a local clone to avoid rebuilding on every rerun.
	if [ ! -d "$yazi_src_dir/.git" ]; then
		rm -rf "$yazi_src_dir"
		git clone "$yazi_repo" "$yazi_src_dir"
	else
		git -C "$yazi_src_dir" fetch --quiet origin
	fi

	local default_branch
	default_branch="$(git -C "$yazi_src_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
	if [ -z "$default_branch" ]; then
		default_branch="main"
	fi

	local local_head remote_head
	local_head="$(git -C "$yazi_src_dir" rev-parse HEAD)"
	remote_head="$(git -C "$yazi_src_dir" rev-parse "origin/${default_branch}")"

	if [ "$local_head" = "$remote_head" ] && [ -x "$yazi_install_dir/target/release/yazi" ]; then
		echo -e "${BOLD}${GREEN}yazi is up to date. Skipping rebuild.${RESET}"
	else
		git -C "$yazi_src_dir" pull --ff-only
		cargo build --release --locked --manifest-path "$yazi_src_dir/Cargo.toml"

		$SUDO rm -rf "$yazi_install_dir"
		$SUDO cp -a "$yazi_src_dir" "$yazi_install_dir"
	fi

	# Modify bashrc to include yazi
	if ! grep -qF 'export PATH=$PATH:/opt/yazi/target/release' ~/.bashrc; then
		echo 'export PATH=$PATH:/opt/yazi/target/release' >>~/.bashrc
	fi

	# Add a shell wrapper fo yazi

	# Check whether the shell wrapper is already included in the bashrc
	if ! grep -qF "$YAZI_WRAPPER_START" ~/.bashrc; then
		# If the function yy() is not found, append it tothe .bashrc file.

		echo -e "${BOLD}${YELLOW}Adding yazi shell wrapper to bashrc...${RESET}"

		echo "" >>~/.bashrc # Append a new line first.
		echo "$yazi_shell_wrapper" >>~/.bashrc
		echo "" >>~/.bashrc # Append a new line last.

		echo -e "${BOLD}${GREEN}yazi shell wrapper added to bashrc.${RESET}"
	else
		echo -e "${BOLD}${RED}yazi shell wrapper already exists in bashrc.${RESET}"
	fi

	echo -e "${BOLD}${GREEN}yazi installed successfully.${RESET}"
}
