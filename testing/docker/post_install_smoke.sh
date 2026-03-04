#!/usr/bin/env bash

set -euo pipefail

echo "Running post-install smoke checks..."

# setup.sh writes ~/.local/bin to .bashrc; tests run in a fresh non-login shell.
export PATH="$HOME/.local/bin:$PATH"

if ! command -v yazi >/dev/null 2>&1; then
	echo "Smoke check failed: yazi is not on PATH."
	exit 1
fi
yazi --version

if ! command -v tmux >/dev/null 2>&1; then
	echo "Smoke check failed: tmux is not on PATH."
	exit 1
fi
tmux -V

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

echo "Bootstrapping LazyVim and checking Neovim commands/logs (:messages, :NoiceLog, :MasonLog)..."
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
