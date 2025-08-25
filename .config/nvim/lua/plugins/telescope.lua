return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local telescope = require("telescope")
    telescope.setup({})
    vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<CR>', { desc = "Поиск файла" })
    vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', { desc = "Поиск по содержимому" })
    vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<CR>', { desc = "Открытые буферы" })
    vim.keymap.set('n', '<leader>fh', '<cmd>Telescope help_tags<CR>', { desc = ":help" })
  end
}

