return {
    -- LuxVim theme
    {
        "LuxVim/lux.nvim",
        priority = 1000,
        config = function()
            require('lux').setup({
                variant = 'vesper'
            })
            local status_ok, _ = pcall(vim.cmd, 'colorscheme lux')
            if not status_ok then
                vim.api.nvim_echo({{'LuxVim: Failed to load colorscheme', 'WarningMsg'}}, true, {})
            end
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