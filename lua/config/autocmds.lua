-- FZF buffer settings
local fzf_group = vim.api.nvim_create_augroup('fzf_buffer', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
    group = fzf_group,
    pattern = 'fzf',
    callback = function()
        vim.opt_local.laststatus = 0
        vim.opt_local.showmode = false
        vim.opt_local.ruler = false
    end
})
vim.api.nvim_create_autocmd('BufLeave', {
    group = fzf_group,
    pattern = '*',
    callback = function()
        if vim.bo.filetype == 'fzf' then
            vim.opt.laststatus = 2
            vim.opt.showmode = true
            vim.opt.ruler = true
        end
    end
})

-- Quickfix keymap
vim.api.nvim_create_autocmd('FileType', {
    pattern = 'qf',
    callback = function()
        vim.keymap.set('n', '<CR>', '<CR>:cclose<CR>', { buffer = true })
    end
})
