return {
  -- The buffer count/filename/path line is now drawn via `winbar` in
  -- config/options.lua, like linkarzu's setup, so bufferline's own tab strip
  -- (LazyVim's default) is redundant here — disable it.
  { "akinsho/bufferline.nvim", enabled = false },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        icons_enabled = true,
        section_separators = "",
        component_separators = { left = "│", right = "│" },
      },

      sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {},
        lualine_x = {
          -- Recording (q) macros
          {
            require("noice").api.statusline.mode.get,
            cond = require("noice").api.statusline.mode.has,
            color = { fg = "#ff9e64" },
          },
        },
        lualine_y = {
          {
            require("noice").api.status.command.get,
            cond = require("noice").api.status.command.has,
            color = { fg = "#ff9e64" },
          },
        },
        lualine_z = { "location" },
      },
    },
  },
}
