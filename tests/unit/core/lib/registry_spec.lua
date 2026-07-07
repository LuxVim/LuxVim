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
      framework_module = "does.not.matter",
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
      framework_module = "_test_fw",
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

  it("load() fails when framework_module cannot be required", function()
    local r = registry.new({
      name = "testreg",
      framework_module = "definitely.not.a.module.xyz",
      user_file = "nope.lua",
      register = function()
        return true
      end,
    })
    local entries, err = r:load()
    assert.is_nil(entries)
    assert.matches("Failed to load testreg registry", err)
  end)

  it("load() merges user 'extends' into framework entries", function()
    package.loaded["_test_fw"] = { base = { a = 1 } }
    local user_root, cleanup = tmpdir.new({
      ["user.lua"] = "return { extends = true, base = { b = 2 } }",
    })
    with_user_config(user_root, function()
      local r = registry.new({
        name = "testreg",
        framework_module = "_test_fw",
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
        framework_module = "_test_fw",
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
        framework_module = "_test_fw",
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
        framework_module = "_test_fw",
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
      framework_module = "_test_fw",
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
      framework_module = "_test_fw",
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
      framework_module = "_test_fw",
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
end)
