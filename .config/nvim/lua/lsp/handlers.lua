local M = {}

-- Диагностика (общая настройка)
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = false,
  update_in_insert = false,
})

-- Hover/Signature с рамкой
M.hover = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
  max_width = 80,
  max_height = 20,
  focusable = false,
  close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
})

M.signature_help = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
})

-- Применяем обработчики
vim.lsp.handlers["textDocument/hover"] = M.hover
vim.lsp.handlers["textDocument/signatureHelp"] = M.signature_help

-- Доп. возможности клиента (пример для hover contentFormat)
function M.capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  caps.textDocument.hover = {
    dynamicRegistration = true,
    contentFormat = { "markdown", "plaintext" }
  }
  return caps
end

-- Кеймапы LSP (вешаем на LspAttach)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local buf = args.buf
    local opts = { buffer = buf }
    vim.diagnostic.enable(true, { bufnr = buf })

    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { buffer = buf, desc = "Go to implementation" })
    vim.keymap.set('n', 'K',  vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  end
})

return M
