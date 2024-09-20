-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Enable buildin spell checker
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text", "python", "bash", "lua", "cpp" },
    callback = function()
        vim.opt.spell = true -- Enable spell checking
        vim.opt.spelllang = "en" -- Set the language (you can set multiple like "en,es")
    end,
})

-- Change the key mapping of nvim-cmp
local cmp = require("cmp")
cmp.setup({
    mapping = cmp.mapping.preset.insert({
        -- Changing the auto completion confirm key from Enter to Tab >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        ["<CR>"] = function(fallback)
            cmp.abort()
            fallback()
        end,
        ["<Tab>"] = cmp.mapping.confirm({ select = true }),
        -- Changing the auto completion confirm key from Enter to Tab <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    }),
})
