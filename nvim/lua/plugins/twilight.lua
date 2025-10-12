return {
  "folke/twilight.nvim",
  opts = {
    dimming = {
      alpha = 0.35, -- затемнение (чем больше, тем темнее)
      color = { "Normal", "#ffffff" },
      term_bg = "#000000",
      inactive = false,
    },
    context = 10,
    treesitter = true,
  },
  keys = {
    { "<leader>tw", "<cmd>Twilight<cr>", desc = "Toggle Twilight" },
  },
}
