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
- The VSCode LazyVim extra is not enabled by default in this setup to avoid plugin conflicts in normal Neovim sessions.
- Keep `nvim/.config/nvim/lazy-lock.json` in the repo. It pins plugin versions for reproducible installs across Ubuntu/WSL. Do not replace it with an empty file.

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
