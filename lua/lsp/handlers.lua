-- LSP handlers configuration
local M = {}

-- Get LSP handlers with borders
function M.get()
    return {
        ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
            border = "rounded",
        }),
        ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
            border = "rounded",
        }),
    }
end

return M
