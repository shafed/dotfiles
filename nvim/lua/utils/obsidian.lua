-- Obsidian vault helpers: auto commit+push of ~/obsidian, saving training
-- notes and exporting workout tables (used by <leader>l* and <leader>go).
--
-- Push is fully detached rather than a plain nvim job: jobstart() children
-- are killed when nvim exits unless `detach = true`, and even detached, a
-- lingering stdout/stderr pipe can still make nvim's own quit wait on the
-- job (see :h jobstart() `detach`). So the command itself backgrounds via
-- `setsid ... &` and redirects to a log file -- the wrapper process jobstart
-- sees exits almost instantly (closing its pipes), while the actual git
-- push keeps running in its own session, immune to both nvim exiting and
-- the kitty tab closing right after. Net effect: push never adds a delay to
-- quitting nvim, on any of its trigger events.

local M = {}

local SYNC_SCRIPT = vim.fn.expand("~/dotfiles/scripts/obsidian-sync.sh")
local VAULT_PATH = vim.fn.expand("~/obsidian")
local LOG_FILE = vim.fn.stdpath("cache") .. "/obsidian-sync-push.log"

local function in_vault()
  return vim.fn.getcwd():find(VAULT_PATH, 1, true) ~= nil
end

local function push(silent)
  vim.cmd("silent! wa")
  local cmd = string.format(
    "setsid %s push %s >>%s 2>&1 </dev/null &",
    vim.fn.shellescape(SYNC_SCRIPT),
    silent and "silent" or "",
    vim.fn.shellescape(LOG_FILE)
  )
  vim.fn.jobstart({ "sh", "-c", cmd }, { detach = true })
end

-- Cooldown so alt-tabbing (FocusLost) doesn't spam commits/pushes.
local last_push_time = 0
local PUSH_COOLDOWN = 3600

function M.push_with_cooldown()
  if not in_vault() then
    return
  end
  local now = os.time()
  if now - last_push_time < PUSH_COOLDOWN then
    return
  end
  last_push_time = now
  push(true)
end

-- Always pushes, ignoring the cooldown -- used right before nvim actually
-- exits, so a push mid-cooldown-window doesn't eat the one that actually
-- mattered. Returns false when cwd is not inside the vault.
function M.push_now(silent)
  if not in_vault() then
    if not silent then
      print("Not in Obsidian Vault")
    end
    return false
  end
  push(silent)
  if not silent then
    print("Obsidian Vault: pushing in background (" .. LOG_FILE .. ")")
  end
  return true
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

-- Save the current buffer as a training note in training/
function M.save_training_note()
  local training_dir = vim.fn.expand("~/obsidian/training/Full Body 2026/")

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
  -- Ask for the session date (defaults to today) so late log entries can
  -- be dated to when the workout actually happened.
  --------------------------------------------------------------------------
  vim.ui.input({ prompt = "Session date: ", default = os.date("%Y-%m-%d") }, function(date_prefix)
    if not date_prefix or date_prefix == "" then
      vim.notify("Training note not saved: no date given", vim.log.levels.WARN)
      return
    end
    if not date_prefix:match("^%d%d%d%d%-%d%d%-%d%d$") then
      vim.notify("Training note not saved: date must be YYYY-MM-DD", vim.log.levels.ERROR)
      return
    end

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

    ------------------------------------------------------------------------
    -- Regenerate the training logbook HTML from the training vault.
    ------------------------------------------------------------------------
    local script = vim.fn.expand("~/dotfiles/scripts/generate_logbook.py")
    vim.fn.jobstart({ "python3", script }, {
      cwd = vim.fn.expand("~/obsidian/training"),
      on_exit = function(_, code)
        vim.schedule(function()
          if code == 0 then
            vim.notify("logbook.html regenerated", vim.log.levels.INFO)
          else
            vim.notify("generate_logbook.py failed (exit " .. code .. ")", vim.log.levels.ERROR)
          end
        end)
      end,
    })
  end)
end

return M
