local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxterm",
    cmd = { "LuxtermToggle", "LuxtermNew", "LuxtermList", "LuxtermNext", "LuxtermPrev" },
    keys = {
        { "<C-/>", "<cmd>LuxtermToggle<CR>", desc = "Toggle terminal" },
        { "<C-_>", "<cmd>LuxtermToggle<CR>", desc = "Toggle terminal" },
        { "<C-`>", "<cmd>LuxtermToggle<CR>", desc = "Toggle terminal" },
    },
    config = function()
        require('luxterm').setup({
            -- Manager window dimensions (0.1 to 1.0)
            manager_width = 0.8,
            manager_height = 0.8,
            
            -- Enable live preview pane
            preview_enabled = true,
            
            -- Focus new sessions when created via :LuxtermNew
            focus_on_create = false,
            
            -- Auto-hide floating windows when cursor leaves
            auto_hide = true,
            
            -- Global keybinding configuration
            keymaps = {
                toggle_manager = "<C-/>",
                next_session = "<C-k>",
                prev_session = "<C-j>",
                global_session_nav = false
            }
        })
        
    end,
}, { debug_name = "nvim-luxterm" })
