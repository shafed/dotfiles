return {
  "shafed/todoist-nvim",
  build = "cargo build --release",
  cmd = "TodoistOpen", -- lazy-load: only load when command is used
  keys = {
    { "<leader>to", "<cmd>TodoistOpen<cr>", desc = "Todoist tasks" },
  },
  config = function()
    require("todoist").setup()
    vim.env.TODOIST_API_TOKEN = "f3736efb85c6f5c726090bb92df83fa9b07a6b19"
  end,
}
