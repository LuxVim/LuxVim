local dev = require('dev')

return dev.create_plugin_spec({
    "josstei/vim-easyops",
    cmd = "EasyOps",
    keys = {
        { "<leader>m", "<cmd>EasyOps<CR>", desc = "Command palette" },
    },
    config = function()
        vim.g.easyops_commands_main = {
            { label = 'Git',    command = 'menu:git' },
            { label = 'Window', command = 'menu:window' },
            { label = 'File',   command = 'menu:file' },
            { label = 'Code',   command = 'menu:code' },
            { label = 'Misc',   command = 'menu:misc' }
        }

        vim.g.easyops_commands_code = {
            { label = 'Maven', command = 'menu:springboot|maven' },
            { label = 'Vim',   command = 'menu:vim' }
        }

        vim.g.easyops_commands_misc = {
            { label = 'Create EasyEnv', command = ':EasyEnvCreate' }
        }
        vim.g.easyops_menu_misc = { commands = vim.g.easyops_commands_misc }
    end,
}, { debug_name = "vim-easyops" })