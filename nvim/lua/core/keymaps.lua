local map = vim.keymap.set

-- Буферы
map('n', 'gn', ':bnext<CR>', { desc = "Next buffer" })
map('n', 'gp', ':bprevious<CR>', { desc = "Previous buffer" })
map('n', 'gw', ':bdelete<CR>', { desc = "Close buffer" })

-- Системный буфер обмена
map({'n','v'}, '<leader>y', '"+y', { desc = "Copy to system clipboard" })
map('n', '<leader>Y', '"+Y', { desc = "Copy line to system clipboard" })
map({'n','v'}, '<leader>p', '"+p', { desc = "Paste from system clipboard" })
map({'n','v'}, '<leader>P', '"+P', { desc = "Paste before from system clipboard" })
map({'n','v'}, '<M-p>', '"0p', { desc = "Paste from copy register" })
map({'n','v'}, '<M-P>', '"0P', { desc = "Paste before copy register" })

map({'n','v','o'}, 'H', '^', { desc = "First non-blank" })
map({'n','v','o'}, 'L', '$', { desc = "End of line" })

-- Дубли на русской раскладке
map({'n','v'}, '<leader>н', '"+y', { desc = "Copy to system clipboard" })
map('n', '<leader>Н', '"+Y', { desc = "Copy line to system clipboard" })
map({'n','v'}, '<leader>з', '"+p', { desc = "Paste from system clipboard" })
map({'n','v'}, '<leader>З', '"+P', { desc = "Paste before from system clipboard" })

map({'n','v','o'}, 'Р', '^', { desc = "First non-blank" })
map({'n','v','o'}, 'Д', '$', { desc = "End of line" })

-- Поиск
map('n', '<leader><space>', ':nohlsearch<CR>', { desc = "Clear search highlight" })

-- Запуск .py и .cpp файлов
local function run_file()
  local filetype = vim.bo.filetype
  local filename = vim.fn.expand('%')
  
  vim.cmd('w')
  
  if filetype == 'python' then
    vim.cmd('!python3 ' .. filename)
  elseif filetype == 'cpp' then
    local output_name = vim.fn.expand('%:r')
    -- Компилируем молча, показываем только вывод программы
    local compile_cmd = 'g++ -std=c++17 -Wall -Wextra -O2 ' .. filename .. ' -o ' .. output_name
    local result = vim.fn.system(compile_cmd)
    
    if vim.v.shell_error == 0 then
      -- Если компиляция успешна, запускаем программу
      vim.cmd('!./' .. output_name)
    else
      -- Если есть ошибки компиляции, показываем их
      print("Compilation failed:")
      print(result)
    end
  else
    print("Unsupported file type: " .. filetype)
  end
end

-- Запуск .py и .cpp файлов
local function run_file_in_terminal()
  local filetype = vim.bo.filetype
  local filename = vim.fn.expand('%')
  
  vim.cmd('w')
  
  if filetype == 'python' then
    vim.cmd('split | terminal python3 ' .. filename)
  elseif filetype == 'cpp' then
    local output_name = vim.fn.expand('%:r')
    local compile_cmd = 'g++ -std=c++17 -Wall -Wextra -O2 ' .. filename .. ' -o ' .. output_name
    
    -- Компилируем в фоне
    local result = vim.fn.system(compile_cmd)
    
    if vim.v.shell_error == 0 then
      -- Открываем терминал и запускаем программу
      vim.cmd('split | terminal ./' .. output_name)
    else
      -- Показываем ошибки компиляции
      vim.cmd('new')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(result, '\n'))
      vim.bo.buftype = 'nofile'
      vim.bo.bufhidden = 'wipe'
      vim.bo.filetype = 'cpp'
    end
  else
    print("Unsupported file type: " .. filetype)
  end
  
  -- Автоматически переходим в insert mode в терминале
  vim.cmd('startinsert')
end

-- Маппинги для обычного запуска
vim.keymap.set('n', '<C-h>', run_file, { desc = "Run current file (Python/C++)" })
vim.keymap.set('i', '<C-h>', function()
  vim.cmd('stopinsert')
  run_file()
end, { desc = "Run current file (Python/C++)" })

-- Маппинги для запуска в терминале
vim.keymap.set('n', '<C-t>', run_file_in_terminal, { desc = "Run file in terminal (Python/C++)" })
vim.keymap.set('i', '<C-t>', function()
  vim.cmd('stopinsert')
  run_file_in_terminal()
end, { desc = "Run file in terminal (Python/C++)" })
-- ====

