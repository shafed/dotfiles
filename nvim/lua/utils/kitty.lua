-- Toggle a companion kitty terminal window beside nvim, in the directory of
-- the current file (or in `dir` if provided).
--
-- Behavior (pure open/close toggle):
--   * No companion window -> launch one (vsplit or hsplit) and focus into it.
--   * Companion window exists -> close it and return to nvim.
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
  -- Honour the existing call-site global for direction
  local pane_direction = vim.g.tmux_pane_direction or "right"
  local split_location = (pane_direction == "right") and "vsplit" or "hsplit"

  local file_dir = dir or vim.fn.expand("%:p:h")
  local escaped_dir = file_dir:gsub("'", "'\\''")

  if has_companion() then
    -- Toggle OFF: a companion terminal exists -> close it and return to nvim.
    -- This call comes from nvim (focus is on nvim), so close every other
    -- window in the focused tab.
    vim.fn.system("kitten @ close-window --match='not state:focused'")
    vim.g.kitty_pane_dir = nil
  else
    -- Toggle ON: no companion -> launch one beside nvim and focus into it.
    vim.g.kitty_pane_dir = escaped_dir
    -- Make sure the tab is in a split layout first; launching in stack would
    -- open the new window full-screen instead of to the side.
    if is_stack_layout() then
      vim.fn.system("kitten @ action goto_layout tall")
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
