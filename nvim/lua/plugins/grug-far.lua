return {
  "MagicDuck/grug-far.nvim",
  config = function(_, opts)
    require("grug-far").setup(opts)
    -- Map <Esc> to quit after ensuring we're in normal mode
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "grug-far",
      callback = function()
        vim.keymap.set({ "n" }, "<Esc>", "<Cmd>stopinsert | bd!<CR>", { buffer = true })
      end,
    })
  end,
  opts = { headerMaxWidth = 80 },
  cmd = { "GrugFar", "GrugFarWithin" },
  keys = {
    {
      "<leader>sr",
      function()
        local grug = require("grug-far")
        local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
        grug.open({
          transient = true,
          prefills = {
            filesFilter = ext and ext ~= "" and "*." .. ext or nil,
          },
        })
      end,
      mode = { "n", "x" },
      desc = "Search and Replace",
    },
  },
}
