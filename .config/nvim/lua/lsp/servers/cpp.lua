local lspconfig = require("lspconfig")
local handlers = require("lsp.handlers")

lspconfig.clangd.setup({
  capabilities = require("lsp.handlers").capabilities(),  -- вызвать функцию
  -- важный блок: ищем корень по файлам проекта, иначе используем текущую папку
  root_dir = function(fname)
    return lspconfig.util.root_pattern("compile_commands.json", "compile_flags.txt", ".git")(fname)
           or vim.loop.cwd()
  end,
  cmd = { "clangd" },
  filetypes = { "c", "cpp", "objc", "objcpp" },
  settings = {
    clangd = {
      arguments = {
        "--header-insertion=never",
        "--completion-style=detailed",
        "--function-arg-placeholders=false",
      },
    },
  },
})
