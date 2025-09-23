local M = {}

function M.setup()
  local lspconfig = require("lspconfig")
  local capabilities = require("lsp.handlers").capabilities()

  -- Конфигурация для texlab (LaTeX LSP сервер)
  lspconfig.texlab.setup({
    capabilities = capabilities,
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
          local = nil, -- local is a reserved keyword in Lua, so use nil
          modifyLineBreaks = false,
        },
        bibtexFormatter = "texlab",
        formatterLineLength = 80,
      },
    },
    filetypes = { "tex", "plaintex", "bib" },
  })
end

return M
