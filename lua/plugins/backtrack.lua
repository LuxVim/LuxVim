local dev = require('dev')

return dev.create_plugin_spec({
    "josstei/vim-backtrack",
    config = function()
        vim.g.backtrack_split = 'botright vsplit'
        vim.g.backtrack_max_count = 10
        vim.g.backtrack_alternate_split_types = { 'easydash' }
        vim.g.backtrack_alternate_split = ''
    end,
}, { debug_name = "vim-backtrack" })