-- Jupyter notebooks inside Neovim, output (incl. plots) rendered inline via
-- kitty's graphics protocol ($TERM=xterm-kitty here). Kernel needs pandas/
-- numpy/etc; that's the "python3-nvim" venv set up in ~/.venvs/nvim (also
-- vim.g.python3_host_prog in config/options.lua, since molten is itself a
-- remote plugin and needs pynvim+jupyter_client on the host python).
return {
  {
    "3rd/image.nvim",
    opts = {
      backend = "kitty",
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    },
  },
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",
    dependencies = { "3rd/image.nvim" },
    init = function()
      -- Must be set before the plugin loads
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = true
      vim.g.molten_wrap_output = true
      vim.g.molten_virt_text_output = true
    end,
    keys = {
      {
        "<leader>mi",
        "<cmd>MoltenInit<cr>",
        desc = "[P]Molten: init kernel for buffer",
      },
      {
        "<leader>mr",
        "<cmd>MoltenEvaluateLine<cr>",
        desc = "[P]Molten: run current line",
      },
      {
        "<leader>mr",
        ":<C-u>MoltenEvaluateVisual<cr>gv",
        mode = "v",
        desc = "[P]Molten: run visual selection",
      },
      {
        "<leader>mc",
        "<cmd>MoltenReevaluateCell<cr>",
        desc = "[P]Molten: re-run current cell",
      },
      {
        "<leader>md",
        "<cmd>MoltenDelete<cr>",
        desc = "[P]Molten: delete cell output",
      },
      {
        "<leader>mh",
        "<cmd>MoltenHideOutput<cr>",
        desc = "[P]Molten: hide output window",
      },
      {
        "<leader>mo",
        "<cmd>MoltenShowOutput<cr>",
        desc = "[P]Molten: show output window",
      },
      {
        "<leader>mn",
        "<cmd>MoltenNext<cr>",
        desc = "[P]Molten: next cell",
      },
      {
        "<leader>mp",
        "<cmd>MoltenPrev<cr>",
        desc = "[P]Molten: previous cell",
      },
    },
  },
  {
    -- .ipynb <-> .py:percent conversion, so notebooks are editable as plain
    -- text; molten's cells are the "# %%" markers this produces
    "GCBallesteros/jupytext.nvim",
    opts = {
      style = "percent",
      output_extension = "py",
      force_ft = "python",
    },
  },
}
