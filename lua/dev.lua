-- Development utilities for LuxVim plugin development
local M = {}

-- Get the LuxVim root directory
local function get_luxvim_root()
    -- Use the directory containing init.lua as the root
    local init_path = vim.fn.findfile('init.lua', vim.fn.stdpath('config') .. ';.')
    if init_path ~= '' then
        return vim.fn.fnamemodify(init_path, ':p:h')
    end
    
    -- Fallback: assume we're in the LuxVim directory structure
    local current_script = debug.getinfo(1, 'S').source:match('^@(.*)')
    if current_script then
        return vim.fn.fnamemodify(current_script, ':p:h:h') -- Go up from lua/ to root
    end
    
    -- Last fallback: use current working directory
    return vim.fn.getcwd()
end

-- Check if a debug version of a plugin exists
function M.has_debug_plugin(plugin_name)
    local luxvim_root = get_luxvim_root()
    local debug_path = luxvim_root .. "/debug/" .. plugin_name
    
    -- Check if directory exists and has essential files
    local stat = vim.loop.fs_stat(debug_path)
    if not stat or stat.type ~= "directory" then
        return false
    end
    
    -- Check for plugin files (either plugin/ or lua/ directory should exist)
    local plugin_dir = debug_path .. "/plugin"
    local lua_dir = debug_path .. "/lua"
    
    local plugin_stat = vim.loop.fs_stat(plugin_dir)
    local lua_stat = vim.loop.fs_stat(lua_dir)
    
    return (plugin_stat and plugin_stat.type == "directory") or 
           (lua_stat and lua_stat.type == "directory")
end

-- Get the local debug path for a plugin
function M.get_debug_path(plugin_name)
    local luxvim_root = get_luxvim_root()
    return luxvim_root .. "/debug/" .. plugin_name
end

-- Create a plugin spec that prioritizes local debug version
function M.create_plugin_spec(remote_spec, options)
    options = options or {}
    local plugin_name = options.debug_name or remote_spec[1]:match("([^/]+)$")
    local enable_debug = options.enable_debug ~= false -- Default to true
    
    if enable_debug and M.has_debug_plugin(plugin_name) then
        local debug_path = M.get_debug_path(plugin_name)
        
        -- Create local plugin spec
        local local_spec = vim.tbl_deep_extend("force", remote_spec, {
            dir = debug_path,
            name = plugin_name .. "-debug"
        })
        
        -- Remove git-related fields for local development
        local_spec[1] = nil -- Remove the repo URL
        local_spec.url = nil
        local_spec.branch = nil
        local_spec.tag = nil
        local_spec.commit = nil
        
        -- Add development markers
        if local_spec.config then
            local original_config = local_spec.config
            local_spec.config = function()
                vim.notify("🔧 Loading DEBUG version of " .. plugin_name, vim.log.levels.INFO)
                original_config()
            end
        end
        
        return local_spec
    else
        -- Return original remote spec
        return remote_spec
    end
end

-- List all available debug plugins
function M.list_debug_plugins()
    local luxvim_root = get_luxvim_root()
    local debug_dir = luxvim_root .. "/debug"
    
    local handle = vim.loop.fs_scandir(debug_dir)
    if not handle then
        return {}
    end
    
    local debug_plugins = {}
    while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        
        -- Accept both directories and symbolic links (which could point to directories)
        if (type == "directory" or type == "link") and M.has_debug_plugin(name) then
            table.insert(debug_plugins, name)
        end
    end
    
    return debug_plugins
end

-- Development status report
function M.dev_status()
    local debug_plugins = M.list_debug_plugins()
    
    print("🔧 LuxVim Development Status")
    print("==========================")
    
    if #debug_plugins == 0 then
        print("No debug plugins found in /debug directory")
    else
        print("Available debug plugins:")
        for _, plugin in ipairs(debug_plugins) do
            local path = M.get_debug_path(plugin)
            print("  • " .. plugin .. " -> " .. path)
        end
    end
    
    print("\nTo use debug plugins:")
    print("1. Place plugin source in /debug/<plugin-name>/")
    print("2. Plugin configurations will automatically detect and use debug versions")
    print("3. Use :LuxDevStatus to check this status anytime")
end

-- Create user command
vim.api.nvim_create_user_command('LuxDevStatus', function()
    M.dev_status()
end, { desc = 'Show LuxVim development status' })

return M
