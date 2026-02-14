# Add some additional configuration to the .bashrc file
config_bashrc() {
	local bashrc="$HOME/.bashrc"
	local start_marker="# >>> mydotfiles managed block >>>"
	local end_marker="# <<< mydotfiles managed block <<<"

	echo -e "${BOLD}${YELLOW} Updating managed .bashrc settings ...${RESET}"

	local new_ps1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\e[38;5;195m\]\w\n\[\033[00m\]\$ '
	local tmp_file
	tmp_file="$(mktemp)"

	# Replace the previous managed block if it exists.
	if grep -qF "$start_marker" "$bashrc" 2>/dev/null; then
		awk -v start="$start_marker" -v end="$end_marker" '
			$0 == start { in_block = 1; next }
			$0 == end { in_block = 0; next }
			!in_block { print }
		' "$bashrc" >"$tmp_file"
		mv "$tmp_file" "$bashrc"
	else
		rm -f "$tmp_file"
	fi

	cat >>"$bashrc" <<EOF

$start_marker
PS1='${new_ps1}'
set -o vi
export GPG_TTY=\$(tty)
if ! ssh-add -l &>/dev/null; then
    eval "\$(ssh-agent -s)"
fi
$end_marker
EOF

	echo -e "${BOLD}${GREEN} Configuration of the .bashrc file completed successfully.${RESET}"
}
