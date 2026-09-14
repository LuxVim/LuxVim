-- tests/unit/core/lib/deps_spec.lua
local deps = require("core.lib.deps")
local platform = require("core.lib.platform")

-- Captured before any test can mutate it, so the restore in after_each is
-- always the real running OS.
local ORIGINAL_OS = platform.os

local SUPPORTED_OS = { "linux", "mac", "windows" }

-- The floors this task pins exactly. Single source of truth for "this
-- dependency has a load-bearing minimum version": each row generates both its
-- manifest pin test and its >= boundary test, so pinning another dependency is
-- a row here, not a new test body.
local PINNED_FLOORS = {
  { cmd = "tree-sitter", min_version = "0.26.1" },
  { cmd = "nvim", min_version = "0.12.0" },
}

local DECLARED_DEPS = {
  { cmd = "nvim", bootstrap = true },
  { cmd = "git", bootstrap = true },
  { cmd = "tree-sitter" },
  { cmd = "curl" },
  { cmd = "tar" },
  { cmd = "cc", alternatives = { "cc", "gcc", "clang", "cl" } },
}

local function find_row(cmd)
  for _, row in ipairs(deps.manifest) do
    if row.cmd == cmd then
      return row
    end
  end
  return nil
end

describe("deps.parse_version", function()
  it("extracts a semver triple from tree-sitter output", function()
    assert.same({ 0, 26, 9 }, deps.parse_version("tree-sitter 0.26.9"))
  end)

  it("extracts a semver triple from nvim --version output", function()
    assert.same({ 0, 12, 4 }, deps.parse_version("NVIM v0.12.4"))
  end)

  it("treats a missing patch segment as zero", function()
    assert.same({ 2, 45, 0 }, deps.parse_version("git version 2.45"))
  end)

  it("returns nil when there is no version to find", function()
    assert.is_nil(deps.parse_version("no numbers here"))
  end)
end)

describe("deps.compare", function()
  it("orders by numeric segment, not lexically", function()
    -- The bug this guards: "0.26.10" < "0.26.9" under string comparison.
    assert.equal(1, deps.compare({ 0, 26, 10 }, { 0, 26, 9 }))
  end)

  it("returns 0 for equal versions", function()
    assert.equal(0, deps.compare({ 0, 26, 1 }, { 0, 26, 1 }))
  end)

  it("returns -1 when the first version is lower", function()
    assert.equal(-1, deps.compare({ 0, 25, 9 }, { 0, 26, 1 }))
  end)
end)

describe("deps.version_ok", function()
  it("accepts the installed CLI against the documented floor", function()
    assert.is_true(deps.version_ok("tree-sitter 0.26.9", "0.26.1"))
  end)

  it("rejects a CLI below the documented floor", function()
    assert.is_false(deps.version_ok("tree-sitter 0.25.0", "0.26.1"))
  end)

  it("rejects unparseable version output rather than assuming it is fine", function()
    assert.is_false(deps.version_ok("", "0.26.1"))
  end)

  -- Boundary guard: the comparison is `>= 0`, and "installed == floor" is the
  -- single most likely real input, because the floor is exactly the version the
  -- install hints tell users to install. Tightening `>=` to `>` must fail here.
  for _, pin in ipairs(PINNED_FLOORS) do
    it(("accepts %s installed exactly at the %s floor"):format(pin.cmd, pin.min_version), function()
      assert.is_true(deps.version_ok(pin.cmd .. " " .. pin.min_version, pin.min_version))
    end)
  end

  it("rejects the version immediately below the floor", function()
    -- Adjacent-below, not far-below: loosening `>= 0` to `>= -1` must fail here.
    assert.is_false(deps.version_ok("tree-sitter 0.26.0", "0.26.1"))
  end)
end)

