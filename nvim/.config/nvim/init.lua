local function parse_node_semver(path)
  local major, minor, patch = path:match("/v(%d+)%.(%d+)%.(%d+)/bin$")
  if not major then
    return nil
  end
  return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function semver_gt(lhs, rhs)
  if not rhs then
    return true
  end
  if lhs[1] ~= rhs[1] then
    return lhs[1] > rhs[1]
  end
  if lhs[2] ~= rhs[2] then
    return lhs[2] > rhs[2]
  end
  return lhs[3] > rhs[3]
end

local function ensure_npm_in_path()
  if vim.fn.executable("npm") == 1 then
    return
  end

  local home = vim.env.HOME
  if not home then
    return
  end

  local nvm_dir = vim.env.NVM_DIR or (home .. "/.nvm")
  if vim.fn.isdirectory(nvm_dir) == 0 then
    return
  end

  local node_bins = vim.fn.globpath(nvm_dir .. "/versions/node", "v*/bin", false, true)
  local best_bin
  local best_version

  for _, bin in ipairs(node_bins) do
    if vim.fn.executable(bin .. "/npm") == 1 then
      local version = parse_node_semver(bin)
      if version then
        if semver_gt(version, best_version) then
          best_version = version
          best_bin = bin
        end
      elseif not best_bin then
        best_bin = bin
      end
    end
  end

  if best_bin then
    vim.env.PATH = best_bin .. ":" .. (vim.env.PATH or "")
  end
end

ensure_npm_in_path()

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
