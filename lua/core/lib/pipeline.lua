-- lua/core/lib/pipeline.lua
-- Factory-pattern pipeline orchestrator. Production uses
-- pipeline.default(); tests use pipeline.new(). Module-level reset()
-- swaps the default for a fresh instance (production hot-reload primitive).

local Pipeline = {}
Pipeline.__index = Pipeline

function Pipeline:on(hook_name, fn)
  self._hooks[hook_name] = self._hooks[hook_name] or {}
  table.insert(self._hooks[hook_name], fn)
end

function Pipeline:_run_hooks(name, context)
  local hooks = self._hooks[name]
  if not hooks then
    return context
  end
  for _, fn in ipairs(hooks) do
    context = fn(context) or context
  end
  return context
end

function Pipeline:register_stage(name, fn)
  table.insert(self._stages, { name = name, fn = fn })
end

local function has_critical(context)
  for _, e in ipairs(context.errors) do
    if e.level == "critical" then
      return true
    end
  end
  return false
end

function Pipeline:run()
  local context = {
    specs = {},
    specs_by_name = {},
    errors = {},
    warnings = {},
  }

  for _, stage in ipairs(self._stages) do
    context = self:_run_hooks("pre_" .. stage.name, context)
    context = stage.fn(context)
    context = self:_run_hooks("post_" .. stage.name, context)
    if has_critical(context) then
      break
    end
  end

  context.ok = not has_critical(context)
  context.raw_specs = context.specs
  return context
end

function Pipeline:reset()
  self._hooks = {}
  self._stages = {}
end

local M = {}

function M.new()
  return setmetatable({ _hooks = {}, _stages = {} }, Pipeline)
end

local _default
function M.default()
  if not _default then
    _default = M.new()
  end
  return _default
end

function M.on(hook_name, fn)        return M.default():on(hook_name, fn) end
function M.register_stage(name, fn) return M.default():register_stage(name, fn) end
function M.run()                    return M.default():run() end
function M.reset()                  _default = M.new() end

return M
