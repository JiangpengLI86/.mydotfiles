# .mydotfiles

Personal Ubuntu/WSL dotfiles with an automated bootstrap script for:
- shell defaults (`.bashrc`, `.inputrc`)
- Neovim (LazyVim-based)
- tmux
- yazi

## Quick start

This script expects the repo directory name to be exactly `.mydotfiles`.

```bash
cd ~
git clone https://github.com/JiangpengLI86/.mydotfiles.git .mydotfiles
cd .mydotfiles
bash setup.sh
# or: bash setup.sh --use-copilot
source ~/.bashrc
```

## What `setup.sh` does

`setup.sh` escalates with `sudo` automatically when needed, then:

1. Runs `apt-get update`.
2. Installs baseline packages:
   - `build-essential`, `wget`, `curl`, `git`, `python3`, `python3-venv`, `make`, `stow`, `fontconfig`, `unzip`, `tar`
3. Installs **CaskaydiaMono Nerd Font** into `~/.local/share/fonts`.
4. Installs **yazi** from source:
   - local source checkout at `~/.local/src/yazi`
   - deployed build under `/opt/yazi`
   - appends `export PATH=$PATH:/opt/yazi/target/release` to `~/.bashrc`
   - adds a `yy()` shell wrapper to preserve cwd after yazi exits
5. Installs **Neovim** from `ppa:neovim-ppa/unstable`.
6. Ensures Node/npm is available for Mason:
   - installs `nvm` + latest LTS Node when needed
7. Ensures `tree-sitter` CLI is available and new enough (>= `0.26.1`):
   - prefers existing install if compatible
   - tries apt package first
   - falls back to `cargo install tree-sitter-cli --locked --force`
8. Installs **tmux**.
9. Rewrites a managed block in `~/.bashrc`:
   - custom `PS1`
   - `set -o vi`
   - `export GPG_TTY=$(tty)`
   - starts `ssh-agent` if missing
10. Runs GNU Stow for:
   - `tmux`, `nvim`, `yazi`, `inputrc`

## Setup options

```bash
bash setup.sh --use-copilot
```

This sets `export ENABLE_COPILOT=1` in `~/.bashrc`, which enables the Neovim Copilot plugin config (`lua/plugins/copilot.lua`).

## Post-install notes

- Reload shell config:
  - `source ~/.bashrc`
- tmux config uses TPM at `~/.config/tmux/plugins/tpm/tpm`.
  - If TPM is missing, install it:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
```

## Neovim config summary

Neovim config is in `nvim/.config/nvim` and is based on LazyVim.

Highlights:
- LazyVim extras enabled for clang/cmake/python/tex/json/yaml/docker/git/dap/etc.
- Clipboard handling supports WSL (`win32yank.exe`) and native Linux clipboard tools.
- `nvim-treesitter` is adjusted to avoid stale parser issues.
- `none-ls` prettier is customized for markdown tab width.
- VimTeX only loads when a TeX compiler (`latexmk` or `tectonic`) exists.

## Utility scripts

### Update Rust stable toolchain

```bash
bash setup_scripts/update_rust_stable.sh
bash setup_scripts/update_rust_stable.sh --yes
bash setup_scripts/update_rust_stable.sh --check
```

Updates `rustup`, `stable`, and stable components (`rustfmt`, `clippy`) without changing non-stable defaults.

### Uninstall source-built artifacts managed by this repo

```bash
bash setup_scripts/uninstall_source_build_tools.sh
bash setup_scripts/uninstall_source_build_tools.sh --yes
bash setup_scripts/uninstall_source_build_tools.sh --check
```

Removes managed source-built installs for:
- `/opt/yazi`
- `~/.cargo/bin/tree-sitter`
- `/usr/local/bin/tree-sitter` symlink (only when it points to the cargo binary)
- yazi PATH/wrapper entries in `~/.bashrc`

## Troubleshooting

### Treesitter textobjects module issue

If Neovim reports:
- `Failed to run config for nvim-treesitter-textobjects`
- `module 'nvim-treesitter-textobjects' not found`

repair with:

```bash
git -C ~/.local/share/nvim/lazy/nvim-treesitter-textobjects restore .
nvim --headless "+Lazy! sync" "+qa"
```

### tmux rendering oddities with yazi/neovim

Try:

```bash
tmux -u
```

### VS Code terminal tips

1. Set terminal font (for example): `"terminal.integrated.fontFamily": "Hack Nerd Font"`.
2. Disable `Terminal > Integrated: Allow Chords`.
3. Enable `Terminal > Integrated: Send Keybindings To Shell`.

## Optional config in repo

- `condarc/.condarc` exists but is not stowed by `setup.sh`.
- To apply it manually:

```bash
stow condarc
```

## Tested environments

- Ubuntu 24.04 Desktop
- Ubuntu 22.04
  - WSL2
  - Docker
