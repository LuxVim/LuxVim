local M = {}

local function get_data_path()
    local luxvim_dir = vim.fn.expand("~/.local/share/LuxVim")
    if vim.env.XDG_DATA_HOME then
        luxvim_dir = vim.env.XDG_DATA_HOME .. "/LuxVim"
    end
    return luxvim_dir .. "/data/installed-themes.lua"
end

function M.load()
    local path = get_data_path()
    local file = io.open(path, "r")
    if not file then
        return {}
    end
    local content = file:read("*a")
    file:close()

    local fn, err = loadstring("return " .. content)
    if not fn then
        return {}
    end

    local ok, result = pcall(fn)
    if not ok or type(result) ~= "table" then
        return {}
    end

    return result
end

function M.save(installed_names)
    local path = get_data_path()
    local dir = vim.fn.fnamemodify(path, ":h")
    vim.fn.mkdir(dir, "p")

    local file = io.open(path, "w")
    if not file then
        vim.notify("Failed to save installed themes", vim.log.levels.ERROR)
        return false
    end

    file:write("{\n")
    for i, name in ipairs(installed_names) do
        file:write('    "' .. name .. '"')
        if i < #installed_names then
            file:write(",")
        end
        file:write("\n")
    end
    file:write("}\n")
    file:close()
    return true
end

function M.add(name)
    local installed = M.load()
    for _, n in ipairs(installed) do
        if n == name then return true end
    end
    table.insert(installed, name)
    return M.save(installed)
end

function M.remove(name)
    local installed = M.load()
    local new_list = {}
    for _, n in ipairs(installed) do
        if n ~= name then
            table.insert(new_list, n)
        end
    end
    return M.save(new_list)
end

function M.is_installed(name)
    local installed = M.load()
    for _, n in ipairs(installed) do
        if n == name then return true end
    end
    return false
end

return M