describe("deps.hint", function()
  -- deps.hint reads platform.os at call time from the cached module table, so
  -- assigning it here is exactly what a mac/windows user's run looks like.
  -- Registered before the tests below and run even when one fails, so a failing
  -- assertion cannot leak a fake OS into the rest of the suite.
  after_each(function()
    platform.os = ORIGINAL_OS
  end)

  local FIXTURE = { cmd = "fake", hints = { linux = "L", mac = "M", windows = "W" } }

  -- OS dispatch, proven on every OS rather than only on the CI runner's.
  -- Freezing the lookup to any single OS (e.g. row.hints["linux"]) fails here.
  for _, os_name in ipairs(SUPPORTED_OS) do
    it(("returns the %s hint when running on %s"):format(os_name, os_name), function()
      platform.os = os_name
      assert.equal(FIXTURE.hints[os_name], deps.hint(FIXTURE))
    end)
  end

  it("falls back to the README when the row declares no hint for this OS", function()
    assert.equal("see the project README", deps.hint({ cmd = "fake", hints = {} }))
    assert.equal("see the project README", deps.hint({ cmd = "fake" }))
  end)

  it("falls back to the README on an OS the row does not name", function()
    platform.os = "haiku"
    assert.equal("see the project README", deps.hint(deps.manifest[1]))
  end)

  it("resolves each manifest row's own hint on every supported OS", function()
    assert.is_true(#deps.manifest > 0)
    for _, row in ipairs(deps.manifest) do
      for _, os_name in ipairs(SUPPORTED_OS) do
        platform.os = os_name
        assert.equal(
          row.hints[os_name],
          deps.hint(row),
          ("row %s returned the wrong hint on %s"):format(row.cmd, os_name)
        )
      end
    end
  end)

  -- Proves the test above can discriminate: if two OSes shared a hint string, a
  -- frozen lookup would satisfy both of their cases. Distinct strings are also
  -- the point of per-OS hints -- a duplicate is usually a copy-paste that tells
  -- Windows users to run apt.
  it("declares a distinct hint per OS on every row", function()
    assert.is_true(#deps.manifest > 0)
    for _, row in ipairs(deps.manifest) do
      for i = 1, #SUPPORTED_OS do
        for j = i + 1, #SUPPORTED_OS do
          local a, b = SUPPORTED_OS[i], SUPPORTED_OS[j]
          assert.not_equal(row.hints[a], row.hints[b], ("row %s gives %s and %s the same hint"):format(row.cmd, a, b))
        end
      end
    end
  end)
end)

describe("deps.manifest", function()
  -- Vacuity guard: an emptied, renamed or floor-drifted manifest must fail
  -- loudly here. Deleting a pinned row fails on the is_truthy; editing its
  -- floor fails on the equality.
  for _, pin in ipairs(PINNED_FLOORS) do
    it(("declares %s with the pinned %s floor"):format(pin.cmd, pin.min_version), function()
      local row = find_row(pin.cmd)
      assert.is_truthy(row, ("manifest declares no %s row"):format(pin.cmd))
      assert.equal(pin.min_version, row.min_version)
      assert.is_truthy(row.version_args, ("row %s has a pinned floor but no version_args"):format(pin.cmd))
    end)
  end

  local REQUIRED_FIELDS = { "cmd", "reason" }

  for _, field in ipairs(REQUIRED_FIELDS) do
    it(("declares %s on every row"):format(field), function()
      assert.is_true(#deps.manifest > 0)
      for index, row in ipairs(deps.manifest) do
        assert.is_truthy(row[field], ("manifest row %d (%s) is missing %s"):format(index, row.cmd or "?", field))
      end
    end)
  end

  it("declares exactly the pinned dependency set, with the pinned alternatives", function()
    local declared = {}
    for _, row in ipairs(deps.manifest) do
      declared[row.cmd] = row
    end

    local expected = {}
    for _, want in ipairs(DECLARED_DEPS) do
      expected[want.cmd] = true
      local row = declared[want.cmd]
      assert.is_truthy(row, ("manifest declares no %s row"):format(want.cmd))
      assert.same(
        want.alternatives or false,
        row.alternatives or false,
        ("row %s: alternatives drifted from the pinned list"):format(want.cmd)
      )
      assert.equal(want.bootstrap or false, row.bootstrap or false, ("row %s: bootstrap flag drifted"):format(want.cmd))
    end

    for cmd in pairs(declared) do
      assert.is_true(
        expected[cmd] == true,
        ("manifest row %s has no DECLARED_DEPS entry, so nothing pins it"):format(cmd)
      )
    end
  end)

  it("declares a hint for every OS on every row", function()
    assert.is_true(#deps.manifest > 0)
    for _, row in ipairs(deps.manifest) do
      for _, os_name in ipairs(SUPPORTED_OS) do
        assert.is_truthy(row.hints and row.hints[os_name], ("row %s is missing a %s hint"):format(row.cmd, os_name))
      end
    end
  end)

  it("declares version_args for every row that declares a min_version", function()
    for _, row in ipairs(deps.manifest) do
      if row.min_version then
        assert.is_truthy(row.version_args, ("row %s has min_version but no version_args"):format(row.cmd))
      end
    end
  end)

  -- Closure guard: PINNED_FLOORS is the single source of truth for "this
  -- dependency has a load-bearing minimum version", and every pin test and
  -- boundary test above is generated from it -- as is the floor enforcement in
  -- deps.check. Nothing else forces the two sets to agree, so without this
  -- assertion, giving another manifest row a min_version would ship a floor
  -- with zero pin coverage and zero boundary coverage while the suite stayed
  -- green, and emptying PINNED_FLOORS would silently delete that coverage
  -- entirely. This is what makes the generated tests provably non-vacuous.
  it("pins exactly the manifest rows that declare a min_version", function()
    local declared = {}
    for _, row in ipairs(deps.manifest) do
      if row.min_version ~= nil then
        declared[row.cmd] = true
      end
    end

    local pinned = {}
    for _, pin in ipairs(PINNED_FLOORS) do
      pinned[pin.cmd] = true
    end

    for cmd in pairs(declared) do
      assert.is_true(
        pinned[cmd] == true,
        (
          "manifest row %s declares a min_version with no PINNED_FLOORS entry, "
          .. "so its floor has no pin or boundary coverage"
        ):format(cmd)
      )
    end
    for cmd in pairs(pinned) do
      assert.is_true(
        declared[cmd] == true,
        ("PINNED_FLOORS pins %s but the manifest declares no min_version for it"):format(cmd)
      )
    end
  end)
end)

describe("deps.check", function()
  -- The hint carried on a result is per-OS, so these tests pin the OS rather
  -- than reading the runner's. Registered before the tests below and run even
  -- when one fails, so a failing assertion cannot leak a fake OS.
  after_each(function()
    platform.os = ORIGINAL_OS
  end)

  local function fake(present, versions)
    return {
      resolve = function(cmd)
        return present[cmd] and ("/usr/bin/" .. cmd) or nil
      end,
      probe = function(path, _)
        local cmd = path:match("([^/]+)$")
        return versions[cmd]
      end,
    }
  end

  local ts_row = {
    cmd = "tree-sitter",
    min_version = "0.26.1",
    version_args = { "--version" },
    reason = "compiles parsers",
    hints = { linux = "pacman -S tree-sitter-cli", mac = "brew", windows = "scoop" },
  }

  it("reports ok when the command is present and new enough", function()
    local opts = fake({ ["tree-sitter"] = true }, { ["tree-sitter"] = "tree-sitter 0.26.9" })
    local result = deps.check(ts_row, opts)
    assert.equal("ok", result.status)
    assert.equal("0.26.9", result.version)
  end)

  -- NEGATIVE TEST: the mechanism must fire when the dependency is absent.
  -- The hint and the reason ARE the missing report -- they are the install
  -- instruction the user reads -- so they are asserted by value, on every OS.
  -- is_truthy here would be satisfied by a hard-coded constant that discards
  -- the row entirely, which is to say by no plumbing at all: deps.hint's whole
  -- per-OS dispatch could be dropped on the floor here and stay green.
  it("reports missing when the command is not on PATH", function()
    local opts = fake({}, {})
    for _, os_name in ipairs(SUPPORTED_OS) do
      platform.os = os_name
      local result = deps.check(ts_row, opts)
      assert.equal("missing", result.status)
      assert.equal(ts_row.hints[os_name], result.hint, ("the %s hint did not reach the result"):format(os_name))
      assert.equal(ts_row.reason, result.reason)
    end
  end)

  -- NEGATIVE TEST: version_args is a manifest field every pinned row declares,
  -- and it is inert unless check hands it to the probe. The `fake` double above
  -- discards its second parameter by construction, so no test using it can
  -- observe this; this double records it. Passing nil instead makes the real
  -- tree-sitter print its usage rather than a version, so every pinned row
  -- would report "unknown" on a correctly installed machine.
  it("passes the resolved path and the row's version_args to the probe", function()
    local seen
    local result = deps.check(ts_row, {
      resolve = function(cmd)
        return "/usr/bin/" .. cmd
      end,
      probe = function(path, args)
        seen = { path = path, args = args }
        return "tree-sitter 0.26.9"
      end,
    })
    assert.equal("/usr/bin/tree-sitter", seen.path)
    assert.same({ "--version" }, seen.args)
    assert.equal("ok", result.status)
  end)

  -- NEGATIVE TEST: the version floor must actually be enforced.
  it("reports outdated when the command is present but below the floor", function()
    local opts = fake({ ["tree-sitter"] = true }, { ["tree-sitter"] = "tree-sitter 0.25.0" })
    local result = deps.check(ts_row, opts)
    assert.equal("outdated", result.status)
    assert.equal("0.25.0", result.version)
    assert.equal(ts_row.min_version, result.min_version)
  end)

  it("accepts any alternative when a row declares alternatives", function()
    local cc_row = {
      cmd = "cc",
      alternatives = { "cc", "gcc", "clang" },
      version_args = { "--version" },
      reason = "C compiler",
      hints = { linux = "gcc", mac = "xcode", windows = "msvc" },
    }
    local opts = fake({ clang = true }, { clang = "clang version 18.1.8" })
    local result = deps.check(cc_row, opts)
    assert.equal("ok", result.status)
    assert.equal("/usr/bin/clang", result.path)
  end)

  -- NEGATIVE TEST: `alternatives` is an ORDERED preference list -- the real
  -- manifest declares { "cc", "gcc", "clang", "cl" }, where the order encodes
  -- "prefer the system default compiler". "Some alternative resolved" is
  -- therefore not the contract: the FIRST one that resolves must win, and the
  -- scan must stop there. The test above marks only the LAST entry present, so
  -- it cannot tell first-wins from last-wins from reverse order -- marking two
  -- present is what discriminates. Dropping the `break` (last-match-wins) or
  -- reversing the iteration both fail here.
  it("prefers the first alternative that resolves and stops scanning there", function()
    local tried = {}
    local present = { gcc = true, clang = true }
    local result = deps.check({
      cmd = "cc",
      alternatives = { "cc", "gcc", "clang" },
      version_args = { "--version" },
      reason = "C compiler",
      hints = { linux = "gcc", mac = "xcode", windows = "msvc" },
    }, {
      resolve = function(cmd)
        table.insert(tried, cmd)
        return present[cmd] and ("/usr/bin/" .. cmd) or nil
      end,
      probe = function()
        return "gcc (GCC) 14.2.0"
      end,
    })
    assert.equal("ok", result.status)
    assert.equal("/usr/bin/gcc", result.path)
    assert.same({ "cc", "gcc" }, tried)
  end)

  it("reports missing when no alternative is present", function()
    local cc_row = {
      cmd = "cc",
      alternatives = { "cc", "gcc", "clang" },
      version_args = { "--version" },
      reason = "C compiler",
      hints = { linux = "gcc", mac = "xcode", windows = "msvc" },
    }
    local result = deps.check(cc_row, fake({}, {}))
    assert.equal("missing", result.status)
  end)

  it("reports ok without a version when the row declares no min_version", function()
    local row = {
      cmd = "tar",
      version_args = { "--version" },
      reason = "unpacks grammars",
      hints = { linux = "tar", mac = "tar", windows = "tar" },
    }
    local result = deps.check(row, fake({ tar = true }, { tar = "tar (GNU tar) 1.35" }))
    assert.equal("ok", result.status)
  end)

  -- NEGATIVE TEST: "present but unreadable version" is the fourth status this
  -- module promises, and it is the one that must NOT degrade to "ok". A CLI
  -- whose --version cannot be parsed has not been shown to meet the floor, so
  -- reporting it ok would reintroduce at this layer exactly the assume-it-is-
  -- fine bug that version_ok refuses. Without this test, replacing the branch
  -- with "ok" leaves the whole suite green.
  it("reports unknown when a pinned command is present but its version cannot be read", function()
    -- Both real shapes: --version produced nothing, and --version produced
    -- output with no version in it.
    local silent = deps.check(ts_row, fake({ ["tree-sitter"] = true }, {}))
    assert.equal("unknown", silent.status)
    assert.is_nil(silent.version)

    local unparseable =
      deps.check(ts_row, fake({ ["tree-sitter"] = true }, { ["tree-sitter"] = "tree-sitter (unknown build)" }))
    assert.equal("unknown", unparseable.status)
    assert.is_nil(unparseable.version)
  end)
end)

describe("deps.check_all", function()
  it("returns one result per manifest row", function()
    local opts = {
      manifest = {
        {
          cmd = "a",
          version_args = { "-v" },
          reason = "r",
          hints = { linux = "h", mac = "h", windows = "h" },
        },
        {
          cmd = "b",
          version_args = { "-v" },
          reason = "r",
          hints = { linux = "h", mac = "h", windows = "h" },
        },
      },
      resolve = function()
        return nil
      end,
      probe = function()
        return nil
      end,
    }
    local results = deps.check_all(opts)
    assert.equal(2, #results)
    assert.equal("a", results[1].cmd)
    assert.equal("b", results[2].cmd)
  end)

  -- NEGATIVE TEST: check_all must surface failures, not swallow them.
  it("surfaces missing dependencies in its results", function()
    local opts = {
      manifest = {
        {
          cmd = "definitely-not-installed",
          version_args = { "-v" },
          reason = "r",
          hints = { linux = "h", mac = "h", windows = "h" },
        },
      },
      resolve = function()
        return nil
      end,
      probe = function()
        return nil
      end,
    }
    local results = deps.check_all(opts)
    assert.equal("missing", results[1].status)
  end)

  -- NEGATIVE TEST: check_all must forward the injected seam into every check.
  -- The two tests above pass under `M.check(row, {})` purely by accident -- no
  -- binary named "a", "b" or "definitely-not-installed" happens to exist on
  -- this host, so the REAL PATH lookup returns the same "missing" the fake
  -- would have. That is the hazard the brief names: "tests must never depend on
  -- what happens to be installed on the machine running them". Fakes that
  -- resolve to a path and record their calls make the forwarding observable, so
  -- severing it fails here instead of silently reintroducing host dependence.
  it("forwards the injected resolve and probe into every check", function()
    local resolved, probed = {}, {}
    local results = deps.check_all({
      manifest = {
        {
          cmd = "a",
          version_args = { "-v" },
          reason = "r",
          hints = { linux = "h", mac = "h", windows = "h" },
        },
        {
          cmd = "b",
          min_version = "2.0.0",
          version_args = { "--version" },
          reason = "r",
          hints = { linux = "h", mac = "h", windows = "h" },
        },
      },
      resolve = function(cmd)
        table.insert(resolved, cmd)
        return "/fake/" .. cmd
      end,
      probe = function(path, args)
        table.insert(probed, { path = path, args = args })
        return "fake 2.3.4"
      end,
    })
    assert.same({ "a", "b" }, resolved)
    assert.equal("/fake/a", probed[1].path)
    assert.same({ "-v" }, probed[1].args)
    assert.equal("/fake/b", probed[2].path)
    assert.same({ "--version" }, probed[2].args)
    assert.equal("ok", results[1].status)
    assert.equal("2.3.4", results[1].version)
    assert.equal("ok", results[2].status)
  end)
end)

-- :checkhealth luxvim and scripts/check-deps.lua call deps.check_all() with NO
-- arguments, so the default resolve/probe wiring is the only path production
-- ever takes -- and it is the one path every injected fake above is structurally
-- unable to reach. Stubbing vim.fn.exepath / vim.system covers it while staying
-- fully host-independent: the same save-and-restore technique the deps.hint
-- tests use for platform.os.
describe("deps defaults (called with no opts)", function()
  local saved_exepath, saved_system

  before_each(function()
    -- rawget, because vim.fn generates and caches its wrappers on demand.
    saved_exepath = rawget(vim.fn, "exepath")
    saved_system = vim.system
  end)

  after_each(function()
    -- Restoring nil lets vim.fn regenerate its own wrapper.
    rawset(vim.fn, "exepath", saved_exepath)
    vim.system = saved_system
  end)

  -- Replaces the two OS calls the defaults make. Returns the argv list every
  -- vim.system call was handed, so the argument plumbing is observable.
  local function stub_env(paths, stdout, stderr)
    local seen = {}
    vim.fn.exepath = function(cmd)
      -- The real vim.fn.exepath returns "" -- never nil -- for a command that
      -- is not on PATH.
      return paths[cmd] or ""
    end
    vim.system = function(cmd, _)
      table.insert(seen, cmd)
      return {
        wait = function()
          return { stdout = stdout, stderr = stderr }
        end,
      }
    end
    return seen
  end

  -- NEGATIVE TEST: vim.fn.exepath returns "" for a missing command, and "" is
  -- TRUTHY in Lua. Without default_resolve's empty-string guard, the first
  -- candidate always "resolves" and EVERY missing dependency reports as present
  -- with path = "" -- a check that examines nothing, guarded by one line.
  it("reports missing when the default PATH lookup finds nothing", function()
    local seen = stub_env({}, "", "")
    local result = deps.check(find_row("tree-sitter"))
    assert.equal("missing", result.status)
    assert.is_nil(result.path)
    assert.same({}, seen, "a command that is not on PATH must never be probed")
  end)

  -- Covers the whole default wiring at once: omitting opts must still resolve
  -- through vim.fn.exepath and spawn `<path> <version_args>`. Dropping any of
  -- `opts = opts or {}`, `or default_resolve`, `or default_probe` makes this
  -- raise "attempt to call a nil value"; probing without version_args fails the
  -- argv assertion.
  it("resolves and probes a real manifest row with no opts at all", function()
    local seen = stub_env({ ["tree-sitter"] = "/usr/bin/tree-sitter" }, "tree-sitter 0.26.9\n", "")
    local result = deps.check(find_row("tree-sitter"))
    assert.equal("ok", result.status)
    assert.equal("/usr/bin/tree-sitter", result.path)
    assert.equal("0.26.9", result.version)
    assert.same({ { "/usr/bin/tree-sitter", "--version" } }, seen)
  end)

  -- NEGATIVE TEST: some toolchains print --version to stderr, not stdout, which
  -- is why default_probe concatenates both. Reading stdout alone reports a
  -- correctly installed compiler as "unknown".
  it("reads a version printed to stderr rather than stdout", function()
    stub_env({ ["tree-sitter"] = "/usr/bin/tree-sitter" }, "", "tree-sitter 0.26.9\n")
    local result = deps.check(find_row("tree-sitter"))
    assert.equal("ok", result.status)
    assert.equal("0.26.9", result.version)
  end)

  -- NEGATIVE TEST: a binary that cannot be spawned must degrade to "unknown",
  -- not throw out of :checkhealth. Removing default_probe's pcall fails here.
  it("reports unknown rather than raising when the probe cannot be spawned", function()
    stub_env({ ["tree-sitter"] = "/usr/bin/tree-sitter" }, "", "")
    vim.system = function()
      error("ENOENT: no such file or directory")
    end
    local result = deps.check(find_row("tree-sitter"))
    assert.equal("unknown", result.status)
    assert.is_nil(result.version)
  end)

  -- NEGATIVE TEST: check_all() with no arguments is exactly how production
  -- calls it. Defaulting its manifest to {} -- or dropping its opts guard --
  -- makes the entry point silently report that there is nothing to check.
  it("check_all() with no arguments checks every row of the real manifest", function()
    stub_env({}, "", "")
    local results = deps.check_all()
    assert.is_true(#deps.manifest > 0)
    assert.equal(#deps.manifest, #results)
    for i, row in ipairs(deps.manifest) do
      assert.equal(row.cmd, results[i].cmd)
      assert.equal("missing", results[i].status)
    end
  end)

  it("check_all() with no arguments probes every row through the defaults", function()
    local paths = {}
    for _, row in ipairs(deps.manifest) do
      for _, candidate in ipairs(row.alternatives or { row.cmd }) do
        paths[candidate] = "/usr/bin/" .. candidate
      end
    end
    local seen = stub_env(paths, "fake 9.9.9\n", "")

    local results = deps.check_all()
    assert.equal(#deps.manifest, #results)
    assert.equal(#deps.manifest, #seen)
    for i, row in ipairs(deps.manifest) do
      assert.equal("ok", results[i].status)
      assert.equal("9.9.9", results[i].version)
      local first = row.alternatives and row.alternatives[1] or row.cmd
      local expected = { "/usr/bin/" .. first }
      for _, arg in ipairs(row.version_args or {}) do
        table.insert(expected, arg)
      end
      assert.same(expected, seen[i], ("row %s was not probed with its own path and version_args"):format(row.cmd))
    end
  end)

  it("bounds every probe with a timeout", function()
    local orig_exepath = vim.fn.exepath
    local orig_system = vim.system
    local seen_opts
    vim.fn.exepath = function(c)
      return "/usr/bin/" .. c
    end
    vim.system = function(_, opts)
      seen_opts = opts
      return {
        wait = function()
          return { stdout = "9.9.9\n", stderr = "" }
        end,
      }
    end

    deps.check(find_row("tree-sitter"))

    vim.fn.exepath = orig_exepath
    vim.system = orig_system

    assert.is_truthy(
      seen_opts and seen_opts.timeout,
      "vim.system was called with no timeout -- a hung binary blocks :checkhealth forever"
    )
    assert.is_true(type(seen_opts.timeout) == "number" and seen_opts.timeout > 0)
  end)

  it("reports unknown when probe wait returns nil (timeout path)", function()
    local orig_exepath = vim.fn.exepath
    local orig_system = vim.system
    vim.fn.exepath = function(c)
      return "/usr/bin/" .. c
    end
    vim.system = function(_, _)
      return {
        wait = function()
          return nil
        end,
      }
    end

    local res = deps.check(find_row("tree-sitter"))

    vim.fn.exepath = orig_exepath
    vim.system = orig_system

    assert.equal("unknown", res.status)
    assert.is_nil(res.version)
  end)
end)

describe("deps.is_fatal", function()
  it("treats missing as fatal for every required command, including bootstrap rows", function()
    assert.is_true(deps.is_fatal({ cmd = "git", status = "missing" }))
    assert.is_true(deps.is_fatal({ cmd = "nvim", status = "missing" }))
    assert.is_true(deps.is_fatal({ cmd = "tree-sitter", status = "missing" }))
    assert.is_true(deps.is_fatal({ cmd = "cc", status = "missing" }))
    assert.is_true(deps.is_fatal({ cmd = "curl", status = "missing" }))
    assert.is_true(deps.is_fatal({ cmd = "tar", status = "missing" }))
  end)

  it("treats missing as fatal for every row in the manifest", function()
    assert.is_true(#deps.manifest > 0)
    for _, row in ipairs(deps.manifest) do
      assert.is_true(
        deps.is_fatal({ cmd = row.cmd, status = "missing", bootstrap = row.bootstrap }),
        ("missing %s was not treated as fatal"):format(row.cmd)
      )
    end
  end)

  it("treats outdated as fatal for non-nvim dependencies", function()
    assert.is_true(deps.is_fatal({
      cmd = "tree-sitter",
      status = "outdated",
      min_version = "0.26.1",
      version = "0.25.0",
    }))
  end)

  it("treats outdated nvim as advisory (non-fatal) due to the unresolved 0.10 vs 0.12 policy", function()
    assert.is_false(deps.is_fatal({
      cmd = "nvim",
      status = "outdated",
      min_version = "0.12.0",
      version = "0.11.0",
      bootstrap = true,
    }))
  end)

  it("treats ok and unknown status as non-fatal", function()
    assert.is_false(deps.is_fatal({ cmd = "git", status = "ok", version = "2.45.0" }))
    assert.is_false(deps.is_fatal({ cmd = "tree-sitter", status = "ok", version = "0.26.9" }))
    assert.is_false(deps.is_fatal({ cmd = "cc", status = "unknown" }))
  end)
end)
