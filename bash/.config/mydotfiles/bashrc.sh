for mydotfiles_bin_dir in \
	"$HOME/.local/bin" \
	"$HOME/.cargo/bin" \
	"$HOME/.local/opt/vscode-cli/bin"; do
	case ":$PATH:" in
	*:"$mydotfiles_bin_dir":*) ;;
	*) PATH="$mydotfiles_bin_dir:$PATH" ;;
	esac
done
export PATH
unset mydotfiles_bin_dir

PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\e[38;5;195m\]\w\n\[\033[00m\]\$ '
set -o vi
export GPG_TTY="$(tty)"

if ! ssh-add -l &>/dev/null; then
	eval "$(ssh-agent -s)"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

[ -f "$HOME/.config/mydotfiles/enable-copilot" ] && export ENABLE_COPILOT=1

alias code="$HOME/.local/opt/vscode-cli/bin/code"
alias lazygit="$HOME/.local/bin/lazygit"

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
