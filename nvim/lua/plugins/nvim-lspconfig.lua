return {
  "neovim/nvim-lspconfig",
  opts = {
    diagnostics = {
      float = {
        border = "rounded",
      },
    },
    servers = {
      markdown_oxide = {
        capabilities = {
          workspace = {
            didChangeWatchedFiles = {
              dynamicRegistration = true,
            },
          },
        },
        on_attach = function(client, bufnr)
          -- Enable Code Lens
          if client.server_capabilities.codeLensProvider then
            vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "CursorHold", "BufEnter" }, {
              buffer = bufnr,
              callback = function()
                vim.lsp.codelens.refresh({ bufnr = bufnr })
              end,
            })
            vim.lsp.codelens.refresh({ bufnr = bufnr })
          end

          -- Enable opening daily notes with natural language
          vim.api.nvim_create_user_command("Daily", function(args)
            vim.lsp.buf.execute_command({ command = "jump", arguments = { args.args } })
          end, { desc = "Open daily note", nargs = "*" })
        end,
      },
      harper_ls = {
        enabled = true,
        filetypes = { "markdown", "typst" },
        settings = {
          ["harper-ls"] = {
            isolateEnglish = true,
            markdown = {
              -- [ignores this part]()
              -- [[ also ignores my marksman links ]]
              IgnoreLinkTitle = true,
            },
            excludePatterns = {
              "/home/shafed/obsidian/base/notes/day_[123].md",
            },
          },
        },
      },
    },
  },
}
