local debug_mod = require("core.lib.debug")
local validate = require("core.lib.validate")
local paths = require("core.lib.paths")

local M = {}

M._specs = {}
M._specs_by_name = {}

function M.get_plugin_dirs(diagnostics)
  local root = debug_mod.get_luxvim_root()
  local plugins_dir = paths.join(root, "lua", "plugins")

  local entries = paths.scandir(plugins_dir, function(_, entry_type)
    return entry_type == "directory"
  end)

  if #entries == 0 then
    diagnostics:add_error("core.lib.discover",
      "Plugin directory not found: " .. plugins_dir ..
      "\nLuxVim root detected as: " .. root ..
      "\nLaunch LuxVim from its directory or check installation.")
  end

  local dirs = {}
  for _, entry in ipairs(entries) do
    table.insert(dirs, { name = entry.name, path = paths.join(plugins_dir, entry.name) })
  end
  return dirs
end

function M.load_category_defaults(category_path)
  local defaults_path = paths.join(category_path, "_defaults.lua")
  if not paths.is_file(defaults_path) then
    return {}
  end

  local ok, defaults = pcall(dofile, defaults_path)
  if ok then
    return defaults
  end
  return {}
end

function M.load_plugin_specs(category_path, category_name, defaults, diagnostics)
  local specs = {}

  local entries = paths.scandir(category_path, function(name, entry_type)
    return entry_type == "file" and name:match("%.lua$") and name ~= "_defaults.lua"
  end)

  for _, entry in ipairs(entries) do
    local file_path = paths.join(category_path, entry.name)
    local ok, spec = pcall(dofile, file_path)

    if not ok then
      diagnostics:add_error(file_path, "failed to load: " .. tostring(spec))
    elseif type(spec) ~= "table" then
      diagnostics:add_error(file_path, "spec must be a table, got " .. type(spec))
    else
      local errors, warnings = validate.validate_plugin_spec(spec, file_path)
      diagnostics:collect(file_path, errors, warnings)

      if #errors == 0 then
        spec._file = file_path
        spec._category = category_name
        spec = vim.tbl_deep_extend("keep", spec, defaults)
        table.insert(specs, spec)
      end
    end
  end

  return specs
end

function M.discover_all(diagnostics)
  M._specs = {}
  M._specs_by_name = {}

  local dirs = M.get_plugin_dirs(diagnostics)

  for _, dir in ipairs(dirs) do
    local defaults = M.load_category_defaults(dir.path)
    local specs = M.load_plugin_specs(dir.path, dir.name, defaults, diagnostics)

    for _, spec in ipairs(specs) do
      table.insert(M._specs, spec)
      local name = debug_mod.resolve_debug_name(spec)
      M._specs_by_name[name] = spec
    end
  end

  return M._specs
end

return M
