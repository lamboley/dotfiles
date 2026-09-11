local map = vim.keymap.set
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Save current file
map("n", "<leader>w", ":w<cr>", { desc = "Save file", remap = true })
map("i", "<C-s>", "<Cmd>write<CR>")

-- Quit Neovim
map("n", "<leader>q", ":q<cr>", { desc = "Quit Neovim", remap = true })

-- Select all
map("n", "<C-a>", "gg<S-v>G", { desc = "Select all", noremap = true })

-- Indenting
map("v", "<", "<gv", { desc = "Indenting", silent = true, noremap = true })
map("v", ">", ">gv", { desc = "Indenting", silent = true, noremap = true })

-- New tab
map("n", "te", ":tabedit")

-- Split window
map("n", "<leader>sh", ":split<Return><C-w>w", { desc = "splits horizontal", noremap = true })
map("n", "<leader>sv", ":vsplit<Return><C-w>w", { desc = "Split vertical", noremap = true })

-- Resize window
map("n", "<C-Up>", ":resize -3<CR>")
map("n", "<C-Down>", ":resize +3<CR>")
map("n", "<C-Left>", ":vertical resize -3<CR>")
map("n", "<C-Right>", ":vertical resize +3<CR>")

-- Barbar
map("n", "<Tab>", ":BufferNext<CR>", { desc = "Move to next tab", noremap = true })
map("n", "<S-Tab>", ":BufferPrevious<CR>", { desc = "Move to previous tab", noremap = true })
map("n", "<leader>x", ":BufferClose<CR>", { desc = "Buffer close", noremap = true })

map("n", "<C-u>", "<C-u>zz", { desc = "Half page up" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down" })

-- Claude
for _, dir in ipairs({ "Left", "Down", "Up", "Right" }) do
  --map("t", "<C-" .. dir .. ">", "<C-\\><C-n><C-w><" .. dir .. ">", { desc = "Window " .. dir .. " from terminal" })
  map("t", "<C-w><" .. dir .. ">", "<C-\\><C-n><C-w><" .. dir .. ">", { desc = "Window " .. dir .. " from terminal" })
end
