-- REPL send for iterative work (Scilab and anything else): opens a :terminal
-- with the target REPL, then <C-c><C-c> sends the current paragraph/motion
-- and visual selections send with the same mapping. Run :SlimeConfig once per
-- Neovim session to point it at the terminal buffer.
return {
  "jpalardy/vim-slime",
  init = function()
    vim.g.slime_target = "neovim"
    vim.g.slime_bracketed_paste = 1
  end,
  keys = {
    {
      "<leader>rs",
      function()
        vim.cmd("vsplit | terminal scilab-cli")
        vim.cmd("startinsert")
      end,
      desc = "[P]Run: open Scilab REPL (then :SlimeConfig once)",
    },
    {
      "<leader>ri",
      function()
        vim.cmd("vsplit | terminal ipython")
        vim.cmd("startinsert")
      end,
      desc = "[P]Run: open IPython REPL (then :SlimeConfig once)",
    },
  },
}
