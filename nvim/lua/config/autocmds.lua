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
            if vim.fn.mode():match("^[iRtsS]") then
              if idx ~= 0 then
                insert_layout = idx
              end
              return
            end
            if idx ~= 0 then
              insert_layout = idx
              vim.system({ "hyprctl", "switchxkblayout", layout_dev, "0" })
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
      save_and_force_us(true)
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    callback = function()
      save_and_force_us(false)
    end,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    callback = function()
      if insert_layout ~= 0 then
        vim.system({ "hyprctl", "switchxkblayout", layout_dev, tostring(insert_layout) })
      end
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
