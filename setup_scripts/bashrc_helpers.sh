MYDOTFILES_BASHRC_MANAGED_START="# >>> mydotfiles managed blocks >>>"
MYDOTFILES_BASHRC_MANAGED_END="# <<< mydotfiles managed blocks <<<"

ensure_bashrc_editable() {
	local bashrc_path="$1"
	local purpose="$2"

	if ! touch "$bashrc_path"; then
		echo -e "${BOLD}${RED}Unable to access ${bashrc_path} for ${purpose}.${RESET}" >&2
		return 1
	fi

	if [ ! -w "$bashrc_path" ]; then
		echo -e "${BOLD}${RED}${bashrc_path} is not writable; cannot configure ${purpose}.${RESET}" >&2
		return 1
	fi
}

strip_managed_block_from_file() {
	local input_file="$1"
	local start_marker="$2"
	local end_marker="$3"
	local output_file="$4"

	awk -v start="$start_marker" -v end="$end_marker" '
		index($0, start) { in_block = 1; next }
		index($0, end) { in_block = 0; next }
		!in_block { print }
	' "$input_file" >"$output_file"
}

trim_trailing_blank_lines_from_file() {
	local input_file="$1"
	local output_file="$2"

	awk '
		{
			lines[NR] = $0
		}
		END {
			last = 0
			for (i = NR; i >= 1; i--) {
				if (lines[i] !~ /^[[:space:]]*$/) {
					last = i
					break
				}
			}
			for (i = 1; i <= last; i++) {
				print lines[i]
			}
		}
	' "$input_file" >"$output_file"
}

trim_surrounding_blank_lines_from_file() {
	local input_file="$1"
	local output_file="$2"

	awk '
		{
			lines[NR] = $0
		}
		END {
			first = 0
			last = 0
			for (i = 1; i <= NR; i++) {
				if (lines[i] !~ /^[[:space:]]*$/) {
					first = i
					break
				}
			}
			for (i = NR; i >= 1; i--) {
				if (lines[i] !~ /^[[:space:]]*$/) {
					last = i
					break
				}
			}
			if (first == 0 || last == 0) {
				exit
			}
			for (i = first; i <= last; i++) {
				print lines[i]
			}
		}
	' "$input_file" >"$output_file"
}

upsert_mydotfiles_bashrc_block() {
	local bashrc_path="$1"
	local block_start="$2"
	local block_end="$3"
	local block_content="$4"
	local purpose="$5"
	local action="Adding"
	local tmp_dir
	local prefix_file
	local outer_body_file
	local suffix_file
	local prefix_clean_file
	local outer_body_clean_file
	local suffix_clean_file
	local final_file

	ensure_bashrc_editable "$bashrc_path" "$purpose" || return 1

	if grep -qF "$block_start" "$bashrc_path" 2>/dev/null; then
		action="Updating"
	fi
	echo -e "${BOLD}${YELLOW}${action} ${purpose} in bashrc...${RESET}"

	tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bashrc.mydotfiles.XXXXXX")" || return 1
	prefix_file="$tmp_dir/prefix"
	outer_body_file="$tmp_dir/outer_body"
	suffix_file="$tmp_dir/suffix"
	prefix_clean_file="$tmp_dir/prefix.clean"
	outer_body_clean_file="$tmp_dir/outer_body.clean"
	suffix_clean_file="$tmp_dir/suffix.clean"
	final_file="$tmp_dir/bashrc"
	: >"$prefix_file"
	: >"$outer_body_file"
	: >"$suffix_file"

	if grep -qF "$MYDOTFILES_BASHRC_MANAGED_START" "$bashrc_path" 2>/dev/null; then
		awk -v start="$MYDOTFILES_BASHRC_MANAGED_START" -v end="$MYDOTFILES_BASHRC_MANAGED_END" \
			-v prefix="$prefix_file" -v body="$outer_body_file" -v suffix="$suffix_file" '
			$0 == start { section = "body"; next }
			$0 == end { section = "suffix"; next }
			section == "" { print > prefix; next }
			section == "body" { print > body; next }
			{ print > suffix }
		' "$bashrc_path"
	else
		cat "$bashrc_path" >"$prefix_file"
		: >"$outer_body_file"
		: >"$suffix_file"
	fi

	strip_managed_block_from_file "$prefix_file" "$block_start" "$block_end" "$prefix_clean_file" || {
		rm -rf "$tmp_dir"
		return 1
	}
	strip_managed_block_from_file "$outer_body_file" "$block_start" "$block_end" "$outer_body_clean_file" || {
		rm -rf "$tmp_dir"
		return 1
	}
	strip_managed_block_from_file "$suffix_file" "$block_start" "$block_end" "$suffix_clean_file" || {
		rm -rf "$tmp_dir"
		return 1
	}
	trim_trailing_blank_lines_from_file "$prefix_clean_file" "$tmp_dir/prefix.trimmed" || {
		rm -rf "$tmp_dir"
		return 1
	}
	mv "$tmp_dir/prefix.trimmed" "$prefix_clean_file"
	trim_surrounding_blank_lines_from_file "$outer_body_clean_file" "$tmp_dir/outer_body.trimmed" || {
		rm -rf "$tmp_dir"
		return 1
	}
	mv "$tmp_dir/outer_body.trimmed" "$outer_body_clean_file"

	{
		cat "$prefix_clean_file"
		if [ -s "$prefix_clean_file" ] && [ -s "$outer_body_clean_file" ]; then
			printf '\n'
		fi
		printf '%s\n' "$MYDOTFILES_BASHRC_MANAGED_START"
		if [ -s "$outer_body_clean_file" ]; then
			cat "$outer_body_clean_file"
			printf '\n'
		fi
		printf '%s\n' "$block_content"
		printf '%s\n' "$MYDOTFILES_BASHRC_MANAGED_END"
		if [ -s "$suffix_clean_file" ]; then
			printf '\n'
			cat "$suffix_clean_file"
		fi
	} >"$final_file" || {
		rm -rf "$tmp_dir"
		return 1
	}

	mv "$final_file" "$bashrc_path" || {
		rm -rf "$tmp_dir"
		return 1
	}

	rm -rf "$tmp_dir"
	return 0
}
