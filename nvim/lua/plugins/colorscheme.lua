local palette = {
  aqua = "#89b482",
  aqua_bg = "#3b443a",
  bg_hard = "#1d2021",
}

local function apply_accents()
  local set = vim.api.nvim_set_hl

  -- Keep the warm Gruvbox syntax palette, but make aqua the recurring UI
  -- accent: focus, selection, navigation and interactive surfaces.
  set(0, "CursorLineNr", { fg = palette.aqua, bold = true })
  set(0, "WinSeparator", { fg = palette.aqua })
  set(0, "FloatBorder", { fg = palette.aqua })
  set(0, "Visual", { bg = palette.aqua_bg })
  set(0, "PmenuSel", { fg = palette.bg_hard, bg = palette.aqua, bold = true })
  set(0, "MatchParen", { fg = palette.aqua, bold = true, underline = true })
  set(0, "DiagnosticHint", { fg = palette.aqua })

  -- Pickers and navigation.
  set(0, "TelescopeMatching", { fg = palette.aqua, bold = true })
  set(0, "TelescopeSelectionCaret", { fg = palette.aqua, bold = true })
  set(0, "OilDir", { fg = palette.aqua, bold = true })
  set(0, "MiniFilesDirectory", { fg = palette.aqua })
  set(0, "MiniFilesTitleFocused", { fg = palette.aqua, bold = true })
  set(0, "WhichKeyGroup", { fg = palette.aqua })

  -- Markdown: headings get the same sage/aqua emphasis as the reference.
  set(0, "@markup.heading", { fg = palette.aqua, bold = true })
  for level = 1, 6 do
    set(0, "@markup.heading." .. level .. ".markdown", { fg = palette.aqua, bold = true })
  end
  set(0, "@markup.link.label.markdown_inline", { fg = palette.aqua, underline = true })
  set(0, "@markup.link.url.markdown_inline", { fg = palette.aqua, underline = true })

  set(0, "@markup.strong.markdown_inline", { fg = "#E78A4E", bold = true }) -- Orange для жирного
  set(0, "@markup.italic.markdown_inline", { italic = true, fg = "#a9b665" }) -- Green для курсива
  set(0, "@markup.raw.markdown_inline", { fg = "#7DAEA3" }) -- Blue для инлайн кода
end

return {
  {
    "sainnhe/gruvbox-material",
    config = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = apply_accents,
      })
      apply_accents()

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
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox-material",
    },
  },
}
