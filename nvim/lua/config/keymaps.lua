-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "kj", "<ESC>", { desc = "[P]Exit insert mode with kj" })

vim.keymap.set({ "n", "v" }, "H", "^", { desc = "[P]Go to the beginning line" })
vim.keymap.set({ "n", "v" }, "L", "$", { desc = "[P]go to the end of the line" })
