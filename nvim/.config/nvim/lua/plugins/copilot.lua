if vim.env.ENABLE_COPILOT ~= "1" then
  return {}
end

return {
  { "zbirenbaum/copilot.lua", opts = {} },
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "fang2hou/blink-copilot" },
    opts = function(_, opts)
      opts = opts or {}
      opts.sources = opts.sources or {}
      opts.sources.providers = opts.sources.providers or {}

      opts.sources.providers.copilot = {
        name = "copilot",
        module = "blink-copilot",
        score_offset = 100,
        async = true,
      }

      local defaults = opts.sources.default or {}
      if type(defaults) ~= "table" then
        defaults = { defaults }
      end
      if not vim.tbl_contains(defaults, "copilot") then
        table.insert(defaults, 1, "copilot")
      end
      opts.sources.default = defaults

      return opts
    end,
  },
}
