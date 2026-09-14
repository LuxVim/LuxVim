-- tests/unit/core/lib/provision_spec.lua
-- Tests the step that closes the actual gap: making the declared parsers
-- exist. Before this, nothing in LuxVim ever installed a parser — install.sh
-- synced plugins only, and `build = ":TSUpdate"` updates parsers that are
-- already installed, so a fresh install had zero and every file opened with
-- treesitter dead.

local provision = require("core.lib.provision")
local tmpdir = require("tests.helpers.tmpdir")

local function make_deps(overrides)
  local captured = { installed = {}, infos = {}, warns = {}, waits = {}, remaining = { "go", "rust" } }
  captured.finish = function(err, result, remaining)
    captured.remaining = remaining or (result == true and {} or captured.remaining)
    captured.callback(err, result)
  end
  local deps = {
    missing = function()
      return captured.remaining
    end,
    install = function(langs)
      table.insert(captured.installed, langs)
      return {
        wait = function(_, timeout)
          table.insert(captured.waits, timeout)
          captured.remaining = {}
          return true
        end,
        await = function(_, callback)
          captured.callback = callback
        end,
      }
    end,
    info = function(msg)
      table.insert(captured.infos, msg)
    end,
    warn = function(msg)
      table.insert(captured.warns, msg)
    end,
  }
  return vim.tbl_extend("force", deps, overrides or {}), captured
end

