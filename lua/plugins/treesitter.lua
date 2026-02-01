return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    priority = 900,
    config = function()
        local data_dir = vim.env.XDG_DATA_HOME or vim.fn.stdpath("data")
        local parser_install_dir = data_dir .. "/data/site"

        require("nvim-treesitter.config").setup({
            install_dir = parser_install_dir,
        })

        vim.api.nvim_create_autocmd("FileType", {
            callback = function(args)
                pcall(vim.treesitter.start, args.buf)
            end,
        })
    end,
}
