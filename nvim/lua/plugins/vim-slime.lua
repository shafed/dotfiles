-- Send code to a REPL running in another kitty window: Scilab (`scilab -nw`,
-- which keeps its own plot windows) or `ipython` for .py notebooks in jupytext
-- percent format. Default maps: <C-c><C-c> sends the paragraph or selection,
-- <C-c>v picks the target window; <leader>rs sends the `# %%` cell.
-- Bracketed paste stays off: scilab -nw echoes its 00~/01~ markers as code.
-- Python goes through IPython's %cpaste instead.
return {
  "jpalardy/vim-slime",
  init = function()
    vim.g.slime_target = "kitty"
    vim.g.slime_python_ipython = 1
    vim.g.slime_cell_delimiter = "^# %%"
  end,
  keys = {
    { "<leader>rs", "<Plug>SlimeSendCell", desc = "[P]Send cell to REPL" },
  },
}
