return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = { "python", "lua", "markdown", "markdown_inline" },
      highlight = { enable = true, additional_vim_regex_highlighting = false },
      indent = { enable = true },
    })
  end
}

