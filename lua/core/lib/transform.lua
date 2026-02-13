local debug_mod = require("core.lib.debug")
local conditions = require("core.registry.conditions")
local platform = require("core.lib.platform")
local notify = require("core.lib.notify")

local M = {}

local passthrough_fields = { "event", "cmd", "ft", "keys" }

local function safe_eval(fn)
  local ok, result = pcall(fn)
  return ok and result
end

function M.evaluate_condition(cond)
  if cond == nil then
    return true
  end

  if type(cond) == "function" then
    return safe_eval(cond)
  end

  if type(cond) == "string" then
    local condition_fn = conditions[cond]
    if condition_fn then
      return safe_eval(condition_fn)
    end
    return false
  end

  return true
end

function M.apply_condition(spec)
  if not M.evaluate_condition(spec.cond) then
    return nil
  end

  if spec.enabled == false then
    return nil
  end

  return spec
end

function M.apply_debug_routing(lazy_spec, spec)
  local debug_name = debug_mod.resolve_debug_name(spec)
  local use_debug = debug_mod.has_debug_plugin(debug_name)

  if use_debug then
    lazy_spec.dir = debug_mod.get_debug_path(debug_name)
    lazy_spec.name = debug_name .. "-debug"
  else
    lazy_spec[1] = spec.source
  end

  return lazy_spec
end

function M.apply_config(lazy_spec, spec)
  if spec.opts then
    lazy_spec.opts = spec.opts
  end

  if spec.config ~= nil then
    lazy_spec.config = spec.config
  elseif spec.opts then
    lazy_spec.config = true
  end

  return lazy_spec
end

function M.apply_dependencies(lazy_spec, spec, specs_by_name)
  if not spec.dependencies then
    return lazy_spec
  end

  lazy_spec.dependencies = M.resolve_dependencies(spec.dependencies, specs_by_name)
  return lazy_spec
end

function M.resolve_dependencies(deps, specs_by_name)
  local resolved = {}
  for _, dep in ipairs(deps) do
    if type(dep) == "string" then
      if specs_by_name[dep] then
        local dep_spec = specs_by_name[dep]
        local lazy_dep = M.transform_one(dep_spec, specs_by_name)
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

function M.apply_passthrough_fields(lazy_spec, spec)
  for _, field in ipairs(passthrough_fields) do
    if spec[field] then
      lazy_spec[field] = spec[field]
    end
  end
  return lazy_spec
end

function M.apply_build(lazy_spec, spec)
  if not spec.build then
    return lazy_spec
  end

  lazy_spec.build = M.transform_build(spec.build)
  return lazy_spec
end

function M.transform_build(build)
  if type(build) == "string" then
    return build
  end

  if type(build) == "table" then
    local cmd = build.cmd
    if build.platforms then
      if build.platforms[platform.os] then
        cmd = build.platforms[platform.os]
      end
    end

    if build.requires then
      for _, exe in ipairs(build.requires) do
        if vim.fn.executable(exe) ~= 1 then
          if build.on_fail == "error" then
            error("Build requires " .. exe .. " but it's not available")
          elseif build.on_fail ~= "ignore" then
            notify.warn("Build skipped: missing " .. exe)
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

function M.apply_lazy_passthrough(lazy_spec, spec)
  if not spec.lazy then
    return lazy_spec
  end

  if type(spec.lazy) == "table" then
    return vim.tbl_deep_extend("force", lazy_spec, spec.lazy)
  elseif spec.lazy == true then
    lazy_spec.lazy = true
  end

  return lazy_spec
end

function M.apply_globals(lazy_spec, spec)
  if not spec.globals then
    return lazy_spec
  end

  local lazy_init = lazy_spec.init
  lazy_spec.init = function()
    for key, value in pairs(spec.globals) do
      vim.g[key] = value
    end
    if lazy_init then
      lazy_init()
    end
  end

  return lazy_spec
end

function M.transform_one(spec, specs_by_name)
  if not M.apply_condition(spec) then
    return nil
  end

  local lazy_spec = {}
  lazy_spec = M.apply_debug_routing(lazy_spec, spec)
  lazy_spec = M.apply_config(lazy_spec, spec)
  lazy_spec = M.apply_dependencies(lazy_spec, spec, specs_by_name)
  lazy_spec = M.apply_passthrough_fields(lazy_spec, spec)
  lazy_spec = M.apply_build(lazy_spec, spec)
  lazy_spec = M.apply_lazy_passthrough(lazy_spec, spec)
  lazy_spec = M.apply_globals(lazy_spec, spec)

  return lazy_spec
end

function M.transform_all(specs, specs_by_name)
  local lazy_specs = {}

  for _, spec in ipairs(specs) do
    local lazy_spec = M.transform_one(spec, specs_by_name)
    if lazy_spec then
      table.insert(lazy_specs, lazy_spec)
    end
  end

  return lazy_specs
end

return M
