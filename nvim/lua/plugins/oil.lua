local file_clipboard = require("utils.file_clipboard")

-- Absolute path for an oil entry in the current directory listing. ".." has
-- no real entry of its own, so it resolves to the listing's own directory.
local function entry_path(dir, entry)
  return entry.name == ".." and dir:sub(1, -2) or (dir .. entry.name)
end

-- Go up `vim.v.count1` parent directories in one step (`3h` == three `-`
-- presses without three separate buffer loads). Plain press behaves like
-- oil's default single-level parent nav.
local function go_up_parent()
  local oil = require("oil")
  local target = oil.get_current_dir():sub(1, -2)
  for _ = 1, vim.v.count1 do
    target = vim.fn.fnamemodify(target, ":h")
  end
  oil.open(target)
end

return {
  "stevearc/oil.nvim",
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    default_file_explorer = true,
    delete_to_trash = true,
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ["q"] = { "actions.close", mode = "n" },
      ["<Esc>"] = { "actions.close", mode = "n" },
    },
  },
  -- Optional dependencies
  dependencies = { { "nvim-mini/mini.icons", opts = {} } },
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
  keys = {
    {
      "<leader>e",
      "<cmd>Oil<cr>",
      desc = "Open oil (Directory of Current File)",
    },
    {
      "<leader>E",
      function()
        vim.cmd.Oil(vim.fn.fnameescape(vim.uv.cwd()))
      end,
      desc = "Open oil (cwd)",
    },
    {
      "yy",
      function()
        local oil = require("oil")
        local entry = oil.get_cursor_entry()
        if not entry then
          vim.notify("No file or directory selected", vim.log.levels.WARN)
          return
        end
        file_clipboard.copy_paths({ entry_path(oil.get_current_dir(), entry) })
      end,
      ft = "oil",
      desc = "Copy file/directory under cursor to clipboard",
    },
    {
      "y",
      function()
        local oil = require("oil")
        local dir = oil.get_current_dir()
        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        if start_line > end_line then
          start_line, end_line = end_line, start_line
        end
        local paths = {}
        for lnum = start_line, end_line do
          local entry = oil.get_entry_on_line(0, lnum)
          if entry and entry.name ~= ".." then
            table.insert(paths, dir .. entry.name)
          end
        end
        vim.api.nvim_input("<Esc>")
        file_clipboard.copy_paths(paths)
      end,
      mode = "x",
      ft = "oil",
      desc = "Copy selected files/directories to clipboard",
    },
    {
      "p",
      function()
        local oil = require("oil")
        local dir = oil.get_current_dir()
        local entry = oil.get_cursor_entry()
        local dest = (entry and entry.type == "directory" and entry.name ~= "..") and (dir .. entry.name .. "/") or dir
        if file_clipboard.paste_into(dest) then
          require("oil.actions").refresh.callback({ force = true })
        end
      end,
      ft = "oil",
      desc = "Paste from clipboard",
    },
  },
}
