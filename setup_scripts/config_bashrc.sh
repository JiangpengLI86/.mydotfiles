config_bashrc() {
	local bashrc_path="${1:-$HOME/.bashrc}"
	local conda_ends
	local conda_starts
	local managed_ends
	local managed_starts
	local temp_path
	local previous_config_pattern

	touch "$bashrc_path"
	managed_starts="$(grep -Ec '^# >>> mydotfiles managed.* >>>$' "$bashrc_path" || true)"
	managed_ends="$(grep -Ec '^# <<< mydotfiles managed.* <<<$' "$bashrc_path" || true)"
	conda_starts="$(grep -Ec '^# >>> conda initialize >>>$' "$bashrc_path" || true)"
	conda_ends="$(grep -Ec '^# <<< conda initialize <<<$' "$bashrc_path" || true)"
	if [ "$managed_starts" -ne "$managed_ends" ] || [ "$conda_starts" -ne "$conda_ends" ]; then
		echo -e "${BOLD}${RED}Refusing to replace malformed managed blocks in ${bashrc_path}.${RESET}" >&2
		return 1
	fi

	previous_config_pattern='^# >>> (mydotfiles managed|conda initialize)|^export (PATH="\$HOME/(\.local/bin|\.cargo/bin|\.local/opt/vscode-cli/bin):\$PATH"|NVM_DIR=|ENABLE_COPILOT=)|mydotfiles/bashrc\.sh|\.cargo/env|NVM_DIR/(nvm\.sh|bash_completion)'
	if grep -Eq "$previous_config_pattern" "$bashrc_path"; then
		echo -e "${BOLD}${YELLOW}Removing previous managed shell configuration from ${bashrc_path}.${RESET}"
	fi

	temp_path="$(mktemp "${bashrc_path}.XXXXXX")"
	trap 'rm -f "$temp_path"' RETURN
	awk '
		/^# >>> mydotfiles managed/ { managed_depth++; next }
		/^# <<< mydotfiles managed/ { if (managed_depth) managed_depth--; next }
		managed_depth { next }
		/^# >>> conda initialize >>>$/ { conda_block = 1; next }
		/^# <<< conda initialize <<<$/{ conda_block = 0; next }
		conda_block { next }
		/^export PATH="\$HOME\/(\.local\/bin|\.cargo\/bin|\.local\/opt\/vscode-cli\/bin):\$PATH"$/ { next }
		/^export NVM_DIR=/ { next }
		/^export ENABLE_COPILOT=1$/ { next }
		/mydotfiles\/bashrc\.sh/ { next }
		/\.cargo\/env/ { next }
		/NVM_DIR\/(nvm\.sh|bash_completion)/ { next }
		/^$/ { trailing_blanks++; next }
		{
			for (i = 0; i < trailing_blanks; i++) print ""
			trailing_blanks = 0
			print
		}
		END {
			print ""
			print "# >>> mydotfiles managed shell setup >>>"
			print "if [ -f \"$HOME/.config/mydotfiles/bashrc.sh\" ]; then"
			print "\tsource \"$HOME/.config/mydotfiles/bashrc.sh\""
			print "fi"
			print "# <<< mydotfiles managed shell setup <<<"
		}
	' "$bashrc_path" >"$temp_path"
	chmod --reference="$bashrc_path" "$temp_path"
	mv "$temp_path" "$bashrc_path"
	trap - RETURN
	echo -e "${BOLD}${GREEN}Shell configuration is sourced from ~/.config/mydotfiles/bashrc.sh.${RESET}"
}
