config_bashrc() {
	local bashrc_path="${1:-$HOME/.bashrc}"
	touch "$bashrc_path"
	sed -i \
		-e '/^# >>> mydotfiles managed blocks >>>$/,/^# <<< mydotfiles managed blocks <<<$/d' \
		-e '/^export PATH="\$HOME\/\.local\/bin:\$PATH"$/d' \
		-e '/^export PATH="\$HOME\/\.cargo\/bin:\$PATH"$/d' \
		-e '/^export ENABLE_COPILOT=1$/d' \
		-e '/^source "\$HOME\/\.config\/mydotfiles\/bashrc\.sh"$/d' \
		"$bashrc_path"
	ensure_bashrc_line 'if [ -f "$HOME/.config/mydotfiles/bashrc.sh" ]; then source "$HOME/.config/mydotfiles/bashrc.sh"; fi' "$bashrc_path"
	echo -e "${BOLD}${GREEN}Shell configuration is sourced from ~/.config/mydotfiles/bashrc.sh.${RESET}"
}
