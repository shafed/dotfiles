-- Markdown task helpers:
--   M.toggle_done — toggle a task and move it under "## Completed Tasks"
--   M.create     — convert a line/bullet into a "- [ ]" task bullet
--   M.yank_text  — copy a task bullet's text (without "- [ ]"/"- [x]") to clipboard

local M = {}

local function restore_view(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_call(win, function()
      vim.cmd("loadview")
    end)
  end
end

local function save_buffer(buf)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent update")
  end)
end

-- Resolve which buffer/line to operate on. When called with `opts.file` (e.g.
-- from the Snacks task picker) it loads that file off-screen so the task can be
-- toggled without the file being the current buffer. With no opts it falls back
-- to the current window/cursor (used by the in-buffer <M-x> mapping).
local function get_task_context(opts)
  opts = opts or {}

  if opts.file then
    local path = vim.fn.fnamemodify(vim.fn.expand(opts.file), ":p")
    local buf = vim.fn.bufadd(path)
    vim.fn.bufload(buf)

    if not vim.api.nvim_buf_is_loaded(buf) then
      vim.notify("Could not load task file: " .. path, vim.log.levels.ERROR)
      return nil
    end

    return {
      buf = buf,
      start_line = math.max((opts.line or 1) - 1, 0),
      win = nil,
    }
  end

  local win = vim.api.nvim_get_current_win()
  local cursor_pos = vim.api.nvim_win_get_cursor(win)

  vim.api.nvim_win_call(win, function()
    vim.cmd("mkview")
  end)

  return {
    buf = vim.api.nvim_get_current_buf(),
    start_line = cursor_pos[1] - 1,
    win = win,
  }
end

