local catalog = require("core.theme-picker.catalog")
local preview = require("core.theme-picker.preview")
local persistence = require("core.theme-picker.persistence")

local M = {}

M.buf = nil
M.win = nil
M.cursor_line = 1
M.items = {}

local function get_installed_themes()
    local installed = {}
    for _, theme in ipairs(catalog.default_bundle) do
        table.insert(installed, { theme = theme, is_default = true })
    end
    local user_installed = persistence.load()
    for _, name in ipairs(user_installed) do
        local theme = catalog.get_by_name(name)
        if theme then
            table.insert(installed, { theme = theme, is_default = false })
        end
    end
    return installed
end

local function get_available_themes()
    local user_installed = persistence.load()
    local installed_set = {}
    for _, name in ipairs(user_installed) do
        installed_set[name] = true
    end

    local available = {}
    for _, theme in ipairs(catalog.optional) do
        if not installed_set[theme.name] then
            table.insert(available, theme)
        end
    end
    return available
end

local function build_items()
    M.items = {}
    local current = vim.g.colors_name or ""

    table.insert(M.items, { type = "header", text = "  INSTALLED" })

    local installed = get_installed_themes()
    for _, entry in ipairs(installed) do
        local prefix = "    "
        if entry.theme.colorscheme == current or
           (entry.theme.variants and vim.tbl_contains(entry.theme.variants, current)) then
            prefix = "  ● "
        end
        table.insert(M.items, {
            type = "installed",
            theme = entry.theme,
            is_default = entry.is_default,
            text = prefix .. entry.theme.name,
        })
    end

    table.insert(M.items, { type = "separator", text = "" })
    table.insert(M.items, { type = "header", text = "  AVAILABLE" })

    local available = get_available_themes()
    if #available == 0 then
        table.insert(M.items, { type = "empty", text = "    (all themes installed)" })
    else
        for _, theme in ipairs(available) do
            local desc = theme.description or ""
            if #desc > 25 then
                desc = desc:sub(1, 22) .. "..."
            end
            table.insert(M.items, {
                type = "available",
                theme = theme,
                text = string.format("    %-14s %s", theme.name, desc),
            })
        end
    end
end

local function render()
    if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then return end

    vim.api.nvim_buf_set_option(M.buf, "modifiable", true)

    local lines = {}
    for _, item in ipairs(M.items) do
        table.insert(lines, item.text)
    end
    table.insert(lines, "")
    table.insert(lines, "  [Enter] Apply  [x] Uninstall  [q] Close")

    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_set_cursor(M.win, { M.cursor_line, 0 })
    end
end

local function move_cursor(direction)
    local new_line = M.cursor_line + direction
    while new_line >= 1 and new_line <= #M.items do
        local item = M.items[new_line]
        if item.type == "installed" or item.type == "available" then
            M.cursor_line = new_line
            if M.win and vim.api.nvim_win_is_valid(M.win) then
                vim.api.nvim_win_set_cursor(M.win, { M.cursor_line, 0 })
            end
            local theme = item.theme
            if item.type == "installed" then
                preview.apply(theme.colorscheme)
            end
            return
        end
        new_line = new_line + direction
    end
end

local function find_first_selectable()
    for i, item in ipairs(M.items) do
        if item.type == "installed" or item.type == "available" then
            return i
        end
    end
    return 1
end

local function on_select()
    local item = M.items[M.cursor_line]
    if not item then return end

    if item.type == "installed" then
        preview.apply(item.theme.colorscheme)
        preview.confirm()
        M.close()
    elseif item.type == "available" then
        M.install_theme(item.theme)
    end
end

local function on_uninstall()
    local item = M.items[M.cursor_line]
    if not item or item.type ~= "installed" then return end

    if item.is_default then
        vim.notify("Cannot uninstall default theme", vim.log.levels.WARN)
        return
    end

    persistence.remove(item.theme.name)
    vim.notify("Removed " .. item.theme.name .. ". Run :Lazy clean to delete files.", vim.log.levels.INFO)
    build_items()
    M.cursor_line = find_first_selectable()
    render()
end

function M.install_theme(theme)
    vim.notify("Installing " .. theme.name .. "...", vim.log.levels.INFO)

    local spec = {
        theme.repo,
        name = theme.name,
        lazy = true,
    }

    require("lazy").install({ plugins = { spec } })

    persistence.add(theme.name)

    vim.defer_fn(function()
        preview.apply(theme.colorscheme)
        build_items()
        M.cursor_line = find_first_selectable()
        render()
        vim.notify(theme.name .. " installed!", vim.log.levels.INFO)
    end, 1000)
end

function M.close()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_close(M.win, true)
    end
    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
        vim.api.nvim_buf_delete(M.buf, { force = true })
    end
    M.win = nil
    M.buf = nil
end

function M.open()
    preview.save_current()
    build_items()

    local width = 50
    local height = #M.items + 3
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    M.buf = vim.api.nvim_create_buf(false, true)

    M.win = vim.api.nvim_open_win(M.buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Themes ",
        title_pos = "center",
    })

    vim.api.nvim_buf_set_option(M.buf, "bufhidden", "wipe")
    vim.api.nvim_win_set_option(M.win, "cursorline", true)

    M.cursor_line = find_first_selectable()
    render()

    local opts = { buffer = M.buf, silent = true }
    vim.keymap.set("n", "j", function() move_cursor(1) end, opts)
    vim.keymap.set("n", "k", function() move_cursor(-1) end, opts)
    vim.keymap.set("n", "<Down>", function() move_cursor(1) end, opts)
    vim.keymap.set("n", "<Up>", function() move_cursor(-1) end, opts)
    vim.keymap.set("n", "<CR>", on_select, opts)
    vim.keymap.set("n", "x", on_uninstall, opts)
    vim.keymap.set("n", "q", function()
        preview.restore()
        M.close()
    end, opts)
    vim.keymap.set("n", "<Esc>", function()
        preview.restore()
        M.close()
    end, opts)

    if M.items[M.cursor_line] and M.items[M.cursor_line].type == "installed" then
        preview.apply(M.items[M.cursor_line].theme.colorscheme)
    end
end

return M
