return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  lazy = false,
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/obsidiansync/",
      },
    },

    new_notes_location = "notes_subdir",
    notes_subdir = "base/notes",
    legacy_commands = false,
    footer = {
      enabled = false,
    },
    
    -- ID всегда timestamp (для стабильности ссылок)
    note_id_func = function(title)
      return tostring(os.time())
    end,
    
    -- Использовать title как имя файла
    note_path_func = function(spec)
      -- spec содержит: id, dir, title
      local path = spec.dir / tostring(spec.title or spec.id)
      return path:with_suffix(".md")
    end,
    
    -- Новый формат для frontmatter
    frontmatter = {
      func = function(note)
        local out = {
          id = note.id,
          aliases = {},  -- Пустой массив aliases
          tags = note.tags,
        }
        
        -- Сохранить существующие поля из метаданных
        if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
          for k, v in pairs(note.metadata) do
            out[k] = v
          end
        end
        
        return out
      end,
    },
  },

 config = function(_, opts) -- <leader>ff Obsidian search
    require("obsidian").setup(opts)
    
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "*.md",
      callback = function()
        if package.loaded["obsidian"] then
          vim.keymap.set('n', '<leader>ff', '<cmd>Obsidian search<CR>', {buffer = true})
          vim.keymap.set('n', '<leader>аа', '<cmd>Obsidian search<CR>', {buffer = true})
        end
      end,
    })

    vim.keymap.set("n", "<leader>o", "<cmd>Obsidian toc<CR>", {desc = "TOC of file"})
    end,
}
