-- tests/unit/core/lib/validate_spec.lua
local validate = require("core.lib.validate")

describe("validate_plugin_spec", function()
  it("flags missing required source as critical", function()
    local errors, _ = validate.validate_plugin_spec({ opts = {} }, "some/file.lua")
    local criticals = vim.tbl_filter(function(e)
      return e.level == "critical"
    end, errors)
    assert.is_true(#criticals > 0)
  end)

  it("warns on unknown fields", function()
    local _, warnings = validate.validate_plugin_spec({
      source = "a/b",
      not_a_real_field = true,
    }, "some/file.lua")
    local path_match = false
    for _, w in ipairs(warnings) do
      if w.path:match("not_a_real_field") then
        path_match = true
      end
    end
    assert.is_true(path_match)
  end)

  it("flags type mismatch as critical", function()
    local errors, _ = validate.validate_plugin_spec({
      source = 42,
    }, "some/file.lua")
    local criticals = vim.tbl_filter(function(e)
      return e.level == "critical"
    end, errors)
    assert.is_true(#criticals > 0)
  end)

  it("accepts a fully valid spec silently", function()
    local errors, warnings = validate.validate_plugin_spec({
      source = "a/b",
      opts = {},
    }, "some/file.lua")
    local criticals = vim.tbl_filter(function(e)
      return e.level == "critical"
    end, errors)
    assert.equal(0, #criticals)
    assert.equal(0, #warnings)
  end)
end)

describe("validate_autocmd_entry", function()
  it("warns when neither action nor callback is provided", function()
    local _, warnings = validate.validate_autocmd_entry({})
    local msg_match = false
    for _, w in ipairs(warnings) do
      if w.message:match("either") then
        msg_match = true
      end
    end
    assert.is_true(msg_match)
  end)

  it("warns when both action and callback are provided", function()
    local _, warnings = validate.validate_autocmd_entry({
      action = "core.save",
      callback = function() end,
    })
    local msg_match = false
    for _, w in ipairs(warnings) do
      if w.message:match("takes precedence") then
        msg_match = true
      end
    end
    assert.is_true(msg_match)
  end)

  it("accepts action-only silently", function()
    local errors, warnings = validate.validate_autocmd_entry({ action = "core.save" })
    local criticals = vim.tbl_filter(function(e)
      return e.level == "critical"
    end, errors)
    assert.equal(0, #criticals)
    local meaningful_warnings = vim.tbl_filter(function(w)
      return not w.path:match("unknown field")
    end, warnings)
    assert.equal(0, #meaningful_warnings)
  end)

  it("accepts callback-only silently", function()
    local errors, warnings = validate.validate_autocmd_entry({ callback = function() end })
    local criticals = vim.tbl_filter(function(e)
      return e.level == "critical"
    end, errors)
    assert.equal(0, #criticals)
    local meaningful_warnings = vim.tbl_filter(function(w)
      return not w.path:match("unknown field")
    end, warnings)
    assert.equal(0, #meaningful_warnings)
  end)
end)

describe("format_errors", function()
  it("produces a stable format string per error and warning", function()
    local line = validate.format_errors(
      { { level = "critical", path = "spec.source", message = "missing required field" } },
      { { level = "warning", path = "spec.weird", message = "unknown field" } }
    )
    assert.matches("CRITICAL", line)
    assert.matches("WARNING", line)
    assert.matches("spec.source", line)
    assert.matches("spec.weird", line)
  end)
end)
