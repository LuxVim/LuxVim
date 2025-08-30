-- LSP server configurations - delegates to LuxLSP
local M = {}

-- Get all available servers from LuxLSP registry
function M.get_all_servers()
    local success, luxlsp_registry = pcall(require, 'luxlsp.lsp.registry')
    if success then
        return luxlsp_registry.get_all_servers()
    end
    return {}
end

-- Get configuration for a specific server from LuxLSP
function M.get_server_config(server_name)
    local success, luxlsp_lsp = pcall(require, 'luxlsp.lsp.init')
    if success and luxlsp_lsp.get_server_config then
        return luxlsp_lsp.get_server_config(server_name)
    end
    return nil
end

-- Check if server is installed via LuxLSP
function M.is_server_installed(server_name)
    local success, luxlsp_lsp = pcall(require, 'luxlsp.lsp.init')
    if success and luxlsp_lsp.is_installed then
        return luxlsp_lsp.is_installed(server_name)
    end
    return false
end

return M
