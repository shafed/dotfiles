-- Percent-encode a filesystem path for inclusion in a file:// URI.
-- Encodes everything except unreserved chars and "/" so the URI round-trips
-- through the clipboard and is consumed correctly by other apps (Nautilus, etc.).
local function path_to_uri(path)
  local encoded = path:gsub("[^%w%-%.%_%~/]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return "file://" .. encoded
end

-- Parse a text/uri-list blob into a list of decoded filesystem paths.
-- Handles CRLF or LF line endings, skips blank and "#" comment lines
-- (per RFC 2483), strips the file:// scheme, percent-decodes, and drops any
-- trailing slash so basenames resolve correctly.
local function uri_list_to_paths(blob)
  local paths = {}
  for line in tostring(blob):gmatch("[^\r\n]+") do
    if not line:match("^%s*#") then
      local uri = line:gsub("^%s+", ""):gsub("%s+$", "")
      if uri ~= "" then
        local p = uri:gsub("^file://", ""):gsub("%%(%x%x)", function(h)
          return string.char(tonumber(h, 16))
        end)
        p = p:gsub("/+$", "")
        if p ~= "" then
          table.insert(paths, p)
        end
      end
    end
  end
  return paths
end

-- Given a destination directory and a desired basename, return a path that does
-- not collide with an existing entry, appending an incrementing number ("name1",
-- "name2", ...) before the extension for files.
local function nonconflicting_dest(dir, name)
  local dest = dir .. "/" .. name
  if vim.uv.fs_stat(dest) == nil then
    return dest
  end
  local stem, ext = name:match("^(.*)(%.[^%.]+)$")
  if not stem then
    stem, ext = name, ""
  end
  local i = 1
  while true do
    local candidate = string.format("%s/%s%d%s", dir, stem, i, ext)
    if vim.uv.fs_stat(candidate) == nil then
      return candidate
    end
    i = i + 1
  end
end

-- Copy the given absolute paths to the system clipboard as a text/uri-list.
local function copy_paths_to_clipboard(paths)
  if #paths == 0 then
    vim.notify("No files selected", vim.log.levels.WARN)
    return
  end
  local uris, names = {}, {}
  for _, p in ipairs(paths) do
    table.insert(uris, path_to_uri(p))
    table.insert(names, vim.fn.fnamemodify(p, ":t"))
  end
  local result = vim.fn.system({ "wl-copy", "--type", "text/uri-list" }, table.concat(uris, "\n"))
  if vim.v.shell_error ~= 0 then
    vim.notify("Copy failed: " .. result, vim.log.levels.ERROR)
  else
    vim.notify(string.format("Copied %d item(s):\n%s", #uris, table.concat(names, "\n")), vim.log.levels.INFO)
  end
end

-- Ad-hoc multi-selection: toggle individual entries (e.g. rows 1, 3, 5) with
-- <Tab>, then copy them all. State is keyed by absolute path (not line number),
-- since mini.files redraws and renumbers rows on navigation.
local Selection = {
  ns = vim.api.nvim_create_namespace("MiniFilesMultiSelect"),
  -- set of selected paths; ordered list preserves selection order for copying
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
    for i, p in ipairs(Selection.order) do
      if p == path then
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
  local out = {}
  for _, p in ipairs(Selection.order) do
    table.insert(out, p)
  end
  return out
end

-- Redraw the selection marker (a sign in the line's left margin) for the given
-- mini.files buffer. Called on every MiniFilesBufferUpdate so highlights survive
-- redraws and follow entries by path.
function Selection.redraw(buf_id)
  if not (buf_id and vim.api.nvim_buf_is_valid(buf_id)) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf_id, Selection.ns, 0, -1)
  local mini_files = require("mini.files")
  local n = vim.api.nvim_buf_line_count(buf_id)
  for lnum = 1, n do
    local entry = mini_files.get_fs_entry(buf_id, lnum)
    if entry and Selection.set[entry.path] then
      vim.api.nvim_buf_set_extmark(buf_id, Selection.ns, lnum - 1, 0, {
        sign_text = "●",
        sign_hl_group = "MiniFilesTitleFocused",
        priority = 100,
      })
    end
  end
end

return {
  "nvim-mini/mini.files",
  opts = {
    windows = {
      preview = true,
      width_focus = 30,
      width_preview = 30,
    },
    options = {
      -- Whether to use for editing directories
      permanent_delete = false,
      -- Disabled by default in LazyVim because neo-tree is used for that
      use_as_default_explorer = true,
    },
    -- Module mappings created only inside explorer.
    -- Use `''` (empty string) to not create one.
    mappings = {
      close = "<Esc>",
      go_in = "l",
      -- Default "L"
      go_in_plus = "<CR>",
      -- Default "h"
      go_out = "H",
      -- Default "H"
      go_out_plus = "h",
      mark_goto = "'",
      mark_set = "m",
      reset = "<BS>",
      reveal_cwd = "@",
      show_help = "g?",
      synchronize = "=",
      trim_left = "<",
      trim_right = ">",
    },
  },
  init = function()
    local group = vim.api.nvim_create_augroup("MiniFilesMultiSelect", { clear = true })
    -- Redraw selection markers whenever a directory buffer is (re)rendered, so
    -- highlights survive navigation and stay attached to the right entries.
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "MiniFilesBufferUpdate",
      callback = function(args)
        Selection.redraw(args.data.buf_id)
      end,
    })
    -- Drop the selection when the explorer closes so it never leaks into the
    -- next session.
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "MiniFilesExplorerClose",
      callback = function()
        Selection.clear()
      end,
    })
  end,
  keys = {
    {
      "<leader>e",
      function()
        require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
      end,
      desc = "Open mini.files (Directory of Current File)",
    },
    {
      "<leader>E",
      function()
        require("mini.files").open(vim.uv.cwd(), true)
      end,
      desc = "Open mini.files (cwd)",
    },
    {
      "<Tab>",
      function()
        local curr_entry = require("mini.files").get_fs_entry()
        if not curr_entry then
          return
        end
        Selection.toggle(curr_entry.path)
        Selection.redraw(vim.api.nvim_get_current_buf())
      end,
      ft = "minifiles",
      desc = "Toggle multi-select on entry",
    },
    {
      "<leader>yy",
      function()
        -- Prefer the ad-hoc multi-selection; fall back to the entry under cursor.
        local marked = Selection.paths()
        if #marked > 0 then
          copy_paths_to_clipboard(marked)
          Selection.clear()
          Selection.redraw(vim.api.nvim_get_current_buf())
          return
        end
        local curr_entry = require("mini.files").get_fs_entry()
        if curr_entry then
          copy_paths_to_clipboard({ curr_entry.path })
        else
          vim.notify("No file or directory selected", vim.log.levels.WARN)
        end
      end,
      ft = "minifiles",
      desc = "Copy marked (or current) file/directory to clipboard",
    },

    {
      "<leader>yy",
      function()
        local mini_files = require("mini.files")
        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        if start_line > end_line then
          start_line, end_line = end_line, start_line
        end
        local paths = {}
        for lnum = start_line, end_line do
          local entry = mini_files.get_fs_entry(0, lnum)
          if entry then
            table.insert(paths, entry.path)
          end
        end
        vim.api.nvim_input("<Esc>")
        copy_paths_to_clipboard(paths)
      end,
      mode = "x",
      ft = "minifiles",
      desc = "Copy selected files/directories to clipboard",
    },

    {
      "<M-t>",
      function()
        local mini_files = require("mini.files")
        local curr_entry = mini_files.get_fs_entry()
        if curr_entry and curr_entry.fs_type == "directory" then
          require("utils.tmux").open(curr_entry.path)
        else
          vim.notify("Not a directory or no entry selected", vim.log.levels.WARN)
        end
      end,
      ft = "minifiles",
      noremap = true,
      silent = true,
      desc = "[P]Open dir in tmux pane",
    },
    {
      "<leader>o",
      function()
        local mini_files = require("mini.files")
        local curr_entry = mini_files.get_fs_entry()
        if curr_entry then
          vim.system({ "xdg-open", curr_entry.path }, { detach = true })
        else
          vim.notify("No file or directory selected", vim.log.levels.WARN)
        end
      end,
      noremap = true,
      silent = true,
      desc = "[P]Open with default app",
    },
    {
      "<leader>p",
      function()
        local mini_files = require("mini.files")
        local curr_entry = mini_files.get_fs_entry()
        if not curr_entry then
          vim.notify("Failed to retrieve current entry in mini.files.", vim.log.levels.ERROR)
          return
        end
        local curr_dir = curr_entry.fs_type == "directory" and curr_entry.path
          or vim.fn.fnamemodify(curr_entry.path, ":h")
        local output = vim.fn.system({ "wl-paste", "--no-newline", "--type", "text/uri-list" })
        if vim.v.shell_error ~= 0 or output == "" then
          vim.notify("Clipboard does not contain a valid file URI.", vim.log.levels.WARN)
          return
        end
        local sources = uri_list_to_paths(output)
        if #sources == 0 then
          vim.notify("Could not parse any file path from clipboard.", vim.log.levels.WARN)
          return
        end

        local pasted, errors = {}, {}
        for _, source_path in ipairs(sources) do
          local stat = vim.uv.fs_stat(source_path)
          if not stat then
            table.insert(errors, "Missing source: " .. source_path)
          else
            local dest_path = nonconflicting_dest(curr_dir, vim.fn.fnamemodify(source_path, ":t"))
            local is_dir = stat.type == "directory"
            -- -T: treat dest as the final name (never copy-into), required for the
            -- auto-renamed destination to behave for both files and directories.
            local copy_cmd = is_dir and { "cp", "-rT", source_path, dest_path }
              or { "cp", "-T", source_path, dest_path }
            local result = vim.fn.system(copy_cmd)
            if vim.v.shell_error ~= 0 then
              table.insert(errors, vim.fn.fnamemodify(source_path, ":t") .. ": " .. result)
            else
              table.insert(pasted, vim.fn.fnamemodify(dest_path, ":t"))
            end
          end
        end

        mini_files.synchronize()
        if #pasted > 0 then
          vim.notify(string.format("Pasted %d item(s):\n%s", #pasted, table.concat(pasted, "\n")), vim.log.levels.INFO)
        end
        if #errors > 0 then
          vim.notify("Paste errors:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
        end
      end,
      ft = "minifiles",
      noremap = true,
      silent = true,
      desc = "[P]Paste from clipboard",
    },
  },
}
