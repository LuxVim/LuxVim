-- LSP capabilities configuration
local M = {}

function M.get()
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    
    -- Enhanced capabilities for better LSP experience
    capabilities.textDocument.completion.completionItem.snippetSupport = true
    capabilities.textDocument.completion.completionItem.resolveSupport = {
        properties = { "documentation", "detail", "additionalTextEdits" }
    }
    
    -- Support for workspace/didChangeWatchedFiles
    capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true
    
    -- Support for textDocument/foldingRange
    capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true
    }
    
    return capabilities
end

return M