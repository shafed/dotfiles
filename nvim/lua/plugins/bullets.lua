return {
  "bullets-vim/bullets.vim",
  ft = { "markdown", "text" },
  init = function()
    -- на всех уровнях использовать только цифры
    vim.g.bullets_outline_levels = { "num", "num", "num" }
  end,
}
