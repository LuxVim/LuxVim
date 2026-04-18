-- tests/unit/core/lib/pipeline/discover_spec.lua
local discover = require("core.lib.pipeline.discover")
local debug_mod = require("core.lib.debug")
local data_mod = require("core.lib.data")
local tmpdir = require("tests.helpers.tmpdir")

local function fresh_ctx()
  return { specs = {}, specs_by_name = {}, errors = {}, warnings = {} }
end

local function with_luxvim_root(root, fn)
  local orig = debug_mod.get_luxvim_root
  debug_mod.get_luxvim_root = function() return root end
  local ok, err = pcall(fn)
  debug_mod.get_luxvim_root = orig
  if not ok then error(err) end
end

local function with_luxvim_data_root(root, fn)
  local orig_env = vim.env.LUXVIM_ROOT
  local orig_stdpath = vim.fn.stdpath
  vim.env.LUXVIM_ROOT = root
  vim.fn.stdpath = function(name)
    if name == "data" then
      return root .. "/data"
    end
    return orig_stdpath(name)
  end
  package.loaded["core.lib.data"] = nil
  data_mod = require("core.lib.data")
  local ok, err = pcall(fn)
  vim.env.LUXVIM_ROOT = orig_env
  vim.fn.stdpath = orig_stdpath
  package.loaded["core.lib.data"] = nil
  data_mod = require("core.lib.data")
  if not ok then error(err) end
end

describe("pipeline.discover", function()
  it("returns a critical error when the plugins dir is missing", function()
    local root, cleanup = tmpdir.new({ lua = {} })
    with_luxvim_root(root, function()
      with_luxvim_data_root(root, function()
        local ctx = discover.run(fresh_ctx())
        local criticals = vim.tbl_filter(function(e) return e.level == "critical" end, ctx.errors)
        assert.is_true(#criticals > 0)
      end)
    end)
    cleanup()
  end)

  it("discovers .lua files per category, ignoring _defaults.lua", function()
    local root, cleanup = tmpdir.new({
      lua = {
        plugins = {
          editor = {
            ["_defaults.lua"] = 'return { event = "BufReadPost" }',
            ["foo.lua"] = 'return { source = "a/foo" }',
            ["bar.lua"] = 'return { source = "a/bar" }',
          },
        },
      },
    })
    with_luxvim_root(root, function()
      with_luxvim_data_root(root, function()
        local ctx = discover.run(fresh_ctx())
        local names = {}
        for _, f in ipairs(ctx.discovered_files) do
          table.insert(names, f.path:match("([^/]+)$"))
        end
        table.sort(names)
        assert.same({ "bar.lua", "foo.lua" }, names)
      end)
    end)
    cleanup()
  end)

  it("attaches per-category _defaults to each discovered file", function()
    local root, cleanup = tmpdir.new({
      lua = {
        plugins = {
          editor = {
            ["_defaults.lua"] = 'return { event = "BufReadPost" }',
            ["foo.lua"] = 'return { source = "a/foo" }',
          },
        },
      },
    })
    with_luxvim_root(root, function()
      with_luxvim_data_root(root, function()
        local ctx = discover.run(fresh_ctx())
        assert.equal("BufReadPost", ctx.discovered_files[1].defaults.event)
        assert.equal("editor", ctx.discovered_files[1].category)
        assert.equal("framework", ctx.discovered_files[1].source)
      end)
    end)
    cleanup()
  end)

  it("includes data/dynamic-specs files with source='dynamic'", function()
    local root, cleanup = tmpdir.new({
      lua = { plugins = { editor = { ["foo.lua"] = 'return { source = "a/foo" }' } } },
      data = { ["dynamic-specs"] = { ["dyn.lua"] = 'return { source = "d/dyn" }' } },
    })
    with_luxvim_root(root, function()
      with_luxvim_data_root(root, function()
        local ctx = discover.run(fresh_ctx())
        local sources = {}
        for _, f in ipairs(ctx.discovered_files) do
          sources[f.source] = (sources[f.source] or 0) + 1
        end
        assert.equal(1, sources.framework)
        assert.equal(1, sources.dynamic)
      end)
    end)
    cleanup()
  end)

  it("includes user plugins with source='user'", function()
    local root, cleanup = tmpdir.new({
      lua = { plugins = { editor = { ["foo.lua"] = 'return { source = "a/foo" }' } } },
    })
    local user_root, user_cleanup = tmpdir.new({
      plugins = { ui = { ["user-widget.lua"] = 'return { source = "u/widget" }' } },
    })
    local orig_env = vim.env.LUXVIM_CONFIG
    vim.env.LUXVIM_CONFIG = user_root
    with_luxvim_root(root, function()
      with_luxvim_data_root(root, function()
        local ctx = discover.run(fresh_ctx())
        local sources = {}
        for _, f in ipairs(ctx.discovered_files) do
          sources[f.source] = (sources[f.source] or 0) + 1
        end
        assert.equal(1, sources.framework)
        assert.equal(1, sources.user)
      end)
    end)
    vim.env.LUXVIM_CONFIG = orig_env
    user_cleanup()
    cleanup()
  end)
end)
