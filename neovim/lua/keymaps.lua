-- keymaps

vim.g.mapleader = " "
local opts = { noremap = true, silent = true }

vim.api.nvim_set_keymap("n", "<Leader>ff", ":Telescope find_files<CR>", opts)
vim.api.nvim_set_keymap("n", "<Leader>fs", ":Telescope live_grep<CR>", opts)
vim.api.nvim_set_keymap("n", "<Leader>tt", ":ToggleTerm <CR>", opts)

function _G.set_terminal_keymaps()
	local opts = { buffer = 0 }
	vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
	vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
	vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
	vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
	vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
end

vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

local Terminal = require("toggleterm.terminal").Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true, direction = "float" })
local k9s = Terminal:new({ cmd = "k9s", hidden = true, direction = "float" })

function _lazygit_toggle()
	lazygit:toggle()
end

function _k9s_toggle()
	k9s:toggle()
end

vim.api.nvim_set_keymap("n", "<Leader>tg", "<cmd>lua _lazygit_toggle()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>tk", "<cmd>lua _k9s_toggle()<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "<Leader>gs", ":Neogit <CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "H", ":BufferLineCyclePrev <CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "L", ":BufferLineCycleNext <CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("v", "<Leader>c", ":OSCYank <CR>", { noremap = true, silent = true })

vim.g.copilot_no_tab_map = true
vim.api.nvim_set_keymap("i", "<C-J>", 'copilot#Accept("<CR>")', { silent = true, expr = true })

vim.cmd([[

augroup FormatAutogroup
autocmd!
autocmd BufWritePost * FormatWrite
augroup END
]])

vim.o.foldcolumn = "1"
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = -1
vim.o.foldenable = true
