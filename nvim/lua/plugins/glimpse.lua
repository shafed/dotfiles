local timers = {}
local last_preview = {}

local function cancel_pipeline()
  pcall(function()
    require("glimpse.previewer.model").cancel()
  end)
  pcall(function()
    require("glimpse.previewer.video").cancel()
  end)
end

local function preview_cursor(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "oil" then
    return
  end

  local oil = require("oil")
  local glimpse = require("glimpse")
  local entry = oil.get_cursor_entry()

  if not entry or entry.type ~= "file" then
    last_preview[buf] = nil
    return
  end

  local dir = oil.get_current_dir(buf)
  if not dir then
    return
  end

  local path = vim.fs.joinpath(dir, entry.name)
  if path == last_preview[buf] then
    return
  end

  -- Do not replace the current preview with an unsupported file while moving
  -- quickly through a mixed directory listing.
  if not glimpse.can_preview(path) then
    last_preview[buf] = nil
    return
  end

  last_preview[buf] = path
  cancel_pipeline()

  if require("glimpse.util").is_video(path) then
    require("glimpse.previewer.video").preview(path)
  else
    glimpse.preview(path)
  end
end

local function attach_auto_preview(buf)
  if vim.b[buf].glimpse_oil_auto_preview then
    return
  end
  vim.b[buf].glimpse_oil_auto_preview = true

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if timers[buf] then
        timers[buf]:stop()
      end

      timers[buf] = vim.defer_fn(function()
        timers[buf] = nil
        vim.schedule(function()
          preview_cursor(buf)
        end)
      end, 180)
    end,
    desc = "Auto-preview Oil entries with Glimpse",
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      if timers[buf] then
        timers[buf]:stop()
        timers[buf] = nil
      end
      last_preview[buf] = nil
    end,
  })

  -- Preview the initially selected entry too; CursorMoved is not guaranteed to
  -- fire when Oil first opens.
  vim.schedule(function()
    preview_cursor(buf)
  end)
end

return {
  "adriancmiranda/glimpse.nvim",
  ft = { "oil" },
  opts = {
    strategy = "inline",
    auto_open = false,
    integrations = {
      oil = {
        enable = true,
      },
    },
  },
  config = function(_, opts)
    require("glimpse").setup(opts)

    local group = vim.api.nvim_create_augroup("GlimpseOilAutoPreview", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "oil",
      group = group,
      callback = function(args)
        attach_auto_preview(args.buf)
      end,
    })

    -- `ft = { "oil" }` can load this config from the FileType event itself, so
    -- also attach to the already-open Oil buffer.
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype == "oil" then
      attach_auto_preview(buf)
    end
  end,
}
