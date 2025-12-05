local dev = require('dev')

return {
    -- LuxWave - Ocean waves at sunset theme (matches Kitty terminal)
    dev.create_plugin_spec({
        "your-username/luxwave.nvim",
        priority = 1000,
        config = function()
            -- Use vim.schedule to ensure plugin is fully loaded
            vim.schedule(function()
                local status_ok, luxwave = pcall(require, 'luxwave')
                if status_ok then
                    luxwave.setup({
                        transparent = false,
                        dim_inactive = false,
                        styles = {
                            comments = { italic = true },
                            keywords = { bold = false },
                            functions = { bold = false },
                        },
                    })
                    local color_status, _ = pcall(vim.cmd, 'colorscheme luxwave')
                    if not color_status then
                        vim.api.nvim_echo({{'LuxVim: Failed to load luxwave colorscheme', 'WarningMsg'}}, true, {})
                    end
                else
                    vim.api.nvim_echo({{'LuxVim: Failed to load luxwave module: ' .. tostring(luxwave), 'ErrorMsg'}}, true, {})
                end
            end)
        end,
    }, { debug_name = "luxwave.nvim" }),

    -- LuxVim theme (alternative)
    {
        "LuxVim/lux.nvim",
        lazy = true,
        config = function()
            require('lux').setup({
                variant = 'vesper',
                transparent = false
            })
        end,
    },

    -- Custom themes
    {
        "josstei/voidpulse.nvim",
        lazy = true,
    },

    -- Vim-compatible themes
    {
        "dracula/vim",
        name = "dracula",
        lazy = true,
    },

    {
        "morhetz/gruvbox",
        lazy = true,
    },

    {
        "arcticicestudio/nord-vim",
        lazy = true,
    },

    {
        "altercation/vim-colors-solarized",
        lazy = true,
    },

    {
        "crusoexia/vim-monokai",
        lazy = true,
    },

    {
        "sainnhe/everforest",
        lazy = true,
    },

    {
        "sainnhe/sonokai",
        lazy = true,
    },

    {
        "NLKNguyen/papercolor-theme",
        lazy = true,
    },

    {
        "joshdick/onedark.vim",
        lazy = true,
    },

    {
        "tomasr/molokai",
        lazy = true,
    },

    {
        "mhartington/oceanic-next",
        lazy = true,
    },

    -- Neovim-only themes (conditional loading)
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "folke/tokyonight.nvim",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "rebelot/kanagawa.nvim",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "navarasu/onedark.nvim",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "EdenEast/nightfox.nvim",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "rose-pine/neovim",
        name = "rose-pine",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "tanvirtin/monokai.nvim",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "nyoom-engineering/oxocarbon.nvim",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "sainnhe/edge",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },

    {
        "marko-cerovac/material.nvim",
        lazy = true,
        cond = vim.fn.has('nvim') == 1,
    },
}
