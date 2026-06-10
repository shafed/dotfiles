-- Update markdown-oxide daily_notes_folder to current month on startup
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local folder = "periodic/" .. os.date("%Y/%m-%b")
    local config = vim.fn.expand("~/obsidian/.moxide.toml")
    if not vim.uv.fs_stat(config) then
      return
    end
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

-- Save markdown foldings on entry
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
