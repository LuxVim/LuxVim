local dev = require('dev')

return dev.create_plugin_spec({
    "neovim/nvim-lspconfig",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
    end,
}, { debug_name = "nvim-lspconfig" })
