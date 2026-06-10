-- Heading-based folding for markdown and typst.
-- The foldexprs are referenced from 'foldexpr' via v:lua; the fold helpers
-- power the zj/zk/zl/z; keymaps in config/keymaps.lua.

local M = {}

-- Checks each line to see if it matches a markdown heading (#, ##, etc.):
-- it's called implicitly by Neovim's folding engine via vim.opt_local.foldexpr
function M.markdown_foldexpr()
  local lnum = vim.v.lnum
  local line = vim.fn.getline(lnum)
  local heading = line:match("^(#+)%s")
  if heading then
    local level = #heading
    if level == 1 then
      -- Special handling for H1: only the very first line or the first line
      -- after the frontmatter starts a level-1 fold
      if lnum == 1 then
        return ">1"
      else
        local frontmatter_end = vim.b.frontmatter_end
        if frontmatter_end and (lnum == frontmatter_end + 1) then
          return ">1"
        end
      end
    elseif level >= 2 and level <= 6 then
      -- Regular handling for H2-H6
      return ">" .. level
    end
  end
  return "="
end

function M.typst_foldexpr()
  local lnum = vim.v.lnum
  local line = vim.fn.getline(lnum)
  local heading = line:match("^(=+)%s")
  if heading then
    local level = #heading
    if level >= 1 and level <= 6 then
      return ">" .. level
    end
  end
  return "="
end

function M.set_markdown_folding()
  vim.opt_local.foldmethod = "expr"
  vim.opt_local.foldexpr = "v:lua.require'utils.folding'.markdown_foldexpr()"
  vim.opt_local.foldlevel = 99

  -- Detect frontmatter closing line (needed by markdown_foldexpr for H1)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local found_first = false
  local frontmatter_end = nil
  for i, line in ipairs(lines) do
    if line == "---" then
      if not found_first then
        found_first = true
      else
        frontmatter_end = i
        break
      end
    end
  end
  vim.b.frontmatter_end = frontmatter_end
end

function M.set_typst_folding()
  vim.opt_local.foldmethod = "expr"
  vim.opt_local.foldexpr = "v:lua.require'utils.folding'.typst_foldexpr()"
  vim.opt_local.foldlevel = 99
end

-- Fold all headings of a specific level. Headings are `## ` style for
-- markdown and `== ` style for typst; the pattern matches the exact level
-- because deeper headings have a marker (not whitespace) after the prefix.
local function fold_headings_of_level(level)
  local marker = vim.bo.filetype == "typst" and "=" or "#"
  -- Move to the top of the file without adding to jumplist
  vim.cmd("keepjumps normal! gg")
  local total_lines = vim.fn.line("$")
  for line = 1, total_lines do
    local line_content = vim.fn.getline(line)
    if line_content:match("^" .. string.rep(marker, level) .. "%s") then
      -- Move the cursor to the current line without adding to jumplist
      vim.cmd(string.format("keepjumps call cursor(%d, 1)", line))
      -- Fold the heading if it has a fold and is not folded already
      if vim.fn.foldlevel(line) > 0 and vim.fn.foldclosed(line) == -1 then
        vim.cmd("normal! za")
      end
    end
  end
end

function M.fold_headings(levels)
  -- Save the view to know where to jump back after folding
  local saved_view = vim.fn.winsaveview()
  for _, level in ipairs(levels) do
    fold_headings_of_level(level)
  end
  vim.cmd("nohlsearch")
  -- Restore the view to jump to where I was
  vim.fn.winrestview(saved_view)
end

return M
