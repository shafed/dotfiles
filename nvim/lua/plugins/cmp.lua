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
      "onsails/lspkind.nvim",   -- иконки как в VS Code
      "windwp/nvim-autopairs",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")


      vim.o.completeopt = "menu,menuone,noinsert"

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-j>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              local entry = cmp.get_selected_entry()
              if entry then
                cmp.select_next_item()
              else
                cmp.select_next_item()
                cmp.select_next_item()
              end
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-k>"]     = cmp.mapping.select_prev_item(),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<C-space>"] = cmp.mapping.complete(),
          ["<C-y>"]     = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
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
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
          }),
        },
      })
    end,
  },
}
