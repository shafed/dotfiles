return {
  "knubie/vim-kitty-navigator",
  build = "cp ./*.py ~/.config/kitty/",
  keys = {
    { "<C-h>", "<cmd>KittyNavigateLeft<cr>" },
    { "<C-j>", "<cmd>KittyNavigateDown<cr>" },
    { "<C-k>", "<cmd>KittyNavigateUp<cr>" },
    { "<C-l>", "<cmd>KittyNavigateRight<cr>" },
  },
}
