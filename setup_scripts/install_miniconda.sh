install_miniconda() {
	local miniconda_home="$HOME/miniconda3"
	local conda_bin=""
	local installer_path
	local installer_url
	local arch
	local resolved_conda

	# Prefer explicit conda executable from environment/PATH before defaulting to ~/miniconda3.
	if [ -n "${CONDA_EXE:-}" ] && [ -x "${CONDA_EXE}" ]; then
		conda_bin="${CONDA_EXE}"
	else
		resolved_conda="$(command -v conda 2>/dev/null || true)"
		if [ -n "$resolved_conda" ] && [[ "$resolved_conda" == */* ]] && [ -x "$resolved_conda" ]; then
			conda_bin="$resolved_conda"
		elif [ -x "$miniconda_home/bin/conda" ]; then
			conda_bin="$miniconda_home/bin/conda"
		fi
	fi

	echo -e "${BOLD}${YELLOW}Ensuring Miniconda is installed...${RESET}"

	if [ -n "$conda_bin" ] && [ -x "$conda_bin" ]; then
		echo -e "${BOLD}${YELLOW}Existing conda detected at ${conda_bin}.${RESET}"
	else
		arch="$(uname -m)"
		case "$arch" in
		x86_64 | amd64)
			installer_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
			;;
		aarch64 | arm64)
			installer_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"
			;;
		*)
			echo -e "${BOLD}${RED}Unsupported architecture for Miniconda installer: ${arch}${RESET}"
			return 1
			;;
		esac

		installer_path="$(mktemp /tmp/miniconda-installer.XXXXXX.sh)"
		echo -e "${BOLD}${YELLOW}Downloading Miniconda installer...${RESET}"
		curl -fsSL "$installer_url" -o "$installer_path"

		echo -e "${BOLD}${YELLOW}Installing Miniconda to ${miniconda_home}...${RESET}"
		bash "$installer_path" -b -p "$miniconda_home"
		rm -f "$installer_path"
		conda_bin="$miniconda_home/bin/conda"
	fi

	link_local_bin "$conda_bin" conda

	echo -e "${BOLD}${YELLOW}Upgrading conda to the latest version in base...${RESET}"
	if "$conda_bin" update -n base -c defaults conda -y; then
		echo -e "${BOLD}${GREEN}Conda upgraded successfully.${RESET}"
	else
		echo -e "${BOLD}${YELLOW}Conda upgrade failed; continuing setup with existing conda.${RESET}"
	fi

	echo -e "${BOLD}${GREEN}Miniconda is ready.${RESET}"
}