-- Перемещение строк
map('n', '<M-j>', ':m .+1<CR>==', { desc = "Move line down" })
map('n', '<M-k>', ':m .-2<CR>==', { desc = "Move line up" })
map('i', '<M-j>', '<Esc>:m .+1<CR>==gi', { desc = "Move line down" })
map('i', '<M-k>', '<Esc>:m .-2<CR>==gi', { desc = "Move line up" })
map('v', '<M-j>', ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map('v', '<M-k>', ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Create todo list
vim.keymap.set({ "n", "i" }, "<M-d>", function()
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


-- Toggletodo
vim.keymap.set("n", "<leader>d", function()
  local function bulletToX(line)
    return line:gsub("^(%s*%- )%[%s*%]", "%1[x]")
  end
  
  local function bulletToBlank(line)
    return line:gsub("^(%s*%- )%[x%]", "%1[ ]")
  end
  
  local function toggleTodo(line)
    if line:match("^%s*%- %[x%]") then
      return bulletToBlank(line)
    elseif line:match("^%s*%- %[%s*%]") then
      return bulletToX(line)
    end
    return line
  end
  
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  local newLine = toggleTodo(line)
  
  vim.api.nvim_set_current_line(newLine)
end, { desc = "Toggle todo checkbox" })
-- Для русской раскладки
vim.keymap.set("n", "<leader>в", "<leader>d", { remap = true, desc = "Toggle todo checkbox (RU layout)" })


-- Подключаем модуль
local copy_workout = require("core.copy_workout")

-- Создаем команду
vim.api.nvim_create_user_command('CopyWorkoutData', function()
  copy_workout.copy_table_data()
end, {})

-- Назначаем горячую клавишу (например, <leader>cw)
vim.keymap.set('n', '<leader>cw', ':CopyWorkoutData<CR>', { desc = 'Copy workout data from table' })

vim.keymap.set('v', 'p', '"_dP')  -- Не сохранять выделенный текст в регистр



-- =====
--  Функции для обрамления жирным шрифтом md (** **), автор @linkarzu
-- =====

vim.keymap.set("v", "<leader>mb", function()
  -- Get the selected text range
  local start_row, start_col = unpack(vim.fn.getpos("'<"), 2, 3)
  local end_row, end_col = unpack(vim.fn.getpos("'>"), 2, 3)
  -- Get the selected lines
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local selected_text = table.concat(lines, "\n"):sub(start_col, #lines == 1 and end_col or -1)
  if selected_text:match("^%*%*.*%*%*$") then
    vim.notify("Text already bold", vim.log.levels.INFO)
  else
    vim.cmd("normal 2gsa*")
  end
end, { desc = "[P]BOLD current selection" })

-- -- Multiline unbold attempt
-- -- In normal mode, bold the current word under the cursor
-- -- If already bold, it will unbold the word under the cursor
-- -- If you're in a multiline bold, it will unbold it only if you're on the
-- -- first line
vim.keymap.set("n", "<leader>mb", function()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_buffer = vim.api.nvim_get_current_buf()
  local start_row = cursor_pos[1] - 1
  local col = cursor_pos[2]
  -- Get the current line
  local line = vim.api.nvim_buf_get_lines(current_buffer, start_row, start_row + 1, false)[1]
  -- Check if the cursor is on an asterisk
  if line:sub(col + 1, col + 1):match("%*") then
    vim.notify("Cursor is on an asterisk, run inside the bold text", vim.log.levels.WARN)
    return
  end
  -- Search for '**' to the left of the cursor position
  local left_text = line:sub(1, col)
  local bold_start = left_text:reverse():find("%*%*")
  if bold_start then
    bold_start = col - bold_start
  end
  -- Search for '**' to the right of the cursor position and in following lines
  local right_text = line:sub(col + 1)
  local bold_end = right_text:find("%*%*")
  local end_row = start_row
  while not bold_end and end_row < vim.api.nvim_buf_line_count(current_buffer) - 1 do
    end_row = end_row + 1
    local next_line = vim.api.nvim_buf_get_lines(current_buffer, end_row, end_row + 1, false)[1]
    if next_line == "" then
      break
    end
    right_text = right_text .. "\n" .. next_line
    bold_end = right_text:find("%*%*")
  end
  if bold_end then
    bold_end = col + bold_end
  end
  -- Remove '**' markers if found, otherwise bold the word
  if bold_start and bold_end then
    -- Extract lines
    local text_lines = vim.api.nvim_buf_get_lines(current_buffer, start_row, end_row + 1, false)
    local text = table.concat(text_lines, "\n")
    -- Calculate positions to correctly remove '**'
    -- vim.notify("bold_start: " .. bold_start .. ", bold_end: " .. bold_end)
    local new_text = text:sub(1, bold_start - 1) .. text:sub(bold_start + 2, bold_end - 1) .. text:sub(bold_end + 2)
    local new_lines = vim.split(new_text, "\n")
    -- Set new lines in buffer
    vim.api.nvim_buf_set_lines(current_buffer, start_row, end_row + 1, false, new_lines)
    -- vim.notify("Unbolded text", vim.log.levels.INFO)
  else
    -- Bold the word at the cursor position if no bold markers are found
    local before = line:sub(1, col)
    local after = line:sub(col + 1)
    local inside_surround = before:match("%*%*[^%*]*$") and after:match("^[^%*]*%*%*")
    if inside_surround then
      vim.cmd("normal gsd*.")
    else
      vim.cmd("normal viw")
      vim.cmd("normal 2gsa*")
    end
    vim.notify("Bolded current word", vim.log.levels.INFO)
  end
end, { desc = "[P]BOLD toggle bold markers" })


-- =====
--  Функции для обрамления курсивом md (* *)
-- =====
vim.keymap.set("v", "<leader>mi", function()
  -- Get the selected text range
  local start_row, start_col = unpack(vim.fn.getpos("'<"), 2, 3)
  local end_row, end_col = unpack(vim.fn.getpos("'>"), 2, 3)
  -- Get the selected lines
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local selected_text = table.concat(lines, "\n"):sub(start_col, #lines == 1 and end_col or -1)
  -- Проверяем курсив (*text*) но не bold (**text**)
  if selected_text:match("^%*[^%*].*[^%*]%*$") or selected_text:match("^%*[^%*]%*$") then
    vim.notify("Text already italic", vim.log.levels.INFO)
  else
    vim.cmd("normal gsa*")
  end
end, { desc = "[P]ITALIC current selection" })

-- Normal mode - toggle italic for word under cursor
vim.keymap.set("n", "<leader>mi", function()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_buffer = vim.api.nvim_get_current_buf()
  local start_row = cursor_pos[1] - 1
  local col = cursor_pos[2]
  -- Get the current line
  local line = vim.api.nvim_buf_get_lines(current_buffer, start_row, start_row + 1, false)[1]
  -- Check if the cursor is on an asterisk
  if line:sub(col + 1, col + 1):match("%*") then
    vim.notify("Cursor is on an asterisk, run inside the italic text", vim.log.levels.WARN)
    return
  end

  -- Helper: find single * (not part of **)
  local function find_single_asterisk_left(text)
    for i = #text, 1, -1 do
      if text:sub(i, i) == "*" then
        local prev = text:sub(i - 1, i - 1)
        local next = text:sub(i + 1, i + 1)
        if prev ~= "*" and next ~= "*" then
          return #text - i + 1, i
        end
      end
    end
    return nil, nil
  end

  local function find_single_asterisk_right(text)
    local i = 1
    while i <= #text do
      if text:sub(i, i) == "*" then
        local prev = text:sub(i - 1, i - 1)
        local next = text:sub(i + 1, i + 1)
        if prev ~= "*" and next ~= "*" then
          return i
        end
      end
      i = i + 1
    end
    return nil
  end

  -- Search for single '*' to the left of the cursor position
  local left_text = line:sub(1, col)
  local _, italic_start = find_single_asterisk_left(left_text)

  -- Search for single '*' to the right of the cursor position
  local right_text = line:sub(col + 1)
  local italic_end_offset = find_single_asterisk_right(right_text)
  local end_row = start_row

  while not italic_end_offset and end_row < vim.api.nvim_buf_line_count(current_buffer) - 1 do
    end_row = end_row + 1
    local next_line = vim.api.nvim_buf_get_lines(current_buffer, end_row, end_row + 1, false)[1]
    if next_line == "" then
      break
    end
    right_text = right_text .. "\n" .. next_line
    italic_end_offset = find_single_asterisk_right(right_text)
  end

  local italic_end = italic_end_offset and (col + italic_end_offset) or nil

  -- Remove '*' markers if found, otherwise italic the word
  if italic_start and italic_end then
    -- Extract lines
    local text_lines = vim.api.nvim_buf_get_lines(current_buffer, start_row, end_row + 1, false)
    local text = table.concat(text_lines, "\n")
    -- Remove single '*' (offset by 1 instead of 2)
    local new_text = text:sub(1, italic_start - 1) .. text:sub(italic_start + 1, italic_end - 1) .. text:sub(italic_end + 1)
    local new_lines = vim.split(new_text, "\n")
    -- Set new lines in buffer
    vim.api.nvim_buf_set_lines(current_buffer, start_row, end_row + 1, false, new_lines)
  else
    -- Italic the word at the cursor position if no italic markers are found
    local before = line:sub(1, col)
    local after = line:sub(col + 1)
    -- Check if inside single * surround (not **)
    local inside_surround = before:match("%*[^%*]*$") and after:match("^[^%*]*%*")
    if inside_surround then
      vim.cmd("normal gsd*")
    else
      vim.cmd("normal viw")
      vim.cmd("normal gsa*")
    end
    vim.notify("Italicized current word", vim.log.levels.INFO)
  end
end, { desc = "[P]ITALIC toggle italic markers" })
