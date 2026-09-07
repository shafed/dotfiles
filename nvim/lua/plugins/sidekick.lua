return {
  {
    "folke/sidekick.nvim",
    config = function(_, opts)
      require("sidekick").setup(opts)
      require("utils.sidekick_kitty").setup()
    end,
  },
}
