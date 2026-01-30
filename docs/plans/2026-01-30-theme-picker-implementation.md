# Theme Picker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an in-editor theme picker that ships a minimal default bundle and allows optional themes to be discovered and installed on demand.

**Architecture:** Core module at `lua/core/theme-picker/` with separate files for catalog data, UI rendering, and preview logic. Integrates with Lazy.nvim's programmatic API for runtime installation. Persists user choices to `data/installed-themes.lua`.

**Tech Stack:** Lua, Neovim API (nvim_open_win, nvim_buf_set_lines), Lazy.nvim API

---

## Task 1: Create Theme Catalog

**Files:**
- Create: `lua/core/theme-picker/catalog.lua`

**Step 1: Create the core directory**

```bash
mkdir -p lua/core/theme-picker
```

**Step 2: Create catalog.lua with theme definitions**

```lua
local M = {}

M.default_bundle = {
    {
        repo = "LuxVim/nami.nvim",
        name = "nami",
        description = "LuxVim default theme",
        colorscheme = "nami",
        is_default = true,
    },
    {
        repo = "catppuccin/nvim",
        name = "catppuccin",
        description = "Soothing pastel theme, 4 variants",
        colorscheme = "catppuccin",
        variants = { "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha" },
    },
    {
        repo = "folke/tokyonight.nvim",
        name = "tokyonight",
        description = "Clean dark theme, multiple styles",
        colorscheme = "tokyonight",
        variants = { "tokyonight-night", "tokyonight-storm", "tokyonight-day", "tokyonight-moon" },
    },
    {
        repo = "morhetz/gruvbox",
        name = "gruvbox",
        description = "Retro groove color scheme",
        colorscheme = "gruvbox",
    },
    {
        repo = "dracula/vim",
        name = "dracula",
        description = "Dark theme for vampires",
        colorscheme = "dracula",
    },
}

M.optional = {
    {
        repo = "rose-pine/neovim",
        name = "rose-pine",
        description = "Minimal, dark and light variants",
        colorscheme = "rose-pine",
        variants = { "rose-pine", "rose-pine-moon", "rose-pine-dawn" },
    },
    {
        repo = "sainnhe/everforest",
        name = "everforest",
        description = "Green-based, easy on eyes",
        colorscheme = "everforest",
    },
    {
        repo = "EdenEast/nightfox.nvim",
        name = "nightfox",
        description = "Soft dark theme, many variants",
        colorscheme = "nightfox",
        variants = { "nightfox", "dayfox", "dawnfox", "duskfox", "nordfox", "terafox", "carbonfox" },
    },
    {
        repo = "rebelot/kanagawa.nvim",
        name = "kanagawa",
        description = "Wave-inspired, dark theme",
        colorscheme = "kanagawa",
        variants = { "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus" },
    },
    {
        repo = "navarasu/onedark.nvim",
        name = "onedark",
        description = "Atom One Dark inspired",
        colorscheme = "onedark",
    },
    {
        repo = "nyoom-engineering/oxocarbon.nvim",
        name = "oxocarbon",
        description = "IBM Carbon design inspired",
        colorscheme = "oxocarbon",
    },
    {
        repo = "sainnhe/sonokai",
        name = "sonokai",
        description = "Monokai Pro inspired",
        colorscheme = "sonokai",
    },
    {
        repo = "marko-cerovac/material.nvim",
        name = "material",
        description = "Material design colors",
        colorscheme = "material",
    },
    {
        repo = "sainnhe/edge",
        name = "edge",
        description = "Clean and elegant",
        colorscheme = "edge",
    },
}

function M.get_by_name(name)
    for _, theme in ipairs(M.default_bundle) do
        if theme.name == name then return theme end
    end
    for _, theme in ipairs(M.optional) do
        if theme.name == name then return theme end
    end
    return nil
end

return M
```

**Step 3: Verify file created**

```bash
cat lua/core/theme-picker/catalog.lua | head -20
```

**Step 4: Commit**

```bash
git add lua/core/theme-picker/catalog.lua
git commit -m "feat(theme-picker): add theme catalog with default bundle and optional themes"
```

---

## Task 2: Create Preview Module

**Files:**
- Create: `lua/core/theme-picker/preview.lua`

**Step 1: Create preview.lua**

```lua
local M = {}

M.original_colorscheme = nil

function M.save_current()
    M.original_colorscheme = vim.g.colors_name
end

function M.apply(colorscheme)
    local ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
    if not ok then
        vim.notify("Failed to preview: " .. colorscheme, vim.log.levels.WARN)
        return false
    end
    return true
end

function M.restore()
    if M.original_colorscheme then
        pcall(vim.cmd, "colorscheme " .. M.original_colorscheme)
    end
end

function M.confirm()
    M.original_colorscheme = vim.g.colors_name
end

return M
```

