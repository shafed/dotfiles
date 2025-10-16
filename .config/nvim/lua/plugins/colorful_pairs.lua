return {
  "HiPhish/rainbow-delimiters.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    local rd = require("rainbow-delimiters")

    vim.g.rainbow_delimiters = {
      strategy = { [""] = rd.strategy["global"] },
      query = { [""] = "rainbow-delimiters", lua = "rainbow-blocks" },
      highlight = {
        "RainbowDelimiterRed",
        "RainbowDelimiterBlue",
        "RainbowDelimiterYellow",
        "RainbowDelimiterViolet",
        "RainbowDelimiterGreen",
        "RainbowDelimiterOrange",
        "RainbowDelimiterIndigo",
      },
    }

    local function set_rainbow_hl()
      local hl = vim.api.nvim_set_hl
      hl(0, "RainbowDelimiterRed",    { fg = "#FF6B6B", nocombine = true })
      hl(0, "RainbowDelimiterBlue",   { fg = "#61AFEF", nocombine = true })
      hl(0, "RainbowDelimiterYellow", { fg = "#FFD75F", nocombine = true })
      hl(0, "RainbowDelimiterIndigo", { fg = "#7A5FFF", nocombine = true })
      hl(0, "RainbowDelimiterGreen",  { fg = "#98C379", nocombine = true })
      hl(0, "RainbowDelimiterOrange", { fg = "#FFA94D", nocombine = true })
      hl(0, "RainbowDelimiterViolet", { fg = "#C792EA", nocombine = true })
    end

    set_rainbow_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = set_rainbow_hl,
      desc = "Reapply rainbow-delimiters highlight after colorscheme",
    })
  end,
}
