-- Toggle a Quick Access Terminal (QAT) panel from nvim's <M-t>.
--
-- The QAT is a floating dropdown terminal that overlays nvim. Re-sending the
-- same `kitten quick-access-terminal` launch with the same --instance-group
-- flips its visibility (show/hide) instead of spawning a new one, so the panel
-- (and whatever runs in it) stays alive between toggles — it is minimised, not
-- closed. Mirrors linkarzu's kitty setup.
--
-- `dir` (optional): cd the panel there on a cold start.

local M = {}

local INSTANCE_GROUP = "nvim-term"
local QAT_CONFIG = vim.fn.expand("~/dotfiles/kitty/quick-access-terminal-right.conf")

M.open = function(dir)
  local file_dir = dir or vim.fn.expand("%:p:h")
  local escaped_dir = file_dir:gsub("'", "'\\''")

  -- --type=background: toggle the panel without spawning a regular window.
  -- On a cold start, start an interactive zsh in the target directory.
  local cmd = "kitten @ launch --type=background kitten quick-access-terminal"
    .. " --config '"
    .. QAT_CONFIG
    .. "' --instance-group "
    .. INSTANCE_GROUP
    .. " zsh -i -c 'cd \""
    .. escaped_dir
    .. "\"; exec zsh'"

  vim.fn.system(cmd)
end

return M
