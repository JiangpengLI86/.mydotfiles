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
4. Runs `setup_scripts/update_rust_stable.sh` and exports `RUSTUP_TOOLCHAIN=stable` for this setup run.
5. Detects existing **conda** and upgrades it in `base`; if missing, installs **Miniconda** to `~/miniconda3`, then runs `conda init bash`.
6. Installs **CaskaydiaMono Nerd Font** into `~/.local/share/fonts`.
7. Installs **yazi**:
   - prefers latest official **musl** prebuilt release into `~/.local/bin` for better libc compatibility
   - falls back to source build from `~/.local/src/yazi` when needed
   - restores the locked Catppuccin Mocha flavor with `ya pkg install`
   - provides a `yy()` shell wrapper through the stowed shell configuration
8. Installs **lazygit** from the latest official GitHub release tarball:
   - downloads from `https://github.com/jesseduffield/lazygit/releases/latest/download/...`
   - installs/overwrites `~/.local/bin/lazygit`
   - exposes `alias lazygit="$HOME/.local/bin/lazygit"` through the stowed shell configuration
9. Installs **Neovim**:
   - installs the official Linux prebuilt into `~/.local/opt/nvim` + `~/.local/bin/nvim`
   - auto-selects `neovim/neovim-releases` binaries on older glibc hosts for compatibility
10. Ensures Node/npm is available for Mason:
   - installs `nvm` + latest LTS Node when needed
   - initializes `NVM_DIR`, `nvm.sh`, and `bash_completion` from the stowed shell configuration
11. Ensures `tree-sitter` CLI is available:
   - runs `cargo install tree-sitter-cli --locked --no-default-features`
12. Installs **tmux**:
   - apt when root/sudo is available
   - otherwise builds from source into `~/.local` (with local ncurses/libevent build if needed)
13. Installs latest **VS Code CLI** from Microsoft download endpoint:
   - downloads `https://code.visualstudio.com/sha/download?build=stable&os=...`
   - installs/overwrites `~/.local/opt/vscode-cli/bin/code`
   - exposes its alias and PATH through the stowed shell configuration
14. Adds one idempotent source line to `~/.bashrc` for `~/.config/mydotfiles/bashrc.sh`, which provides:
   - custom `PS1`
   - `set -o vi`
   - `export GPG_TTY=$(tty)`
   - starts `ssh-agent` if missing
   - local binary paths, NVM initialization, aliases, and `yy()`
15. Runs GNU Stow for:
   - `bash`, `tmux`, `nvim`, `yazi`, `inputrc`, `condarc`
   - `codex` → `~/.codex/` (config, skills)
   - `claude` → `~/.claude/` (settings, `CLAUDE.md` symlinked to shared `AGENTS.md`)
   - `gemini` → `~/.gemini/` (settings, `GEMINI.md` symlinked to shared `AGENTS.md`)

## Docker scenario tests

Automated tests for privilege/package edge cases are in `testing/docker`.

Run all scenarios:

```bash
bash testing/docker/run_tests.sh
```

Scenarios covered:
1. sudo permission granted to the non-root user.
2. no sudo permission and essential packages missing (expects failure).
3. no sudo permission and all essential packages pre-installed.
4. unit tests for pure/isolated shell functions (no network, no apt).
5. idempotency: runs `setup.sh` twice in succession to verify no side-effect corruption.

Notes:
- Tests copy this repo into each image via `COPY . ...` (no host bind mount), avoiding host/container file permission issues.
- Containers are always deleted after execution (`docker run --rm`).
- Temporary test images are removed by default; pass `--keep-images` to retain them.
- If Docker or the Docker daemon is unavailable, tests stop with: `Testing could not be run without Docker.`
- Case 2 uses `SETUP_TEST_EXIT_AFTER_PREREQS=1` to validate the non-sudo missing-prereqs failure path quickly.
- Cases 1, 3, and 5 run full `setup.sh`, then run post-install smoke checks in `testing/docker/post_install_smoke.sh`:
  - `yazi --version`
  - `lazygit --version`
  - `tmux -V` and isolated tmux server lifecycle
  - `~/.local/opt/vscode-cli/bin/code --version`
  - one `~/.bashrc` source line for the stowed shell configuration
  - `npm`, `yy()`, and the VS Code/lazygit aliases from a fresh interactive shell
  - Neovim headless checks for the Noice module, `:messages`, and `:Mason`
- Neovim smoke checks run `Lazy! sync` first because first-run LazyVim plugin installation can take time.
- Case 4 runs `testing/docker/unit_test_functions.sh`, covering `require_commands`, the idempotent shell-config source line, and `setup.sh` argument parsing.
- Case 5 runs `setup.sh` twice before smoke tests to verify idempotency (no duplicate bashrc lines, no stow conflicts, no permission errors on re-run).

## Setup options

```bash
bash setup.sh --use-copilot
```

This creates `~/.config/mydotfiles/enable-copilot`, which the stowed shell configuration uses to enable the Neovim Copilot plugin config (`lua/plugins/copilot.lua`).

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
- LazyVim's Prettier extra formats supported files through Conform.
- VimTeX only loads when a TeX compiler (`latexmk` or `tectonic`) exists.

## Utility scripts

### Update Rust stable toolchain

```bash
bash setup_scripts/update_rust_stable.sh
```

Installs rustup when absent, updates stable, adds `rustfmt` and `clippy`, then runs `rustup check`.

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
