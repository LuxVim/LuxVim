-- LSP server configurations
local M = {}

-- List of servers to install and configure
M.ensure_installed = {
    "lua_ls",
    "ts_ls", 
    "pyright",
    "rust_analyzer",
    "gopls",
    "clangd",
    "jdtls",
    "solargraph",
    "bashls",
    "jsonls",
    "yamlls",
    "html",
    "cssls",
    "tailwindcss",
}

-- Server configurations
local configs = {
    lua_ls = {
        settings = {
            Lua = {
                runtime = {
                    version = "LuaJIT",
                },
                diagnostics = {
                    globals = { "vim", "use" },
                    disable = {"trailing-space"},
                },
                workspace = {
                    library = vim.api.nvim_get_runtime_file("", true),
                    maxPreload = 100000,
                    preloadFileSize = 10000,
                    checkThirdParty = false,
                },
                telemetry = { enable = false },
                format = { enable = false }, -- Use stylua instead
            },
        },
    },
    
    ts_ls = {
        settings = {
            typescript = {
                inlayHints = {
                    includeInlayParameterNameHints = "all",
                    includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                    includeInlayFunctionParameterTypeHints = true,
                    includeInlayVariableTypeHints = true,
                    includeInlayPropertyDeclarationTypeHints = true,
                    includeInlayFunctionLikeReturnTypeHints = true,
                    includeInlayEnumMemberValueHints = true,
                }
            },
            javascript = {
                inlayHints = {
                    includeInlayParameterNameHints = "all",
                    includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                    includeInlayFunctionParameterTypeHints = true,
                    includeInlayVariableTypeHints = true,
                    includeInlayPropertyDeclarationTypeHints = true,
                    includeInlayFunctionLikeReturnTypeHints = true,
                    includeInlayEnumMemberValueHints = true,
                }
            }
        }
    },
    
    pyright = {
        settings = {
            python = {
                analysis = {
                    autoSearchPaths = true,
                    diagnosticMode = "workspace",
                    useLibraryCodeForTypes = true,
                }
            }
        }
    },
    
    rust_analyzer = {
        settings = {
            ["rust-analyzer"] = {
                cargo = {
                    allFeatures = true,
                },
                procMacro = {
                    enable = true,
                },
                checkOnSave = {
                    command = "clippy",
                },
            },
        },
    },
    
    gopls = {
        settings = {
            gopls = {
                analyses = {
                    unusedparams = true,
                },
                staticcheck = true,
                gofumpt = true,
                hints = {
                    parameterNames = true,
                    rangeVariableTypes = true,
                },
            },
        },
    },
    
    jdtls = {
        settings = {
            java = {
                eclipse = {
                    downloadSources = true,
                },
                configuration = {
                    updateBuildConfiguration = "interactive",
                    runtimes = function()
                        local runtimes = {}
                        -- Auto-detect Java installations
                        local java_paths = {
                            "/usr/lib/jvm/java-8-openjdk-amd64",
                            "/usr/lib/jvm/java-11-openjdk-amd64", 
                            "/usr/lib/jvm/java-17-openjdk-amd64",
                            "/Library/Java/JavaVirtualMachines/openjdk-8.jdk/Contents/Home",
                            "/Library/Java/JavaVirtualMachines/openjdk-11.jdk/Contents/Home",
                            "/Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home",
                        }
                        for _, path in ipairs(java_paths) do
                            if vim.fn.isdirectory(path) == 1 then
                                local version = path:match("java%-(%d+)")
                                if version then
                                    table.insert(runtimes, {
                                        name = "JavaSE-" .. version,
                                        path = path,
                                    })
                                end
                            end
                        end
                        return runtimes
                    end,
                },
                compile = {
                    nullAnalysis = {
                        mode = "automatic",
                    },
                },
                maven = {
                    downloadSources = true,
                },
                implementationsCodeLens = {
                    enabled = true,
                },
                referencesCodeLens = {
                    enabled = true,
                },
                references = {
                    includeDecompiledSources = true,
                },
                inlayHints = {
                    parameterNames = {
                        enabled = "all",
                    },
                },
                format = {
                    enabled = false,
                },
            },
            signatureHelp = { enabled = true },
            completion = {
                favoriteStaticMembers = {
                    "org.hamcrest.MatcherAssert.assertThat",
                    "org.hamcrest.Matchers.*",
                    "org.hamcrest.CoreMatchers.*",
                    "org.junit.jupiter.api.Assertions.*",
                    "java.util.Objects.requireNonNull",
                    "java.util.Objects.requireNonNullElse",
                    "org.mockito.Mockito.*",
                },
            },
            contentProvider = { preferred = "fernflower" },
            extendedClientCapabilities = {
                progressReportProvider = false,
                classFileContentsSupport = true,
                generateToStringPromptSupport = true,
                hashCodeEqualsPromptSupport = true,
                advancedExtractRefactoringSupport = true,
                advancedOrganizeImportsSupport = true,
                generateConstructorsPromptSupport = true,
                generateDelegateMethodsPromptSupport = true,
                moveRefactoringSupport = true,
            },
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticStarThreshold = 9999,
                },
            },
            codeGeneration = {
                toString = {
                    template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
                },
                useBlocks = true,
            },
        }
    },
    
    clangd = {
        cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--completion-style=bundled",
            "--cross-file-rename",
            "--header-insertion=iwyu",
        },
        init_options = {
            clangdFileStatus = true,
            usePlaceholders = true,
            completeUnimported = true,
        },
    },
    
    solargraph = {
        cmd = function()
            local luxlsp_root = vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h") .. "/data/luxlsp/solargraph"
            local wrapper_bin = luxlsp_root .. "/bin/solargraph-wrapper"
            if vim.fn.executable(wrapper_bin) == 1 then
                return { wrapper_bin, "stdio" }
            elseif vim.fn.executable("solargraph") == 1 then
                return { "solargraph", "stdio" }
            end
            return nil
        end,
        settings = {
            solargraph = {
                autoformat = false,
                completion = true,
                diagnostic = true,
                folding = true,
                references = true,
                rename = true,
                symbols = true,
                logLevel = "warn",
                -- Performance optimizations for faster diagnostics
                useBundler = false,
                checkGemVersion = false,
                backgroundAnalysis = false,
                useBundlerForDefinitions = false,
                -- Enable faster file watching and analysis
                workspaceAnalysis = true,
                -- Reduce diagnostic delay
                diagnosticsDelay = 100,
                -- Optimize memory usage
                maxFiles = 5000,
                -- Cache for better performance
                enableCache = true,
            }
        }
    },
}

-- Get configuration for a specific server
function M.get_config(server_name)
    local config = configs[server_name] or {}
    
    -- Handle function-based configurations
    if config.settings and config.settings.java and config.settings.java.configuration and config.settings.java.configuration.runtimes then
        if type(config.settings.java.configuration.runtimes) == "function" then
            config.settings.java.configuration.runtimes = config.settings.java.configuration.runtimes()
        end
    end
    
    -- Handle function-based cmd configurations
    if config.cmd and type(config.cmd) == "function" then
        config.cmd = config.cmd()
    end
    
    
    return config
end

return M
