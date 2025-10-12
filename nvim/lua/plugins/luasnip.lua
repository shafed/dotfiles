return {
  "L3MON4D3/LuaSnip",
  version = "v2.*",
  event = "InsertEnter",
  dependencies = {
    "rafamadriz/friendly-snippets",
  },
  config = function()
    local ls = require("luasnip")
    local types = require("luasnip.util.types")

    ls.config.set_config({
      history = true,
      update_events = "TextChanged,TextChangedI",
      enable_autosnippets = true,
      region_check_events = "CursorMoved,CursorMovedI,InsertLeave",
      delete_check_events  = "TextChanged,TextChangedI,InsertLeave",
      ext_opts = {
        [types.choiceNode] = { active = { virt_text = { { "●", "DiagnosticWarn" } } } },
      },
    })

    -- VSCode-пакеты (friendly-snippets)
    require("luasnip.loaders.from_vscode").lazy_load()

    require("luasnip.loaders.from_lua").lazy_load({ paths = "~/.config/nvim/snippets" })

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
