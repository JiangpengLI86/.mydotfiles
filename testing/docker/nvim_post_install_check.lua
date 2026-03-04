local function fail(msg)
  io.stderr:write(msg .. "\n")
  vim.cmd("cquit 1")
end

local function info(msg)
  io.stdout:write(msg .. "\n")
end

local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
  fail("lazy.nvim is not available after setup")
end

lazy.load({
  plugins = {
    "noice.nvim",
    "folke/noice.nvim",
    "mason.nvim",
    "williamboman/mason.nvim",
  },
})
pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "VeryLazy" })

local ok_messages, err_messages = pcall(vim.cmd, "silent messages")
if not ok_messages then
  fail("`:messages` failed: " .. tostring(err_messages))
end

local function plugin_installed(dir_name)
  local plugin_path = vim.fn.stdpath("data") .. "/lazy/" .. dir_name
  return vim.fn.isdirectory(plugin_path) == 1
end

local function run_first_available(checks, label)
  for _, check in ipairs(checks) do
    if vim.fn.exists(":" .. check.command) == 2 then
      local ok_cmd, err_cmd = pcall(vim.cmd, "silent! " .. check.invocation)
      if not ok_cmd then
        fail("`:" .. check.invocation .. "` failed for " .. label .. ": " .. tostring(err_cmd))
      end
      info(label .. " command check passed via :" .. check.invocation)
      return true
    end
  end
  info(label .. " command unavailable in headless session")
  return false
end

local noice_cmd_ok = run_first_available({
  { command = "NoiceLog", invocation = "NoiceLog" },
  { command = "Noice", invocation = "Noice history" },
}, "Noice")

local mason_cmd_ok = run_first_available({
  { command = "MasonLog", invocation = "MasonLog" },
  { command = "Mason", invocation = "Mason" },
}, "Mason")

local state_dir = vim.fn.stdpath("state")
local log_presence = {}
for _, log in ipairs({ "noice.log", "mason.log" }) do
  local path = state_dir .. "/" .. log
  local fd = io.open(path, "r")
  if fd then
    local size = #(fd:read("*a") or "")
    fd:close()
    info(log .. " readable (" .. tostring(size) .. " bytes)")
    log_presence[log] = true
  else
    info(log .. " not found at " .. path)
    log_presence[log] = false
  end
end

if not noice_cmd_ok and not plugin_installed("noice.nvim") then
  fail("Noice plugin is not installed")
end
if not mason_cmd_ok and not plugin_installed("mason.nvim") then
  fail("Mason plugin is not installed")
end

info("NVIM_POST_CHECK_OK")
vim.cmd("qa")
