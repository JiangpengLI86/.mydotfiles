# Add some additional configuration to the .bashrc file
config_bashrc() {

	# Re-define the PS1 prompt for better shell readability ====================
	echo -e "${BOLD}${YELLOW} Re-defining the PS1 prompt for better shell readability ...${RESET}"

	local new_ps1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\e[38;5;195m\]\w\n\[\033[00m\]\$ '
	echo "PS1='${new_ps1}'" >>~/.bashrc

	echo -e "${BOLD}${GREEN} PS1 prompt re-defined successfully.${RESET}"

	# Configure the shell to use vi mode ==========================================
	echo -e "${BOLD}${YELLOW} Configuring the shell to use vi mode ...${RESET}"
	echo "set -o vi" >>~/.bashrc
	echo -e "${BOLD}${GREEN} Shell configured to use vi mode successfully.${RESET}"

	# Configure the shell to use gpg keys ========================================
	echo -e "${BOLD}${YELLOW} Configuring the shell to use gpg keys ...${RESET}"
	echo "export GPG_TTY=$(tty)" >>~/.bashrc
	echo -e "${BOLD}${GREEN} Shell configured to use gpg keys successfully.${RESET}"

	# Configure the shell to start SSH agnet =====================================
	echo -e "${BOLD}${YELLOW} Configuring the shell to start SSH agent ...${RESET}"

	local command='
    if ! pgrep -u $USER ssh-agent > /dev/null; then
        eval "$(ssh-agent -s)"
    fi
    '
	echo "${command}" >>~/.bashrc

	echo -e "${BOLD}${GREEN} Shell configured to start SSH agent successfully.${RESET}"

	source ~/.bashrc
	echo -e "${BOLD}${GREEN} Configuration of the .bashrc file completed successfully.${RESET}"
}
