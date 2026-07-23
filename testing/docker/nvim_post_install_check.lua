local function fail(message)
  io.stderr:write(message .. "\n")
  vim.cmd("cquit 1")
end

local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
  fail("lazy.nvim is not available after setup")
end

local ok_sync, sync_error = pcall(vim.cmd, "Lazy! sync")
if not ok_sync then
  fail("Lazy sync failed: " .. tostring(sync_error))
end

lazy.load({ plugins = { "noice.nvim" } })
local ok_noice, noice = pcall(require, "noice")
if not ok_noice or type(noice.setup) ~= "function" then
  fail("noice.nvim is not loadable")
end

for _, plugin in ipairs({ "noice.nvim", "mason.nvim", "nvim-treesitter" }) do
  if vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/" .. plugin) ~= 1 then
    fail(plugin .. " is not installed")
  end
end

if vim.fn.exists(":Mason") ~= 2 then
  fail(":Mason is unavailable")
end

local ok_messages, messages_error = pcall(vim.cmd, "silent messages")
if not ok_messages then
  fail(":messages failed: " .. tostring(messages_error))
end

io.stdout:write("NVIM_POST_CHECK_OK\n")
vim.cmd("qa")
