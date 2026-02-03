return {
  "L3MON4D3/LuaSnip",
  enabled = true,
  opts = function(_, opts)
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
        trig = "mail",
        name = "My Gmail",
        desc = "My Gmail",
      }, {
        t("shaparenko.fedor@gmail.com"),
        i(1),
      })
    )

    ls.add_snippets("all", snippets)

    return opts
  end,
}
