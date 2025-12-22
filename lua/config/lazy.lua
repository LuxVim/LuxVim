-- Bootstrap lazy.nvim

local luxvim_dir = vim.fn.expand("~/.local/share/LuxVim")
if vim.env.XDG_DATA_HOME then
    luxvim_dir = vim.env.XDG_DATA_HOME .. "/LuxVim"
end
local lazypath = luxvim_dir .. "/data/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Configure lazy.nvim
require("lazy").setup({
    spec = {
        { import = "plugins" },
    },
    defaults = {
        lazy = false,
        version = false,
    },
    install = { colorscheme = { "lux", "habamax" } },
    checker = { enabled = true, frequency = 86400 },
    performance = {
        cache = {
            enabled = true,
        },
        reset_packpath = true,
        rtp = {
            reset = true,
            disabled_plugins = {
                "gzip",
                "matchit",
                "matchparen",
                "netrwPlugin",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
    root = luxvim_dir .. "/data/lazy",
    lockfile = luxvim_dir .. "/lazy-lock.json",
})
