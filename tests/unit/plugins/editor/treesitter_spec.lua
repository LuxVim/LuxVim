-- tests/unit/plugins/editor/treesitter_spec.lua
-- Tests that the treesitter plugin config wires all three runtime pieces:
-- nvim-treesitter's install_dir, the FileType failure reporter, and parser
-- provisioning (both the background self-heal and the blocking command the
-- installer drives).

-- Captured before any stubbing so the stub mirrors the real contract and the
-- expected command name stays derived rather than duplicated here.
local real_provision = require("core.lib.provision")
local real_languages = require("core.lib.languages")

describe("plugins.editor.treesitter", function()
  local root = vim.fn.getcwd()
  local saved = {}
  local ensure_calls, buffers, declared_rows, warns, saved_start, saved_uis

  local function stub(name, value)
    if not saved[name] then
      saved[name] = { present = package.loaded[name] ~= nil, value = package.loaded[name] }
    end
    package.loaded[name] = value
  end

  local function load_spec()
    return dofile(root .. "/lua/plugins/editor/treesitter.lua")
  end

  local function buffer(filetype)
    local buf = vim.api.nvim_create_buf(true, false)
    table.insert(buffers, buf)
    vim.bo[buf].filetype = filetype
    return buf
  end

  local function startup()
    load_spec().config()
    assert.is_true(vim.wait(1000, function()
      return #ensure_calls > 0
    end))
  end

  before_each(function()
    -- Drain any vim.schedule() left pending by the previous test BEFORE
    -- resetting the recorder, or its provisioning callback lands in this
    -- test's tally.
    vim.wait(20)
    ensure_calls = {}
    saved = {}
    buffers, declared_rows, warns = {}, {}, {}
    saved_start = vim.treesitter.start
    saved_uis = vim.api.nvim_list_uis

    stub("core.lib.languages", {
      rows = function()
        return declared_rows
      end,
      by_filetype = real_languages.by_filetype,
    })
    stub("core.lib.notify", {
      info = function() end,
      warn = function(msg)
        table.insert(warns, msg)
      end,
    })
    stub("core.lib.treesitter_report", nil)

    stub("core.lib.provision", {
      COMMAND = real_provision.COMMAND,
      BOOTSTRAP_TIMEOUT_MS = real_provision.BOOTSTRAP_TIMEOUT_MS,
      ensure = function(_, opts)
        table.insert(ensure_calls, opts or {})
      end,
    })
    stub("nvim-treesitter.config", {
      setup = function() end,
      get_available = function()
        return { "zig" }
      end,
    })

    pcall(vim.api.nvim_del_user_command, real_provision.COMMAND)
  end)

  after_each(function()
    vim.wait(20)
    pcall(vim.api.nvim_del_augroup_by_name, "LuxVimTreesitter")
    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    vim.treesitter.start = saved_start
    vim.api.nvim_list_uis = saved_uis
    for name, entry in pairs(saved) do
      package.loaded[name] = entry.present and entry.value or nil
    end
    pcall(vim.api.nvim_del_user_command, real_provision.COMMAND)
  end)

  it("hands nvim-treesitter the LuxVim install_dir", function()
    local setup_opts
    stub("nvim-treesitter.config", {
      setup = function(opts)
        setup_opts = opts
      end,
      get_available = function()
        return {}
      end,
    })

    load_spec().config()

    assert.is_table(setup_opts)
    assert.is_string(setup_opts.install_dir)
  end)

  it("reports a treesitter failure through the FileType autocmd", function()
    stub("core.lib.notify", {
      warn = function(msg)
        table.insert(warns, msg)
      end,
      info = function() end,
    })
    package.loaded["core.lib.treesitter_report"] = nil

    local orig_start = vim.treesitter.start
    vim.treesitter.start = function()
      error("simulated start failure")
    end

    load_spec().config()
    vim.api.nvim_exec_autocmds("FileType", { pattern = "zig", modeline = false })
    vim.api.nvim_exec_autocmds("FileType", { pattern = "zig", modeline = false })
    vim.api.nvim_exec_autocmds("FileType", { pattern = "unavailable_lang", modeline = false })

    vim.treesitter.start = orig_start
    package.loaded["core.lib.treesitter_report"] = nil

    assert.equal(1, #warns, "expected exactly one deduped warning")
    assert.is_not_nil(warns[1]:find("zig", 1, true))
  end)

  it("provisions missing declared parsers in the background at startup", function()
    -- The self-heal that makes a language declaration sufficient on its own:
    -- add lua/languages/go.lua, restart, get a parser. Without it a
    -- declaration is only honored by re-running the installer.
    load_spec().config()
    vim.wait(100, function()
      return #ensure_calls > 0
    end)

    assert.equal(1, #ensure_calls)
  end)

  it("does not block startup on the parser install", function()
    -- Negative partner to the blocking command below: installing a parser
    -- compiles C, so the startup path must never wait on it.
    load_spec().config()
    vim.wait(100, function()
      return #ensure_calls > 0
    end)

    assert.is_nil(ensure_calls[1].wait_ms)
  end)

  it("defines the provisioning command", function()
    load_spec().config()

    assert.equal(2, vim.fn.exists(":" .. real_provision.COMMAND))
  end)

  it("makes the provisioning command block, so headless bootstrap cannot exit early", function()
    load_spec().config()
    vim.wait(100, function()
      return #ensure_calls > 0
    end)
    local before = #ensure_calls

    vim.cmd(real_provision.COMMAND)

    assert.equal(before + 1, #ensure_calls)
    assert.is_true(ensure_calls[#ensure_calls].wait_ms > 0)
  end)

  it("keeps an interactive session open after a blocking install fails", function()
    local deps = {
      missing = function()
        return { "lua" }
      end,
      install = function()
        return {
          wait = function()
            return false
          end,
        }
      end,
      info = function() end,
      warn = function(msg)
        table.insert(warns, msg)
      end,
    }
    startup()
    package.loaded["core.lib.provision"].ensure = function(_, opts)
      return real_provision.ensure(deps, opts)
    end
    vim.api.nvim_list_uis = function()
      return { {} }
    end

    assert.has_no.errors(function()
      vim.cmd(real_provision.COMMAND)
    end)

    assert.equal(1, #warns)
    assert.is_not_nil(warns[1]:find("install failed", 1, true))
  end)

  describe("attachment after provisioning", function()
    local attempts, ready, attached

    before_each(function()
      attempts, ready, attached = {}, {}, {}
      declared_rows = {
        { name = "luatest", parser = "lua", filetypes = { "luatest", "luatest2" } },
        { name = "rusttest", parser = "rust", filetypes = { "rusttest" } },
        { name = "ignored", parser = false, filetypes = { "ignored" } },
      }
      package.loaded["nvim-treesitter.config"].get_available = function()
        return { "lua", "rust" }
      end
      vim.treesitter.start = function(buf, lang)
        table.insert(attempts, { buf = buf, lang = lang })
        if not ready[lang] then
          error("parser has not been built")
        end
        attached[buf] = lang
      end
      startup()
      assert.is_function(ensure_calls[1].on_complete)
    end)

    it("retries every open buffer using a newly available declared parser", function()
      local first, second = buffer("luatest"), buffer("luatest2")
      assert.same({}, attached)
      assert.equal(2, #attempts)
      local failures = require("core.lib.treesitter_report").failures
      assert.is_not_nil(failures.luatest)

      ready.lua = true
      ensure_calls[1].on_complete({ "lua" })

      assert.equal("lua", attached[first])
      assert.equal("lua", attached[second])
      assert.equal(4, #attempts)
      assert.equal(2, #warns, "retry uses the original reporter's warning dedupe")
      assert.is_not_nil(failures.luatest, "historical failures remain available to health")
    end)

    it("skips closed, unloaded, changed, unrelated, and parser-disabled buffers", function()
      local closed, unloaded, changed = buffer("luatest"), buffer("luatest"), buffer("luatest")
      buffer("rusttest")
      buffer("ignored")
      vim.api.nvim_buf_delete(closed, { force = true })
      vim.api.nvim_buf_delete(unloaded, { force = true, unload = true })
      vim.bo[changed].filetype = "rusttest"
      assert.is_true(vim.api.nvim_buf_is_valid(unloaded))
      assert.is_false(vim.api.nvim_buf_is_loaded(unloaded))
      local before = #attempts

      ready.lua = true
      assert.has_no.errors(function()
        ensure_calls[1].on_complete({ "lua" })
      end)

      assert.equal(before, #attempts)
      assert.same({}, attached)
    end)

    it("attaches the successful subset of a partially failed installation", function()
      local lua_buf, rust_buf = buffer("luatest"), buffer("rusttest")
      ready.lua = true

      ensure_calls[1].on_complete({ "lua" }, "rust build failed")

      assert.equal("lua", attached[lua_buf])
      assert.is_nil(attached[rust_buf])
      assert.equal(3, #attempts)
    end)

    it("does not retry when no parser became available", function()
      buffer("luatest")

      ensure_calls[1].on_complete({}, "build failed")

      assert.equal(1, #attempts)
      assert.same({}, attached)
    end)

    it("deduplicates warnings if attachment still fails after installation", function()
      buffer("luatest")
      assert.equal(1, #warns)

      ensure_calls[1].on_complete({ "lua" })

      assert.equal(2, #attempts)
      assert.equal(1, #warns)
    end)

    it("also retries open buffers after the manual provisioning command", function()
      local buf = buffer("luatest")
      vim.cmd(real_provision.COMMAND)
      assert.is_true(ensure_calls[2].wait_ms > 0)
      ready.lua = true

      ensure_calls[2].on_complete({ "lua" })

      assert.equal("lua", attached[buf])
      assert.equal(2, #attempts)
    end)
  end)
end)
