local M = {}
local cache = { projects = nil, sections = {} }

function M.new()
  return setmetatable({}, { __index = M })
end

function M:get_trigger_characters()
  return { "/" }
end

function M:get_completions(ctx, resolve)
  local line = ctx.line
  local cursor = ctx.cursor[2]
  local before = line:sub(1, cursor)

  -- Match a single /something (no second slash yet)
  local query = before:match("/([^/%s<!]*)$")
  if not query then
    resolve({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local function make_items(all_sections)
    local items = {}
    for project, sections in pairs(all_sections) do
      for _, section in ipairs(sections) do
        table.insert(items, {
          label = project .. "/" .. section,
          insertText = project .. "/" .. section,
          filterText = project .. "/" .. section,
          kind = vim.lsp.protocol.CompletionItemKind.Value,
        })
      end
      table.insert(items, {
        label = project,
        insertText = project,
        filterText = project,
        kind = vim.lsp.protocol.CompletionItemKind.Module,
      })
    end
    resolve({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
  end

  -- Return from cache if all sections already loaded
  if cache.all_sections then
    make_items(cache.all_sections)
    return
  end

  -- Fetch all projects, then all their sections
  local projects = {}
  vim.fn.jobstart("~/dotfiles/scripts/todoist-export.sh --list-projects", {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, l in ipairs(data) do
        if l ~= "" then
          table.insert(projects, l)
        end
      end
    end,
    on_exit = function()
      local all_sections = {}
      local remaining = #projects
      for _, project in ipairs(projects) do
        all_sections[project] = {}
        vim.fn.jobstart("~/dotfiles/scripts/todoist-export.sh --list-sections " .. vim.fn.shellescape(project), {
          stdout_buffered = true,
          on_stdout = function(_, data)
            for _, l in ipairs(data) do
              if l ~= "" then
                table.insert(all_sections[project], l)
              end
            end
          end,
          on_exit = function()
            remaining = remaining - 1
            if remaining == 0 then
              cache.all_sections = all_sections
              vim.schedule(function()
                make_items(all_sections)
              end)
            end
          end,
        })
      end
    end,
  })
end

return M
