return {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false, -- Load immediately to ensure filesystem watcher works
    config = function()
        require("nvim-tree").setup({
            -- Disable netrw for better performance
            disable_netrw = true,
            hijack_netrw = true,

            -- Performance: only update cwd on DirChanged
            sync_root_with_cwd = true,
            respect_buf_cwd = true,
            update_focused_file = {
                enable = true,
                update_root = false, -- Don't change root, better performance
                ignore_list = {},
            },

            view = {
                width = 30,
                side = "left",
                preserve_window_proportions = false,
                number = false,
                relativenumber = false,
                signcolumn = "yes",
            },

            renderer = {
                group_empty = true,
                full_name = false,
                highlight_git = false, -- Disable for performance
                highlight_opened_files = "icon", -- Show which files are open
                highlight_modified = "none", -- Disable for performance
                highlight_bookmarks = "icon",
                root_folder_label = ":~:s?$?/..?",
                indent_width = 2,
                indent_markers = {
                    enable = true, -- Visual guide for folder nesting
                    inline_arrows = true,
                    icons = {
                        corner = "└",
                        edge = "│",
                        item = "│",
                        bottom = "─",
                        none = " ",
                    },
                },
                icons = {
                    show = {
                        file = true,
                        folder = true,
                        folder_arrow = true,
                        git = false, -- Disable git icons for performance
                        modified = false, -- Disable for performance
                        bookmarks = true,
                    },
                    glyphs = {
                        default = "",
                        symlink = "",
                        bookmark = "󰆤",
                        folder = {
                            arrow_closed = "",
                            arrow_open = "",
                            default = "",
                            open = "",
                            empty = "",
                            empty_open = "",
                            symlink = "",
                            symlink_open = "",
                        },
                    },
                },
            },

            filters = {
                dotfiles = false,
                git_ignored = false,
                custom = { "^.git$", "^node_modules$", "^.cache$" }, -- Filter out heavy directories
                exclude = {},
            },

            -- Disable git integration for better performance
            git = {
                enable = false,
                show_on_dirs = false,
                show_on_open_dirs = false,
                timeout = 400,
            },

            -- Optimize filesystem watcher
            filesystem_watchers = {
                enable = true,
                debounce_delay = 50,
                ignore_dirs = {
                    "node_modules",
                    ".git",
                    ".cache",
                    "target",
                    "build",
                    "dist",
                },
            },

            actions = {
                use_system_clipboard = true,
                change_dir = {
                    enable = true,
                    global = false,
                },
                open_file = {
                    quit_on_open = false,
                    resize_window = true, -- Auto-resize windows when opening files
                    window_picker = {
                        enable = true,
                        picker = "default",
                        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
                        exclude = {
                            filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
                            buftype = { "nofile", "terminal", "help" },
                        },
                    },
                },
                expand_all = {
                    max_folder_discovery = 300,
                    exclude = { ".git", "target", "build", "node_modules" },
                },
                remove_file = {
                    close_window = true,
                },
            },

            -- Disable diagnostics for performance
            diagnostics = {
                enable = false,
            },

            -- Optimize modified file tracking
            modified = {
                enable = false,
            },

            -- Performance: limit live filter
            live_filter = {
                prefix = "[FILTER]: ",
                always_show_folders = false, -- Better performance
            },

            -- Trash support for safer deletes
            trash = {
                cmd = "trash",
                require_confirm = true,
            },

            -- Optimize tab behavior
            tab = {
                sync = {
                    open = false,
                    close = false,
                },
            },

            -- Reduce UI updates
            ui = {
                confirm = {
                    remove = true,
                    trash = true,
                },
            },

            -- Logging for debugging performance issues
            log = {
                enable = false,
                truncate = true,
                types = {
                    diagnostics = false,
                    git = false,
                    profile = false,
                    watcher = false,
                },
            },
        })
    end,
}