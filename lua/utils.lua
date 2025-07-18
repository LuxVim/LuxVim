local M = {}

-- Search text function
function M.search_text_in_current_dir()
    local searchText = vim.fn.input('Search For Text (Current Directory): ')
    if searchText == '' then
        print('Cancelled.')
        return
    end

    local cmd
    if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
        cmd = 'findstr /S /N /I /P /C:' .. vim.fn.shellescape(searchText) .. ' *'
    else
        cmd = 'grep -rniI --exclude-dir=.git ' .. vim.fn.shellescape(searchText) .. ' .'
    end

    local results = vim.fn.systemlist(cmd)
    if #results == 0 then
        print('  - No Matches Found - ')
        return
    end

    vim.fn.setqflist({}, 'r', {lines = results, title = 'Search Results'})
    vim.cmd('copen')
end

-- FZF function
function M.fzf_open(cmd)
    vim.cmd(cmd)
end

return M