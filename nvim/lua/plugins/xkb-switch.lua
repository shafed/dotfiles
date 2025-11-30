-- Переключение раскладки
return {
  'lyokha/vim-xkbswitch',
  config = function()
    vim.g.XkbSwitchEnabled = 1
    vim.g.XkbSwitchLib = '/usr/lib/libxkbswitch.so'
    vim.g.XkbSwitchNLayout = 'us'
    
    -- Переменная для хранения последней раскладки в Insert mode
    vim.g.last_insert_layout = 'us'
    
    -- При входе в Insert mode восстановить последнюю раскладку
    vim.api.nvim_create_autocmd('InsertEnter', {
      callback = function()
        if vim.g.last_insert_layout then
          vim.fn.system('xkb-switch -s ' .. vim.g.last_insert_layout)
        end
      end
    })
    
    -- При выходе из Insert mode сохранить раскладку и переключить на английский
    vim.api.nvim_create_autocmd('InsertLeave', {
      callback = function()
        vim.g.last_insert_layout = vim.fn.system('xkb-switch -p'):gsub('%s+', '')
        vim.fn.system('xkb-switch -s us')
      end
    })
    
    -- При входе в командный режим (:) всегда английский
    vim.api.nvim_create_autocmd('CmdlineEnter', {
      pattern = ':',
      callback = function()
        vim.fn.system('xkb-switch -s us')
      end
    })
    
    -- При входе в поиск (/?) восстановить последнюю раскладку из Insert
    vim.api.nvim_create_autocmd('CmdlineEnter', {
      pattern = '[/\\?]',
      callback = function()
        if vim.g.last_insert_layout then
          vim.fn.system('xkb-switch -s ' .. vim.g.last_insert_layout)
        end
      end
    })

    -- При выходе из поиска переключить на английский
    vim.api.nvim_create_autocmd('CmdlineLeave', {
      pattern = '[/\\?]',
      callback = function()
        vim.fn.system('xkb-switch -s us')
      end
    })
    
    -- При выходе из командного режима переключить на английский
    vim.api.nvim_create_autocmd('CmdlineLeave', {
      pattern = ':',
      callback = function()
        vim.fn.system('xkb-switch -s us')
      end
    })
  end
}
