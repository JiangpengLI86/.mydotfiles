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
