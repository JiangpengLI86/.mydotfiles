return {
  "stevearc/conform.nvim",
  opts = function()
    require("conform").setup({
      formatters_by_ft = {
        cpp = { "clang-format" },
      },
    })
  end,
}
