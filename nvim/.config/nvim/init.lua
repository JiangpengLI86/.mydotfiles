-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Add unnamedplus to the clipboard option
vim.opt.clipboard:append("unnamedplus")

-- Configure the clipboard for win32yank in WSL
vim.g.clipboard = {
  name = "win32yank-wsl",
  copy = {
    ["+"] = "win32yank.exe -i --crlf",
    ["*"] = "win32yank.exe -i --crlf",
  },
  paste = {
    ["+"] = "win32yank.exe -o --lf",
    ["*"] = "win32yank.exe -o --lf",
  },
  cache_enabled = 0,
}
