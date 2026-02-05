return {
  "m4xshen/hardtime.nvim",
  lazy = false,
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {},
  opts = function(_, opts)
    -- make sure the default table exists
    opts.restricted_keys = opts.restricted_keys or {}
    -- do NOT restrict gj / gk
    opts.restricted_keys["gj"] = false
    opts.restricted_keys["gk"] = false
    opts.max_count = 12
  end,
}
