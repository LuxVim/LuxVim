local dev = require('dev')

return dev.create_plugin_spec({
    "neovim/nvim-lspconfig",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        -- Initialize LuxLSP system for LSP management
        local luxlsp = require('luxlsp')
        luxlsp.setup({
            install_root = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "data", "luxlsp"),
        })
    end,
}, { debug_name = "nvim-lspconfig" })
