-- tests/unit/languages_manifest_spec.lua
-- Drift guard over the SHIPPED lua/languages/ declarations.
--
-- core.lib.languages_spec proves the machinery against fixtures; this proves
-- the real directory the machinery is pointed at. Without the non-vacuity
-- assertion below, renaming or moving lua/languages/ would empty every
-- downstream check — provisioning, health, and filetype options would all
-- quietly agree there is nothing to do, and every test here would still pass.

local languages = require("core.lib.languages")
local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")

local function framework_dirs()
  -- Framework directory ONLY. Loading default_dirs() here would let a
  -- developer's ~/.config/luxvim/languages/ decide whether CI passes.
  return { { path = paths.join(debug_mod.get_luxvim_root(), "lua", "languages"), source = "framework" } }
end

describe("lua/languages declarations", function()
  local rows, errors

  before_each(function()
    rows, errors = languages.load({ dirs = framework_dirs() })
  end)

  it("is not empty", function()
    assert.is_true(
      #rows > 0,
      "lua/languages/ resolved to zero declarations — every derived check "
        .. "(provisioning, health, filetype options) is now silently a no-op"
    )
  end)

  it("loads every declaration without error", function()
    assert.same({}, errors)
  end)

  it("declares go, the language whose missing parser this registry exists to prevent", function()
    local names = vim.tbl_map(function(row)
      return row.name
    end, rows)

    assert.is_true(vim.tbl_contains(names, "go"))
  end)

  it("never lets two languages claim the same filetype", function()
    local owner = {}
    for _, row in ipairs(rows) do
      for _, filetype in ipairs(row.filetypes) do
        assert.is_nil(
          owner[filetype],
          (
            "filetype '%s' is claimed by both '%s' and '%s'; the options and "
            .. "parser it resolves to would depend on load order"
          ):format(filetype, tostring(owner[filetype]), row.name)
        )
        owner[filetype] = row.name
      end
    end
  end)

  it("never declares options on a language that owns no filetype", function()
    for _, row in ipairs(rows) do
      if next(row.options) then
        assert.is_true(
          #row.filetypes > 0,
          ("'%s' declares options but no filetypes, so those options can " .. "never be applied"):format(row.name)
        )
      end
    end
  end)

  it("gives every declaration a parser name or an explicit parser = false", function()
    for _, row in ipairs(rows) do
      assert.is_true(
        row.parser == false or type(row.parser) == "string",
        ("'%s' has a parser of type %s"):format(row.name, type(row.parser))
      )
    end
  end)
end)
