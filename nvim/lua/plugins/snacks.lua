return {
  "folke/snacks.nvim",
  keys = {
    -- Use mini.files
    { "<leader>e", false },
    -- Keymaps picker
    {
      "<leader>sk",
      function()
        Snacks.picker.keymaps({
          layout = "vertical",
        })
      end,
      desc = "Keymaps",
    },
    -- File picker
    {
      "<leader><space>",
      function()
        Snacks.picker.files({
          finder = "files",
          format = "file",
          show_empty = true,
          supports_live = true,
          -- In case you want to override the layout for this keymap
          -- layout = "vscode",
        })
      end,
      desc = "Find Files",
    },
    -- LSP References
    {
      "gr",
      function()
        Snacks.picker.lsp_references({
          on_show = function()
            vim.cmd.stopinsert()
          end,
          layout = "vertical",
        })
      end,
      desc = "References",
    },
    -- Navigate my buffers
    {
      "<M-h>",
      function()
        Snacks.picker.buffers({
          -- I always want my buffers picker to start in normal mode
          on_show = function()
            vim.cmd.stopinsert()
          end,
          finder = "buffers",
          format = "buffer",
          hidden = false,
          unloaded = true,
          current = true,
          sort_lastused = true,
          win = {
            input = {
              keys = {
                ["d"] = "bufdelete",
              },
            },
            list = { keys = { ["d"] = "bufdelete" } },
          },
          -- In case you want to override the layout for this keymap
          -- layout = "ivy",
        })
      end,
      desc = "[P]Snacks picker buffers",
    },

    -- -- Iterate through incomplete tasks in Snacks_picker
    {
      -- -- You can confirm in your teminal lamw26wmal with:
      -- -- rg "^\s*-\s\[ \]" test-markdown.md
      "<leader>tt",
      function()
        Snacks.picker.grep({
          prompt = " ",
          -- pass your desired search as a static pattern
          search = "^\\s*- \\[ \\]",
          -- we enable regex so the pattern is interpreted as a regex
          regex = true,
          -- no “live grep” needed here since we have a fixed pattern
          live = false,
          -- restrict search to the current working directory
          dirs = { vim.fn.getcwd() },
          -- include files ignored by .gitignore
          args = { "--no-ignore" },
          -- Start in normal mode
          on_show = function()
            vim.cmd.stopinsert()
          end,
          finder = "grep",
          format = "file",
          show_empty = true,
          supports_live = false,
          layout = "ivy",
        })
      end,
      desc = "[P]Search for incomplete tasks",
    },
    -- -- Iterate throuth completed tasks in Snacks_picker lamw26wmal
    {
      "<leader>tc",
      function()
        Snacks.picker.grep({
          prompt = " ",
          -- pass your desired search as a static pattern
          search = "^\\s*- \\[x\\] `done:",
          -- we enable regex so the pattern is interpreted as a regex
          regex = true,
          -- no “live grep” needed here since we have a fixed pattern
          live = false,
          -- restrict search to the current working directory
          dirs = { vim.fn.getcwd() },
          -- include files ignored by .gitignore
          args = { "--no-ignore" },
          -- Start in normal mode
          on_show = function()
            vim.cmd.stopinsert()
          end,
          finder = "grep",
          format = "file",
          show_empty = true,
          supports_live = false,
          layout = "ivy",
        })
      end,
      desc = "[P]Search for complete tasks",
    },
  },
  opts = {
    picker = {
      -- My ~/github/dotfiles-latest/neovim/lazyvim/lua/config/keymaps.lua
      -- file was always showing at the top, I needed a way to decrease its
      -- score, in frecency you could use :FrecencyDelete to delete a file
      -- from the database, here you can decrease it's score
      transform = function(item)
        if not item.file then
          return item
        end
        -- Demote the "lazyvim" keymaps file:
        if item.file:match("lazyvim/lua/config/keymaps%.lua") then
          item.score_add = (item.score_add or 0) - 30
        end
        -- Demote my old kanata config file
        if item.file:match("kanata/configs/macos%.kbd") then
          item.score_add = (item.score_add or 0) - 30
        end
        -- Boost the "neobean" keymaps file:
        -- if item.file:match("neobean/lua/config/keymaps%.lua") then
        --   item.score_add = (item.score_add or 0) + 100
        -- end
        return item
      end,
      -- In case you want to make sure that the score manipulation above works
      -- or if you want to check the score of each file
      debug = {
        scores = false, -- show scores in the list
      },
      -- I like the "ivy" layout, so I set it as the default globaly, you can
      -- still override it in different keymaps
      layout = {
        preset = "ivy",
        -- When reaching the bottom of the results in the picker, I don't want
        -- it to cycle and go back to the top
        cycle = false,
      },
      layouts = {
        -- I wanted to modify the ivy layout height and preview pane width,
        -- this is the only way I was able to do it
        -- NOTE: I don't think this is the right way as I'm declaring all the
        -- other values below, if you know a better way, let me know
        --
        -- Then call this layout in the keymaps above
        -- got example from here
        -- https://github.com/folke/snacks.nvim/discussions/468
        ivy = {
          layout = {
            box = "vertical",
            backdrop = false,
            row = -1,
            width = 0,
            height = 0.5,
            border = "top",
            title = " {title} {live} {flags}",
            title_pos = "left",
            { win = "input", height = 1, border = "bottom" },
            {
              box = "horizontal",
              { win = "list", border = "none" },
              { win = "preview", title = "{preview}", width = 0.5, border = "left" },
            },
          },
        },
        -- I wanted to modify the layout width
        --
        vertical = {
          layout = {
            backdrop = false,
            width = 0.8,
            min_width = 80,
            height = 0.8,
            min_height = 30,
            box = "vertical",
            border = "rounded",
            title = "{title} {live} {flags}",
            title_pos = "center",
            { win = "input", height = 1, border = "bottom" },
            { win = "list", border = "none" },
            { win = "preview", title = "{preview}", height = 0.4, border = "top" },
          },
        },
      },
      matcher = {
        frecency = true,
      },
      win = {
        input = {
          keys = {
            -- to close the picker on ESC instead of going to normal mode,
            -- add the following keymap to your config
            ["<Esc>"] = { "close", mode = { "n", "i" } },
            -- I'm used to scrolling like this in LazyGit
            ["J"] = { "preview_scroll_down", mode = { "i", "n" } },
            ["K"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["H"] = { "preview_scroll_left", mode = { "i", "n" } },
            ["L"] = { "preview_scroll_right", mode = { "i", "n" } },
          },
        },
      },
      formatters = {
        file = {
          filename_first = true, -- display filename before the file path
          truncate = 80,
        },
      },
    },
    lazygit = {
      theme = {
        selectedLineBgColor = { bg = "CursorLine" },
      },
    },
    dashboard = {
      preset = {
        pick = function(cmd, opts)
          return LazyVim.pick(cmd, opts)()
        end,
        header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝

 ]],
        -- stylua: ignore
        ---@type snacks.dashboard.Item[]
        keys = {
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = " ", key = "<Esc>", desc = "Quit", action = ":qa" },
        },
      },
    },
  },
}
