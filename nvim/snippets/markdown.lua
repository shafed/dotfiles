local ls = require("luasnip")

local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local c = ls.choice_node
local f = ls.function_node

local function filename()
  local name = vim.fn.expand("%:t:r")
  return name ~= "" and name or "Untitled"
end

return {
  s({
    trig = ";source",
    name = "Vault source",
    desc = "Source frontmatter used by the Markdown vault",
  }, {
    t({ "---", "tags:", "  - source/" }),
    c(1, {
      t("article"),
      t("book"),
      t("course"),
      t("movie"),
      t("podcast"),
      t("video"),
    }),
    t({ "", "aliases:", "category:", '  - "[[' }),
    i(2, "category"),
    t({ ']]"', "creator: " }),
    -- Creator is optional; insert the complete quoted wikilink only when known.
    i(3),
    t({ "", "url: " }),
    i(4),
    t({ "", "---", "", "" }),
    i(0),
  }),

  s({
    trig = ";project",
    name = "Vault project",
    desc = "Project frontmatter used by the Markdown vault",
  }, {
    t({ "---", "tags:", "  - project/single", "aliases:", "category:", '  - "[[' }),
    i(1, "category"),
    t({ ']]"', "---", "", "" }),
    i(0),
  }),

  s({
    trig = ";category",
    name = "Vault category",
    desc = "Category page with generated indexes",
  }, {
    t({ "---", "tags:", "  - system/category", "aliases:", "---", "", "# " }),
    f(filename, {}),
    t({
      "",
      "",
      "## Meta-Notes",
      "",
      "<!-- index:meta -->",
      "<!-- /index -->",
      "",
      "## Projects",
      "",
      "<!-- index:projects -->",
      "<!-- /index -->",
      "",
      "## Sources",
      "",
      "<!-- index:sources -->",
      "<!-- /index -->",
      "",
    }),
    i(0),
  }),

  s({
    trig = ";meta",
    name = "Vault meta-note",
    desc = "Thematic hub with a generated mentions index",
  }, {
    t({ "---", "tags:", "  - system/meta", "aliases:", "category:", '  - "[[' }),
    i(1, "category"),
    t({
      ']]"',
      "---",
      "",
      "## Mentions",
      "",
      "<!-- index:meta-mentions -->",
      "<!-- /index -->",
      "",
    }),
    i(0),
  }),

  s({
    trig = ";creator",
    name = "Vault creator",
    desc = "Creator page with generated source, quote, and mention indexes",
  }, {
    t({ "---", "tags:", "  - people/creator", "aliases:", "---", "", "# " }),
    f(filename, {}),
    t({
      "",
      "",
      "## Sources",
      "",
      "<!-- index:creator-sources -->",
      "<!-- /index -->",
      "",
      "## Quotes",
      "",
      "<!-- index:creator-quotes -->",
      "<!-- /index -->",
      "",
      "## Mentions",
      "",
      "<!-- index:creator-mentions -->",
      "<!-- /index -->",
      "",
    }),
    i(0),
  }),

  s({
    trig = ";quote",
    name = "Vault quote",
    desc = "Standalone quote with visible source and creator attribution",
  }, {
    t({ "---", "tags:", "  - mark/quote", "aliases:", "---", "", "> [!quote]", "> " }),
    i(1, "quote"),
    t({ "", ">", "> - [[" }),
    i(2, "source"),
    t({ "]]", "> - [[" }),
    i(3, "creator"),
    t({ "]]", "" }),
    i(0),
  }),

  s({
    trig = ";daily",
    name = "Vault daily note",
    desc = "Metadata-free journal note headed by its filename",
  }, {
    t("# "),
    f(filename, {}),
  }),
}
