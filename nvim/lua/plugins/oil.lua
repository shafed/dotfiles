local file_clipboard = require("utils.file_clipboard")

-- Absolute path for an oil entry in the current directory listing. ".." has
-- no real entry of its own, so it resolves to the listing's own directory.
local function entry_path(dir, entry)
  return entry.name == ".." and dir:sub(1, -2) or (dir .. entry.name)
end

-- Remember the last focused entry for every directory, similar to mini.files'
-- tracked directory cursors. Store entry names instead of line numbers so the
-- position survives sorting changes and files being inserted/removed.
local CursorMemory = {
  entries = {},
}

local function directory_key(dir)
  return vim.fs.normalize(dir)
end

local function explorer_win(buf, preferred_win)
  local function is_explorer(win)
    return vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf and not vim.wo[win].previewwindow
  end

  if preferred_win and is_explorer(preferred_win) then
    return preferred_win
  end

  local current_win = vim.api.nvim_get_current_win()
  if is_explorer(current_win) then
    return current_win
  end

  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if is_explorer(win) then
      return win
    end
  end
end

function CursorMemory.remember(buf, win)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  local oil = require("oil")
  local dir = oil.get_current_dir(buf)
  if not dir then
    return
  end

  win = explorer_win(buf, win)
  if not win then
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  local entry = oil.get_entry_on_line(buf, lnum)
  if entry and entry.name ~= ".." then
    CursorMemory.entries[directory_key(dir)] = entry.name
  end
end

function CursorMemory.restore(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  local oil = require("oil")
  local dir = oil.get_current_dir(buf)
  local wanted = dir and CursorMemory.entries[directory_key(dir)]
  if not wanted then
    return
  end

  local target_line
  for lnum = 1, vim.api.nvim_buf_line_count(buf) do
    local entry = oil.get_entry_on_line(buf, lnum)
    if entry and entry.name == wanted then
      target_line = lnum
      break
    end
  end
  if not target_line then
    return
  end

  local win = explorer_win(buf)
  if win then
    vim.api.nvim_win_set_cursor(win, { target_line, 0 })
  end
end

local function select_with_cursor_memory()
  CursorMemory.remember(vim.api.nvim_get_current_buf())
  require("oil.actions").select.callback({
    callback = function(err)
      if not err then
        vim.schedule(function()
          CursorMemory.restore(vim.api.nvim_get_current_buf())
        end)
      end
    end,
  })
end

local function parent_with_cursor_memory()
  local oil = require("oil")
  local buf = vim.api.nvim_get_current_buf()
  local dir = oil.get_current_dir(buf)

  CursorMemory.remember(buf)
  if dir then
    local child_dir = directory_key(dir)
    local parent_dir = vim.fs.dirname(child_dir)
    if parent_dir ~= child_dir then
      CursorMemory.entries[directory_key(parent_dir)] = vim.fs.basename(child_dir)
    end
  end

  oil.open(nil, nil, function()
    vim.schedule(function()
      CursorMemory.restore(vim.api.nvim_get_current_buf())
    end)
  end)
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
      ["H"] = {
        callback = parent_with_cursor_memory,
        mode = "n",
        desc = "Open parent and focus the directory just left",
      },
      ["L"] = {
        callback = select_with_cursor_memory,
        mode = "n",
        desc = "Open entry and restore its directory cursor",
      },
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
      "<cmd>Oil --preview<cr>",
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

    -- OilEnter fires after the directory has actually rendered, so restore its
    -- last focused entry and then redraw persistent multi-selection highlights.
    vim.api.nvim_create_autocmd("User", {
      pattern = "OilEnter",
      callback = function(args)
        local buf = (args.data and args.data.buf) or vim.api.nvim_get_current_buf()
        vim.schedule(function()
          CursorMemory.restore(buf)
          Selection.redraw(buf)
        end)
      end,
    })

    -- Track the focused entry continuously, and once more before leaving the
    -- Oil buffer so immediately entering a directory also records its parent
    -- position even if no CursorMoved event happened first.
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave" }, {
      pattern = "oil://*",
      callback = function(args)
        CursorMemory.remember(args.buf)
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
