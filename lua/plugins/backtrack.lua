return {
    "josstei/vim-backtrack",
    config = function()
        vim.g.backtrack_split = 'botright vsplit'
        vim.g.backtrack_max_count = 10
        vim.g.backtrack_alternate_split_types = { 'easydash' }
        vim.g.backtrack_alternate_split = ''
    end,
}