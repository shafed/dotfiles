-- Obsidian vault helpers: auto commit+push of ~/obsidian, saving training
-- notes and exporting workout tables (used by <leader>l* and <leader>go).

local M = {}

-- Commit and push the vault. Returns false when cwd is not inside it.
function M.push(silent)
  local vault_path = vim.fn.expand("~/obsidian")
  local current_dir = vim.fn.getcwd()

  if current_dir:find(vault_path, 1, true) == nil then
    return false
  end

  vim.cmd("silent! wa")

  local commit_msg = "Vault backup: " .. os.date("%Y-%m-%d %H:%M:%S")
  -- Commit only when there is something to commit, but always push, so
  -- earlier unpushed commits don't get stuck until the next change
  local cmd = string.format(
    "cd %s && git add . && (git diff --cached --quiet || git commit -m '%s') && git push",
    vault_path,
    commit_msg
  )

  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 and not silent then
        vim.schedule(function()
          print("Obsidian Vault pushed successfully")
        end)
      end
    end,
  })

  return true
end

-- Cooldown защита
local last_push_time = 0
local PUSH_COOLDOWN = 3600

function M.push_with_cooldown()
  local now = os.time()
  if now - last_push_time < PUSH_COOLDOWN then
    return
  end
  if M.push(true) then
    last_push_time = now
  end
end

-- Copy workout data from last markdown table to clipboard lamw25wmal
function M.copy_workout_table()
  -- Get all lines from current buffer
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Find all tables in the buffer
  local tables = {}
  local current_table = {}
  local in_table = false

  for _, line in ipairs(lines) do
    if line:match("^|") then
      in_table = true
      table.insert(current_table, line)
    else
      if in_table and #current_table > 0 then
        table.insert(tables, current_table)
        current_table = {}
        in_table = false
      end
    end
  end

  if #current_table > 0 then
    table.insert(tables, current_table)
  end

  if #tables == 0 then
    vim.notify("No tables found!", vim.log.levels.WARN)
    return
  end

  local last_table = tables[#tables]
  local exercises = {}
  local data = {}

  -- Parse table rows (skip header and separator, start from row 3)
  for i = 3, #last_table do
    local line = last_table[i]
    local cells = {}

    for cell in line:gmatch("[^|]+") do
      table.insert(cells, vim.trim(cell))
    end

    if #cells >= 4 then
      local exercise = cells[2]
      local reps = cells[3]
      local weight = cells[4]

      local processed_reps = reps
      local match = reps:match("^%d+X([%d%-,]+)$")
      if match and match:find("-") then
        processed_reps = match
      end

      table.insert(exercises, exercise)
      table.insert(data, { processed_reps, weight, "kg" })
    end
  end

  if #exercises == 0 then
    vim.notify("No data to copy!", vim.log.levels.WARN)
    return
  end

  -- Line 1: exercise names separated by empty cells
  local line1_parts = {}
  for i, ex in ipairs(exercises) do
    table.insert(line1_parts, ex)
    if i < #exercises then
      table.insert(line1_parts, "")
      table.insert(line1_parts, "")
    end
  end

  -- Line 2: column headers (Reps/Weight) for each exercise
  local line2_parts = {}
  for i = 1, #exercises do
    table.insert(line2_parts, "Reps")
    table.insert(line2_parts, "Weight")
    if i < #exercises then
      table.insert(line2_parts, "")
    end
  end

  -- Line 3: actual data (reps/weight/kg) for each exercise
  local line3_parts = {}
  for _, d in ipairs(data) do
    table.insert(line3_parts, d[1])
    table.insert(line3_parts, d[2])
    table.insert(line3_parts, d[3])
  end

  local line1 = table.concat(line1_parts, "\t")
  local line2 = table.concat(line2_parts, "\t")
  local line3 = table.concat(line3_parts, "\t")
  local output = line1 .. "\n" .. line2 .. "\n" .. line3

  vim.fn.setreg("+", output)
  vim.notify("Copied: " .. #exercises .. " exercises", vim.log.levels.INFO)
end

-- Save the current buffer as a training note in periodic/training/
function M.save_training_note()
  local training_dir = vim.fn.expand("~/obsidian/periodic/training/")

  --------------------------------------------------------------------------
  -- Extract H1 from the current file to use as training note filename
  --------------------------------------------------------------------------
  local h1_text = nil
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 1, false)) do
    local match = line:match("^#%s+(.+)$")
    if match then
      h1_text = vim.trim(match)
      break
    end
  end

  if not h1_text then
    vim.notify("H1 heading not found in current file!", vim.log.levels.WARN)
    return
  end

  --------------------------------------------------------------------------
  -- Write current buffer contents to training/YYYY-MM-DD-<h1_text>.md
  -- h1_text is the filename without extension, e.g. "Day 2"
  -- training note slug: YYYY-MM-DD-Day-2 (date + h1 with spaces→dashes)
  --------------------------------------------------------------------------
  local date_prefix = os.date("%Y-%m-%d")
  local h1_slug = h1_text:gsub("%s+", "-")
  local training_slug = date_prefix .. "-" .. h1_slug
  local training_filename = training_slug .. ".md"
  local training_path = training_dir .. training_filename
  local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  -- Replace H1 with training_slug so file's H1 matches its filename
  for i, line in ipairs(buf_lines) do
    if line:match("^#%s+") then
      buf_lines[i] = "# " .. training_slug
      break
    end
  end
  vim.fn.writefile(buf_lines, training_path)

  vim.notify("Training note saved: " .. training_filename, vim.log.levels.INFO)
end

return M
