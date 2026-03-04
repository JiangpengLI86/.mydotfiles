# .mydotfiles

Personal Ubuntu/WSL dotfiles with an automated bootstrap script for:
- shell defaults (`.bashrc`, `.inputrc`, `.condarc`)
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

`setup.sh` detects privilege mode first:

- If root/sudo is available, it uses apt where appropriate.
- If sudo is unavailable, it continues in non-sudo mode and uses already-installed tools, prebuilt binaries, or source builds in `~/.local`.
- If essential build components are missing in non-sudo mode, it exits with a clear error.

Then it:

1. Runs `apt-get update` when apt is available.
2. Installs baseline packages via apt when possible:
   - build-essential, wget, curl, git, python3, python3-venv, make, stow, fontconfig, unzip, tar, bzip2, xz-utils
3. Runs `setup_scripts/update_rust_stable.sh --yes` and exports `RUSTUP_TOOLCHAIN=stable` for this setup run.
4. Detects existing **conda** and upgrades it in `base`; if missing, installs **Miniconda** to `~/miniconda3`, then runs `conda init bash`.
5. Installs **CaskaydiaMono Nerd Font** into `~/.local/share/fonts`.
6. Installs **yazi**:
   - prefers latest official **musl** prebuilt release into `~/.local/bin` for better libc compatibility
   - falls back to source build from `~/.local/src/yazi` when needed
   - adds a `yy()` shell wrapper to preserve cwd after yazi exits
7. Installs **Neovim**:
   - apt (`ppa:neovim-ppa/unstable`) when root/sudo is available
   - otherwise Linux prebuilt into `~/.local/opt/nvim` + `~/.local/bin/nvim`
   - auto-selects `neovim/neovim-releases` binaries on older glibc hosts for compatibility
8. Ensures Node/npm is available for Mason:
   - installs `nvm` + latest LTS Node when needed
9. Ensures `tree-sitter` CLI is available and new enough (>= `0.26.1`):
   - prefers existing install if compatible
   - tries apt package first
   - falls back to `cargo install tree-sitter-cli --locked --force`
   - isolates cargo target artifacts by local libc/arch to avoid cross-host cache reuse issues
   - removes incompatible cached Neovim parser `.so` files so they rebuild locally
10. Installs **tmux**:
   - apt when root/sudo is available
   - otherwise builds from source into `~/.local` (with local ncurses/libevent build if needed)
11. Rewrites a managed block in `~/.bashrc`:
   - custom `PS1`
   - `set -o vi`
   - `export GPG_TTY=$(tty)`
   - starts `ssh-agent` if missing
12. Runs GNU Stow for:
   - `tmux`, `nvim`, `yazi`, `inputrc`, `condarc`

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

## Tested environments

- Ubuntu 24.04 Desktop
- Ubuntu 22.04
  - WSL2
  - Docker
