local debug_mod = require("core.lib.debug")
local paths = require("core.lib.paths")
local platform = require("core.lib.platform")
local conditions = require("core.registry.conditions")
local notify = require("core.lib.notify")

local M = {}

local passthrough_fields = { "event", "cmd", "ft", "keys" }

local function normname(name)
  return tostring(name or "")
    :lower()
    :gsub("^n?vim%-", "")
    :gsub("%.n?vim$", "")
    :gsub("[%.%-]lua", "")
    :gsub("[^a-z]+", "")
end

local function lua_modules(lua_dir)
  local modules = {}
  local handle = vim.uv.fs_scandir(lua_dir)
  if not handle then
    return modules
  end

  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if entry_type == "file" and name:match("%.lua$") then
      table.insert(modules, name:gsub("%.lua$", ""))
    elseif entry_type == "directory" and vim.uv.fs_stat(paths.join(lua_dir, name, "init.lua")) then
      table.insert(modules, name)
    end
  end

  return modules
end

local function infer_debug_main(debug_name, debug_path)
  local modules = lua_modules(paths.join(debug_path, "lua"))
  local target = normname(debug_name)

  for _, module in ipairs(modules) do
    if normname(module) == target then
      return module
    end
  end

  if #modules == 1 then
    return modules[1]
  end

  return nil
end

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

function M.transform_one(spec, specs_by_name)
  -- Virtual specs have no plugin code — they're framework-internal containers
  -- for actions and config. Processed directly by core/init.lua, not lazy.nvim.
  if spec.source == "virtual" then
    return nil
  end

  local debug_name = debug_mod.resolve_debug_name(spec)
  local use_debug = debug_mod.has_debug_plugin(debug_name)

  local lazy_spec = {}

  if use_debug then
    local debug_path = debug_mod.get_debug_path(debug_name)
    lazy_spec.dir = debug_path
    lazy_spec.name = debug_name .. "-debug"
    lazy_spec.main = infer_debug_main(debug_name, debug_path)
  else
    lazy_spec[1] = spec.source
  end

  if spec.opts then
    lazy_spec.opts = spec.opts
  end

  if spec.config ~= nil then
    lazy_spec.config = spec.config
  elseif spec.opts then
    lazy_spec.config = true
  end

  if spec.dependencies then
    lazy_spec.dependencies = M.resolve_dependencies(spec.dependencies, specs_by_name)
  end

  for _, field in ipairs(passthrough_fields) do
    if spec[field] then
      lazy_spec[field] = spec[field]
    end
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

  if spec.globals then
    local lazy_init = lazy_spec.init
    lazy_spec.init = function()
      for key, value in pairs(spec.globals) do
        vim.g[key] = value
      end
      if lazy_init then
        lazy_init()
      end
    end
  end

  -- Defer condition evaluation to lazy.nvim
  if spec.cond ~= nil then
    local cond = spec.cond
    lazy_spec.cond = function()
      return M.evaluate_condition(cond)
    end
  end

  return lazy_spec
end

function M.run(context)
  local lazy_specs = {}

  for _, spec in ipairs(context.specs) do
    local lazy_spec = M.transform_one(spec, context.specs_by_name)
    if lazy_spec then
      table.insert(lazy_specs, lazy_spec)
    end
  end

  context.lazy_specs = lazy_specs
  return context
end

return M
