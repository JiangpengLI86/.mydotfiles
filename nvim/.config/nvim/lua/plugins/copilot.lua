return {
  "zbirenbaum/copilot.lua",

  -- Lazy-load on command
  cmd = "Copilot",
  -- build is exectued when a plugin is installed or udpated.
  build = ":Copilot auth",
  -- Lazy-load on event: InsertEnter
  event = "InsertEnter",

  config = function()
    require("copilot").setup({})
  end,
  -- opts should be a table which will be passed to the config function as an argument.
  -- Setting this function will imply plugin.config()
  opts = {
    suggestion = { enabled = false },
    panel = { enabled = false },
    filetypes = {
      markdown = true,
      help = true,
    },
  },
}
