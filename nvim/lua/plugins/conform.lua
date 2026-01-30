return {
	"stevearc/conform.nvim",
	config = function()
		require("conform").setup({
			formatters_by_ft = {
				python = { "ruff_format", "ruff_organize_imports" },
				markdown = { "prettier" },
				lua = { "stylua" },
				cpp = { "clang-format" },
			},
			format_on_save = { timeout_ms = 500, lsp_fallback = true },
		})
		vim.keymap.set("n", "<leader>f", function()
			require("conform").format()
		end, { desc = "Format code" })
	end,
}
