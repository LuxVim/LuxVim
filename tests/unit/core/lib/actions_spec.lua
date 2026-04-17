-- tests/unit/core/lib/actions_spec.lua
local actions = require("core.lib.actions")

describe("actions", function()
  describe("new()", function()
    it("returns a fresh instance with empty registry", function()
      local a = actions.new()
      assert.is_table(a._registry)
      assert.is_nil(next(a._registry))
    end)

    it("returns instances that do not share state", function()
      local a1 = actions.new()
      local a2 = actions.new()
      a1:register("ns", "m", function() end)
      assert.is_function(a1._registry.ns.m)
      assert.is_nil((a2._registry.ns or {}).m)
    end)
  end)

  describe(":register / :unregister", function()
    it("stores a function under namespace.method", function()
      local a = actions.new()
      a:register("ns", "m", function() return 42 end)
      local fn, err = a:resolve("ns.m")
      assert.is_nil(err)
      assert.equal(42, fn())
    end)

    it("unregister removes a method", function()
      local a = actions.new()
      a:register("ns", "m", function() end)
      a:unregister("ns", "m")
      local fn, err = a:resolve("ns.m")
      assert.is_nil(fn)
      assert.is_string(err)
    end)
  end)

  describe(":register_namespace", function()
    it("registers an entire table at once", function()
      local a = actions.new()
      a:register_namespace("ns", {
        one = function() return 1 end,
        two = function() return 2 end,
      })
      local one = a:resolve("ns.one")
      local two = a:resolve("ns.two")
      assert.equal(1, one())
      assert.equal(2, two())
    end)
  end)

  describe(":resolve", function()
    it("returns (nil, err) for unregistered action", function()
      local a = actions.new()
      local fn, err = a:resolve("missing.action")
      assert.is_nil(fn)
      assert.matches("unregistered", err)
    end)

    it("returns (nil, err) for malformed action string", function()
      local a = actions.new()
      local fn, err = a:resolve("no_dot")
      assert.is_nil(fn)
      assert.is_string(err)
    end)
  end)

  describe("longest-prefix namespace match", function()
    it("resolves dotted namespaces before first-dot split", function()
      local a = actions.new()
      a:register("fzf.vim", "files", function() return "dotted" end)
      local fn, err = a:resolve("fzf.vim.files")
      assert.is_nil(err)
      assert.equal("dotted", fn())
    end)

    it("falls back to first-dot split when no dotted namespace matches", function()
      local a = actions.new()
      a:register("ns", "action", function() return "short" end)
      local fn = a:resolve("ns.action")
      assert.equal("short", fn())
    end)
  end)

  describe(":invoke", function()
    it("returns true on success", function()
      local a = actions.new()
      local called = false
      a:register("ns", "m", function() called = true end)
      assert.is_true(a:invoke("ns.m"))
      assert.is_true(called)
    end)

    it("returns false and swallows pcall errors", function()
      local a = actions.new()
      a:register("ns", "bad", function() error("boom") end)
      assert.is_false(a:invoke("ns.bad"))
    end)

    it("returns false for unregistered action", function()
      local a = actions.new()
      assert.is_false(a:invoke("nope.nada"))
    end)
  end)

  describe(":register_from_spec", function()
    it("wraps ':command' strings into vim.cmd callables", function()
      local a = actions.new()
      a:register_from_spec({
        source = "virtual",
        debug_name = "core",
        actions = { save = ":write" },
      })
      local fn, err = a:resolve("core.save")
      assert.is_nil(err)
      assert.is_function(fn)
    end)

    it("registers function actions directly", function()
      local a = actions.new()
      local token = {}
      a:register_from_spec({
        source = "virtual",
        debug_name = "core",
        actions = { tok = function() return token end },
      })
      local fn = a:resolve("core.tok")
      assert.equal(token, fn())
    end)

    it("skips invalid action types", function()
      local a = actions.new()
      a:register_from_spec({
        source = "virtual",
        debug_name = "core",
        actions = { bad = 42 },
      })
      local fn, err = a:resolve("core.bad")
      assert.is_nil(fn)
      assert.is_string(err)
    end)

    it("is a no-op when spec has no actions table", function()
      local a = actions.new()
      a:register_from_spec({ source = "x/y" })
      assert.is_nil(next(a._registry))
    end)
  end)

  describe("default() singleton", function()
    it("returns the same instance on repeated calls", function()
      local a = actions.default()
      local b = actions.default()
      assert.equal(a, b)
    end)
  end)

  describe("module-level convenience API", function()
    after_each(function()
      actions.unregister("test_mod", "m")
    end)

    it("actions.register forwards to default", function()
      actions.register("test_mod", "m", function() return "ok" end)
      local fn = actions.default():resolve("test_mod.m")
      assert.equal("ok", fn())
    end)
  end)
end)
