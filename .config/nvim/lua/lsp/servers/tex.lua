local M = {}

function M.setup()
  local handlers = require("lsp.handlers")

  vim.lsp.config["texlab"] = {
    cmd = { "texlab" },
    filetypes = { "tex", "plaintex", "bib" },
    capabilities = handlers.capabilities(),
    on_attach = handlers.on_attach,
    settings = {
      texlab = {
        rootDirectory = nil,
        build = {
          executable = "latexmk",
          args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
          onSave = false,
          forwardSearchAfter = false,
        },
        auxDirectory = ".",
        forwardSearch = {
          executable = nil,
          args = {},
        },
        chktex = {
          onOpenAndSave = false,
          onEdit = false,
        },
        diagnosticsDelay = 300,
        latexFormatter = "latexindent",
        latexindent = {
          ["local"] = nil, -- ✅ ключ обёрнут в кавычки
          modifyLineBreaks = false,
        },
        bibtexFormatter = "texlab",
        formatterLineLength = 80,
      },
    },
  }

  vim.lsp.enable("texlab")
end

return M
