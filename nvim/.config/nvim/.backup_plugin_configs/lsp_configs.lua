return {
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim", -- Ensure Mason is installed
            "williamboman/mason-lspconfig", -- Ensure Mason LSP config is installed
        },
        opts = function()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "pyright", -- Python LSP
                    "bashls", -- Bash LSP
                    "texlab", -- LaTeX LSP
                    "lua_ls", -- Lua LSP
                    "clangd", -- C/C++ LSP
                },
                automatic_installation = true,
            })
            local lspconfig = require("lspconfig")
            lspconfig.pyright.setup({})
            lspconfig.bashls.setup({})
            lspconfig.texlab.setup({})
            lspconfig.lua_ls.setup({})

            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities.offsetEncoding = { "utf-16" }
            lspconfig.clangd.setup({ capabilities = capabilities })

            vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
        end,
    },
}
