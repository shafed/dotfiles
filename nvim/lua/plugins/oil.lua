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

  -- Clear stale selection highlights from every Oil buffer, not only the
  -- current directory. This matters when entries were selected across dirs.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "oil" then
      pcall(vim.api.nvim_buf_clear_namespace, buf, Selection.ns, 0, -1)
    end
  end
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
          line_hl_group = "Visual",
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
  Selection.redraw(vim.api.nvim_get_current_buf())
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

  -- A copied selection is a completed operation, like selection in a normal
  -- file manager. Do not leave old <Tab> highlights active for the next copy.
  Selection.clear()
end

local function copy_visual_selection()
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
  Selection.clear()
end

local function paste_from_clipboard()
  local oil = require("oil")
  local dir = oil.get_current_dir()
  local entry = oil.get_cursor_entry()
  local dest = (entry and entry.type == "directory" and entry.name ~= "..") and (dir .. entry.name .. "/") or dir
  if file_clipboard.paste_into(dest) then
    require("oil.actions").refresh.callback({ force = true })
  end
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

      -- Keep these inside Oil's own buffer-local keymap setup. Defining them as
      -- Lazy `keys` with ft = "oil" was racy and could lose to other mappings.
      ["<Tab>"] = {
        callback = toggle_selection,
        mode = "n",
        desc = "Toggle file/directory selection",
      },
      ["yy"] = {
        callback = copy_selection_or_cursor,
        mode = "n",
        desc = "Copy selected files/directories to clipboard",
      },
      ["y"] = {
        callback = copy_visual_selection,
        mode = "x",
        desc = "Copy selected files/directories to clipboard",
      },
      ["p"] = {
        callback = paste_from_clipboard,
        mode = "n",
        desc = "Paste from clipboard",
      },
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
  },
  config = function(_, opts)
    require("oil").setup(opts)

    -- OilEnter fires after the directory has actually rendered, so selection
    -- highlights are restored reliably when moving between Oil buffers.
    vim.api.nvim_create_autocmd("User", {
      pattern = "OilEnter",
      callback = function(args)
        local buf = (args.data and args.data.buf) or vim.api.nvim_get_current_buf()
        vim.schedule(function()
          Selection.redraw(buf)
        end)
      end,
    })

    -- Also refresh highlights after local buffer edits (renames/new entries)
    -- without applying them; autosave is disabled for Oil in auto-save.lua.
    vim.api.nvim_create_autocmd("TextChanged", {
      pattern = "oil://*",
      callback = function(args)
        vim.schedule(function()
          Selection.redraw(args.buf)
        end)
      end,
    })
  end,
}
