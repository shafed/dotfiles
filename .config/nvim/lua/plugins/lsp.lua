return {
  "neovim/nvim-lspconfig",
  config = function()
    -- Общие обработчики/кеймапы/diagnostics
    require("lsp.handlers")
    -- Языковые сервера
    require("lsp.servers.python")
  end,
}

