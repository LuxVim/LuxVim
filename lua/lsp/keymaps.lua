-- LSP keybindings
local M = {}

-- On attach function for LSP servers
function M.on_attach(client, bufnr)
    local opts = { buffer = bufnr, silent = true }

    -- LSP navigation
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    
    -- LSP actions
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>f", function()
        vim.lsp.buf.format { async = true }
    end, opts)
    
    -- Diagnostic navigation
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
    vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, opts)
    
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
    
    -- Highlight references under cursor
    if client.server_capabilities.documentHighlightProvider then
        vim.api.nvim_create_augroup("lsp_document_highlight", {
            clear = false
        })
        vim.api.nvim_clear_autocmds({
            buffer = bufnr,
            group = "lsp_document_highlight",
        })
        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            group = "lsp_document_highlight",
            buffer = bufnr,
            callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            group = "lsp_document_highlight",
            buffer = bufnr,
            callback = vim.lsp.buf.clear_references,
        })
    end
end

return M
