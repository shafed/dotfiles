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
map('n', '<C-j>', ':m .+1<CR>==', { desc = "Move line down" })
map('n', '<C-k>', ':m .-2<CR>==', { desc = "Move line up" })
map('i', '<C-j>', '<Esc>:m .+1<CR>==gi', { desc = "Move line down" })
map('i', '<C-k>', '<Esc>:m .-2<CR>==gi', { desc = "Move line up" })
map('v', '<C-j>', ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map('v', '<C-k>', ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

