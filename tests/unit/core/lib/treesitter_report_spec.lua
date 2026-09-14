-- tests/unit/core/lib/treesitter_report_spec.lua
-- Tests the FileType failure-reporting path.
--
-- The bug this file's contract was rewritten around: the report deduped per
-- filetype, so the SECOND Go buffer of a session got no message even though
-- treesitter was just as dead as in the first. Silence read as "resolved" when
-- it meant "still broken, no longer mentioned". Deduping the notification is
-- right; dropping the fact is not, so every failure is now recorded for
-- :checkhealth luxvim regardless of whether it was announced.

local treesitter_report = require("core.lib.treesitter_report")

--- Builds deps with sane defaults so each test states only what it is about.
local function make_deps(overrides)
  local captured = {
    warns = {},
    record = {},
  }
  local deps = {
    start = function()
      return false, "/usr/share/nvim/runtime/lua/vim/treesitter.lua:460: Parser could not be created"
    end,
    get_lang = function(filetype)
      return filetype
    end,
    get_available = function()
      return { "go", "zig", "rust" }
    end,
    declared = {},
    warn = function(msg)
      table.insert(captured.warns, msg)
    end,
    record = captured.record,
  }
  return vim.tbl_extend("force", deps, overrides or {}), captured
end

describe("core.lib.treesitter_report", function()
  describe("when treesitter starts successfully", function()
    it("says nothing and records nothing", function()
      local deps, captured = make_deps({
        start = function()
          return true, nil
        end,
        declared = { go = { name = "go", parser = "go" } },
      })

      treesitter_report.new(deps)({ buf = 1, match = "go" })

      assert.same({}, captured.warns)
      assert.same({}, captured.record)
    end)
  end)

  describe("when a declared language fails to start", function()
    it("warns that LuxVim promised this language", function()
      local deps, captured = make_deps({
        declared = { go = { name = "go", parser = "go" } },
      })

      treesitter_report.new(deps)({ buf = 1, match = "go" })

      assert.equal(1, #captured.warns)
      assert.is_not_nil(captured.warns[1]:find("go", 1, true))
      assert.is_not_nil(captured.warns[1]:find("checkhealth luxvim", 1, true))
    end)

    it("never leaks the raw Neovim error into the notification", function()
      -- The second line users saw was a DEBUG-level vim.notify carrying
      -- "/usr/share/nvim/runtime/lua/vim/treesitter.lua:460: ...". Neovim's
      -- default handler prints DEBUG exactly like every other level, so a
      -- diagnostic meant for maintainers read to users as a crash.
      local deps, captured = make_deps({
        declared = { go = { name = "go", parser = "go" } },
      })

      treesitter_report.new(deps)({ buf = 1, match = "go" })

      for _, msg in ipairs(captured.warns) do
        assert.is_nil(
          msg:find("treesitter.lua:460", 1, true),
          "user-facing text must not contain Neovim internals: " .. msg
        )
      end
    end)
  end)

  describe("when an undeclared filetype fails to start", function()
    it("suggests declaring the language rather than implying a broken install", function()
      local deps, captured = make_deps({ declared = {} })

      treesitter_report.new(deps)({ buf = 1, match = "zig" })

      assert.equal(1, #captured.warns)
      assert.is_not_nil(
        captured.warns[1]:find("lua/languages/zig.lua", 1, true),
        "an undeclared language should point at the declaration that would fix it "
          .. "permanently, got: "
          .. captured.warns[1]
      )
    end)

    it("stays silent when no parser exists upstream to install", function()
      -- NOTE: get_lang() falls back to returning the filetype itself, so it can
      -- never be the availability guard — get_lang("fzf") is "fzf", not nil.
      local deps, captured = make_deps({
        get_available = function()
          return { "go" }
        end,
      })

      treesitter_report.new(deps)({ buf = 1, match = "fzf" })

      assert.same({}, captured.warns)
    end)
  end)

  describe("the session record", function()
    it("records a failure that was announced", function()
      local deps, captured = make_deps({
        declared = { go = { name = "go", parser = "go" } },
      })

      treesitter_report.new(deps)({ buf = 1, match = "go" })

      assert.is_table(captured.record.go)
      assert.equal("go", captured.record.go.lang)
      assert.is_true(captured.record.go.declared)
    end)

    -- The core of the reported bug: the notification is deduped, the fact is
    -- not. A report that forgot the second failure would pass every other test
    -- in this file.
    it("still records a repeat failure whose notification was deduped", function()
      local deps, captured = make_deps({
        declared = { go = { name = "go", parser = "go" } },
      })
      local handler = treesitter_report.new(deps)

      handler({ buf = 1, match = "go" })
      captured.record.go = nil -- prove the second call writes, not just the first
      handler({ buf = 2, match = "go" })

      assert.equal(1, #captured.warns, "the notification is still deduped")
      assert.is_table(captured.record.go, "but the failure is still recorded")
    end)

    it("does not record a filetype with no upstream parser", function()
      local deps, captured = make_deps({
        get_available = function()
          return {}
        end,
      })

      treesitter_report.new(deps)({ buf = 1, match = "fzf" })

      assert.same({}, captured.record)
    end)

    it("marks an undeclared failure as undeclared", function()
      local deps, captured = make_deps({ declared = {} })

      treesitter_report.new(deps)({ buf = 1, match = "zig" })

      assert.is_false(captured.record.zig.declared)
    end)
  end)

  describe("deduplication", function()
    it("warns once per filetype but again for a different filetype", function()
      local deps, captured = make_deps({})
      local handler = treesitter_report.new(deps)

      handler({ buf = 1, match = "zig" })
      handler({ buf = 2, match = "zig" })
      assert.equal(1, #captured.warns)

      handler({ buf = 3, match = "rust" })
      assert.equal(2, #captured.warns)
    end)
  end)

  describe("language resolution", function()
    local buf

    after_each(function()
      if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      buf = nil
    end)

    it("attaches the declared parser to a custom filetype using the real start adapter", function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].filetype = "luatest"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local answer = 42" })
      local deps, captured = make_deps({
        start = treesitter_report.default_deps().start,
        declared = { luatest = { parser = "lua" } },
        get_available = function()
          return { "lua" }
        end,
      })

      treesitter_report.new(deps)({ buf = buf, match = "luatest" })

      assert.is_not_nil(vim.treesitter.highlighter.active[buf])
      assert.equal("lua", vim.treesitter.get_parser(buf, "lua"):lang())
      assert.same({}, captured.warns)
      assert.same({}, captured.record)
    end)

    it("uses the declaration for availability checks, failure records, and install advice", function()
      local deps, captured = make_deps({
        declared = { luatest = { parser = "lua" } },
        get_available = function()
          return { "lua" }
        end,
      })

      treesitter_report.new(deps)({ buf = 1, match = "luatest" })

      assert.equal("lua", captured.record.luatest.lang)
      assert.is_true(captured.record.luatest.declared)
      assert.is_not_nil(captured.warns[1]:find(":TSInstall lua ", 1, true))
    end)

    it("skips attachment and reporting when the declaration disables its parser", function()
      local starts = 0
      local deps, captured = make_deps({
        declared = { go = { parser = false } },
        start = function()
          starts = starts + 1
          return false
        end,
      })

      treesitter_report.new(deps)({ buf = 1, match = "go" })

      assert.equal(0, starts)
      assert.same({}, captured.warns)
      assert.same({}, captured.record)
    end)

    it("retains Neovim's parser mapping for an undeclared filetype", function()
      local started_lang
      local deps = make_deps({
        get_lang = function()
          return "tsx"
        end,
        start = function(_, lang)
          started_lang = lang
          return true
        end,
      })

      treesitter_report.new(deps)({ buf = 1, match = "typescriptreact" })

      assert.equal("tsx", started_lang)
    end)

    it("names the treesitter language, not the filetype, in the install advice", function()
      local deps, captured = make_deps({
        get_lang = function(filetype)
          return filetype == "cpp" and "c_plus_plus" or filetype
        end,
        get_available = function()
          return { "c_plus_plus" }
        end,
      })

      treesitter_report.new(deps)({ buf = 1, match = "cpp" })

      assert.equal(1, #captured.warns)
      assert.is_not_nil(captured.warns[1]:find("c_plus_plus", 1, true))
    end)
  end)

  describe("default_deps", function()
    it("supplies every collaborator the handler calls", function()
      local defaults = treesitter_report.default_deps()

      assert.is_function(defaults.start)
      assert.is_function(defaults.get_lang)
      assert.is_function(defaults.get_available)
      assert.is_function(defaults.warn)
      assert.is_table(defaults.declared)
      assert.is_table(defaults.record)
    end)

    it("defaults the record to the module's session store so health can read it", function()
      -- is_table first: with no session store at all both sides are nil and
      -- the equality below would hold vacuously.
      assert.is_table(treesitter_report.failures)
      assert.equal(treesitter_report.failures, treesitter_report.default_deps().record)
    end)

    it("offers no notification channel other than warn", function()
      -- The regression: default_deps() used to carry a `debug` notifier that
      -- called vim.notify(msg, vim.log.levels.DEBUG). Neovim's default handler
      -- displays DEBUG identically to every other level, so that "debug" line
      -- was unconditionally user-facing and carried a Neovim source path and
      -- line number. There is no severity that makes internals user-facing
      -- text; the detail belongs in :checkhealth luxvim, which the warning
      -- points at.
      assert.is_nil(treesitter_report.default_deps().debug)
    end)
  end)
end)
