local M = {}

local Backend = {}
Backend.__index = Backend
Backend.priority = 10

local patched = false

local function run(args, stdin)
  local out
  if stdin ~= nil then
    out = vim.fn.system(args, stdin)
  else
    out = vim.fn.system(args)
  end
  return vim.v.shell_error, out
end

local function source_window_id()
  return vim.env.KITTY_WINDOW_ID and tostring(vim.env.KITTY_WINDOW_ID) or nil
end

local function kitty_windows(match)
  local args = { "kitten", "@", "ls" }
  if match then
    vim.list_extend(args, { "--match", match })
  end

  local code, out = run(args)
  if code ~= 0 then
    return {}
  end

  local ok, data = pcall(vim.json.decode, out)
  if not ok or type(data) ~= "table" then
    return {}
  end

  local windows = {}
  for _, os_window in ipairs(data) do
    for _, tab in ipairs(os_window.tabs or {}) do
      for _, win in ipairs(tab.windows or {}) do
        win._sidekick_tab_id = tab.id
        windows[#windows + 1] = win
      end
    end
  end
  return windows
end

local function window_for_id(id)
  return kitty_windows("id:" .. tostring(id))[1]
end

local function same_tab(left, right)
  if not left or not right then
    return false
  end
  return left._sidekick_tab_id == right._sidekick_tab_id
end

local function local_sidekick_windows()
  local source = source_window_id()
  if not source then
    return {}
  end

  local windows = {}
  for _, win in ipairs(kitty_windows("var:sidekick_nvim=1")) do
    local env = win.env or {}
    if tostring(env.SIDEKICK_SOURCE_WINDOW_ID or "") == source then
      windows[#windows + 1] = win
    end
  end
  return windows
end

local function available()
  return source_window_id() ~= nil and vim.fn.executable("kitten") == 1
end

local function maybe_disable_watch()
  if #local_sidekick_windows() > 0 then
    return
  end

  local ok, Terminal = pcall(require, "sidekick.cli.terminal")
  if ok and not vim.tbl_isempty(Terminal.terminals or {}) then
    return
  end

  require("sidekick.cli.watch").disable()
end

function Backend:init()
  self.external = true
  self.priority = 10
  self.mux_session = self.mux_session or "kitty"
end

function Backend:start()
  if not available() then
    error("Sidekick kitty backend requires Neovim to run inside kitty")
  end

  local source = assert(source_window_id())

  -- Kitty only honors vsplit/hsplit placement in the splits layout.
  run({ "kitten", "@", "action", "goto_layout", "splits" })

  local cmd = {
    "kitten",
    "@",
    "launch",
    "--location=vsplit",
    "--bias",
    "49",
    "--next-to",
    "id:" .. source,
    "--add-to-session",
    ".",
    "--copy-env",
    "--cwd",
    self.cwd,
    "--var",
    "sidekick_nvim=1",
    "--var",
    "sidekick_tool=" .. self.tool.name,
    "--var",
    "sidekick_source=" .. source,
    "--env",
    "SIDEKICK_TOOL=" .. self.tool.name,
    "--env",
    "SIDEKICK_CWD=" .. self.cwd,
    "--env",
    "SIDEKICK_SOURCE_WINDOW_ID=" .. source,
  }

  if vim.v.servername ~= "" then
    vim.list_extend(cmd, { "--env", "NVIM=" .. vim.v.servername })
  end

  for key, value in pairs(self.tool.env or {}) do
    if value == false then
      vim.list_extend(cmd, { "--env", key })
    else
      vim.list_extend(cmd, { "--env", key .. "=" .. tostring(value) })
    end
  end

  vim.list_extend(cmd, self.tool.cmd)

  local code, out = run(cmd)
  if code ~= 0 then
    error("Failed to launch Sidekick CLI in kitty: " .. vim.trim(out or ""))
  end

  local id = tonumber(vim.trim(out or ""))
  if not id then
    error("kitty did not return a window id for Sidekick CLI")
  end

  self.kitty_window_id = id
  self.id = "kitty " .. id
  self.started = true
  self.external = true

  local win = window_for_id(id)
  if win then
    self.pids = win.pid and { win.pid } or nil
    self.mux_session = win.created_in_session_name or "kitty"
  end

  local Config = require("sidekick.config")
  if Config.cli.watch then
    require("sidekick.cli.watch").enable()
  end
end

function Backend:attach() end

function Backend:detach()
  vim.schedule(maybe_disable_watch)
end

function Backend:is_running()
  return self.kitty_window_id ~= nil and window_for_id(self.kitty_window_id) ~= nil
end

function Backend:is_hidden()
  return not same_tab(window_for_id(self.kitty_window_id), window_for_id(source_window_id()))
end

function Backend:is_focused()
  if not self.kitty_window_id then
    return false
  end
  return #kitty_windows("id:" .. self.kitty_window_id .. " and state:focused") > 0
end

function Backend:show(focus)
  if not self.kitty_window_id then
    return
  end

  local source = source_window_id()
  if source and self:is_hidden() then
    run({ "kitten", "@", "goto-layout", "--match", "window_id:" .. source, "splits" })
    run({
      "kitten",
      "@",
      "detach-window",
      "--match",
      "id:" .. self.kitty_window_id,
      "--target-tab",
      "window_id:" .. source,
    })
  end

  local target = focus == false and source or self.kitty_window_id
  if target then
    run({ "kitten", "@", "focus-window", "--match", "id:" .. target })
  end
end

function Backend:focus()
  self:show(true)
end

function Backend:hide()
  if not self.kitty_window_id or self:is_hidden() then
    return
  end

  run({
    "kitten",
    "@",
    "detach-window",
    "--match",
    "id:" .. self.kitty_window_id,
    "--target-tab",
    "new",
    "--stay-in-tab",
  })

  local source = source_window_id()
  if source then
    run({ "kitten", "@", "focus-window", "--match", "id:" .. source })
  end
end

function Backend:close()
  if self.kitty_window_id then
    run({ "kitten", "@", "close-window", "--match", "id:" .. self.kitty_window_id })
  end
end

function Backend:send(text)
  if not self.kitty_window_id then
    return
  end

  run({
    "kitten",
    "@",
    "send-text",
    "--match",
    "id:" .. self.kitty_window_id,
    "--bracketed-paste=auto",
    "--stdin",
  }, text)
end

function Backend:submit()
  if self.kitty_window_id then
    run({ "kitten", "@", "send-key", "--match", "id:" .. self.kitty_window_id, "enter" })
  end
end

function Backend:dump()
  if not self.kitty_window_id then
    return nil
  end

  local code, out = run({
    "kitten",
    "@",
    "get-text",
    "--match",
    "id:" .. self.kitty_window_id,
    "--extent=all",
    "--ansi",
  })
  return code == 0 and out or nil
end

function Backend:sessions()
  local Config = require("sidekick.config")
  local ret = {}

  for _, win in ipairs(local_sidekick_windows()) do
    local env = win.env or {}
    local tool = env.SIDEKICK_TOOL
    if tool and Config.cli.tools[tool] then
      ret[#ret + 1] = {
        id = "kitty " .. win.id,
        cwd = env.SIDEKICK_CWD or win.cwd,
        tool = tool,
        pids = win.pid and { win.pid } or nil,
        kitty_window_id = win.id,
        mux_session = win.created_in_session_name or "kitty",
        external = true,
        started = true,
      }
    end
  end

  return ret
end

local function normalize_opts(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  opts = vim.deepcopy(opts)
  opts.filter = opts.filter or {}
  opts.filter.name = opts.name or opts.filter.name
  return opts
end

function M.setup()
  if patched or not available() then
    return
  end
  patched = true

  local Session = require("sidekick.cli.session")
  local State = require("sidekick.cli.state")
  local Cli = require("sidekick.cli")

  Session.register("kitty", Backend)

  -- Sidekick normally chooses only terminal/tmux/zellij for a brand-new
  -- session. Seed a kitty session before its normal attach path so all the
  -- existing Sidekick context/send/prompt actions keep working unchanged.
  local original_attach = State.attach
  State.attach = function(state, opts)
    opts = opts or {}
    if not state.session then
      state = vim.tbl_extend("force", {}, state, {
        session = Session.new({ tool = state.tool.name, backend = "kitty" }),
      })
    end

    local ret, attached = original_attach(state, opts)
    if ret.session and ret.session.backend == "kitty" and opts.show and ret.session:is_running() then
      ret.session:show(opts.focus ~= false)
    end
    return ret, attached
  end

  -- Stock window actions only know how to manipulate Neovim terminal windows.
  -- A hidden kitty session is kept alive in its own tab and moved back beside
  -- the source Neovim window when shown again.
  Cli.toggle = function(opts)
    opts = normalize_opts(opts)
    State.with(function(state, attached)
      if state.session and state.session.backend == "kitty" then
        if attached or state.session:is_hidden() then
          state.session:show(opts.focus ~= false)
        else
          state.session:hide()
        end
        return
      end
      if not state.terminal then
        return
      end
      if not attached then
        state.terminal:toggle()
      end
      if state.terminal:is_open() and opts.focus ~= false then
        state.terminal:focus()
      end
    end, {
      all = opts.all,
      attach = true,
      filter = opts.filter,
    })
  end

  Cli.focus = function(opts)
    opts = normalize_opts(opts)
    State.with(function(state)
      if state.session and state.session.backend == "kitty" then
        if state.session:is_focused() then
          local source = source_window_id()
          if source then
            run({ "kitten", "@", "focus-window", "--match", "id:" .. source })
          end
        else
          state.session:focus()
        end
        return
      end
      if not state.terminal then
        return
      end
      if state.terminal:is_focused() then
        state.terminal:blur()
      else
        state.terminal:focus()
      end
    end, {
      all = opts.all,
      attach = true,
      filter = opts.filter,
      focus = false,
      show = true,
    })
  end

  Cli.hide = function(opts)
    opts = normalize_opts(opts)
    State.with(function(state)
      if state.session and state.session.backend == "kitty" then
        state.session:hide()
      elseif state.terminal then
        state.terminal:hide()
      end
    end, {
      all = opts.all,
      filter = opts.filter,
    })
  end

  Cli.close = function(opts)
    opts = normalize_opts(opts)
    State.with(function(state)
      if state.session and state.session.backend == "kitty" then
        state.session:close()
      end
      State.detach(state)
    end, {
      all = opts.all,
      filter = opts.filter,
    })
  end
end

return M
