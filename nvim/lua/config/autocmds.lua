-- Update markdown-oxide daily_notes_folder to current month on startup
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local folder = "periodic/" .. os.date("%Y/%m-%b")
    local config = "/home/shafed/obsidian/.moxide.toml"
    vim.fn.system(string.format(
      "sed -i 's|^daily_notes_folder = .*|daily_notes_folder = \"%s\"|' %s",
      folder, config
    ))
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
