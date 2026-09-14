-- tests/unit/core/lib/declarations_spec.lua
-- Tests the generic declaration-directory loader: the primitive that turns a
-- directory of one-file-per-thing declarations into rows, with per-directory
-- defaults and a later-directory overlay. Domain-agnostic on purpose — it
-- knows nothing about languages, plugins, or any other product vocabulary.

local declarations = require("core.lib.declarations")
local tmpdir = require("tests.helpers.tmpdir")

describe("core.lib.declarations", function()
  -- Registered rather than cleaned inline so a failing assertion cannot leak
  -- a temp tree; after_each runs even when the test body aborts.
  local cleanups = {}

  local function tmp(tree)
    local root, cleanup = tmpdir.new(tree)
    table.insert(cleanups, cleanup)
    return root
  end

  after_each(function()
    for _, cleanup in ipairs(cleanups) do
      cleanup()
    end
    cleanups = {}
  end)

  it("keys each .lua file by its basename without the extension", function()
    local root = tmp({
      ["go.lua"] = "return { parser = 'go' }",
      ["rust.lua"] = "return { parser = 'rust' }",
    })

    local rows = declarations.load({ dirs = { { path = root } } })

    assert.is_table(rows.go)
    assert.equal("go", rows.go.parser)
    assert.equal("rust", rows.rust.parser)
  end)

  it("ignores files that are not .lua", function()
    local root = tmp({
      ["go.lua"] = "return { parser = 'go' }",
      ["README.md"] = "not a declaration",
      ["notes.txt"] = "also not a declaration",
    })

    local rows = declarations.load({ dirs = { { path = root } } })

    assert.is_table(rows.go)
    assert.is_nil(rows.README)
    assert.is_nil(rows.notes)
  end)

  it("merges _defaults.lua into every row without emitting it as a row", function()
    local root = tmp({
      ["_defaults.lua"] = "return { options = { expandtab = true }, tier = 'stable' }",
      ["go.lua"] = "return { parser = 'go' }",
    })

    local rows = declarations.load({ dirs = { { path = root } } })

    assert.is_nil(rows._defaults)
    assert.equal("stable", rows.go.tier)
    assert.is_true(rows.go.options.expandtab)
  end)

  it("lets a row override a value supplied by _defaults.lua", function()
    local root = tmp({
      ["_defaults.lua"] = "return { tier = 'stable' }",
      ["go.lua"] = "return { tier = 'unstable' }",
    })

    local rows = declarations.load({ dirs = { { path = root } } })

    assert.equal("unstable", rows.go.tier)
  end)

  it("excludes underscore-prefixed files from the rows", function()
    local root = tmp({
      ["_helpers.lua"] = "return { parser = 'nope' }",
      ["go.lua"] = "return { parser = 'go' }",
    })

    local rows = declarations.load({ dirs = { { path = root } } })

    assert.is_nil(rows._helpers)
    assert.is_table(rows.go)
  end)

  it("reports an error and skips a file that fails to load", function()
    local root = tmp({
      ["broken.lua"] = "this is not lua at all (",
      ["go.lua"] = "return { parser = 'go' }",
    })

    local rows, errors = declarations.load({ dirs = { { path = root } } })

    assert.is_nil(rows.broken)
    assert.is_table(rows.go)
    assert.equal(1, #errors)
    assert.is_not_nil(errors[1].file:find("broken.lua", 1, true))
  end)

  it("reports an error and skips a file that does not return a table", function()
    local root = tmp({
      ["bad.lua"] = "return 42",
      ["go.lua"] = "return { parser = 'go' }",
    })

    local rows, errors = declarations.load({ dirs = { { path = root } } })

    assert.is_nil(rows.bad)
    assert.is_table(rows.go)
    assert.equal(1, #errors)
    assert.is_not_nil(errors[1].message:find("table", 1, true))
  end)

  it("returns no rows and no errors for a directory that does not exist", function()
    local rows, errors = declarations.load({
      dirs = { { path = "/nonexistent/luxvim/declarations" } },
    })

    assert.same({}, rows)
    assert.same({}, errors)
  end)

  it("deep-merges a later directory over an earlier one", function()
    local framework = tmp({
      ["go.lua"] = "return { parser = 'go', options = { tabstop = 4, shiftwidth = 4 } }",
    })
    local user = tmp({
      ["go.lua"] = "return { options = { tabstop = 2 } }",
    })

    local rows = declarations.load({
      dirs = { { path = framework }, { path = user } },
    })

    assert.equal("go", rows.go.parser, "keys the user did not touch survive")
    assert.equal(2, rows.go.options.tabstop, "the user value wins")
    assert.equal(4, rows.go.options.shiftwidth, "sibling keys survive the merge")
  end)

  it("discards the earlier row entirely when a later row sets replaces", function()
    local framework = tmp({
      ["go.lua"] = "return { parser = 'go', options = { tabstop = 4 } }",
    })
    local user = tmp({
      ["go.lua"] = "return { replaces = true, parser = 'go' }",
    })

    local rows = declarations.load({
      dirs = { { path = framework }, { path = user } },
    })

    assert.equal("go", rows.go.parser)
    assert.is_nil(rows.go.options, "the framework options must not survive a replace")
    assert.is_nil(rows.go.replaces, "the replaces marker is consumed, not leaked into the row")
  end)

  it("adds rows a later directory introduces that the earlier one lacks", function()
    local framework = tmp({
      ["go.lua"] = "return { parser = 'go' }",
    })
    local user = tmp({
      ["zig.lua"] = "return { parser = 'zig' }",
    })

    local rows = declarations.load({
      dirs = { { path = framework }, { path = user } },
    })

    assert.is_table(rows.go)
    assert.is_table(rows.zig)
  end)

  it("stamps each row with the file it came from and its source label", function()
    local root = tmp({ ["go.lua"] = "return { parser = 'go' }" })

    local rows = declarations.load({
      dirs = { { path = root, source = "framework" } },
    })

    assert.equal("framework", rows.go._source)
    assert.is_not_nil(rows.go._file:find("go.lua", 1, true))
  end)

  it("stamps the winning source when a later directory overrides a row", function()
    local framework = tmp({ ["go.lua"] = "return { parser = 'go' }" })
    local user = tmp({ ["go.lua"] = "return { parser = 'go' }" })

    local rows = declarations.load({
      dirs = {
        { path = framework, source = "framework" },
        { path = user, source = "user" },
      },
    })

    assert.equal("user", rows.go._source)
  end)

  it("does not share mutable default tables between rows", function()
    local root = tmp({
      ["_defaults.lua"] = "return { options = { expandtab = true } }",
      ["go.lua"] = "return {}",
      ["rust.lua"] = "return {}",
    })

    local rows = declarations.load({ dirs = { { path = root } } })
    rows.go.options.expandtab = false

    assert.is_true(rows.rust.options.expandtab, "mutating one row's defaults must not reach into another row")
  end)
end)
