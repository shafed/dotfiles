-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local wk = require("which-key")
wk.add({ { mode = { "n" }, { "<leader>t", group = "[P]todo" }, { "<leader>l", group = "[P]Log" } } })

-- LazyGit Keymap
if vim.fn.executable("lazygit") == 1 then
  vim.keymap.set("n", "<M-g>", function()
    Snacks.lazygit({ cwd = LazyVim.root.git() })
  end, { desc = "Lazygit (Root Dir)" })
end

vim.keymap.set({ "n", "v" }, "gh", "^", { desc = "[P]Go to the beginning line" })
vim.keymap.set({ "n", "v" }, "gl", "$", { desc = "[P]go to the end of the line" })

-- Fast quit
vim.keymap.set({ "n", "v", "i" }, "<M-q>", "<cmd>q!<cr>", { desc = "[P]Quit All" })
vim.keymap.set({ "n", "v", "i" }, "<M-esc>", "<cmd>q!<cr>", { desc = "[P]Quit All" })

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "[P]Yank to system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>Y", [["+Y]], { desc = "[P]Yank line to system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]], { desc = "[P]Paste from system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>d", [["+d]], { desc = "[P]Delete to system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>D", [["+D]], { desc = "[P]Delete line to system clipboard" })

-- Paste unformatted text from Neovim
if vim.g.simpler_scrollback ~= "deeznuts" then
  vim.keymap.set("v", "y", function()
    -- Check if the current buffer's filetype is markdown
    if vim.bo.filetype ~= "markdown" then
      -- Not a Markdown file, copy the selection to the system clipboard
      vim.cmd('normal! "+y')
      -- Optionally, notify the user
      vim.notify("Yanked to system clipboard", vim.log.levels.INFO)
      return
    end
    -- Yank the selected text into register 'z' without affecting the unnamed register
    vim.cmd('silent! normal! "zy')
    -- Get the yanked text from register 'z'
    local text = vim.fn.getreg("z")
    -- Path to a temporary file (uses a unique temporary file name)
    local temp_file = vim.fn.tempname() .. ".md"
    -- Write the selected text to the temporary file
    local file = io.open(temp_file, "w")
    if file == nil then
      vim.notify("Error: Cannot write to temporary file.", vim.log.levels.ERROR)
      return
    end
    file:write(text)
    file:close()
    -- Run Prettier on the temporary file to format it
    -- Adding > /dev/null 2>&1' because if the command produces output, I see that
    -- in the neovim buffer
    local cmd = 'prettier --prose-wrap never --write "' .. temp_file .. '" > /dev/null 2>&1'
    local result = os.execute(cmd)
    if result ~= 0 then
      vim.notify("Error: Prettier formatting failed.", vim.log.levels.ERROR)
      os.remove(temp_file)
      return
    end
    -- Read the formatted text from the temporary file
    file = io.open(temp_file, "r")
    if file == nil then
      vim.notify("Error: Cannot read from temporary file.", vim.log.levels.ERROR)
      os.remove(temp_file)
      return
    end
    local formatted_text = file:read("*all")
    file:close()
    -- Copy the formatted text to the system clipboard
    vim.fn.setreg("+", formatted_text)
    -- Delete the temporary file
    os.remove(temp_file)
    -- Notify the user
    vim.notify("yanked markdown with --prose-wrap never", vim.log.levels.INFO)
  end, { desc = "[P]Copy selection formatted with Prettier", noremap = true, silent = true })
end

-------------------------------------------------------------------------------
--                           Folding section
-------------------------------------------------------------------------------

