-- IPython REPL in a split for .py notebooks in jupytext percent format
-- (`# %%` cells). The interpreter comes from the nearest .venv above the buffer
-- (needs ipython there), else from PATH. <leader>sn sends the cell and moves to
-- the next one. Scilab stays on vim-slime.
return {
  "Vigemus/iron.nvim",
  ft = "python",
  config = function()
    local iron = require("iron.core")
    local view = require("iron.view")
    local common = require("iron.fts.common")

    -- iron calls this with { current_bufnr } when creating the repl but with
    -- { current_buffer } from bracketed_paste_python on every send.
    local function ipython(meta)
      local buf = meta.current_bufnr or meta.current_buffer or 0
      local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
      local venv = vim.fs.find(".venv", { upward = true, path = dir, type = "directory" })[1]
      local bin = venv and venv .. "/bin/ipython"
      if bin and vim.uv.fs_stat(bin) then
        return { bin, "--no-autoindent" }
      end
      return { "ipython", "--no-autoindent" }
    end

    iron.setup({
      config = {
        scratch_repl = true,
        repl_definition = {
          python = {
            command = ipython,
            format = common.bracketed_paste_python,
            block_dividers = { "# %%", "#%%" },
          },
        },
        repl_open_cmd = view.split.vertical.rightbelow("40%"),
      },
      -- iron ships no default maps; this is the README set, except toggle_repl
      -- (<leader>rr is code_runner's RunCode).
      keymaps = {
        toggle_repl = "<leader>rt",
        restart_repl = "<leader>rR",
        send_motion = "<leader>sc",
        visual_send = "<leader>sc",
        send_file = "<leader>sf",
        send_line = "<leader>sl",
        send_paragraph = "<leader>sp",
        send_until_cursor = "<leader>su",
        send_mark = "<leader>sm",
        send_code_block = "<leader>sb",
        send_code_block_and_move = "<leader>sn",
        mark_motion = "<leader>mc",
        mark_visual = "<leader>mc",
        remove_mark = "<leader>md",
        cr = "<leader>s<cr>",
        interrupt = "<leader>s<space>",
        exit = "<leader>sq",
        clear = "<leader>cl",
      },
    })
  end,
}
