#!/usr/bin/env bash

set -euo pipefail

echo "Running post-install smoke checks..."

# setup.sh writes ~/.local/bin to .bashrc; tests run in a fresh non-login shell.
export PATH="$HOME/.local/bin:$PATH"

VSCODE_CLI_BIN="$HOME/.local/opt/vscode-cli/bin/code"
VSCODE_CLI_BLOCK_START="# >>> mydotfiles vscode cli block >>>"
VSCODE_CLI_BLOCK_END="# <<< mydotfiles vscode cli block <<<"

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

if [ ! -x "$VSCODE_CLI_BIN" ]; then
	echo "Smoke check failed: expected VS Code CLI at $VSCODE_CLI_BIN."
	exit 1
fi
"$VSCODE_CLI_BIN" --version | head -n1

if ! grep -qF "$VSCODE_CLI_BLOCK_START" "$HOME/.bashrc"; then
	echo "Smoke check failed: VS Code CLI managed block start marker missing in ~/.bashrc."
	exit 1
fi
if ! grep -qF "$VSCODE_CLI_BLOCK_END" "$HOME/.bashrc"; then
	echo "Smoke check failed: VS Code CLI managed block end marker missing in ~/.bashrc."
	exit 1
fi
if ! grep -qF "alias code=\"$VSCODE_CLI_BIN\"" "$HOME/.bashrc"; then
	echo "Smoke check failed: VS Code CLI alias line missing in ~/.bashrc."
	exit 1
fi
if ! grep -qF "export PATH=\"$HOME/.local/opt/vscode-cli/bin:\$PATH\"" "$HOME/.bashrc"; then
	echo "Smoke check failed: VS Code CLI PATH prepend line missing in ~/.bashrc."
	exit 1
fi

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
