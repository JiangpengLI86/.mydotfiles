# .mydotfiles

Ubuntu and WSL dotfiles with a single bootstrap script for development tools
and shell/editor configuration.

## Install

The repository must be cloned as `~/.mydotfiles`:

```bash
git clone https://github.com/JiangpengLI86/.mydotfiles.git ~/.mydotfiles
cd ~/.mydotfiles
bash setup.sh
source ~/.bashrc
```

The setup uses `apt` when sudo is available and falls back to prebuilt binaries
or local source builds where supported.

### Without sudo

Ask an administrator to install these prerequisites before running the setup:

```bash
build-essential wget curl git python3 python3-venv make stow fontconfig unzip tar bzip2 xz-utils
```

Without them, the setup reports the missing commands and exits before
installing the user-local tools.

## Included

- Bash, tmux, Neovim (LazyVim), Yazi, and input/Conda configuration
- Codex, Claude, and Gemini configuration
- Rust, uv, Miniconda, Node.js, and Tree-sitter CLI
- Nerd Font, Lazygit, and VS Code CLI

GNU Stow links the managed configuration into the home directory. Tool
installations live under `~/.local` where possible.

## Options

Enable the optional Neovim Copilot configuration only on trusted machines:

```bash
bash setup.sh --use-copilot
```

Run `bash setup.sh --help` for the current command-line options.

## Tests

Docker scenarios cover sudo and non-sudo installs, prerequisite failures,
idempotency, and isolated shell-function checks:

```bash
bash testing/docker/run_tests.sh
```

Use `--keep-images` to retain the temporary test images.
