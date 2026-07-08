-------------------------------------------------------------------------------
--                            Remote operations
-------------------------------------------------------------------------------

-- The following are used in all the remote motions
-- r - remote flash
-- {text} - stuff to search with flash
-- {flash_char} - character used to jump in flash

-- Surround in "", 4 words in a remote location
-- gsar{text}{flash_char}4e"
-- gsa - surround add (leaves you in pending mode)
-- 4e - select 4 words
-- " - surround in quotes

-- Paste text in '' in another line where my cursor is at
-- Mind blowing trick shared by Maria Solano
-- https://youtu.be/0DNC3uRPBwc?si=kHMTyvpEP6j8q9eD&t=3214
-- yr{text}{flash_char}a'p
-- y - copy mode (leaves you in pending)
-- a' - around ' (select the text around '')
-- p - paste

-- Bold a remote location
-- gsar{text}{flash_char}4e?**<CR>**<CR>
-- gsa - surround add (leaves you in pending mode)
-- 4e - select 4 words
-- ? - mini.surround interactive. Prompts user to enter left and right parts.

-------------------------------------------------------------------------------
--                         End of Remote operations
-------------------------------------------------------------------------------

-- Bilingual flash search: each typed char becomes a vim-regex collection of
-- itself + its ЙЦУКЕН counterpart on the same physical key ([gп], [hр], …),
-- so one `s` search matches both English and Russian text. Needed because
-- flash reads input via getchar(), bypassing langmap, and normal mode is
-- always US (see config/autocmds.lua). Works in both directions, so Cyrillic
-- input (async layout-switch gap) still finds Latin text too.
local en_ru = {
  q = "й",
  w = "ц",
  e = "у",
  r = "к",
  t = "е",
  y = "н",
  u = "г",
  i = "ш",
  o = "щ",
  p = "з",
  ["["] = "х",
  ["]"] = "ъ",
  a = "ф",
  s = "ы",
  d = "в",
  f = "а",
  g = "п",
  h = "р",
  j = "о",
  k = "л",
  l = "д",
  [";"] = "ж",
  ["'"] = "э",
  z = "я",
  x = "ч",
  c = "с",
  v = "м",
  b = "и",
  n = "т",
  m = "ь",
  [","] = "б",
  ["."] = "ю",
  ["`"] = "ё",
}
local ru_en = {}
for en, ru in pairs(en_ru) do
  ru_en[ru] = en
end

local function bilingual(str)
  local pat = { "\\V" }
  if str == vim.fn.tolower(str) then
    table.insert(pat, "\\c") -- smartcase: all-lowercase input ignores case
  end
  for _, ch in ipairs(vim.fn.split(str, "\\zs")) do
    local lower = vim.fn.tolower(ch)
    local other = en_ru[lower] or ru_en[lower]
    if other then
      if ch ~= lower then
        other = vim.fn.toupper(other)
      end
      if ch == "]" then -- ']' is only literal as the first char of a collection
        table.insert(pat, "\\[]" .. other .. "]")
      else
        table.insert(pat, "\\[" .. ch .. other .. "]")
      end
    else
      table.insert(pat, ch == "\\" and "\\\\" or ch)
    end
  end
  return table.concat(pat)
end

-- flash's labeler drops labels that could continue the search, but it checks
-- the literal buffer char after each match — for Russian text that char is
-- Cyrillic and never collides with the Latin label set. E.g. searching "н"
-- (key y): "е" on key t continues "не", yet `t` stays a label, so typing it
-- jumps to a random match instead of narrowing. Extra pass over the same
-- skip-pattern: also drop labels whose same-key Cyrillic partner continues a
-- match.
local function patch_labeler()
  local Labeler = require("flash.labeler")
  local orig_skip = Labeler.skip
  function Labeler:skip(win, labels)
    labels = orig_skip(self, win, labels) or {}
    local pattern = self.state.pattern.skip
    if pattern == "" or #labels == 0 or not pcall(vim.regex, pattern) then
      return labels
    end
    vim.api.nvim_win_call(win, function()
      while #labels > 0 do
        local group = {}
        for _, l in ipairs(labels) do
          local ru = en_ru[l:lower()]
          if ru then
            group[#group + 1] = ru .. vim.fn.toupper(ru)
          end
        end
        if #group == 0 then
          return
        end
        local p = "\\%(" .. pattern .. "\\)\\m\\zs[" .. table.concat(group) .. "]"
        local ok, pos = pcall(vim.fn.searchpos, p, "cnw")
        if not ok or pos[1] == 0 then
          return
        end
        local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
        local char = vim.fn.strpart(line, pos[2] - 1, 1, true)
        local latin = ru_en[vim.fn.tolower(char)]
        local before = #labels
        labels = vim.tbl_filter(function(c)
          return c:lower() ~= latin
        end, labels)
        if #labels == before then
          return -- safety net against an endless loop
        end
      end
    end)
    return labels
  end
end

-- Same bilingual treatment for f/t/F/T (flash's char mode): replace the
-- pattern builder so the typed char becomes the [cХ] collection of its
-- physical key — `f` + key `y` jumps to `y` or `н`, `dt` + key `t` deletes
-- up to `t` or `е`. `;`/`,` repeats go through the same builder, so they
-- inherit it. Everything except the atom is copied verbatim from upstream
-- Char.mode (flash/plugins/char.lua).
local function patch_char_mode()
  local Char = require("flash.plugins.char")
  local Config = require("flash.config")
  function Char.mode(motion)
    return function(c)
      local lower = vim.fn.tolower(c)
      local other = en_ru[lower] or ru_en[lower]
      local atom
      if other then
        if c ~= lower then
          other = vim.fn.toupper(other)
        end
        if c == "]" then -- ']' is only literal as the first char of a collection
          atom = "\\[]" .. other .. "]"
        else
          atom = "\\[" .. c .. other .. "]"
        end
      else
        atom = (c:gsub("\\", "\\\\"))
      end
      local pattern
      if motion == "t" then
        pattern = "\\m.\\ze\\V" .. atom
      elseif motion == "T" then
        pattern = "\\V" .. atom .. "\\zs\\m."
      else
        pattern = "\\V" .. atom
      end
      if not Config.get("char").multi_line then
        local pos = vim.api.nvim_win_get_cursor(0)
        pattern = ("\\%%%dl"):format(pos[1]) .. pattern
      end
      return pattern
    end
  end
end

return {
  "folke/flash.nvim",
  config = function(_, opts)
    require("flash").setup(opts)
    patch_labeler()
    patch_char_mode()
  end,
  opts = {
    labels = "fghjklqwetyupzcvbnm",
    search = {
      mode = bilingual,
    },
    modes = {
      char = {
        enabled = true,
      },
    },
  },
  keys = {
    {
      "s",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump({
          labels = "fghjklqwetyupzcvbnm",
        })
      end,
      desc = "Flash (EN+RU)",
    },
    -- The old `ы`/`Ы` mappings (RU labels) are gone: langmap now translates
    -- ы→s / Ы→S before mapping lookup, so they could never fire anyway.
    {
      "S",
      mode = { "n", "x", "o" },
      function()
        require("flash").treesitter()
      end,
      desc = "Flash Treesitter",
    },
  },
}