-- Checks each line to see if it matches a markdown heading (#, ##, etc.):
-- It’s called implicitly by Neovim’s folding engine by vim.opt_local.foldexpr
function _G.markdown_foldexpr()
  local lnum = vim.v.lnum
  local line = vim.fn.getline(lnum)
  local heading = line:match("^(#+)%s")
  if heading then
    local level = #heading
    if level == 1 then
      -- Special handling for H1
      if lnum == 1 then
        return ">1"
      else
        local frontmatter_end = vim.b.frontmatter_end
        if frontmatter_end and (lnum == frontmatter_end + 1) then
          return ">1"
        end
      end
    elseif level >= 2 and level <= 6 then
      -- Regular handling for H2-H6
      return ">" .. level
    end
  end
  return "="
end

function _G.typst_foldexpr()
  local lnum = vim.v.lnum
  local line = vim.fn.getline(lnum)
  local heading = line:match("^(=+)%s")
  if heading then
    local level = #heading
    if level >= 1 and level <= 6 then
      return ">" .. level
    end
  end
  return "="
end

local function set_markdown_folding()
  vim.opt_local.foldmethod = "expr"
  vim.opt_local.foldexpr = "v:lua.markdown_foldexpr()"
  vim.opt_local.foldlevel = 99

  -- Detect frontmatter closing line
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local found_first = false
  local frontmatter_end = nil
  for i, line in ipairs(lines) do
    if line == "---" then
      if not found_first then
        found_first = true
      else
        frontmatter_end = i
        break
      end
    end
  end
  vim.b.frontmatter_end = frontmatter_end
end

local function set_typst_folding()
  vim.opt_local.foldmethod = "expr"
  vim.opt_local.foldexpr = "v:lua.typst_foldexpr()"
  vim.opt_local.foldlevel = 99
end

-- Use autocommand to apply only to markdown files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = set_markdown_folding,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "typst",
  callback = set_typst_folding,
})

-- Function to fold all headings of a specific level
local function fold_headings_of_level(level)
  -- Move to the top of the file without adding to jumplist
  vim.cmd("keepjumps normal! gg")
  -- Get the total number of lines
  local total_lines = vim.fn.line("$")
  for line = 1, total_lines do
    -- Get the content of the current line
    local line_content = vim.fn.getline(line)
    if vim.bo.filetype == "typst" then
      if line_content:match("^" .. string.rep("=", level) .. "%s") then
        -- Move the cursor to the current line without adding to jumplist
        vim.cmd(string.format("keepjumps call cursor(%d, 1)", line))
        -- Check if the current line has a fold level > 0
        local current_foldlevel = vim.fn.foldlevel(line)
        if current_foldlevel > 0 then
          -- Fold the heading if it matches the level
          if vim.fn.foldclosed(line) == -1 then
            vim.cmd("normal! za")
          end
          -- else
          --   vim.notify("No fold at line " .. line, vim.log.levels.WARN)
        end
      end
    else
      -- "^" -> Ensures the match is at the start of the line
      -- string.rep("#", level) -> Creates a string with 'level' number of "#" characters
      -- "%s" -> Matches any whitespace character after the "#" characters
      -- So this will match `## `, `### `, `#### ` for example, which are markdown headings
      if line_content:match("^" .. string.rep("#", level) .. "%s") then
        -- Move the cursor to the current line without adding to jumplist
        vim.cmd(string.format("keepjumps call cursor(%d, 1)", line))
        -- Check if the current line has a fold level > 0
        local current_foldlevel = vim.fn.foldlevel(line)
        if current_foldlevel > 0 then
          -- Fold the heading if it matches the level
          if vim.fn.foldclosed(line) == -1 then
            vim.cmd("normal! za")
          end
          -- else
          --   vim.notify("No fold at line " .. line, vim.log.levels.WARN)
        end
      end
    end
  end
end

local function fold_markdown_headings(levels)
  -- I save the view to know where to jump back after folding
  local saved_view = vim.fn.winsaveview()
  for _, level in ipairs(levels) do
    fold_headings_of_level(level)
  end
  vim.cmd("nohlsearch")
  -- Restore the view to jump to where I was
  vim.fn.winrestview(saved_view)
