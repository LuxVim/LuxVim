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
  for _, t in ipairs(_opts.themes or {}) do
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
  local seen = {}

  -- Picker-managed themes from persistence file
  local managed = load_installed()
  for _, name in ipairs(managed) do
    local theme = find_theme(name)
    if theme then
      seen[theme.name] = true
      table.insert(installed, { theme = theme, is_managed = true })
    end
  end

  -- Current active colorscheme (from plugin specs like colorschemes.lua)
  local current = vim.g.colors_name
  if current and not seen[current] then
    -- Check if it matches a catalog theme
    for _, theme in ipairs(_opts.themes or {}) do
      if theme.colorscheme == current or
          (theme.variants and vim.tbl_contains(theme.variants, current)) then
        if not seen[theme.name] then
          seen[theme.name] = true
          table.insert(installed, 1, { theme = theme, is_managed = false })
        end
        break
      end
    end
    -- If not in catalog, show raw colorscheme name
    if not seen[current] then
      table.insert(installed, 1, {
        theme = { name = current, colorscheme = current },
        is_managed = false,
      })
    end
  end

  return installed, seen
end

local function get_available_themes()
  local _, installed_set = get_installed_themes()

  local available = {}
  for _, theme in ipairs(_opts.themes or {}) do
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
  if #installed == 0 then
    table.insert(_items, { type = "empty", text = "    (no themes installed)" })
  else
    for _, entry in ipairs(installed) do
      local prefix = "    "
      if entry.theme.colorscheme == current or
          (entry.theme.variants and vim.tbl_contains(entry.theme.variants, current)) then
        prefix = "  * "
      end
      table.insert(_items, {
        type = "installed",
        theme = entry.theme,
        is_managed = entry.is_managed,
        text = prefix .. entry.theme.name,
      })
    end
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
  table.insert(lines, "  [Enter] Apply  [i] Install  [x] Uninstall  [q] Close")

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

local function install_theme(theme)
  -- Save to persistence and write dynamic spec for next startup
  local installed = load_installed()
  table.insert(installed, theme.name)
  save_installed(installed)
  write_dynamic_spec(theme)

  -- Clone directly into lazy's plugin directory — no lazy UI involved
  local lazy_root = data.lazy_root()
  local plugin_name = theme.repo:match("[^/]+$")
  local install_path = paths.join(lazy_root, plugin_name)

  if not vim.uv.fs_stat(install_path) then
    notify.info("Installing " .. theme.name .. "...")
    vim.fn.system({
      "git", "clone", "--filter=blob:none",
      "https://github.com/" .. theme.repo .. ".git",
      install_path,
    })
    if vim.v.shell_error ~= 0 then
      notify.error("Failed to install " .. theme.name)
      return
    end
  end

  -- Add to runtimepath so colorscheme is available immediately
  vim.opt.rtp:prepend(install_path)

  -- Rebuild picker UI — theme moves from AVAILABLE to INSTALLED
  build_items()
  _cursor_line = find_first_selectable()
  render()
  notify.info(theme.name .. " installed! Navigate to it and press Enter to apply.")
end

local function on_select()
  local item = _items[_cursor_line]
  if not item then return end

  if item.type == "installed" then
    preview_apply(item.theme.colorscheme)
    _original_colorscheme = vim.g.colors_name
    close()
  end
end

local function on_install()
  local item = _items[_cursor_line]
  if not item or item.type ~= "available" then return end
  install_theme(item.theme)
end

local function on_uninstall()
  local item = _items[_cursor_line]
  if not item or item.type ~= "installed" then return end

  if not item.is_managed then
    notify.warn("This theme is installed via a plugin spec, not the theme picker")
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
  preview_restore()
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

  local kopts = { buffer = _buf, silent = true }
  vim.keymap.set("n", "j", function() move_cursor(1) end, kopts)
  vim.keymap.set("n", "k", function() move_cursor(-1) end, kopts)
  vim.keymap.set("n", "<Down>", function() move_cursor(1) end, kopts)
  vim.keymap.set("n", "<Up>", function() move_cursor(-1) end, kopts)
  vim.keymap.set("n", "<CR>", on_select, kopts)
  vim.keymap.set("n", "i", on_install, kopts)
  vim.keymap.set("n", "x", on_uninstall, kopts)
  vim.keymap.set("n", "q", function() preview_restore(); close() end, kopts)
  vim.keymap.set("n", "<Esc>", function() preview_restore(); close() end, kopts)

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
