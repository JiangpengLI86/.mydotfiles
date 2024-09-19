source ./setup_scripts/install_basic_packages.sh # For is_installed and install_package functions

yazi_shell_wrapper=$(cat << 'EOF'
    function yy() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
EOF
)

# Install the terminal file manager yazi
install_yazi() {
	echo -e "${BOLD}${YELLOW}Installing yazi...${RESET}"

	dependencies=("file" "fd-find" "ripgrep" "fzf")

	install_packages "${dependencies[@]}"

	wait

	# Build yazi from source ================================================

	# Download the rust setup script
	curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	# -s: Tells sh to read from standard input (the script downloaded by curl).
	# --: This is a separator that tells sh that what follows are arguments to be passed to the script being executed, not options for sh itself.
	# -y: This is an option passed to rust setup script to accept all default options automatically.

	wait

	# Ensure that the `rustup` binary is available in the current shell
	source $HOME/.cargo/env

	rm -rf ~/yazi
	$SUDO rm -rf /opt/yazi

	# Clone the yazi repository and build it
	git clone https://github.com/sxyazi/yazi.git ~/yazi

	wait 

	cargo build --release --locked --manifest-path ~/yazi/Cargo.toml

	wait

	$SUDO mv $HOME/yazi /opt/yazi

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
