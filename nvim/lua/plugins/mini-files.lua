local file_clipboard = require("utils.file_clipboard")

-- mini.files' LSP file-operation hook (mini.nvim >= 0.18.0) assumes every
-- `workspace.fileOperations` filter scheme is a string. Some servers advertise
-- `"scheme": null` (or `"matches": null`), which Neovim decodes to `vim.NIL`
-- (a userdata sentinel), so the hook's `scheme .. ':'` crashes with E5108.
-- Normalize such filters to plain `nil` so they are treated as "no filter".
local function normalize_file_ops_schemes(client)
  local file_ops = client.server_capabilities
    and client.server_capabilities.workspace
    and client.server_capabilities.workspace.fileOperations
  if type(file_ops) ~= "table" then
    return
  end
  local function replace_nil(t)
    for k, v in pairs(t) do
      if v == vim.NIL then
        t[k] = nil
      elseif type(v) == "table" then
        replace_nil(v)
      end
    end
  end
  replace_nil(file_ops)
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

-- Open the image file under the cursor in a centered floating window, rendered
-- via the Snacks image module (kitty graphics protocol). Falls back to a plain
-- text buffer if the format isn't a supported image.
local preview_buf = nil
local preview_path = nil

local function close_preview()
  if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
    for _, w in ipairs(vim.fn.win_findbuf(preview_buf)) do
      if vim.api.nvim_win_is_valid(w) then
        vim.api.nvim_win_close(w, true)
      end
    end
  end
  preview_buf, preview_path = nil, nil
end

