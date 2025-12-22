vim.keymap.set('n', '<space>', '<nop>')
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

-- LuxTerm terminal mode mappings (normal mode handled by lazy.nvim keys)
vim.keymap.set('t', '<C-_>', '<C-\\><C-n>:LuxtermToggle<CR>', { silent = true })
vim.keymap.set('t', '<C-/>', '<C-\\><C-n>:LuxtermToggle<CR>', { silent = true })
vim.keymap.set('t', '<C-`>', '<C-\\><C-n>:LuxtermToggle<CR>', { silent = true })
vim.keymap.set('t', '<c-n>', '<c-\\><c-n>')

-- LuxTerm extended keymaps
--[[ vim.keymap.set('n', '<leader>tn', ':LuxTermNext<CR>', { silent = true })
vim.keymap.set('n', '<leader>tp', ':LuxTermPrev<CR>', { silent = true })
vim.keymap.set('n', '<leader>tl', ':LuxTermList<CR>', { silent = true })
vim.keymap.set('n', '<leader>tc', ':LuxTermClean<CR>', { silent = true })
vim.keymap.set('n', '<leader>ts', ':LuxTermSession<CR>', { silent = true }) ]]

-- LuxTerm integration commands
--[[ vim.keymap.set('n', '<leader>tr', ':LuxTermRun<CR>', { silent = true })
vim.keymap.set('n', '<leader>tb', ':LuxTermBuild<CR>', { silent = true })
vim.keymap.set('n', '<leader>tt', ':LuxTermTest<CR>', { silent = true })
vim.keymap.set('n', '<leader>tg', ':LuxTermGitStatus<CR>', { silent = true })
vim.keymap.set('n', '<leader>ta', ':LuxTermGitAdd<CR>', { silent = true })
vim.keymap.set('n', '<leader>td', ':LuxTermGitDiff<CR>', { silent = true }) ]]

-- nvim-tree
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>')

