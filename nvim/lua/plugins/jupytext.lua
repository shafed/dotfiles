-- Open .ipynb as a plain-text py:percent buffer (`# %%` cells); :w writes the
-- notebook back via `jupytext --update`, so existing outputs are kept. Cells
-- are sent to a REPL with vim-slime. Must not be lazy-loaded.
return {
  "GCBallesteros/jupytext.nvim",
  lazy = false,
  opts = {
    style = "percent",
    output_extension = "auto",
    force_ft = "python",
  },
}
