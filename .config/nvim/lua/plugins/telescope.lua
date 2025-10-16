return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
      config = function()
        require("telescope").load_extension("fzf")
      end,
    },
  },
  config = function()
    local telescope = require("telescope")

    telescope.setup({
      defaults = {
        prompt_prefix = " ",
        selection_caret = " ",
        path_display = { "smart" },
        sorting_strategy = "descending",
        layout_config = { prompt_position = "bottom" },
        file_ignore_patterns = { "node_modules", ".git/" },
        case_mode = "smart_case",
      },
      pickers = {
        find_files = { hidden = true },
        live_grep = { theme = "dropdown" },
      },
    })

    vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Поиск файла" })
    vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Поиск по содержимому" })
    vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Открытые буферы" })
    vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = ":help" })
  end,
}
