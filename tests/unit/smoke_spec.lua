-- tests/unit/smoke_spec.lua
describe("test harness", function()
  it("runs a passing assertion", function()
    assert.equal(2, 1 + 1)
  end)

  it("can require a LuxVim core module", function()
    local paths = require("core.lib.paths")
    assert.equal("a/b", paths.join("a", "b"))
  end)

  it("can require a test helper", function()
    local helpers = require("tests.helpers")
    local spec = helpers.fixtures.build_spec()
    assert.equal("fake/plugin", spec.source)
  end)
end)
