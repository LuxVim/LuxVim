-- tests/unit/core/lib/pipeline/merge_spec.lua
local merge = require("core.lib.pipeline.merge")

local function fw_spec(name, overrides)
  local s = { source = "framework/" .. name, _source = "framework", _category = "editor" }
  for k, v in pairs(overrides or {}) do
    s[k] = v
  end
  return s
end

local function user_spec(overrides)
  local s = { _source = "user", _file = "user/init.lua" }
  for k, v in pairs(overrides or {}) do
    s[k] = v
  end
  return s
end

local function ctx_with_specs(specs)
  return { specs = specs, specs_by_name = {}, errors = {}, warnings = {} }
end

describe("pipeline.merge", function()
  it("returns context unchanged when no user specs are present", function()
    local a = fw_spec("a")
    local ctx = merge.run(ctx_with_specs({ a }))
    assert.equal(1, #ctx.specs)
    assert.equal(a, ctx.specs[1])
  end)

  it("extends deep-merges scalar and table fields", function()
    local fw = fw_spec("foo", { opts = { a = 1, b = 2 } })
    local user = user_spec({ source = "framework/foo", extends = "foo", opts = { b = 99, c = 3 } })
    local ctx = merge.run(ctx_with_specs({ fw, user }))
    assert.equal(1, #ctx.specs)
    assert.equal(1, ctx.specs[1].opts.a)
    assert.equal(99, ctx.specs[1].opts.b)
    assert.equal(3, ctx.specs[1].opts.c)
  end)

  it("extends overwrites list fields (tbl_deep_extend force semantics)", function()
    local fw = fw_spec("foo", { event = { "BufRead" } })
    local user = user_spec({ source = "framework/foo", extends = "foo", event = { "InsertEnter" } })
    local ctx = merge.run(ctx_with_specs({ fw, user }))
    assert.same({ "InsertEnter" }, ctx.specs[1].event)
  end)

  it("warns and appends when extends target is missing (extends field retained)", function()
    local user = user_spec({ source = "user/dangling", extends = "nowhere" })
    local ctx = merge.run(ctx_with_specs({ user }))
    assert.equal(1, #ctx.warnings)
    assert.equal(1, #ctx.specs)
    assert.equal("nowhere", ctx.specs[1].extends)
  end)

  it("replaces the framework entry at the same index", function()
    local fw = fw_spec("foo", { opts = { original = true } })
    local user = user_spec({ source = "user/foo", replaces = "foo", opts = { replaced = true } })
    local ctx = merge.run(ctx_with_specs({ fw, user }))
    assert.equal(1, #ctx.specs)
    assert.is_nil(ctx.specs[1].opts.original)
    assert.is_true(ctx.specs[1].opts.replaced)
  end)

  it("warns and appends when replaces target is missing (replaces field retained)", function()
    local user = user_spec({ source = "user/new", replaces = "nowhere" })
    local ctx = merge.run(ctx_with_specs({ user }))
    assert.equal(1, #ctx.warnings)
    assert.equal(1, #ctx.specs)
    assert.equal("nowhere", ctx.specs[1].replaces)
  end)

  it("rebuilds specs_by_name after merge", function()
    local fw = fw_spec("foo")
    local user = user_spec({ source = "user/bar" })
    local ctx = merge.run(ctx_with_specs({ fw, user }))
    assert.is_table(ctx.specs_by_name["foo"])
    assert.is_table(ctx.specs_by_name["bar"])
  end)
end)
