local M = {}

local catalog = require("core.theme-picker.catalog")
local persistence = require("core.theme-picker.persistence")
local ui = require("core.theme-picker.ui")

function M.open()
    ui.open()
end

function M.get_installed_specs()
    local specs = {}
    local installed = persistence.load()

    for _, name in ipairs(installed) do
        local theme = catalog.get_by_name(name)
        if theme then
            table.insert(specs, {
                theme.repo,
                name = theme.name,
                lazy = true,
            })
        end
    end

    return specs
end

vim.api.nvim_create_user_command("Themes", function()
    M.open()
end, { desc = "Open theme picker" })

return M
