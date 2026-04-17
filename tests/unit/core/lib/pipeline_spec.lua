-- tests/unit/core/lib/pipeline_spec.lua
local pipeline = require("core.lib.pipeline")

local function noop_stage(ctx) return ctx end

describe("pipeline", function()
  describe("new()", function()
    it("returns an instance with empty hooks and stages", function()
      local p = pipeline.new()
      assert.is_nil(next(p._hooks))
      assert.equal(0, #p._stages)
    end)

    it("returns instances that do not share state", function()
      local p1 = pipeline.new()
      local p2 = pipeline.new()
      p1:register_stage("s", noop_stage)
      assert.equal(1, #p1._stages)
      assert.equal(0, #p2._stages)
    end)
  end)

  describe(":register_stage", function()
    it("preserves insertion order", function()
      local p = pipeline.new()
      local order = {}
      p:register_stage("a", function(c) table.insert(order, "a"); return c end)
      p:register_stage("b", function(c) table.insert(order, "b"); return c end)
      p:register_stage("c", function(c) table.insert(order, "c"); return c end)
      p:run()
      assert.same({ "a", "b", "c" }, order)
    end)
  end)

  describe(":on / hooks", function()
    it("fires pre_<stage> before stage fn and post_<stage> after", function()
      local p = pipeline.new()
      local order = {}
      p:on("pre_a", function(c) table.insert(order, "pre"); return c end)
      p:on("post_a", function(c) table.insert(order, "post"); return c end)
      p:register_stage("a", function(c) table.insert(order, "stage"); return c end)
      p:run()
      assert.same({ "pre", "stage", "post" }, order)
    end)

    it("supports multiple hooks for the same name (insertion order)", function()
      local p = pipeline.new()
      local order = {}
      p:on("pre_a", function(c) table.insert(order, "first"); return c end)
      p:on("pre_a", function(c) table.insert(order, "second"); return c end)
      p:register_stage("a", noop_stage)
      p:run()
      assert.same({ "first", "second" }, order)
    end)

    it("hooks can mutate context; returned context replaces input", function()
      local p = pipeline.new()
      p:on("pre_a", function(c) c.mutated = true; return c end)
      p:register_stage("a", function(c) return c end)
      local result = p:run()
      assert.is_true(result.mutated)
    end)
  end)

  describe(":run", function()
    it("produces a context with ok=true when no errors", function()
      local p = pipeline.new()
      p:register_stage("noop", noop_stage)
      local r = p:run()
      assert.is_true(r.ok)
    end)

    it("aliases raw_specs to specs at completion", function()
      local p = pipeline.new()
      p:register_stage("set_specs", function(c)
        c.specs = { "a", "b" }
        return c
      end)
      local r = p:run()
      assert.same({ "a", "b" }, r.raw_specs)
    end)

    it("aborts remaining stages on critical error", function()
      local p = pipeline.new()
      local hit_after = false
      p:register_stage("bad", function(c)
        table.insert(c.errors, { level = "critical", file = "x", message = "boom" })
        return c
      end)
      p:register_stage("after", function(c)
        hit_after = true
        return c
      end)
      local r = p:run()
      assert.is_false(hit_after)
      assert.is_false(r.ok)
    end)

    it("does not abort on non-critical errors", function()
      local p = pipeline.new()
      local hit_after = false
      p:register_stage("warn", function(c)
        table.insert(c.errors, { level = "warning", file = "x", message = "meh" })
        return c
      end)
      p:register_stage("after", function(c)
        hit_after = true
        return c
      end)
      local r = p:run()
      assert.is_true(hit_after)
      assert.is_true(r.ok)
    end)
  end)

  describe(":reset", function()
    it("clears hooks and stages on an instance", function()
      local p = pipeline.new()
      p:register_stage("a", noop_stage)
      p:on("pre_a", function(c) return c end)
      p:reset()
      assert.equal(0, #p._stages)
      assert.is_nil(next(p._hooks))
    end)
  end)

  describe("default() singleton", function()
    it("returns the same instance on repeated calls", function()
      local a = pipeline.default()
      local b = pipeline.default()
      assert.equal(a, b)
    end)

    it("module-level reset() replaces the default", function()
      local before = pipeline.default()
      pipeline.reset()
      local after = pipeline.default()
      assert.not_equal(before, after)
    end)
  end)

  describe("module-level convenience API", function()
    after_each(function()
      pipeline.reset()
    end)

    it("pipeline.register_stage / pipeline.run operate on default", function()
      pipeline.reset()
      local ran = false
      pipeline.register_stage("m", function(c) ran = true; return c end)
      pipeline.run()
      assert.is_true(ran)
    end)
  end)
end)