local function preview_image()
  -- <leader>ip injected into the float buffer (filetype = "minifiles") — treat
  -- it as a toggle: close the preview from inside.
  if preview_buf and vim.api.nvim_get_current_buf() == preview_buf then
    close_preview()
    return
  end

  local curr_entry = require("mini.files").get_fs_entry()
  if not curr_entry or curr_entry.fs_type ~= "file" then
    vim.notify("No file selected", vim.log.levels.WARN)
    return
  end
  local path = curr_entry.path
  if not Snacks.image.supports_file(path) then
    vim.notify("Not a supported image: " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.WARN)
    return
  end

  -- Toggle: same entry closes it, a different one replaces it.
  if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
    close_preview()
    if preview_path == path then
      return
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  -- Open initially at a max area; the window is then resized to hug the image
  -- once its size is known (see on_update below). The float takes focus.
  local area_w = math.floor(vim.o.columns * 0.6)
  local area_h = math.floor(vim.o.lines * 0.6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = vim.fn.fnamemodify(path, ":t"),
    width = area_w,
    height = area_h,
    row = math.floor((vim.o.lines - area_h) / 2),
    col = math.floor((vim.o.columns - area_w) / 2),
  })
  preview_buf, preview_path = buf, path
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, "<cmd>close<cr>", { buffer = buf })
  end

  local function recenter(w, h)
    vim.api.nvim_win_set_config(win, {
      relative = "editor",
      row = math.max(0, math.floor((vim.o.lines - h) / 2)),
      col = math.max(0, math.floor((vim.o.columns - w) / 2)),
      width = w,
      height = h,
    })
  end

  -- Render the image into the float and shrink the window to fit it, appending
  -- a footer with filename, resolution and size (mirrors linkarzu's popup).
  --
  -- NOTE: the buffer gets `filetype = "minifiles"` (not "image") on purpose:
  -- mini.files tracks lost focus with a 1 s timer that closes the explorer
  -- when the *current* buffer's filetype isn't minifiles. The float takes
  -- focus, so its filetype must look like the explorer or the timer would
  -- close mini.files right after the preview opens. The image still renders —
  -- the Snacks placement doesn't depend on the filetype. Side effect: LazyVim
  -- injects the ft = "minifiles" keymaps into the float; preview_image()
  -- handles <leader>ip there as a toggle (see top of the function).
  local Terminal = require("snacks.image.terminal")
  Terminal.detect(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    Snacks.util.bo(buf, { filetype = "minifiles", modifiable = false, modified = false, swapfile = false })
    local sized = false
    local placement
    placement = Snacks.image.placement.new(buf, path, {
      inline = false,
      conceal = true,
      on_update = function()
        if sized or not placement:ready() then
          return
        end
        sized = true
        local loc = placement:state().loc
        local bs = setmetatable({ opts = vim.api.nvim_win_get_config(win) }, { __index = Snacks.win }):border_size()
        local meta = { vim.fn.fnamemodify(path, ":t") }
        -- Resolution via ImageMagick (already a dependency of the Snacks image
        -- module); Snacks only carries `img.info` for converted formats.
        local res = vim.fn.systemlist({ "identify", "-format", "%w %h", path })
        if res[1] and res[1]:match("^%d+ %d+$") then
          table.insert(meta, res[1]:gsub(" ", " x ") .. " px")
        end
        table.insert(meta, string.format("%.2f MB", math.max(vim.fn.getfsize(path), 0) / (1024 * 1024)))
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "  " .. table.concat(meta, "  ·  ") })
        vim.bo[buf].modifiable = false
        local w = loc.width + bs.left + bs.right
        local h = loc.height + bs.top + bs.bottom + 2
        recenter(w, h)
      end,
    })
  end)
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
  -- No longer the default explorer (see plugins/oil.lua) and its remaining
  -- keys are all `ft = "minifiles"`-scoped, so nothing would trigger lazy
  -- module-loading anymore. Load eagerly so it's still reachable via
  -- `require("mini.files").open(...)`.
  lazy = false,
  opts = {
    windows = {
      preview = true,
      width_focus = 30,
      width_preview = 30,
    },
    options = {
      -- Whether to use for editing directories
      permanent_delete = false,
      -- oil.nvim is now the default explorer (see plugins/oil.lua); mini.files
      -- stays configured and reachable via <leader>m*, just not on `gx`/netrw.
      use_as_default_explorer = false,
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
    -- Normalize null `scheme`/`matches` file-operation filters on LSP attach
    -- (see normalize_file_ops_schemes), and on already-attached clients.
    vim.api.nvim_create_autocmd("LspAttach", {
      group = group,
      callback = function(args)
        -- `vim.lsp.get_client({ id })` is the modern API but missing on this
        -- nvim build, so fall back to the (deprecated) `get_client_by_id`.
        local client = vim.lsp.get_client and vim.lsp.get_client({ id = args.data.client_id })
          or vim.lsp.get_client_by_id(args.data.client_id)
        if client then
          normalize_file_ops_schemes(client)
        end
      end,
    })
    for _, client in ipairs(vim.lsp.get_clients()) do
      normalize_file_ops_schemes(client)
    end
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
      "yy",
      function()
        -- Prefer the ad-hoc multi-selection; fall back to the entry under cursor.
        local marked = Selection.paths()
        if #marked > 0 then
          file_clipboard.copy_paths(marked)
          Selection.clear()
          Selection.redraw(vim.api.nvim_get_current_buf())
          return
        end
        local curr_entry = require("mini.files").get_fs_entry()
        if curr_entry then
          file_clipboard.copy_paths({ curr_entry.path })
        else
          vim.notify("No file or directory selected", vim.log.levels.WARN)
        end
      end,
      ft = "minifiles",
      desc = "Copy marked (or current) file/directory to clipboard",
    },

    {
      "y",
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
        file_clipboard.copy_paths(paths)
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
          require("utils.kitty").open(curr_entry.path)
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
      ft = "minifiles",
      noremap = true,
      silent = true,
      desc = "[P]Open with default app",
    },
    {
      "<leader>ip",
      function()
        preview_image()
      end,
      ft = "minifiles",
      noremap = true,
      silent = true,
      desc = "Preview image in float window",
    },
    {
      "p",
      function()
        local mini_files = require("mini.files")
        local curr_entry = mini_files.get_fs_entry()
        if not curr_entry then
          vim.notify("Failed to retrieve current entry in mini.files.", vim.log.levels.ERROR)
          return
        end
        local curr_dir = curr_entry.fs_type == "directory" and curr_entry.path
          or vim.fn.fnamemodify(curr_entry.path, ":h")
        if file_clipboard.paste_into(curr_dir) then
          mini_files.synchronize()
        end
      end,
      ft = "minifiles",
      noremap = true,
      silent = true,
      desc = "[P]Paste from clipboard",
    },
  },
}
