-- System-clipboard copy/paste of filesystem paths, shared by any file
-- explorer buffer (mini.files, oil) that wants a `yy`/`p`-style workflow.
-- Multi-file aware: copy_paths takes a list, paste_into resolves every
-- path found in the clipboard's uri-list.
local M = {}

-- Percent-encode a filesystem path for inclusion in a file:// URI.
-- Encodes everything except unreserved chars and "/" so the URI round-trips
-- through the clipboard and is consumed correctly by other apps (Nautilus, etc.).
local function path_to_uri(path)
  local encoded = path:gsub("[^%w%-%.%_%~/]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return "file://" .. encoded
end

local image_mime_by_ext = {
  avif = "image/avif",
  bmp = "image/bmp",
  gif = "image/gif",
  jpeg = "image/jpeg",
  jpg = "image/jpeg",
  png = "image/png",
  tif = "image/tiff",
  tiff = "image/tiff",
  webp = "image/webp",
}

local function image_mime_type(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil
  end

  return image_mime_by_ext[vim.fn.fnamemodify(path, ":e"):lower()]
end

local function read_binary_file(path)
  local fd, open_err = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return nil, open_err
  end

  local stat, stat_err = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil, stat_err
  end

  local data, read_err = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  if not data then
    return nil, read_err
  end

  return data
end

-- Run `wl-copy` asynchronously with `data` on stdin, then call `on_done(ok, err)`.
-- wl-copy daemonizes (forks and detaches) to keep serving the clipboard after
-- it returns, and the detached process keeps the inherited stdout/stderr pipe
-- open — a *blocking* wait (`vim.system(...):wait()`) never sees EOF on that
-- pipe and hangs forever. `jobstart`'s on_exit fires on the immediate child's
-- exit instead (which happens quickly), so it doesn't have this problem.
local function wl_copy_async(mime, data, on_done)
  local stderr = {}
  local jid = vim.fn.jobstart({ "wl-copy", "--type", mime }, {
    stderr_buffered = true,
    on_stderr = function(_, chunks)
      stderr = chunks
    end,
    on_exit = function(_, code)
      on_done(code == 0, table.concat(stderr, "\n"))
    end,
  })
  if jid <= 0 then
    on_done(false, "Failed to start wl-copy")
    return
  end
  vim.api.nvim_chan_send(jid, data)
  vim.fn.chanclose(jid, "stdin")
end

-- CopyQ is the primary mechanism: it can serve *different* content per MIME
-- type in one copy (image bytes here, vs. bare path/file:// URI below), which
-- a single wl-copy invocation cannot. wl-copy is only the fallback for when
-- copyq itself is unavailable or errors immediately at copy time.
local function copy_single_image_to_clipboard(path, mime, on_done)
  local data, read_err = read_binary_file(path)
  if not data then
    on_done(false, "Could not read image: " .. tostring(read_err))
    return
  end

  local uri_blob = path_to_uri(path) .. "\r\n"
  local copyq_cmd = {
    "copyq",
    "--start-server",
    "copy",
    mime,
    "-",
    "text/plain",
    path,
    "text/uri-list",
    uri_blob,
  }
  local copyq_result = vim.system(copyq_cmd, { stdin = data, text = false }):wait()
  if copyq_result.code == 0 then
    on_done(true)
    return
  end

  if vim.fn.executable("wl-copy") == 0 then
    on_done(false, copyq_result.stderr ~= "" and copyq_result.stderr or "copyq failed and wl-copy is unavailable")
    return
  end
  wl_copy_async(mime, data, on_done)
end

-- Parse a clipboard blob into a list of filesystem paths. Accepts both the plain
-- paths we now copy (one per line) and the file:// URIs that other apps or older
-- copies may put on the clipboard. Handles CRLF or LF line endings, skips blank
-- and "#" comment lines (per RFC 2483), strips the file:// scheme when present,
-- percent-decodes, and drops any trailing slash so basenames resolve correctly.
local function uri_list_to_paths(blob)
  local paths = {}
  for line in tostring(blob):gmatch("[^\r\n]+") do
    if not line:match("^%s*#") then
      local entry = line:gsub("^%s+", ""):gsub("%s+$", "")
      if entry ~= "" then
        local p = entry
        -- Only percent-decode file:// URIs; bare paths are taken verbatim so a
        -- literal "%" in a filename survives.
        if p:match("^file://") then
          p = p:gsub("^file://", ""):gsub("%%(%x%x)", function(h)
            return string.char(tonumber(h, 16))
          end)
        end
        p = p:gsub("/+$", "")
        if p ~= "" then
          table.insert(paths, p)
        end
      end
    end
  end
  return paths
end

-- Given a destination directory and a desired basename, return a path that does
-- not collide with an existing entry, appending an incrementing number ("name1",
-- "name2", ...) before the extension for files.
local function nonconflicting_dest(dir, name)
  local dest = dir .. "/" .. name
  if vim.uv.fs_stat(dest) == nil then
    return dest
  end
  local stem, ext = name:match("^(.*)(%.[^%.]+)$")
  if not stem then
    stem, ext = name, ""
  end
  local i = 1
  while true do
    local candidate = string.format("%s/%s%d%s", dir, stem, i, ext)
    if vim.uv.fs_stat(candidate) == nil then
      return candidate
    end
    i = i + 1
  end
end

-- Copy the given absolute paths to the system clipboard. A single image is
-- copied as image/* first, so browsers/Claude paste the bitmap instead of the
-- file:// URI. Everything else gets BOTH text/plain and text/uri-list
-- representations (bare paths for Claude/terminal, file:// URIs for
-- Telegram/Dolphin) via CopyQ — see copy_single_image_to_clipboard for why
-- CopyQ is primary and wl-copy only a fallback.
M.copy_paths = function(paths)
  if #paths == 0 then
    vim.notify("No files selected", vim.log.levels.WARN)
    return
  end

  local single_image_mime = #paths == 1 and image_mime_type(paths[1]) or nil
  if single_image_mime then
    copy_single_image_to_clipboard(paths[1], single_image_mime, function(ok, err)
      if ok then
        vim.notify("Copied image:\n" .. vim.fn.fnamemodify(paths[1], ":t"), vim.log.levels.INFO)
      else
        vim.notify("Image copy failed: " .. tostring(err), vim.log.levels.ERROR)
      end
    end)
    return
  end

  local uris, names = {}, {}
  for _, p in ipairs(paths) do
    table.insert(uris, path_to_uri(p))
    table.insert(names, vim.fn.fnamemodify(p, ":t"))
  end
  -- CopyQ wants uri-list lines CRLF-terminated (RFC 2483).
  local uri_blob = table.concat(uris, "\r\n") .. "\r\n"

  local function report(ok, err)
    if ok then
      vim.notify(string.format("Copied %d item(s):\n%s", #paths, table.concat(names, "\n")), vim.log.levels.INFO)
    else
      vim.notify("Copy failed: " .. tostring(err), vim.log.levels.ERROR)
    end
  end

  local copyq_output = vim.fn.system({
    "copyq",
    "--start-server",
    "copy",
    "text/plain",
    table.concat(paths, "\n"),
    "text/uri-list",
    uri_blob,
  })
  if vim.v.shell_error == 0 then
    report(true)
    return
  end

  if vim.fn.executable("wl-copy") == 0 then
    report(false, copyq_output ~= "" and copyq_output or "copyq failed and wl-copy is unavailable")
    return
  end
  wl_copy_async("text/uri-list", uri_blob, report)
end

-- Paste every file/directory referenced by the clipboard's uri-list into `dir`.
-- Multi-file aware (mirrors copy_paths). Returns true if anything was pasted,
-- so the caller knows whether to refresh its listing.
M.paste_into = function(dir)
  local output = vim.fn.system({ "wl-paste", "--no-newline", "--type", "text/uri-list" })
  if vim.v.shell_error ~= 0 or output == "" then
    vim.notify("Clipboard does not contain a valid file URI.", vim.log.levels.WARN)
    return false
  end
  local sources = uri_list_to_paths(output)
  if #sources == 0 then
    vim.notify("Could not parse any file path from clipboard.", vim.log.levels.WARN)
    return false
  end

  local pasted, errors = {}, {}
  for _, source_path in ipairs(sources) do
    local stat = vim.uv.fs_stat(source_path)
    if not stat then
      table.insert(errors, "Missing source: " .. source_path)
    else
      local dest_path = nonconflicting_dest(dir, vim.fn.fnamemodify(source_path, ":t"))
      local is_dir = stat.type == "directory"
      -- -T: treat dest as the final name (never copy-into), required for the
      -- auto-renamed destination to behave for both files and directories.
      local copy_cmd = is_dir and { "cp", "-rT", source_path, dest_path } or { "cp", "-T", source_path, dest_path }
      local result = vim.fn.system(copy_cmd)
      if vim.v.shell_error ~= 0 then
        table.insert(errors, vim.fn.fnamemodify(source_path, ":t") .. ": " .. result)
      else
        table.insert(pasted, vim.fn.fnamemodify(dest_path, ":t"))
      end
    end
  end

  if #pasted > 0 then
    vim.notify(string.format("Pasted %d item(s):\n%s", #pasted, table.concat(pasted, "\n")), vim.log.levels.INFO)
  end
  if #errors > 0 then
    vim.notify("Paste errors:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
  end
  return #pasted > 0
end

return M
