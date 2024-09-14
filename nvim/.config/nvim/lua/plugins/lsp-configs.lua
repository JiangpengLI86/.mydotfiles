return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ensure_installed = {
          "clang-format",
        },
      })
    end,
  },
  {
    "williamboman/mason-lspconfig",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "bashls",
          "texlab",
          "lua_ls",
          "clangd",
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      lspconfig.bashls.setup({})
      lspconfig.texlab.setup({})
      lspconfig.lua_ls.setup({})
      lspconfig.clangd.setup({})

      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
    end,
  },
  -- {
  --   "nvimtools/none-ls.nvim",
  --   event = "VeryLazy",
  --   opts = function()
  --     local none_ls = require("none-ls")
  --     local options = {
  --       none_ls.builtins.formatting.clang_format,
  --     }
  --     return options
  --   end,
  -- },
}
