local M = {}

local Backend = {}
Backend.__index = Backend
Backend.priority = 100

local PANE_FORMAT =
  "#{session_id}:#{pane_id}:#{pane_pid}:#{session_name}:#{?pane_current_path,#{pane_current_path},#{pane_start_path}}"

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
        windows[#windows + 1] = win
      end
    end
  end
  return windows
end

local function window_for_id(id)
  return id and kitty_windows("id:" .. tostring(id))[1] or nil
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

local function kitty_window_for_mux(mux_session)
  for _, win in ipairs(local_sidekick_windows()) do
    if (win.env or {}).SIDEKICK_TMUX_SESSION == mux_session then
      return win
    end
  end
end

local function tmux_source(mux_session)
  local code, out = run({ "tmux", "show-options", "-v", "-t", mux_session, "@sidekick_kitty_source" })
  return code == 0 and vim.trim(out or "") or nil
end

local function available()
  return source_window_id() ~= nil and vim.fn.executable("kitten") == 1 and vim.fn.executable("tmux") == 1
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

local function add_tool_cmd(cmd, tool)
  for key, value in pairs(tool.env or {}) do
    if value == false then
      vim.list_extend(cmd, { "-u", key })
    else
      vim.list_extend(cmd, { "-e", key .. "=" .. tostring(value) })
    end
  end
  vim.list_extend(cmd, tool.cmd)
end

function Backend:init()
  self.external = true
  self.priority = 100
  self.mux_session = self.mux_session or self.sid
end

function Backend:open()
  if not available() then
    error("Sidekick kitty backend requires Neovim inside kitty and tmux")
  end
  local source = assert(source_window_id())
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
    "--env",
    "SIDEKICK_TMUX_SESSION=" .. self.mux_session,
  }
  if vim.v.servername ~= "" then
    vim.list_extend(cmd, { "--env", "NVIM=" .. vim.v.servername })
  end
  vim.list_extend(cmd, { "tmux", "attach-session", "-t", self.mux_session })
  local code, out = run(cmd)
  if code ~= 0 then
    error("Failed to launch Sidekick tmux session in kitty: " .. vim.trim(out or ""))
  end
  local id = tonumber(vim.trim(out or ""))
  if not id then
    error("kitty did not return a window id for Sidekick CLI")
  end
  self.kitty_window_id = id
  local win = window_for_id(id)
  if win and win.pid then
    self.pids = vim.list_extend(vim.deepcopy(self.pids or {}), { win.pid })
  end
  local Config = require("sidekick.config")
  if Config.cli.watch then
    require("sidekick.cli.watch").enable()
  end
end

function Backend:start()
  if not available() then
    error("Sidekick kitty backend requires Neovim inside kitty and tmux")
  end
  local Tmux = require("sidekick.cli.session.tmux")
  local cmd = { "tmux", "new-session", "-dP", "-F", PANE_FORMAT, "-s", self.sid, "-c", self.cwd }
  add_tool_cmd(cmd, self.tool)
  local pane = Tmux.panes({ cmd = cmd, notify = true })[1]
  if not pane then
    error("Failed to create tmux session for Sidekick CLI")
  end
  self.id = "kitty " .. pane.pid
  self.mux_session = pane.session_name
  self.tmux_pane_id = pane.id
  self.tmux_pid = pane.pid
  self.pids = { pane.pid }
  self.started = true
  local source = assert(source_window_id())
  run({ "tmux", "set-option", "-q", "-t", self.mux_session, "@sidekick_kitty_source", source })
  run({ "tmux", "set-option", "-q", "-t", self.mux_session, "status", "off" })
  run({ "tmux", "set-option", "-q", "-t", self.mux_session, "detach-on-destroy", "on" })
  self:open()
end

function Backend:attach()
  local win = kitty_window_for_mux(self.mux_session)
  if win then
    self.kitty_window_id = win.id
  else
    self:open()
  end
end

function Backend:detach()
  vim.schedule(maybe_disable_watch)
end

function Backend:is_running()
  return window_for_id(self.kitty_window_id) ~= nil
end

function Backend:is_hidden()
  return window_for_id(self.kitty_window_id) == nil
end

