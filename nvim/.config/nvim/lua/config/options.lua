-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Use Snacks as the picker backend so dashboard "f" and <leader><space>
-- don't go through the legacy fzf-lua default picker selection.
vim.g.lazyvim_picker = "snacks"

-- Setting indentations
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
