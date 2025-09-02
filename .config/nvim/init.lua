-- === Core ===
require("core.options")
require("core.langmap")
require("core.clipboard")
require("core.keymaps")
require("core.autocmds")

-- === lazy.nvim bootstrap ===
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- === Плагины: автоподхват всех спецификаций из lua/plugins/*.lua ===
require("lazy").setup({
  { import = "plugins" },  -- импортирует все файлы в lua/plugins/
}, {
  change_detection = { notify = false },
})

-- === Цветовая схема (после загрузки плагинов) ===
vim.cmd.colorscheme("gruvbox-material")


vim.keymap.set('n', '<leader>q', function()
  local pdf = vim.fn.expand('%:r') .. '.pdf'
  -- открыть pdf в zathura
  vim.fn.jobstart({ 'zathura', pdf }, { detach = true })
  -- немного подождать и растянуть окно
  vim.fn.jobstart({ 'sh', '-c', 'sleep 0.3 && wmctrl -r zathura -b add,maximized_vert,maximized_horz' },
                  { detach = true })
end, { desc = 'Open PDF in zathura maximized' })

