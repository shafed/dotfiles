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

-- Запуск Python файла
map('n', '<C-f5>', ':w<CR>:!python3 %<CR>', { desc = "Run Python file" })
map('i', '<C-f5>', '<Esc>:w<CR>:!python3 %<CR>', { desc = "Run Python file" })

-- Перемещение строк
map('n', '<C-j>', ':m .+1<CR>==', { desc = "Move line down" })
map('n', '<C-k>', ':m .-2<CR>==', { desc = "Move line up" })
map('i', '<C-j>', '<Esc>:m .+1<CR>==gi', { desc = "Move line down" })
map('i', '<C-k>', '<Esc>:m .-2<CR>==gi', { desc = "Move line up" })
map('v', '<C-j>', ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map('v', '<C-k>', ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
