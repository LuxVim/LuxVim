-- tests/unit/core/lib/pipeline/transform_spec.lua
local transform = require("core.lib.pipeline.transform")

describe("pipeline.transform", function()
  it("returns nil for virtual specs", function()
    local r = transform.transform_one({ source = "virtual", debug_name = "core" }, {})
    assert.is_nil(r)
  end)

  it("sets [1]=source for non-debug specs", function()
    local r = transform.transform_one({ source = "author/plugin" }, {})
    assert.equal("author/plugin", r[1])
    assert.is_nil(r.dir)
  end)

  it("applies config=true shortcut when opts is set but config is not", function()
    local r = transform.transform_one({ source = "a/b", opts = { x = 1 } }, {})
    assert.is_true(r.config)
  end)

  it("passes through a user-provided config function", function()
    local fn = function() end
    local r = transform.transform_one({ source = "a/b", config = fn }, {})
    assert.equal(fn, r.config)
  end)

  it("copies passthrough fields (event, cmd, ft, keys)", function()
    local r = transform.transform_one({
      source = "a/b",
      event = { "BufRead" },
      cmd = "X",
      ft = "lua",
      keys = { "<leader>x" },
    }, {})
    assert.same({ "BufRead" }, r.event)
    assert.equal("X", r.cmd)
    assert.equal("lua", r.ft)
    assert.same({ "<leader>x" }, r.keys)
  end)

  it("passes string build through unchanged", function()
    local r = transform.transform_one({ source = "a/b", build = ":make" }, {})
    assert.equal(":make", r.build)
  end)

  it("wraps globals via the init function", function()
    local r = transform.transform_one({
      source = "a/b",
      globals = { my_flag = 7 },
    }, {})
    assert.is_function(r.init)
    r.init()
    assert.equal(7, vim.g.my_flag)
    vim.g.my_flag = nil
  end)

  it("defers cond to a function lazy.nvim will invoke", function()
    local r = transform.transform_one({ source = "a/b", cond = function() return true end }, {})
    assert.is_function(r.cond)
    assert.is_true(r.cond())
  end)

  it("resolves dependencies through specs_by_name", function()
    local dep = { source = "d/dep" }
    local main = { source = "m/main", dependencies = { "dep" } }
    local specs_by_name = { dep = dep, main = main }
    local r = transform.transform_one(main, specs_by_name)
    assert.is_table(r.dependencies)
    assert.equal(1, #r.dependencies)
    assert.equal("d/dep", r.dependencies[1][1])
  end)

  it("passes unknown dependency names through as strings", function()
    local main = { source = "m/main", dependencies = { "unknown" } }
    local r = transform.transform_one(main, {})
    assert.equal("unknown", r.dependencies[1])
  end)

  it("sets dir/name when a vendored plugin is detected", function()
    local bundle_mod = require("core.lib.bundle")
    local orig_has = bundle_mod.has_vendored_plugin
    local orig_path = bundle_mod.get_vendored_path
    bundle_mod.has_vendored_plugin = function(name) return name == "myplugin" end
    bundle_mod.get_vendored_path = function(name) return "/fake/vendor/" .. name end

    local r = transform.transform_one({ source = "x/myplugin" }, {})
    assert.equal("/fake/vendor/myplugin", r.dir)
    assert.equal("myplugin", r.name)
    assert.is_nil(r[1])

    bundle_mod.has_vendored_plugin = orig_has
    bundle_mod.get_vendored_path = orig_path
  end)

  describe("transform_build", function()
    it("returns the cmd field for a plain table build", function()
      local cmd = transform.transform_build({ cmd = ":make" })
      assert.equal(":make", cmd)
    end)

    it("uses platform-specific cmd when the current OS is mapped", function()
      local platform = require("core.lib.platform")
      local orig = platform.os
      platform.os = "mac"
      local cmd = transform.transform_build({
        cmd = "default",
        platforms = { mac = "mac-specific" },
      })
      assert.equal("mac-specific", cmd)
      platform.os = orig
    end)

    it("falls back to default cmd when the platform is not mapped", function()
      local platform = require("core.lib.platform")
      local orig = platform.os
      platform.os = "linux"
      local cmd = transform.transform_build({
        cmd = "default",
        platforms = { windows = "win-only" },
      })
      assert.equal("default", cmd)
      platform.os = orig
    end)

    it("returns nil when a required executable is missing and on_fail=ignore", function()
      local orig = vim.fn.executable
      vim.fn.executable = function() return 0 end
      local cmd = transform.transform_build({
        cmd = ":make",
        requires = { "not-a-real-binary-xyz" },
        on_fail = "ignore",
      })
      assert.is_nil(cmd)
      vim.fn.executable = orig
    end)

    it("raises when a required executable is missing and on_fail=error", function()
      local orig = vim.fn.executable
      vim.fn.executable = function() return 0 end
      assert.has_error(function()
        transform.transform_build({
          cmd = ":make",
          requires = { "not-a-real-binary-xyz" },
          on_fail = "error",
        })
      end)
      vim.fn.executable = orig
    end)

    it("notifies when a required executable is missing and on_fail defaults to warn", function()
      local notify = require("core.lib.notify")
      local orig_warn = notify.warn
      local orig_exec = vim.fn.executable
      local warned
      notify.warn = function(msg) warned = msg end
      vim.fn.executable = function() return 0 end

      local cmd = transform.transform_build({
        cmd = ":make",
        requires = { "not-a-real-binary-xyz" },
      })

      assert.is_nil(cmd)
      assert.is_string(warned)
      assert.matches("missing", warned)

      notify.warn = orig_warn
      vim.fn.executable = orig_exec
    end)

    it("returns nil when build cond evaluates to false", function()
      local cmd = transform.transform_build({
        cmd = ":make",
        cond = function() return false end,
      })
      assert.is_nil(cmd)
    end)
  end)
end)
