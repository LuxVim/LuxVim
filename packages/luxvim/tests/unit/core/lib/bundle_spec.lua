describe("core.lib.bundle", function()
  local bundle
  local tmpdir = require("tests.helpers.tmpdir")

  before_each(function()
    package.loaded["core.lib.bundle"] = nil
    bundle = require("core.lib.bundle")
  end)

  describe("get_vendor_root", function()
    it("returns $LUXVIM_ROOT/vendor/plugins", function()
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = "/fake/pkg"
      assert.equal("/fake/pkg/vendor/plugins", bundle.get_vendor_root())
      vim.env.LUXVIM_ROOT = original
    end)
  end)

  describe("get_vendored_path", function()
    it("joins vendor_root with plugin name", function()
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = "/fake/pkg"
      assert.equal("/fake/pkg/vendor/plugins/nvim-tree.lua", bundle.get_vendored_path("nvim-tree.lua"))
      vim.env.LUXVIM_ROOT = original
    end)
  end)

  describe("has_vendored_plugin", function()
    it("returns false when vendor dir missing", function()
      local root, cleanup = tmpdir.new({})
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = root
      assert.is_false(bundle.has_vendored_plugin("nothing"))
      vim.env.LUXVIM_ROOT = original
      cleanup()
    end)

    it("returns true when vendor/plugins/<name>/ exists", function()
      local root, cleanup = tmpdir.new({
        vendor = { plugins = { ["nvim-tree.lua"] = { ["init.lua"] = "-- stub" } } },
      })
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = root
      assert.is_true(bundle.has_vendored_plugin("nvim-tree.lua"))
      vim.env.LUXVIM_ROOT = original
      cleanup()
    end)

    it("returns false when vendor/plugins/<name> is a file, not a dir", function()
      local root, cleanup = tmpdir.new({
        vendor = { plugins = { ["nvim-tree.lua"] = "-- not a dir" } },
      })
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = root
      assert.is_false(bundle.has_vendored_plugin("nvim-tree.lua"))
      vim.env.LUXVIM_ROOT = original
      cleanup()
    end)
  end)
end)
