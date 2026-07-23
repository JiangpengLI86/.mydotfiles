# Managed command locations
for mydotfiles_bin_dir in \
	"$HOME/.local/bin" \
	"$HOME/.cargo/bin"; do
	case ":$PATH:" in
	*:"$mydotfiles_bin_dir":*) ;;
	*) PATH="$mydotfiles_bin_dir:$PATH" ;;
	esac
done
export PATH
unset mydotfiles_bin_dir

# Managed tool initialization
if [ -x "$HOME/.local/bin/conda" ]; then
	mydotfiles_conda_bin="$(readlink -f "$HOME/.local/bin/conda" 2>/dev/null || true)"
	case "$mydotfiles_conda_bin" in
	*/bin/conda)
		mydotfiles_conda_hook="${mydotfiles_conda_bin%/bin/conda}/etc/profile.d/conda.sh"
		[ -f "$mydotfiles_conda_hook" ] && . "$mydotfiles_conda_hook"
		;;
	esac
	unset mydotfiles_conda_bin mydotfiles_conda_hook
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# Interactive shell defaults
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\e[38;5;195m\]\w\n\[\033[00m\]\$ '
set -o vi
tty -s && export GPG_TTY="$(tty)"

if ! ssh-add -l &>/dev/null; then
	eval "$(ssh-agent -s)"
fi

# Managed feature flags and compatibility aliases
[ -f "$HOME/.config/mydotfiles/enable-copilot" ] && export ENABLE_COPILOT=1

[ -x "$HOME/.local/bin/code" ] && alias code="$HOME/.local/bin/code"
[ -x "$HOME/.local/bin/lazygit" ] && alias lazygit="$HOME/.local/bin/lazygit"

yy() {
	local tmp cwd status
	tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
	command yazi "$@" --cwd-file="$tmp"
	status=$?
	IFS= read -r cwd <"$tmp" || true
	rm -f -- "$tmp"
	if [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	return "$status"
}
