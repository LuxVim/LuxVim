local dev = require('dev')

return dev.create_plugin_spec({
    "neovim/nvim-lspconfig",
    dependencies = {
        "nvim-lua/plenary.nvim", -- Required for LuxLSP async operations
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("lsp").setup()
    end,
}, { debug_name = "nvim-lspconfig" })