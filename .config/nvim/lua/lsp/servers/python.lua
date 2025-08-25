local lspconfig = require("lspconfig")
local handlers = require("lsp.handlers")

lspconfig.pyright.setup({
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
      }
    }
  },
  capabilities = handlers.capabilities(),
})

