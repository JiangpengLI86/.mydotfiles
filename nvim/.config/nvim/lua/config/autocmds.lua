-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Enable built-in spell checker
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text", "python", "bash", "lua", "cpp" },
    callback = function()
        vim.opt.spell = true
        vim.opt.spelllang = "en"
    end,
})
