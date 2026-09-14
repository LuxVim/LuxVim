-- tests/unit/core/lib/registry_spec.lua
local registry = require("core.lib.registry")
local tmpdir = require("tests.helpers.tmpdir")

local function with_user_config(root, fn)
  local orig = vim.env.LUXVIM_CONFIG
  vim.env.LUXVIM_CONFIG = root
  local ok, err = pcall(fn)
  vim.env.LUXVIM_CONFIG = orig
  if not ok then
    error(err)
  end
end

describe("registry.new", function()
  it("returns an instance with the configured fields", function()
    local r = registry.new({
      name = "testreg",
      framework = {},
      user_file = "nope.lua",
      register = function()
        return true
      end,
    })
    assert.equal("testreg", r.name)
    assert.is_function(r.register)
  end)

  it("load() returns framework entries when no user file exists", function()
    package.loaded["_test_fw"] = { foo = "bar" }
    local r = registry.new({
      name = "testreg",
      framework = package.loaded["_test_fw"],
      user_file = "no-such-user-file.lua",
      register = function()
        return true
      end,
    })
    local entries, err = r:load()
    assert.is_nil(err)
    assert.equal("bar", entries.foo)
    package.loaded["_test_fw"] = nil
  end)

  it("load() merges user 'extends' into framework entries", function()
    package.loaded["_test_fw"] = { base = { a = 1 } }
    local user_root, cleanup = tmpdir.new({
      ["user.lua"] = "return { extends = true, base = { b = 2 } }",
    })
    with_user_config(user_root, function()
      local r = registry.new({
        name = "testreg",
        framework = package.loaded["_test_fw"],
        user_file = "user.lua",
        register = function()
          return true
        end,
      })
      local entries, err = r:load()
      assert.is_nil(err)
      assert.equal(1, entries.base.a)
      assert.equal(2, entries.base.b)
    end)
    cleanup()
    package.loaded["_test_fw"] = nil
  end)

  it("load() respects user 'replaces' to swap entirely", function()
    package.loaded["_test_fw"] = { base = { a = 1 } }
    local user_root, cleanup = tmpdir.new({
      ["user.lua"] = "return { replaces = true, other = { x = 9 } }",
    })
    with_user_config(user_root, function()
      local r = registry.new({
        name = "testreg",
        framework = package.loaded["_test_fw"],
        user_file = "user.lua",
        register = function()
          return true
        end,
      })
      local entries, err = r:load()
      assert.is_nil(err)
      assert.is_nil(entries.base)
      assert.equal(9, entries.other.x)
    end)
    cleanup()
    package.loaded["_test_fw"] = nil
  end)

  it("load() fails when user file has a syntax error", function()
    package.loaded["_test_fw"] = { foo = "bar" }
    local user_root, cleanup = tmpdir.new({
      ["user.lua"] = "this is not valid lua ::::",
    })
    with_user_config(user_root, function()
      local r = registry.new({
        name = "testreg",
        framework = package.loaded["_test_fw"],
        user_file = "user.lua",
        register = function()
          return true
        end,
      })
      local entries, err = r:load()
      assert.is_nil(entries)
      assert.matches("Failed to load user testreg config", err)
    end)
    cleanup()
    package.loaded["_test_fw"] = nil
  end)

  it("load() rejects a failing user validator when a user file is present", function()
    package.loaded["_test_fw"] = { foo = "bar" }
    local user_root, cleanup = tmpdir.new({
      ["user.lua"] = 'return { extends = true, foo = "baz" }',
    })
    with_user_config(user_root, function()
      local r = registry.new({
        name = "testreg",
        framework = package.loaded["_test_fw"],
        user_file = "user.lua",
        validate_user = function()
          return nil, "user rejected"
        end,
        register = function()
          return true
        end,
      })
      local entries, err = r:load()
      assert.is_nil(entries)
      assert.equal("user rejected", err)
    end)
    cleanup()
    package.loaded["_test_fw"] = nil
  end)

  it("load() rejects a failing entries validator", function()
    package.loaded["_test_fw"] = { foo = "bar" }
    local r = registry.new({
      name = "testreg",
      framework = package.loaded["_test_fw"],
      user_file = "nope.lua",
      validate_entries = function()
        return nil, "entries rejected"
      end,
      register = function()
        return true
      end,
    })
    local entries, err = r:load()
    assert.is_nil(entries)
    assert.equal("entries rejected", err)
    package.loaded["_test_fw"] = nil
  end)

  it("setup() propagates register failure", function()
    package.loaded["_test_fw"] = { foo = "bar" }
    local r = registry.new({
      name = "testreg",
      framework = package.loaded["_test_fw"],
      user_file = "nope.lua",
      register = function()
        return nil, "register boom"
      end,
    })
    local ok, err = r:setup()
    assert.is_nil(ok)
    assert.equal("register boom", err)
    package.loaded["_test_fw"] = nil
  end)

  it("setup() calls register with merged entries and returns true on success", function()
    package.loaded["_test_fw"] = { foo = "bar" }
    local seen
    local r = registry.new({
      name = "testreg",
      framework = package.loaded["_test_fw"],
      user_file = "nope.lua",
      register = function(entries)
        seen = entries
        return true
      end,
    })
    local ok = r:setup()
    assert.is_true(ok)
    assert.equal("bar", seen.foo)
    package.loaded["_test_fw"] = nil
  end)
  -- A registry's entries are not always a hand-written module. The filetype
  -- registry derives its entries from the language declarations, so the source
  -- of "framework entries" has to be injectable without giving up the user
  -- overlay, extends/replaces, or validation that registry.new already owns.
  describe("derived framework entries", function()
    it("load() accepts a framework provider function instead of a module name", function()
      local r = registry.new({
        name = "testreg",
        framework = function()
          return { derived = "yes" }
        end,
        user_file = "no-such-user-file.lua",
        register = function()
          return true
        end,
      })

      local entries, err = r:load()

      assert.is_nil(err)
      assert.equal("yes", entries.derived)
    end)

    it("load() accepts a framework table instead of a module name", function()
      local r = registry.new({
        name = "testreg",
        framework = { derived = "yes" },
        user_file = "no-such-user-file.lua",
        register = function()
          return true
        end,
      })

      local entries, err = r:load()

      assert.is_nil(err)
      assert.equal("yes", entries.derived)
    end)

    it("load() reports an error when the framework provider throws", function()
      local r = registry.new({
        name = "testreg",
        framework = function()
          error("derivation blew up")
        end,
        user_file = "nope.lua",
        register = function()
          return true
        end,
      })

      local entries, err = r:load()

      assert.is_nil(entries)
      assert.matches("Failed to load testreg registry", err)
      -- Without this the assertion above passes for any failure at all,
      -- including one where the provider was never called.
      assert.matches("derivation blew up", err)
    end)

    it("load() still merges a user overlay onto derived entries", function()
      local user_root, cleanup = tmpdir.new({
        ["user.lua"] = 'return { extends = true, added = "by user" }',
      })
      with_user_config(user_root, function()
        local r = registry.new({
          name = "testreg",
          framework = function()
            return { derived = "yes" }
          end,
          user_file = "user.lua",
          register = function()
            return true
          end,
        })

        local entries, err = r:load()

        assert.is_nil(err)
        assert.equal("yes", entries.derived)
        assert.equal("by user", entries.added)
      end)
      cleanup()
    end)
  end)
end)
