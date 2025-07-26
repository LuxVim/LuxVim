return {
    "LuxVim/vim-luxpane",
    optional = true,
    config = function()
        vim.g.luxpane_protected_bt = { 'quickfix', 'help', 'nofile', 'terminal' }
        vim.g.luxpane_protected_ft = { 'NvimTree' }
    end,
}