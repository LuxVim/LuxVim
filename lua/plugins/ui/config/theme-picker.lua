-- lua/plugins/ui/config/theme-picker.lua
local notify = require("core.lib.notify")
local data = require("core.lib.data")
local paths = require("core.lib.paths")

local M = {}

local _opts = {}
local _buf = nil
local _win = nil
local _cursor_line = 1
local _items = {}
local _original_colorscheme = nil

-- Persistence

local function get_data_path()
  return paths.join(data.root(), "data", "installed-themes.json")
end

local function get_dynamic_specs_dir()
  return paths.join(data.root(), "data", "dynamic-specs")
end

local function load_installed()
  local path = get_data_path()
  local file = io.open(path, "r")
  if not file then
    return {}
  end
  local content = file:read("*a")
  file:close()

  local ok, result = pcall(vim.json.decode, content)
  if not ok or type(result) ~= "table" then
    return {}
  end
  return result
end

local function save_installed(installed_names)
  local path = get_data_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local file = io.open(path, "w")
  if not file then
    notify.error("Failed to save installed themes")
    return false
  end
  file:write(vim.json.encode(installed_names))
  file:close()
  return true
end

local function write_dynamic_spec(theme)
  local dir = get_dynamic_specs_dir()
  vim.fn.mkdir(dir, "p")
  local path = paths.join(dir, "theme-" .. theme.name .. ".lua")
  local file = io.open(path, "w")
  if not file then
    return false
  end
  file:write('return {\n')
  file:write('  source = "' .. theme.repo .. '",\n')
  file:write('  lazy = { lazy = true, priority = 1000 },\n')
  file:write('}\n')
  file:close()
  return true
end

local function delete_dynamic_spec(theme_name)
  local path = paths.join(get_dynamic_specs_dir(), "theme-" .. theme_name .. ".lua")
  os.remove(path)
end

-- Theme lookup

local function find_theme(name)
  for _, t in ipairs(_opts.default_themes or {}) do
    if t.name == name then return t end
  end
  for _, t in ipairs(_opts.optional_themes or {}) do
    if t.name == name then return t end
  end
  return nil
end

-- Preview

local function preview_apply(colorscheme)
  local ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
  if not ok then
    notify.warn("Failed to preview: " .. colorscheme)
  end
end

local function preview_restore()
  if _original_colorscheme then
    pcall(vim.cmd, "colorscheme " .. _original_colorscheme)
  end
end

-- UI

local function get_installed_themes()
  local installed = {}
  for _, theme in ipairs(_opts.default_themes or {}) do
    table.insert(installed, { theme = theme, is_default = true })
  end
  local user_installed = load_installed()
  for _, name in ipairs(user_installed) do
    local theme = find_theme(name)
    if theme then
      table.insert(installed, { theme = theme, is_default = false })
    end
  end
  return installed
end

local function get_available_themes()
  local user_installed = load_installed()
  local installed_set = {}
  for _, name in ipairs(user_installed) do
    installed_set[name] = true
  end

  local available = {}
  for _, theme in ipairs(_opts.optional_themes or {}) do
    if not installed_set[theme.name] then
      table.insert(available, theme)
    end
  end
  return available
end

local function build_items()
  _items = {}
  local current = vim.g.colors_name or ""

  table.insert(_items, { type = "header", text = "  INSTALLED" })

  local installed = get_installed_themes()
  for _, entry in ipairs(installed) do
    local prefix = "    "
    if entry.theme.colorscheme == current or
        (entry.theme.variants and vim.tbl_contains(entry.theme.variants, current)) then
      prefix = "  * "
    end
    table.insert(_items, {
      type = "installed",
      theme = entry.theme,
      is_default = entry.is_default,
      text = prefix .. entry.theme.name,
    })
  end

  table.insert(_items, { type = "separator", text = "" })
  table.insert(_items, { type = "header", text = "  AVAILABLE" })

  local available = get_available_themes()
  if #available == 0 then
    table.insert(_items, { type = "empty", text = "    (all themes installed)" })
  else
    for _, theme in ipairs(available) do
      local desc = theme.description or ""
      if #desc > 25 then
        desc = desc:sub(1, 22) .. "..."
      end
      table.insert(_items, {
        type = "available",
        theme = theme,
        text = string.format("    %-14s %s", theme.name, desc),
      })
    end
  end
