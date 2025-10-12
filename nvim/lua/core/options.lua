vim.opt.spell = true
vim.opt.spelllang = { "en", "ru" }
vim.keymap.set("i", "<C-l>", "<c-g>u<Esc>[s1z=`]a<c-g>u", { silent = true })

vim.g.mapleader = " "
                        
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.termguicolors = true
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.mouse = "a"
vim.opt.scrolloff = 8
vim.opt.swapfile = false
vim.opt.cursorline = true

vim.opt.conceallevel = 2

-- Автодополнение скобок (базовые настройки)
vim.opt.showmatch = true -- показывать совпадающие скобки vim.opt.matchtime = 1 -- время показа совпадения (в десятых долях секунды)
vim.opt.matchpairs = "(:),{:},[:],<:>" -- пары символов для показа совпадений

-- VimTeX конфигурация
vim.g.maplocalleader = " "
--vim.g.vimtex_view_method = 'zathura'
--vim.g.vimtex_view_automatic = 0
--vim.g.vimtex_view_forward_search_on_start = 0

--vim.g.vimtex_compiler_method = 'latexmk'

--vim.g.vimtex_view_general_options = '--fullscreen @pdf'

-- Настройка VimTeX для WSL с SumatraPDF
vim.g.vimtex_view_method = 'general'
vim.g.vimtex_view_general_viewer = '/mnt/c/Users/shapa/AppData/Local/SumatraPDF/SumatraPDF.exe'
vim.g.vimtex_view_general_options = '-reuse-instance @pdf'

-- Дополнительные настройки VimTeX
vim.g.vimtex_compiler_method = 'latexmk'
vim.g.vimtex_quickfix_mode = 0

-- Опционально: отключить предупреждения о совместимости
vim.g.vimtex_compiler_silent = 1
