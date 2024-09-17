source ./install_basic_packages.sh # For is_installed and install_package functions

local yazi_shell_wrapper =
"
    function yy() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
    "

# Install the terminal file manager yazi
install_yazi() {
	echo -e "${BOLD}${YELLOW}Installing yazi...${RESET}"

	dependencies=("file" "fd-find" "ripgrep" "fzf")

	install_packages "${dependencies[@]}"

	# Build yazi from source ================================================

	# Get the yazi setup script
	mkdir -p /opt/yazi/
	curl -o /opt/yazi/ --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
	rustup update

	# Clone the yazi repository and build it
	git clone https://github.com/sxyazi/yazi.git /opt/yazi/
	cargo build --release --locked --manifest-path /opt/yazi/Cargo.toml

	# Modify bashrc to include yazi
	echo "export PATH=\$PATH:/opt/yazi/target/release" >>~/.bashrc

	# Add a shell wrapper fo yazi

	# Check whether the shell wrapper is already included in the bashrc
	if ! grep -q "yazi-cwd" ~/.bashrc; then
		# If the function yy() is not found, append it tothe .bashrc file.

		echo -e "${BOLD}${YELLOW}Adding yazi shell wrapper to bashrc...${RESET}"

		echo "" >>~/.bashrc # Append a new line first.
		echo "$yazi_shell_wrapper" >>~/.bashrc
		echo "" >>~/.bashrc # Append a new line last.

		echo -e "${BOLD}${GREEN}yazi shell wrapper added to bashrc.${RESET}"
	else
		echo -e "${BOLD}${RED}yazi shell wrapper already exists in bashrc.${RESET}"
	fi

	source ~/.bashrc

	echo -e "${BOLD}${GREEN}yazi installed successfully.${RESET}"
}
