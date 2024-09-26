-- lua/config/plugins.lua (create this file if it doesn't exist)

return {
    {
        "nvimtools/none-ls.nvim",
        opts = function(_, opts)
            local null_ls = require("null-ls")
            local formatting = null_ls.builtins.formatting

            opts.sources = vim.list_extend(opts.sources, {
                formatting.prettier.with({
                    extra_args = { "--tab-width", "4" }, -- Set tab width to 4 spaces
                    filetypes = { "markdown" }, -- Only apply to markdown files
                }),
            })
        end,
    },
}
