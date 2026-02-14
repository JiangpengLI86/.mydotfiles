local is_wsl = vim.fn.has("wsl") == 1
local has_win32yank = vim.fn.executable("win32yank.exe") == 1
local has_mac_clipboard = vim.fn.executable("pbcopy") == 1
local has_wayland_clipboard = vim.fn.executable("wl-copy") == 1 and vim.env.WAYLAND_DISPLAY ~= nil
local has_x11_clipboard = (vim.fn.executable("xclip") == 1 or vim.fn.executable("xsel") == 1) and vim.env.DISPLAY ~= nil
local has_remote_clipboard = vim.fn.executable("lemonade") == 1 or vim.fn.executable("doitclient") == 1
local has_termux_clipboard = vim.fn.executable("termux-clipboard-set") == 1
local has_clipboard_tool = has_win32yank
  or has_mac_clipboard
  or has_wayland_clipboard
  or has_x11_clipboard
  or has_remote_clipboard
  or has_termux_clipboard

-- Disable providers that are not needed before plugin bootstrap.
if vim.fn.executable("neovim-node-host") == 0 then
  vim.g.loaded_node_provider = 0
end
vim.g.loaded_perl_provider = 0
if vim.fn.executable("neovim-ruby-host") == 0 then
  vim.g.loaded_ruby_provider = 0
end

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

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
  vim.opt.clipboard:append("unnamedplus")
elseif has_clipboard_tool then
  vim.opt.clipboard:append("unnamedplus")
end
