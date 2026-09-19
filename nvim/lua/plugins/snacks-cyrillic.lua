-- snacks' matcher folds case with Lua string.lower, which only knows ASCII, so
-- smartcase silently degrades into case-sensitive search for Cyrillic: "жор"
-- misses "Предмет Жоры" while "Жор" finds it (matcher.lua:341 and :523). Fold
-- Cyrillic case ourselves, and let a Latin-typed pattern match Cyrillic text
-- through the QWERTY/ЙЦУКЕН layout, so ";jhf" finds "Жора".

local CASE_OFFSET = 0x20

-- Lowercases Cyrillic only; ASCII is left alone so snacks keeps its own
-- smartcase behaviour. Byte length is preserved, so match positions stay valid
-- and highlighting does not drift.
local function cyrillic_lower(s)
  if not s:find("\208", 1, true) then
    return s
  end
  return (s:gsub("\208([\129\144-\175])", function(b)
    local c = b:byte()
    if c == 0x81 then -- Ё
      return "\209\145"
    elseif c <= 0x9F then -- А-П
      return "\208" .. string.char(c + CASE_OFFSET)
    end
    return "\209" .. string.char(c - CASE_OFFSET) -- Р-Я
  end))
end

local LAYOUT = {
  q = "й", w = "ц", e = "у", r = "к", t = "е", y = "н", u = "г", i = "ш",
  o = "щ", p = "з", a = "ф", s = "ы", d = "в", f = "а", g = "п", h = "р",
  j = "о", k = "л", l = "д", z = "я", x = "ч", c = "с", v = "м", b = "и",
  n = "т", m = "ь", [";"] = "ж", [","] = "б", ["."] = "ю", ["["] = "х",
  ["]"] = "ъ",
}

local function to_cyrillic(s)
  return (s:gsub("[a-zA-Z;,%.%[%]]", function(ch)
    return LAYOUT[ch:lower()] or ch
  end))
end

-- The matcher ANDs space-separated tokens and treats a bare "|" as "the next
-- token is an alternative" (matcher.lua:236), so pair every Latin token with
-- its layout twin instead of replacing it.
local function with_layout_alternatives(pattern)
  local tokens = {}
  for _, token in ipairs(vim.split(vim.trim(pattern), " +")) do
    tokens[#tokens + 1] = token
    if token ~= "" and token ~= "|" then
      local alt = to_cyrillic(token)
      if alt ~= token then
        tokens[#tokens + 1] = "|"
        tokens[#tokens + 1] = alt
      end
    end
  end
  return table.concat(tokens, " ")
end

local function patch_matcher()
  local ok, Matcher = pcall(require, "snacks.picker.core.matcher")
  if not ok or type(Matcher) ~= "table" or Matcher.cyrillic_patched then
    return
  end
  local orig_init, orig_match = Matcher.init, Matcher._match
  if type(orig_init) ~= "function" or type(orig_match) ~= "function" then
    vim.notify("snacks matcher changed; Cyrillic patch skipped", vim.log.levels.WARN)
    return
  end

  function Matcher:init(pattern)
    return orig_init(self, cyrillic_lower(with_layout_alternatives(pattern)))
  end

  function Matcher:_match(item, mods)
    local text = item.text
    if not mods.ignorecase or type(text) ~= "string" or not text:find("\208", 1, true) then
      return orig_match(self, item, mods)
    end
    if item.cyrillic_src ~= text then
      item.cyrillic_src, item.cyrillic_lc = text, cyrillic_lower(text)
    end
    item.text = item.cyrillic_lc
    local matched, result = pcall(orig_match, self, item, mods)
    item.text = text
    if not matched then
      error(result, 0)
    end
    return result
  end

  Matcher.cyrillic_patched = true
end

return {
  "folke/snacks.nvim",
  optional = true,
  opts = function(_, opts)
    patch_matcher()
    return opts
  end,
}
