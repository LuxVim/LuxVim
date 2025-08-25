local dev = require('dev')

return dev.create_plugin_spec({
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("lsp").setup()
    end,
}, { debug_name = "nvim-lspconfig" })