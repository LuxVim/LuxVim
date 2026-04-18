local debug_mod = require("core.lib.debug")
local paths = require("core.lib.paths")

local M = {}

function M.scan_plugin_dirs(base_path)
  local entries = paths.scandir(base_path, function(_, entry_type)
    return entry_type == "directory"
  end)

  local dirs = {}
  for _, entry in ipairs(entries) do
    table.insert(dirs, { name = entry.name, path = paths.join(base_path, entry.name) })
  end
  return dirs
end

function M.scan_category(category_path, category_name)
  local entries = paths.scandir(category_path, function(name, entry_type)
    return entry_type == "file" and name:match("%.lua$") and name ~= "_defaults.lua"
  end)

  local defaults_path = paths.join(category_path, "_defaults.lua")
  local defaults = {}
  if vim.uv.fs_stat(defaults_path) then
    local ok, result = pcall(dofile, defaults_path)
    if ok then
      defaults = result
    end
  end

  local files = {}
  for _, entry in ipairs(entries) do
    table.insert(files, {
      path = paths.join(category_path, entry.name),
      category = category_name,
      defaults = defaults,
      source = "framework",
    })
  end
  return files
end

function M.run(context)
  local root = debug_mod.get_luxvim_root()
  local plugins_dir = paths.join(root, "lua", "plugins")

  local dirs = M.scan_plugin_dirs(plugins_dir)

  if #dirs == 0 then
    table.insert(context.errors, {
      level = "critical",
      file = "core.lib.pipeline.discover",
      message = "Plugin directory not found: " .. plugins_dir
          .. "\nLuxVim root detected as: " .. root
          .. "\nLaunch LuxVim from its directory or check installation.",
    })
    return context
  end

  local files = {}
  for _, dir in ipairs(dirs) do
    local category_files = M.scan_category(dir.path, dir.name)
    for _, f in ipairs(category_files) do
      table.insert(files, f)
    end
  end

  -- Scan dynamic-specs directory (for theme picker and other dynamic plugins)
  local data = require("core.lib.data")
  local dynamic_dir = data.dynamic_specs_dir()
  if vim.uv.fs_stat(dynamic_dir) then
    local dynamic_entries = paths.scandir(dynamic_dir, function(name, entry_type)
      return entry_type == "file" and name:match("%.lua$")
    end)
    for _, entry in ipairs(dynamic_entries) do
      table.insert(files, {
        path = paths.join(dynamic_dir, entry.name),
        category = "dynamic",
        defaults = {},
        source = "dynamic",
      })
    end
  end

  -- Scan user plugin directories
  local user_config = data.user_config_path()
  local user_plugins_dir = paths.join(user_config, "plugins")
  if vim.uv.fs_stat(user_plugins_dir) then
    local user_dirs = M.scan_plugin_dirs(user_plugins_dir)
    for _, dir in ipairs(user_dirs) do
      local category_files = M.scan_category(dir.path, dir.name)
      for _, f in ipairs(category_files) do
        f.source = "user"
        table.insert(files, f)
      end
    end
  end

  context.discovered_files = files
  return context
end

return M
