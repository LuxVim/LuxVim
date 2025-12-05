local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxdash",
    config = function()
        require("luxdash").setup({
            name = 'LuxVim',
            logo_color = {
                row_gradient = {
                    start = '#ff7801',
                    bottom = '#db2dee'
                }
            },
            
           
            performance = {
                debounce_resize = 100,  -- Debounce resize events by 100ms
                lazy_render = true,     -- Only render when visible
                cache_logo = true       -- Cache ASCII logo rendering
            },
            
            sections = {
                main = {
                    type = 'logo',
                    config = {
                        show_title = false,
                        show_underline = false,
                        alignment = {
                            horizontal = 'center',
                            vertical = 'center'
                        }
                    }
                },
                bottom = {
                    {
                        id = 'actions',
                        type = 'menu',
                        title = '⚡ Actions',
                        config = {
                            show_title = true,
                            show_underline = true,
<<<<<<< HEAD
                            menu_items = { 'newfile', 'fzf', 'closelux' },
=======
                            menu_items = { 'newfile','fzf', 'closelux' },
>>>>>>> eb0477f7ec438648b7a7822d493ed5d4f9471c28
                            alignment = {
                                horizontal = 'center',
                                vertical = 'top',
                                title_horizontal = 'center',
                                content_horizontal = 'center'
                            },
                            padding = { left = 2, right = 2 }
                        }
                    },
                    {
                        id = 'recent',
                        type = 'recent_files',
                        title = '📁 Recent Files',
                        config = {
                            show_title = true,
                            show_underline = true,
                            max_files = 8,
                            alignment = {
                                horizontal = 'center',
                                vertical = 'top',
                                title_horizontal = 'center',
                                content_horizontal = 'left'
                            },
                            padding = { left = 2, right = 2 }
                        }
                    },
                    {
                        id = 'git',
                        type = 'git_status',
                        title = '🌿 Git Status',
                        config = {
                            show_title = true,
                            show_underline = true,
                            alignment = {
                                horizontal = 'center',
                                vertical = 'top',
                                title_horizontal = 'center',
                                content_horizontal = 'left'
                            },
                            padding = { left = 2, right = 2 }
                        }
                    }
                }
            },
            
            -- Layout configuration
            layout_config = {
                main_height_ratio = 0.8,
                bottom_sections_equal_width = true,
                section_spacing = 4
            },
            
            logo = {
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⣿⣧⠀⠀⠀⠈⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⣿⣧⠀⠀⠀⠘⣿⣿⣿⣿⣿⠁⠀⠀⠀⣾⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣆⠀⠀⠀⠹⣿⣿⣿⠃⠀⠀⠀⣼⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⣤⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠹⣿⠃⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀⠉⠀⠀⠀⣠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠉⠉⠛⠻⠿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⠿⠟⠛⠉⡉⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀⢠⣿⣿⣿⣿⣿⡿⠀⠀⠀⢀⣴⠾⠋⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⢀⣴⡾⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣷⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⡿⠛⠉⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠉⠛⢿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣾⠛⠁⠈⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣾⠟⠁⠀⠀⠀⠀⠀⢿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⡾⠟⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
                '⣤⣤⠀⠀⠀⢀⣠⣼⡟⠁⠀⠀⣤⣤⠀⣤⣤⡄⠀⠀⣤⣤⡄⣤⣤⡄⠀⠀⠀⣤⣤⡄⢠⣤⡄⠀⢠⣤⣤⡀⠀⠀⢀⣤⣤⡄',
                '⣿⣿⠀⣠⠾⠋⢹⣿⡇⠀⠀⠀⣿⣿⠀⠈⣿⣿⡄⣼⣿⠟⠀⠘⣿⣿⠀⠀⢀⣿⣿⠀⢸⣿⡇⠀⢸⣿⣿⣷⠀⠀⣾⣿⣿⡇',
                '⣿⣿⠈⠀⠀⠀⢸⣿⡇⠀⠀⠀⣿⣿⠀⠀⠈⣿⣿⣿⠟⠀⠀⠀⢻⣿⡆⠀⣾⣿⠃⠀⢸⣿⡇⠀⢸⣿⡿⣿⣆⣰⣿⢿⣿⡇',
                '⣿⣿⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⣿⣿⠀⠀⢀⣿⣿⣿⣧⠀⠀⠀⠀⣿⣿⢠⣿⡿⠀⠀⢸⣿⡇⠀⢸⣿⡇⢿⣿⣿⡿⢸⣿⡇',
                '⣿⣿⣶⣶⣶⡆⠈⣿⣿⣤⣤⣾⣿⠏⠀⢠⣿⣿⠁⢻⣿⣷⠀⠀⠀⢹⣿⣿⣿⠁⠀⠀⢸⣿⡇⠀⢸⣿⡇⠈⣿⣿⠀⢸⣿⡇',
                '⠛⠛⠛⠛⠛⠃⠀⠀⠙⠻⠿⠛⠉⠀⠀⠛⠛⠁⠀⠀⠛⠛⠓⠀⠀⠀⠛⠛⠛⠀⠀⠀⠘⠛⠓⠀⠘⠛⠃⠀⠀⠀⠀⠘⠛⠃',
            },
            
        })
    end,
}, { debug_name = "nvim-luxdash" })
