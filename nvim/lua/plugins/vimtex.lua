return {
  "lervag/vimtex",
  lazy = false,
  init = function()
    vim.g.vimtex_view_method = "sioyek"
    vim.g.vimtex_compiler_latexmk_engines = { _ = "-lualatex" }
    vim.g.vimtex_compiler_latexmk = {
      out_dir = "build",
      aux_dir = "build",
      options = {
        "-verbose",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
        "-shell-escape",
      },
    }
  end,
}
