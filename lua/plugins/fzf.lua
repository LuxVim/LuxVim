return {
    "junegunn/fzf",
    dependencies = { "junegunn/fzf.vim" },
    cmd = { "Files", "GFiles", "Buffers", "Rg", "Lines", "History", "Commits", "Commands" },
    keys = {
        { "<leader><leader>", "<cmd>Files<CR>", desc = "Find files" },
        { "<leader>st", "<cmd>SearchText<CR>", desc = "Search text" },
    },
    config = function()
        vim.g.fzf_layout = { down = '20%' }
    end,
}