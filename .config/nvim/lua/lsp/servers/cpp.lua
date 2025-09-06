local lspconfig = require("lspconfig")
local handlers = require("lsp.handlers")

lspconfig.clangd.setup({
  capabilities = require("lsp.handlers").capabilities(),  -- вызвать функцию
  on_attach = handlers.on_attach,
  -- важный блок: ищем корень по файлам проекта, иначе используем текущую папку
  root_dir = function(fname)
    return lspconfig.util.root_pattern("compile_commands.json", "compile_flags.txt", ".git")(fname)
           or vim.loop.cwd()
  end,
  cmd = { "clangd" },
  filetypes = { "c", "cpp", "objc", "objcpp" },
})
