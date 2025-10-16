return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "/mnt/c/ObsidianSync/",
      },
    },
    
    -- Fix legacy commands warning
    legacy_commands = false,
    
    -- Fix checkbox deprecation warning
    checkbox = {
      enabled = true,
      order = {
        " ",
        "x",
        ">",
        "~",
        "!",
      },
    },
    
    -- Minimal UI config (removed deprecated checkboxes/bullets)
    ui = {
      enable = true,
      update_debounce = 200,
      max_file_length = 5000,
    },
    footer = {
      enabled = false,   -- убрать backlinks подпись
  },
    
    -- Note ID configuration
    note_id_func = function(title)
      return title
    end,
  },
}
