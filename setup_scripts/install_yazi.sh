source ./setup_scripts/install_basic_packages.sh # For helpers and install_packages functions

YAZI_WRAPPER_START="# >>> yazi shell wrapper >>>"
YAZI_WRAPPER_END="# <<< yazi shell wrapper <<<"

yazi_shell_wrapper=$(
	cat <<'EOF'
    # >>> yazi shell wrapper >>>
    function yy() {
        local yazi_cmd
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        if command -v yazi >/dev/null 2>&1; then
            yazi_cmd="$(command -v yazi)"
        elif [ -x "$HOME/.local/bin/yazi" ]; then
            yazi_cmd="$HOME/.local/bin/yazi"
        elif [ -x "/opt/yazi/target/release/yazi" ]; then
            yazi_cmd="/opt/yazi/target/release/yazi"
        else
            echo "yy: yazi is not installed or not on PATH."
            rm -f -- "$tmp"
            return 127
        fi

        "$yazi_cmd" "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
    # <<< yazi shell wrapper <<<
EOF
)

resolve_yazi_bins() {
	local yazi_bin=""
	local ya_bin=""
	local yazi_from_path=""
	local ya_from_path=""
	local yazi_dir=""
	local ya_dir=""

	yazi_from_path="$(command -v yazi 2>/dev/null || true)"
	if [ -n "$yazi_from_path" ]; then
		yazi_dir="$(dirname "$yazi_from_path")"
		if [ -x "$yazi_dir/ya" ]; then
			yazi_bin="$yazi_from_path"
			ya_bin="$yazi_dir/ya"
		fi
	fi

	if [ -z "$yazi_bin" ] || [ -z "$ya_bin" ]; then
		ya_from_path="$(command -v ya 2>/dev/null || true)"
		if [ -n "$ya_from_path" ]; then
			ya_dir="$(dirname "$ya_from_path")"
			if [ -x "$ya_dir/yazi" ]; then
				yazi_bin="$ya_dir/yazi"
				ya_bin="$ya_from_path"
			fi
		fi
	fi

	if [ -z "$yazi_bin" ] || [ -z "$ya_bin" ]; then
		if [ -x "$HOME/.local/bin/yazi" ] && [ -x "$HOME/.local/bin/ya" ]; then
			yazi_bin="$HOME/.local/bin/yazi"
			ya_bin="$HOME/.local/bin/ya"
		fi
	fi

	if [ -z "$yazi_bin" ] || [ -z "$ya_bin" ]; then
		if [ -x "/opt/yazi/target/release/yazi" ] && [ -x "/opt/yazi/target/release/ya" ]; then
			yazi_bin="/opt/yazi/target/release/yazi"
			ya_bin="/opt/yazi/target/release/ya"
		fi
	fi

	if [ -z "$yazi_bin" ] || [ -z "$ya_bin" ]; then
		return 1
	fi

	if [ ! -x "$yazi_bin" ] || [ ! -x "$ya_bin" ]; then
		return 1
	fi

	echo "$yazi_bin|$ya_bin"
	return 0
}

yazi_binaries_usable() {
	local resolved_bins
	local yazi_bin
	local ya_bin

	resolved_bins="$(resolve_yazi_bins || true)"
	if [ -z "$resolved_bins" ]; then
		return 1
	fi
	yazi_bin="${resolved_bins%%|*}"
	ya_bin="${resolved_bins##*|}"

	"$yazi_bin" --version >/dev/null 2>&1 || return 1
	"$ya_bin" --help >/dev/null 2>&1 || "$ya_bin" --version >/dev/null 2>&1 || return 1
	return 0
}

ensure_yazi_commands_on_path() {
	local resolved_bins
	local yazi_bin
	local ya_bin

	ensure_local_bin_on_path

	resolved_bins="$(resolve_yazi_bins || true)"
	if [ -z "$resolved_bins" ]; then
		return 1
	fi
	yazi_bin="${resolved_bins%%|*}"
	ya_bin="${resolved_bins##*|}"

	if [ "$yazi_bin" != "$HOME/.local/bin/yazi" ]; then
		ln -sfn "$yazi_bin" "$HOME/.local/bin/yazi" || return 1
	fi
	if [ "$ya_bin" != "$HOME/.local/bin/ya" ]; then
		ln -sfn "$ya_bin" "$HOME/.local/bin/ya" || return 1
	fi
	return 0
}

install_yazi_prebuilt() {
	local arch
	local yazi_arch
	local asset_url
	local tmp_zip
	local tmp_extract_dir
	local yazi_bin
	local ya_bin

	arch="$(uname -m)"
	case "$arch" in
	x86_64 | amd64)
		yazi_arch="x86_64"
		;;
	aarch64 | arm64)
		yazi_arch="aarch64"
		;;
	*)
		echo -e "${BOLD}${YELLOW}No official yazi prebuilt target configured for architecture ${arch}.${RESET}"
		return 1
		;;
	esac

	require_commands curl unzip || return 1

	# Prefer musl assets for broader runtime compatibility across Ubuntu releases.
	asset_url="$(github_latest_asset_url "sxyazi/yazi" "/yazi-${yazi_arch}-unknown-linux-musl\\.zip$")"
	if [ -z "$asset_url" ]; then
		asset_url="$(github_latest_asset_url "sxyazi/yazi" "/yazi-${yazi_arch}-unknown-linux-gnu\\.zip$")"
	fi
	if [ -z "$asset_url" ]; then
		echo -e "${BOLD}${YELLOW}Could not resolve a matching yazi prebuilt asset from latest release.${RESET}"
		return 1
	fi

	echo -e "${BOLD}${YELLOW}Installing yazi from prebuilt release (${yazi_arch})...${RESET}"
	tmp_zip="$(mktemp /tmp/yazi.XXXXXX.zip)"
	tmp_extract_dir="$(mktemp -d /tmp/yazi-extract.XXXXXX)"
	curl -fL "$asset_url" -o "$tmp_zip"
	unzip -q "$tmp_zip" -d "$tmp_extract_dir"
	rm -f "$tmp_zip"

	yazi_bin="$(find "$tmp_extract_dir" -type f -name yazi -perm /111 | head -n1)"
	ya_bin="$(find "$tmp_extract_dir" -type f -name ya -perm /111 | head -n1)"
	if [ -z "$yazi_bin" ] || [ -z "$ya_bin" ]; then
		rm -rf "$tmp_extract_dir"
		echo -e "${BOLD}${RED}Failed to locate yazi/ya binaries in downloaded archive.${RESET}"
		return 1
	fi

	ensure_local_bin_on_path
	install -m 0755 "$yazi_bin" "$HOME/.local/bin/yazi"
	install -m 0755 "$ya_bin" "$HOME/.local/bin/ya"
	rm -rf "$tmp_extract_dir"

	if ! "$HOME/.local/bin/yazi" --version >/dev/null 2>&1 || ! ("$HOME/.local/bin/ya" --help >/dev/null 2>&1 || "$HOME/.local/bin/ya" --version >/dev/null 2>&1); then
		echo -e "${BOLD}${YELLOW}Installed yazi prebuilt binary is not runnable in this environment; falling back to source build.${RESET}"
		return 1
	fi

	return 0
}

