-- Obsidian vault helpers for manually pushing the vault, saving training notes
-- and exporting workout tables (used by <leader>go and <leader>l*).

local M = {}

local VAULT_PATH = vim.fn.expand("~/github/obsidian")
local LOGBOOK_SCRIPT = vim.fn.expand("~/github/dotfiles/scripts/generate_logbook.py")

local function in_vault()
  return vim.fn.getcwd():find(VAULT_PATH, 1, true) ~= nil
end

-- Manual <leader>go implementation. The same runtime lock path is used by
-- obsidian-git-view-sync, so a manual commit/push cannot race with automatic
-- HEAD/index catch-up.
local MANUAL_PUSH_SCRIPT = [=[
set -euo pipefail

vault="$1"
branch="${OBSIDIAN_GIT_BRANCH:-main}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp/obsidian-git-${UID}}/obsidian-git"
mkdir -p "$runtime_dir"
lock_file="$runtime_dir/lock$(printf '%s' "$vault" | md5sum | cut -c1-8)"

exec 9>"$lock_file"
flock 9

cd "$vault"

current_branch="$(git symbolic-ref -q --short HEAD 2>/dev/null || true)"
if [[ "$current_branch" != "$branch" ]]; then
  echo "blocked: current branch is '${current_branch:-detached}', expected '$branch'" >&2
  exit 23
fi

git_dir="$(git rev-parse --git-dir)"
if [[ -f "$git_dir/MERGE_HEAD" ||
      -f "$git_dir/CHERRY_PICK_HEAD" ||
      -f "$git_dir/REVERT_HEAD" ||
      -d "$git_dir/rebase-merge" ||
      -d "$git_dir/rebase-apply" ]]; then
  echo "blocked: Git operation in progress" >&2
  exit 24
fi

GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" \
  git fetch --quiet origin "$branch"

if ! git merge-base --is-ancestor "origin/$branch" HEAD; then
  if git merge-base --is-ancestor HEAD "origin/$branch"; then
    echo "blocked: local Git metadata is behind origin/$branch; wait for git-view-sync" >&2
    exit 20
  fi
  echo "blocked: local $branch has diverged from origin/$branch" >&2
  exit 25
fi

git add -A

if ! git diff --cached --quiet --; then
  git commit --quiet -m "Vault backup: $(date '+%Y-%m-%d %H:%M:%S')"
fi

GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" \
  git push --quiet origin "$branch"
]=]

-- Keep the manual push detached so it can finish if nvim or its kitty tab is
-- closed immediately after the keymap is used. While nvim remains open, report
-- only a short success/error notification; no persistent push log is written.
function M.push_now()
  if not in_vault() then
    print("Not in Obsidian Vault")
    return false
  end

  vim.cmd("silent! wa")

  local output = {}
  local function collect(_, data)
    for _, line in ipairs(data or {}) do
      if line ~= "" then
        table.insert(output, line)
      end
    end
  end

  local job = vim.fn.jobstart({ "bash", "-c", MANUAL_PUSH_SCRIPT, "obsidian-manual-push", VAULT_PATH }, {
    detach = true,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = collect,
    on_stderr = collect,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          vim.notify("Obsidian Vault: pushed", vim.log.levels.INFO)
          return
        end

        local detail = vim.trim(table.concat(output, "\n"))
        if detail == "" then
          detail = "exit " .. code
        end
        vim.notify("Obsidian Vault push failed:\n" .. detail, vim.log.levels.ERROR)
      end)
    end,
  })

  if job <= 0 then
    vim.notify("Obsidian Vault: failed to start manual push", vim.log.levels.ERROR)
    return false
  end

  vim.notify("Obsidian Vault: pushing…", vim.log.levels.INFO)
  return true
end

-- Copy workout data from last markdown table to clipboard
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
  local training_dir = vim.fn.expand(("~/github/obsidian/training/Full Body %s/"):format(os.date("%Y")))

  --------------------------------------------------------------------------
  -- Training notes now use one fixed filename shape: YYYY-MM-DD-Training.md.
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

    local training_slug = date_prefix .. "-Training"
    local training_filename = training_slug .. ".md"
    local training_path = training_dir .. training_filename
    local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- Keep the document heading aligned with the fixed filename when an H1
    -- exists, but do not require the source buffer's H1 to determine the name.
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
    M.regenerate_logbook({ silent = true })
  end)
end

-- Regenerate logbook.html from the training vault. Used automatically after
-- saving a training note and manually via <leader>lr. Guards on the script
-- existing and reports failures via notify.
function M.regenerate_logbook(opts)
  opts = opts or {}
  if vim.fn.filereadable(LOGBOOK_SCRIPT) == 0 then
    vim.notify("Logbook generator not found: " .. LOGBOOK_SCRIPT, vim.log.levels.ERROR)
    return
  end
  if not opts.silent then
    vim.notify("Regenerating logbook…", vim.log.levels.INFO)
  end
  vim.system({ "python3", LOGBOOK_SCRIPT }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        local out = (res.stdout or "") .. (res.stderr or "")
        vim.notify("Logbook generation failed:\n" .. vim.trim(out), vim.log.levels.ERROR)
        return
      end
      if not opts.silent then
        vim.notify("logbook.html regenerated", vim.log.levels.INFO)
      end
    end)
  end)
end

return M
