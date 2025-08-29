-- Main LSP setup orchestrator using LuxLSP
local M = {}

function M.setup()
    -- Setup LuxLSP for language server management
    local luxlsp_success, luxlsp = pcall(require, 'luxlsp')
    if not luxlsp_success then
        vim.notify("LuxLSP not available, falling back to basic LSP setup", vim.log.levels.WARN)
        M.setup_basic_lsp()
        return
    end
    
    -- Configure LuxLSP with LuxVim integration
    luxlsp.setup({
        window = {
            width = 0.8,
            height = 0.8,
            border = "rounded",
            title = " LuxVim LSP Manager ",
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
    
    -- Setup diagnostics and handlers
    local diagnostics = require("lsp.diagnostics")
    diagnostics.setup()
    
    -- Setup lazy-loading autocmds for available LSP servers
    M.setup_available_servers()
    
    vim.notify("LuxLSP initialized - use <leader>L to manage language servers", vim.log.levels.INFO)
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
    
    -- Setup autocmds for each server (lazy loading)
    for _, server_name in ipairs(servers.ensure_installed) do
        -- Only setup autocmd if server binary exists
        local server_config = servers.get_config(server_name)
        local server_cmd = M.find_server_command(server_name, server_config)
        if server_cmd then
            M.setup_server_autocmd(server_name, vim.tbl_deep_extend("force", base_config, server_config))
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
    
    -- Configure each server from our servers list (immediate startup)
    for _, server_name in ipairs(servers.ensure_installed) do
        -- Only configure if server binary exists
        local server_config = servers.get_config(server_name)
        local server_cmd = M.find_server_command(server_name, server_config)
        if server_cmd then
            M.configure_server(server_name, base_config)
        end
    end
end

-- Configure a single LSP server (modular function)
function M.configure_server(server_name, base_config)
    local servers = require("lsp.servers")
    
    -- Get server-specific configuration
    local server_config = servers.get_config(server_name)
    
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
    
    -- Configure the server with both methods for compatibility
    pcall(vim.lsp.config, server_name, final_config)
    
    return true
end

-- Find server command (checks multiple locations)
function M.find_server_command(server_name, server_config)
    -- Use server-specific cmd if provided
    if server_config.cmd then
        if type(server_config.cmd) == "table" then
            -- Validate that the first element is executable
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
    
    -- Server-specific binary names
    local binary_names = {
        lua_ls = "lua-language-server",
        ts_ls = "typescript-language-server",
        pyright = "pyright-langserver",
        rust_analyzer = "rust-analyzer",
        gopls = "gopls",
        clangd = "clangd",
        jdtls = "jdtls",
        solargraph = "solargraph",
        bashls = "bash-language-server",
        jsonls = "vscode-json-language-server",
        yamlls = "yaml-language-server",
        html = "vscode-html-language-server",
        cssls = "vscode-css-language-server",
        tailwindcss = "tailwindcss-language-server",
    }
    
    local binary_name = binary_names[server_name] or server_name
    
    -- Check LuxLSP installation with correct binary name
    local luxlsp_binary_path = vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h") .. "/data/luxlsp/" .. server_name .. "/bin/" .. binary_name
    if vim.fn.executable(luxlsp_binary_path) == 1 then
        return { luxlsp_binary_path }
    end
    
    -- Check system PATH with correct binary name
    if vim.fn.executable(binary_name) == 1 then
        return { binary_name }
    end
    
    -- Fallback: check with server name
    if binary_name ~= server_name then
        local fallback_path = vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h") .. "/data/luxlsp/" .. server_name .. "/bin/" .. server_name
        if vim.fn.executable(fallback_path) == 1 then
            return { fallback_path }
        end
        
        if vim.fn.executable(server_name) == 1 then
            return { server_name }
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
                local server_config = servers.get_config(server_name)
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

-- Get filetypes for a server
function M.get_server_filetypes(server_name)
    local filetype_map = {
        lua_ls = { "lua" },
        ts_ls = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
        pyright = { "python" },
        rust_analyzer = { "rust" },
        gopls = { "go" },
        clangd = { "c", "cpp" },
        jdtls = { "java" },
        solargraph = { "ruby" },
        bashls = { "sh", "bash" },
        jsonls = { "json" },
        yamlls = { "yaml" },
        html = { "html" },
        cssls = { "css" },
        tailwindcss = { "css", "html", "javascript", "typescript", "javascriptreact", "typescriptreact" },
    }
    
    return filetype_map[server_name]
end

-- Fallback basic LSP setup (uses modular system with lazy loading)
function M.setup_basic_lsp()
    local capabilities = require("lsp.capabilities")
    local diagnostics = require("lsp.diagnostics")
    local handlers = require("lsp.handlers")
    local keymaps = require("lsp.keymaps")
    
    -- Setup diagnostics
    diagnostics.setup()
    
    -- Use modular configuration system
    local base_config = {
        capabilities = capabilities.get(),
        handlers = handlers.get(),
        on_attach = keymaps.on_attach,
    }
    
    -- Setup lazy loading for common servers
    local common_servers = { "lua_ls", "ts_ls", "pyright", "solargraph" }
    for _, server_name in ipairs(common_servers) do
        local servers = require("lsp.servers")
        local server_config = servers.get_config(server_name)
        local server_cmd = M.find_server_command(server_name, server_config)
        if server_cmd then
            M.setup_server_autocmd(server_name, vim.tbl_deep_extend("force", base_config, server_config))
        end
    end
end


return M
