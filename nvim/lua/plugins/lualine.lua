return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  init = function()
    -- Force the tabline to stay visible at all times (even with a single buffer).
    -- Something in LazyVim resets showtabline to 1 (e.g. on <leader>bo, when the
    -- other buffers are closed). We also hook OptionSet to restore it to 2 right
    -- after showtabline is changed elsewhere.
    vim.opt.showtabline = 2
    vim.api.nvim_create_autocmd(
      { "BufAdd", "BufDelete", "BufEnter", "BufWinEnter", "VimEnter", "WinEnter", "TabEnter" },
      {
        callback = function()
          if vim.o.showtabline ~= 2 then
            vim.opt.showtabline = 2
          end
        end,
      }
    )
    vim.api.nvim_create_autocmd("OptionSet", {
      pattern = "showtabline",
      callback = function()
        if vim.v.option_new ~= "2" then
          -- Defer to the next tick, otherwise a repeated set inside
          -- OptionSet may be swallowed by the same handler.
          vim.schedule(function()
            vim.opt.showtabline = 2
          end)
        end
      end,
    })
  end,
  opts = {
    options = {
      theme = "auto",
      globalstatus = true,
      always_show_tabline = true,
      icons_enabled = true,
      section_separators = "",
      component_separators = { left = "│", right = "│" },
    },

    tabline = {
      lualine_a = {
        {
          function()
            -- Count the number of buffers
            local buffers = vim.fn.getbufinfo({ buflisted = 1 })
            local buf_count = #buffers
            return "(" .. buf_count .. ")"
          end,
          color = { fg = "#756a5e", bg = "#32302f", gui = "bold" },
          separator = { right = "" },
          padding = { left = 0, right = 0 },
        },
        {
          "filename",
          path = 0,
          padding = { left = 0, right = 1 },
          color = { fg = "#756a5e", bg = "#32302f", gui = "bold" },
        },
      },
      lualine_b = {},
      lualine_c = {},
      lualine_x = {},
      lualine_y = {},
      lualine_z = {
        {
          function()
            local path = vim.fn.expand("%:p:h")
            -- If the buffer has no path of its own, show the working directory
            if path == "" or path == "." then
              path = vim.fn.getcwd()
            end
            -- Replace the home directory with ~
            local home = os.getenv("HOME")
            if home then
              path = path:gsub("^" .. home, "~")
            end
            -- Cap the path length
            local max_len = 40
            if #path > max_len then
              path = "..." .. path:sub(-max_len + 3)
            end
            return path
          end,
          color = { fg = "#918273", bg = "#353332" },
          separator = { right = "" },
          padding = 1,
        },
      },
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
}
