-- Google Calendar (gcalcli) integration.
-- Create an event from the current task line. Date comes from a wikilink:
--   - [ ] Sync vault [[2026/04-Apr/2026-04-18-Saturday]]          -> all-day on that date
--   - [ ] Meeting [[2026/04-Apr/2026-04-18-Saturday]] 15:00        -> 1h event at 15:00
--   - [ ] Call [[2026/04-Apr/2026-04-18-Saturday]] 15:00-16:30     -> explicit duration
-- Appends <!-- gcal:<event-id> --> to the line to prevent duplicate creation.

local M = {}

M.calendar = "shaparenko.fedor@gmail.com"

function M.create_from_line()
  local line = vim.api.nvim_get_current_line()

  if line:match("<!%-%- gcal:") then
    vim.notify("gcal: event already created for this line", vim.log.levels.WARN)
    return
  end

  local date = line:match("%[%[[^%]]-(%d%d%d%d%-%d%d%-%d%d)[^%]]-%]%]")
  if not date then
    vim.notify("gcal: no date wikilink [[.../YYYY-MM-DD-...]] on line", vim.log.levels.ERROR)
    return
  end

  local start_t, end_t = line:match("(%d?%d:%d%d)%-(%d?%d:%d%d)")
  if not start_t then
    start_t = line:match("(%d?%d:%d%d)")
  end
  if start_t and #start_t == 4 then
    start_t = "0" .. start_t
  end
  if end_t and #end_t == 4 then
    end_t = "0" .. end_t
  end
  local all_day = start_t == nil

  local title = line
    :gsub("^%s*%- %[[ x]%]%s*", "")
    :gsub("^%s*%-%s*", "")
    :gsub("%[%[[^%]]-%]%]", "")
    :gsub("%d?%d:%d%d%-%d?%d:%d%d", "")
    :gsub("%d?%d:%d%d", "")
    :gsub("<!%-%-.-%-%->", "")
    :gsub("/[^/<!%s]+/[^/<!%s]*", "")
    :gsub("%s+", " ")
    :gsub("%s+$", "")
    :gsub("^%s+", "")

  if title == "" then
    vim.notify("gcal: empty title", vim.log.levels.WARN)
    return
  end

  local tz = tostring(os.date("%z")):gsub("(%+?%-?%d%d)(%d%d)", "%1:%2")
  local when
  local duration_min
  if all_day then
    when = date .. "T09:00:00" .. tz
    duration_min = 30
  else
    when = date .. "T" .. start_t .. ":00" .. tz
    if end_t then
      local sh, sm = start_t:match("(%d+):(%d+)")
      local eh, em = end_t:match("(%d+):(%d+)")
      duration_min = (tonumber(eh) * 60 + tonumber(em)) - (tonumber(sh) * 60 + tonumber(sm))
      if duration_min <= 0 then
        duration_min = 30
      end
    else
      duration_min = 30
    end
  end
  local cmd = string.format(
    "gcalcli --calendar %s add --noprompt --title %s --when %s --duration %d --reminder '0 popup' 2>&1",
    vim.fn.shellescape(M.calendar),
    vim.fn.shellescape(title),
    vim.fn.shellescape(when),
    duration_min
  )

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      local out = table.concat(data or {}, "\n")
      local event_id = out:match("id=([%w_-]+)") or out:match("eid=([%w_-]+)")
      vim.schedule(function()
        local cur = vim.api.nvim_get_current_line()
        if event_id and not cur:match("<!%-%- gcal:") then
          vim.api.nvim_set_current_line(cur:gsub("%s+$", "") .. " <!-- gcal:" .. event_id .. " -->")
        end
        vim.notify("gcal: event created — " .. title, vim.log.levels.INFO)
      end)
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify("gcal: error (exit " .. code .. ")", vim.log.levels.ERROR)
        end)
      end
    end,
  })
end

-- Show upcoming events in a terminal split
function M.agenda()
  vim.cmd(
    "botright 15split | terminal gcalcli --calendar "
      .. vim.fn.shellescape(M.calendar)
      .. " agenda --military --details=all"
  )
end

return M
