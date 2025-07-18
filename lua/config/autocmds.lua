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

-- NERDTree handler
local nerdtree_group = vim.api.nvim_create_augroup('NerdTreeHandler', { clear = true })
vim.api.nvim_create_autocmd('TabNew', {
    group = nerdtree_group,
    pattern = '*',
    callback = function()
        -- Don't auto-open NERDTree if luxdash is active
        local current_ft = vim.bo.filetype
        if current_ft ~= 'luxdash' then
            vim.cmd('NERDTree | wincmd p')
        end
    end
})

-- Prevent luxdash from closing when NERDTree toggles
vim.api.nvim_create_autocmd({'BufEnter', 'WinEnter'}, {
    group = nerdtree_group,
    pattern = '*',
    callback = function()
        -- If we're entering a non-luxdash buffer and luxdash exists, resize it
        local current_ft = vim.bo.filetype
        if current_ft ~= 'luxdash' then
            for _, winnr in ipairs(vim.api.nvim_list_wins()) do
                local bufnr = vim.api.nvim_win_get_buf(winnr)
                if vim.api.nvim_buf_get_option(bufnr, 'filetype') == 'luxdash' then
                    local current_win = vim.api.nvim_get_current_win()
                    vim.api.nvim_set_current_win(winnr)
                    if pcall(require, 'luxdash.core') then
                        require('luxdash.core').resize()
                    end
                    vim.api.nvim_set_current_win(current_win)
                    break
                end
            end
        end
    end
})