local catalog = require("core.theme-picker.catalog")
local persistence = require("core.theme-picker.persistence")

local M = {}

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

function M.build_items()
  local items = {}
  local current = vim.g.colors_name or ""

  table.insert(items, { type = "header", text = "  INSTALLED" })

  local installed = get_installed_themes()
  for _, entry in ipairs(installed) do
    local prefix = "    "
    if entry.theme.colorscheme == current or
       (entry.theme.variants and vim.tbl_contains(entry.theme.variants, current)) then
      prefix = "  ● "
    end
    table.insert(items, {
      type = "installed",
      theme = entry.theme,
      is_default = entry.is_default,
      text = prefix .. entry.theme.name,
    })
  end

  table.insert(items, { type = "separator", text = "" })
  table.insert(items, { type = "header", text = "  AVAILABLE" })

  local available = get_available_themes()
  if #available == 0 then
    table.insert(items, { type = "empty", text = "    (all themes installed)" })
  else
    for _, theme in ipairs(available) do
      local desc = theme.description or ""
      if #desc > 25 then
        desc = desc:sub(1, 22) .. "..."
      end
      table.insert(items, {
        type = "available",
        theme = theme,
        text = string.format("    %-14s %s", theme.name, desc),
      })
    end
  end

  return items
end

function M.render(buf, items)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  vim.bo[buf].modifiable = true

  local lines = {}
  for _, item in ipairs(items) do
    table.insert(lines, item.text)
  end
  table.insert(lines, "")
  table.insert(lines, "  [Enter] Apply  [x] Uninstall  [q] Close")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

return M
