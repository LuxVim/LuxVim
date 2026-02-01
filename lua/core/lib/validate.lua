local schema = require("core.lib.schema")

local M = {}

M.errors = {
  CRITICAL = "critical",
  WARNING = "warning",
}

local function type_matches(value, expected_type)
  if type(expected_type) == "string" then
    if expected_type == "list" then
      return type(value) == "table" and vim.islist(value)
    end
    return type(value) == expected_type
  elseif type(expected_type) == "table" then
    if expected_type.type then
      return type_matches(value, expected_type.type)
    end
    for _, t in ipairs(expected_type) do
      if type_matches(value, t) then
        return true
      end
    end
    return false
  end
  return false
end

function M.validate_against(value, schema_def, path)
  local errors = {}
  local warnings = {}
  path = path or "spec"

  if type(value) ~= "table" then
    table.insert(errors, {
      level = M.errors.CRITICAL,
      path = path,
      message = "must be a table, got " .. type(value),
    })
    return errors, warnings
  end

  for field, rules in pairs(schema_def) do
    local field_value = value[field]
    local field_path = path .. "." .. field

    if rules.required and field_value == nil then
      table.insert(errors, {
        level = M.errors.CRITICAL,
        path = field_path,
        message = "missing required field",
      })
    elseif field_value ~= nil and rules.type then
      if not type_matches(field_value, rules.type) then
        table.insert(errors, {
          level = M.errors.CRITICAL,
          path = field_path,
          message = "expected " .. vim.inspect(rules.type) .. ", got " .. type(field_value),
        })
      end
    end
  end

  for field, _ in pairs(value) do
    if not schema_def[field] then
      local known_fields = vim.tbl_keys(schema_def)
      table.sort(known_fields)
      table.insert(warnings, {
        level = M.errors.WARNING,
        path = path .. "." .. field,
        message = "unknown field (known: " .. table.concat(known_fields, ", ") .. ")",
      })
    end
  end

  return errors, warnings
end

function M.validate_plugin_spec(spec, file_path)
  return M.validate_against(spec, schema.plugin_spec, file_path or "plugin")
end

function M.format_errors(errors, warnings)
  local lines = {}
  for _, err in ipairs(errors) do
    table.insert(lines, string.format("[%s] %s: %s", err.level:upper(), err.path, err.message))
  end
  for _, warn in ipairs(warnings) do
    table.insert(lines, string.format("[%s] %s: %s", warn.level:upper(), warn.path, warn.message))
  end
  return table.concat(lines, "\n")
end

return M
