local M = {}

local _hooks = {}
local _stages = {}

function M.on(hook_name, fn)
  _hooks[hook_name] = _hooks[hook_name] or {}
  table.insert(_hooks[hook_name], fn)
end

local function run_hooks(name, context)
  local hooks = _hooks[name]
  if not hooks then
    return context
  end
  for _, fn in ipairs(hooks) do
    context = fn(context) or context
  end
  return context
end

function M.register_stage(name, fn)
  table.insert(_stages, { name = name, fn = fn })
end

function M.run()
  local context = {
    specs = {},
    specs_by_name = {},
    errors = {},
    warnings = {},
  }

  for _, stage in ipairs(_stages) do
    context = run_hooks("pre_" .. stage.name, context)
    context = stage.fn(context)
    context = run_hooks("post_" .. stage.name, context)

    local critical = vim.tbl_filter(function(e)
      return e.level == "critical"
    end, context.errors)
    if #critical > 0 then
      break
    end
  end

  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, context.errors)

  context.ok = #critical == 0
  context.raw_specs = context.specs
  return context
end

function M.reset()
  _hooks = {}
  _stages = {}
end

return M
