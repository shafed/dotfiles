return {
  "ChuYanLon/telegram.nvim",
  build = "npm i",
  event = "VeryLazy",
  dependencies = {
    -- "folke/snacks.nvim",   -- optional: enables fuzzy-find chat picker
  },
  keys = {
    { "<leader>tt", "<cmd>Tg<Cr>", desc = "Toggle Telegram" },
    { "<leader>tL", "<cmd>TgLogout<Cr>", desc = "Logout Telegram" },
    { "<leader>tp", "<cmd>TgPr<Cr>", desc = "Create PR" },
    { "<leader>ti", "<cmd>TgIssue<Cr>", desc = "Manage Issues" },
  },
  cmd = {
    "Tg",
    "TgLogout",
    "TgPr",
    "TgIssue",
  },
  opts = {
    -- Default is the plugin's own directory, so `:Lazy clean`/reinstall takes
    -- the Telegram session with it. Keep the session outside of it.
    data_dir = vim.fn.stdpath("data") .. "/telegram.nvim",
    -- Credentials live in ~/.config/telegram-nvim/secret.lua, outside this repo
    -- (it is public, and ~/.config/nvim symlinks into it). Without them the
    -- plugin logs in with the api_id hardcoded in src/client.ts, which belongs
    -- to its author; Telegram then tends to terminate the session.
    -- Get your own at https://my.telegram.org -> API development tools.
    -- tdlib_path = "/path/to/libtdjson.so",         -- optional: .so (Linux) / .dylib (macOS) / .dll (Windows)
    -- proxy = "socks5://127.0.0.1:7890",             -- optional: for regions where Telegram is blocked
  },
  config = function(_, opts)
    local secret_file = vim.fn.expand("~/.config/telegram-nvim/secret.lua")
    if vim.uv.fs_stat(secret_file) then
      local ok, secret = pcall(dofile, secret_file)
      if ok and type(secret) == "table" then
        opts = vim.tbl_extend("force", opts, secret)
      else
        vim.notify("Ignoring unreadable " .. secret_file, vim.log.levels.WARN, { title = "tg" })
      end
    end
    require("telegram").setup(opts)

    -- Any failed auth poll wipes tdlib_db/tdlib_files (init.lua:830-835), so a
    -- working login is destroyed by transient failures too: a leftover server
    -- process holding the lock on td.binlog makes the new one exit, TDLib
    -- reports "A closed client cannot be reused", and the session is deleted.
    -- Esc at the phone/code prompt does the same. Stash the session across that
    -- callback; :TgLogout stays the only way to actually clear it.
    local auth = require("telegram.auth")
    local config = require("telegram.config")
    local server = require("telegram.server")
    local uv = vim.uv or vim.loop

    -- The server's SIGTERM handler calls process.exit(0) without awaiting
    -- tgClient.shutdown(), so TDLib never gets `close` and td.binlog is not
    -- flushed (src/server.ts:932-936; only SIGINT prints "Shutting down...").
    -- Both jobstop() and kill send SIGTERM, so send SIGINT first and wait.
    local function graceful_stop()
      local port = tostring(config.config.http_port)
      local listener = vim.fn.system({ "ss", "-ltnHp", "sport", "=", ":" .. port })
      local pid = listener:match("pid=(%d+)")
      if not pid then
        return
      end
      -- Only ever signal our own server, never whoever else holds the port.
      if not vim.fn.system({ "ps", "-o", "args=", "-p", pid }):find("telegram.nvim", 1, true) then
        return
      end
      vim.fn.system({ "kill", "-INT", pid })
      vim.wait(5000, function()
        return uv.fs_stat("/proc/" .. pid) == nil
      end, 100)
    end

    -- Every request is capped at --max-time 5 (lua/telegram/server.lua:76), but
    -- the first /chats walks the whole chat list through getChat one by one and
    -- takes ~17s, so curl aborts with an empty body and the plugin reports
    -- "connection failed after 4 retries" / "No chats found". The server caches
    -- the result, so only that first call is slow. Fetch these ourselves with a
    -- timeout that fits; everything else keeps the plugin's own 5s.
    local function http_get_slow(path)
      local url = "http://localhost:" .. tostring(config.config.http_port) .. path
      local result = vim.fn.system({
        "curl",
        "-s",
        "--noproxy",
        "*",
        "--fail-with-body",
        "--connect-timeout",
        "2",
        "--max-time",
        "180",
        url,
      })
      if vim.v.shell_error ~= 0 then
        vim.notify("Request to " .. path .. " failed", vim.log.levels.ERROR, { title = "tg" })
        return nil
      end
      local ok, data = pcall(vim.json.decode, result)
      if not ok then
        vim.notify("Invalid response from server", vim.log.levels.ERROR, { title = "tg" })
        return nil
      end
      if type(data) == "table" and data.error then
        vim.notify(data.error, vim.log.levels.ERROR, { title = "tg" })
        return nil
      end
      return data
    end

    server.get_chats = function()
      return http_get_slow("/chats")
    end
    server.get_groups = function()
      return http_get_slow("/groups")
    end
    server.get_saved_chat = function()
      return http_get_slow("/chats/saved")
    end

    -- snacks' matcher can only fold ASCII case, so Cyrillic chat titles match
    -- their exact case only: "жор" misses "Предмет Жоры". Opt just this picker
    -- in (which also lets a Latin-typed ";jhf" find "Жора"); file and grep
    -- pickers keep stock matching. See utils/cyrillic_matcher.lua.
    local cyrillic = require("utils.cyrillic_matcher")
    local groups = require("telegram.groups")
    local orig_show_picker = groups.show_groups_picker
    local function show_picker(on_select, custom_items)
      return cyrillic.with(function()
        return orig_show_picker(on_select, custom_items)
      end)
    end
    groups.show_groups_picker = show_picker
    -- ui.lua copied the reference at load time, and tools.lua calls it through
    -- ui, so patching only `groups` would miss every @-tool picker.
    require("telegram.ui").show_groups_picker = show_picker

    local orig_stop_server = server.stop_server
    server.stop_server = function()
      graceful_stop()
      return orig_stop_server()
    end

    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("TgGracefulStop", { clear = true }),
      callback = graceful_stop,
    })

    local orig_auth_poll = auth.auth_poll

    auth.auth_poll = function(on_done)
      orig_auth_poll(function(success)
        if success then
          return on_done(true)
        end
        local stashed = {}
        for _, name in ipairs({ "tdlib_db", "tdlib_files" }) do
          local path = config.config.data_dir .. "/" .. name
          local stash = path .. ".keep"
          if uv.fs_stat(path) then
            vim.fn.delete(stash, "rf")
            if uv.fs_rename(path, stash) then
              stashed[#stashed + 1] = { path = path, stash = stash }
            end
          end
        end
        pcall(on_done, false)
        for _, s in ipairs(stashed) do
          uv.fs_rename(s.stash, s.path)
        end
        if #stashed > 0 then
          vim.notify("Session kept, :TgLogout to clear it", vim.log.levels.INFO, { title = "tg" })
        end
      end)
    end
  end,
}
