return {
  "lervag/vimtex",
  lazy = false,
  init = function()
    vim.g.vimtex_view_method = "sioyek"
    vim.g.vimtex_compiler_latexmk_engines = { _ = "-lualatex" }
    vim.g.vimtex_compiler_latexmk = {
      out_dir = "build",
      callback = 1,
    }

    -- Copy .pdf from build out_dir
    vim.api.nvim_create_augroup("vimtex_callbacks", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      group = "vimtex_callbacks",
      pattern = "VimtexEventCompileSuccess",
      callback = function()
        vim.fn.system("cp build/*.pdf .")
      end,
    })
  end,
}
