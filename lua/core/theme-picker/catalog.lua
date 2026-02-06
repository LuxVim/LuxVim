local M = {}

M.default_bundle = {
    {
        repo = "LuxVim/nami.nvim",
        name = "nami",
        description = "LuxVim default theme",
        colorscheme = "nami",
        is_default = true,
    },
    {
        repo = "catppuccin/nvim",
        name = "catppuccin",
        description = "Soothing pastel theme, 4 variants",
        colorscheme = "catppuccin",
        variants = { "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha" },
    },
    {
        repo = "folke/tokyonight.nvim",
        name = "tokyonight",
        description = "Clean dark theme, multiple styles",
        colorscheme = "tokyonight",
        variants = { "tokyonight-night", "tokyonight-storm", "tokyonight-day", "tokyonight-moon" },
    },
    {
        repo = "morhetz/gruvbox",
        name = "gruvbox",
        description = "Retro groove color scheme",
        colorscheme = "gruvbox",
    },
    {
        repo = "dracula/vim",
        name = "dracula",
        description = "Dark theme for vampires",
        colorscheme = "dracula",
    },
}

M.optional = {
    {
        repo = "rose-pine/neovim",
        name = "rose-pine",
        description = "Minimal, dark and light variants",
        colorscheme = "rose-pine",
        variants = { "rose-pine", "rose-pine-moon", "rose-pine-dawn" },
    },
    {
        repo = "sainnhe/everforest",
        name = "everforest",
        description = "Green-based, easy on eyes",
        colorscheme = "everforest",
    },
    {
        repo = "EdenEast/nightfox.nvim",
        name = "nightfox",
        description = "Soft dark theme, many variants",
        colorscheme = "nightfox",
        variants = { "nightfox", "dayfox", "dawnfox", "duskfox", "nordfox", "terafox", "carbonfox" },
    },
    {
        repo = "rebelot/kanagawa.nvim",
        name = "kanagawa",
        description = "Wave-inspired, dark theme",
        colorscheme = "kanagawa",
        variants = { "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus" },
    },
    {
        repo = "navarasu/onedark.nvim",
        name = "onedark",
        description = "Atom One Dark inspired",
        colorscheme = "onedark",
    },
    {
        repo = "nyoom-engineering/oxocarbon.nvim",
        name = "oxocarbon",
        description = "IBM Carbon design inspired",
        colorscheme = "oxocarbon",
    },
    {
        repo = "sainnhe/sonokai",
        name = "sonokai",
        description = "Monokai Pro inspired",
        colorscheme = "sonokai",
    },
    {
        repo = "marko-cerovac/material.nvim",
        name = "material",
        description = "Material design colors",
        colorscheme = "material",
    },
    {
        repo = "sainnhe/edge",
        name = "edge",
        description = "Clean and elegant",
        colorscheme = "edge",
    },
}

local _index = nil

local function get_index()
    if _index then
        return _index
    end
    _index = {}
    for _, theme in ipairs(M.default_bundle) do
        _index[theme.name] = theme
    end
    for _, theme in ipairs(M.optional) do
        _index[theme.name] = theme
    end
    return _index
end

function M.get_by_name(name)
    return get_index()[name]
end

return M
