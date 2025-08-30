local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxlsp",
    dependencies = {
        "nvim-lua/plenary.nvim", -- For async operations and utilities
    },
    priority = 1000, -- Load before LSP config
    lazy = false, 
    cmd = {
        "LuxLsp",
        "LuxLspInstall", 
        "LuxLspUninstall",
        "LuxLspList",
    },
    keys = {
        { "<leader>L", "<cmd>LuxLsp<cr>", desc = "Toggle LuxLSP Manager" },
    },
    config = function()
        -- Simple setup - plugin handles all defaults
        require('luxlsp').setup()
    end,
}, { debug_name = "nvim-luxlsp" })