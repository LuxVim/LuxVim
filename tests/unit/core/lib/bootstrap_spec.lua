-- tests/unit/core/lib/bootstrap_spec.lua
local bootstrap = require("core.lib.bootstrap")
local data = require("core.lib.data")

describe("core.lib.bootstrap", function()
  describe("lazy_opts", function()
    it("passes provided specs into spec field", function()
      local dummy_specs = { { "some/plugin" } }
      local opts = bootstrap.lazy_opts(dummy_specs)
      assert.same(dummy_specs, opts.spec)
    end)

    it("resets rtp for performance", function()
      local opts = bootstrap.lazy_opts({})
      assert.is_true(opts.performance.rtp.reset)
    end)

    it("preserves LuxVim root in rtp paths across reset so checkhealth is discoverable", function()
      local opts = bootstrap.lazy_opts({})
      assert.is_table(opts.performance.rtp.paths)
      assert.is_true(vim.tbl_contains(opts.performance.rtp.paths, data.root()))
    end)

    it("configures lazy root and lockfile paths via data module", function()
      local opts = bootstrap.lazy_opts({})
      assert.equal(data.lazy_root(), opts.root)
      assert.equal(data.lockfile_path(), opts.lockfile)
    end)
  end)

  describe("setup_lazy", function()
    -- NEGATIVE-TEST CONTRACT: fails if setup_lazy stops handing lazy_opts()
    -- to lazy.setup. A correct lazy_opts is worthless if the table never
    -- reaches lazy -- that is exactly the ":checkhealth luxvim -> No
    -- healthcheck found" bug this commit fixes.
    it("hands lazy_opts through to lazy.setup so rtp paths actually reach lazy", function()
      local real_ensure = bootstrap.ensure_lazy
      local prev_lazy = package.loaded["lazy"]
      local captured
      bootstrap.ensure_lazy = function() end
      package.loaded["lazy"] = {
        setup = function(o)
          captured = o
        end,
      }

      local ok, err = pcall(bootstrap.setup_lazy, { { "some/plugin" } })

      bootstrap.ensure_lazy = real_ensure
      package.loaded["lazy"] = prev_lazy

      assert.is_true(ok, tostring(err))
      assert.is_table(captured)
      assert.same(bootstrap.lazy_opts({ { "some/plugin" } }), captured)
      assert.is_table(captured.performance.rtp.paths)
      assert.is_true(vim.tbl_contains(captured.performance.rtp.paths, data.root()))
    end)

    it("bootstraps lazy.nvim before configuring it", function()
      local real_ensure = bootstrap.ensure_lazy
      local prev_lazy = package.loaded["lazy"]
      local order = {}
      bootstrap.ensure_lazy = function()
        table.insert(order, "ensure_lazy")
      end
      package.loaded["lazy"] = {
        setup = function()
          table.insert(order, "lazy.setup")
        end,
      }

      local ok, err = pcall(bootstrap.setup_lazy, {})

      bootstrap.ensure_lazy = real_ensure
      package.loaded["lazy"] = prev_lazy

      assert.is_true(ok, tostring(err))
      assert.same({ "ensure_lazy", "lazy.setup" }, order)
    end)
  end)
end)
