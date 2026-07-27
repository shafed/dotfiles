-- Daily note review helpers: fold the last N daily notes of ~/obsidian into
-- one scratch buffer, or show the same calendar day across previous years
-- (used by <leader>lw, <leader>lm and <leader>ld).

local M = {}

local vault = vim.fn.expand("~/obsidian")

-- Drop YAML frontmatter and the meta-bind-button blocks left over from the
-- Obsidian daily template, they are noise when reading many notes at once
local function clean(lines)
  local out, in_frontmatter, in_metabind = {}, false, false

  for i, line in ipairs(lines) do
    if i == 1 and line == "---" then
      in_frontmatter = true
    elseif in_frontmatter then
      if line == "---" then
        in_frontmatter = false
      end
    elseif line:match("^```meta%-bind") then
      in_metabind = true
    elseif in_metabind then
      if line == "```" then
        in_metabind = false
      end
    else
      table.insert(out, line)
    end
  end

  while #out > 0 and out[#out]:match("^%s*$") do
    table.remove(out)
  end

  return out
end

-- A note counts as written only if it has something besides its headings,
-- otherwise it's just the untouched template
local function meaningful(lines)
  local size = 0

  for _, line in ipairs(lines) do
    if not line:match("^%s*$") and not line:match("^#") then
      size = size + #vim.trim(line)
    end
  end

  -- Count characters, not lines: the older notes hold a whole day in a single
  -- unwrapped paragraph, and a line count would discard them as empty
  return size >= 20
end

-- periodic/2026/07-Jul/2026-07-25-Saturday.md
-- Month and weekday names come from strftime, so this assumes an English
-- locale (LANG=en_US.UTF-8 here), same as the names the vault already uses
local function daily_path(time)
  return string.format(
    "%s/periodic/%s/%s/%s.md",
    vault,
    os.date("%Y", time),
    os.date("%m-%b", time),
    os.date("%Y-%m-%d-%A", time)
  )
end

-- Read a daily note, return its cleaned body only when it was actually used
local function read_daily(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local body = clean(vim.fn.readfile(path))

  return meaningful(body) and body or nil
end

-- Which notes got the most commits in the period. The vault is auto-committed
-- by utils.obsidian, so this is a free record of where the attention went
local function git_activity(days)
  local cmd = string.format(
    "git -C %s log --since='%d days ago' --name-only --pretty=format: "
      .. "| grep '\\.md$' | grep -v '^\\.obsidian/' | sort | uniq -c | sort -rn | head -15",
    vim.fn.shellescape(vault),
    days
  )

  return vim.fn.systemlist(cmd)
end

local function open_scratch(lines)
  vim.cmd("enew")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "markdown"
  -- Keep the BufLeave autoformat autocmd away from a throwaway buffer
  vim.b.autoformat = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modifiable = false
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

-- Collect the daily notes of the last `days` days into one buffer
function M.review(days)
  days = days or 7

  local out, written, blank = {}, 0, 0

  for offset = days, 1, -1 do
    local body = read_daily(daily_path(os.time() - offset * 86400))

    if body then
      vim.list_extend(out, body)
      vim.list_extend(out, { "", "---", "" })
      written = written + 1
    else
      blank = blank + 1
    end
  end

  table.insert(out, 1, string.format("> %d days: %d written, %d blank", days, written, blank))
  table.insert(out, 2, "")

  -- For a month or more the git history says more than the notes themselves
  if days >= 28 then
    local activity = git_activity(days)

    if #activity > 0 then
      vim.list_extend(out, { "# Most edited notes", "" })

      for _, line in ipairs(activity) do
        table.insert(out, "- " .. vim.trim(line))
      end
    end
  end

  open_scratch(out)
end

-- The same calendar day in every previous year
function M.on_this_day()
  local today = os.date("*t")
  local out = {}

  for year = 2021, today.year - 1 do
    -- The weekday differs from year to year, so glob the tail of the name
    local pattern = string.format(
      "%s/periodic/%d/%02d-%s/%d-%02d-%02d-*.md",
      vault,
      year,
      today.month,
      os.date("%b"),
      year,
      today.month,
      today.day
    )

    for _, path in ipairs(vim.fn.glob(pattern, false, true)) do
      local body = read_daily(path)

      if body then
        vim.list_extend(out, body)
        vim.list_extend(out, { "", "---", "" })
      end
    end
  end

  if #out == 0 then
    out = { "> nothing written on this day in previous years" }
  end

  open_scratch(out)
end

return M
