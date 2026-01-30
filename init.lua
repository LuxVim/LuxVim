-- **********************************************************
-- ********************* LUXVIM *****************************
-- **********************************************************

-- Add current directory to package path for module loading
local current_dir = vim.fn.expand('<sfile>:p:h')
vim.opt.runtimepath:prepend(current_dir)

-- Add the lua directory to the package.path for proper module loading
package.path = current_dir .. '/lua/?.lua;' .. current_dir .. '/lua/?/init.lua;' .. package.path

-- Helper function to safely require modules
local function safe_require(module_name)
    local ok, result = pcall(require, module_name)
    if not ok then
        vim.notify("Failed to load module: " .. module_name .. "\n" .. result, vim.log.levels.WARN)
        return nil
    end
    return result
end

-- Set mapleader before loading lazy.nvim
vim.g.mapleader = ' '

-- Load configuration modules
safe_require("config.lazy")
safe_require("config.options")
safe_require("config.keymaps")
safe_require("config.autocmds")

-- Load utility functions
local utils = safe_require("utils")

-- Load development utilities
safe_require("dev")

-- Load theme picker module
safe_require("core.theme-picker")

-- Create commands only if utils loaded successfully
if utils then
    vim.api.nvim_create_user_command('SearchText', utils.search_text_in_current_dir, {})
    
    -- Global functions for backward compatibility
    function SearchTextInCurrentDir()
        utils.search_text_in_current_dir()
    end

    function FZFOpen(cmd)
        utils.fzf_open(cmd)
    end
else
    vim.notify("Utils module not available. Some commands may not work.", vim.log.levels.WARN)
end
