local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()
local is_windows = wezterm.target_triple:find("windows") ~= nil

config.default_domain = "local"
config.term = "xterm-256color"
config.enable_kitty_keyboard = false

if is_windows then
  config.default_prog = { "powershell.exe", "-NoLogo" }

  local launch_menu = {
    {
      label = "Windows PowerShell",
      args = { "powershell.exe", "-NoLogo" },
      domain = { DomainName = "local" },
    },
  }

  local has_wsl_domains, wsl_domains = pcall(wezterm.default_wsl_domains)
  if has_wsl_domains then
    for _, domain in ipairs(wsl_domains) do
      local label = domain.distribution or domain.name:gsub("^WSL:", "")
      table.insert(launch_menu, {
        label = label .. " (WSL)",
        domain = { DomainName = domain.name },
      })
    end
  end

  config.launch_menu = launch_menu
end

if not is_windows then
  config.launch_menu = {
    {
      label = "Default Shell",
      domain = { DomainName = "local" },
    },
  }
end

config.automatically_reload_config = true
config.check_for_updates = false

config.font = wezterm.font_with_fallback({
  "CaskaydiaCove Nerd Font Mono",
  "Cascadia Mono",
  "Consolas",
})
config.font_size = 11.0

config.color_scheme = "Catppuccin Mocha"
config.window_background_opacity = 0.96
config.window_decorations = "TITLE|RESIZE"
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.audible_bell = "Disabled"

config.inactive_pane_hsb = {
  saturation = 0.8,
  brightness = 0.65,
}

config.window_padding = {
  left = 6,
  right = 6,
  top = 4,
  bottom = 2,
}

config.leader = {
  key = "b",
  mods = "CTRL",
  timeout_milliseconds = 1000,
}

config.keys = {
  { key = "l", mods = "ALT", action = act.ShowLauncherArgs({ flags = "LAUNCH_MENU_ITEMS|DOMAINS" }) },
  -- tmux-like leader bindings.
  { key = "b", mods = "LEADER|CTRL", action = act.SendKey({ key = "b", mods = "CTRL" }) },
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "&", mods = "LEADER|SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "Space", mods = "LEADER", action = act.RotatePanes("Clockwise") },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
  { key = "w", mods = "LEADER", action = act.ShowTabNavigator },

  -- Split panes like tmux: prefix % for horizontal, prefix " for vertical.
  { key = "%", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "\"", mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

  -- Prefix + hjkl also moves panes, useful when an application consumes Ctrl-h/j/k/l.
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

  -- Prefix + arrows resize panes, similar to tmux resize-pane.
  { key = "LeftArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Left", 5 }) },
  { key = "DownArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Down", 5 }) },
  { key = "UpArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Up", 5 }) },
  { key = "RightArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Right", 5 }) },
}

return config
