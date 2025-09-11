-- lua/plugins/luasnip-latex-snippets.lua
return {
  "iurimateus/luasnip-latex-snippets.nvim",
  event = "InsertEnter",
  ft = { "markdown", "tex" },
  dependencies = { "L3MON4D3/LuaSnip" },
  config = function()
    require("luasnip-latex-snippets").setup({
      use_treesitter    = true,
      allow_on_markdown = true,
    })
    require("luasnip").filetype_extend("markdown", { "tex" })
  end,
}