end

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- Keymap for folding markdown headings of level 1 or above
vim.keymap.set("n", "zj", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mfj", function()
  -- Reloads the file to refresh folds, otheriise you have to re-open neovim
  vim.cmd("edit!")
  -- Unfold everything first or I had issues
  vim.cmd("normal! zR")
  fold_markdown_headings({ 6, 5, 4, 3, 2, 1 })
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 1 or above" })

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- Keymap for folding markdown headings of level 2 or above
-- I know, it reads like "madafaka" but "k" for me means "2"
vim.keymap.set("n", "zk", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mfk", function()
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  -- Unfold everything first or I had issues
  vim.cmd("normal! zR")
  fold_markdown_headings({ 6, 5, 4, 3, 2 })
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 2 or above" })

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- Keymap for folding markdown headings of level 3 or above
vim.keymap.set("n", "zl", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mfl", function()
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  -- Unfold everything first or I had issues
  vim.cmd("normal! zR")
  fold_markdown_headings({ 6, 5, 4, 3 })
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 3 or above" })

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- Keymap for folding markdown headings of level 4 or above
vim.keymap.set("n", "z;", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mf;", function()
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  -- Unfold everything first or I had issues
  vim.cmd("normal! zR")
  fold_markdown_headings({ 6, 5, 4 })
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 4 or above" })

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- Use <CR> to fold when in normal mode
-- To see help about folds use `:help fold`
vim.keymap.set("n", "<CR>", function()
  -- Get the current line number
  local line = vim.fn.line(".")
  -- Get the fold level of the current line
  local foldlevel = vim.fn.foldlevel(line)
  if foldlevel == 0 then
    vim.notify("No fold found", vim.log.levels.INFO)
  else
    vim.cmd("normal! za")
    vim.cmd("normal! zz") -- center the cursor line on screen
  end
end, { desc = "[P]Toggle fold" })

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- Keymap for unfolding markdown headings of level 2 or above
-- Changed all the markdown folding and unfolding keymaps from <leader>mfj to
-- zj, zk, zl, z; and zu respectively lamw25wmal
vim.keymap.set("n", "zu", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mfu", function()
  -- Reloads the file to reflect the changes
  vim.cmd("edit!")
  vim.cmd("normal! zR") -- Unfold all headings
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Unfold all headings level 2 or above" })

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- gk jummps to the markdown heading above and then folds it
-- zi by default toggles folding, but I don't need it lamw25wmal
vim.keymap.set("n", "zi", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- Difference between normal and normal!
  -- - `normal` executes the command and respects any mappings that might be defined.
  -- - `normal!` executes the command in a "raw" mode, ignoring any mappings.
  vim.cmd("normal gk")
  -- This is to fold the line under the cursor
  vim.cmd("normal! za")
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold the heading cursor currently on" })

-- Creates a markdown heading based on the level specified
local function insert_heading_and_date(level)
  local heading = string.rep("#", level) .. " " -- Generate heading based on the level
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0)) -- Get the current row number
  -- Insert heading
  vim.api.nvim_buf_set_lines(0, row, row, false, { heading })
  -- Move the cursor to the end of the heading and enter insert mode
  vim.api.nvim_win_set_cursor(0, { row + 1, #heading })
  vim.cmd("startinsert!")
end

-- These create the the markdown heading
-- H1
vim.keymap.set("n", "<leader>jj", function()
  local date_line = insert_heading_and_date(1)
end, { desc = "[P]H1 heading and date" })

-- H2
vim.keymap.set("n", "<leader>kk", function()
  local date_line = insert_heading_and_date(2)
end, { desc = "[P]H2 heading and date" })

-- H3
vim.keymap.set("n", "<leader>ll", function()
  local date_line = insert_heading_and_date(3)
end, { desc = "[P]H3 heading and date" })

-- H4
vim.keymap.set("n", "<leader>;;", function()
  local date_line = insert_heading_and_date(4)
end, { desc = "[P]H4 heading and date" })

-- H5
vim.keymap.set("n", "<leader>uu", function()
  local date_line = insert_heading_and_date(5)
end, { desc = "[P]H5 heading and date" })

-- H6
vim.keymap.set("n", "<leader>ii", function()
  local date_line = insert_heading_and_date(6)
end, { desc = "[P]H6 heading and date" })

-------------------------------------------------------------------------------
--                         End Folding section
-------------------------------------------------------------------------------

-- Jump between md headings
vim.keymap.set({ "n", "v" }, "gk", function()
  -- `?` - Start a search backwards from the current cursor position.
  -- `^` - Match the beginning of a line.
  -- `##` - Match 2 ## symbols
  -- `\\+` - Match one or more occurrences of prev element (#)
  -- `\\s` - Match exactly one whitespace character following the hashes
  -- `.*` - Match any characters (except newline) following the space
  -- vim.cmd("silent! ?^##\\+\\s.*$")
  local ft = vim.bo.filetype
  if ft == "typst" then
    vim.cmd("silent! ?^==\\+\\s.*$")
    -- Clear the search highlight
    vim.cmd("nohlsearch")
    return
  end -- `$` - Match extends to end of line
  vim.cmd("silent! ?^##\\+\\s.*$")
  -- Clear the search highlight
  vim.cmd("nohlsearch")
end, { desc = "[P]Go to previous markdown header" })

vim.keymap.set({ "n", "v" }, "gj", function()
  -- `/` - Start a search forwards from the current cursor position.
  -- `^` - Match the beginning of a line.
  -- `##` - Match 2 ## symbols
  -- `\\+` - Match one or more occurrences of prev element (#)
  -- `\\s` - Match exactly one whitespace character following the hashes
  -- `.*` - Match any characters (except newline) following the space
  -- `$` - Match extends to end of line
  local ft = vim.bo.filetype
  if ft == "typst" then
    vim.cmd("silent! /^==\\+\\s.*$")
    -- Clear the search highlight
    vim.cmd("nohlsearch")
    return
  end
  vim.cmd("silent! /^##\\+\\s.*$")
  -- Clear the search highlight
  vim.cmd("nohlsearch")
end, { desc = "[P]Go to next markdown header" })

-- Copy workout data from last markdown table to clipboard lamw25wmal
vim.keymap.set("n", "<leader>lc", function()
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
end, { desc = "[P]Log Copy: workout table to clipboard" })

-- Paste entire file contents into daily note lamw25wmal
vim.keymap.set("n", "<leader>lp", function()
  -- ===================== Customizable variables =====================
  -- NOTE: Path to the daily note creation script
  local daily_note_script = vim.fn.expand("~/dotfiles/tmux/tools/prime/daily-notes.sh")
  -- NOTE: Path to the daily note (adjust the pattern to match your structure)
  local daily_note_path = vim.fn.expand("~/obsidian/periodic/") .. os.date("%Y/%m-%b/%Y-%m-%d-%A") .. ".md"
  -- NOTE: Heading before which to insert content
  local tasks_heading = "## Completed Tasks"

  --------------------------------------------------------------------------
  -- Extract H1 from the current file
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

  local training_heading = "## Training Log of the " .. h1_text

  -- All file contents without the H1 line (skip first 2 lines: H1 + blank)
  local buf_lines = vim.api.nvim_buf_get_lines(0, 2, -1, false)

  --------------------------------------------------------------------------
  -- 1. If daily note does not exist, create it via script
  --------------------------------------------------------------------------
  if vim.fn.filereadable(daily_note_path) ~= 1 then
    vim.fn.system(daily_note_script)
    if vim.fn.filereadable(daily_note_path) ~= 1 then
      vim.notify("daily-note.sh failed to create file: " .. daily_note_path, vim.log.levels.ERROR)
      return
    end
  end

  --------------------------------------------------------------------------
  -- Read the daily note contents
  --------------------------------------------------------------------------
  local daily_lines = vim.fn.readfile(daily_note_path)

  --------------------------------------------------------------------------
  -- Look for the "## Completed Tasks" heading
  --------------------------------------------------------------------------
  local heading_index = nil
  for i, line in ipairs(daily_lines) do
    if line:match("^" .. tasks_heading .. "%s*$") then
      heading_index = i
      break
    end
  end

  --------------------------------------------------------------------------
  -- Build the insert block: heading + blank line + file contents
  --------------------------------------------------------------------------
  local insert_block = {}
  table.insert(insert_block, training_heading)
  table.insert(insert_block, "")
  for _, line in ipairs(buf_lines) do
    table.insert(insert_block, line)
  end

  local result = {}

  if heading_index then
    --------------------------------------------------------------------------
    -- 2. Heading found: insert BEFORE it
    --------------------------------------------------------------------------
    for i = 1, heading_index - 1 do
      table.insert(result, daily_lines[i])
    end
    -- Remove trailing blank lines before the insert block
    while #result > 0 and result[#result] == "" do
      table.remove(result)
    end
    table.insert(result, "")
    -- Insert the block
    for _, line in ipairs(insert_block) do
      table.insert(result, line)
    end
    table.insert(result, "")
    -- Append daily note from the heading onwards
    for i = heading_index, #daily_lines do
      table.insert(result, daily_lines[i])
    end
  else
    --------------------------------------------------------------------------
    -- 3. Heading not found: insert at the end
    --------------------------------------------------------------------------
    result = vim.list_extend({}, daily_lines)
    -- Remove trailing blank lines before the insert block
    while #result > 0 and result[#result] == "" do
      table.remove(result)
    end
    table.insert(result, "")
    -- Insert the block
    for _, line in ipairs(insert_block) do
      table.insert(result, line)
    end
  end

  --------------------------------------------------------------------------
  -- Write the result back to the daily note
  --------------------------------------------------------------------------
  vim.fn.writefile(result, daily_note_path)
  vim.notify("Inserted into daily note: " .. daily_note_path, vim.log.levels.INFO)
end, { desc = "[P]Log Paste: file contents into daily note" })

-- Auto push Obsidian Vault
local function push_obsidian_vault(silent)
  local vault_path = vim.fn.expand("~/obsidian")
  local current_dir = vim.fn.getcwd()

  if current_dir:find(vault_path, 1, true) == nil then
    return false
  end

  vim.cmd("silent! wa")

  local commit_msg = "Vault backup: " .. os.date("%Y-%m-%d %H:%M:%S")
  local cmd = string.format("cd %s && git add . && git commit -m '%s' && git push", vault_path, commit_msg)

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
local PUSH_COOLDOWN = 1800

local function push_with_cooldown()
  local now = os.time()
  if now - last_push_time < PUSH_COOLDOWN then
    return
  end
  if push_obsidian_vault(true) then
    last_push_time = now
  end
end

-- Автопуш при разных событиях
vim.api.nvim_create_autocmd({
  "FocusLost", -- переключился на другое окно
  "QuitPre", -- перед выходом из Neovim
  "VimSuspend", -- Ctrl+Z (suspend)
  "VimLeavePre", -- перед закрытием Neovim
}, {
  desc = "Autopush Obsidian Vault",
  callback = push_with_cooldown,
})

-- Ручной кеймап
vim.keymap.set("n", "<leader>go", function()
  vim.cmd("silent! wa")
  if not push_obsidian_vault(false) then
    print("Not in Obsidian Vault")
  end
end, { desc = "[P]Autopush Obsidian Vault" })

-- Grug
vim.keymap.set(
  { "v", "n" },
  "<leader>s1",
  '<cmd>lua require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })<cr>',
  { noremap = true, silent = true, desc = "grug-far: Search in current file" }
)

vim.keymap.set({ "n", "x" }, "<leader>sv", function()
  require("grug-far").open({ visualSelectionUsage = "operate-within-range" })
end, { desc = "grug-far: Search within range" })

-- Code Runner
vim.keymap.set("n", "<leader>rr", function()
  vim.cmd("w")
  local file = vim.fn.expand("%:t")
  local out = vim.fn.expand("%:t:r")
  local dir = vim.fn.expand("%:p:h")
  local ext = vim.fn.expand("%:e")

  local cmd

  if ext == "cpp" or ext == "cc" or ext == "cxx" then
    cmd = string.format("cd '%s' && g++ -std=c++17 -O2 -Wall -o '%s' '%s' && ./'%s'", dir, out, file, out)
  elseif ext == "c" then
    cmd = string.format("cd '%s' && gcc -O2 -Wall -o '%s' '%s' && ./'%s'", dir, out, file, out)
  elseif ext == "py" then
    cmd = string.format("cd '%s' && python3 '%s'", dir, file)
  else
    vim.notify("Нет команды для ." .. ext, vim.log.levels.WARN)
    return
  end

  vim.cmd("split | terminal " .. cmd)
  vim.cmd("startinsert")
end, { desc = "Run Code" })

-- Normal Mode in Terminal
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Normal mode" })

-- Quit with "q"
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    local opts = { buffer = true, silent = true }
    vim.keymap.set("n", "q", "<cmd>bd!<CR>", opts)
  end,
})

-- If there is no `untoggled` or `done` label on an item, mark it as done
-- and move it to the "## completed tasks" markdown heading in the same file, if
-- the heading does not exist, it will be created, if it exists, items will be
-- appended to it at the top lamw25wmal
--
-- If an item is moved to that heading, it will be added the `done` label
vim.keymap.set("n", "<M-x>", function()
  -- Customizable variables
  -- NOTE: Customize the completion label
  local label_done = "done:"
  -- NOTE: Customize the timestamp format
  local timestamp = os.date("%Y-%m-%d-%H:%M")
  -- local timestamp = os.date("%y%m%d")
  -- NOTE: Customize the heading and its level
  local tasks_heading = "## Completed Tasks"
  -- Save the view to preserve folds
  vim.cmd("mkview")
  local api = vim.api
  -- Retrieve buffer & lines
  local buf = api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local start_line = cursor_pos[1] - 1
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local total_lines = #lines
  -- If cursor is beyond last line, do nothing
  if start_line >= total_lines then
    vim.cmd("loadview")
    return
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
    vim.cmd("loadview")
    return
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
    local win = api.nvim_get_current_win()
    local view = api.nvim_win_call(win, function()
      return vim.fn.winsaveview()
    end)
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
      -- Remove any blank line right after newly inserted chunk
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
    -- Update buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.notify("Completed", vim.log.levels.INFO)
    -- Restore window view to preserve scroll position
    api.nvim_win_call(win, function()
      vim.fn.winrestview(view)
    end)
  end
  -- Write changes and restore view to preserve folds
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  vim.cmd("loadview")
end, { desc = "[P]Toggle task and move it to 'done'" })

-- Create task
vim.keymap.set({ "n", "i" }, "<M-l>", function()
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
  -- 2) Check if line already has a bullet with possible indentation: e.g. "  - Something"
  --    We'll capture "  -" (including trailing spaces) as `bullet` plus the rest as `text`.
  local bullet, text = line:match("^([%s]*[-*]%s+)(.*)$")
  if bullet then
    -- Convert bullet => bullet .. "[ ] " .. text
    local final_line = bullet .. "[ ] " .. text
    vim.api.nvim_set_current_line(final_line)
    -- Place the cursor right after "[ ] "
    -- bullet length + "[ ] " is bullet_len + 4 characters,
    -- but bullet has trailing spaces, so #bullet includes those.
    local bullet_len = #bullet
    -- We want to land after the brackets (four characters: `[ ] `),
    -- so col = bullet_len + 4 (0-based).
    vim.api.nvim_win_set_cursor(0, { row, bullet_len + 4 })
    return
  end
  -- 3) If there's text, but no bullet => prepend "- [ ] "
  --    and place cursor after the brackets
  local final_line = "- [ ] " .. line
  vim.api.nvim_set_current_line(final_line)
  -- "- [ ] " is 6 characters
  vim.api.nvim_win_set_cursor(0, { row, 6 })
end, { desc = "Convert bullet to a task or insert new task bullet" })
