return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/ObsidianSync/",
      },
    },
    legacy_commands = false,
    footer = {
      enabled = false,
    },
  },
}
