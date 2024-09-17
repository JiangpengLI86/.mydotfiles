# Install the tmux terminal multiplexer
install_tmux() {
	echo -e "{$BOLD}{$YELLOW}Installing tmux...${RESET}"
	apt-get install -y tmux
	echo -e "{$BOLD}{$GREEN}tmux successfully installed.${RESET}"
}
