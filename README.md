# .mydotfiles

This is a repo used to store my configuration files across machines.

## Installation

1. Clone this repo under `~`
2. Inside the repo, run: `bash setup.sh`
   - If you want GitHub Copilot in Neovim, run: `bash setup.sh --use-copilot`
3. Source your `.bashrc`: `source ~/.bashrc`

## Notes for Ubuntu / WSL

- Neovim is installed from `ppa:neovim-ppa/unstable` to keep it updated.
- Copilot is controlled by `ENABLE_COPILOT` in `.bashrc`.
- In WSL, clipboard integration uses `win32yank.exe` only when it is available; on native Ubuntu it falls back to default clipboard providers.

## Rust Manual Update

If you want to manually update Rust in a controlled way (outside of `setup.sh`), use:

- `bash setup_scripts/update_rust_stable.sh`
- Non-interactive: `bash setup_scripts/update_rust_stable.sh --yes`
- Status only: `bash setup_scripts/update_rust_stable.sh --check`

The script updates `rustup` and the `stable` toolchain, ensures `rustfmt` and `clippy` are installed, and does not change non-stable default toolchains.

## Source-built Tools Manual Uninstall

If you want to remove source-built installs before reinstalling with `setup.sh`, use:

- `bash setup_scripts/uninstall_source_build_tools.sh`
- Non-interactive: `bash setup_scripts/uninstall_source_build_tools.sh --yes`
- Status only: `bash setup_scripts/uninstall_source_build_tools.sh --check`

This removes managed source-built artifacts for:
- `yazi` installed at `/opt/yazi`
- `tree-sitter` CLI installed via cargo at `~/.cargo/bin/tree-sitter` (plus repo-managed symlink `/usr/local/bin/tree-sitter` when it points to the cargo binary)

After uninstalling, you can reinstall with `bash setup.sh`.

Recommended recovery flow:
1. Check current managed state: `bash setup_scripts/uninstall_source_build_tools.sh --check`
2. Uninstall source-built artifacts: `bash setup_scripts/uninstall_source_build_tools.sh`
3. Reinstall with fresh builds: `bash setup.sh`

## Tips

1. Sometimes, using yazi and NeoVim in tmux will have some display issues. To fix this, run tmux with `tmux -u`.
2. To use this settings in the VSCode terminal, you need to:
   1. Set VSCode terminal fonts, for example: `"terminal.integrated.fontFamily":"Hack Nerd Font"`.
      Make sure this font is installed on your **local** computer.
   2. Uncheck `Terminal > Integrated: Allow Chords`.
   3. Check `Terminal > Integrated: Send Keybindings To Shell`.

## Tested on: (20240920)

- Ubuntu 24.04 Desktop
- Ubuntu 22.04
  - WSL2
  - Docker
