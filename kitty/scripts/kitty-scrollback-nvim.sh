#!/bin/sh
# Scrollback viewer for kitty_mod+i (see kitty.conf).
# Trailing blank lines come from two places, so both get trimmed:
#  1. kitty's @screen_scrollback stdin is the scrollback buffer plus the WHOLE
#     current screen grid, padded with blank lines down to the window height
#     -> sed strips them before nvim.
#  2. nvim_open_term() pads its terminal buffer to the window height anyway
#     -> deferred lua deletes the trailing blanks once the terminal rendered.
# TermRequest is ignored because the replayed stream contains OSC 133 shell
# integration marks: nvim's default handler sets an extmark at the terminal
# cursor row, which can be past the end of the buffer once we trim it below.
sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}' |
  KITTY_SIMPLE_SCROLLBACK=1 nvim \
    --cmd 'set eventignore=FileType,TermRequest' \
    '+nnoremap q ZQ' \
    '+call nvim_open_term(0, {})' \
    '+set nomodified nolist noswapfile number relativenumber' \
    '+$' \
    '+lua vim.defer_fn(function()
      local n = vim.api.nvim_buf_line_count(0)
      local last = n
      while last > 1 and vim.api.nvim_buf_get_lines(0, last - 1, last, true)[1]:match("^%s*$") do
        last = last - 1
      end
      if last < n then
        vim.bo.modifiable = true
        vim.api.nvim_buf_set_lines(0, last, n, true, {})
        vim.bo.modifiable = false
        vim.bo.modified = false
      end
      vim.cmd("normal! G")
    end, 100)' -
