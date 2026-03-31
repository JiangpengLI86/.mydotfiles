return {
  {
    "olimorris/onedarkpro.nvim",
    priority = 1000, -- Ensure it loads first
  },
  {
    -- Configure LazyVim to load onedark
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
