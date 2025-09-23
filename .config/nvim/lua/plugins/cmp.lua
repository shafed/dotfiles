return {
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "lervag/vimtex",
      "micangl/cmp-vimtex",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      vim.o.completeopt = "menu,menuone,noinsert"

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-j>"]     = cmp.mapping.select_next_item(),
          ["<C-k>"]     = cmp.mapping.select_prev_item(),
          ["<C-d>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<C-;>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "vimtex" },
          { name = "path" },
          { name = "buffer" },
        }),
        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        formatting = {
          fields = { "abbr", "menu", "kind" },
          format = function(entry, item)
            local menus = {
              nvim_lsp = "[LSP]",
              luasnip  = "[Snip]",
              vimtex   = "[VimTeX]",
              buffer   = "[Buf]",
              path     = "[Path]",
            }
            item.menu = menus[entry.source.name] or ""
            return item
          end,
        },
      })
    end,
  },
}
