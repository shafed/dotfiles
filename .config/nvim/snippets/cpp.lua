local ls = require("luasnip")
local s  = ls.snippet
local t  = ls.text_node
local i  = ls.insert_node

return {
  -- авто-сниппет практического задания
  s({ trig = ";pr", snippetType = "autosnippet", priority = 2000 }, {
    t({
      '  cout << "КВБО-11-25 Шапаренко Фёдор Александрович" << endl;',
      '  cout << "Практическое задание №',
    }),
    i(1),
    t({'" << endl;', '  cout', '      << R"(Условие: '}),
    i(2, "..."),
    t({ ')"', '      << endl;' }),
  }),

  -- альтернативный безопасный триггер без конфликтов (на случай, если не хочешь трогать 'main')
  s({ trig = ";mnn", snippetType = "autosnippet" }, {
    t({
      "#include <iostream>",
      "using namespace std;",
      "",
      "int main() {",
      "  ",
    }),
    i(1),
    t({ "", "", "  return 0;", "}" }),
  }),
}
