#!/usr/bin/env bash

set -euo pipefail

echo "Running post-install smoke checks..."

# Tests run in a fresh non-login shell.
export PATH="$HOME/.local/bin:$PATH"

VSCODE_CLI_BIN="$HOME/.local/opt/vscode-cli/bin/code"
SHELL_CONFIG="$HOME/.config/mydotfiles/bashrc.sh"
SHELL_SOURCE_LINE='source "$HOME/.config/mydotfiles/bashrc.sh"'

if ! command -v yazi >/dev/null 2>&1; then
	echo "Smoke check failed: yazi is not on PATH."
	exit 1
fi
yazi --version

if [ ! -d "$HOME/.config/yazi/flavors/catppuccin-mocha.yazi" ]; then
	echo "Smoke check failed: Catppuccin Mocha was not installed by ya pkg."
	exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
	echo "Smoke check failed: tmux is not on PATH."
	exit 1
fi
tmux -V

if ! command -v lazygit >/dev/null 2>&1; then
	echo "Smoke check failed: lazygit is not on PATH."
	exit 1
fi
lazygit --version | head -n1

# Exercise a real tmux server lifecycle in isolation from host sockets.
TMUX_SOCKET="smoke_$$"
tmux -L "$TMUX_SOCKET" -f /dev/null new-session -d -s smoke "sleep 10"
tmux -L "$TMUX_SOCKET" has-session -t smoke
tmux -L "$TMUX_SOCKET" kill-server

if ! command -v nvim >/dev/null 2>&1; then
	echo "Smoke check failed: nvim is not on PATH."
	exit 1
fi
nvim --version | head -n1

if [ ! -x "$VSCODE_CLI_BIN" ]; then
	echo "Smoke check failed: expected VS Code CLI at $VSCODE_CLI_BIN."
	exit 1
fi
"$VSCODE_CLI_BIN" --version | head -n1

if [ ! -f "$SHELL_CONFIG" ]; then
	echo "Smoke check failed: stowed shell configuration is missing."
	exit 1
fi
if [ "$(grep -cF "$SHELL_SOURCE_LINE" "$HOME/.bashrc")" -ne 1 ]; then
	echo "Smoke check failed: ~/.bashrc must source the shell configuration exactly once."
	exit 1
fi

if ! bash -ic 'type yy >/dev/null && alias code >/dev/null && alias lazygit >/dev/null' >/dev/null 2>&1; then
	echo "Smoke check failed: shell aliases or yy() are unavailable."
	exit 1
fi

if [ -s "$HOME/.nvm/nvm.sh" ]; then
	if ! bash -ic 'command -v npm >/dev/null 2>&1 && npm --version >/dev/null 2>&1' >/dev/null 2>&1; then
		echo "Smoke check failed: npm is not available from a fresh interactive shell after sourcing ~/.bashrc."
		exit 1
	fi
fi

echo "Bootstrapping LazyVim and checking Noice plus Neovim commands (:messages, :Mason)..."
check_log="$(mktemp /tmp/nvim-post-check.XXXXXX.log)"
if ! nvim --headless "+luafile testing/docker/nvim_post_install_check.lua" >"$check_log" 2>&1; then
	echo "Neovim post-install check failed. Recent log:"
	tail -n 200 "$check_log"
	rm -f "$check_log"
	exit 1
fi
cat "$check_log"
rm -f "$check_log"

echo "POST_INSTALL_SMOKE_OK"
