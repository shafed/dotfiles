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

-- Oil does not have a built-in persistent multi-selection model for arbitrary
-- entries. Keep a tiny path-based selection so it survives cursor movement and
-- directory changes. <Tab> toggles the entry under the cursor; yy copies all
-- selected paths, falling back to the current entry when nothing is selected.
local Selection = {
  ns = vim.api.nvim_create_namespace("OilMultiSelect"),
  set = {},
  order = {},
}

function Selection.clear()
  Selection.set = {}
  Selection.order = {}
end

function Selection.toggle(path)
  if Selection.set[path] then
    Selection.set[path] = nil
    for i, selected in ipairs(Selection.order) do
      if selected == path then
        table.remove(Selection.order, i)
        break
      end
    end
  else
    Selection.set[path] = true
    table.insert(Selection.order, path)
  end
end

function Selection.paths()
  local paths = {}
  for _, path in ipairs(Selection.order) do
    table.insert(paths, path)
  end
  return paths
end

function Selection.redraw(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, Selection.ns, 0, -1)

  local oil = require("oil")
  local dir = oil.get_current_dir(buf)
  if not dir then
    return
  end

  for lnum = 1, vim.api.nvim_buf_line_count(buf) do
    local entry = oil.get_entry_on_line(buf, lnum)
    if entry and entry.name ~= ".." then
      local path = entry_path(dir, entry)
      if Selection.set[path] then
        vim.api.nvim_buf_set_extmark(buf, Selection.ns, lnum - 1, 0, {
          sign_text = "●",
          sign_hl_group = "OilDir",
          priority = 100,
        })
      end
    end
  end
end

local function toggle_selection()
  local oil = require("oil")
  local entry = oil.get_cursor_entry()
  if not entry or entry.name == ".." then
    vim.notify("No file or directory selected", vim.log.levels.WARN)
    return
  end

  local path = entry_path(oil.get_current_dir(), entry)
  Selection.toggle(path)
  Selection.redraw(0)
  vim.cmd.normal({ "j", bang = true })
end

local function copy_selection_or_cursor()
  local paths = Selection.paths()
  if #paths == 0 then
    local oil = require("oil")
    local entry = oil.get_cursor_entry()
    if not entry then
      vim.notify("No file or directory selected", vim.log.levels.WARN)
      return
    end
    paths = { entry_path(oil.get_current_dir(), entry) }
  end

  file_clipboard.copy_paths(paths)
end

return {
  "stevearc/oil.nvim",
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    default_file_explorer = true,
    delete_to_trash = true,
    win_options = {
      -- <Tab> multi-selection is rendered with extmark signs.
      signcolumn = "yes",
    },
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
      "<Tab>",
      toggle_selection,
      ft = "oil",
      desc = "Toggle file/directory selection",
    },
    {
      "yy",
      copy_selection_or_cursor,
      ft = "oil",
      desc = "Copy selected files/directories to clipboard",
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
  config = function(_, opts)
    require("oil").setup(opts)

    vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
      pattern = "oil://*",
      callback = function(args)
        vim.schedule(function()
          Selection.redraw(args.buf)
        end)
      end,
    })
  end,
}
