# .mydotfiles

Personal Ubuntu/WSL dotfiles with an automated bootstrap script for:
- shell defaults (`.bashrc`, `.inputrc`, `.condarc`)
- Neovim (LazyVim-based)
- tmux
- yazi
- lazygit

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
3. Verifies essential prerequisites are present (`cc`, `wget`, `curl`, `git`, `python3`, `make`, `stow`, `fc-cache`, `unzip`, `tar`, `bzip2`, `xz`, Python `venv` module), and exits early with a clear error if they are missing.
4. Runs `setup_scripts/update_rust_stable.sh --yes` and exports `RUSTUP_TOOLCHAIN=stable` for this setup run.
5. Detects existing **conda** and upgrades it in `base`; if missing, installs **Miniconda** to `~/miniconda3`, then runs `conda init bash`.
6. Installs **CaskaydiaMono Nerd Font** into `~/.local/share/fonts`.
7. Installs **yazi**:
   - prefers latest official **musl** prebuilt release into `~/.local/bin` for better libc compatibility
   - falls back to source build from `~/.local/src/yazi` when needed
   - if a legacy source build exists at `/opt/yazi/target/release`, reuses it by linking `yazi`/`ya` into `~/.local/bin`
   - adds a `yy()` shell wrapper to preserve cwd after yazi exits inside the shared mydotfiles-managed `~/.bashrc` section
8. Installs **lazygit** from the latest official GitHub release tarball:
   - downloads from `https://github.com/jesseduffield/lazygit/releases/latest/download/...`
   - installs/overwrites `~/.local/bin/lazygit`
   - manages a dedicated inner block inside the shared mydotfiles-managed `~/.bashrc` section with `alias lazygit="$HOME/.local/bin/lazygit"`
9. Installs **Neovim**:
   - apt (`ppa:neovim-ppa/unstable`) when root/sudo is available
   - otherwise Linux prebuilt into `~/.local/opt/nvim` + `~/.local/bin/nvim`
   - auto-selects `neovim/neovim-releases` binaries on older glibc hosts for compatibility
10. Ensures Node/npm is available for Mason:
   - installs `nvm` + latest LTS Node when needed
   - manages a dedicated inner `~/.bashrc` block that initializes `NVM_DIR`, `nvm.sh`, and `bash_completion` for fresh shells
11. Ensures `tree-sitter` CLI is available and new enough (>= `0.26.1`):
   - prefers existing install if compatible
   - tries apt package first
   - falls back to `cargo install tree-sitter-cli --locked --force`
   - isolates cargo target artifacts by local libc/arch to avoid cross-host cache reuse issues
   - removes incompatible cached Neovim parser `.so` files so they rebuild locally
12. Installs **tmux**:
   - apt when root/sudo is available
   - otherwise builds from source into `~/.local` (with local ncurses/libevent build if needed)
13. Installs latest **VS Code CLI** from Microsoft download endpoint:
   - downloads `https://code.visualstudio.com/sha/download?build=stable&os=...`
   - installs/overwrites `~/.local/opt/vscode-cli/bin/code`
   - manages a dedicated inner block inside the shared mydotfiles-managed `~/.bashrc` section with:
     - `alias code="$HOME/.local/opt/vscode-cli/bin/code"`
     - PATH-prepend for `~/.local/opt/vscode-cli/bin` so this managed CLI is preferred over system `code`
14. Rewrites the shell-defaults inner block in the shared mydotfiles-managed section of `~/.bashrc`:
   - custom `PS1`
   - `set -o vi`
   - `export GPG_TTY=$(tty)`
   - starts `ssh-agent` if missing
15. Runs GNU Stow for:
   - `tmux`, `nvim`, `yazi`, `inputrc`, `condarc`

## Docker scenario tests

Automated tests for privilege/package edge cases are in `testing/docker`.

Run all three scenarios:

```bash
bash testing/docker/run_tests.sh
```

Scenarios covered:
1. sudo permission granted to the non-root user.
2. no sudo permission and essential packages missing (expects failure).
3. no sudo permission and all essential packages pre-installed.

Notes:
- Tests copy this repo into each image via `COPY . ...` (no host bind mount), avoiding host/container file permission issues.
- Containers are always deleted after execution (`docker run --rm`).
- Temporary test images are removed by default; pass `--keep-images` to retain them.
- If Docker or the Docker daemon is unavailable, tests stop with: `Testing could not be run without Docker.`
- Case 2 uses `SETUP_TEST_EXIT_AFTER_PREREQS=1` to validate the non-sudo missing-prereqs failure path quickly.
- Cases 1 and 3 run full `setup.sh`, then run post-install smoke checks in `testing/docker/post_install_smoke.sh`:
  - `yazi --version`
  - `lazygit --version`
  - `tmux -V` and isolated tmux server lifecycle
  - `~/.local/opt/vscode-cli/bin/code --version`
  - top-level mydotfiles-managed `~/.bashrc` block markers
  - `nvm` managed block markers and `npm` availability from a fresh interactive shell
  - VS Code CLI managed block markers + alias/PATH lines in `~/.bashrc`
  - lazygit managed block markers + `alias lazygit="$HOME/.local/bin/lazygit"` in `~/.bashrc`
  - Neovim headless checks for `:messages`, `:NoiceLog`, and `:MasonLog`
- Neovim smoke checks run `Lazy! sync` first because first-run LazyVim plugin installation can take time.

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