end

local function render()
  if not _buf or not vim.api.nvim_buf_is_valid(_buf) then return end

  vim.bo[_buf].modifiable = true
  local lines = {}
  for _, item in ipairs(_items) do
    table.insert(lines, item.text)
  end
  table.insert(lines, "")
  table.insert(lines, "  [Enter] Apply  [x] Uninstall  [q] Close")

  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false

  if _win and vim.api.nvim_win_is_valid(_win) then
    vim.api.nvim_win_set_cursor(_win, { _cursor_line, 0 })
  end
end

local function find_first_selectable()
  for i, item in ipairs(_items) do
    if item.type == "installed" or item.type == "available" then
      return i
    end
  end
  return 1
end

local function move_cursor(direction)
  local new_line = _cursor_line + direction
  while new_line >= 1 and new_line <= #_items do
    local item = _items[new_line]
    if item.type == "installed" or item.type == "available" then
      _cursor_line = new_line
      if _win and vim.api.nvim_win_is_valid(_win) then
        vim.api.nvim_win_set_cursor(_win, { _cursor_line, 0 })
      end
      if item.type == "installed" then
        preview_apply(item.theme.colorscheme)
      end
      return
    end
    new_line = new_line + direction
  end
end

local function close()
  if _win and vim.api.nvim_win_is_valid(_win) then
    vim.api.nvim_win_close(_win, true)
  end
  if _buf and vim.api.nvim_buf_is_valid(_buf) then
    vim.api.nvim_buf_delete(_buf, { force = true })
  end
  _win = nil
  _buf = nil
end

local function on_select()
  local item = _items[_cursor_line]
  if not item then return end

  if item.type == "installed" then
    preview_apply(item.theme.colorscheme)
    _original_colorscheme = vim.g.colors_name
    close()
  elseif item.type == "available" then
    local installed = load_installed()
    table.insert(installed, item.theme.name)
    save_installed(installed)
    write_dynamic_spec(item.theme)
    build_items()
    _cursor_line = find_first_selectable()
    render()
    notify.info(item.theme.name .. " added. Restart LuxVim to activate.")
  end
end

local function on_uninstall()
  local item = _items[_cursor_line]
  if not item or item.type ~= "installed" then return end

  if item.is_default then
    notify.warn("Cannot uninstall default theme")
    return
  end

  local installed = load_installed()
  local new_list = {}
  for _, n in ipairs(installed) do
    if n ~= item.theme.name then
      table.insert(new_list, n)
    end
  end
  save_installed(new_list)
  delete_dynamic_spec(item.theme.name)
  notify.info("Removed " .. item.theme.name .. ". Run :Lazy clean to delete files.")
  build_items()
  _cursor_line = find_first_selectable()
  render()
end

local function open()
  _original_colorscheme = vim.g.colors_name
  build_items()

  local width = 50
  local height = #_items + 3
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  _buf = vim.api.nvim_create_buf(false, true)

  _win = vim.api.nvim_open_win(_buf, true, {
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

  vim.bo[_buf].bufhidden = "wipe"
  vim.wo[_win].cursorline = true

  _cursor_line = find_first_selectable()
  render()

  local opts = { buffer = _buf, silent = true }
  vim.keymap.set("n", "j", function() move_cursor(1) end, opts)
  vim.keymap.set("n", "k", function() move_cursor(-1) end, opts)
  vim.keymap.set("n", "<Down>", function() move_cursor(1) end, opts)
  vim.keymap.set("n", "<Up>", function() move_cursor(-1) end, opts)
  vim.keymap.set("n", "<CR>", on_select, opts)
  vim.keymap.set("n", "x", on_uninstall, opts)
  vim.keymap.set("n", "q", function() preview_restore(); close() end, opts)
  vim.keymap.set("n", "<Esc>", function() preview_restore(); close() end, opts)

  if _items[_cursor_line] and _items[_cursor_line].type == "installed" then
    preview_apply(_items[_cursor_line].theme.colorscheme)
  end
end

function M.setup(opts)
  _opts = opts or {}

  vim.api.nvim_create_user_command("Themes", function()
    open()
  end, { desc = "Open theme picker" })
end

return M
