local handlers = require("lsp.handlers")

-- новый способ регистрации сервера
vim.lsp.config["pyright"] = {
  cmd = { "pyright-langserver", "--stdio" },
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
      },
    },
  },
  capabilities = handlers.capabilities(),
}

-- включение LSP-сервера
vim.lsp.enable("pyright")