-- If there is no `untoggled` or `done` label on an item, mark it as done
-- and move it to the "## completed tasks" markdown heading in the same file, if
-- the heading does not exist, it will be created, if it exists, items will be
-- appended to it at the top
--
-- If an item is moved to that heading, it will be added the `done` label
--
-- `opts` is optional: { file = <path>, line = <1-based line> }. When omitted the
-- current window/cursor is used. Returns true if a task was changed.
function M.toggle_done(opts)
  local context = get_task_context(opts)
  if not context then
    return false
  end

  -- Customizable variables
  -- NOTE: Customize the completion label
  local label_done = "done:"
  -- NOTE: Customize the timestamp format
  local timestamp = os.date("%Y-%m-%d-%H:%M")
  -- NOTE: Customize the heading and its level
  local tasks_heading = "## Completed Tasks"
  local api = vim.api
  -- Retrieve buffer & lines
  local buf = context.buf
  local start_line = context.start_line
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local total_lines = #lines
  -- If cursor is beyond last line, do nothing
  if start_line >= total_lines then
    restore_view(context.win)
    return false
  end
  ------------------------------------------------------------------------------
  -- (A) Move upwards to find the bullet line (if user is somewhere in the chunk)
  ------------------------------------------------------------------------------
  while start_line > 0 do
    local line_text = lines[start_line + 1]
    -- Stop if we find a blank line or a bullet line
    if line_text == "" or line_text:match("^%s*%-") then
      break
    end
    start_line = start_line - 1
  end
  -- Now we might be on a blank line or a bullet line
  if lines[start_line + 1] == "" and start_line < (total_lines - 1) then
    start_line = start_line + 1
  end
  ------------------------------------------------------------------------------
  -- (B) Validate that it's actually a task bullet, i.e. '- [ ]' or '- [x]'
  ------------------------------------------------------------------------------
  local bullet_line = lines[start_line + 1]
  if not bullet_line:match("^%s*%- %[[x ]%]") then
    -- Not a task bullet => show a message and return
    print("Not a task bullet: no action taken.")
    restore_view(context.win)
    return false
  end
  ------------------------------------------------------------------------------
  -- 1. Identify the chunk boundaries
  ------------------------------------------------------------------------------
  local chunk_start = start_line
  local chunk_end = start_line
  while chunk_end + 1 < total_lines do
    local next_line = lines[chunk_end + 2]
    if next_line == "" or next_line:match("^%s*%-") then
      break
    end
    chunk_end = chunk_end + 1
  end
  -- Collect the chunk lines
  local chunk = {}
  for i = chunk_start, chunk_end do
    table.insert(chunk, lines[i + 1])
  end
  ------------------------------------------------------------------------------
  -- 2. Check if chunk has [done: ...] or [untoggled], then transform them
  ------------------------------------------------------------------------------
  local has_done_index = nil
  local has_untoggled_index = nil
  for i, line in ipairs(chunk) do
    -- Replace `[done: ...]` -> `` `done: ...` ``
    chunk[i] = line:gsub("%[done:([^%]]+)%]", "`" .. label_done .. "%1`")
    -- Replace `[untoggled]` -> `` `untoggled` ``
    chunk[i] = chunk[i]:gsub("%[untoggled%]", "`untoggled`")
    if chunk[i]:match("`" .. label_done .. ".-`") then
      has_done_index = i
      break
    end
  end
  if not has_done_index then
    for i, line in ipairs(chunk) do
      if line:match("`untoggled`") then
        has_untoggled_index = i
        break
      end
    end
  end
  ------------------------------------------------------------------------------
  -- 3. Helpers to toggle bullet
  ------------------------------------------------------------------------------
  -- Convert '- [ ]' to '- [x]'
  local function bulletToX(line)
    return line:gsub("^(%s*%- )%[%s*%]", "%1[x]")
  end
  -- Convert '- [x]' to '- [ ]'
  local function bulletToBlank(line)
    return line:gsub("^(%s*%- )%[x%]", "%1[ ]")
  end
  ------------------------------------------------------------------------------
  -- 4. Insert or remove label *after* the bracket
  ------------------------------------------------------------------------------
  local function insertLabelAfterBracket(line, label)
    local prefix = line:match("^(%s*%- %[[x ]%])")
    if not prefix then
      return line
    end
    local rest = line:sub(#prefix + 1)
    return prefix .. " " .. label .. rest
  end
  local function removeLabel(line)
    -- If there's a label (like `` `done: ...` `` or `` `untoggled` ``) right after
    -- '- [x]' or '- [ ]', remove it
    return line:gsub("^(%s*%- %[[x ]%])%s+`.-`", "%1")
  end
  ------------------------------------------------------------------------------
  -- 5. Update the buffer with new chunk lines (in place)
  ------------------------------------------------------------------------------
  local function updateBufferWithChunk(new_chunk)
    for idx = chunk_start, chunk_end do
      lines[idx + 1] = new_chunk[idx - chunk_start + 1]
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
  ------------------------------------------------------------------------------
  -- 6. Main toggle logic
  ------------------------------------------------------------------------------
  if has_done_index then
    chunk[has_done_index] = removeLabel(chunk[has_done_index]):gsub("`" .. label_done .. ".-`", "`untoggled`")
    chunk[1] = bulletToBlank(chunk[1])
    chunk[1] = removeLabel(chunk[1])
    chunk[1] = insertLabelAfterBracket(chunk[1], "`untoggled`")
    updateBufferWithChunk(chunk)

    vim.notify("Untoggled", vim.log.levels.INFO)
  elseif has_untoggled_index then
    chunk[has_untoggled_index] =
      removeLabel(chunk[has_untoggled_index]):gsub("`untoggled`", "`" .. label_done .. " " .. timestamp .. "`")
    chunk[1] = bulletToX(chunk[1])
    chunk[1] = removeLabel(chunk[1])
    chunk[1] = insertLabelAfterBracket(chunk[1], "`" .. label_done .. " " .. timestamp .. "`")
    updateBufferWithChunk(chunk)

    vim.notify("Completed", vim.log.levels.INFO)
  else
    -- Save original window view before modifications
    local win = context.win
    local view = win
        and api.nvim_win_is_valid(win)
        and api.nvim_win_call(win, function()
          return vim.fn.winsaveview()
        end)
      or nil
    chunk[1] = bulletToX(chunk[1])
    chunk[1] = insertLabelAfterBracket(chunk[1], "`" .. label_done .. " " .. timestamp .. "`")

    -- Remove chunk from the original lines
    for i = chunk_end, chunk_start, -1 do
      table.remove(lines, i + 1)
    end
    -- Append chunk under 'tasks_heading'
    local heading_index = nil
    for i, line in ipairs(lines) do
      if line:match("^" .. tasks_heading) then
        heading_index = i
        break
      end
    end
    if heading_index then
      for _, cLine in ipairs(chunk) do
        table.insert(lines, heading_index + 1, cLine)
        heading_index = heading_index + 1
      end
      local after_last_item = heading_index + 1
      if lines[after_last_item] == "" then
        table.remove(lines, after_last_item)
      end
    else
      table.insert(lines, tasks_heading)
      for _, cLine in ipairs(chunk) do
        table.insert(lines, cLine)
      end
      local after_last_item = #lines + 1
      if lines[after_last_item] == "" then
        table.remove(lines, after_last_item)
      end
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.notify("Completed", vim.log.levels.INFO)
    -- Restore window view to preserve scroll position
    if win and view then
      api.nvim_win_call(win, function()
        vim.fn.winrestview(view)
      end)
    end
  end
  -- Write changes and restore view to preserve folds
  save_buffer(buf)
  restore_view(context.win)
  return true
end

-- Convert the current line into a "- [ ]" task bullet (or insert a fresh one
-- on an empty line) and leave the cursor right after the brackets. If the
-- line is already a task bullet ("- [ ]"/"- [x]"), toggle it back into a
-- plain bullet instead.
function M.create()
  -- Get the current line/row/column
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row, _ = cursor_pos[1], cursor_pos[2]
  local line = vim.api.nvim_get_current_line()
  -- 1) If line is empty => replace it with "- [ ] " and set cursor after the brackets
  if line:match("^%s*$") then
    local final_line = "- [ ] "
    vim.api.nvim_set_current_line(final_line)
    -- "- [ ] " is 6 characters, so cursor col = 6 places you *after* that space
    vim.api.nvim_win_set_cursor(0, { row, 6 })
    return
  end
  -- 2) If line is already a task bullet => strip "[ ]"/"[x]" back to a plain bullet
  local plain_bullet, after_checkbox = line:match("^([%s]*[-*]%s+)%[[x ]%]%s*(.*)$")
  if plain_bullet then
    local final_line = plain_bullet .. after_checkbox
    vim.api.nvim_set_current_line(final_line)
    vim.api.nvim_win_set_cursor(0, { row, #plain_bullet })
    return
  end
  -- 3) Check if line already has a bullet with possible indentation: e.g. "  - Something"
  --    We'll capture "  -" (including trailing spaces) as `bullet` plus the rest as `text`.
  local bullet, text = line:match("^([%s]*[-*]%s+)(.*)$")
  if bullet then
    -- Convert bullet => bullet .. "[ ] " .. text
    local final_line = bullet .. "[ ] " .. text
    vim.api.nvim_set_current_line(final_line)
    -- Place the cursor right after "[ ] " (bullet length + 4 characters, 0-based)
    vim.api.nvim_win_set_cursor(0, { row, #bullet + 4 })
    return
  end
  -- 4) If there's text, but no bullet => prepend "- [ ] "
  --    and place cursor after the brackets
  local final_line = "- [ ] " .. line
  vim.api.nvim_set_current_line(final_line)
  -- "- [ ] " is 6 characters
  vim.api.nvim_win_set_cursor(0, { row, 6 })
end

local yank_namespace = vim.api.nvim_create_namespace("markdown_yank_item")

local flash_generation = 0

---Parse a Markdown structural prefix.
---@param line string
---@return table|nil
local function parse_prefix(line)
  local rest = line
  local col = 0

  -- Initial indentation
  local indent = rest:match("^%s*") or ""
  col = col + #indent
  rest = rest:sub(#indent + 1)

  -- One or more blockquote markers:
  -- > text
  -- >> text
  -- > > text
  local quote_level = 0

  while true do
    local quote = rest:match("^>%s*")

    if not quote then
      break
    end

    quote_level = quote_level + 1
    col = col + #quote
    rest = rest:sub(#quote + 1)
  end

  -- Unordered or ordered list marker:
  -- - text
  -- * text
  -- + text
  -- 1. text
  -- 1) text
  local list = rest:match("^[-*+]%s+") or rest:match("^%d+[.)]%s+")

  if list then
    col = col + #list
    rest = rest:sub(#list + 1)

    -- Task checkbox, including Obsidian custom states:
    -- [ ], [x], [-], [/], [!], etc.
    local task = rest:match("^%[[^%]]%]%s*")

    if task then
      col = col + #task
    end

    return {
      kind = "list",
      col = col,
      quote_level = quote_level,
    }
  end

  -- Markdown heading
  local heading = rest:match("^#+%s+")

  if heading then
    col = col + #heading

    return {
      kind = "heading",
      col = col,
      quote_level = quote_level,
    }
  end

  -- Plain blockquote
  if quote_level > 0 then
    return {
      kind = "quote",
      col = col,
      quote_level = quote_level,
    }
  end

  return nil
end

---@param line string
---@return boolean
local function is_blank(line)
  return line:match("^%s*$") ~= nil
end

---Find the complete Markdown item under the cursor.
---Wrapped continuation lines are included.
---@param lines string[]
---@param cursor_line integer 0-based
---@return integer|nil start_line
---@return integer|nil end_line
local function find_item_range(lines, cursor_line)
  local start_line = cursor_line
  local item = parse_prefix(lines[start_line + 1] or "")

  -- Cursor can be on a wrapped continuation line.
  while not item do
    local current = lines[start_line + 1] or ""

    if is_blank(current) or start_line == 0 then
      return nil, nil
    end

    start_line = start_line - 1
    item = parse_prefix(lines[start_line + 1] or "")
  end

  -- A quote consists of consecutive quote lines.
  if item.kind == "quote" then
    while start_line > 0 do
      local previous = parse_prefix(lines[start_line] or "")

      if not previous or previous.kind ~= "quote" then
        break
      end

      start_line = start_line - 1
    end

    local end_line = start_line

    while end_line + 1 < #lines do
      local following = parse_prefix(lines[end_line + 2] or "")

      if not following or following.kind ~= "quote" then
        break
      end

      end_line = end_line + 1
    end

    return start_line, end_line
  end

  -- Headings are always a single line.
  if item.kind == "heading" then
    return start_line, start_line
  end

  -- List/task item: include wrapped lines until the next item or blank.
  local end_line = start_line

  while end_line + 1 < #lines do
    local next_line = lines[end_line + 2] or ""

    if is_blank(next_line) then
      break
    end

    local following = parse_prefix(next_line)

    if following then
      -- A new list item or heading starts another chunk.
      if following.kind == "list" or following.kind == "heading" then
        break
      end

      -- A quote following an ordinary list is a new block.
      if following.kind == "quote" and item.quote_level == 0 then
        break
      end

      -- Inside a blockquote, a quote-only line can be a wrapped
      -- continuation of "> - item".
      if following.kind == "quote" and following.quote_level < item.quote_level then
        break
      end
    end

    end_line = end_line + 1
  end

  return start_line, end_line
end

---Flash the original copied range.
---@param buf integer
---@param lines string[]
---@param start_line integer 0-based
---@param end_line integer 0-based
local function flash_range(buf, lines, start_line, end_line)
  flash_generation = flash_generation + 1
  local current_generation = flash_generation

  vim.api.nvim_buf_clear_namespace(buf, yank_namespace, 0, -1)

  for line_number = start_line, end_line do
    local line = lines[line_number + 1] or ""
    local prefix = parse_prefix(line)
    local start_col = prefix and prefix.col or 0

    if #line > start_col then
      vim.api.nvim_buf_set_extmark(buf, yank_namespace, line_number, start_col, {
        end_row = line_number,
        end_col = #line,
        hl_group = "IncSearch",
        priority = 200,
      })
    end
  end

  vim.defer_fn(function()
    if current_generation ~= flash_generation then
      return
    end

    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, yank_namespace, 0, -1)
    end
  end, 180)
end

---Copy Markdown item text without structural prefixes.
---
---Normal mode:
---  Copies the item under the cursor, including wrapped lines.
---
---Visual mode:
---  Copies all selected lines and strips the Markdown prefix
---  independently from every selected item.
---
---@param visual boolean|nil
function M.yank_text(visual)
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local start_line
  local end_line

  if visual then
    local visual_line = vim.fn.getpos("v")[2] - 1
    local cursor_line = vim.fn.getpos(".")[2] - 1

    start_line = math.min(visual_line, cursor_line)
    end_line = math.max(visual_line, cursor_line)
  else
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

    start_line, end_line = find_item_range(lines, cursor_line)

    if not start_line then
      vim.notify("Cursor is not on a Markdown item", vim.log.levels.INFO)
      return
    end
  end

  local result = {}
  local found_prefix = false

  for line_number = start_line, end_line do
    local line = lines[line_number + 1] or ""
    local prefix = parse_prefix(line)

    if prefix then
      found_prefix = true
      line = line:sub(prefix.col + 1)
    end

    result[#result + 1] = line
  end

  if visual and not found_prefix then
    vim.notify("Selection contains no Markdown items", vim.log.levels.INFO)
    return
  end

  local text = table.concat(result, "\n")

  -- System clipboard and unnamed register.
  vim.fn.setreg("+", text, "v")
  vim.fn.setreg('"', text, "v")

  flash_range(buf, lines, start_line, end_line)
end

return M
