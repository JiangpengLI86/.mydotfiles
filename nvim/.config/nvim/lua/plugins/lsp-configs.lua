return {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "clang-format",
        "black",
      },
    },
  },
  {
    "williamboman/mason-lspconfig",
    opts = {
      ensure_installed = {
        "bashls",
        "texlab",
        "lua_ls",
        "clangd",
      },
    },
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
  {
    "nvimtools/none-ls.nvim",
    filetype = { "lua", "python", "cpp" },
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.root_dir = opts.root_dir
        or require("null-ls.utils").root_pattern(".null-ls-root", ".neoconf.json", "Makefile", ".git")
      opts.sources = vim.list_extend(opts.sources or {}, {
        nls.builtins.formatting.stylua,
        nls.builtins.formatting.shfmt,
        nls.builtins.formatting.black,
        nls.builtins.formatting.clang_format,
      })
    end,
  },
}
