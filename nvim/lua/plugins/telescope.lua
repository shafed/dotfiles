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

    vim.keymap.set("n", "<leader>sf", "<cmd>Telescope find_files<CR>", { desc = "Поиск файла" })
    vim.keymap.set("n", "<leader>sg", "<cmd>Telescope live_grep<CR>", { desc = "Поиск по содержимому" })
    vim.keymap.set("n", "<leader>sb", "<cmd>Telescope buffers<CR>", { desc = "Открытые буферы" })
    vim.keymap.set("n", "<leader>ыа", "<cmd>Telescope find_files<CR>", { desc = "Поиск файла" })
    vim.keymap.set("n", "<leader>ып", "<cmd>Telescope live_grep<CR>", { desc = "Поиск по содержимому" })
    vim.keymap.set("n", "<leader>ыи", "<cmd>Telescope buffers<CR>", { desc = "Открытые буферы" })
  end,
}
