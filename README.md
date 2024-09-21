# .mydotfiles

This is a repo used to store my configuration files across machines.

## Installation

1. Clone this repo under ~
2. Inside the repo, run: `bash setup.sh`
3. Source your .bashrc: `source ~/.bashrc`

## Tips

1. Sometimes, using yazi and NeoVim in tmux will have some display issues. To fix this, run the tmux with `tmux -u`.
2. To use this settings in the VScode's terminal, you need to:
   1. Set VSCode's terminal fonts, like: `"terminal.integrated.fontFamily":"Hack Nerd Font"`. <u>And make sure that you have also installed that font on your **local** computer</u>
   2. Uncheck the `Terminal > Integrated: Allow Chords`.
   3. Check the `Terminal > Integrated: Send Keybindings To Shell`

## Tested on: (20240920)

- Ubuntu 24.04 Desktop
- Ubuntu 22.04
  - WSL2
  - Docker
