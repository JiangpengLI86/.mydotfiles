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

info("Bootstrapping plugins via :Lazy! sync (first run can take time)")
local ok_sync, err_sync = pcall(vim.cmd, "silent! Lazy! sync")
if not ok_sync then
  fail("`:Lazy! sync` failed: " .. tostring(err_sync))
end

lazy.load({
  plugins = {
    "noice.nvim",
    "mason.nvim",
    "nvim-treesitter",
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

local function parse_package_spec(spec)
  local spec_str = tostring(spec or "")
  if spec_str == "" then
    return "", nil
  end
  local ok_package, package_mod = pcall(require, "mason-core.package")
  if ok_package and type(package_mod.Parse) == "function" then
    local ok_parse, name, version = pcall(package_mod.Parse, spec_str)
    if ok_parse and type(name) == "string" and name ~= "" then
      return name, version
    end
  end
  local at = spec_str:find("@", 1, true)
  if at then
    return spec_str:sub(1, at - 1), spec_str:sub(at + 1)
  end
  return spec_str, nil
end

local function find_plugin(name_fragment)
  local ok_config, lazy_config = pcall(require, "lazy.core.config")
  if not ok_config or type(lazy_config.plugins) ~= "table" then
    return nil
  end
  for key, plugin in pairs(lazy_config.plugins) do
    local key_str = tostring(key)
    local name = tostring(plugin.name or "")
    if key_str == name_fragment or name == name_fragment then
      return plugin
    end
  end
  for _, plugin in pairs(lazy_config.plugins) do
    local url = tostring(plugin.url or "")
    if url:find("/" .. name_fragment .. ".git", 1, true) then
      return plugin
    end
  end
  return nil
end

local function get_mason_ensure_specs()
  local plugin = find_plugin("mason.nvim")
  if not plugin then
    return {}
  end
  local opts = nil
  local ok_plugin, lazy_plugin = pcall(require, "lazy.core.plugin")
  if ok_plugin and type(lazy_plugin.values) == "function" then
    local ok_opts, resolved_opts = pcall(lazy_plugin.values, plugin, "opts", false)
    if ok_opts and type(resolved_opts) == "table" then
      opts = resolved_opts
    end
  end
  if type(opts) ~= "table" then
    opts = type(plugin.opts) == "table" and plugin.opts or {}
  end
  local ensure = opts.ensure_installed
  if type(ensure) ~= "table" then
    return {}
  end
  local specs = {}
  for _, spec in ipairs(ensure) do
    if type(spec) == "string" and spec ~= "" then
      specs[#specs + 1] = spec
    end
  end
  return specs
end

local function get_treesitter_ensure_languages()
  local plugin = find_plugin("nvim-treesitter")
  if not plugin then
    return {}
  end
  local opts = nil
  local ok_plugin, lazy_plugin = pcall(require, "lazy.core.plugin")
  if ok_plugin and type(lazy_plugin.values) == "function" then
    local ok_opts, resolved_opts = pcall(lazy_plugin.values, plugin, "opts", false)
    if ok_opts and type(resolved_opts) == "table" then
      opts = resolved_opts
    end
  end
  if type(opts) ~= "table" then
    opts = type(plugin.opts) == "table" and plugin.opts or {}
  end
  local ensure = opts.ensure_installed
  if type(ensure) ~= "table" then
    return {}
  end
  local languages = {}
  for _, lang in ipairs(ensure) do
    if type(lang) == "string" and lang ~= "" then
      languages[#languages + 1] = lang
    end
  end
  return languages
end

local function list_or_none(items, max_items)
  if #items == 0 then
    return "none"
  end
  local maxn = max_items or 12
  local shown = {}
  for i = 1, math.min(#items, maxn) do
    shown[#shown + 1] = items[i]
  end
  if #items > maxn then
    shown[#shown + 1] = "(+" .. tostring(#items - maxn) .. " more)"
  end
  return table.concat(shown, ", ")
end

local function wait_for_mason_installation()
  local ok_registry, registry = pcall(require, "mason-registry")
  if not ok_registry then
    info("mason-registry unavailable; skipping install wait")
    return
  end

  local timeout_ms = tonumber(vim.env.NVIM_POST_CHECK_MASON_TIMEOUT_MS) or 900000
  local poll_ms = tonumber(vim.env.NVIM_POST_CHECK_MASON_POLL_MS) or 1000

  local ensure_specs = get_mason_ensure_specs()
  if #ensure_specs == 0 then
    info("No Mason ensure_installed packages configured")
    return
  end

  local ok_refresh, refresh_err = pcall(registry.refresh)
  if not ok_refresh then
    info("Mason registry refresh failed: " .. tostring(refresh_err))
  end

  local targets = {}
  local seen = {}
  for _, spec in ipairs(ensure_specs) do
    local name, version = parse_package_spec(spec)
    if name ~= "" and not seen[name] then
      local ok_has, has_pkg = pcall(registry.has_package, name)
      if ok_has and has_pkg then
        local ok_get, pkg = pcall(registry.get_package, name)
        if ok_get and pkg then
          targets[#targets + 1] = {
            name = name,
            version = version,
            pkg = pkg,
          }
          seen[name] = true
        else
          info("Skipping unknown Mason package: " .. name)
        end
      else
        info("Skipping unavailable Mason package: " .. name)
      end
    end
  end

  if #targets == 0 then
    info("No valid Mason package targets found")
    return
  end

  local install_failures = {}
  for _, target in ipairs(targets) do
    if not target.pkg:is_installed() and not target.pkg:is_installing() then
      local target_name = target.name
      local ok_install, install_err = pcall(target.pkg.install, target.pkg, { version = target.version }, function(success, err)
        if not success then
          install_failures[target_name] = tostring(err)
        end
      end)
      if not ok_install then
        install_failures[target_name] = tostring(install_err)
      end
    end
  end

  local ok_all, all_packages = pcall(registry.get_all_packages)
  if not ok_all or type(all_packages) ~= "table" then
    all_packages = {}
    for _, target in ipairs(targets) do
      all_packages[#all_packages + 1] = target.pkg
    end
  end

  local function get_active_package_names()
    local active = {}
    for _, pkg in ipairs(all_packages) do
      if pkg:is_installing() then
        active[#active + 1] = pkg.name
      end
    end
    table.sort(active)
    return active
  end

  local function get_missing_target_names()
    local missing = {}
    for _, target in ipairs(targets) do
      if not target.pkg:is_installed() then
        missing[#missing + 1] = target.name
      end
    end
    table.sort(missing)
    return missing
  end

  local deadline = vim.loop.hrtime() / 1000000 + timeout_ms
  local last_status = nil
  while true do
    local missing = get_missing_target_names()
    local active = get_active_package_names()

    if #missing == 0 and #active == 0 then
      info("Mason ensure_installed packages ready")
      return
    end

    if next(install_failures) ~= nil and #active == 0 then
      local parts = {}
      for name, err in pairs(install_failures) do
        parts[#parts + 1] = name .. ": " .. err
      end
      table.sort(parts)
      fail("Mason installation failed: " .. table.concat(parts, "; "))
    end

    local now = vim.loop.hrtime() / 1000000
    if now >= deadline then
      fail(
        "Timed out waiting for Mason installations."
          .. " missing="
          .. list_or_none(missing)
          .. " active="
          .. list_or_none(active)
      )
    end

    local status = "Waiting for Mason installs: missing=" .. list_or_none(missing) .. " active=" .. list_or_none(active)
    if status ~= last_status then
      info(status)
      last_status = status
    end
    vim.wait(poll_ms)
  end
end

local function wait_for_treesitter_installation()
  local ensure_languages = get_treesitter_ensure_languages()
  if #ensure_languages == 0 then
    info("No Tree-sitter ensure_installed languages configured")
    return
  end

  local ok_config, ts_config = pcall(require, "nvim-treesitter.config")
  local ok_install, ts_install = pcall(require, "nvim-treesitter.install")
  if not ok_config or not ok_install then
    info("Tree-sitter modules unavailable; skipping parser wait")
    return
  end

  local installed_list = ts_config.get_installed() or {}
  local installed = {}
  for _, lang in ipairs(installed_list) do
    installed[lang] = true
  end

  local missing = {}
  for _, lang in ipairs(ensure_languages) do
    if not installed[lang] then
      missing[#missing + 1] = lang
    end
  end
  table.sort(missing)

  if #missing == 0 then
    info("Tree-sitter ensure_installed languages ready")
    return
  end

  info("Installing missing Tree-sitter languages: " .. list_or_none(missing))
  local timeout_ms = tonumber(vim.env.NVIM_POST_CHECK_TREESITTER_TIMEOUT_MS) or 900000
  local task = ts_install.install(missing, { summary = true })
  if not task or type(task.wait) ~= "function" then
    fail("Tree-sitter install task did not start")
  end

  local ok_wait, wait_err = pcall(task.wait, task, timeout_ms)
  if not ok_wait then
    fail("Tree-sitter installation failed: " .. tostring(wait_err))
  end

  local after = {}
  for _, lang in ipairs(ts_config.get_installed() or {}) do
    after[lang] = true
  end
  local remaining = {}
  for _, lang in ipairs(ensure_languages) do
    if not after[lang] then
      remaining[#remaining + 1] = lang
    end
  end
  table.sort(remaining)
  if #remaining > 0 then
    fail("Tree-sitter languages still missing after install: " .. list_or_none(remaining))
  end

  info("Tree-sitter ensure_installed languages ready")
end

local noice_cmd_ok = run_first_available({
  { command = "NoiceLog", invocation = "NoiceLog" },
  { command = "Noice", invocation = "Noice history" },
}, "Noice")

local mason_cmd_ok = run_first_available({
  { command = "MasonLog", invocation = "MasonLog" },
  { command = "Mason", invocation = "Mason" },
}, "Mason")

wait_for_mason_installation()
wait_for_treesitter_installation()

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
