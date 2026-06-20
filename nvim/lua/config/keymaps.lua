local folding = require("utils.folding")
local tasks = require("utils.tasks")
local gcal = require("utils.gcal")
local obsidian = require("utils.obsidian")

vim.keymap.set("x", "p", '"_dP') -- Don't copy visual in clipboard

-- Toggle a kitty window (zsh) on the right with the current file's directory
vim.keymap.set({ "n", "v", "i" }, "<M-t>", function()
  require("utils.kitty").open()
end, { desc = "[P]Terminal on kitty window" })

-- Copy to clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y')
vim.keymap.set("n", "<leader>Y", '"+Y')

-- Paste from clipboard
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p')
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P')

-- Delete to black hole
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d')

-- Fix last spelling mistake without leaving insert mode
vim.keymap.set("i", "<C-l>", "<c-g>u<Esc>[s1z=`]a<c-g>u", { silent = true })

-- Auto-yank visual selection to the system clipboard on mouse release
-- NOTE: This requires Neovim to receive mouse events (so `mouse` must include visual mode)
-- NOTE: LazyVim already enables `opt.mouse = "a"` (mouse mode), so we don't set it here
-- https://stackoverflow.com/questions/79585797/how-to-copy-on-mouse-selection-in-neovim
vim.keymap.set("v", "<LeftRelease>", [["+ygv]], { silent = true, desc = "[P]Mouse select -> yank to system clipboard" })
vim.keymap.set(
  "v",
  "<2-LeftRelease>",
  [["+ygv]],
  { silent = true, desc = "[P]Mouse select (double) -> yank to system clipboard" }
)

if vim.env.KITTY_SIMPLE_SCROLLBACK == "1" then
  vim.keymap.set("v", "y", [["+y<cmd>q!<cr>]], { desc = "[P]Yank to system clipboard + quit" })
else
  -- Yank to system clipboard; in markdown run the selection through Prettier
  -- (--prose-wrap never) first so wrapped lines are unwrapped on paste
  vim.keymap.set("v", "y", function()
    if vim.bo.filetype ~= "markdown" then
      vim.cmd('normal! "+y')
      vim.notify("Yanked to system clipboard", vim.log.levels.INFO)
      return
    end
    -- Yank the selected text into register 'z' without affecting the unnamed register
    vim.cmd('silent! normal! "zy')
    local text = vim.fn.getreg("z")
    local temp_file = vim.fn.tempname() .. ".md"
    local file = io.open(temp_file, "w")
    if file == nil then
      vim.notify("Error: Cannot write to temporary file.", vim.log.levels.ERROR)
      return
    end
    file:write(text)
    file:close()
    -- Redirect prettier's output, otherwise it shows up in the buffer
    local cmd = 'prettier --prose-wrap never --write "' .. temp_file .. '" > /dev/null 2>&1'
    local result = os.execute(cmd)
    if result ~= 0 then
      vim.notify("Error: Prettier formatting failed.", vim.log.levels.ERROR)
      os.remove(temp_file)
      return
    end
    file = io.open(temp_file, "r")
    if file == nil then
      vim.notify("Error: Cannot read from temporary file.", vim.log.levels.ERROR)
      os.remove(temp_file)
      return
    end
    local formatted_text = file:read("*all")
    file:close()
    vim.fn.setreg("+", formatted_text)
    os.remove(temp_file)
    vim.notify("yanked markdown with --prose-wrap never", vim.log.levels.INFO)
  end, { desc = "[P]Copy selection formatted with Prettier", noremap = true, silent = true })
end

local wk = require("which-key")
wk.add({
  {
    mode = { "n" },
    { "<leader>t", group = "[P]Todo" },
    { "<leader>l", group = "[P]Log" },
    { "<leader>gc", group = "[P]gcalcli" },
  },
})

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

-------------------------------------------------------------------------------
--                           Folding section
-------------------------------------------------------------------------------
-- Implementation lives in lua/utils/folding.lua

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = folding.set_markdown_folding,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "typst",
  callback = folding.set_typst_folding,
})

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- zj folds headings level 1+, zk level 2+ (I know, it reads like "madafaka"
-- but "k" for me means "2"), zl level 3+, z; level 4+ lamw25wmal
for key, level in pairs({ j = 1, k = 2, l = 3, [";"] = 4 }) do
  vim.keymap.set("n", "z" .. key, function()
    -- "Update" saves only if the buffer has been modified since the last save
    vim.cmd("silent update")
    -- Reloads the file to refresh folds, otherwise you have to re-open neovim
    vim.cmd("edit!")
    -- Unfold everything first or I had issues
    vim.cmd("normal! zR")
    local levels = {}
    for l = 6, level, -1 do
      table.insert(levels, l)
    end
    folding.fold_headings(levels)
    vim.cmd("normal! zz") -- center the cursor line on screen
  end, { desc = "[P]Fold all headings level " .. level .. " or above" })
end

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

-- Keymap for unfolding all headings
vim.keymap.set("n", "zu", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- Reloads the file to reflect the changes
  vim.cmd("edit!")
  vim.cmd("normal! zR") -- Unfold all headings
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Unfold all headings level 2 or above" })

-- gk jumps to the markdown heading above and then folds it
-- zi by default toggles folding, but I don't need it lamw25wmal
vim.keymap.set("n", "zi", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- `normal` (not `normal!`) so the gk mapping below is respected
  vim.cmd("normal gk")
  -- This is to fold the line under the cursor
  vim.cmd("normal! za")
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold the heading cursor currently on" })

-- Creates a markdown heading based on the level specified
local function insert_heading(level)
  local heading = string.rep("#", level) .. " " -- Generate heading based on the level
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0)) -- Get the current row number
  -- Insert heading
  vim.api.nvim_buf_set_lines(0, row, row, false, { heading })
  -- Move the cursor to the end of the heading and enter insert mode
  vim.api.nvim_win_set_cursor(0, { row + 1, #heading })
  vim.cmd("startinsert!")
end

-- <leader>jj..ii create markdown headings H1..H6
for key, level in pairs({ jj = 1, kk = 2, ll = 3, [";;"] = 4, uu = 5, ii = 6 }) do
  vim.keymap.set("n", "<leader>" .. key, function()
    insert_heading(level)
  end, { desc = "[P]H" .. level .. " heading and date" })
end

-------------------------------------------------------------------------------
--                         End Folding section
-------------------------------------------------------------------------------

-- Jump between md/typst headings: searches for lines starting with `##`
-- (or `==` in typst) without polluting the search highlight
vim.keymap.set({ "n", "v" }, "gk", function()
  local pattern = vim.bo.filetype == "typst" and "?^==\\+\\s.*$" or "?^##\\+\\s.*$"
  vim.cmd("silent! " .. pattern)
  vim.cmd("nohlsearch")
end, { desc = "[P]Go to previous markdown header" })

vim.keymap.set({ "n", "v" }, "gj", function()
  local pattern = vim.bo.filetype == "typst" and "/^==\\+\\s.*$" or "/^##\\+\\s.*$"
  vim.cmd("silent! " .. pattern)
  vim.cmd("nohlsearch")
end, { desc = "[P]Go to next markdown header" })

-- Workout log helpers (lua/utils/obsidian.lua)
vim.keymap.set("n", "<leader>lc", obsidian.copy_workout_table, { desc = "[P]Log Copy: workout table to clipboard" })
vim.keymap.set("n", "<leader>lp", obsidian.save_training_note, { desc = "[P]Log Paste: save training note" })

-- Автопуш Obsidian Vault при разных событиях
vim.api.nvim_create_autocmd({
  "FocusLost", -- переключился на другое окно
  "QuitPre", -- перед выходом из Neovim
  "VimSuspend", -- Ctrl+Z (suspend)
  "VimLeavePre", -- перед закрытием Neovim
}, {
  desc = "Autopush Obsidian Vault",
  callback = obsidian.push_with_cooldown,
})

-- Ручной кеймап
vim.keymap.set("n", "<leader>go", function()
  if not obsidian.push(false) then
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

-- Toggle task done/undone and move it under "## Completed Tasks"
-- (lua/utils/tasks.lua)
vim.keymap.set("n", "<M-x>", tasks.toggle_done, { desc = "[P]Toggle task and move it to 'done'" })

-- Create task (markdown only, checked inside the function)
vim.keymap.set({ "n", "i" }, "<M-l>", function()
  if vim.bo.filetype ~= "markdown" then
    return
  end
  tasks.create()
end, { desc = "Convert bullet to a task or insert new task bullet" })

-- Google Calendar (lua/utils/gcal.lua)
vim.keymap.set("n", "<leader>gcc", gcal.create_from_line, { desc = "[P]gcalcli: create event from line" })
vim.keymap.set("n", "<leader>gca", gcal.agenda, { desc = "[P]gcalcli: show agenda" })
