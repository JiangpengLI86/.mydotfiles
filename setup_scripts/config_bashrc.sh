# Add some additional configuration to the .bashrc file
config_bashrc() {
	local bashrc="$HOME/.bashrc"
	local start_marker="# >>> mydotfiles managed block >>>"
	local end_marker="# <<< mydotfiles managed block <<<"
	local block_content

	local new_ps1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\e[38;5;195m\]\w\n\[\033[00m\]\$ '
	block_content=$(cat <<EOF
$start_marker
PS1='${new_ps1}'
set -o vi
export GPG_TTY=\$(tty)
if ! ssh-add -l &>/dev/null; then
    eval "\$(ssh-agent -s)"
fi
$end_marker
EOF
)

	upsert_mydotfiles_bashrc_block "$bashrc" "$start_marker" "$end_marker" "$block_content" "managed .bashrc defaults" || return 1

	echo -e "${BOLD}${GREEN} Configuration of the .bashrc file completed successfully.${RESET}"
}
