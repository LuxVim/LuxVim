local M = {}

function M.run(context)
  -- Validation already happens in load stage (validate_plugin_spec on each spec).
  -- This stage exists as a hook point: users can register pre_validate/post_validate
  -- hooks to add custom validation, modify specs, or filter specs.
  --
  -- Filter out specs that are disabled.
  local filtered = {}
  for _, spec in ipairs(context.specs) do
    if spec.enabled ~= false then
      table.insert(filtered, spec)
    end
  end
  context.specs = filtered
  return context
end

return M
