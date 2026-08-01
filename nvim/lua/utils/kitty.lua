-- Toggle a companion kitty terminal window (right or bottom) with zsh in the
-- directory of the current file, or in `dir` if provided. Ported from the
-- original tmux implementation (linkarzu), adapted to kitty remote control.
--
-- Behavior (mirrors the tmux `resize-pane -Z` zoom toggle):
--   * No companion window -> split a new one and cd into target dir.
--   * Companion exists, not zoomed (stack) -> zoom the current window.
--   * Companion exists, zoomed -> unzoom, jump to the other window, and
--     (if auto_cd_to_new_dir) cd into the new directory when it changed.
--
-- Reads vim.g.tmux_pane_direction:
--   "right" (default) -> vsplit (side-by-side)
--   anything else     -> hsplit (top/bottom)

local M = {}

-- Return the focused OS window's focused tab table (.layout, .windows).
local function get_focused_tab()
  local raw = vim.fn.system("kitten @ ls")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return nil
  end
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

-- kitty reports the layout on the TAB (tab.layout), not on windows.
local function is_zoomed(tab)
  return tab ~= nil and tab.layout == "stack"
end

local function has_companion(tab)
  return tab ~= nil and tab.windows and #tab.windows > 1
end

-- The non-active window in the tab (the companion terminal, since nvim's own
-- window is always the active one when <M-t> is pressed from nvim). Matching
-- by id is used instead of `--match='not state:focused'`: in a stack layout
-- that negation is unreliable and can resolve to the active (nvim) window,
-- sending the cd text into the nvim buffer instead of the terminal.
local function companion_window_id(tab)
  if not tab or not tab.windows then
    return nil
  end
  for _, win in ipairs(tab.windows) do
    if not win.is_active then
      return win.id
    end
  end
  return nil
end

M.open = function(dir)
  local auto_cd_to_new_dir = true
  local pane_direction = vim.g.tmux_pane_direction or "right"
  local split_location = (pane_direction == "right") and "vsplit" or "hsplit"
  local move = (pane_direction == "right") and "right" or "down"

  local file_dir = dir or vim.fn.expand("%:p:h")
  local escaped_dir = file_dir:gsub("'", "'\\''")

  local tab = get_focused_tab()

  if has_companion(tab) then
    if is_zoomed(tab) then
      -- Zoomed -> unzoom, then jump to the other (companion) window.
      local companion_id = companion_window_id(tab)
      if auto_cd_to_new_dir and companion_id and vim.g.kitty_pane_dir ~= escaped_dir then
        vim.fn.system("kitten @ send-text --match=id:" .. companion_id .. " 'cd \"" .. escaped_dir .. "\"\n'")
        vim.g.kitty_pane_dir = escaped_dir
      end
      vim.fn.system("kitten @ action goto_layout tall")
      vim.fn.system("kitten @ action neighboring_window " .. move)
    else
      -- Not zoomed -> zoom the current window (stack layout).
      vim.fn.system("kitten @ action goto_layout stack")
    end
  else
    -- No companion yet -> split a new one beside nvim, as a narrow edge-right
    -- pane (not half/full screen).
    if vim.g.kitty_pane_dir == nil then
      vim.g.kitty_pane_dir = escaped_dir
    end
    -- Make sure the tab is in a split layout first; launching in stack would
    -- open the new window full-screen instead of to the side.
    if tab and tab.layout ~= "tall" then
      vim.fn.system("kitten @ action goto_layout tall")
    end
    -- --bias sets the new window's size: ~35% width for a vsplit (right edge),
    -- ~30% height for an hsplit (bottom edge).
    local bias = (pane_direction == "right") and 49 or 30
    vim.fn.system(
      "kitten @ launch --location="
        .. split_location
        .. " --bias "
        .. bias
        .. " --add-to-session . --cwd '"
        .. escaped_dir
        .. "' --env DISABLE_PULL=1 zsh"
    )
  end
end

return M
