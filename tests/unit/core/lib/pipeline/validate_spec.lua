-- tests/unit/core/lib/pipeline/validate_spec.lua
local validate = require("core.lib.pipeline.validate")

local function ctx_with_specs(specs)
  return { specs = specs, specs_by_name = {}, errors = {}, warnings = {} }
end

describe("pipeline.validate (stage)", function()
  it("keeps specs without an enabled field", function()
    local ctx = validate.run(ctx_with_specs({
      { source = "a/b" },
    }))
    assert.equal(1, #ctx.specs)
  end)

  it("keeps specs with enabled=true", function()
    local ctx = validate.run(ctx_with_specs({
      { source = "a/b", enabled = true },
    }))
    assert.equal(1, #ctx.specs)
  end)

  it("filters out specs with enabled=false", function()
    local ctx = validate.run(ctx_with_specs({
      { source = "a/b", enabled = true },
      { source = "c/d", enabled = false },
    }))
    assert.equal(1, #ctx.specs)
    assert.equal("a/b", ctx.specs[1].source)
  end)
end)
