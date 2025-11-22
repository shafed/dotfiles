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
------------

-- Перемещение строк
map('n', '<M-j>', ':m .+1<CR>==', { desc = "Move line down" })
map('n', '<M-k>', ':m .-2<CR>==', { desc = "Move line up" })
map('i', '<M-j>', '<Esc>:m .+1<CR>==gi', { desc = "Move line down" })
map('i', '<M-k>', '<Esc>:m .-2<CR>==gi', { desc = "Move line up" })
map('v', '<M-j>', ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map('v', '<M-k>', ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Create todo list
vim.keymap.set({ "n", "i" }, "<C-g>", function()
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

vim.keymap.set('v', 'p', '"_dP')  -- Не сохранять выделение в регистр
