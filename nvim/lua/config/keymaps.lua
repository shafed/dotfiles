-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "kj", "<ESC>", { desc = "[P]Exit insert mode with kj" })

vim.keymap.set({ "n", "v" }, "H", "^", { desc = "[P]Go to the beginning line" })
vim.keymap.set({ "n", "v" }, "L", "$", { desc = "[P]go to the end of the line" })

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "[P]Yank to system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]], { desc = "[P]Paste from system clipboard" })

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

-- Copy workout data from last markdown table
vim.keymap.set("n", "<leader>cw", function()
  -- Get all lines from current buffer
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Find all tables in the buffer
  local tables = {}
  local current_table = {}
  local in_table = false

  -- Iterate through lines and collect table rows
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

  -- Add last table if buffer ends with a table
  if #current_table > 0 then
    table.insert(tables, current_table)
  end

  -- Check if any tables were found
  if #tables == 0 then
    vim.notify("Таблицы не найдены!", vim.log.levels.WARN)
    return
  end

  -- Get the last table from the buffer
  local last_table = tables[#tables]

  local exercises = {}
  local data = {}

  -- Parse table rows (skip header and separator, start from row 3)
  for i = 3, #last_table do
    local line = last_table[i]
    local cells = {}

    -- Split line by pipe character and trim whitespace
    for cell in line:gmatch("[^|]+") do
      table.insert(cells, vim.trim(cell))
    end

    -- Extract data: cells[1] = №, cells[2] = Exercise, cells[3] = Reps, cells[4] = Weight
    if #cells >= 4 then
      local exercise = cells[2]
      local reps = cells[3]
      local weight = cells[4]

      -- Process reps: extract part after X if there's a hyphen (e.g., "3X8-10" -> "8-10")
      local processed_reps = reps
      local match = reps:match("^%d+X([%d%-,]+)$")
      if match and match:find("-") then
        processed_reps = match
      end

      table.insert(exercises, exercise)
      table.insert(data, { processed_reps, weight, "kg" })
    end
  end

  if #exercises > 0 then
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
      table.insert(line3_parts, d[1]) -- reps
      table.insert(line3_parts, d[2]) -- weight
      table.insert(line3_parts, d[3]) -- kg
    end

    -- Join parts with tabs and combine into final output
    local line1 = table.concat(line1_parts, "\t")
    local line2 = table.concat(line2_parts, "\t")
    local line3 = table.concat(line3_parts, "\t")
    local output = line1 .. "\n" .. line2 .. "\n" .. line3

    -- Copy to system clipboard
    vim.fn.setreg("+", output)
    vim.notify("Скопировано: " .. #exercises .. " упражнений", vim.log.levels.INFO)
  else
    vim.notify("Нет данных для копирования!", vim.log.levels.WARN)
  end
end, { desc = "[P]Copy workout table data" })

vim.keymap.set("n", "<leader>go", function()
  -- Save files
  vim.cmd("wa")

  -- Check if in Obsidian Repo
  local vault_path = vim.fn.expand("~/obsidian")
  local current_dir = vim.fn.getcwd()

  if current_dir:find(vault_path, 1, true) == nil then
    print("Not in Obsidian Vault")
    return
  end

  -- Git commands
  local commit_msg = "Vault backup: " .. os.date("%Y-%m-%d %H:%M:%S")
  local cmd = string.format("cd %s && git add . && git commit -m '%s' && git push", vault_path, commit_msg)

  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 then
        print("Obsidian Vault pushed successfully")
      else
        print("Error push")
      end
    end,
  })
end, { desc = "[P]Autopush Obsidian Repo" })
