return {
    -- File management and fuzzy finding
    {
        "junegunn/fzf",
        dependencies = { "junegunn/fzf.vim" },
        config = function()
            vim.g.fzf_layout = { down = '20%' }
        end,
    },

    -- File explorer
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("nvim-tree").setup({
                view = {
                    width = 30,
                    side = "left",
                },
                renderer = {
                    group_empty = true,
                    icons = {
                        glyphs = {
                            default = "",
                            symlink = "",
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
                },
                git = {
                    enable = true,
                },
                actions = {
                    open_file = {
                        quit_on_open = false,
                    },
                },
            })
        end,
    },

    {
        "LuxVim/nvim-luxmotion",
        config = function()
            require("luxmotion").setup({
                cursor = {
                    duration = 10,
                    easing = "ease-out",
                    enabled = true,
                },
                scroll = {
                    duration = 380,
                    easing = "ease-out", 
                    enabled = true,
                },
                keymaps = {
                    cursor = true,
                    scroll = true,
                    experimental = false,
                },
            })
        end,
    },
}
