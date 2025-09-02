-- lua/plugins/luasnip.lua
return {
  "L3MON4D3/LuaSnip",
  version = "v2.*",
  event = "InsertEnter",
  dependencies = {
    -- большой общий пак высокоуровневых сниппетов (в т.ч. для latex)
    "rafamadriz/friendly-snippets",
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

    -- загрузить vscode-совместимые (friendly-snippets)
    require("luasnip.loaders.from_vscode").lazy_load()

    -- загрузить наши локальные
    require("luasnip.loaders.from_lua").load({ paths = vim.fn.stdpath("config") .. "/luasnippets" })

    -- джампы внутри сниппетов
    vim.keymap.set({ "i", "s" }, "<Tab>", function()
      if ls.jumpable(1) then ls.jump(1) else return "<Tab>" end
    end, { expr = true, silent = true })

    vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
      if ls.jumpable(-1) then ls.jump(-1) else return "<S-Tab>" end
    end, { expr = true, silent = true })
  end,
}

