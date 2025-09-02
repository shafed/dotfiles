local ls = require("luasnip")
local s  = ls.snippet
local t  = ls.text_node
local i  = ls.insert_node
local f  = ls.function_node
local fmta = require("luasnip.extras.fmt").fmta

return {
  -- Math mode
  s("mk", fmta("$$<>$$", { i(1) })),
  s("dm", fmta("$$\n<>\n$$", { i(1) })),
  s("beg", fmta("\\begin{<>}\n<>\n\\end{<>}", { i(1, "env"), i(2), i(1) })),

  -- Greek
  s("@a", t("\\alpha")),
  s("@b", t("\\beta")),
  s("@g", t("\\gamma")),
  s("@G", t("\\Gamma")),
  s("@d", t("\\delta")),
  s("@D", t("\\Delta")),
  s("@e", t("\\epsilon")),
  s(":e", t("\\varepsilon")),
  s("@t", t("\\theta")),
  s(":t", t("\\vartheta")),
  s("@l", t("\\lambda")),
  s("@L", t("\\Lambda")),
  s("@s", t("\\sigma")),
  s("@S", t("\\Sigma")),
  s("@o", t("\\omega")),
  s("@O", t("\\Omega")),

  -- Basic operations
  s("sr", t("^{2}")),
  s("cb", t("^{3}")),
  s("rd", fmta("^{<>}", { i(1) })),
  s("_", fmta("_{<>}", { i(1) })),
  s("sq", fmta("\\sqrt{<>}", { i(1) })),
  s("//", fmta("\\frac{<>}{<>}", { i(1), i(2) })),
  s("ee", fmta("e^{<>}", { i(1) })),

  -- Logic / symbols
  s("=>", t("\\implies")),
  s("=<", t("\\impliedby")),
  s("<=>", t("\\Leftrightarrow")),
  s("->", t("\\to")),
  s("<-", t("\\leftarrow")),
  s("!>", t("\\mapsto")),
  s("...", t("\\dots")),
  s("===", t("\\equiv")),
  s("!=", t("\\neq")),
  s(">=", t("\\geq")),
  s("<=", t("\\leq")),

  -- Sets
  s("and", t("\\cap")),
  s("orr", t("\\cup")),
  s("inn", t("\\in")),
  s("notin", t("\\notin")),
  s("eset", t("\\emptyset")),
  s("set", fmta("\\{ <> \\}", { i(1) })),

  -- Mathbb
  s("RR", t("\\mathbb{R}")),
  s("ZZ", t("\\mathbb{Z}")),
  s("NN", t("\\mathbb{N}")),
  s("CC", t("\\mathbb{C}")),

  -- Brackets
  s("avg", fmta("\\langle <> \\rangle", { i(1) })),
  s("norm", fmta("\\lvert <> \\rvert", { i(1) })),
  s("Norm", fmta("\\lVert <> \\rVert", { i(1) })),
  s("ceil", fmta("\\lceil <> \\rceil", { i(1) })),
  s("floor", fmta("\\lfloor <> \\rfloor", { i(1) })),

  -- Environments
  s("cases", fmta("\\begin{cases}\n<>\n\\end{cases}", { i(1) })),
  s("align", fmta("\\begin{align}\n<>\n\\end{align}", { i(1) })),
  s("pmat", fmta("\\begin{pmatrix}\n<>\n\\end{pmatrix}", { i(1) })),
  s("bmat", fmta("\\begin{bmatrix}\n<>\n\\end{bmatrix}", { i(1) })),
  s("matrix", fmta("\\begin{matrix}\n<>\n\\end{matrix}", { i(1) })),

  -- Trig functions
  s("sin", t("\\sin")),
  s("cos", t("\\cos")),
  s("tan", t("\\tan")),
  s("log", t("\\log")),
  s("ln",  t("\\ln")),
  s("exp", t("\\exp")),

  -- Integrals
  s("int", fmta("\\int <> \\, d<>", { i(1), i(2, "x") })),
  s("dint", fmta("\\int_{<>}^{<>} <> \\, d<>", { i(1,"0"), i(2,"1"), i(3), i(4,"x") })),
  s("oinf", fmta("\\int_{0}^{\\infty} <> \\, d<>", { i(1), i(2,"x") })),
  s("infi", fmta("\\int_{-\\infty}^{\\infty} <> \\, d<>", { i(1), i(2,"x") })),

  -- Taylor expansion
  s("tayl", fmta(
    [[<>
(<> + <>) = <> + <> '<> <> + <> ''(<>) \frac{<>^{2}}{2!} + \dots]],
    { i(1,"f"), i(2,"x"), i(3,"h"), rep(1), rep(1), rep(2), rep(3), rep(1), rep(2), rep(3) }
  )),
}

