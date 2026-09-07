return {
  {
    "sainnhe/gruvbox-material",
    config = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "@markup.strong.markdown_inline", { fg = "#E78A4E", bold = true }) -- Orange для жирного
          vim.api.nvim_set_hl(0, "@markup.italic.markdown_inline", { italic = true, fg = "#a9b665" }) -- Green для курсива
          vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { fg = "#7DAEA3" }) -- Yellow для инлайн кода

          -- gruvbox-material.vim sets g:terminal_color_0..15 itself, but
          -- duplicates each bright variant onto its normal color (e.g.
          -- terminal_color_11 == terminal_color_3). kitty/current-theme.conf
          -- (generated from colors.toml) gives bright colors distinct hues,
          -- so embedded :terminal buffers (sidekick, :terminal) render some
          -- ANSI colors differently than a real kitty pane. Match kitty's
          -- palette exactly. Keep in sync with kitty/current-theme.conf.
          local terminal_colors = {
            "#665c54", "#ea6962", "#a9b665", "#e78a4e",
            "#7daea3", "#d3869b", "#89b482", "#d4be98",
            "#928374", "#ea6962", "#a9b665", "#d8a657",
            "#7daea3", "#d3869b", "#89b482", "#d4be98",
          }
          for i, hex in ipairs(terminal_colors) do
            vim.g["terminal_color_" .. (i - 1)] = hex
          end
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
