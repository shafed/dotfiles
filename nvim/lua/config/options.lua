-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.spell = true
vim.opt.spelllang = { "en", "ru" }

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.textwidth = 80
vim.opt.colorcolumn = "80"
vim.g.markdown_recommended_style = 0
vim.opt.termguicolors = true
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.mouse = "a"
vim.opt.scrolloff = 8
vim.opt.swapfile = false
vim.opt.cursorline = true

-- убрать clipboard из постоянной синхронизации
vim.opt.clipboard = ""

vim.g.snacks_animate = false

vim.opt.conceallevel = 2

vim.opt.langmap =
  "ФИСВУАПРШОЛДЬТЩЗЙКЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRTUVWXYZ,фисвуапршолдьтщзйкегмцчня;abcdefghijklmnopqrtuvwxyz"

-- Winbar: shows "(buffer count) filename" on the left and the directory path
-- on the right, per window. Using winbar (not lualine's tabline/showtabline)
-- means this never depends on bufferline's own showtabline logic, which used
-- to hide the line after <leader>bo.
-- Colors match gruvbox-material "medium" background (StatusLine/WinBar bg,
-- Fg/Grey foregrounds).
local function set_winbar_highlights()
  vim.api.nvim_set_hl(0, "WinBarCount", { fg = "#d8a657", bg = "#32302f", bold = true })
  vim.api.nvim_set_hl(0, "WinBarFile", { fg = "#ddc7a1", bg = "#32302f", bold = true })
  vim.api.nvim_set_hl(0, "WinBarPath", { fg = "#928374", bg = "#32302f" })
end
set_winbar_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_winbar_highlights })

local function get_winbar_path()
  local path = vim.fn.expand("%:p:h")
  if path == "" or path == "." then
    path = vim.fn.getcwd()
  end
  local home = os.getenv("HOME")
  if home then
    path = path:gsub("^" .. home, "~")
  end
  local max_len = 40
  if #path > max_len then
    path = "..." .. path:sub(-max_len + 3)
  end
  return path
end

local function update_winbar()
  local buf_count = #vim.fn.getbufinfo({ buflisted = 1 })
  vim.opt_local.winbar = "%#WinBarCount#("
    .. buf_count
    .. ") "
    .. "%#WinBarFile#%t"
    .. "%*%=%#WinBarPath#"
    .. get_winbar_path()
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufDelete", "WinEnter", "VimEnter" }, {
  callback = function()
    vim.schedule(update_winbar)
  end,
})
