-- General settings
vim.opt.compatible = false 	     -- Enables full Vim features (modern mode)
vim.opt.relativenumber = true        -- Display line numbers relative to current line
vim.opt.number = true
vim.opt.ignorecase = true            -- remove case sensitivity for search
vim.opt.cursorline = true            -- Highlight line cursor is currently on
vim.opt.timeoutlen = 500             -- Timeout length between keymap keystrokes (in ms)
vim.opt.encoding = 'UTF-8'           -- Set encoding to UTF-8
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.swapfile = false             -- Prevent swap file creation
vim.opt.fillchars = { eob = ' ' }    -- Hide characters at the end of the buffer

-- Allow system clipboard if applicable
if vim.fn.has('clipboard') == 1 then
    vim.opt.clipboard:append('unnamedplus')
end

-- Enables 24-bit RGB (true color) support in the terminal if applicable
if vim.fn.has("termguicolors") == 1 then
    vim.opt.termguicolors = true
end

-- Enable syntax highlighting and filetype detection
vim.cmd('syntax on')
vim.cmd('filetype plugin indent on')
