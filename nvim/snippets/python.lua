local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local fmta = require("luasnip.extras.fmt").fmta

return {
	-- Basic Python snippets
	s("def", fmta("def <>(<>):\n    <>\n    return <>", { i(1, "function_name"), i(2, ""), i(3, "pass"), i(4) })),
	s(
		"class",
		fmta(
			"class <>(<>):\n    def __init__(self<>, <>):\n        <>\n",
			{ i(1, "ClassName"), i(2, ""), i(3, ""), i(4, ""), i(5, "pass") }
		)
	),
	s("if", fmta("if <>\n    <>\n", { i(1, "condition"), i(2, "pass") })),
	s("for", fmta("for <> in <>:\n    <>\n", { i(1, "item"), i(2, "iterable"), i(3, "pass") })),
	s("while", fmta("while <>\n    <>\n", { i(1, "condition"), i(2, "pass") })),
	s(
		"try",
		fmta("try:\n    <>\nexcept <> as <>:\n    <>\n", { i(1, "pass"), i(2, "Exception"), i(3, "e"), i(4, "pass") })
	),
	s("main", fmta("if __name__ == '__main__':\n    <>\n", { i(1, "main()") })),
	s("print", fmta("print(<>)", { i(1, "") })),
	s("import", fmta("import <>", { i(1, "") })),
	s("from", fmta("from <> import <>", { i(1, ""), i(2, "") })),
}
