local map = vim.keymap.set
local opts = { noremap = true, silent = true }

vim.g.mapleader = " "

map("i", "jk", "<ESC>",opts)
map("n", "<leader>s", "<cmd>w<cr>",opts)
map("n", "<leader>w", "<cmd>wq<cr>",opts)
map("n", "<leader>q", "<cmd>qa<cr>",opts)

map("n", "ff", "<cmd>Telescope find_files<cr>", {})
map("n", "fg", "<cmd>Telescope live_grep<cr>", {})
map("n", "fb", "<cmd>Telescope buffers<cr>" , {})
