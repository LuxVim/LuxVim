local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxlsp",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
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
        require('luxlsp').setup()
    end,
}, { debug_name = "nvim-luxlsp" })