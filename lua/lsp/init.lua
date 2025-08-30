-- Main LSP setup orchestrator
local M = {}

function M.setup()
    -- Setup diagnostics and handlers
    local diagnostics = require("lsp.diagnostics")
    diagnostics.setup()
    
    -- Setup lazy-loading autocmds for available LSP servers
    M.setup_available_servers()
end

-- Setup lazy-loading autocmds for available LSP servers (does not start servers immediately)
function M.setup_available_servers()
    local capabilities = require("lsp.capabilities")
    local keymaps = require("lsp.keymaps")
    local handlers = require("lsp.handlers")
    local servers = require("lsp.servers")
    
    -- Base configuration for all servers
    local base_config = {
        capabilities = capabilities.get(),
        handlers = handlers.get(),
        on_attach = keymaps.on_attach,
    }
    
    -- Get all available servers from LuxLSP
    local all_servers = servers.get_all_servers()
    
    -- Setup autocmds for installed servers
    for server_name, server_def in pairs(all_servers) do
        if servers.is_server_installed(server_name) then
            local server_config = servers.get_server_config(server_name) or {}
            local server_cmd = M.find_server_command(server_name, server_config)
            if server_cmd then
                M.setup_server_autocmd(server_name, vim.tbl_deep_extend("force", base_config, server_config))
            end
        end
    end
end

-- Configure all available LSP servers (immediate configuration - used for testing/fallback)
function M.configure_available_servers()
    local capabilities = require("lsp.capabilities")
    local keymaps = require("lsp.keymaps")
    local handlers = require("lsp.handlers")
    local servers = require("lsp.servers")
    
    -- Base configuration for all servers
    local base_config = {
        capabilities = capabilities.get(),
        handlers = handlers.get(),
        on_attach = keymaps.on_attach,
    }
    
    -- Get all available servers from LuxLSP
    local all_servers = servers.get_all_servers()
    
    -- Configure installed servers
    for server_name, _ in pairs(all_servers) do
        if servers.is_server_installed(server_name) then
            local server_config = servers.get_server_config(server_name) or {}
            local server_cmd = M.find_server_command(server_name, server_config)
            if server_cmd then
                M.configure_server(server_name, base_config)
            end
        end
    end
end

-- Configure a single LSP server (modular function)
function M.configure_server(server_name, base_config)
    local servers = require("lsp.servers")
    
    -- Get server-specific configuration from LuxLSP
    local server_config = servers.get_server_config(server_name) or {}
    
    -- Check if server binary exists
    local server_cmd = M.find_server_command(server_name, server_config)
    if not server_cmd then
        return false -- Server not available
    end
    
    -- Merge base config with server-specific config
    local final_config = vim.tbl_deep_extend("force", base_config, server_config)
    
    -- Set server name and cmd
    final_config.name = server_name
    if type(server_cmd) == "table" then
        final_config.cmd = server_cmd
    end
    
    -- Configure the server
    pcall(vim.lsp.config, server_name, final_config)
    
    return true
end

-- Find server command - delegates to LuxLSP
function M.find_server_command(server_name, server_config)
    -- Use server-specific cmd if provided in config
    if server_config and server_config.cmd then
        if type(server_config.cmd) == "table" then
            if server_config.cmd[1] and vim.fn.executable(server_config.cmd[1]) == 1 then
                return server_config.cmd
            end
        elseif type(server_config.cmd) == "function" then            
            local cmd_result = server_config.cmd()
            if cmd_result and cmd_result[1] and vim.fn.executable(cmd_result[1]) == 1 then
                return cmd_result
            end
        end
    end
    
    -- Get executable from LuxLSP
    local success, luxlsp_lsp = pcall(require, 'luxlsp.lsp.init')
    if success and luxlsp_lsp.get_executable_path then
        local exe_path = luxlsp_lsp.get_executable_path(server_name)
        if exe_path and vim.fn.executable(exe_path) == 1 then
            return { exe_path }
        end
    end
    
    return nil -- Server not found
end

-- Setup autocommand to start server for specific filetypes
function M.setup_server_autocmd(server_name, config)
    local filetypes = M.get_server_filetypes(server_name)
    if not filetypes or #filetypes == 0 then
        return
    end
    
    local group_name = "LSP_" .. server_name
    local group = vim.api.nvim_create_augroup(group_name, { clear = true })
    
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = filetypes,
        callback = function()
            -- Delay server start slightly to improve responsiveness
            vim.defer_fn(function()
                -- Check if server is already attached to this buffer
                local clients = vim.lsp.get_clients({ bufnr = 0, name = server_name })
                if #clients > 0 then
                    return
                end
                
                -- Ensure server command is available
                local servers = require("lsp.servers")
                local server_config = servers.get_server_config(server_name)
                local server_cmd = M.find_server_command(server_name, server_config)
                if not server_cmd then
                    return
                end
                
                -- Prepare final config for this server
                local final_config = vim.tbl_deep_extend("force", config, server_config)
                final_config.name = server_name
                if type(server_cmd) == "table" then
                    final_config.cmd = server_cmd
                end
                
                -- Start the LSP client
                vim.lsp.start(final_config, {
                    reuse_client = function(client, conf)
                        return client.name == server_name
                    end,
                })
            end, 50) -- 50ms delay
        end,
    })
end

-- Get filetypes for a server from LuxLSP
function M.get_server_filetypes(server_name)
    local servers = require("lsp.servers")
    local all_servers = servers.get_all_servers()
    local server_def = all_servers[server_name]
    
    if server_def and server_def.filetypes then
        return server_def.filetypes
    end
    
    return nil
end

return M
