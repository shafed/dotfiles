return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		options = {
			theme = "auto",
			globalstatus = true,
			icons_enabled = true,
			section_separators = "",
			component_separators = { left = "│", right = "│" },
		},

		sections = {
			lualine_a = {
				{
					"buffers",
					mode = 0,
					show_filename_only = true,
					hide_filename_extension = false,
					show_modified_status = true,
					use_mode_colors = true,
					symbols = { modified = " ●", alternate_file = "", directory = "" },
					buffers_color = {
						active = "lualine_a_normal",
						inactive = "lualine_c_inactive",
					},
					max_length = vim.o.columns * 2 / 3,
				},
			},
			lualine_b = {},
			lualine_c = {},
			lualine_x = { --for recording (q) macros
				{
					require("noice").api.statusline.mode.get,
					cond = require("noice").api.statusline.mode.has,
					color = { fg = "#ff9e64" },
				},
			},
			lualine_y = { "encoding" },
			lualine_z = { "location" },
		},
	},
}
