return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
    "TmuxNavigatorProcessList",
  },
  keys = {
    { "<C-h>", "<cmd><C-U>TmuxNavigateLeft<cr>", mode = { "n", "v", "i" } },
    { "<C-j>", "<cmd><C-U>TmuxNavigateDown<cr>", mode = { "n", "v", "i" } },
    { "<C-k>", "<cmd><C-U>TmuxNavigateUp<cr>", mode = { "n", "v", "i" } },
    { "<C-l>", "<cmd><C-U>TmuxNavigateRight<cr>", mode = { "n", "v", "i" } },
  },
}