**Step 2: Commit**

```bash
git add lua/core/theme-picker/preview.lua
git commit -m "feat(theme-picker): add preview module for live theme switching"
```

---

## Task 3: Create Persistence Module

**Files:**
- Create: `lua/core/theme-picker/persistence.lua`

**Step 1: Create persistence.lua**

```lua
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
```

**Step 2: Commit**

```bash
git add lua/core/theme-picker/persistence.lua
git commit -m "feat(theme-picker): add persistence module for saving installed themes"
```

---

## Task 4: Create UI Module

**Files:**
- Create: `lua/core/theme-picker/ui.lua`

**Step 1: Create ui.lua**

```lua
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
```

**Step 2: Commit**

```bash
git add lua/core/theme-picker/ui.lua
git commit -m "feat(theme-picker): add floating window UI with navigation and live preview"
```

---

## Task 5: Create Entry Point and Command

**Files:**
- Create: `lua/core/theme-picker/init.lua`
- Modify: `init.lua`

**Step 1: Create init.lua for theme-picker**

```lua
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
```

**Step 2: Load theme-picker in init.lua**

Edit `init.lua` to add after `safe_require("dev")`:

```lua
safe_require("core.theme-picker")
```

**Step 3: Commit**

```bash
git add lua/core/theme-picker/init.lua init.lua
git commit -m "feat(theme-picker): add entry point and :Themes command"
```

---

## Task 6: Update colorschemes.lua

**Files:**
- Modify: `lua/plugins/colorschemes.lua`

**Step 1: Replace colorschemes.lua with minimal default bundle**

```lua
local dev = require('dev')

local function get_optional_theme_specs()
    local ok, picker = pcall(require, "core.theme-picker")
    if ok and picker.get_installed_specs then
        return picker.get_installed_specs()
    end
    return {}
end

local themes = {
    dev.create_plugin_spec({
        "LuxVim/nami.nvim",
        priority = 1000,
        config = function()
            require('nami').setup({
                transparent = false
            })
            local status_ok, _ = pcall(vim.cmd, 'colorscheme nami')
            if not status_ok then
                vim.api.nvim_echo({{'LuxVim: Failed to load colorscheme', 'WarningMsg'}}, true, {})
            end
        end,
    }, { debug_name = "nami.nvim" }),

    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = true,
    },

    {
        "folke/tokyonight.nvim",
        lazy = true,
    },

    {
        "morhetz/gruvbox",
        lazy = true,
    },

    {
        "dracula/vim",
        name = "dracula",
        lazy = true,
    },
}

local optional = get_optional_theme_specs()
for _, spec in ipairs(optional) do
    table.insert(themes, spec)
end

return themes
```

**Step 2: Commit**

```bash
git add lua/plugins/colorschemes.lua
git commit -m "refactor(colorschemes): reduce to default bundle, integrate theme-picker"
```

---

## Task 7: Manual Testing

**Step 1: Test in LuxVim**

Launch LuxVim from the worktree:

```bash
NVIM_APPNAME="LuxVim" nvim
```

**Step 2: Verify default themes load**

Run `:Lazy` and confirm only 5 colorscheme plugins are installed:
- nami.nvim
- catppuccin
- tokyonight
- gruvbox
- dracula

**Step 3: Test :Themes command**

Run `:Themes` and verify:
- Floating window opens centered
- INSTALLED section shows 5 default themes
- AVAILABLE section shows optional themes
- j/k navigation works
- Live preview works on installed themes
- q closes and restores original theme

**Step 4: Test installation**

Navigate to an available theme, press Enter:
- Theme installs
- Theme applies
- Theme appears in INSTALLED section

**Step 5: Test uninstall**

Navigate to user-installed theme, press x:
- Theme removed from list
- Message about :Lazy clean shown

**Step 6: Test persistence**

Quit and relaunch LuxVim:
- User-installed themes still appear in :Themes INSTALLED section

---

## Task 8: Final Commit and Summary

**Step 1: Verify all files**

```bash
git status
ls -la lua/core/theme-picker/
```

**Step 2: Tag completion**

```bash
git log --oneline -10
```

Files created:
- `lua/core/theme-picker/init.lua`
- `lua/core/theme-picker/catalog.lua`
- `lua/core/theme-picker/ui.lua`
- `lua/core/theme-picker/preview.lua`
- `lua/core/theme-picker/persistence.lua`

Files modified:
- `init.lua`
- `lua/plugins/colorschemes.lua`
