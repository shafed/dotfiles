return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("nvim-tree").setup({
      disable_netrw = true,
      hijack_netrw = true,
      view = { width = 30, side = "left" },
      renderer = { group_empty = true },
      filters = { dotfiles = false },
    })
    vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>')
  end
}

