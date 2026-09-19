-- Case-insensitive Cyrillic search for snacks pickers that ask for it.
--
-- snacks' matcher folds case with Lua string.lower, which only knows ASCII, so
-- smartcase silently degrades into case-sensitive search for Cyrillic: "жор"
-- misses "Предмет Жоры" while "Жор" finds it. No option fixes this — smartcase
-- and ignorecase are booleans feeding that same ASCII-only :lower().
--
-- Opt-in per picker: only a matcher built inside M.with() is affected, so file
-- and grep pickers keep stock behaviour.
local M = {}

local CASE_OFFSET = 0x20

-- Lowercases Cyrillic only; ASCII is left alone so snacks keeps its own
-- smartcase ("Trans" still refuses to match "transcriber bot"). Byte length is
-- preserved, so match positions stay valid and highlighting does not drift.
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
-- token is an alternative", so append the ЙЦУКЕН twin instead of replacing the
-- token: ";jhf" then finds "Жора" while a literal ";jhf" still matches too.
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

local patched = false
local marking = false

local function patch()
  if patched then
    return
  end
  patched = true
  local ok, Matcher = pcall(require, "snacks.picker.core.matcher")
  if not ok or type(Matcher) ~= "table" then
    return
  end
  local orig_new, orig_init, orig_match = Matcher.new, Matcher.init, Matcher._match
  if type(orig_new) ~= "function" or type(orig_init) ~= "function" or type(orig_match) ~= "function" then
    vim.notify("snacks matcher changed; Cyrillic search not applied", vim.log.levels.WARN)
    return
  end

  Matcher.new = function(opts)
    local matcher = orig_new(opts)
    if marking then
      matcher.opts.cyrillic = true
    end
    return matcher
  end

  function Matcher:init(pattern)
    if not self.opts.cyrillic then
      return orig_init(self, pattern)
    end
    return orig_init(self, cyrillic_lower(with_layout_alternatives(pattern)))
  end

  function Matcher:_match(item, mods)
    local text = item.text
    if
      not self.opts.cyrillic
      or not mods.ignorecase
      or type(text) ~= "string"
      or not text:find("\208", 1, true)
    then
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
end

-- Runs fn with any picker it opens marked for Cyrillic matching. The matcher is
-- built synchronously inside pick() and lives until the picker closes, so the
-- mark only has to survive this call.
function M.with(fn)
  patch()
  marking = true
  local ok, result = pcall(fn)
  marking = false
  if not ok then
    error(result, 0)
  end
  return result
end

return M
