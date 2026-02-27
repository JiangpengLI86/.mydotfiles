return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = function(_, opts)
      -- Force parsers to load from stdpath("data")/site first.
      -- This avoids stale parser binaries under plugin paths causing query mismatches.
      opts.install_dir = vim.fn.stdpath("data") .. "/site"

      opts.ensure_installed = opts.ensure_installed or {}

      -- jsonc is no longer a supported parser name in current nvim-treesitter.
      opts.ensure_installed = vim.tbl_filter(function(lang)
        return lang ~= "jsonc"
      end, opts.ensure_installed)

      -- Avoid runtime parser installation attempts on startup/opening files.
      opts.auto_install = false
    end,
  },
}
