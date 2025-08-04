local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxmotion",
    config = function()
        require("luxmotion").setup({
            cursor = {
                duration = 250,
                easing = "ease-out",
                enabled = true,
            },
            scroll = {
                duration = 400,
                easing = "ease-out", 
                enabled = true,
            },
            keymaps = {
                cursor = true,
                scroll = true,
                experimental = true,
            },
            performance = {
                enabled = false,  -- Can enable for testing
                disable_syntax_during_scroll = true,
                ignore_events = {'WinScrolled', 'CursorMoved', 'CursorMovedI'},
                reduce_frame_rate = false,
                frame_rate_threshold = 30,
                auto_enable_on_large_files = true,
                large_file_threshold = 5000,
            },
        })
    end,
}, { debug_name = "nvim-luxmotion" })
