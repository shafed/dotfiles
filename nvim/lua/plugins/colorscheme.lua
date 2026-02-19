return {
  {
    "sainnhe/gruvbox-material",
    config = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "@markup.strong.markdown_inline", { fg = "#E78A4E", bold = true }) -- Orange для жирного
          vim.api.nvim_set_hl(0, "@markup.italic.markdown_inline", { italic = true, fg = "#a9b665" }) -- Green для курсива
          vim.api.nvim_set_hl(0, "@lsp.type.decorator.markdown", { fg = "#D3869B", italic = true }) -- Purple для URL
          vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { fg = "#7DAEA3" }) -- Yellow для инлайн кода
        end,
      })
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox-material",
    },
  },
}
