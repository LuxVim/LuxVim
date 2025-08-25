-- Main LSP setup orchestrator
local M = {}

function M.setup()
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")
    local capabilities = require("lsp.capabilities")
    local diagnostics = require("lsp.diagnostics")
    local handlers = require("lsp.handlers")
    local keymaps = require("lsp.keymaps")
    local servers = require("lsp.servers")
    
    -- Setup Mason
    mason.setup({
        install_root_dir = vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h") .. "/data/mason",
        ui = {
            icons = {
                package_installed = "✓",
                package_pending = "➜",
                package_uninstalled = "✗"
            },
            border = "rounded",
        }
    })
    
    -- Setup diagnostics
    diagnostics.setup()
    
    -- Setup mason-lspconfig
    mason_lspconfig.setup({
        ensure_installed = servers.ensure_installed,
        automatic_enable = true, -- Replaces automatic_installation in v2.0+
    })
    
    -- Get common config
    local base_config = {
        capabilities = capabilities.get(),
        handlers = handlers.get(),
        on_attach = keymaps.on_attach,
    }
    
    -- Setup each server using vim.lsp.config 
    for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
        local config = vim.tbl_deep_extend("force", base_config, servers.get_config(server_name) or {})
        vim.lsp.config(server_name, config)
    end
    
    -- Also setup servers from ensure_installed that might not be installed yet
    for _, server_name in ipairs(servers.ensure_installed or {}) do
        local config = vim.tbl_deep_extend("force", base_config, servers.get_config(server_name) or {})
        vim.lsp.config(server_name, config)
    end
end

return M
