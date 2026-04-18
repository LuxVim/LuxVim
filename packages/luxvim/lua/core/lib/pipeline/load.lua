local debug_mod = require("core.lib.debug")
local validate = require("core.lib.validate")

local M = {}

function M.run(context)
  local files = context.discovered_files or {}
  local specs = {}
  local specs_by_name = {}

  for _, file in ipairs(files) do
    local ok, spec = pcall(dofile, file.path)

    if not ok then
      table.insert(context.errors, {
        level = "critical",
        file = file.path,
        message = "failed to load: " .. tostring(spec),
      })
    elseif type(spec) ~= "table" then
      table.insert(context.errors, {
        level = "critical",
        file = file.path,
        message = "spec must be a table, got " .. type(spec),
      })
    else
      local errors, warnings = validate.validate_plugin_spec(spec, file.path)
      for _, e in ipairs(errors) do
        table.insert(context.errors, { level = e.level or "critical", file = file.path, message = e.message })
      end
      for _, w in ipairs(warnings) do
        table.insert(context.warnings, { level = "warning", file = file.path, message = w.message })
      end

      if #errors == 0 then
        spec._file = file.path
        spec._category = file.category
        spec._source = file.source or "framework"
        spec = vim.tbl_deep_extend("keep", spec, file.defaults)

        local name = debug_mod.resolve_debug_name(spec)
        table.insert(specs, spec)
        specs_by_name[name] = spec
      end
    end
  end

  context.specs = specs
  context.specs_by_name = specs_by_name
  return context
end

return M
