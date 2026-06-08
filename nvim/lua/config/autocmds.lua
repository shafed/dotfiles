-- Update markdown-oxide daily_notes_folder to current month on startup
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local folder = "periodic/" .. os.date("%Y/%m-%b")
    local config = "/home/shafed/obsidian/.moxide.toml"
    vim.fn.system(string.format("sed -i 's|^daily_notes_folder = .*|daily_notes_folder = \"%s\"|' %s", folder, config))
  end,
})

-- Mini.files relative numbers
-- Dedicated, more contrasty line-number groups applied only to mini.files
-- windows via window-local 'winhighlight', so global LineNr stays untouched.
local function set_minifiles_hl()
  vim.api.nvim_set_hl(0, "MiniFilesLineNr", { fg = "#a89984" })
  vim.api.nvim_set_hl(0, "MiniFilesVisual", { bg = "#504945", fg = "#d4be98" })
end
set_minifiles_hl()
-- Re-apply after colorscheme reloads, which reset custom highlights.
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_minifiles_hl })

local function set_minifiles_numbers(args)
  local win_id = args.data.win_id
  vim.wo[win_id].number = true
  vim.wo[win_id].relativenumber = true
  -- Append our remaps without clobbering mini.files' own winhighlight entries
  -- (NormalFloat/FloatTitle/CursorLine), which it manages by string-appending
  -- too. Add each only if not already present.
  local wh = vim.wo[win_id].winhighlight
  for _, entry in ipairs({ "LineNr:MiniFilesLineNr", "Visual:MiniFilesVisual" }) do
    if not wh:find(entry, 1, true) then
      wh = wh == "" and entry or (wh .. "," .. entry)
    end
  end
  vim.wo[win_id].winhighlight = wh
end

vim.api.nvim_create_autocmd("User", {
  pattern = { "MiniFilesWindowOpen", "MiniFilesWindowUpdate" },
  callback = set_minifiles_numbers,
})

-- Auto pull Obsidian Vault on startup
local function pull_obsidian_vault()
  local vault_paths = {
    vim.fn.expand("~/obsidian"),
    "/data/data/com.termux/files/home/storage/shared/obsidian",
  }

  local matched
  local function check(path)
    for _, p in ipairs(vault_paths) do
      if path:find(p, 1, true) ~= nil then
        matched = p
        return true
      end
    end
  end

  if not check(vim.fn.getcwd()) then
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and check(name) then
        break
      end
    end
  end

  if not matched then
    return
  end

  local cmd = string.format("cd %s && git pull --rebase --autostash", matched)

  vim.notify("Obsidian Vault: pulling...", vim.log.levels.INFO)

  local stdout_lines = {}
  local stderr_lines = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          table.insert(stdout_lines, line)
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          table.insert(stderr_lines, line)
        end
      end
    end,
    on_exit = function(_, code)
      local out = table.concat(stdout_lines, "\n")
      local err = table.concat(stderr_lines, "\n")
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("Obsidian Vault pull failed (code " .. code .. ")\n" .. err, vim.log.levels.WARN)
        elseif out:match("Already up to date") or err:match("Already up to date") then
          vim.notify("Obsidian Vault: already up to date", vim.log.levels.INFO)
        else
          vim.notify("Obsidian Vault pulled:\n" .. (out ~= "" and out or err), vim.log.levels.INFO)
        end
      end)
    end,
  })
end

vim.api.nvim_create_autocmd("VimEnter", {
  desc = "Auto pull Obsidian Vault on startup",
  callback = pull_obsidian_vault,
})

-- needed by mkview/loadview below: persist folds and cursor position
vim.opt.viewoptions = "folds,cursor"

vim.api.nvim_create_autocmd("BufWinLeave", {
  pattern = "*.md",
  callback = function()
    vim.cmd("mkview")
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  pattern = "*.md",
  callback = function()
    -- defer until after the FileType foldexpr has finished, otherwise
    -- loadview can restore folds before they're computed (flaky state)
    vim.schedule(function()
      pcall(vim.cmd, "loadview")
    end)
  end,
})
