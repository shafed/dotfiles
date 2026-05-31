return {
  "HakonHarnes/img-clip.nvim",
  event = "VeryLazy",
  opts = {
    default = {
      dir_path = function()
        return vim.fn.expand("%:p:h") .. "/assets"
      end,
    },
  },
  keys = {
    -- suggested keymap
    { "<leader>ip", "<cmd>PasteImage<cr>", desc = "Paste image from system clipboard" },
  },
}
