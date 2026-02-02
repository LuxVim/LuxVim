local debug_mod = require("core.lib.debug")
local validate = require("core.lib.validate")
local conditions = require("core.registry.conditions")

local M = {}

M._specs = {}
M._specs_by_name = {}
M._errors = {}
M._warnings = {}

function M.get_plugin_dirs()
  local root = debug_mod.get_luxvim_root()
  local plugins_dir = root .. "/lua/plugins"
  local dirs = {}

  local handle = vim.uv.fs_scandir(plugins_dir)
  if not handle then
    return dirs
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if type == "directory" then
      table.insert(dirs, { name = name, path = plugins_dir .. "/" .. name })
    end
  end

  return dirs
end

function M.load_category_defaults(category_path)
  local defaults_path = category_path .. "/_defaults.lua"
  local stat = vim.uv.fs_stat(defaults_path)
  if not stat then
    return {}
  end

  local ok, defaults = pcall(dofile, defaults_path)
  if ok then
    return defaults
  end
  return {}
end

function M.load_plugin_specs(category_path, category_name, defaults)
  local specs = {}
  local handle = vim.uv.fs_scandir(category_path)
  if not handle then
    return specs
  end

  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if entry_type == "file" and name:match("%.lua$") and name ~= "_defaults.lua" then
      local file_path = category_path .. "/" .. name
      local ok, spec = pcall(dofile, file_path)

      if not ok then
        table.insert(M._errors, {
          level = "critical",
          file = file_path,
          message = "failed to load: " .. tostring(spec),
        })
      elseif type(spec) ~= "table" then
        table.insert(M._errors, {
          level = "critical",
          file = file_path,
          message = "spec must be a table, got " .. type(spec),
        })
      else
        local errors, warnings = validate.validate_plugin_spec(spec, file_path)
        for _, e in ipairs(errors) do
          table.insert(M._errors, { level = e.level, file = file_path, message = e.message })
        end
        for _, w in ipairs(warnings) do
          table.insert(M._warnings, { level = w.level, file = file_path, message = w.message })
        end

        if #errors == 0 then
          spec._file = file_path
          spec._category = category_name
          spec = vim.tbl_deep_extend("keep", spec, defaults)
          table.insert(specs, spec)
        end
      end
    end
  end

  return specs
end

function M.evaluate_condition(cond)
  if cond == nil then
    return true
  end

  if type(cond) == "function" then
    local ok, result = pcall(cond)
    return ok and result
  end

  if type(cond) == "string" then
    local condition_fn = conditions[cond]
    if condition_fn then
      local ok, result = pcall(condition_fn)
      return ok and result
    end
    return false
  end

  return true
end

function M.transform_to_lazy(spec)
  if not M.evaluate_condition(spec.cond) then
    return nil
  end

  if spec.enabled == false then
    return nil
  end

  local debug_name = debug_mod.resolve_debug_name(spec)
  local use_debug = debug_mod.has_debug_plugin(debug_name)

  local lazy_spec = {}

  if use_debug then
    lazy_spec.dir = debug_mod.get_debug_path(debug_name)
    lazy_spec.name = debug_name .. "-debug"
  else
    lazy_spec[1] = spec.source
  end

  if spec.opts then
    lazy_spec.opts = spec.opts
  end

  if spec.config then
    lazy_spec.config = spec.config
  elseif spec.opts and not spec.config then
    lazy_spec.config = true
  end

  if spec.dependencies then
    lazy_spec.dependencies = M.resolve_dependencies(spec.dependencies)
  end

  if spec.event then
    lazy_spec.event = spec.event
  end
  if spec.cmd then
    lazy_spec.cmd = spec.cmd
  end
  if spec.ft then
    lazy_spec.ft = spec.ft
  end
  if spec.keys then
    lazy_spec.keys = spec.keys
  end

  if spec.build then
    lazy_spec.build = M.transform_build(spec.build)
  end

  if spec.lazy then
    if type(spec.lazy) == "table" then
      lazy_spec = vim.tbl_deep_extend("force", lazy_spec, spec.lazy)
    elseif spec.lazy == true then
      lazy_spec.lazy = true
    end
  end

  M._specs_by_name[debug_name] = spec

  return lazy_spec
end

function M.resolve_dependencies(deps)
  local resolved = {}
  for _, dep in ipairs(deps) do
    if type(dep) == "string" then
      if M._specs_by_name[dep] then
        local dep_spec = M._specs_by_name[dep]
        local lazy_dep = M.transform_to_lazy(dep_spec)
        if lazy_dep then
          table.insert(resolved, lazy_dep)
        end
      else
        table.insert(resolved, dep)
      end
    elseif type(dep) == "table" then
      table.insert(resolved, dep)
    end
  end
  return resolved
end

function M.transform_build(build)
  if type(build) == "string" then
    return build
  end

  if type(build) == "table" then
    local cmd = build.cmd
    if build.platforms then
      local platform = vim.fn.has("mac") == 1 and "mac"
          or vim.fn.has("linux") == 1 and "linux"
          or vim.fn.has("win32") == 1 and "windows"
      if build.platforms[platform] then
        cmd = build.platforms[platform]
      end
    end

    if build.requires then
      for _, exe in ipairs(build.requires) do
        if vim.fn.executable(exe) ~= 1 then
          if build.on_fail == "error" then
            error("Build requires " .. exe .. " but it's not available")
          elseif build.on_fail ~= "ignore" then
            vim.notify("[LuxVim] Build skipped: missing " .. exe, vim.log.levels.WARN)
          end
          return nil
        end
      end
    end

    if build.cond then
      if not M.evaluate_condition(build.cond) then
        return nil
      end
    end

    return cmd
  end

  return nil
end

function M.discover_all()
  M._specs = {}
  M._specs_by_name = {}
  M._errors = {}
  M._warnings = {}

  local dirs = M.get_plugin_dirs()

  for _, dir in ipairs(dirs) do
    local defaults = M.load_category_defaults(dir.path)
    local specs = M.load_plugin_specs(dir.path, dir.name, defaults)

    for _, spec in ipairs(specs) do
      table.insert(M._specs, spec)
      local name = debug_mod.resolve_debug_name(spec)
      M._specs_by_name[name] = spec
    end
  end

  return M._specs
end

function M.get_lazy_specs()
  local lazy_specs = {}

  for _, spec in ipairs(M._specs) do
    local lazy_spec = M.transform_to_lazy(spec)
    if lazy_spec then
      table.insert(lazy_specs, lazy_spec)
    end
  end

  return lazy_specs
end

function M.report_errors()
  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, M._errors)

  if #critical > 0 then
    local msg = "[LuxVim] FATAL: Cannot start\n"
    for _, e in ipairs(critical) do
      msg = msg .. "  " .. e.file .. ": " .. e.message .. "\n"
    end
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
    return false
  end

  local non_critical = vim.tbl_filter(function(e)
    return e.level ~= "critical"
  end, M._errors)

  for _, e in ipairs(non_critical) do
    vim.notify("[LuxVim] Plugin skipped: " .. e.file .. "\n  " .. e.message, vim.log.levels.WARN)
  end

  if #M._warnings > 0 then
    vim.defer_fn(function()
      vim.notify("[LuxVim] Started with " .. #M._warnings .. " warnings. Run :LuxVimErrors for details.", vim.log.levels.INFO)
    end, 100)
  end

  return true
end

function M.get_errors()
  return M._errors
end

function M.get_warnings()
  return M._warnings
end

return M
