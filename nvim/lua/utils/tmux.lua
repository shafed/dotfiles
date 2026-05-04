-- Toggle a tmux pane (right or bottom) with zsh in the directory of the
-- current file, or in `dir` if provided. Adapted from linkarzu's dotfiles
-- for Arch Linux (no macOS-specific bits).
--
-- Behavior:
--   * No extra pane exists -> split a new one and cd into target dir.
--   * Extra pane exists, current pane not zoomed -> zoom current pane.
--   * Extra pane exists, current pane zoomed -> unzoom, jump to other
--     pane, and (if auto_cd_to_new_dir) cd into the new directory when
--     it differs from the previously remembered one.

local M = {}

M.open = function(dir)
  local auto_cd_to_new_dir = true
  local pane_direction = vim.g.tmux_pane_direction or "right"
  local pane_size = (pane_direction == "right") and 60 or 15
  local move_key = (pane_direction == "right") and "C-l" or "C-k"
  local split_cmd = (pane_direction == "right") and "-h" or "-v"

  local file_dir = dir or vim.fn.expand("%:p:h")
  local has_panes = vim.fn.system("tmux list-panes | wc -l"):gsub("%s+", "") ~= "1"
  local is_zoomed = vim.fn.system("tmux display-message -p '#{window_zoomed_flag}'"):gsub("%s+", "") == "1"
  local escaped_dir = file_dir:gsub("'", "'\\''")

  if has_panes then
    if is_zoomed then
      if auto_cd_to_new_dir and vim.g.tmux_pane_dir ~= escaped_dir then
        vim.fn.system("tmux send-keys -t :.+ 'cd \"" .. escaped_dir .. "\"' Enter")
        vim.g.tmux_pane_dir = escaped_dir
      end
      vim.fn.system("tmux resize-pane -Z")
      vim.fn.system("tmux send-keys " .. move_key)
    else
      vim.fn.system("tmux resize-pane -Z")
    end
  else
    if vim.g.tmux_pane_dir == nil then
      vim.g.tmux_pane_dir = escaped_dir
    end
    vim.fn.system(
      "tmux split-window "
        .. split_cmd
        .. " -l "
        .. pane_size
        .. " 'cd \""
        .. escaped_dir
        .. "\" && DISABLE_PULL=1 zsh'"
    )
  end
end

return M
