-- Langmap
vim.opt.langmap = table.concat({
  -- верхний ряд
  "йq,цw,уe,кr,еt,нy,гu,шi,щo,зp,х[,ъ],",
  "ЙQ,ЦW,УE,КR,ЕT,НY,ГU,ШI,ЩO,ЗP,Х{,Ъ},",
  -- средний ряд
  "фa,ыs,вd,аf,пg,рh,оj,лk,дl,ж\\;,э\\',",
  "ФA,ЫS,ВD,АF,ПG,РH,ОJ,ЛK,ДL,Ж\\:,Э\\\",",
  -- нижний ряд
  "яz,чx,сc,мv,иb,тn,ьm,б\\,,ю\\.,ё\\`,",
  "ЯZ,ЧX,СC,МV,ИB,ТN,ЬM,Б\\<,Ю\\>,Ё\\~",
}, "")
-- Базовые настройки
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.termguicolors = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.mouse = "a"
vim.opt.scrolloff = 8
vim.opt.swapfile = false
vim.opt.cursorline = true

vim.g.mapleader = " "

-- Настройка копирования
vim.g.clipboard = {
  name = 'win32yank',
  copy = {
    ['+'] = 'win32yank.exe -i --crlf',
    ['*'] = 'win32yank.exe -i --crlf',
  },
  paste = {
    ['+'] = 'win32yank.exe -o --lf',
    ['*'] = 'win32yank.exe -o --lf',
  },
  cache_enabled = 0,
}

-- Установка lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Настройка плагинов
require("lazy").setup({
  -- Плагин для подсветки синтаксиса
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "python", "lua", "markdown", "markdown_inline" },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true
        },
      })
    end
  },

  -- LSP для Python
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      
      -- Настройка диагностики
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = false,
        update_in_insert = false,
      })
      
      -- Настройка pyright
      lspconfig.pyright.setup({
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
            }
          }
        },
        -- Настройки для лучшего отображения типов
        capabilities = (function()
          local capabilities = vim.lsp.protocol.make_client_capabilities()
          capabilities.textDocument.hover = {
            dynamicRegistration = true,
            contentFormat = { "markdown", "plaintext" }
          }
          return capabilities
        end)(),
      })
      
      -- Клавиши для LSP
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc = "Go to implementation" })
      vim.keymap.set('n', 'K', vim.lsp.buf.hover)
      vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action)
      vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references)
    end
  },

  -- Автодополнение
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = {
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          ['<C-d>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-e>'] = cmp.mapping.close(),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          },
          ['<Tab>'] = function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end,
          ['<S-Tab>'] = function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end,
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        },
      })
    end
  },

  -- Форматирование и линтинг
  {
    "stevearc/conform.nvim",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          python = { "ruff_format", "ruff_organize_imports" },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
      })
      vim.keymap.set('n', '<leader>f', function()
        require("conform").format()
      end, { desc = "Format code" })
    end
  },

  -- Дерево файлов
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        -- Отключаем netrw полностью
        disable_netrw = true,
        hijack_netrw = true,
        -- Другие настройки
        view = {
          width = 30,
          side = "left",
        },
        renderer = {
          group_empty = true,
        },
        filters = {
          dotfiles = false,
        },
      })
      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>')
    end
  },

  -- Поиск файлов
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope")
      telescope.setup()
      -- Удобные хоткеи для поиска
      vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<CR>', { desc = "Поиск файла" })
      vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', { desc = "Поиск по содержимому" })
      vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<CR>', { desc = "Список открытых буферов" })
      vim.keymap.set('n', '<leader>fh', '<cmd>Telescope help_tags<CR>', { desc = "Поиск по :help" })
    end
  },

  -- LSP signature help (красивые подсказки)
  {
    "ray-x/lsp_signature.nvim",
    event = "LspAttach",
    config = function()
      require("lsp_signature").setup({
        bind = true,
        handler_opts = {
          border = "rounded"
        },
        hint_enable = false, -- убрать inline-подсказки, если мешают
      })
    end
  },

    -- Переключение раскладки
  {
    "keaising/im-select.nvim",
    config = function()
      require("im_select").setup({
      default_im_select = "1033",
      default_command = "im-select.exe",
      set_default_events = {"InsertLeave", "CmdLineLeave" },
  })
    end,
  },


  -- Цветовые схемы

  -- Gruvbox Material
  {
    "sainnhe/gruvbox-material",
    priority = 1000,
    config = function()
      -- Доступные варианты: 'hard', 'medium'(default), 'soft'
      vim.g.gruvbox_material_background = 'medium'
      
      -- Доступные варианты: 'material', 'mix', 'original'
      vim.g.gruvbox_material_foreground = 'material'
      
      vim.g.gruvbox_material_disable_italic_comment = 0
      vim.g.gruvbox_material_enable_bold = 1
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_cursor = 'auto'
      vim.g.gruvbox_material_transparent_background = 0
      vim.g.gruvbox_material_visual = 'reverse'
      vim.g.gruvbox_material_menu_selection_background = 'grey'
      vim.g.gruvbox_material_sign_column_background = 'none'
      vim.g.gruvbox_material_spell_foreground = 'none'
      vim.g.gruvbox_material_ui_contrast = 'low'
      vim.g.gruvbox_material_show_eob = 1
      vim.g.gruvbox_material_diagnostic_text_highlight = 1
      vim.g.gruvbox_material_diagnostic_line_highlight = 0
      vim.g.gruvbox_material_diagnostic_virtual_text = 'colored'
      vim.g.gruvbox_material_current_word = 'grey background' 
      vim.g.gruvbox_material_disable_terminal_colors = 0
      vim.g.gruvbox_material_statusline_style = 'material'
      vim.g.gruvbox_material_lightline_disable_bold = 0
      vim.g.gruvbox_material_better_performance = 0
    end,
  },

})

