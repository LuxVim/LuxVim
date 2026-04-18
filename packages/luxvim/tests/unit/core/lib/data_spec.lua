describe("core.lib.data", function()
  local data
  local original_stdpath

  before_each(function()
    package.loaded["core.lib.data"] = nil
    data = require("core.lib.data")
    original_stdpath = vim.fn.stdpath
  end)

  after_each(function()
    vim.fn.stdpath = original_stdpath
  end)

  local function stub_stdpath(map)
    vim.fn.stdpath = function(name)
      return map[name] or error("unexpected stdpath(" .. tostring(name) .. ")")
    end
  end

  describe("state_root", function()
    it("returns vim.fn.stdpath('data')", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data", data.state_root())
    end)
  end)

  describe("lazy_root", function()
    it("is under state_root (not $LUXVIM_ROOT/data)", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/lazy", data.lazy_root())
    end)
  end)

  describe("lazy_path", function()
    it("is state_root/lazy/lazy.nvim", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/lazy/lazy.nvim", data.lazy_path())
    end)
  end)

  describe("luxlsp_path", function()
    it("is state_root/luxlsp", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/luxlsp", data.luxlsp_path())
    end)
  end)

  describe("parser_path", function()
    it("is state_root/site", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/site", data.parser_path())
    end)
  end)

  describe("installed_themes_path", function()
    it("is state_root/installed-themes.json", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/installed-themes.json", data.installed_themes_path())
    end)
  end)

  describe("dynamic_specs_dir", function()
    it("is state_root/dynamic-specs", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/dynamic-specs", data.dynamic_specs_dir())
    end)
  end)

  describe("lockfile_path", function()
    it("stays under the LuxVim package root (read-only)", function()
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = "/fake/pkg"
      assert.equal("/fake/pkg/lazy-lock.json", data.lockfile_path())
      vim.env.LUXVIM_ROOT = original
    end)
  end)

  describe("user_config_path", function()
    it("respects $LUXVIM_CONFIG when set", function()
      local original = vim.env.LUXVIM_CONFIG
      vim.env.LUXVIM_CONFIG = "/custom/luxvim-config"
      assert.equal("/custom/luxvim-config", data.user_config_path())
      vim.env.LUXVIM_CONFIG = original
    end)

    it("uses $XDG_CONFIG_HOME/LuxVim (capitalized) by default", function()
      local orig_lc = vim.env.LUXVIM_CONFIG
      local orig_xdg = vim.env.XDG_CONFIG_HOME
      vim.env.LUXVIM_CONFIG = nil
      vim.env.XDG_CONFIG_HOME = "/fake/config"
      assert.equal("/fake/config/LuxVim", data.user_config_path())
      vim.env.LUXVIM_CONFIG = orig_lc
      vim.env.XDG_CONFIG_HOME = orig_xdg
    end)
  end)
end)
