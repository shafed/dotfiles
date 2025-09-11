-- lua/plugins/luasnip.lua
return {
  "L3MON4D3/LuaSnip",
  version = "v2.*",
  event = "InsertEnter",
  dependencies = {
    "iurimateus/luasnip-latex-snippets.nvim",
  },
  config = function()
    local ls = require("luasnip")

    ls.config.set_config({
      history = true,
      updateevents = "TextChanged,TextChangedI",
      enable_autosnippets = true,
      region_check_events = "CursorHold,InsertLeave",
      delete_check_events  = "TextChanged,InsertLeave",
    })

    -- vscode-пакеты
    require("luasnip.loaders.from_vscode").lazy_load()

    -- LaTeX-сниппеты с ограничением по контексту
    require("luasnip-latex-snippets").setup({
      use_treesitter = true,   -- использовать treesitter для определения math-зоны
      allow_on_markdown = true,  -- разрешить в markdown
      smart_in_math = true,
    })

    -- Чтобы tex-сниппеты были доступны и в markdown
    ls.filetype_extend("markdown", { "tex" })

    -- джампы
    local map = vim.keymap.set
    map({ "i", "s" }, "<Tab>", function()
      if ls.jumpable(1) then return "<Plug>luasnip-jump-next" end
      return "<Tab>"
    end, { expr = true, silent = true })
    map({ "i", "s" }, "<S-Tab>", function()
      if ls.jumpable(-1) then return "<Plug>luasnip-jump-prev" end
      return "<S-Tab>"
    end, { expr = true, silent = true })
  end,
}

