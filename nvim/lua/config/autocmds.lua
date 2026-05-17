-- Update markdown-oxide daily_notes_folder to current month on startup
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local folder = "periodic/" .. os.date("%Y/%m-%b")
    local config = "/home/shafed/obsidian/.moxide.toml"
    vim.fn.system(string.format("sed -i 's|^daily_notes_folder = .*|daily_notes_folder = \"%s\"|' %s", folder, config))
  end,
})

-- When I open markdown files I want to fold the markdown headings
-- Originally I thought about using it only for skitty-notes, but I think I want
-- it in all markdown files
--
-- if vim.g.neovim_mode == "skitty" then
vim.api.nvim_create_autocmd("BufRead", {
  pattern = "*.md",
  callback = function()
    -- Get the full path of the current file
    local file_path = vim.fn.expand("%:p")
    -- Ignore files in my daily note directory
    if file_path:match(os.getenv("HOME") .. "/github/obsidian_main/250%-daily/") then
      return
    end -- Avoid running zk multiple times for the same buffer
    if vim.b.zk_executed then
      return
    end
    vim.b.zk_executed = true -- Mark as executed
    -- Use `vim.defer_fn` to add a slight delay before executing `zk`
    vim.defer_fn(function()
      vim.cmd("normal zk")
      -- This write was disabling my inlay hints
      -- vim.cmd("silent write")
      vim.notify("Folded keymaps", vim.log.levels.INFO)
    end, 100) -- Delay in milliseconds (100ms should be enough)
  end,
})

-- Mini.files relative numbers
local function set_minifiles_numbers(args)
  local win_id = args.data.win_id
  vim.wo[win_id].number = true
  vim.wo[win_id].relativenumber = true
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
