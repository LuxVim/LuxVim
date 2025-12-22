local dev = require('dev')

return dev.create_plugin_spec({
    "josstei/vim-easycomment",
    cmd = "EasyComment",
    keys = {
        { "<leader>cc", "<cmd>EasyComment<CR>", mode = { "n", "v" }, desc = "Toggle comment" },
    },
}, { debug_name = "vim-easycomment" })
