return {
	"neovim/nvim-lspconfig",
	config = function()
		-- Общие обработчики/кеймапы/diagnostics
		require("lsp.handlers")
		-- Языковые сервера
		require("lsp.servers.python")
		require("lsp.servers.cpp")
		require("lsp.servers.tex")
	end,
}
