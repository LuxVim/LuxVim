return {
    "junegunn/fzf",
    dependencies = { "junegunn/fzf.vim" },
    config = function()
        vim.g.fzf_layout = { down = '20%' }
    end,
}