return {
  {
    "folke/sidekick.nvim",
    opts = {
      cli = {
        mux = { enabled = true, create = "split" },
        tools = {
          -- Claude Code drops to 256-colour whenever $TMUX is set, regardless
          -- of COLORTERM, FORCE_COLOR or terminfo RGB (its own tmux-truecolor
          -- probe short-circuits on $TMUX alone). That turns its #d77757
          -- accent into palette index 174 (#d78787, pink). Found via strings
          -- on the bundled CLI: `if(a.CLAUDE_CODE_TMUX_TRUECOLOR)return!1` is
          -- checked before the `$TMUX` downgrade, so it's a real (if
          -- undocumented) escape hatch, not a guess.
          claude = { env = { CLAUDE_CODE_TMUX_TRUECOLOR = "1" } },
        },
      },
    },
    config = function(_, opts)
      require("sidekick").setup(opts)
      -- Prefer a native kitty split when Neovim is running inside kitty. The
      -- configured mux remains the fallback elsewhere and keeps existing tmux
      -- sessions discoverable.
      require("utils.sidekick_kitty").setup()

      -- sidekick links its terminal window's background to NormalFloat
      -- (sidekick/cli/terminal.lua's winhighlight + config.lua's set_hl),
      -- which this colorscheme renders as a muted/warm tint distinct from
      -- the CLI's own near-black background. Match Normal instead.
      local function fix_sidekick_hl()
        vim.api.nvim_set_hl(0, "SidekickChat", { link = "Normal" })
      end
      fix_sidekick_hl()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = fix_sidekick_hl })
    end,
  },
}