ensure_yazi_source_prereqs() {
	if command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1; then
		return 0
	fi

	if can_use_apt; then
		echo -e "${BOLD}${YELLOW}Rust toolchain missing; installing rustc/cargo via apt...${RESET}"
		install_packages rustc cargo
	fi

	if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
		echo -e "${BOLD}${RED}Rust toolchain (cargo/rustc) is required for source-built yazi, and it is not available.${RESET}"
		echo -e "${BOLD}${RED}Without sudo/root, install Rust first or use a supported prebuilt release.${RESET}"
		return 1
	fi

	return 0
}

install_yazi_from_source() {
	local yazi_src_dir="$HOME/.local/src/yazi"
	local yazi_repo="https://github.com/sxyazi/yazi.git"
	local default_branch
	local local_head
	local remote_head

	require_commands git cargo rustc || return 1
	ensure_local_bin_on_path
	mkdir -p "$HOME/.local/src"

	# Keep a local clone to avoid rebuilding on every rerun.
	if [ ! -d "$yazi_src_dir/.git" ]; then
		rm -rf "$yazi_src_dir"
		git clone "$yazi_repo" "$yazi_src_dir"
	else
		git -C "$yazi_src_dir" fetch --quiet origin
	fi

	default_branch="$(git -C "$yazi_src_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
	if [ -z "$default_branch" ]; then
		default_branch="main"
	fi

	local_head="$(git -C "$yazi_src_dir" rev-parse HEAD)"
	remote_head="$(git -C "$yazi_src_dir" rev-parse "origin/${default_branch}")"

	if [ "$local_head" != "$remote_head" ]; then
		git -C "$yazi_src_dir" pull --ff-only
	fi

	# Avoid reusing target artifacts from a different libc/runtime.
	if [ -d "$yazi_src_dir/target" ]; then
		rm -rf "$yazi_src_dir/target"
	fi
	configure_local_cargo_build_env
	cargo build --release --locked --manifest-path "$yazi_src_dir/Cargo.toml"
	install -m 0755 "$yazi_src_dir/target/release/yazi" "$HOME/.local/bin/yazi"
	install -m 0755 "$yazi_src_dir/target/release/ya" "$HOME/.local/bin/ya"

	return 0
}

add_yazi_shell_wrapper() {
	local bashrc_path="$HOME/.bashrc"
	upsert_mydotfiles_bashrc_block "$bashrc_path" "$YAZI_WRAPPER_START" "$YAZI_WRAPPER_END" "$yazi_shell_wrapper" "yazi shell wrapper" || return 1
	echo -e "${BOLD}${GREEN}yazi shell wrapper is configured in bashrc.${RESET}"
	return 0
}

# Install the terminal file manager yazi
install_yazi() {
	echo -e "${BOLD}${YELLOW}Installing yazi...${RESET}"

	# Optional runtime tools used by yazi plugins and integration.
	install_packages file fd-find ripgrep fzf

	if yazi_binaries_usable; then
		ensure_yazi_commands_on_path
		echo -e "${BOLD}${YELLOW}yazi is already installed and runnable.${RESET}"
	else
		if command -v yazi >/dev/null 2>&1 || command -v ya >/dev/null 2>&1; then
			echo -e "${BOLD}${YELLOW}Existing yazi/ya binary is not runnable in this environment; reinstalling.${RESET}"
		fi
		if ! install_yazi_prebuilt; then
			echo -e "${BOLD}${YELLOW}Falling back to source build for yazi...${RESET}"
			ensure_yazi_source_prereqs
			install_yazi_from_source
		fi
	fi

	if ! yazi_binaries_usable; then
		echo -e "${BOLD}${RED}Failed to install a runnable yazi binary for this environment.${RESET}"
		return 1
	fi

	ensure_yazi_commands_on_path
	add_yazi_shell_wrapper
	echo -e "${BOLD}${GREEN}yazi installed successfully.${RESET}"
}
