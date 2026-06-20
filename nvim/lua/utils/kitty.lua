-- Toggle a kitty window (right or bottom) with zsh in the directory of the
-- current file, or in `dir` if provided.
--
-- Behavior:
--   * No companion window exists -> launch a new one (vsplit or hsplit) and
--     cd into target dir.
--   * Companion window exists, not in stack layout -> toggle_layout stack
--     (fills the tab with the current nvim window, like tmux zoom).
--   * Companion window exists, already in stack layout -> unstack, focus the
--     companion window, and (if auto_cd_to_new_dir) cd into the new directory
--     when it differs from the previously remembered one.
--
-- Reads vim.g.tmux_pane_direction for call-site compatibility:
--   "right" (default) -> vsplit (side-by-side)
--   anything else     -> hsplit (top/bottom)

local M = {}

-- Parse `kitten @ ls` JSON and return the focused OS window's focused tab
-- table (with .layout and .windows). Returns nil on error.
local function get_focused_tab()
  local raw = vim.fn.system("kitten @ ls")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return nil
  end
  -- data is a list of OS windows
  for _, os_win in ipairs(data) do
    if os_win.is_focused then
      for _, tab in ipairs(os_win.tabs or {}) do
        if tab.is_focused then
          return tab
        end
      end
    end
  end
  return nil
end

-- Return true if the focused tab is currently in stack layout.
-- NOTE: kitty reports the layout on the TAB (tab.layout), not on windows.
local function is_stack_layout()
  local tab = get_focused_tab()
  return tab ~= nil and tab.layout == "stack"
end

-- Return true when more than one window exists in the focused tab.
local function has_companion()
  local tab = get_focused_tab()
  if not tab or not tab.windows then
    return false
  end
  return #tab.windows > 1
end

M.open = function(dir)
  local auto_cd_to_new_dir = true
  -- Honour the existing call-site global for direction
  local pane_direction = vim.g.tmux_pane_direction or "right"
  local split_location = (pane_direction == "right") and "vsplit" or "hsplit"

  local file_dir = dir or vim.fn.expand("%:p:h")
  local escaped_dir = file_dir:gsub("'", "'\\''")

  local move = (pane_direction == "right") and "right" or "down"

  if has_companion() then
    -- A companion window exists. <M-t> should jump focus to the companion
    -- (the terminal) and zoom it, so we land *inside* the terminal.
    if auto_cd_to_new_dir and vim.g.kitty_pane_dir ~= escaped_dir then
      -- cd the companion (the unfocused window) to the new directory.
      vim.fn.system(
        "kitten @ send-text --match='not state:focused' 'cd \"" .. escaped_dir .. "\"\n'"
      )
      vim.g.kitty_pane_dir = escaped_dir
    end
    -- Ensure we're zoomed (stack), then move focus to the neighbouring window.
    -- In stack layout the focused window fills the tab, so this lands us in
    -- the terminal at full size.
    if not is_stack_layout() then
      vim.fn.system("kitten @ action goto_layout stack")
    end
    vim.fn.system("kitten @ action neighboring_window " .. move)
  else
    -- No companion yet: launch one and focus *into* it (no --keep-focus).
    if vim.g.kitty_pane_dir == nil then
      vim.g.kitty_pane_dir = escaped_dir
    end
    vim.fn.system(
      "kitten @ launch --location="
        .. split_location
        .. " --cwd '"
        .. escaped_dir
        .. "' --env DISABLE_PULL=1 zsh"
    )
  end
end

return M
