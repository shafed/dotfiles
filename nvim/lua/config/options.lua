-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.spell = true
vim.opt.spelllang = { "en", "ru" }
vim.keymap.set("i", "<C-l>", "<c-g>u<Esc>[s1z=`]a<c-g>u", { silent = true })

vim.g.mapleader = " "

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
