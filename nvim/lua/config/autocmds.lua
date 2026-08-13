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

-- RU layout: normal mode is always US; entering insert restores whatever
-- layout was active when insert was last left. Drives the same kanata virtual
-- device as scripts/symlayout-watch.sh (per-device switching, so physical
-- keyboards are untouched). The langmap in options.lua covers keys typed in
-- the short window before the async hyprctl call lands.
if vim.fn.executable("hyprctl") == 1 then
  local layout_dev = "kanata"
  local insert_layout = 0

  local function switch_layout(layout)
    vim.system({ "hyprctl", "switchxkblayout", layout_dev, tostring(layout) })
  end

  -- Snacks picker: its input is a prompt like ':' cmdline, so while a picker
  -- is open the layout must stay US — a picker opened from insert mode would
  -- otherwise trigger InsertEnter and restore RU. The picker never touches
  -- insert_layout (the InsertEnter/InsertLeave guards below), so on close the
  -- user is in normal mode (US) and re-entering insert restores RU from
  -- insert_layout — no layout restore on close needed.
  local picker_active = false

  local function has_active_picker()
    local ok, picker = pcall(require, "snacks.picker")
    return ok and #picker.get() > 0
  end

  local function is_layout_typing_mode()
    local mode = vim.fn.mode()
    if mode:match("^[iRtsS]") then
      return true
    end

    -- Search should use the layout remembered from insert mode. Treat its
    -- command line as a typing mode so a late InsertLeave query cannot force
    -- US after CmdlineEnter has restored RU.
    if mode == "c" then
      local cmdtype = vim.fn.getcmdtype()
      return cmdtype == "/" or cmdtype == "?"
    end

    return false
  end

  -- overwrite_us: whether an active US layout may overwrite a remembered RU
  -- one. True when leaving insert (restore what the user last typed in);
  -- false for cmdline, where US is the norm (":w") and shouldn't clobber the
  -- layout remembered from insert.
  local function save_and_force_us(overwrite_us)
    vim.system({ "hyprctl", "-j", "devices" }, { text = true }, function(out)
      if out.code ~= 0 then
        return
      end
      local ok, devices = pcall(vim.json.decode, out.stdout)
      if not ok then
        return
      end
      for _, kb in ipairs(devices.keyboards or {}) do
        if kb.name == layout_dev then
          local idx = kb.active_layout_index or 0
          vim.schedule(function()
            -- By the time the async query lands we may be back in a typing
            -- mode: bullets.vim's <CR> runs an expression register (an i:c:i
            -- blip that fires CmdlineLeave), and a fast Esc-i does the same
            -- for InsertLeave. Forcing US then would flip the layout right
            -- under the user's fingers — keep it, only refresh the memory.
            if is_layout_typing_mode() then
              if idx ~= 0 then
                insert_layout = idx
              end
              return
            end
            if idx ~= 0 then
              insert_layout = idx
              switch_layout(0)
            elseif overwrite_us then
              insert_layout = 0
            end
          end)
          return
        end
      end
    end)
  end

  vim.api.nvim_create_autocmd({ "VimEnter", "InsertLeave" }, {
    callback = function()
      -- While a picker is open, forcing US must not clobber insert_layout:
      -- the picker input is US regardless, and restoring insert_layout on
      -- return is what puts the user back in RU after a picker opened from
      -- insert mode.
      if has_active_picker() then
        switch_layout(0)
        return
      end
      save_and_force_us(true)
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    callback = function()
      save_and_force_us(false)
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineEnter", {
    callback = function()
      local cmdtype = vim.fn.getcmdtype()
      if cmdtype == ":" then
        switch_layout(0)
      elseif cmdtype == "/" or cmdtype == "?" then
        switch_layout(insert_layout)
      end
    end,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    callback = function()
      -- A picker input starts insert mode; keep it US like the ':' cmdline
      -- instead of restoring the RU remembered from the last insert.
      if has_active_picker() then
        switch_layout(0)
        return
      end
      if insert_layout ~= 0 then
        switch_layout(insert_layout)
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinEnter", {
    callback = function()
      -- Entering a picker: force US. Guarded so re-focusing between picker
      -- windows (input/list/preview) doesn't re-trigger.
      if has_active_picker() and not picker_active then
        picker_active = true
        switch_layout(0)
        return
      end
      -- Deferred close detection: picker:close() clears M._active only after
      -- focus already returned to the main window, so evaluate on the next
      -- loop tick. No layout change on close — normal mode is US anyway and
      -- insert_layout was never touched by the picker.
      vim.schedule(function()
        if picker_active and not has_active_picker() then
          picker_active = false
        end
      end)
    end,
  })
end

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
    -- The fold keymaps run `edit!`, which re-triggers BufWinEnter. They set
    -- vim.b.skip_loadview so loadview doesn't fire afterwards and clobber the
    -- folds they just applied (loadview is deferred, so it would run last).
    if vim.b.skip_loadview then
      vim.b.skip_loadview = false
      return
    end
    -- defer until after the FileType foldexpr has finished, otherwise
    -- loadview can restore folds before they're computed (flaky state)
    vim.schedule(function()
      pcall(vim.cmd, "loadview")
    end)
  end,
})
