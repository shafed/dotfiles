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
      "<leader>yy",
      function()
        local mini_files = require("mini.files")
        local curr_entry = mini_files.get_fs_entry()
        if curr_entry then
          local path = curr_entry.path
          local cmd = string.format("echo -n 'file://%s' | wl-copy --type text/uri-list", path)
          local result = vim.fn.system(cmd)
          if vim.v.shell_error ~= 0 then
            vim.notify("Copy failed: " .. result, vim.log.levels.ERROR)
          else
            vim.notify(vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
            vim.notify("Copied to system clipboard", vim.log.levels.INFO)
          end
        else
          vim.notify("No file or directory selected", vim.log.levels.WARN)
        end
      end,
      ft = "minifiles",
      desc = "Copy file/directory to clipboard",
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
        -- take only the first URI, strip trailing whitespace
        local uri = tostring(output):match("([^\n\r]+)")
        local source_path = uri:gsub("^file://", ""):gsub("%%(%x%x)", function(h)
          return string.char(tonumber(h, 16))
        end)
        if source_path == "" then
          vim.notify("Could not parse file path from clipboard.", vim.log.levels.WARN)
          return
        end
        local dest_path = curr_dir .. "/" .. vim.fn.fnamemodify(source_path, ":t")
        local copy_cmd = vim.fn.isdirectory(source_path) == 1 and { "cp", "-r", source_path, dest_path }
          or { "cp", source_path, dest_path }
        local result = vim.fn.system(copy_cmd)
        if vim.v.shell_error ~= 0 then
          vim.notify("Paste operation failed: " .. result, vim.log.levels.ERROR)
          return
        end
        mini_files.synchronize()
        vim.notify("Pasted successfully.", vim.log.levels.INFO)
      end,
      ft = "minifiles",
      noremap = true,
      silent = true,
      desc = "[P]Paste from clipboard",
    },
  },
}
