local ls = require("luasnip")
local s  = ls.snippet
local t  = ls.text_node

return {
  s({ trig = "mail", wordTrig = false }, t("shaparenko.fedor@gmail.com")),
  s({ trig = ".mail", wordTrig = false }, t("shaparenkofedor@gmail.com")),
  s({ trig = "mmail", wordTrig = false }, t("shaparenko.f.a@edu.mirea.ru")),
}
