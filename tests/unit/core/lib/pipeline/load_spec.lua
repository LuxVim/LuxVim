-- tests/unit/core/lib/pipeline/load_spec.lua
local load_stage = require("core.lib.pipeline.load")
local tmpdir = require("tests.helpers.tmpdir")

local function ctx_with_files(files)
  return { specs = {}, specs_by_name = {}, errors = {}, warnings = {}, discovered_files = files }
end

describe("pipeline.load", function()
  it("attaches _file/_category/_source metadata to valid specs", function()
    local root, cleanup = tmpdir.new({
      ["foo.lua"] = 'return { source = "a/foo" }',
    })
    local ctx = load_stage.run(ctx_with_files({
      { path = root .. "/foo.lua", category = "editor", source = "framework", defaults = {} },
    }))
    assert.equal(1, #ctx.specs)
    assert.equal(root .. "/foo.lua", ctx.specs[1]._file)
    assert.equal("editor", ctx.specs[1]._category)
    assert.equal("framework", ctx.specs[1]._source)
    cleanup()
  end)

  it("reports a critical error when dofile fails", function()
    local root, cleanup = tmpdir.new({
      ["bad.lua"] = 'syntax !!! error',
    })
    local ctx = load_stage.run(ctx_with_files({
      { path = root .. "/bad.lua", category = "editor", source = "framework", defaults = {} },
    }))
    local criticals = vim.tbl_filter(function(e) return e.level == "critical" end, ctx.errors)
    assert.is_true(#criticals > 0)
    cleanup()
  end)

  it("reports a critical error when the spec is not a table", function()
    local root, cleanup = tmpdir.new({
      ["num.lua"] = 'return 42',
    })
    local ctx = load_stage.run(ctx_with_files({
      { path = root .. "/num.lua", category = "editor", source = "framework", defaults = {} },
    }))
    local criticals = vim.tbl_filter(function(e) return e.level == "critical" end, ctx.errors)
    assert.is_true(#criticals > 0)
    cleanup()
  end)

  it("merges defaults with 'keep' semantics (spec wins)", function()
    local root, cleanup = tmpdir.new({
      ["foo.lua"] = 'return { source = "a/foo", event = "VeryLazy" }',
    })
    local ctx = load_stage.run(ctx_with_files({
      { path = root .. "/foo.lua", category = "editor", source = "framework",
        defaults = { event = "BufReadPost", lazy = true } },
    }))
    assert.equal("VeryLazy", ctx.specs[1].event)
    assert.equal(true, ctx.specs[1].lazy)
    cleanup()
  end)

  it("keys specs_by_name by resolved debug name (basename of source)", function()
    local root, cleanup = tmpdir.new({
      ["foo.lua"] = 'return { source = "author/nvim-tree.lua", debug_name = "nvim-tree" }',
    })
    local ctx = load_stage.run(ctx_with_files({
      { path = root .. "/foo.lua", category = "ui", source = "framework", defaults = {} },
    }))
    assert.is_table(ctx.specs_by_name["nvim-tree"])
    cleanup()
  end)

  it("appends validation errors and warnings", function()
    local root, cleanup = tmpdir.new({
      ["bad.lua"] = 'return { opts = {} }',
    })
    local ctx = load_stage.run(ctx_with_files({
      { path = root .. "/bad.lua", category = "editor", source = "framework", defaults = {} },
    }))
    local criticals = vim.tbl_filter(function(e) return e.level == "critical" end, ctx.errors)
    assert.is_true(#criticals > 0)
    cleanup()
  end)
end)
