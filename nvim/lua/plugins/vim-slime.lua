-- Send code to a REPL running in another kitty window: Scilab (`scilab -nw`,
-- which keeps its own plot windows). Default maps: <C-c><C-c> sends the
-- paragraph or selection, <C-c>v picks the target window. Bracketed paste stays
-- off: scilab -nw echoes its 00~/01~ markers as code. Python notebooks use
-- iron.nvim instead.
return {
  "jpalardy/vim-slime",
  init = function()
    vim.g.slime_target = "kitty"
  end,
}
