local debug_mod = require("core.lib.debug")

local M = {}

function M.run(context)
  local framework_specs = {}
  local user_specs = {}

  for _, spec in ipairs(context.specs) do
    if spec._source == "user" then
      table.insert(user_specs, spec)
    else
      table.insert(framework_specs, spec)
    end
  end

  if #user_specs == 0 then
    return context
  end

  local fw_by_name = {}
  for i, spec in ipairs(framework_specs) do
    local name = debug_mod.resolve_debug_name(spec)
    fw_by_name[name] = { index = i, spec = spec }
  end

  local merged = {}
  for _, spec in ipairs(framework_specs) do
    table.insert(merged, spec)
  end

  for _, user_spec in ipairs(user_specs) do
    if user_spec.extends then
      local target = fw_by_name[user_spec.extends]
      if target then
        local base = merged[target.index]
        user_spec.extends = nil
        user_spec._source = nil
        user_spec._category = base._category
        merged[target.index] = vim.tbl_deep_extend("force", base, user_spec)
      else
        table.insert(context.warnings, {
          level = "warning",
          file = user_spec._file or "user",
          message = "extends target '" .. user_spec.extends .. "' not found, treating as new spec",
        })
        table.insert(merged, user_spec)
      end
    elseif user_spec.replaces then
      local target = fw_by_name[user_spec.replaces]
      if target then
        user_spec.replaces = nil
        merged[target.index] = user_spec
      else
        table.insert(context.warnings, {
          level = "warning",
          file = user_spec._file or "user",
          message = "replaces target '" .. user_spec.replaces .. "' not found, treating as new spec",
        })
        table.insert(merged, user_spec)
      end
    else
      table.insert(merged, user_spec)
    end
  end

  context.specs = merged

  context.specs_by_name = {}
  for _, spec in ipairs(merged) do
    local name = debug_mod.resolve_debug_name(spec)
    context.specs_by_name[name] = spec
  end

  return context
end

return M
