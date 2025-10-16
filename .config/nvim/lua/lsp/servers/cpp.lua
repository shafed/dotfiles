local handlers = require("lsp.handlers")

local config = {
  cmd = {
    "clangd",
    "--header-insertion=never",
    "--completion-style=detailed",
    "--function-arg-placeholders=false",
  },
  filetypes = { "c", "cpp", "objc", "objcpp" },
  root_dir = function(fname)
    return vim.fs.root(fname, { "compile_commands.json", "compile_flags.txt", ".git" })
           or vim.uv.cwd()
  end,
  capabilities = handlers.capabilities(),
  -- ✅ Добавьте обработчики
  handlers = {
    ["textDocument/hover"] = handlers.hover,
    ["textDocument/signatureHelp"] = handlers.signature_help,
  },
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "objc", "objcpp" },
  callback = function()
    vim.lsp.start(config)
  end,
})
