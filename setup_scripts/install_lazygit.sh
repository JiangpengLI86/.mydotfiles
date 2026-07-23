# Install lazygit from the official GitHub binary release.

lazygit_download_arch() {
	local arch
	arch="$(uname -m)"

	case "$arch" in
	x86_64 | amd64)
		echo "linux_x86_64"
		;;
	aarch64 | arm64)
		echo "linux_arm64"
		;;
	armv7l)
		echo "linux_armv6"
		;;
	i386 | i686)
		echo "linux_32-bit"
		;;
	*)
		echo -e "${BOLD}${RED}Unsupported architecture for lazygit installer: ${arch}${RESET}" >&2
		return 1
		;;
	esac
}

install_lazygit() {
	local lazygit_arch
	local download_url
	local checksum_url
	local checksum_file
	local archive_name
	local expected_checksum
	local actual_checksum
	local archive_path
	local tmp_dir
	local extracted_lazygit_path
	local target_lazygit_path="$HOME/.local/bin/lazygit"
	local install_tmp_path
	local existing_lazygit_path
	local installed_version

	echo -e "${BOLD}${YELLOW}Installing lazygit...${RESET}"

	if ! require_commands curl tar install uname mktemp grep head sha256sum awk mv; then
		echo -e "${BOLD}${RED}Missing essential tools for lazygit install.${RESET}" >&2
		return 1
	fi

	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		echo -e "${BOLD}${YELLOW}Warning: setup is running as root. For safety, prefer running setup.sh as a regular user.${RESET}"
		echo -e "${BOLD}${YELLOW}If running as root intentionally (for example in Docker), ensure \$HOME/.local/bin is trusted.${RESET}"
	fi

	lazygit_arch="$(lazygit_download_arch)" || return 1
	download_url="$(github_latest_asset_url "jesseduffield/lazygit" "lazygit_.*_${lazygit_arch}\\.tar\\.gz$" || true)"
	if [ -z "$download_url" ]; then
		echo -e "${BOLD}${RED}Unable to resolve latest lazygit download URL.${RESET}" >&2
		return 1
	fi
	checksum_url="${download_url%/*}/checksums.txt"
	archive_name="${download_url##*/}"

	archive_path="$(mktemp "${TMPDIR:-/tmp}/lazygit.XXXXXX.tar.gz")"
	tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lazygit.XXXXXX")"
	checksum_file="$(mktemp "${TMPDIR:-/tmp}/lazygit-checksums.XXXXXX.txt")"
	trap 'rm -rf "$tmp_dir" "$archive_path" "$checksum_file" "$install_tmp_path"' RETURN

	echo -e "${BOLD}${YELLOW}Downloading latest lazygit from ${download_url}${RESET}"
	curl -fL "$download_url" -o "$archive_path"

	echo -e "${BOLD}${YELLOW}Verifying lazygit archive checksum...${RESET}"
	curl -fL "$checksum_url" -o "$checksum_file"
	expected_checksum="$(awk -v filename="$archive_name" '$NF == filename { print $1; exit }' "$checksum_file")"
	if [ -z "$expected_checksum" ]; then
		echo -e "${BOLD}${RED}Failed to find checksum for ${archive_name} in upstream checksums.txt.${RESET}" >&2
		return 1
	fi
	actual_checksum="$(sha256sum "$archive_path" | awk '{print $1}')"
	if [ "$actual_checksum" != "$expected_checksum" ]; then
		echo -e "${BOLD}${RED}Checksum verification failed for downloaded lazygit archive.${RESET}" >&2
		return 1
	fi

	tar -xzf "$archive_path" -C "$tmp_dir" lazygit
	extracted_lazygit_path="$tmp_dir/lazygit"
	if [ ! -f "$extracted_lazygit_path" ]; then
		echo -e "${BOLD}${RED}Downloaded lazygit archive did not contain the expected lazygit binary.${RESET}" >&2
		return 1
	fi

	ensure_local_bin_on_path
	existing_lazygit_path="$(command -v lazygit 2>/dev/null || true)"
	if [ -n "$existing_lazygit_path" ]; then
		echo -e "${BOLD}${YELLOW}Existing lazygit detected at ${existing_lazygit_path}; overwriting managed binary at ${target_lazygit_path}.${RESET}"
	fi
	# Install to a temporary file in the destination directory, then atomically
	# replace the target path. This avoids following a pre-existing symlink.
	install_tmp_path="$(mktemp "${HOME}/.local/bin/.lazygit.XXXXXX")"
	install -m 0755 "$extracted_lazygit_path" "$install_tmp_path"
	mv -fT "$install_tmp_path" "$target_lazygit_path"

	installed_version="$("$target_lazygit_path" --version 2>/dev/null | head -n1 || true)"
	if [ -n "$installed_version" ]; then
		echo -e "${BOLD}${GREEN}${installed_version} installed at ${target_lazygit_path}.${RESET}"
	else
		echo -e "${BOLD}${GREEN}lazygit installed at ${target_lazygit_path}.${RESET}"
	fi
}
