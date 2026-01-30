local dev = require('dev')

local function get_optional_theme_specs()
    local ok, picker = pcall(require, "core.theme-picker")
    if ok and picker.get_installed_specs then
        return picker.get_installed_specs()
    end
    return {}
end

local themes = {
    dev.create_plugin_spec({
        "LuxVim/nami.nvim",
        priority = 1000,
        config = function()
            require('nami').setup({
                transparent = false
            })
            local status_ok, _ = pcall(vim.cmd, 'colorscheme nami')
            if not status_ok then
                vim.api.nvim_echo({{'LuxVim: Failed to load colorscheme', 'WarningMsg'}}, true, {})
            end
        end,
    }, { debug_name = "nami.nvim" }),

    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = true,
    },

    {
        "folke/tokyonight.nvim",
        lazy = true,
    },

    {
        "morhetz/gruvbox",
        lazy = true,
    },

    {
        "dracula/vim",
        name = "dracula",
        lazy = true,
    },
}

local optional = get_optional_theme_specs()
for _, spec in ipairs(optional) do
    table.insert(themes, spec)
end

return themes
