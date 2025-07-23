return {
    -- Editor enhancement plugins
     {
         "LuxVim/nvim-luxline",
         config = function()
             require('luxline').setup({
                 -- NvimTree specific configuration  
                 left_active_items_NvimTree = { 'windownumber' },
                 left_inactive_items_NvimTree = { 'windownumber' },
                 right_active_items_NvimTree = {},
                 right_inactive_items_NvimTree = {},
    
                 -- Terminal specific configuration
                 left_active_items_tidyterm = { 'windownumber', 'git:branch' },
                 left_inactive_items_tidyterm = { 'windownumber' },
                 right_active_items_tidyterm = { 'filetype' },
                 right_inactive_items_tidyterm = { 'filetype' },
    
                 -- Luxdash specific configuration
                 left_active_items_luxdash = { 'windownumber', 'git:branch' },
                 left_inactive_items_luxdash = { 'windownumber' },
                 right_active_items_luxdash = {},
                 right_inactive_items_luxdash = {},
    
                 -- Default configuration with enhanced item variants
                 left_active_items = { 'windownumber', 'git:status', 'filename:tail', 'modified:icon' },
                 left_inactive_items = { 'windownumber' },
                 right_active_items = { 'position', 'filetype:icon', 'encoding:short' },
                 right_inactive_items = { 'filename:tail' },
                 
                 -- Winbar configuration - window number left, filename right
                 winbar_enabled = true,
                 left_active_items_winbar = { 'windownumber' },
                 left_inactive_items_winbar = { 'windownumber' },
                 right_active_items_winbar = { 'filename:tail' },
                 right_inactive_items_winbar = { 'filename:tail' },
    
                 -- Visual separators
                 left_separator = '',
                 right_separator = '',
    
                 -- Performance settings
                 update_throttle = 20,
                 git_cache_timeout = 5000,
                 git_diff_debounce = 200,
                 git_enabled = true,
    
                 -- Theme
                 default_theme = 'default',
             })
         end,
     },

    {
        "josstei/vim-easycomment",
    },

    {
        "josstei/vim-easyops",
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
    },

    {
        "josstei/vim-easyenv",
    },

    {
        "LuxVim/nvim-luxterm",
        config = function()
            require('luxterm').setup({
                autostart = false,
                position = 'bottom',
                size = 20,
                filetype = 'sh',
                session_persistence = true,
                floating_window = true,
                floating_width = 0.8,
                floating_height = 0.6,
                floating_border = 'rounded',
                smart_position = true,
                focus_on_toggle = true,
                remember_size = true,
                statusline_integration = true,
                history_size = 100,
                shell_integration = true,
                auto_cd = true,
                terminal_title = true,
                quick_commands = {}
            })
            
        end,
    },

    {
        "josstei/vim-backtrack",
        config = function()
            vim.g.backtrack_split = 'botright vsplit'
            vim.g.backtrack_max_count = 10
            vim.g.backtrack_alternate_split_types = { 'easydash' }
            vim.g.backtrack_alternate_split = ''
        end,
    },
}
