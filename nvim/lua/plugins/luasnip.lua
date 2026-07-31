return {
  "L3MON4D3/LuaSnip",
  enabled = true,
  dependencies = {
    "rafamadriz/friendly-snippets",
  },
  opts = function(_, opts)
    opts.enable_autosnippets = true
    require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/snippets" }) -- load custom snippets
    require("luasnip.loaders.from_vscode").lazy_load()
    require("luasnip").filetype_extend("markdown", { "tex" }) -- extend .tex snippets to .md

    local ls = require("luasnip")

    -- Add prefix ";" to each one of my snippets using the extend_decorator
    local extend_decorator = require("luasnip.util.extend_decorator")

    local function auto_semicolon(context)
      if type(context) == "string" then
        return { trig = ";" .. context }
      end
      return vim.tbl_extend("keep", { trig = ";" .. context.trig }, context)
    end

    extend_decorator.register(ls.s, {
      arg_indx = 1,
      extend = function(original)
        return auto_semicolon(original)
      end,
    })
    local s = extend_decorator.apply(ls.s, {})

    local t = ls.text_node
    local i = ls.insert_node
    local f = ls.function_node

    local function clipboard()
      return vim.fn.getreg("+")
    end

    local snippets = {}

    -- Paste clipboard contents in link section
    table.insert(
      snippets,
      s({
        trig = "linkc",
        name = "Paste clipboard as .md link",
        desc = "Paste clipboard as .md link",
      }, {
        t("["),
        i(1),
        t("]("),
        f(clipboard, {}),
        t(")"),
      })
    )

    table.insert(
      snippets,
      s({
        trig = "prettierignore",
        name = "Add prettier ignore start and end headings",
        desc = "Add prettier ignore start and end headings",
      }, {
        t({
          " ",
          "<!-- prettier-ignore-start -->",
          " ",
          "> ",
        }),
        i(1),
        t({
          " ",
          " ",
          "<!-- prettier-ignore-end -->",
        }),
      })
    )

    table.insert(
      snippets,
      s({
        trig = "markdownlint",
        name = "Add markdownlint disable and restore headings",
        desc = "Add markdownlint disable and restore headings",
      }, {
        t({
          " ",
          "<!-- markdownlint-disable -->",
          " ",
          "> ",
        }),
        i(1),
        t({
          " ",
          " ",
          "<!-- markdownlint-restore -->",
        }),
      })
    )

    table.insert(
      snippets,
      s({
        trig = "date",
        name = "Current date ISO 8601",
        desc = "Insert current date in YYYY-MM-DD format",
      }, {
        f(function()
          return os.date("%Y-%m-%d")
        end, {}),
      })
    )

    table.insert(
      snippets,
      s({
        trig = "mail",
        name = "My Gmail",
        desc = "My Gmail",
      }, {
        t("shaparenko.fedor@gmail.com"),
        i(1),
      })
    )

    ls.add_snippets("all", snippets)

    -- Auto-open the choice picker whenever a choice node becomes the active
    -- node (snippet expand or jump into it). The scheduled + choice_active()
    -- guard avoids a stale open if the user already Tabbed past the node.
    vim.api.nvim_create_autocmd("User", {
      pattern = "LuasnipChoiceNodeEnter",
      callback = function()
        vim.schedule(function()
          if require("luasnip").choice_active() then
            require("luasnip.extras.select_choice")()
          end
        end)
      end,
    })

    -- Manual reopen of the picker. When no choice is active, fall back to the
    -- built-in <C-u> (delete to start of line). Must NOT be an expr mapping:
    -- select_choice opens the Snacks picker window, which is forbidden during
    -- expr evaluation (E565).
    vim.keymap.set({ "i", "s" }, "<C-u>", function()
      if require("luasnip").choice_active() then
        require("luasnip.extras.select_choice")()
      else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-u>", true, false, true), "n", false)
      end
    end, { silent = true, desc = "LuaSnip: select choice" })

    return opts
  end,
}
