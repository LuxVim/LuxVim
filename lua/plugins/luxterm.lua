local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxterm",
    config = function()
        require('luxterm').setup({
            -- Manager window settings
            manager_width = 0.8,
            manager_height = 0.8,
            border = "rounded",
            left_pane_width = 0.3,
            
            -- Preview settings
            preview_enabled = true,
            preview_max_lines = 1000,
            preview_refresh_ms = 2000,
            
            -- Session behavior
            auto_close = false,
            focus_on_create = false,
            default_shell = nil,
            session_name_template = "Terminal %d",
            
            -- Performance options
            cache_enabled = true,
            lazy_render = true,
            
            -- Keymaps for manager window
            keymaps = {
                new_session = "n",
                close_manager = "<Esc>",
                delete_session = "d",
                rename_session = "r",
                next_session = "<C-Right>",
                prev_session = "<C-Left>",
                select_session_1 = "1",
                select_session_2 = "2",
                select_session_3 = "3",
                select_session_4 = "4",
                select_session_5 = "5",
                move_down = "j",
                move_up = "k",
            },
            
            -- Highlight groups
            highlights = {
                active_session = "PmenuSel",
                inactive_session = "Pmenu",
                border = "FloatBorder",
                preview_border = "FloatBorder"
            }
        })
        
    end,
}, { debug_name = "nvim-luxterm" })
