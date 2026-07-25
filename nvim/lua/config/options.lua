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

-- ЙЦУКЕН → QWERTY in normal mode. Safety net for the RU-layout auto-switch in
-- autocmds.lua: catches keys typed in the short window before the async
-- hyprctl switch lands. Punctuation pairs keep the same physical keys as US
-- (ж→; б→, ю→. etc.); `;` and `,` are langmap metachars, hence the escapes.
-- Do not map the literal US `.`/`,` to `/`/`?`: langmap cannot tell which
-- keyboard layout produced them, so those pairs break `.` repeat in normal
-- mode after the layout has already switched to US.
vim.opt.langmap = {
  "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  "фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz",
  "ж\\;",
  "Ж:",
  "б\\,",
  "Б<",
  "ю.",
  "Ю>",
  "х[",
  "Х{",
  "ъ]",
  "Ъ}",
  "э'",
  'Э"',
  "ё`",
  "Ё~",
}

-- Winbar: see nvim/lua/utils/winbar.lua for the "(buffer count) filename" +
-- dir path bar. Split out into its own module so Snacks.zen (config in
-- plugins/snacks.lua) can force it off across all windows while zen mode is
-- open.
require("utils.winbar").setup()
