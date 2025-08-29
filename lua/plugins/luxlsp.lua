local dev = require('dev')

return dev.create_plugin_spec({
    "LuxVim/nvim-luxlsp",
    dependencies = {
        "nvim-lua/plenary.nvim", -- For async operations and utilities
    },
    priority = 1000, -- Load before LSP config
    lazy = false, 
    cmd = {
        "LuxLsp",
        "LuxLspInstall", 
        "LuxLspUninstall",
        "LuxLspList",
    },
    keys = {
        { "<leader>L", "<cmd>LuxLsp<cr>", desc = "Toggle LuxLSP Manager" },
    },
    config = function()
        local success, luxlsp = pcall(require, 'luxlsp')
        if not success then
            vim.notify("Failed to load nvim-luxlsp: " .. tostring(luxlsp), vim.log.levels.ERROR)
            return
        end
        
        local setup_success = pcall(luxlsp.setup, {
            window = {
                width = 0.8,
                height = 0.8,
                border = "rounded",
                title = " LuxLSP Manager ",
            },
            install_root = vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h") .. "/data/luxlsp",
            search = {
                placeholder = "Search language servers...",
                max_results = 20,
            },
            keymaps = {
                toggle = "<leader>L",
                install = "<CR>",
                uninstall = "d", 
                quit = { "<Esc>", "q" },
                refresh = "r",
                help = "?",
            },
            ui = {
                icons = {
                    installed = "✓",
                    not_installed = "○", 
                    installing = "⟳",
                    error = "✗",
                    running = "●",
                },
                colors = {
                    installed = "DiagnosticOk",
                    not_installed = "DiagnosticHint",
                    installing = "DiagnosticWarn", 
                    error = "DiagnosticError",
                    running = "DiagnosticInfo",
                }
            }
        })
        
        if not setup_success then
            vim.notify("Failed to setup nvim-luxlsp", vim.log.levels.ERROR)
        end
    end,
}, { debug_name = "nvim-luxlsp" })