function Backend:is_focused()
  if not self.kitty_window_id then
    return false
  end
  return #kitty_windows("id:" .. self.kitty_window_id .. " and state:focused") > 0
end

function Backend:show(focus)
  if self:is_hidden() then
    self:open()
  end
  local target = focus == false and source_window_id() or self.kitty_window_id
  if target then
    run({ "kitten", "@", "focus-window", "--match", "id:" .. target })
  end
end

function Backend:focus()
  self:show(true)
end

function Backend:hide()
  if self.kitty_window_id then
    run({ "kitten", "@", "close-window", "--match", "id:" .. self.kitty_window_id })
    self.kitty_window_id = nil
  end
end

function Backend:close()
  self:hide()
end

function Backend:send(text)
  require("sidekick.cli.session.tmux").send(self, text)
end

function Backend:submit()
  require("sidekick.cli.session.tmux").submit(self)
end

function Backend:dump()
  return require("sidekick.cli.session.tmux").dump(self)
end

function Backend:sessions()
  local Tmux = require("sidekick.cli.session.tmux")
  local source = source_window_id()
  local ret = {}
  for _, session in ipairs(Tmux.sessions()) do
    if tmux_source(session.mux_session) == source then
      local win = kitty_window_for_mux(session.mux_session)
      session.id = "kitty " .. session.tmux_pid
      session.kitty_window_id = win and win.id or nil
      session.external = true
      session.started = true
      ret[#ret + 1] = session
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

  -- Sidekick intentionally keeps a bare "start new tool" entry beside every
  -- external session. For this backend that defeats automatic reopen: after
  -- C-. the persistent tmux session and a duplicate new tool both match. A
  -- kitty session in the current cwd is the resumable form of that same entry.
  local original_get = State.get
  State.get = function(filter)
    local states = original_get(filter)
    local kitty_sids = {}
    for _, state in ipairs(states) do
      if state.session and state.session.backend == "kitty" then
        kitty_sids[state.session.sid] = true
      end
    end
    return vim.tbl_filter(function(state)
      return state.session ~= nil or not kitty_sids[Session.sid({ tool = state.tool.name })]
    end, states)
  end

  -- New sessions use tmux for persistence but are presented in a native kitty
  -- split. Detached tmux sessions discovered by Backend:sessions() keep all
  -- normal Sidekick context, prompt, send and selection behavior.
  local original_attach = State.attach
  State.attach = function(state, opts)
    opts = opts or {}
    if not state.session then
      state = vim.tbl_extend("force", {}, state, {
        session = Session.new({ tool = state.tool.name, backend = "kitty" }),
      })
    elseif state.session.backend == "tmux" then
      local source = assert(source_window_id())
      run({ "tmux", "set-option", "-q", "-t", state.session.mux_session, "@sidekick_kitty_source", source })
      state = vim.tbl_extend("force", {}, state, {
        session = Session.new(vim.tbl_extend("force", {}, state.session, {
          backend = "kitty",
          external = true,
          id = "kitty " .. state.session.tmux_pid,
        })),
      })
    end
    local ret, attached = original_attach(state, opts)
    if ret.session and ret.session.backend == "kitty" and opts.show and ret.session:is_running() then
      ret.session:show(opts.focus ~= false)
    end
    return ret, attached
  end

  Cli.toggle = function(opts)
    opts = normalize_opts(opts)
    State.with(function(state, attached)
      if state.session and state.session.backend == "kitty" then
        if attached then
          state.session:show(opts.focus ~= false)
        else
          state.session:hide()
          State.detach(state)
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
    end, { all = opts.all, attach = true, filter = opts.filter })
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
    end, { all = opts.all, attach = true, filter = opts.filter, focus = false, show = true })
  end

  local function hide(state)
    if state.session and state.session.backend == "kitty" then
      state.session:hide()
      State.detach(state)
    elseif state.terminal then
      state.terminal:hide()
    end
  end

  Cli.hide = function(opts)
    opts = normalize_opts(opts)
    State.with(hide, { all = opts.all, filter = opts.filter })
  end

  Cli.close = function(opts)
    opts = normalize_opts(opts)
    State.with(function(state)
      if state.session and state.session.backend == "kitty" then
        state.session:hide()
      end
      State.detach(state)
    end, { all = opts.all, filter = opts.filter })
  end
end

return M
