local dev = require('dev')

return dev.create_plugin_spec({
    "josstei/vim-easyenv",
    cmd = { "EasyEnvCreate", "EasyEnvLoad", "EasyEnvEdit" },
}, { debug_name = "vim-easyenv" })