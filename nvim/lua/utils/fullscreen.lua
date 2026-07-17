-- Make the OS chrome around nvim match Snacks.zen: fullscreen the Hyprland
-- window and hide kitty's tab bar while zen mode is open, restoring both on
-- close.
local M = {}

M.zen_fullscreened = false

local function get_active_window()
  if vim.fn.executable("hyprctl") == 0 then
    return nil
  end
  local out = vim.fn.system({ "hyprctl", "-j", "activewindow" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local ok, data = pcall(vim.json.decode, out)
  if not ok or type(data) ~= "table" then
    return nil
  end
  return data
end

-- `hyprctl dispatch fullscreen 0` is a toggle, so this only calls it on open
-- when the window isn't already fullscreen, and only calls it again on close
-- if this module is the one that turned it on (avoids un-fullscreening a
-- window the user had already fullscreened themselves before entering zen).
local function set_hyprland_fullscreen(active)
  if active then
    local win = get_active_window()
    if win and win.fullscreen == 0 then
      vim.fn.system({ "hyprctl", "dispatch", "fullscreen", "0" })
      M.zen_fullscreened = true
    else
      M.zen_fullscreened = false
    end
  elseif M.zen_fullscreened then
    vim.fn.system({ "hyprctl", "dispatch", "fullscreen", "0" })
    M.zen_fullscreened = false
  end
end

-- kitty has no remote-control command to toggle the tab bar at runtime
-- (tab_bar_hidden is only ever set once at startup from tab_bar_style) so
-- this drives the custom kitten in kitty/toggle_tab_bar.py, which pokes the
-- internal TabManager API directly.
local function set_kitty_tab_bar(shown)
  if vim.fn.executable("kitten") == 0 then
    return
  end
  vim.fn.system({ "kitten", "@", "kitten", "toggle_tab_bar.py", shown and "show" or "hide" })
end

function M.set_zen(active)
  set_hyprland_fullscreen(active)
  set_kitty_tab_bar(not active)
end

return M
