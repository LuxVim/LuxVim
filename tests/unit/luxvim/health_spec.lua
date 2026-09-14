-- tests/unit/luxvim/health_spec.lua
local tmpdir = require("tests.helpers.tmpdir")

describe("luxvim.health", function()
  local orig_health
  local orig_rtp
  local events

  local function find_event(event_type, pattern)
    for _, e in ipairs(events) do
      if e.type == event_type and (pattern == nil or e.msg:find(pattern)) then
        return e
      end
    end
    return nil
  end

  before_each(function()
    events = {}
    orig_health = vim.health
    orig_rtp = vim.opt.runtimepath:get()

    vim.health = {
      start = function(msg)
        table.insert(events, { type = "start", msg = msg })
      end,
      ok = function(msg)
        table.insert(events, { type = "ok", msg = msg })
      end,
      warn = function(msg, advice)
        table.insert(events, { type = "warn", msg = msg, advice = advice })
      end,
      error = function(msg, advice)
        table.insert(events, { type = "error", msg = msg, advice = advice })
      end,
      info = function(msg)
        table.insert(events, { type = "info", msg = msg })
      end,
    }

    package.loaded["luxvim.health"] = nil
  end)

  after_each(function()
    vim.health = orig_health
    vim.opt.runtimepath = orig_rtp
    package.loaded["luxvim.health"] = nil
  end)

  describe("check", function()
    it("emits both external dependencies and treesitter health sections", function()
      local health = require("luxvim.health")
      health.check()

      local dep_start = find_event("start", "LuxVim: external dependencies")
      local ts_start = find_event("start", "LuxVim: treesitter")

      assert.is_not_nil(dep_start, "M.check() did not start external dependencies section")
      assert.is_not_nil(ts_start, "M.check() did not start treesitter section")
    end)
  end)

  describe("check_dependencies", function()
    local orig_deps

    before_each(function()
      orig_deps = package.loaded["core.lib.deps"]
    end)

    after_each(function()
      package.loaded["core.lib.deps"] = orig_deps
    end)

    it("reports ok for healthy dependencies", function()
      package.loaded["core.lib.deps"] = {
        check_all = function()
          return {
            { cmd = "tree-sitter", version = "0.26.9", status = "ok", reason = "compiles parsers" },
          }
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local ok_event = find_event("ok", "tree%-sitter 0%.26%.9 — compiles parsers")
      assert.is_not_nil(ok_event, "healthy dependency was not reported with ok")
    end)

    it("reports error with install hint for missing dependencies", function()
      package.loaded["core.lib.deps"] = {
        check_all = function()
          return {
            { cmd = "git", status = "missing", reason = "clones plugins", hint = "pacman -S git" },
          }
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local err_event = find_event("error", "git not found — clones plugins")
      assert.is_not_nil(err_event, "missing dependency was not reported with error")
      assert.same({ "Install via pacman -S git" }, err_event.advice)
    end)

    it("reports error with update hint when version is outdated", function()
      package.loaded["core.lib.deps"] = {
        check_all = function()
          return {
            {
              cmd = "tree-sitter",
              version = "0.25.0",
              min_version = "0.26.1",
              status = "outdated",
              reason = "compiles parsers",
              hint = "pacman -S tree-sitter-cli",
            },
          }
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local err_event = find_event("error", "tree%-sitter is 0%.25%.0, but 0%.26%.1 or later is required")
      assert.is_not_nil(err_event, "outdated dependency was not reported with error naming versions")
      assert.same({ "Update via pacman -S tree-sitter-cli" }, err_event.advice)
    end)

    it("reports warn when dependency version is unknown", function()
      package.loaded["core.lib.deps"] = {
        check_all = function()
          return {
            {
              cmd = "cc",
              path = "/usr/bin/cc",
              status = "unknown",
              reason = "C compiler",
            },
          }
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local warn_event = find_event("warn", "cc found at /usr/bin/cc but its version could not be determined")
      assert.is_not_nil(warn_event, "unknown version dependency was not reported with warn")
    end)
  end)

  describe("check_treesitter", function()
    local orig_data
    local orig_deps

    before_each(function()
      orig_data = package.loaded["core.lib.data"]
      orig_deps = package.loaded["core.lib.deps"]
      package.loaded["core.lib.deps"] = {
        check_all = function()
          return {}
        end,
      }
    end)

    after_each(function()
      package.loaded["core.lib.data"] = orig_data
      package.loaded["core.lib.deps"] = orig_deps
    end)

    it("reports error when install_dir is not on runtimepath", function()
      local root, cleanup = tmpdir.new({})
      package.loaded["core.lib.data"] = {
        parser_path = function()
          return root
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local err_event = find_event("error", "install_dir is not on the runtimepath")
      assert.is_not_nil(err_event, "missing runtimepath was not reported with error")
      cleanup()
    end)

    it("reports ok when install_dir is on runtimepath", function()
      local root, cleanup = tmpdir.new({})
      vim.opt.runtimepath:append(root)
      package.loaded["core.lib.data"] = {
        parser_path = function()
          return root
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local ok_event = find_event("ok", "install_dir is on the runtimepath")
      assert.is_not_nil(ok_event, "present runtimepath was not reported with ok")
      cleanup()
    end)

    it("reports error when no parsers are installed", function()
      local root, cleanup = tmpdir.new({})
      vim.opt.runtimepath:append(root)
      package.loaded["core.lib.data"] = {
        parser_path = function()
          return root
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local err_event = find_event("error", "no parsers are installed")
      assert.is_not_nil(err_event, "empty parser dir was not reported with error")
      assert.is_table(err_event.advice)
      cleanup()
    end)

    it("reports ok with installed parser count", function()
      local root, cleanup = tmpdir.new({
        parser = { ["svelte.so"] = "", ["html.so"] = "" },
      })
      vim.opt.runtimepath:append(root)
      package.loaded["core.lib.data"] = {
        parser_path = function()
          return root
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local ok_event = find_event("ok", "2 parsers installed: html, svelte")
      assert.is_not_nil(ok_event, "parser count was not reported with ok")
      cleanup()
    end)

    it("reports warn and advice on inherit gap, and omits the ok message", function()
      -- NEGATIVE-TEST CONTRACT: svelte inherits html, but html is not installed.
      -- Must emit a WARN with :TSInstall advice and must NOT emit "every inherited
      -- query language is installed".
      local root, cleanup = tmpdir.new({
        parser = { ["svelte.so"] = "" },
        queries = {
          svelte = {
            ["highlights.scm"] = "; inherits: html\n",
          },
        },
      })
      vim.opt.runtimepath:append(root)
      package.loaded["core.lib.data"] = {
        parser_path = function()
          return root
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local warn_event = find_event(
        "warn",
        "svelte/highlights%.scm inherits 'html', which is not installed — those captures are inactive"
      )
      assert.is_not_nil(warn_event, "inherit gap was not reported with warn")
      assert.same({ "Run :TSInstall html" }, warn_event.advice)

      local ok_event = find_event("ok", "every inherited query language is installed")
      assert.is_nil(ok_event, "healthy ok message was falsely emitted despite inherit gap")
      cleanup()
    end)

    it("reports ok when all inherited query languages are installed", function()
      local root, cleanup = tmpdir.new({
        parser = { ["svelte.so"] = "", ["html.so"] = "" },
        queries = {
          svelte = {
            ["highlights.scm"] = "; inherits: html\n",
          },
          html = {
            ["highlights.scm"] = "(tag_name) @tag\n",
          },
        },
      })
      vim.opt.runtimepath:append(root)
      package.loaded["core.lib.data"] = {
        parser_path = function()
          return root
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local ok_event = find_event("ok", "every inherited query language is installed")
      assert.is_not_nil(ok_event, "clean inherit tree was not reported with ok")

      local warn_event = find_event("warn", "inherits 'html'")
      assert.is_nil(warn_event, "bogus warn was emitted for satisfied inherit")
      cleanup()
    end)

    it("reports info on injection gaps", function()
      local root, cleanup = tmpdir.new({
        parser = { ["svelte.so"] = "" },
        queries = {
          svelte = {
            ["injections.scm"] = '((text) @injection.content (#set! injection.language "javascript"))\n',
          },
        },
      })
      vim.opt.runtimepath:append(root)
      package.loaded["core.lib.data"] = {
        parser_path = function()
          return root
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local info_event = find_event("info", "1 injected languages have no parser.*javascript")
      assert.is_not_nil(info_event, "injection gap was not reported in info message")

      local ok_event = find_event("ok", "every injected language has a parser")
      assert.is_nil(ok_event, "healthy ok message was falsely emitted despite injection gap")
      cleanup()
    end)

    it("reports ok when every injected language has a parser", function()
      local root, cleanup = tmpdir.new({
        parser = { ["svelte.so"] = "", ["javascript.so"] = "" },
        queries = {
          svelte = {
            ["injections.scm"] = '((text) @injection.content (#set! injection.language "javascript"))\n',
          },
        },
      })
      vim.opt.runtimepath:append(root)
      package.loaded["core.lib.data"] = {
        parser_path = function()
          return root
        end,
      }

      local health = require("luxvim.health")
      health.check()

      local ok_event = find_event("ok", "every injected language has a parser")
      assert.is_not_nil(ok_event, "clean injection tree was not reported with ok")
      cleanup()
    end)
  end)
  describe("check_languages", function()
    local orig_languages, orig_report, orig_deps, orig_ts_config

    -- A row shaped the way core.lib.languages emits one.
    local function row(name, overrides)
      return vim.tbl_extend("force", {
        name = name,
        parser = name,
        filetypes = { name },
        options = {},
      }, overrides or {})
    end

    local function stub_languages(rows, errors, missing)
      package.loaded["core.lib.languages"] = {
        load = function()
          return rows, errors or {}
        end,
        rows = function()
          return rows
        end,
        parsers = function(r)
          return vim.tbl_map(function(x)
            return x.parser
          end, r)
        end,
        missing_parsers = function()
          return missing or {}
        end,
        by_filetype = function()
          return {}
        end,
      }
    end

    before_each(function()
      orig_languages = package.loaded["core.lib.languages"]
      orig_report = package.loaded["core.lib.treesitter_report"]
      orig_deps = package.loaded["core.lib.deps"]
      orig_ts_config = package.loaded["nvim-treesitter.config"]

      package.loaded["core.lib.deps"] = {
        check_all = function()
          return {}
        end,
      }
      package.loaded["core.lib.treesitter_report"] = { failures = {} }
      package.loaded["nvim-treesitter.config"] = {
        get_available = function()
          return { "go", "rust", "lua" }
        end,
      }
    end)

    after_each(function()
      package.loaded["core.lib.languages"] = orig_languages
      package.loaded["core.lib.treesitter_report"] = orig_report
      package.loaded["core.lib.deps"] = orig_deps
      package.loaded["nvim-treesitter.config"] = orig_ts_config
    end)

    it("starts a languages section", function()
      stub_languages({ row("go") })

      require("luxvim.health").check()

      assert.is_not_nil(find_event("start", "LuxVim: languages"))
    end)

    it("reports how many languages are declared", function()
      stub_languages({ row("go"), row("rust") })

      require("luxvim.health").check()

      assert.is_not_nil(find_event("ok", "2 languages declared"))
    end)

    -- Non-vacuity: with zero declarations every other check in this section
    -- has nothing to examine and would report success by examining nothing.
    it("errors when nothing is declared at all", function()
      stub_languages({})

      require("luxvim.health").check()

      assert.is_not_nil(find_event("error", "no languages are declared"))
    end)

    it("errors for a declaration that failed to load", function()
      stub_languages({ row("go") }, { { file = "/x/lua/languages/bad.lua", message = "boom" } })

      require("luxvim.health").check()

      assert.is_not_nil(find_event("error", "bad%.lua"))
    end)

    it("errors when a declared parser has no upstream grammar", function()
      -- Typo guard: "golang" is not an nvim-treesitter parser, so this
      -- declaration can never be satisfied by any amount of installing.
      stub_languages({ row("go", { parser = "golang" }) })

      require("luxvim.health").check()

      local err = find_event("error", "golang")
      assert.is_not_nil(err, "an unknown parser name was not reported")
    end)

    -- Negative partner to the typo guard.
    it("does not report an unknown parser when every declared parser exists upstream", function()
      stub_languages({ row("go"), row("rust") })

      require("luxvim.health").check()

      assert.is_nil(find_event("error", "does not provide"))
    end)

    it("errors listing the declared parsers that are not installed", function()
      -- This is the check that would have caught the reported bug: go is
      -- declared, go is not installed, and nothing said so.
      stub_languages({ row("go"), row("rust") }, {}, { "go" })

      require("luxvim.health").check()

      local err = find_event("error", "not installed")
      assert.is_not_nil(err, "a declared-but-missing parser was not reported")
      assert.is_not_nil(err.msg:find("go", 1, true))
      assert.is_table(err.advice)
    end)

    -- Negative partner: proves the check above is keyed on the actual gap set.
    it("reports ok when every declared parser is installed", function()
      stub_languages({ row("go"), row("rust") }, {}, {})

      require("luxvim.health").check()

      assert.is_not_nil(find_event("ok", "every declared parser is installed"))
    end)

    it("reports a treesitter failure recorded earlier in this session", function()
      -- The durable surface. The FileType warning fires once per filetype, so
      -- without this a failure seen at 09:00 is unrecoverable at 17:00.
      stub_languages({ row("go") })
      package.loaded["core.lib.treesitter_report"] = {
        failures = { go = { lang = "go", declared = true, error = "Parser could not be created" } },
      }

      require("luxvim.health").check()

      assert.is_not_nil(find_event("warn", "failed to start"))
    end)

    -- Negative partner: a clean session must not manufacture a failure.
    it("reports ok when nothing failed to start this session", function()
      stub_languages({ row("go") })

      require("luxvim.health").check()

      assert.is_nil(find_event("warn", "failed to start"))
    end)
  end)
end)
