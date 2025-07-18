-- Set leader key
vim.keymap.set('n', '<space>', '<nop>')
vim.g.mapleader = ' '
vim.keymap.set('i', 'jk', '<ESC>')

-- File operations
vim.keymap.set('n', '<leader>fq', ':q<CR>')
vim.keymap.set('n', '<leader>fs', ':w<CR>')
vim.keymap.set('n', '<leader>FQ', ':q!<CR>')
vim.keymap.set('n', '<leader>bye', ':qa!<CR>')

-- Window navigation
vim.keymap.set('n', '<leader>wv', ':rightbelow vs new<CR>')
vim.keymap.set('n', '<leader>wh', ':rightbelow split new<CR>')
vim.keymap.set('n', '<leader>1', ':1wincmd w<CR>')
vim.keymap.set('n', '<leader>2', ':2wincmd w<CR>')
vim.keymap.set('n', '<leader>3', ':3wincmd w<CR>')
vim.keymap.set('n', '<leader>4', ':4wincmd w<CR>')
vim.keymap.set('n', '<leader>5', ':5wincmd w<CR>')
vim.keymap.set('n', '<leader>6', ':6wincmd w<CR>')

-- File/Text search
vim.keymap.set('n', '<leader><leader>', function()
    vim.cmd('Files')
end)
vim.keymap.set('n', '<leader>t', ':SearchText<CR>')

-- EasyOps
vim.keymap.set('n', '<leader>m', ':EasyOps<CR>', { silent = true })

-- TidyTerm
vim.keymap.set('n', '<C-_>', ':TidyTerm<CR>', { silent = true })
vim.keymap.set('t', '<C-_>', '<C-\\><C-n>:TidyTerm<CR>', { silent = true })
vim.keymap.set('t', '<c-n>', '<c-\\><c-n>')

-- nvim-tree
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>')

-- EasyComment
vim.keymap.set('n', '<leader>cc', ':EasyComment <CR>')
vim.keymap.set('v', '<leader>cc', ':EasyComment <CR>')