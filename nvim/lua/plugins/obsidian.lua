return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
    lazy = false,
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/obsidiansync/",
      },
    },
    legacy_commands = false,
    footer = {
      enabled = false,
    },
  },
}
