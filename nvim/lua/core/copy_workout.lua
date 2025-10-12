local M = {}

function M.copy_table_data()
  -- Получаем содержимое текущего буфера
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Находим все таблицы
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
  
  -- Добавляем последнюю таблицу, если она есть
  if #current_table > 0 then
    table.insert(tables, current_table)
  end
  
  if #tables == 0 then
    vim.notify("Таблицы не найдены!", vim.log.levels.WARN)
    return
  end
  
  -- Берем последнюю таблицу
  local last_table = tables[#tables]
  
  -- Пропускаем заголовок и разделитель (первые 2 строки)
  local result = {}
  
  for i = 3, #last_table do
    local line = last_table[i]
    -- Разбиваем строку по |
    local cells = {}
    for cell in line:gmatch("[^|]+") do
      table.insert(cells, vim.trim(cell))
    end
    
    if #cells >= 4 then
      local reps = cells[3]
      local weight = cells[4]
      
      -- Обработка reps (извлечение части после X если есть дефис)
      local processed_reps = reps
      local match = reps:match("^%d+X([%d%-,]+)$")
      if match and match:find("-") then
        processed_reps = match
      end
      
      table.insert(result, processed_reps)
      table.insert(result, weight)
      table.insert(result, "kg")
    end
  end
  
  if #result > 0 then
    local output = table.concat(result, "\t")
    
    -- Копируем в системный буфер обмена
    vim.fn.setreg("+", output)
    vim.notify("Скопировано в буфер обмена!", vim.log.levels.INFO)
    
    -- Альтернативный способ через системную команду (более надежный)
    -- vim.fn.system("echo '" .. output .. "' | pbcopy")  -- для macOS
    -- vim.fn.system("echo '" .. output .. "' | xclip -selection clipboard")  -- для Linux
    -- vim.fn.system("echo '" .. output .. "' | clip.exe")  -- для WSL
  else
    vim.notify("Нет данных для копирования!", vim.log.levels.WARN)
  end
end

return M
