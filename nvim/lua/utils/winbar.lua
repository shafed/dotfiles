-- Custom winbar: "(buffer count) filename" on the left, dir path on the
-- right, per window. Using winbar (not lualine's tabline/showtabline) means
-- this never depends on bufferline's own showtabline logic, which used to
-- hide the line after <leader>bo.
--
-- Exposed as a module (rather than living inline in options.lua) so the zen
-- toggle (plugins/snacks.lua) can force it off on every window while zen mode
-- is open.
local M = {}

M.zen_active = false

-- Colors match gruvbox-material "medium" background (StatusLine/WinBar bg,
-- Fg/Grey foregrounds).
local function set_highlights()
  vim.api.nvim_set_hl(0, "WinBarCount", { fg = "#d8a657", bg = "#32302f", bold = true })
  vim.api.nvim_set_hl(0, "WinBarFile", { fg = "#ddc7a1", bg = "#32302f", bold = true })
  vim.api.nvim_set_hl(0, "WinBarPath", { fg = "#928374", bg = "#32302f" })
end

local function get_path()
  local path = vim.fn.expand("%:p:h")
  if path == "" or path == "." then
    path = vim.fn.getcwd()
  end
  local home = os.getenv("HOME")
  if home and path:sub(1, #home) == home then
    path = "~" .. path:sub(#home + 1)
  end
  local max_len = 40
  if #path > max_len then
    path = "..." .. path:sub(-max_len + 3)
  end
  return path
end

function M.update()
  -- Skip floating windows (e.g. mini.files' explorer panes): they draw their
  -- own border title and setting winbar on them stacks a garbled extra line
  -- (raw buffer name like "minifiles://2//home/shafed") above the content.
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  if M.zen_active then
    vim.opt_local.winbar = ""
    return
  end
  local buf_count = #vim.fn.getbufinfo({ buflisted = 1 })
  vim.opt_local.winbar = "%#WinBarCount#("
    .. buf_count
    .. ") "
    .. "%#WinBarFile#%t"
    .. "%*%=%#WinBarPath#"
    .. get_path()
end

-- Called from the zen toggle in plugins/snacks.lua: hide winbar on every
-- normal window while zen mode is active, restore it everywhere when it
-- closes.
function M.set_zen(active)
  M.zen_active = active
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      vim.api.nvim_win_call(win, M.update)
    end
  end
end

function M.setup()
  set_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufDelete", "WinEnter", "VimEnter" }, {
    callback = function()
      vim.schedule(M.update)
    end,
  })
end

return M
