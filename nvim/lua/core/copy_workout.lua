local M = {}

--- Копирует данные из последней markdown-таблицы в буфер обмена
--- Формат вывода (3 строки):
--- ex1              ex2
--- Reps  Weight     Reps  Weight
--- reps  wt  kg     reps  wt  kg
function M.copy_table_data()
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
  
  if #current_table > 0 then
    table.insert(tables, current_table)
  end
  
  if #tables == 0 then
    vim.notify("Таблицы не найдены!", vim.log.levels.WARN)
    return
  end
  
  local last_table = tables[#tables]
  
  local exercises = {}
  local data = {}
  
  for i = 3, #last_table do
    local line = last_table[i]
    local cells = {}
    for cell in line:gmatch("[^|]+") do
      table.insert(cells, vim.trim(cell))
    end
    
    -- cells[1] = №, cells[2] = Exercise, cells[3] = Reps, cells[4] = Weight
    if #cells >= 4 then
      local exercise = cells[2]
      local reps = cells[3]
      local weight = cells[4]
      
      -- Обработка reps (извлечение части после X если есть дефис)
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
    -- Строка 1: названия упражнений
    local line1_parts = {}
    for i, ex in ipairs(exercises) do
      table.insert(line1_parts, ex)
      if i < #exercises then
        table.insert(line1_parts, "")
        table.insert(line1_parts, "")
      end
    end
    
    -- Строка 2: заголовки Reps/Weight
    local line2_parts = {}
    for i = 1, #exercises do
      table.insert(line2_parts, "Reps")
      table.insert(line2_parts, "Weight")
      if i < #exercises then
        table.insert(line2_parts, "")
      end
    end
    
    -- Строка 3: данные reps/weight/kg
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
    vim.notify("Скопировано: " .. #exercises .. " упражнений", vim.log.levels.INFO)
  else
    vim.notify("Нет данных для копирования!", vim.log.levels.WARN)
  end
end

return M
