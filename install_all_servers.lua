#!/usr/bin/env lux

-- Script to install all LuxLSP servers systematically
-- This script waits for each installation to complete

local luxlsp = require('luxlsp')
local registry = require('luxlsp.lsp.registry')
local installer = require('luxlsp.lsp.installer')
local lsp_manager = require('luxlsp.lsp.init')

-- Get all servers categorized by type
local all_servers = registry.get_all_servers()
local installation_results = {}

-- Categorize servers by installation type
local servers_by_type = {
    npm_install = {},
    github_release = {},
    pip_install = {},
    go_install = {},
    gem_install = {},
    manual = {}
}

for name, config in pairs(all_servers) do
    local install_type = config.install.type
    if servers_by_type[install_type] then
        table.insert(servers_by_type[install_type], name)
    end
end

-- Function to install servers synchronously (with callback wait)
local function install_server_sync(server_name)
    local done = false
    local success = false
    local message = ""
    
    print("Installing " .. server_name .. "...")
    
    installer.install(server_name, function(install_success, install_message)
        done = true
        success = install_success
        message = install_message or ""
        if install_success then
            print("✓ " .. server_name .. " installed successfully")
        else
            print("✗ " .. server_name .. " failed: " .. install_message)
        end
    end)
    
    -- Wait for completion (with timeout)
    local timeout = 0
    while not done and timeout < 300 do  -- 30 second timeout
        vim.wait(100)
        timeout = timeout + 1
    end
    
    if not done then
        print("✗ " .. server_name .. " timed out")
        return false, "Installation timed out"
    end
    
    return success, message
end

-- Install each category of servers
local install_order = {
    "npm_install",
    "go_install", 
    "gem_install",
    "pip_install",
    "github_release",
    "manual"
}

print("=== LuxLSP Server Installation Report ===")
print("Found " .. vim.tbl_count(all_servers) .. " total servers")
print("")

for _, install_type in ipairs(install_order) do
    local servers = servers_by_type[install_type]
    if #servers > 0 then
        print("--- " .. string.upper(install_type) .. " SERVERS (" .. #servers .. ") ---")
        
        for _, server_name in ipairs(servers) do
            if install_type == "manual" then
                print("⚠ " .. server_name .. " requires manual installation")
                installation_results[server_name] = { success = false, message = "Manual installation required", type = install_type }
            else
                local success, message = install_server_sync(server_name)
                installation_results[server_name] = { success = success, message = message, type = install_type }
            end
        end
        print("")
    end
end

-- Final report
print("=== INSTALLATION SUMMARY ===")
local successful = 0
local failed = 0
local manual_servers = 0

for server_name, result in pairs(installation_results) do
    if result.type == "manual" then
        manual_servers = manual_servers + 1
    elseif result.success then
        successful = successful + 1
    else
        failed = failed + 1
    end
end

print("Successful installations: " .. successful)
print("Failed installations: " .. failed)
print("Manual installations required: " .. manual_servers)
print("Total servers: " .. vim.tbl_count(all_servers))

print("\n=== DETAILED FAILURES ===")
for server_name, result in pairs(installation_results) do
    if not result.success and result.type ~= "manual" then
        print("✗ " .. server_name .. " (" .. result.type .. "): " .. result.message)
    end
end

print("\n=== MANUAL INSTALL SERVERS ===")
for server_name, result in pairs(installation_results) do
    if result.type == "manual" then
        local config = all_servers[server_name]
        local description = config.install.description or "No description"
        print("⚠ " .. server_name .. ": " .. description)
    end
end