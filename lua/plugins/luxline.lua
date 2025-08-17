local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxline",
    config = function()
        require('luxline').setup({
                 -- LuxTerm specific configuration
                 left_active_items_winbar_luxterm_main          = {},
                 left_inactive_items_winbar_luxterm_main        = {},
                 right_active_items_winbar_luxterm_main         = {},
                 right_inactive_items_winbar_luxterm_main       = {},

                 left_active_items_winbar_luxterm_preview       = {},
                 left_inactive_items_winbar_luxterm_preview     = {},
                 right_active_items_winbar_luxterm_preview      = {},
                 right_inactive_items_winbar_luxterm_preview    = {},

                 -- NvimTree specific configuration
                 right_active_items_winbar_NvimTree = {},
                 right_inactive_items_winbar_NvimTree = {},
                 
                 -- Terminal specific configuration
                 left_active_items_winbar_terminal = { 'windownumber'},
                 left_inactive_items_winbar_terminal = { 'windownumber'},
                 right_active_items_winbar_terminal= {},
                 right_inactive_items_winbar_terminal= {},
    
                 -- Default configuration with enhanced item variants
                 left_active_items = { 'filename:tail' , 'git:status'},
                 left_inactive_items = {},
                 right_active_items = { 'position', 'filetype:icon', 'encoding:short' },
                 right_inactive_items = { 'filename:tail' },
                 
                 -- Winbar configuration - window number left, filename right
                 winbar_enabled = true,
                 winbar_disabled_filetypes = { 'luxterm_main', 'luxterm_preview' },
                 left_active_items_winbar = { 'windownumber' },
                 left_inactive_items_winbar = { 'windownumber' },
                 right_active_items_winbar = { 'modified','filename:tail' },
                 right_inactive_items_winbar = { 'modified','filename:tail' },

                 -- Visual separators
                left_separator       = '',
                right_separator      = '',
                 
                 -- Winbar-specific separators
                 left_separator_winbar = '▶',
                 right_separator_winbar = '◀',
    
                 -- Performance settings
                 update_throttle = 20,
                 git_cache_timeout = 5000,
                 git_diff_debounce = 200,
                 git_enabled = true,
    
                 -- Theme
                 default_theme = 'default',
        })
        
    end,
}, { debug_name = "nvim-luxline" })
