local zen_active = false

return {
  "folke/snacks.nvim",
  keys = {
    -- Use mini.files
    { "<leader>e", false },
    -- Zen mode = Hyprland fullscreen, not Snacks.zen's floating window:
    -- fullscreen the OS window and hide kitty's tab bar (utils/fullscreen.lua),
    -- plus blank the winbar across all windows (utils/winbar.lua). Overrides
    -- LazyVim's Snacks.toggle.zen() which would open an nvim float.
    {
      "<leader>uz",
      function()
        local winbar = require("utils.winbar")
        local fullscreen = require("utils.fullscreen")
        zen_active = not zen_active
        winbar.set_zen(zen_active)
        fullscreen.set_zen(zen_active)
      end,
      desc = "Zen Mode (Hyprland fullscreen)",
    },
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
    -- When invoked inside ~/obsidian, search notes by filename AND by frontmatter
    -- `aliases`. Anywhere else, fall back to the regular Find Files picker.
    {
      "<leader><space>",
      function()
        local obsidian = vim.fn.expand("~/obsidian")
        local cwd = vim.fn.getcwd()
        if cwd:sub(1, #obsidian) ~= obsidian then
          Snacks.picker.files({
            finder = "files",
            format = "file",
            show_empty = true,
            supports_live = true,
          })
          return
        end

        -- Read the YAML `aliases` from a note's frontmatter. Supports both the
        -- block form (aliases:\n  - foo) and the inline form (aliases: [foo]).
        local function read_aliases(path)
          local fh = io.open(path, "r")
          if not fh then
            return nil
          end
          local aliases = {}
          local in_frontmatter, in_aliases = false, false
          local lineno = 0
          for line in fh:lines() do
            lineno = lineno + 1
            if lineno == 1 then
              if line ~= "---" then
                break -- no frontmatter
              end
              in_frontmatter = true
            elseif in_frontmatter and line == "---" then
              break -- end of frontmatter
            elseif in_frontmatter then
              local inline = line:match("^aliases:%s*%[(.-)%]%s*$")
              local scalar = line:match("^aliases:%s*(%S.*)$")
              if inline then
                -- aliases: [a, "b c", 'd']
                for a in inline:gmatch("[^,]+") do
                  a = a:gsub("^%s*['\"]?", ""):gsub("['\"]?%s*$", "")
                  if a ~= "" then
                    table.insert(aliases, a)
                  end
                end
              elseif scalar then
                -- aliases: some value (scalar on the same line)
                scalar = scalar:gsub("^['\"]?", ""):gsub("['\"]?%s*$", "")
                table.insert(aliases, scalar)
              elseif line:match("^aliases:%s*$") then
                in_aliases = true
              elseif in_aliases then
                -- Either a list item ("  - foo") or a bare indented scalar
                -- ("  foo") that some notes use under "aliases:".
                local item = line:match("^%s*-%s*(.+)$") or line:match("^%s+(%S.*)$")
                if item then
                  item = item:gsub("^['\"]?", ""):gsub("['\"]?%s*$", "")
                  table.insert(aliases, item)
                elseif not line:match("^%s") then
                  in_aliases = false -- next top-level key
                end
              end
            end
          end
          fh:close()
          return aliases
        end

        Snacks.picker.pick({
          source = "obsidian_notes",
          title = "Obsidian Notes",
          format = "file",
          show_empty = true,
          -- Snacks' matcher uses Lua string.lower(), which only handles ASCII.
          -- Normalize both sides with Vim's Unicode-aware tolower() so Russian
          -- filenames and aliases are matched case-insensitively too.
          filter = {
            transform = function(_, filter)
              filter.pattern = vim.fn.tolower(filter.pattern)
            end,
          },
          finder = function()
            local items = {}
            local files = vim.fn.systemlist({
              "rg",
              "--files",
              obsidian,
            })
            for _, file in ipairs(files) do
              local aliases = file:match("%.md$") and read_aliases(file) or nil
              -- The matcher searches against `text`; append aliases so notes
              -- are findable by alias, while `format = "file"` still shows path.
              local text = vim.fn.fnamemodify(file, ":t")
              if aliases and #aliases > 0 then
                text = text .. " " .. table.concat(aliases, " ")
              end
              table.insert(items, {
                text = vim.fn.tolower(text),
                file = file,
              })
            end
            return items
          end,
        })
      end,
      desc = "Find Files / Obsidian notes (name + aliases)",
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
          -- I want to filter this to only show markdown files
          glob = "*.md",
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
          actions = {
            -- Toggle the selected task done (and move it under "## Completed
            -- Tasks") without leaving the picker, then refresh the list
            task_done = function(picker, item)
              picker:norm(function()
                item = item or picker:current()
                local path = item and Snacks.picker.util.path(item)
                local line = item and item.pos and item.pos[1]
                if not path or not line then
                  vim.notify("No task selected", vim.log.levels.WARN)
                  return
                end
                local changed = require("utils.tasks").toggle_done({
                  file = path,
                  line = line,
                })
                if changed then
                  picker:refresh()
                end
              end)
            end,
          },
          win = {
            input = {
              keys = {
                ["<M-x>"] = { "task_done", mode = { "n", "i" } },
              },
            },
            list = {
              keys = {
                ["<M-x>"] = "task_done",
              },
            },
          },
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
    image = {
      enabled = true,
      doc = {
        inline = false,
        float = true,
        max_width = 60,
        max_height = 30,
      },
    },
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
