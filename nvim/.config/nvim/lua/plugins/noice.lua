return {
  {
    "folke/noice.nvim",
    init = function()
      -- Prevent search_count UI events that have caused Noice fast-event errors on some setups.
      vim.opt.shortmess:append("S")
    end,
    opts = function(_, opts)
      opts.cmdline = opts.cmdline or {}
      opts.cmdline.format = opts.cmdline.format or {}

      -- Avoid tree-sitter highlighting of Vim cmdline text in Noice.
      -- This works around parser/query mismatches that can flood :Noice log.
      if opts.cmdline.format.cmdline then
        opts.cmdline.format.cmdline.lang = nil
      end
      if opts.cmdline.format.calculator then
        opts.cmdline.format.calculator.lang = nil
      end
    end,
  },
}