-- Устанавливаем основную тему
vim.cmd.colorscheme "gruvbox-material"

-- Дополнительные хоткеи
-- Навигация по буферам
vim.keymap.set('n', 'gn', ':bnext<CR>', { desc = "Next buffer" })
vim.keymap.set('n', 'gp', ':bprevious<CR>', { desc = "Previous buffer" })
vim.keymap.set('n', 'gw', ':bdelete<CR>', { desc = "Close buffer" })

-- Удобные хоткеи для работы с системным буфером 
-- Копирование в системный буфер
vim.keymap.set({'n', 'v'}, '<leader>y', '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set('n', '<leader>Y', '"+Y', { desc = "Copy line to system clipboard" })

-- Вставка из системного буфера
vim.keymap.set({'n', 'v'}, '<leader>p', '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({'n', 'v'}, '<leader>P', '"+P', { desc = "Paste before from system clipboard" })

-- Вырезание в системный буфер
vim.keymap.set({'n', 'v'}, '<leader>d', '"+d', { desc = "Cut to system clipboard" })

-- ^ -> H, $ -> L
vim.keymap.set({'n', 'v', 'o'}, 'H', '^', { desc = "Go to first non-blank character" })
vim.keymap.set({'n', 'v', 'o'}, 'L', '$', { desc = "Go to end of line" })

-- Отключение подсветки поиска
vim.keymap.set('n', '<leader><space>', ':nohlsearch<CR>', { desc = "Clear search highlight" })

-- Запуск Python файлов
vim.keymap.set('n', '<C-h>', ':w<CR>:!python3 %<CR>', { desc = "Run Python file" })
vim.keymap.set('i', '<C-h>', '<Esc>:w<CR>:!python3 %<CR>', { desc = "Run Python file" })

-- Перемещение строк Alt+j/k
vim.keymap.set('n', '<C-j>', ':m .+1<CR>==', { desc = "Move line down" })
vim.keymap.set('n', '<C-k>', ':m .-2<CR>==', { desc = "Move line up" })
vim.keymap.set('i', '<C-j>', '<Esc>:m .+1<CR>==gi', { desc = "Move line down" })
vim.keymap.set('i', '<C-k>', '<Esc>:m .-2<CR>==gi', { desc = "Move line up" })
vim.keymap.set('v', '<C-j>', ':m \'>+1<CR>gv=gv', { desc = "Move selection down" })
vim.keymap.set('v', '<C-k>', ':m \'<-2<CR>gv=gv', { desc = "Move selection up" })


-- Автокоманды
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "init.lua",
  command = "echo 'init.lua saved! Restart nvim to apply changes'",
})

-- Колонка для Python файлов (PEP 8)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.colorcolumn = "88"
  end,
})

-- Настройка LSP handlers с подсветкой синтаксиса
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
  max_width = 80,
  max_height = 20,
  focusable = false,
  close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
})
