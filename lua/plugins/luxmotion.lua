local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxmotion",
    event = "VeryLazy",
    config = function()
        require("luxmotion").setup({})
    end,
}, { debug_name = "nvim-luxmotion" })