describe("core.lib.provision", function()
  describe("when every declared parser is present", function()
    it("installs nothing", function()
      local deps, captured = make_deps({
        missing = function()
          return {}
        end,
      })

      provision.ensure(deps)

      assert.same({}, captured.installed)
    end)

    it("says nothing, so a healthy startup stays silent", function()
      local deps, captured = make_deps({
        missing = function()
          return {}
        end,
      })

      provision.ensure(deps)

      assert.same({}, captured.infos)
      assert.same({}, captured.warns)
    end)

    it("reports that nothing was missing", function()
      local deps = make_deps({
        missing = function()
          return {}
        end,
      })

      assert.same({}, provision.ensure(deps))
    end)
  end)

  describe("when declared parsers are missing", function()
    it("installs exactly the missing ones", function()
      local deps, captured = make_deps({})

      provision.ensure(deps)

      assert.equal(1, #captured.installed)
      assert.same({ "go", "rust" }, captured.installed[1])
    end)

    it("announces what it is installing so a slow first launch is explicable", function()
      local deps, captured = make_deps({})

      provision.ensure(deps)

      assert.equal(1, #captured.infos)
      assert.is_not_nil(captured.infos[1]:find("go", 1, true))
      assert.is_not_nil(captured.infos[1]:find("rust", 1, true))
    end)

    it("returns the languages it acted on", function()
      local deps = make_deps({})

      assert.same({ "go", "rust" }, provision.ensure(deps))
    end)
  end)

  describe("blocking mode", function()
    it("waits for the install when given a timeout, for bootstrap scripts", function()
      local deps, captured = make_deps({})

      local _, err = provision.ensure(deps, { wait_ms = 300000 })

      assert.same({ 300000 }, captured.waits)
      assert.is_nil(err)
    end)

    -- Negative partner: startup must NOT block the editor on a compile.
    it("does not wait when no timeout is given", function()
      local deps, captured = make_deps({})

      provision.ensure(deps)

      assert.same({}, captured.waits)
      assert.is_function(captured.callback)
    end)
  end)

  describe("failure handling", function()
    it("warns instead of throwing when the installer errors", function()
      local deps, captured = make_deps({
        install = function()
          error("tree-sitter CLI not found")
        end,
      })

      local _, err = provision.ensure(deps)
      assert.is_string(err)
      assert.equal(1, #captured.warns)
      assert.is_not_nil(captured.warns[1]:find("tree-sitter CLI not found", 1, true))
    end)

    it("warns instead of throwing when waiting on the install errors", function()
      local deps, captured = make_deps({
        install = function()
          return {
            wait = function()
              error("timed out")
            end,
          }
        end,
      })

      local _, err = provision.ensure(deps, { wait_ms = 1 })
      assert.is_not_nil(err:find("timed out", 1, true))
      assert.equal(1, #captured.warns)
    end)

    it("reports a failed task result even when wait does not throw", function()
      local deps, captured = make_deps({
        install = function()
          return {
            wait = function()
              return false
            end,
          }
        end,
      })

      local acted, err = provision.ensure(deps, { wait_ms = 100 })

      assert.same({ "go", "rust" }, acted)
      assert.is_not_nil(err:find("install failed", 1, true))
      assert.equal(1, #captured.warns)
    end)

    it("rejects a successful task that leaves a requested parser missing", function()
      local deps, captured = make_deps({
        install = function()
          return {
            wait = function()
              return true
            end,
          }
        end,
      })

      local _, err = provision.ensure(deps, { wait_ms = 100 })

      assert.is_not_nil(err:find("still missing: go, rust", 1, true))
      assert.equal(1, #captured.warns)
    end)

    it("reports an installer that returns no task", function()
      local deps, captured = make_deps({ install = function() end })

      local _, err = provision.ensure(deps, { wait_ms = 100 })

      assert.is_not_nil(err:find("no task", 1, true))
      assert.equal(1, #captured.warns)
    end)

    it("warns instead of throwing when resolving what is missing errors", function()
      local deps, captured = make_deps({
        missing = function()
          error("nvim-treesitter is not loaded")
        end,
      })

      local acted, err = provision.ensure(deps)
      assert.same({}, acted)
      assert.is_string(err)
      assert.equal(1, #captured.warns)
      assert.same({}, captured.installed)
    end)

    it("reports a failure to recheck parsers after installation", function()
      local checks = 0
      local deps = make_deps({
        missing = function()
          checks = checks + 1
          if checks > 1 then
            error("resolver unavailable")
          end
          return { "go" }
        end,
      })

      local _, err = provision.ensure(deps, { wait_ms = 100 })

      assert.is_not_nil(err:find("could not verify", 1, true))
      assert.is_not_nil(err:find("resolver unavailable", 1, true))
    end)
  end)

  describe("completion", function()
    local function observe(deps, opts)
      local completions = {}
      opts = opts or {}
      opts.on_complete = function(installed, err)
        table.insert(completions, { installed = installed, err = err })
      end
      provision.ensure(deps, opts)
      return completions
    end

    local function wait_for(completions)
      assert.is_true(vim.wait(1000, function()
        return #completions > 0
      end))
      assert.equal(1, #completions)
      return completions[1]
    end

    it("schedules notification only after background installation finishes", function()
      local deps, captured = make_deps({})
      local completions = observe(deps)

      assert.same({}, captured.waits)
      assert.same({}, completions)
      captured.finish(nil, true)
      assert.same({}, completions, "a task callback must not run editor work inline")

      assert.same({ installed = { "go", "rust" } }, wait_for(completions))
      assert.same({}, captured.warns)
    end)

    it("also schedules completion after a blocking install", function()
      local deps = make_deps({})
      local completions = observe(deps, { wait_ms = 100 })

      assert.same({}, completions)
      assert.same({ installed = { "go", "rust" } }, wait_for(completions))
    end)

    it("provides the successfully installed subset when another build fails", function()
      local deps, captured = make_deps({})
      local completions = observe(deps)
      captured.finish(nil, false, { "rust" })

      local completion = wait_for(completions)
      assert.same({ "go" }, completion.installed)
      assert.is_not_nil(completion.err:find("install failed", 1, true))
      assert.is_not_nil(completion.err:find("still missing: rust", 1, true))
      assert.equal(1, #captured.warns)
    end)

    it("reports a background task error without throwing", function()
      local deps, captured = make_deps({})
      local completions = observe(deps)
      captured.finish("download interrupted", nil)

      local completion = wait_for(completions)
      assert.same({}, completion.installed)
      assert.is_not_nil(completion.err:find("download interrupted", 1, true))
      assert.equal(1, #captured.warns)
    end)

    it("rechecks availability even when the background task reports success", function()
      local deps, captured = make_deps({})
      local completions = observe(deps)
      captured.finish(nil, true, { "go", "rust" })

      local completion = wait_for(completions)
      assert.same({}, completion.installed)
      assert.is_not_nil(completion.err:find("still missing", 1, true))
    end)

    it("keeps callback failures nonfatal", function()
      local deps, captured = make_deps({})
      provision.ensure(deps, {
        on_complete = function()
          error("callback failed")
        end,
      })
      captured.finish(nil, true)

      assert.is_true(vim.wait(1000, function()
        return #captured.warns > 0
      end))
      assert.is_not_nil(captured.warns[1]:find("callback failed", 1, true))
    end)
  end)

  describe("default_deps", function()
    local languages = require("core.lib.languages")
    local saved_rows, saved_treesitter, saved_rtp, cleanup

    before_each(function()
      saved_rows = languages.rows
      saved_treesitter = package.loaded["nvim-treesitter"]
      saved_rtp = vim.o.runtimepath
    end)

    after_each(function()
      languages.rows = saved_rows
      package.loaded["nvim-treesitter"] = saved_treesitter
      vim.o.runtimepath = saved_rtp
      if cleanup then
        cleanup()
        cleanup = nil
      end
    end)

    it("supplies every collaborator ensure calls", function()
      local defaults = provision.default_deps()

      assert.is_function(defaults.missing)
      assert.is_function(defaults.install)
      assert.is_function(defaults.info)
      assert.is_function(defaults.warn)
    end)

    it("resolves the missing set from the language declarations", function()
      -- Not a hard-coded list: whatever lua/languages/ declares is what gets
      -- provisioned. A default that returned a fixed list would pass every
      -- other test in this file.
      local expected = languages.missing_parsers(languages.rows())

      assert.same(expected, provision.default_deps().missing())
    end)

    it("repairs a query-only installation while leaving resolvable parsers alone", function()
      local root
      root, cleanup = tmpdir.new({
        languages = {
          ["luxvim_repair.lua"] = "return {}",
          ["luxvim_present.lua"] = "return {}",
          ["lua.lua"] = "return {}", -- bundled by Neovim
        },
        site = {
          parser = { ["luxvim_present.so"] = "" },
          queries = { luxvim_repair = { ["highlights.scm"] = "" } },
        },
      })
      vim.opt.runtimepath:prepend(root .. "/site")
      languages.rows = function()
        return saved_rows({ dirs = { { path = root .. "/languages", source = "framework" } } })
      end

      local installs = {}
      package.loaded["nvim-treesitter"] = {
        install = function(langs, opts)
          table.insert(installs, langs)
          return {
            wait = function()
              -- Like the pinned installer, consider queries sufficient unless
              -- forced. Materialize the repaired binary only when a build runs.
              if opts and opts.force then
                vim.fn.writefile({}, root .. "/site/parser/luxvim_repair.so")
              end
              return true
            end,
          }
        end,
      }

      local defaults = provision.default_deps()
      defaults.info = function() end
      defaults.warn = function() end
      local acted, err = provision.ensure(defaults, { wait_ms = 100 })

      assert.same({ "luxvim_repair" }, acted)
      assert.is_nil(err)
      assert.same({}, defaults.missing())
      assert.same({}, provision.ensure(defaults, { wait_ms = 100 }))
      assert.same({ { "luxvim_repair" } }, installs)
    end)
  end)
end)
