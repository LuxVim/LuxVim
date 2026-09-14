-- tests/unit/scripts/check_deps_spec.lua
-- Tests the check-deps installer contract: wire format, exit code, and fatal/non-fatal gates.

local deps = require("core.lib.deps")
local tmpdir = require("tests.helpers.tmpdir")

describe("deps.report", function()
  it("formats lines as exactly 4 tab-separated fields with no interior tabs", function()
    assert.equal("\t", deps.FIELD_SEP)
    local results = {
      {
        cmd = "tree-sitter",
        status = "ok",
        version = "0.26.9",
        reason = "compiles treesitter parsers",
      },
      {
        cmd = "git",
        status = "missing",
        reason = "clones lazy.nvim",
        hint = "pacman -S git",
      },
    }

    local lines, failed = deps.report(results)
    assert.is_true(failed)
    assert.equal(2, #lines)

    for _, line in ipairs(lines) do
      local parts = vim.split(line, "\t", { plain = true })
      assert.equal(4, #parts, "line does not have 4 tab-separated fields: " .. line)
      for _, part in ipairs(parts) do
        assert.is_nil(part:find("\t", 1, true), "field contains interior tab: " .. part)
      end
    end
  end)

  it("formats messages according to status type", function()
    local results = {
      {
        cmd = "curl",
        status = "ok",
        version = "8.2.1",
        reason = "downloads grammars",
      },
      {
        cmd = "git",
        status = "missing",
        reason = "clones plugins",
        hint = "apt install git",
      },
      {
        cmd = "tree-sitter",
        status = "outdated",
        version = "0.25.0",
        min_version = "0.26.1",
        reason = "compiles parsers",
        hint = "brew install tree-sitter",
      },
      {
        cmd = "cc",
        status = "unknown",
        path = "/usr/bin/cc",
        reason = "C compiler",
        hint = "apt install gcc",
      },
    }

    local lines, _ = deps.report(results)
    assert.equal("ok\tcurl\t8.2.1\tdownloads grammars", lines[1])
    assert.equal("missing\tgit\t-\tnot found — clones plugins. Install via apt install git", lines[2])
    assert.equal(
      "outdated\ttree-sitter\t0.25.0\t0.25.0 is older than the required 0.26.1 — compiles parsers. Update via brew install tree-sitter",
      lines[3]
    )
    assert.equal("unknown\tcc\t-\tfound at /usr/bin/cc but its version could not be determined", lines[4])
  end)

  it("returns failed == false when all dependencies are ok", function()
    local results = {
      { cmd = "nvim", status = "ok", version = "0.12.0", reason = "host" },
      { cmd = "git", status = "ok", version = "2.40.0", reason = "clone" },
      { cmd = "tree-sitter", status = "ok", version = "0.26.1", reason = "parser" },
    }
    local _, failed = deps.report(results)
    assert.is_false(failed)
  end)

  it("returns failed == false when status is unknown or outdated nvim (advisory)", function()
    local results = {
      {
        cmd = "nvim",
        status = "outdated",
        version = "0.11.0",
        min_version = "0.12.0",
        reason = "host",
        hint = "update",
      },
      { cmd = "cc", status = "unknown", path = "/usr/bin/cc", reason = "compiler" },
    }
    local _, failed = deps.report(results)
    assert.is_false(failed)
  end)

  it("returns failed == true when any required dependency is missing", function()
    for _, cmd in ipairs({ "git", "nvim", "tree-sitter", "cc", "curl", "tar" }) do
      local results = {
        { cmd = cmd, status = "missing", reason = "required tool", hint = "install it" },
      }
      local _, failed = deps.report(results)
      assert.is_true(failed, ("missing %s should fail the installer gate"):format(cmd))
    end
  end)

  it("returns failed == true when a non-nvim dependency is outdated", function()
    local results = {
      {
        cmd = "tree-sitter",
        status = "outdated",
        version = "0.25.0",
        min_version = "0.26.1",
        reason = "compiles parsers",
        hint = "update",
      },
    }
    local _, failed = deps.report(results)
    assert.is_true(failed)
  end)
end)

describe("scripts/check-deps.lua process execution", function()
  local root = vim.fn.getcwd()
  local nvim_bin = vim.fn.fnamemodify(vim.v.progpath, ":p")
  local bin, cleanup

  local function probe(cmd, version)
    vim.fn.writefile({ "#!/bin/sh", "printf '%s\\n' " .. vim.fn.shellescape(version) }, bin .. "/" .. cmd)
    assert(vim.uv.fs_chmod(bin .. "/" .. cmd, 493)) -- 0755
  end

  before_each(function()
    local fake_root
    fake_root, cleanup = tmpdir.new({ bin = {} })
    bin = fake_root .. "/bin"
    for _, row in ipairs(deps.manifest) do
      probe(row.cmd, row.min_version or "1.0.0")
    end
  end)

  after_each(function()
    cleanup()
  end)

  local function run()
    -- Run the actual host editor, while every PATH/version probe (including
    -- nvim --version) sees controlled fixtures rather than CI's installed tools.
    return vim
      .system({ nvim_bin, "-l", root .. "/scripts/check-deps.lua" }, {
        cwd = root,
        env = { PATH = bin },
        text = true,
        timeout = 10000,
      })
      :wait()
  end

  local function report(res)
    assert.is_string(res.stdout)
    local lines = vim.split(vim.trim(res.stdout), "\n")
    assert.equal(#deps.manifest, #lines)
    local rows = {}
    for i, line in ipairs(lines) do
      local parts = vim.split(line, "\t", { plain = true })
      assert.equal(4, #parts)
      assert.equal(deps.manifest[i].cmd, parts[2])
      rows[parts[2]] = { status = parts[1], version = parts[3] }
    end
    return rows
  end

  it("exits 0 and outputs valid tab-separated lines on a healthy environment", function()
    local res = run()

    assert.equal(0, res.code, res.stderr)
    for _, row in pairs(report(res)) do
      assert.equal("ok", row.status)
    end
  end)

  it("exits 0 when Neovim 0.10 is reported as outdated but advisory", function()
    probe("nvim", "NVIM v0.10.0")
    local res = run()

    assert.equal(0, res.code, res.stderr)
    assert.same({ status = "outdated", version = "0.10.0" }, report(res).nvim)
  end)

  it("exits 1 when the tree-sitter CLI is outdated", function()
    probe("tree-sitter", "tree-sitter 0.25.0")
    local res = run()

    assert.equal(1, res.code, res.stderr)
    assert.equal("outdated", report(res)["tree-sitter"].status)
  end)

  for _, dependency in ipairs(deps.manifest) do
    it("exits 1 when " .. dependency.cmd .. " is missing from PATH", function()
      assert(vim.uv.fs_unlink(bin .. "/" .. dependency.cmd))
      local res = run()

      assert.equal(1, res.code, res.stderr)
      for cmd, row in pairs(report(res)) do
        assert.equal(cmd == dependency.cmd and "missing" or "ok", row.status)
      end
    end)
  end
end)
