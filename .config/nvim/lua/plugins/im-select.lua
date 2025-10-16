return {
"keaising/im-select.nvim",
config = function()
require("im_select").setup({
default_im_select = "1033",
default_command = "im-select.exe",
set_default_events = {"InsertLeave"},
})
-- Переключение на английский при ВХОДЕ в командный режим
vim.api.nvim_create_autocmd("CmdLineEnter", {
  callback = function()
    local cmdtype = vim.v.event.cmdtype
    -- Переключаем на английский при входе в команды
    if cmdtype == ":" then
      vim.fn.system("im-select.exe 1033")
    end
  end,
})

-- Переключение на английский при ВЫХОДЕ из поиска
vim.api.nvim_create_autocmd("CmdLineLeave", {
  callback = function()
    local cmdtype = vim.v.event.cmdtype
    -- Переключаем только для поиска
    if cmdtype == "/" or cmdtype == "?" then
      vim.fn.system("im-select.exe 1033")
    end
  end,
})

end,
}
