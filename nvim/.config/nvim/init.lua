-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Add unnamedplus to the clipboard option
vim.opt.clipboard:append("unnamedplus")

-- Configure win32yank clipboard only when running in WSL and win32yank exists.
local is_wsl = vim.fn.has("wsl") == 1
local has_win32yank = vim.fn.executable("win32yank.exe") == 1

if is_wsl and has_win32yank then
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
end
