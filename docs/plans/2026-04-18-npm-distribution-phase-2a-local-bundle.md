# LuxVim npm Distribution — Phase 2a (Local Bundle) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a fully-bundled LuxVim distribution on a single developer machine — `node scripts/release.mjs --no-publish --platform=native` assembles two npm tarballs (main + native runtime), and `npm install -g` of both makes `lux` launch the real Neovim editor with all plugins vendored, fzf working, and a curated treesitter parser set loaded.

**Architecture:** Add a `core/lib/bundle.lua` pipeline hook that sets `spec.dir` for plugins present under `packages/luxvim/vendor/plugins/`, bypassing lazy.nvim's git-clone step. Remove the legacy `debug/` directory precedence (spec.dir injection is now bundle-only). Build a set of Node ESM scripts that fetch upstream assets (plugin tarballs via GitHub codeload, Neovim release tarballs, fzf release binaries, treesitter parsers compiled under headless Neovim) into `packages/luxvim/vendor/` and `packages/runtime-<platform>/`. A `release.mjs` orchestrator calls them in order and produces two `npm pack` tarballs for the developer's native platform.

**Tech Stack:** Node.js 18+ (ESM, built-in `fetch`, `node --test`), system `tar` (macOS/Linux dev), lazy.nvim's `dir` per-spec option, tree-sitter CLI (via nvim-treesitter), upstream Neovim + fzf release tarballs.

**Design spec:** `docs/design/2026-04-17-npm-distribution-design.md` (§2.3 Plugin vendoring, §2.4 fzf binary, §2.5 Treesitter parsers, §3.4 License compliance, stream #3–#5 in the work decomposition).

**Phase 1 status:** Merged or on `feat/npm-foundation`. This plan branches off the latest Phase 1 tip; if Phase 1 merges to main first, rebase onto main.

**Scope boundaries:**

- **IN SCOPE:** `core/lib/bundle.lua` + pipeline hook + tests, removal of `debug/` precedence, `scripts/` build tooling (7 scripts + shared helpers), `packages/runtime-template/` template, updates to `fzf.lua` and `treesitter.lua` plugin specs, local `npm pack + npm install -g` smoke test, gitignoring vendored trees.
- **OUT OF SCOPE (Phase 2b):** `.github/workflows/release.yml`, npm Trusted Publishing setup, cross-platform CI matrix (building for all 5 platforms from one machine). Phase 2a builds only the developer's native platform.
- **OUT OF SCOPE (Phase 2c):** Migration guide document, README rewrite to prefer npm-first install, legacy lowercase user-config detection (O-11).

**Milestone (exit criteria):**

1. Every plenary test still green after bundle.lua lands.
2. Every Node test still green (Phase 1's 11 tests + new tests).
3. `node scripts/release.mjs --no-publish --platform=native` exits 0 and produces two tarballs in `packages/*/`.
4. `npm install -g ./packages/runtime-<native>/josstei-luxvim-runtime-<native>-0.0.1.tgz && npm install -g ./packages/luxvim/josstei-luxvim-0.0.1.tgz` succeeds.
5. `/opt/homebrew/bin/lux` opens the Neovim editor (not the "No LuxVim runtime available" error).
6. Inside that editor, `:Lazy` shows all plugins as loaded/installed from local `dir`, fzf fuzzy-find (`<Space><Space>`) works, `:TSInstallInfo` shows bundled parsers as installed, and `:Themes` opens normally.
7. `./scripts/test.sh` and `./scripts/validate.sh` still green.
8. `./install.sh` git-clone path still works end-to-end.
9. All commits on a new branch `feat/npm-phase-2a-local-bundle`, ready for PR.

---

## Prerequisites

- [ ] **P.1: Branch or worktree off Phase 1's tip**

```bash
# From the main clone (not the existing worktree):
cd /Users/josstei/Development/lux-workspace/LuxVim
git fetch origin
# If Phase 1 is merged to main:
git checkout main && git pull origin main
# If not merged yet:
git checkout feat/npm-foundation

git worktree add -b feat/npm-phase-2a-local-bundle .worktrees/npm-phase-2a
cd .worktrees/npm-phase-2a
git branch --show-current   # Expected: feat/npm-phase-2a-local-bundle
```

- [ ] **P.2: Verify baseline green**

```bash
./scripts/test.sh 2>&1 | grep -E "Failed : |Errors : " | sort | uniq -c   # Expected: only "0" entries
./scripts/validate.sh 2>&1 | tail -3                                       # Expected: "OK: no errors or warnings" + exit 0
(cd packages/luxvim && npm test)                                            # Expected: 11 passing, 0 failing
```

If any command fails, STOP — Phase 2a assumes Phase 1 is green.

- [ ] **P.3: Confirm toolchain**

```bash
node --version   # Expected: >= v18
npm --version    # Expected: >= 9.5
tar --version    # Expected: GNU tar or bsdtar; any version
which nvim       # Expected: path to nvim >= 0.10
```

On macOS, system `tar` is bsdtar — works. On Linux, it's GNU tar — works. Windows is out of scope for 2a local proof.

- [ ] **P.4: Record native platform**

```bash
node -e 'console.log(`${process.platform}-${process.arch}`)'
# Example output: darwin-arm64
```

Note this string — it appears in subsequent paths. In the plan below, `<native>` is a placeholder for this value. Use actual platform string when running commands (e.g., `darwin-arm64`).

---

## File Structure

### Created

| Path | Responsibility |
|---|---|
| `packages/luxvim/lua/core/lib/bundle.lua` | Lua module: detect vendored plugins under `packages/luxvim/vendor/plugins/<name>/` and return `dir` paths |
| `packages/luxvim/tests/unit/core/lib/bundle_spec.lua` | plenary tests for bundle.lua |
| `packages/runtime-template/package.template.json` | Template stamped per-platform by `build-runtime-package.mjs` |
| `packages/runtime-template/README.template.md` | Package-level README for runtime packages |
| `scripts/lib/fetch.mjs` | HTTP GET + tar.gz/zip extraction helper |
| `scripts/lib/spdx.mjs` | License text → SPDX identifier detection |
| `scripts/lib/shell.mjs` | Subprocess wrapper around `child_process.execFileSync` |
| `scripts/lib/paths.mjs` | Path manipulation helpers |
| `scripts/lib/plugin-enumeration.mjs` | Run headless Neovim helper, parse JSON output of plugin specs |
| `scripts/helpers/enumerate-specs.lua` | Headless-Neovim script: dumps `[{name, source, build}]` JSON for each LuxVim plugin |
| `scripts/vendor-plugins.mjs` | Fetch plugin tarballs via GitHub codeload, extract, trim, audit license |
| `scripts/vendor-neovim.mjs` | Fetch upstream Neovim release tarball for target platform |
| `scripts/vendor-fzf.mjs` | Fetch upstream fzf release binary for target platform |
| `scripts/vendor-parsers.mjs` | Compile curated treesitter parser set via nvim-treesitter, collect `.so`/`.dll` |
| `scripts/audit-licenses.mjs` | Validate SPDX IDs across vendored content, emit `THIRD_PARTY.md` + `NOTICE` + `licenses/` |
| `scripts/build-runtime-package.mjs` | Stamp runtime template, copy vendored native assets, ready for `npm pack` |
| `scripts/release.mjs` | Orchestrate all vendoring + audit + pack; `--no-publish` mode for 2a |
| `scripts/tests/spdx.test.mjs` | Node unit tests for SPDX detection |
| `scripts/tests/paths.test.mjs` | Node unit tests for path helpers |
| `scripts/tests/plugin-enumeration.test.mjs` | Node unit tests for plugin-enumeration parsing |

### Modified

| Path | Nature of change |
|---|---|
| `packages/luxvim/lua/core/lib/pipeline/transform.lua` | Replace `debug_mod.has_debug_plugin`/`get_debug_path` check with `bundle_mod.has_vendored_plugin`/`get_vendored_path` |
| `packages/luxvim/lua/core/lib/debug.lua` | Remove `get_debug_path`, `has_debug_plugin`, `list_debug_plugins`. Keep `get_luxvim_root`, `resolve_debug_name`. |
| `packages/luxvim/lua/core/init.lua` | Remove `:LuxDevStatus` command (relied on removed debug functions) |
| `packages/luxvim/lua/plugins/lib/fzf.lua` | Drop the `build` field — fzf binary now ships in runtime package, not compiled at install |
| `packages/luxvim/lua/plugins/editor/treesitter.lua` | Point nvim-treesitter's `parser_install_dir` at bundled parser dir when `LUXVIM_RUNTIME` is set; fall back to XDG path for user-installed parsers |
| `packages/luxvim/tests/unit/core/lib/pipeline/transform_spec.lua` | Update debug-override tests to exercise bundle-override path instead |
| `.gitignore` | Ignore `packages/luxvim/vendor/`, `packages/runtime-*/`, `scripts/tmp/` |
| `packages/luxvim/package.json` | `optionalDependencies`: pin `@josstei/luxvim-runtime-<platform>` at `=0.0.1` for all 5 platforms (even though only one exists locally for 2a) |
| `packages/luxvim/.npmignore` | Add `vendor/.manifest.json` exclusion (if we choose to ship the manifest) — no, keep it. Add `licenses/` inclusion (we want the licenses dir shipped). Actually: replace allowlist-based thinking; `files` in package.json is the whitelist, `.npmignore` just strips dev cruft. Add `licenses/` nothing to exclude. |

### Deleted

| Path | Reason |
|---|---|
| `packages/luxvim/lua/core/lib/debug.lua` functions `get_debug_path`, `has_debug_plugin`, `list_debug_plugins` | Debug-directory precedence removed; bundle precedence replaces it |
| `:LuxDevStatus` command in `core/init.lua` | Depended on removed functions; no longer meaningful |

### Constants pinned in this plan

- **`NVIM_VERSION`**: `v0.11.3`. Used by `vendor-neovim.mjs`. Implementer may bump to whatever is the latest stable on `github.com/neovim/neovim/releases` at execution time.
- **`FZF_VERSION`**: `0.56.0`. Used by `vendor-fzf.mjs`. Implementer may bump to the latest stable on `github.com/junegunn/fzf/releases`.
- **`TS_PARSER_SET`** (17 parsers from spec O-2): `lua, python, javascript, typescript, tsx, rust, go, bash, json, yaml, toml, markdown, markdown_inline, html, css, vim, vimdoc`.
- **License allowlist** (from spec §3.4): `MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, CC0-1.0, Unlicense, Vim, Zlib`.

---

## Phase 2a.1 — Lua runtime: bundle.lua + debug/ removal

**Goal:** Swap the pipeline's plugin-override mechanism from `debug/` directory to `packages/luxvim/vendor/plugins/`. Remove debug-only APIs. After this phase, with `vendor/plugins/` empty (the scripts haven't run yet), lazy.nvim continues to git-clone plugins as before — but the hook is in place for when vendored content exists.

### Task 2a.1.1: Write failing test for `bundle.lua` accessors

**Files:**
- Create: `packages/luxvim/tests/unit/core/lib/bundle_spec.lua`

- [ ] **Step 1: Write the tests**

Create `packages/luxvim/tests/unit/core/lib/bundle_spec.lua` with exactly this content:

```lua
describe("core.lib.bundle", function()
  local bundle
  local tmpdir = require("tests.helpers.tmpdir")

  before_each(function()
    package.loaded["core.lib.bundle"] = nil
    bundle = require("core.lib.bundle")
  end)

  describe("get_vendor_root", function()
    it("returns $LUXVIM_ROOT/vendor/plugins", function()
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = "/fake/pkg"
      assert.equal("/fake/pkg/vendor/plugins", bundle.get_vendor_root())
      vim.env.LUXVIM_ROOT = original
    end)
  end)

  describe("get_vendored_path", function()
    it("joins vendor_root with plugin name", function()
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = "/fake/pkg"
      assert.equal("/fake/pkg/vendor/plugins/nvim-tree.lua", bundle.get_vendored_path("nvim-tree.lua"))
      vim.env.LUXVIM_ROOT = original
    end)
  end)

  describe("has_vendored_plugin", function()
    it("returns false when vendor dir missing", function()
      local root, cleanup = tmpdir.new({})
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = root
      assert.is_false(bundle.has_vendored_plugin("nothing"))
      vim.env.LUXVIM_ROOT = original
      cleanup()
    end)

    it("returns true when vendor/plugins/<name>/ exists", function()
      local root, cleanup = tmpdir.new({
        vendor = { plugins = { ["nvim-tree.lua"] = { ["init.lua"] = "-- stub" } } },
      })
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = root
      assert.is_true(bundle.has_vendored_plugin("nvim-tree.lua"))
      vim.env.LUXVIM_ROOT = original
      cleanup()
    end)

    it("returns false when vendor/plugins/<name> is a file, not a dir", function()
      local root, cleanup = tmpdir.new({
        vendor = { plugins = { ["nvim-tree.lua"] = "-- not a dir" } },
      })
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = root
      assert.is_false(bundle.has_vendored_plugin("nvim-tree.lua"))
      vim.env.LUXVIM_ROOT = original
      cleanup()
    end)
  end)
end)
```

- [ ] **Step 2: Run tests — expect failure**

```bash
./scripts/test.sh 2>&1 | tail -30
```

Expected: failures in `bundle_spec` (`module 'core.lib.bundle' not found`).

- [ ] **Step 3: Commit**

```bash
git add packages/luxvim/tests/unit/core/lib/bundle_spec.lua
git commit -m "test(bundle): failing tests for vendor-plugin resolver"
```

### Task 2a.1.2: Implement `bundle.lua`

**Files:**
- Create: `packages/luxvim/lua/core/lib/bundle.lua`

- [ ] **Step 1: Write the module**

Create `packages/luxvim/lua/core/lib/bundle.lua` with exactly this content:

```lua
local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")

local M = {}

function M.get_vendor_root()
  local root = vim.env.LUXVIM_ROOT or debug_mod.get_luxvim_root()
  return paths.join(root, "vendor", "plugins")
end

function M.get_vendored_path(plugin_name)
  return paths.join(M.get_vendor_root(), plugin_name)
end

function M.has_vendored_plugin(plugin_name)
  local path = M.get_vendored_path(plugin_name)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

return M
```

- [ ] **Step 2: Run tests — expect PASS**

```bash
./scripts/test.sh 2>&1 | tail -20
```

Expected: all bundle_spec tests pass. All other suites still green.

- [ ] **Step 3: Commit**

```bash
git add packages/luxvim/lua/core/lib/bundle.lua
git commit -m "feat(bundle): resolver for vendored plugins"
```

### Task 2a.1.3: Update `transform.lua` to use bundle instead of debug

**Files:**
- Modify: `packages/luxvim/lua/core/lib/pipeline/transform.lua`
- Modify: `packages/luxvim/tests/unit/core/lib/pipeline/transform_spec.lua`

- [ ] **Step 1: Read current transform.lua**

```bash
cat packages/luxvim/lua/core/lib/pipeline/transform.lua
```

Around lines 100–106, the current code reads:

```lua
local debug_name = debug_mod.resolve_debug_name(spec)
local use_debug = debug_mod.has_debug_plugin(debug_name)
local lazy_spec = {...}
if use_debug then
  lazy_spec.dir = debug_mod.get_debug_path(debug_name)
end
```

- [ ] **Step 2: Update the override block**

Replace the `use_debug`/`has_debug_plugin`/`get_debug_path` block with the bundle-based equivalent. At the top of `transform.lua`, add:

```lua
local bundle_mod = require("core.lib.bundle")
```

Alongside the existing `local debug_mod = require("core.lib.debug")`.

Replace the override block (the `if use_debug then ... end` section) with:

```lua
local plugin_name = debug_mod.resolve_debug_name(spec)
if bundle_mod.has_vendored_plugin(plugin_name) then
  lazy_spec.dir = bundle_mod.get_vendored_path(plugin_name)
end
```

Remove the `local use_debug = ...` line — no longer needed.

- [ ] **Step 3: Update transform_spec.lua**

In `packages/luxvim/tests/unit/core/lib/pipeline/transform_spec.lua`, find the test block that stubs `debug_mod.has_debug_plugin` and `debug_mod.get_debug_path` (around lines 80–92). Replace the block with one that stubs the bundle module. The exact content:

Find this block:

```lua
local debug_mod = require("core.lib.debug")
local orig_has = debug_mod.has_debug_plugin
local orig_path = debug_mod.get_debug_path
debug_mod.has_debug_plugin = function(name) return name == "myplugin" end
debug_mod.get_debug_path = function(name) return "/fake/debug/" .. name end
```

Replace with:

```lua
local bundle_mod = require("core.lib.bundle")
local orig_has = bundle_mod.has_vendored_plugin
local orig_path = bundle_mod.get_vendored_path
bundle_mod.has_vendored_plugin = function(name) return name == "myplugin" end
bundle_mod.get_vendored_path = function(name) return "/fake/vendor/" .. name end
```

And find the corresponding restore block:

```lua
debug_mod.has_debug_plugin = orig_has
debug_mod.get_debug_path = orig_path
```

Replace with:

```lua
bundle_mod.has_vendored_plugin = orig_has
bundle_mod.get_vendored_path = orig_path
```

Update the test's assertion: if it previously checked `spec.dir == "/fake/debug/myplugin"`, update to `spec.dir == "/fake/vendor/myplugin"`.

- [ ] **Step 4: Run tests — expect PASS**

```bash
./scripts/test.sh 2>&1 | grep -E "Failed : |Errors : " | sort | uniq -c
```

Expected: only "0" entries.

- [ ] **Step 5: Commit**

```bash
git add packages/luxvim/lua/core/lib/pipeline/transform.lua packages/luxvim/tests/unit/core/lib/pipeline/transform_spec.lua
git commit -m "refactor(pipeline): switch override to bundle precedence"
```

### Task 2a.1.4: Remove debug-only functions from `debug.lua`

**Files:**
- Modify: `packages/luxvim/lua/core/lib/debug.lua`

- [ ] **Step 1: Rewrite `debug.lua` with functions retained**

Replace the entire contents of `packages/luxvim/lua/core/lib/debug.lua` with:

```lua
local paths = require("core.lib.paths")

local M = {}

local _luxvim_root = nil

function M._is_luxvim_root(candidate)
  return vim.fn.filereadable(paths.join(candidate, "init.lua")) == 1
      and vim.fn.isdirectory(paths.join(candidate, "lua", "core")) == 1
end

function M.get_luxvim_root()
  if _luxvim_root then
    return _luxvim_root
  end

  local info = debug.getinfo(1, "S")
  if info and info.source and info.source:sub(1, 1) == "@" then
    local this_file = info.source:sub(2)
    local candidate = paths.normalize(vim.fn.fnamemodify(this_file, ":p:h:h:h:h"))
    if M._is_luxvim_root(candidate) then
      _luxvim_root = candidate
      return _luxvim_root
    end
  end

  for _, path in ipairs(vim.opt.runtimepath:get()) do
    local normalized = paths.normalize(path)
    if M._is_luxvim_root(normalized) then
      _luxvim_root = normalized
      return _luxvim_root
    end
  end

  _luxvim_root = paths.normalize(vim.fn.getcwd())
  return _luxvim_root
end

function M.resolve_debug_name(spec)
  if spec.debug_name then
    return spec.debug_name
  end
  return paths.basename(spec.source)
end

return M
```

Removed: `get_debug_path`, `has_debug_plugin`, `list_debug_plugins`. Retained: `get_luxvim_root`, `resolve_debug_name`, `_is_luxvim_root`.

- [ ] **Step 2: Remove `:LuxDevStatus` command from `core/init.lua`**

Open `packages/luxvim/lua/core/init.lua`. Find the block around lines 146–156 that registers the `:LuxDevStatus` user command. It looks like:

```lua
vim.api.nvim_create_user_command("LuxDevStatus", function()
  local debug_mod = require("core.lib.debug")
  local plugins = debug_mod.list_debug_plugins()
  ...
end, {})
```

Delete this entire command-registration block (not just the body — the `nvim_create_user_command` call in full). Leave the surrounding code intact.

- [ ] **Step 3: Run tests**

```bash
./scripts/test.sh 2>&1 | grep -E "Failed : |Errors : " | sort | uniq -c
```

Expected: only "0" entries. If `discover_spec` or others reference `list_debug_plugins` / `has_debug_plugin` / `get_debug_path`, update them to remove the references (or stubs) — they shouldn't, since transform was the only consumer.

- [ ] **Step 4: Verify no stragglers**

```bash
grep -rn "list_debug_plugins\|has_debug_plugin\|get_debug_path\|LuxDevStatus" packages/luxvim/ scripts/ 2>/dev/null
```

Expected: no matches. If matches appear in docstrings/comments, delete those lines.

- [ ] **Step 5: Commit**

```bash
git add packages/luxvim/lua/core/lib/debug.lua packages/luxvim/lua/core/init.lua
git commit -m "refactor(debug): remove debug/ precedence helpers and LuxDevStatus command"
```

### Task 2a.1.5: Confirm transform pipeline still green end-to-end

- [ ] **Step 1: Run every suite**

```bash
./scripts/test.sh 2>&1 | grep -E "Failed : |Errors : " | sort | uniq -c
./scripts/validate.sh 2>&1 | tail -3
```

Expected: all zeros, validator exits 0.

- [ ] **Step 2: Smoke test — git-clone path still runs**

```bash
rm -rf data/
./install.sh 2>&1 | tail -10
lux --headless +LuxVimValidate +qa
echo "exit: $?"
```

Expected: install completes, lux exits 0 with "config validates cleanly". With `vendor/plugins/` empty, lazy.nvim git-clones plugins as before.

No commit — verification only.

---

## Phase 2a.2 — Shared script infrastructure

**Goal:** Build reusable Node helpers for fetch/extract, SPDX detection, subprocess spawning, and path manipulation. Every subsequent script depends on these.

### Task 2a.2.1: Create `scripts/lib/paths.mjs` with tests

**Files:**
- Create: `scripts/lib/paths.mjs`
- Create: `scripts/tests/paths.test.mjs`

- [ ] **Step 1: Write failing test**

Create `scripts/tests/paths.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { repoRoot, packagesDir, luxvimPackageDir, runtimePackageDir, platformTriple } from '../lib/paths.mjs';

test('platformTriple: darwin/arm64 → darwin-arm64', () => {
  assert.equal(platformTriple('darwin', 'arm64'), 'darwin-arm64');
});

test('platformTriple: linux/x64 → linux-x64', () => {
  assert.equal(platformTriple('linux', 'x64'), 'linux-x64');
});

test('repoRoot: ends with no trailing slash', () => {
  const r = repoRoot();
  assert.equal(r.endsWith('/'), false);
  assert.equal(typeof r, 'string');
  assert.ok(r.length > 1);
});

test('packagesDir: repoRoot + /packages', () => {
  const r = repoRoot();
  assert.equal(packagesDir(), `${r}/packages`);
});

test('luxvimPackageDir: packages + /luxvim', () => {
  assert.equal(luxvimPackageDir(), `${packagesDir()}/luxvim`);
});

test('runtimePackageDir: packages + /runtime-<triple>', () => {
  assert.equal(runtimePackageDir('darwin-arm64'), `${packagesDir()}/runtime-darwin-arm64`);
});
```

- [ ] **Step 2: Run — expect failure**

```bash
node --test scripts/tests/paths.test.mjs 2>&1 | tail -10
```

Expected: module-not-found error.

- [ ] **Step 3: Implement paths.mjs**

Create `scripts/lib/paths.mjs`:

```js
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const SCRIPTS_LIB_DIR = path.dirname(__filename);

export function repoRoot() {
  return path.resolve(SCRIPTS_LIB_DIR, '..', '..');
}

export function packagesDir() {
  return path.join(repoRoot(), 'packages');
}

export function luxvimPackageDir() {
  return path.join(packagesDir(), 'luxvim');
}

export function runtimePackageDir(triple) {
  return path.join(packagesDir(), `runtime-${triple}`);
}

export function vendorPluginsDir() {
  return path.join(luxvimPackageDir(), 'vendor', 'plugins');
}

export function platformTriple(platform, arch) {
  return `${platform}-${arch}`;
}

export function nativePlatformTriple() {
  return platformTriple(process.platform, process.arch);
}
```

- [ ] **Step 4: Run — expect PASS**

```bash
node --test scripts/tests/paths.test.mjs 2>&1 | tail -10
```

Expected: 6 passing, 0 failing.

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/paths.mjs scripts/tests/paths.test.mjs
git commit -m "feat(scripts): path helpers"
```

### Task 2a.2.2: Create `scripts/lib/shell.mjs`

**Files:**
- Create: `scripts/lib/shell.mjs`

No unit test — this is a thin wrapper around `child_process.execFileSync`. Integration tests via the scripts that use it.

- [ ] **Step 1: Write the module**

Create `scripts/lib/shell.mjs`:

```js
import { execFileSync, spawnSync } from 'node:child_process';

export function run(cmd, args, options = {}) {
  return execFileSync(cmd, args, {
    stdio: options.stdio ?? 'inherit',
    cwd: options.cwd,
    env: options.env ?? process.env,
    encoding: options.encoding,
  });
}

export function runCapture(cmd, args, options = {}) {
  const result = spawnSync(cmd, args, {
    cwd: options.cwd,
    env: options.env ?? process.env,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.status !== 0) {
    throw new Error(
      `${cmd} ${args.join(' ')} failed (exit ${result.status}):\n${result.stderr}`
    );
  }
  return result.stdout;
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/lib/shell.mjs
git commit -m "feat(scripts): shell helper"
```

### Task 2a.2.3: Create `scripts/lib/fetch.mjs`

**Files:**
- Create: `scripts/lib/fetch.mjs`

No unit test — wraps `fetch` + system `tar`. Verified via scripts that use it.

- [ ] **Step 1: Write the module**

Create `scripts/lib/fetch.mjs`:

```js
import fs from 'node:fs';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import { run } from './shell.mjs';

export async function downloadToFile(url, destFile, { token } = {}) {
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  const response = await fetch(url, { headers, redirect: 'follow' });
  if (!response.ok) {
    throw new Error(`GET ${url} failed: ${response.status} ${response.statusText}`);
  }
  await fs.promises.mkdir(path.dirname(destFile), { recursive: true });
  const file = fs.createWriteStream(destFile);
  await pipeline(Readable.fromWeb(response.body), file);
  return destFile;
}

export function extractTarGz(tarPath, destDir, { stripComponents = 0 } = {}) {
  fs.mkdirSync(destDir, { recursive: true });
  const args = ['-xzf', tarPath, '-C', destDir];
  if (stripComponents > 0) {
    args.push(`--strip-components=${stripComponents}`);
  }
  run('tar', args);
}

export function extractZip(zipPath, destDir) {
  fs.mkdirSync(destDir, { recursive: true });
  run('unzip', ['-q', '-o', zipPath, '-d', destDir]);
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/lib/fetch.mjs
git commit -m "feat(scripts): fetch + tar/zip extraction helpers"
```

### Task 2a.2.4: Create `scripts/lib/spdx.mjs` with tests

**Files:**
- Create: `scripts/lib/spdx.mjs`
- Create: `scripts/tests/spdx.test.mjs`

- [ ] **Step 1: Write failing test**

Create `scripts/tests/spdx.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { detectSpdxId, isPermissiveSpdx } from '../lib/spdx.mjs';

const MIT_TEXT = `MIT License

Copyright (c) 2024 Example

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.`;

const APACHE_TEXT = `                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION`;

const BSD3_TEXT = `BSD 3-Clause License

Copyright (c) 2024, Example
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:`;

const GPL_TEXT = `                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007`;

test('detectSpdxId: MIT', () => {
  assert.equal(detectSpdxId(MIT_TEXT), 'MIT');
});

test('detectSpdxId: Apache-2.0', () => {
  assert.equal(detectSpdxId(APACHE_TEXT), 'Apache-2.0');
});

test('detectSpdxId: BSD-3-Clause', () => {
  assert.equal(detectSpdxId(BSD3_TEXT), 'BSD-3-Clause');
});

test('detectSpdxId: GPL returns null (disallowed)', () => {
  assert.equal(detectSpdxId(GPL_TEXT), null);
});

test('detectSpdxId: unknown returns null', () => {
  assert.equal(detectSpdxId('Random text with no license keywords'), null);
});

test('isPermissiveSpdx: MIT is permissive', () => {
  assert.equal(isPermissiveSpdx('MIT'), true);
});

test('isPermissiveSpdx: Apache-2.0 is permissive', () => {
  assert.equal(isPermissiveSpdx('Apache-2.0'), true);
});

test('isPermissiveSpdx: GPL-3.0 is not permissive', () => {
  assert.equal(isPermissiveSpdx('GPL-3.0'), false);
});

test('isPermissiveSpdx: null is not permissive', () => {
  assert.equal(isPermissiveSpdx(null), false);
});
```

- [ ] **Step 2: Run — expect failure**

```bash
node --test scripts/tests/spdx.test.mjs 2>&1 | tail -10
```

Expected: module-not-found error.

- [ ] **Step 3: Implement spdx.mjs**

Create `scripts/lib/spdx.mjs`:

```js
const PERMISSIVE_ALLOWLIST = Object.freeze([
  'MIT',
  'Apache-2.0',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'ISC',
  'CC0-1.0',
  'Unlicense',
  'Vim',
  'Zlib',
]);

const DETECTORS = [
  {
    id: 'Apache-2.0',
    test: (t) => /Apache License[\s\S]{0,200}Version 2\.0/i.test(t),
  },
  {
    id: 'BSD-3-Clause',
    test: (t) =>
      /BSD 3-Clause|Redistribution and use in source and binary forms/i.test(t) &&
      /3\. Neither the name of/i.test(t),
  },
  {
    id: 'BSD-2-Clause',
    test: (t) =>
      /BSD 2-Clause|Redistribution and use in source and binary forms/i.test(t) &&
      !/3\. Neither the name of/i.test(t),
  },
  {
    id: 'MIT',
    test: (t) =>
      /\bMIT License\b/i.test(t) ||
      /Permission is hereby granted, free of charge/i.test(t),
  },
  {
    id: 'ISC',
    test: (t) =>
      /ISC License|Permission to use, copy, modify, and\/or distribute this software/i.test(t),
  },
  {
    id: 'CC0-1.0',
    test: (t) => /Creative Commons.*CC0|\bCC0 1\.0\b/i.test(t),
  },
  {
    id: 'Unlicense',
    test: (t) => /This is free and unencumbered software released into the public domain/i.test(t),
  },
  {
    id: 'Vim',
    test: (t) => /VIM LICENSE/i.test(t),
  },
  {
    id: 'Zlib',
    test: (t) => /\bzlib\b[\s\S]{0,200}altered from any source distribution/i.test(t),
  },
];

const DISALLOWED = [
  {
    id: 'GPL',
    test: (t) => /GNU GENERAL PUBLIC LICENSE/i.test(t),
  },
  {
    id: 'LGPL',
    test: (t) => /GNU LESSER GENERAL PUBLIC LICENSE/i.test(t),
  },
  {
    id: 'AGPL',
    test: (t) => /GNU AFFERO GENERAL PUBLIC LICENSE/i.test(t),
  },
  {
    id: 'MPL',
    test: (t) => /Mozilla Public License/i.test(t),
  },
  {
    id: 'SSPL',
    test: (t) => /Server Side Public License/i.test(t),
  },
];

export function detectSpdxId(text) {
  for (const rule of DISALLOWED) {
    if (rule.test(text)) return null;
  }
  for (const rule of DETECTORS) {
    if (rule.test(text)) return rule.id;
  }
  return null;
}

export function isPermissiveSpdx(id) {
  return PERMISSIVE_ALLOWLIST.includes(id);
}

export function allowlist() {
  return [...PERMISSIVE_ALLOWLIST];
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
node --test scripts/tests/spdx.test.mjs 2>&1 | tail -10
```

Expected: 9 passing, 0 failing.

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/spdx.mjs scripts/tests/spdx.test.mjs
git commit -m "feat(scripts): SPDX license detection"
```

---

## Phase 2a.3 — vendor-plugins.mjs

**Goal:** Populate `packages/luxvim/vendor/plugins/<name>/` from `lazy-lock.json`-pinned commits. Depends on a headless-Neovim helper that enumerates plugin specs as JSON.

### Task 2a.3.1: Create headless enumeration helper

**Files:**
- Create: `scripts/helpers/enumerate-specs.lua`

- [ ] **Step 1: Write the Lua helper**

Create `scripts/helpers/enumerate-specs.lua` with exactly this content:

```lua
-- Usage:
--   nvim --headless -u packages/luxvim/init.lua -c 'luafile scripts/helpers/enumerate-specs.lua' -c 'qa!'
-- Output (to stdout):
--   JSON array of { name, source, build } for every discovered LuxVim plugin spec.
--   "name" is the resolved plugin identifier, "source" is the "owner/repo" string,
--   "build" is the spec's build field if present (else null).

local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")
local pipeline = require("core.lib.pipeline")

local ctx = pipeline.new_context()
ctx = pipeline.discover(ctx)
ctx = pipeline.load(ctx)
ctx = pipeline.merge(ctx)

local rows = {}
for _, spec in ipairs(ctx.specs or {}) do
  if spec.source and spec.source ~= "" then
    table.insert(rows, {
      name = debug_mod.resolve_debug_name(spec),
      source = spec.source,
      build = spec.build or vim.NIL,
    })
  end
end

io.write(vim.fn.json_encode(rows))
io.write("\n")
```

**Note:** the exact API calls on the `pipeline` module depend on what's exported. If `pipeline.new_context()` / `pipeline.discover(ctx)` don't exist by those names, adapt to whatever the current module exposes — `require("core.lib.pipeline")` and check the available functions. The goal is: run through the discover+load+merge stages and enumerate `ctx.specs`.

- [ ] **Step 2: Manually test the helper**

```bash
cd packages/luxvim
nvim --headless -u init.lua -c 'luafile ../../scripts/helpers/enumerate-specs.lua' -c 'qa!' 2>&1 | tail -1
```

Expected: a single line of JSON with an array of `{"name":"…","source":"…/…","build":null}` objects. At minimum: `lazy.nvim`, `nvim-treesitter`, `fzf`, `fzf.vim`, `nvim-tree.lua`, `nvim-web-devicons`, `plenary.nvim`, `nvim-lspconfig`, plus the LuxVim plugins.

If the helper errors, adjust the pipeline-API calls to match what's actually exposed. Use `print(vim.inspect(pipeline))` as a debugging aid.

- [ ] **Step 3: Commit**

```bash
cd /Users/josstei/Development/lux-workspace/LuxVim/.worktrees/npm-phase-2a
git add scripts/helpers/enumerate-specs.lua
git commit -m "feat(scripts): headless plugin-spec enumeration helper"
```

### Task 2a.3.2: Create plugin-enumeration wrapper with tests

**Files:**
- Create: `scripts/lib/plugin-enumeration.mjs`
- Create: `scripts/tests/plugin-enumeration.test.mjs`

- [ ] **Step 1: Write failing test**

Create `scripts/tests/plugin-enumeration.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseEnumerationOutput, joinWithLockfile } from '../lib/plugin-enumeration.mjs';

test('parseEnumerationOutput: parses JSON array from last line', () => {
  const raw = `Some pre-noise\n[{"name":"nvim-tree.lua","source":"nvim-tree/nvim-tree.lua","build":null}]`;
  const result = parseEnumerationOutput(raw);
  assert.equal(result.length, 1);
  assert.equal(result[0].name, 'nvim-tree.lua');
  assert.equal(result[0].source, 'nvim-tree/nvim-tree.lua');
  assert.equal(result[0].build, null);
});

test('parseEnumerationOutput: rejects non-JSON', () => {
  assert.throws(() => parseEnumerationOutput('not json'), /parse/i);
});

test('joinWithLockfile: attaches commit SHA from lockfile', () => {
  const specs = [
    { name: 'nvim-tree.lua', source: 'nvim-tree/nvim-tree.lua', build: null },
    { name: 'plenary.nvim', source: 'nvim-lua/plenary.nvim', build: null },
  ];
  const lockfile = {
    'nvim-tree.lua': { branch: 'master', commit: 'abc123' },
    'plenary.nvim': { branch: 'master', commit: 'def456' },
  };
  const result = joinWithLockfile(specs, lockfile);
  assert.equal(result.length, 2);
  assert.equal(result[0].commit, 'abc123');
  assert.equal(result[1].commit, 'def456');
});

test('joinWithLockfile: throws on missing lockfile entry', () => {
  const specs = [{ name: 'unknown', source: 'x/unknown', build: null }];
  const lockfile = {};
  assert.throws(() => joinWithLockfile(specs, lockfile), /unknown/);
});
```

- [ ] **Step 2: Run — expect failure**

```bash
node --test scripts/tests/plugin-enumeration.test.mjs 2>&1 | tail -10
```

Expected: module-not-found error.

- [ ] **Step 3: Implement plugin-enumeration.mjs**

Create `scripts/lib/plugin-enumeration.mjs`:

```js
import fs from 'node:fs';
import path from 'node:path';
import { runCapture } from './shell.mjs';
import { repoRoot, luxvimPackageDir } from './paths.mjs';

export function parseEnumerationOutput(raw) {
  const lines = raw.trim().split('\n');
  const jsonLine = lines[lines.length - 1];
  try {
    const parsed = JSON.parse(jsonLine);
    if (!Array.isArray(parsed)) throw new Error('expected array');
    return parsed;
  } catch (err) {
    throw new Error(`Failed to parse enumeration output as JSON: ${err.message}`);
  }
}

export function readLockfile(lockfilePath) {
  return JSON.parse(fs.readFileSync(lockfilePath, 'utf8'));
}

export function joinWithLockfile(specs, lockfile) {
  return specs.map((s) => {
    const entry = lockfile[s.name];
    if (!entry || !entry.commit) {
      throw new Error(`No lockfile entry for plugin "${s.name}"`);
    }
    return { ...s, commit: entry.commit, branch: entry.branch ?? null };
  });
}

export function enumerate() {
  const pkg = luxvimPackageDir();
  const helper = path.join(repoRoot(), 'scripts', 'helpers', 'enumerate-specs.lua');
  const raw = runCapture(
    'nvim',
    ['--headless', '-u', path.join(pkg, 'init.lua'),
     '-c', `luafile ${helper}`,
     '-c', 'qa!'],
    { cwd: pkg }
  );
  const specs = parseEnumerationOutput(raw);

  const lockfile = readLockfile(path.join(pkg, 'lazy-lock.json'));
  return joinWithLockfile(specs, lockfile);
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
node --test scripts/tests/plugin-enumeration.test.mjs 2>&1 | tail -10
```

Expected: 4 passing, 0 failing.

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/plugin-enumeration.mjs scripts/tests/plugin-enumeration.test.mjs
git commit -m "feat(scripts): plugin-enumeration wrapper"
```

### Task 2a.3.3: Write `vendor-plugins.mjs`

**Files:**
- Create: `scripts/vendor-plugins.mjs`

No dedicated unit test — this script orchestrates the already-tested helpers and performs IO. End-to-end verification in Step 4.

- [ ] **Step 1: Write the script**

Create `scripts/vendor-plugins.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { downloadToFile, extractTarGz } from './lib/fetch.mjs';
import { enumerate } from './lib/plugin-enumeration.mjs';
import { detectSpdxId, isPermissiveSpdx } from './lib/spdx.mjs';
import { luxvimPackageDir, vendorPluginsDir, repoRoot } from './lib/paths.mjs';

const STRIP_DIRS = ['.git', 'tests', 'test', '.github', 'spec', 'benchmarks'];
const LICENSE_CANDIDATES = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING', 'UNLICENSE'];

function rmrf(p) {
  fs.rmSync(p, { recursive: true, force: true });
}

function findLicense(dir) {
  for (const name of LICENSE_CANDIDATES) {
    const p = path.join(dir, name);
    if (fs.existsSync(p)) return { path: p, name, text: fs.readFileSync(p, 'utf8') };
  }
  return null;
}

async function vendorOne(spec, tmpDir) {
  const { name, source, commit } = spec;
  const pluginDir = path.join(vendorPluginsDir(), name);
  rmrf(pluginDir);

  const tarPath = path.join(tmpDir, `${name}-${commit}.tar.gz`);
  const url = `https://codeload.github.com/${source}/tar.gz/${commit}`;
  process.stdout.write(`  Fetching ${source}@${commit.slice(0, 7)} ... `);
  await downloadToFile(url, tarPath, { token: process.env.GITHUB_TOKEN });

  fs.mkdirSync(pluginDir, { recursive: true });
  extractTarGz(tarPath, pluginDir, { stripComponents: 1 });

  for (const dir of STRIP_DIRS) {
    rmrf(path.join(pluginDir, dir));
  }

  const license = findLicense(pluginDir);
  const spdx = license ? detectSpdxId(license.text) : null;

  process.stdout.write(`${spdx ?? 'UNKNOWN'}\n`);
  return { name, source, commit, license_spdx: spdx, license_file: license?.name ?? null };
}

async function main() {
  const tmpDir = path.join(repoRoot(), 'scripts', 'tmp');
  fs.mkdirSync(tmpDir, { recursive: true });

  fs.mkdirSync(vendorPluginsDir(), { recursive: true });

  console.log('Enumerating plugin specs under headless nvim...');
  const specs = enumerate();
  console.log(`Found ${specs.length} plugins.\n`);

  const manifest = [];
  for (const spec of specs) {
    manifest.push(await vendorOne(spec, tmpDir));
  }

  const unknown = manifest.filter((m) => !m.license_spdx);
  if (unknown.length > 0) {
    console.error('\nPlugins with undetected licenses:');
    for (const m of unknown) console.error(`  ${m.name} (${m.source})`);
    console.error('\nExpect `audit-licenses.mjs` to fail until these are resolved.');
  }

  const manifestPath = path.join(vendorPluginsDir(), '.manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  console.log(`\nWrote manifest: ${manifestPath}`);

  rmrf(tmpDir);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/vendor-plugins.mjs
```

- [ ] **Step 3: Run end-to-end**

```bash
node scripts/vendor-plugins.mjs 2>&1 | tail -30
```

Expected: every plugin fetched, license detected for most (MIT/Apache-2.0). Any "UNKNOWN" entries are listed at the end; they'll need to be re-classified in `audit-licenses.mjs` or require a license override.

Verify:

```bash
ls packages/luxvim/vendor/plugins/
# Expected: directories for every plugin in lazy-lock.json
cat packages/luxvim/vendor/plugins/.manifest.json | head -20
# Expected: JSON array with one entry per plugin
```

- [ ] **Step 4: Smoke test — LuxVim loads from vendor tree**

```bash
./scripts/validate.sh 2>&1 | tail -3
echo "exit: $?"
# Expected: exit 0. With vendor/plugins populated, the bundle hook should make
# lazy.nvim see dir= and skip cloning. (Any plugins missing from lazy-lock get
# cloned as usual — not our concern here.)
```

- [ ] **Step 5: Commit — vendor tree is gitignored later (Phase 2a.11)**

```bash
# Add the script but not the populated vendor/ tree
git add scripts/vendor-plugins.mjs
git commit -m "feat(scripts): vendor-plugins.mjs — fetch plugin tarballs via codeload"
```

---

## Phase 2a.4 — vendor-neovim.mjs

**Goal:** Download upstream Neovim release tarball for the native platform into `packages/runtime-<native>/neovim/`.

### Task 2a.4.1: Write `vendor-neovim.mjs`

**Files:**
- Create: `scripts/vendor-neovim.mjs`

- [ ] **Step 1: Write the script**

Create `scripts/vendor-neovim.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { downloadToFile, extractTarGz, extractZip } from './lib/fetch.mjs';
import { runtimePackageDir, nativePlatformTriple, repoRoot } from './lib/paths.mjs';

export const NVIM_VERSION = 'v0.11.3';

const ASSET_MAP = {
  'darwin-arm64': { file: 'nvim-macos-arm64.tar.gz', format: 'tar.gz', stripComponents: 1 },
  'darwin-x64':   { file: 'nvim-macos-x86_64.tar.gz', format: 'tar.gz', stripComponents: 1 },
  'linux-x64':    { file: 'nvim-linux-x86_64.tar.gz', format: 'tar.gz', stripComponents: 1 },
  'linux-arm64':  { file: 'nvim-linux-arm64.tar.gz', format: 'tar.gz', stripComponents: 1 },
  'win32-x64':    { file: 'nvim-win64.zip', format: 'zip', stripComponents: 0 },
};

function parseArgs() {
  const args = process.argv.slice(2);
  let platform = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--platform') platform = args[++i];
    else if (args[i].startsWith('--platform=')) platform = args[i].split('=')[1];
  }
  if (!platform || platform === 'native') platform = nativePlatformTriple();
  return { platform };
}

async function main() {
  const { platform } = parseArgs();
  const asset = ASSET_MAP[platform];
  if (!asset) {
    console.error(`Unsupported platform: ${platform}`);
    console.error(`Supported: ${Object.keys(ASSET_MAP).join(', ')}`);
    process.exit(1);
  }

  const url = `https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${asset.file}`;
  const tmpDir = path.join(repoRoot(), 'scripts', 'tmp');
  fs.mkdirSync(tmpDir, { recursive: true });

  const archive = path.join(tmpDir, asset.file);
  const destDir = path.join(runtimePackageDir(platform), 'neovim');
  fs.rmSync(destDir, { recursive: true, force: true });
  fs.mkdirSync(destDir, { recursive: true });

  console.log(`Fetching Neovim ${NVIM_VERSION} for ${platform}...`);
  console.log(`  ${url}`);
  await downloadToFile(url, archive);

  console.log(`Extracting to ${destDir}...`);
  if (asset.format === 'tar.gz') {
    extractTarGz(archive, destDir, { stripComponents: asset.stripComponents });
  } else {
    extractZip(archive, destDir);
    // Windows zip extracts to nvim-win64/ inside destDir; move contents up one level.
    const inner = path.join(destDir, 'nvim-win64');
    if (fs.existsSync(inner)) {
      for (const entry of fs.readdirSync(inner)) {
        fs.renameSync(path.join(inner, entry), path.join(destDir, entry));
      }
      fs.rmdirSync(inner);
    }
  }

  const nvimBin = path.join(
    destDir, 'bin', platform === 'win32-x64' ? 'nvim.exe' : 'nvim'
  );
  if (!fs.existsSync(nvimBin)) {
    console.error(`Neovim binary not found at expected path: ${nvimBin}`);
    process.exit(1);
  }

  fs.rmSync(archive);
  console.log(`✓ Neovim bundled at ${nvimBin}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

- [ ] **Step 2: Make executable and run for native platform**

```bash
chmod +x scripts/vendor-neovim.mjs
node scripts/vendor-neovim.mjs --platform=native 2>&1 | tail -10
```

Expected: tarball downloaded, extracted; `packages/runtime-<native>/neovim/bin/nvim` exists and is executable.

- [ ] **Step 3: Verify binary runs**

```bash
packages/runtime-$(node -e 'console.log(`${process.platform}-${process.arch}`)')/neovim/bin/nvim --version | head -2
# Expected: "NVIM v0.11.3" on first line
```

- [ ] **Step 4: Commit**

```bash
git add scripts/vendor-neovim.mjs
git commit -m "feat(scripts): vendor-neovim.mjs — download upstream Neovim binary"
```

---

## Phase 2a.5 — vendor-fzf.mjs

**Goal:** Download upstream fzf Go binary for the native platform into `packages/runtime-<native>/fzf/bin/`.

### Task 2a.5.1: Write `vendor-fzf.mjs`

**Files:**
- Create: `scripts/vendor-fzf.mjs`

- [ ] **Step 1: Write the script**

Create `scripts/vendor-fzf.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { downloadToFile, extractTarGz, extractZip } from './lib/fetch.mjs';
import { runtimePackageDir, nativePlatformTriple, repoRoot } from './lib/paths.mjs';

export const FZF_VERSION = '0.56.0';

const ASSET_MAP = {
  'darwin-arm64': { file: (v) => `fzf-${v}-darwin_arm64.tar.gz`, format: 'tar.gz' },
  'darwin-x64':   { file: (v) => `fzf-${v}-darwin_amd64.tar.gz`, format: 'tar.gz' },
  'linux-x64':    { file: (v) => `fzf-${v}-linux_amd64.tar.gz`, format: 'tar.gz' },
  'linux-arm64':  { file: (v) => `fzf-${v}-linux_arm64.tar.gz`, format: 'tar.gz' },
  'win32-x64':    { file: (v) => `fzf-${v}-windows_amd64.zip`,   format: 'zip' },
};

function parseArgs() {
  const args = process.argv.slice(2);
  let platform = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--platform') platform = args[++i];
    else if (args[i].startsWith('--platform=')) platform = args[i].split('=')[1];
  }
  if (!platform || platform === 'native') platform = nativePlatformTriple();
  return { platform };
}

async function main() {
  const { platform } = parseArgs();
  const asset = ASSET_MAP[platform];
  if (!asset) {
    console.error(`Unsupported platform: ${platform}`);
    process.exit(1);
  }

  const file = asset.file(FZF_VERSION);
  const url = `https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${file}`;
  const tmpDir = path.join(repoRoot(), 'scripts', 'tmp');
  fs.mkdirSync(tmpDir, { recursive: true });

  const archive = path.join(tmpDir, file);
  const destDir = path.join(runtimePackageDir(platform), 'fzf', 'bin');
  fs.rmSync(path.dirname(destDir), { recursive: true, force: true });
  fs.mkdirSync(destDir, { recursive: true });

  console.log(`Fetching fzf ${FZF_VERSION} for ${platform}...`);
  console.log(`  ${url}`);
  await downloadToFile(url, archive);

  console.log(`Extracting to ${destDir}...`);
  if (asset.format === 'tar.gz') {
    extractTarGz(archive, destDir);
  } else {
    extractZip(archive, destDir);
  }

  const fzfBin = path.join(destDir, platform === 'win32-x64' ? 'fzf.exe' : 'fzf');
  if (!fs.existsSync(fzfBin)) {
    console.error(`fzf binary not found at expected path: ${fzfBin}`);
    process.exit(1);
  }

  fs.rmSync(archive);
  console.log(`✓ fzf bundled at ${fzfBin}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

- [ ] **Step 2: Make executable, run, verify**

```bash
chmod +x scripts/vendor-fzf.mjs
node scripts/vendor-fzf.mjs --platform=native 2>&1 | tail -10

# Verify binary runs
packages/runtime-$(node -e 'console.log(`${process.platform}-${process.arch}`)')/fzf/bin/fzf --version
# Expected: 0.56.0 or similar
```

- [ ] **Step 3: Commit**

```bash
git add scripts/vendor-fzf.mjs
git commit -m "feat(scripts): vendor-fzf.mjs — download upstream fzf binary"
```

---

## Phase 2a.6 — vendor-parsers.mjs

**Goal:** Compile the curated 17-parser treesitter set for the native platform and collect the `.so` (or `.dll`) artifacts into `packages/runtime-<native>/parsers/`.

### Task 2a.6.1: Write `vendor-parsers.mjs`

**Files:**
- Create: `scripts/vendor-parsers.mjs`

- [ ] **Step 1: Write the script**

Create `scripts/vendor-parsers.mjs`. We use nvim-treesitter's `TSInstall` command in a headless Neovim session (LuxVim already has nvim-treesitter in its spec tree), then copy the compiled parsers out of `$XDG_DATA_HOME/LuxVim/site/parser/`.

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { run } from './lib/shell.mjs';
import { runtimePackageDir, nativePlatformTriple, luxvimPackageDir } from './lib/paths.mjs';

export const TS_PARSER_SET = Object.freeze([
  'lua', 'python', 'javascript', 'typescript', 'tsx',
  'rust', 'go', 'bash', 'json', 'yaml', 'toml',
  'markdown', 'markdown_inline', 'html', 'css',
  'vim', 'vimdoc',
]);

function parseArgs() {
  const args = process.argv.slice(2);
  let platform = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--platform') platform = args[++i];
    else if (args[i].startsWith('--platform=')) platform = args[i].split('=')[1];
  }
  if (!platform || platform === 'native') platform = nativePlatformTriple();
  return { platform };
}

function stagingXdgData() {
  return path.join(os.tmpdir(), `luxvim-ts-parsers-${process.pid}`);
}

async function main() {
  const { platform } = parseArgs();
  if (platform !== nativePlatformTriple()) {
    console.error(`vendor-parsers.mjs only supports the native platform (${nativePlatformTriple()}) in Phase 2a.`);
    console.error(`Cross-compilation lands in Phase 2b via CI matrix.`);
    process.exit(1);
  }

  const stagingData = stagingXdgData();
  fs.rmSync(stagingData, { recursive: true, force: true });
  fs.mkdirSync(stagingData, { recursive: true });

  const pkg = luxvimPackageDir();
  const tsInstallArgs = ['TSInstallSync', ...TS_PARSER_SET].join(' ');

  console.log(`Compiling ${TS_PARSER_SET.length} treesitter parsers into ${stagingData}...`);
  run('nvim', [
    '--headless',
    '--cmd', `let $NVIM_APPNAME = 'LuxVim'`,
    '--cmd', `let $XDG_DATA_HOME = '${stagingData}'`,
    '--cmd', `set rtp^=${pkg}`,
    '-u', path.join(pkg, 'init.lua'),
    '-c', 'lua vim.cmd("TSUpdateSync")',
    '-c', `${tsInstallArgs}`,
    '-c', 'qa!',
  ], { stdio: 'inherit' });

  const srcParserDir = path.join(stagingData, 'LuxVim', 'site', 'parser');
  const destDir = path.join(runtimePackageDir(platform), 'parsers');
  fs.rmSync(destDir, { recursive: true, force: true });
  fs.mkdirSync(destDir, { recursive: true });

  const files = fs.readdirSync(srcParserDir);
  let copied = 0;
  for (const file of files) {
    if (!file.endsWith('.so') && !file.endsWith('.dll')) continue;
    fs.copyFileSync(path.join(srcParserDir, file), path.join(destDir, file));
    copied++;
  }

  console.log(`✓ Copied ${copied} parser(s) to ${destDir}`);
  fs.rmSync(stagingData, { recursive: true, force: true });

  if (copied < TS_PARSER_SET.length) {
    console.warn(`Warning: expected ${TS_PARSER_SET.length} parsers, copied ${copied}. Some parsers may have failed to compile.`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x scripts/vendor-parsers.mjs
node scripts/vendor-parsers.mjs --platform=native 2>&1 | tail -20
```

Expected: 17 parsers compiled. Some parsers may legitimately fail if their grammar is broken at nvim-treesitter's pinned version — document any skipped parsers as open issues for future resolution.

Verify:

```bash
ls packages/runtime-$(node -e 'console.log(`${process.platform}-${process.arch}`)')/parsers/
# Expected: 17 .so files (or close to that count)
```

- [ ] **Step 3: Commit**

```bash
git add scripts/vendor-parsers.mjs
git commit -m "feat(scripts): vendor-parsers.mjs — compile curated treesitter parser set"
```

---

## Phase 2a.7 — audit-licenses.mjs

**Goal:** Validate every vendored plugin has a license from the allowlist; emit `THIRD_PARTY.md`, `NOTICE`, and `licenses/<name>/` directories inside the main package and the runtime package.

### Task 2a.7.1: Write `audit-licenses.mjs`

**Files:**
- Create: `scripts/audit-licenses.mjs`

- [ ] **Step 1: Write the script**

Create `scripts/audit-licenses.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { isPermissiveSpdx, allowlist } from './lib/spdx.mjs';
import { luxvimPackageDir, vendorPluginsDir, runtimePackageDir, nativePlatformTriple } from './lib/paths.mjs';

function readManifest() {
  const manifestPath = path.join(vendorPluginsDir(), '.manifest.json');
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Manifest not found at ${manifestPath}. Run vendor-plugins.mjs first.`);
  }
  return JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
}

function copyLicenseText(plugin, destRoot) {
  if (!plugin.license_file) return;
  const src = path.join(vendorPluginsDir(), plugin.name, plugin.license_file);
  if (!fs.existsSync(src)) return;
  const destDir = path.join(destRoot, 'licenses', plugin.name);
  fs.mkdirSync(destDir, { recursive: true });
  fs.copyFileSync(src, path.join(destDir, plugin.license_file));
}

function emitThirdPartyMd(manifest, destRoot, extraRows = []) {
  const rows = [
    '# Third-Party Software',
    '',
    '| Name | Source | Commit | License |',
    '|---|---|---|---|',
  ];
  for (const m of manifest) {
    rows.push(`| ${m.name} | ${m.source} | ${m.commit.slice(0, 7)} | ${m.license_spdx ?? 'UNKNOWN'} |`);
  }
  for (const row of extraRows) {
    rows.push(`| ${row.name} | ${row.source} | ${row.version} | ${row.license} |`);
  }
  rows.push('');
  rows.push('Full license texts are available under `licenses/<name>/`.');
  rows.push('');
  fs.writeFileSync(path.join(destRoot, 'THIRD_PARTY.md'), rows.join('\n'));
}

function emitNotice(manifest, destRoot) {
  const attribution = manifest
    .filter((m) => m.license_spdx === 'Apache-2.0')
    .map((m) => `- ${m.name} (${m.source}) — Apache License, Version 2.0.`);
  const body = [
    'LuxVim',
    'Copyright (c) LuxVim contributors',
    '',
    'This product includes software developed by:',
    '',
    ...attribution,
    '',
    'Full license texts available under `licenses/<name>/` and `THIRD_PARTY.md`.',
    '',
  ].join('\n');
  fs.writeFileSync(path.join(destRoot, 'NOTICE'), body);
}

function parseArgs() {
  const args = process.argv.slice(2);
  let platform = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--platform') platform = args[++i];
    else if (args[i].startsWith('--platform=')) platform = args[i].split('=')[1];
  }
  if (!platform || platform === 'native') platform = nativePlatformTriple();
  return { platform };
}

async function main() {
  const { platform } = parseArgs();
  const manifest = readManifest();

  const failures = [];
  for (const m of manifest) {
    if (!m.license_spdx) {
      failures.push(`  ${m.name}: license not detected`);
    } else if (!isPermissiveSpdx(m.license_spdx)) {
      failures.push(`  ${m.name}: license "${m.license_spdx}" not on allowlist`);
    }
  }

  if (failures.length > 0) {
    console.error('License audit FAILED:');
    for (const f of failures) console.error(f);
    console.error(`\nAllowlist: ${allowlist().join(', ')}`);
    process.exit(1);
  }

  console.log(`✓ All ${manifest.length} plugins have permissive licenses.`);

  // Emit into main package
  const mainPkg = luxvimPackageDir();
  for (const m of manifest) copyLicenseText(m, mainPkg);
  emitThirdPartyMd(manifest, mainPkg);
  emitNotice(manifest, mainPkg);
  console.log(`  Wrote THIRD_PARTY.md, NOTICE, and licenses/ under ${mainPkg}`);

  // Emit into runtime package with native-asset rows added
  const runtimePkg = runtimePackageDir(platform);
  fs.mkdirSync(runtimePkg, { recursive: true });
  const extraRows = [
    { name: 'Neovim', source: 'neovim/neovim', version: 'v0.11.3', license: 'Apache-2.0 + Vim' },
    { name: 'fzf',    source: 'junegunn/fzf',   version: 'v0.56.0', license: 'MIT' },
  ];
  emitThirdPartyMd(manifest, runtimePkg, extraRows);
  emitNotice(manifest, runtimePkg);

  // Copy Neovim + fzf license texts into runtime package (best-effort: from the vendored content)
  const nvimLicenseSrc = path.join(runtimePkg, 'neovim', 'LICENSE.txt');
  if (fs.existsSync(nvimLicenseSrc)) {
    const destDir = path.join(runtimePkg, 'licenses', 'neovim');
    fs.mkdirSync(destDir, { recursive: true });
    fs.copyFileSync(nvimLicenseSrc, path.join(destDir, 'LICENSE.txt'));
  }

  console.log(`  Wrote THIRD_PARTY.md, NOTICE under ${runtimePkg}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x scripts/audit-licenses.mjs
node scripts/audit-licenses.mjs --platform=native 2>&1 | tail -15
```

Expected: either exits 0 with "All N plugins have permissive licenses" OR lists failures. If any plugin shows UNKNOWN, investigate — the SPDX detector may need a new pattern added to `spdx.mjs`.

Common fix paths:
- `vimscript`-based plugins sometimes have unusual LICENSE files — extend `DETECTORS` in `spdx.mjs`.
- LuxVim's own plugins (`quill.nvim`, `fathom.nvim`, `whisk.nvim`, etc.) should be Apache-2.0 or MIT.

- [ ] **Step 3: Verify emitted files**

```bash
ls packages/luxvim/{NOTICE,THIRD_PARTY.md}
ls packages/luxvim/licenses/ | head -5
# Expected: all files exist; licenses/ contains subdirs per plugin
```

- [ ] **Step 4: Commit**

```bash
git add scripts/audit-licenses.mjs
git commit -m "feat(scripts): audit-licenses.mjs — validate + emit NOTICE/THIRD_PARTY"
```

---

## Phase 2a.8 — Runtime package template + build-runtime-package.mjs

**Goal:** Establish a runtime-package template and a stamp-per-platform script.

### Task 2a.8.1: Create runtime package template

**Files:**
- Create: `packages/runtime-template/package.template.json`
- Create: `packages/runtime-template/README.template.md`

- [ ] **Step 1: Write the package.json template**

Create `packages/runtime-template/package.template.json`:

```json
{
  "name": "@josstei/luxvim-runtime-{{PLATFORM}}",
  "version": "{{VERSION}}",
  "description": "LuxVim runtime binaries for {{PLATFORM}}.",
  "license": "MIT",
  "author": "josstei",
  "homepage": "https://github.com/josstei/luxvim",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/josstei/luxvim.git"
  },
  "os": ["{{OS}}"],
  "cpu": ["{{ARCH}}"],
  "files": [
    "neovim/",
    "fzf/",
    "parsers/",
    "LICENSE",
    "NOTICE",
    "THIRD_PARTY.md",
    "licenses/",
    "README.md"
  ]
}
```

Placeholders `{{PLATFORM}}`, `{{VERSION}}`, `{{OS}}`, `{{ARCH}}` are substituted by `build-runtime-package.mjs`.

- [ ] **Step 2: Write README template**

Create `packages/runtime-template/README.template.md`:

```markdown
# @josstei/luxvim-runtime-{{PLATFORM}}

Platform-specific runtime binaries for LuxVim on {{PLATFORM}}.

Bundles:
- Neovim (upstream release, Apache-2.0 + Vim License)
- fzf (upstream release, MIT)
- Curated treesitter parser set

This package is not meant to be installed directly. Install the main package:

```bash
npm install -g @josstei/luxvim
```

npm will resolve and install the correct runtime package for your platform automatically.

See `THIRD_PARTY.md` and `NOTICE` for attribution of bundled software.
```

- [ ] **Step 3: Write a LICENSE file for the runtime package**

Create `packages/runtime-template/LICENSE.template`:

```
MIT License

Copyright (c) 2026 LuxVim contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

This covers the runtime packaging itself; it does NOT override individual component licenses (Neovim/fzf/parsers each retain their upstream licenses, bundled in `licenses/<component>/`).

- [ ] **Step 4: Commit**

```bash
git add packages/runtime-template/
git commit -m "feat(runtime): package template for platform-specific runtimes"
```

### Task 2a.8.2: Write `build-runtime-package.mjs`

**Files:**
- Create: `scripts/build-runtime-package.mjs`

- [ ] **Step 1: Write the script**

Create `scripts/build-runtime-package.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { runtimePackageDir, packagesDir, nativePlatformTriple, repoRoot } from './lib/paths.mjs';

function parseArgs() {
  const args = process.argv.slice(2);
  let platform = null;
  let version = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--platform') platform = args[++i];
    else if (args[i].startsWith('--platform=')) platform = args[i].split('=')[1];
    else if (args[i] === '--version') version = args[++i];
    else if (args[i].startsWith('--version=')) version = args[i].split('=')[1];
  }
  if (!platform || platform === 'native') platform = nativePlatformTriple();
  if (!version) version = '0.0.1';
  return { platform, version };
}

function stampTemplate(template, values) {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => values[key] ?? '');
}

async function main() {
  const { platform, version } = parseArgs();
  const [os, arch] = platform.split('-');

  const templateDir = path.join(packagesDir(), 'runtime-template');
  const destDir = runtimePackageDir(platform);

  const values = { PLATFORM: platform, VERSION: version, OS: os, ARCH: arch };

  const manifestIn = fs.readFileSync(path.join(templateDir, 'package.template.json'), 'utf8');
  const readmeIn = fs.readFileSync(path.join(templateDir, 'README.template.md'), 'utf8');
  const licenseIn = fs.readFileSync(path.join(templateDir, 'LICENSE.template'), 'utf8');

  fs.mkdirSync(destDir, { recursive: true });
  fs.writeFileSync(path.join(destDir, 'package.json'), stampTemplate(manifestIn, values));
  fs.writeFileSync(path.join(destDir, 'README.md'), stampTemplate(readmeIn, values));
  fs.writeFileSync(path.join(destDir, 'LICENSE'), licenseIn);

  // Verify required content is present (should have been filled by earlier scripts)
  const required = ['neovim/bin', 'fzf/bin', 'parsers', 'NOTICE', 'THIRD_PARTY.md'];
  const missing = required.filter((p) => !fs.existsSync(path.join(destDir, p)));
  if (missing.length > 0) {
    console.error(`Runtime package missing required content:`);
    for (const m of missing) console.error(`  ${m}`);
    console.error(`Run vendor-neovim.mjs, vendor-fzf.mjs, vendor-parsers.mjs, audit-licenses.mjs first.`);
    process.exit(1);
  }

  console.log(`✓ Stamped runtime package at ${destDir}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x scripts/build-runtime-package.mjs
node scripts/build-runtime-package.mjs --platform=native --version=0.0.1 2>&1 | tail -5
```

Expected: stamped package, exits 0.

Verify:

```bash
cat packages/runtime-$(node -e 'console.log(`${process.platform}-${process.arch}`)')/package.json
# Expected: concrete values for name, os, cpu, version
```

- [ ] **Step 3: Commit**

```bash
git add scripts/build-runtime-package.mjs
git commit -m "feat(scripts): build-runtime-package.mjs — stamp template per platform"
```

---

## Phase 2a.9 — release.mjs orchestration

**Goal:** One command that runs every vendoring step + audit + pack for the native platform.

### Task 2a.9.1: Write `release.mjs`

**Files:**
- Create: `scripts/release.mjs`

- [ ] **Step 1: Write the orchestrator**

Create `scripts/release.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { run } from './lib/shell.mjs';
import {
  luxvimPackageDir,
  runtimePackageDir,
  nativePlatformTriple,
  repoRoot,
} from './lib/paths.mjs';

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { platform: 'native', version: '0.0.1', publish: false, skip: [] };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--no-publish') opts.publish = false;
    else if (a === '--publish') opts.publish = true;
    else if (a === '--platform') opts.platform = args[++i];
    else if (a.startsWith('--platform=')) opts.platform = a.split('=')[1];
    else if (a === '--version') opts.version = args[++i];
    else if (a.startsWith('--version=')) opts.version = a.split('=')[1];
    else if (a === '--skip') opts.skip.push(args[++i]);
    else if (a.startsWith('--skip=')) opts.skip.push(a.split('=')[1]);
  }
  if (opts.platform === 'native') opts.platform = nativePlatformTriple();
  return opts;
}

function step(name, skip, fn) {
  if (skip.includes(name)) {
    console.log(`\n=== SKIP: ${name} ===`);
    return;
  }
  console.log(`\n=== ${name} ===`);
  fn();
}

async function main() {
  const opts = parseArgs();
  const scriptsDir = path.join(repoRoot(), 'scripts');
  const runNode = (script, args = []) =>
    run('node', [path.join(scriptsDir, script), ...args], { stdio: 'inherit' });

  step('vendor-plugins', opts.skip, () => runNode('vendor-plugins.mjs'));
  step('vendor-neovim', opts.skip, () => runNode('vendor-neovim.mjs', [`--platform=${opts.platform}`]));
  step('vendor-fzf', opts.skip, () => runNode('vendor-fzf.mjs', [`--platform=${opts.platform}`]));
  step('vendor-parsers', opts.skip, () => runNode('vendor-parsers.mjs', [`--platform=${opts.platform}`]));
  step('audit-licenses', opts.skip, () => runNode('audit-licenses.mjs', [`--platform=${opts.platform}`]));
  step('build-runtime-package', opts.skip, () =>
    runNode('build-runtime-package.mjs', [`--platform=${opts.platform}`, `--version=${opts.version}`])
  );

  console.log(`\n=== pack main ===`);
  run('npm', ['pack'], { cwd: luxvimPackageDir(), stdio: 'inherit' });

  console.log(`\n=== pack runtime ===`);
  run('npm', ['pack'], { cwd: runtimePackageDir(opts.platform), stdio: 'inherit' });

  if (opts.publish) {
    console.log(`\n=== PUBLISH (not supported in Phase 2a; use Phase 2b CI) ===`);
    console.error('release.mjs --publish is not implemented in Phase 2a. Use Phase 2b CI for publishing.');
    process.exit(2);
  }

  console.log(`\n✓ Local bundle ready.`);
  console.log(`  Main:    ${path.join(luxvimPackageDir(), `josstei-luxvim-${opts.version}.tgz`)}`);
  console.log(`  Runtime: ${path.join(runtimePackageDir(opts.platform), `josstei-luxvim-runtime-${opts.platform}-${opts.version}.tgz`)}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

- [ ] **Step 2: Make executable and run end-to-end**

```bash
chmod +x scripts/release.mjs
node scripts/release.mjs --no-publish --platform=native --version=0.0.1 2>&1 | tail -30
```

Expected: every step runs, two tarballs produced, exit 0.

Verify:

```bash
ls packages/luxvim/*.tgz
ls packages/runtime-$(node -e 'console.log(`${process.platform}-${process.arch}`)')/*.tgz
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release.mjs
git commit -m "feat(scripts): release.mjs orchestrator (no-publish mode)"
```

---

## Phase 2a.10 — Update plugin specs for bundling

**Goal:** Strip the fzf `build` field (binary now comes from runtime package) and point nvim-treesitter at the bundled parser dir.

### Task 2a.10.1: Drop fzf build field

**Files:**
- Modify: `packages/luxvim/lua/plugins/lib/fzf.lua`

- [ ] **Step 1: Read current contents**

```bash
cat packages/luxvim/lua/plugins/lib/fzf.lua
```

Expected: a spec with `build = { "..." }` or `build = "..."`.

- [ ] **Step 2: Remove the build field**

Edit the file: remove the `build = ...` line entirely. If this leaves a trailing comma on the previous field, clean that up. If the spec becomes empty of everything but `source`, retain just `source`.

Example final state:

```lua
return {
  source = "junegunn/fzf",
}
```

- [ ] **Step 3: Verify lazy.nvim still picks up fzf correctly**

```bash
./scripts/validate.sh 2>&1 | tail -3
./scripts/test.sh 2>&1 | grep -E "Failed : |Errors : " | sort | uniq -c
```

Expected: validator exits 0; tests all "0" failures.

- [ ] **Step 4: Commit**

```bash
git add packages/luxvim/lua/plugins/lib/fzf.lua
git commit -m "refactor(fzf): drop build field — binary now ships via runtime package"
```

### Task 2a.10.2: Point nvim-treesitter at bundled parser dir

**Files:**
- Modify: `packages/luxvim/lua/plugins/editor/treesitter.lua`

- [ ] **Step 1: Read current contents**

```bash
cat packages/luxvim/lua/plugins/editor/treesitter.lua
```

- [ ] **Step 2: Update opts to inject bundled parser dir**

In `packages/luxvim/lua/plugins/editor/treesitter.lua`, modify the `opts` field (or add one if missing). The goal: when `LUXVIM_RUNTIME` env var is set, tell nvim-treesitter to use `$LUXVIM_RUNTIME/parsers/` as its parser install directory. When unset (git-clone dev mode), fall back to the default.

The concrete edit depends on the current structure. A safe pattern:

```lua
local data = require("core.lib.data")

local function parser_install_dir()
  if vim.env.LUXVIM_RUNTIME and vim.env.LUXVIM_RUNTIME ~= "" then
    return vim.env.LUXVIM_RUNTIME .. "/parsers"
  end
  return data.parser_path()
end

return {
  source = "nvim-treesitter/nvim-treesitter",
  opts = {
    parser_install_dir = parser_install_dir(),
    -- ... retain other existing opts
  },
  config = function(_, opts)
    if vim.env.LUXVIM_RUNTIME and vim.env.LUXVIM_RUNTIME ~= "" then
      vim.opt.runtimepath:append(vim.env.LUXVIM_RUNTIME .. "/parsers")
    end
    require("nvim-treesitter.configs").setup(opts)
  end,
  -- ... retain other existing fields
}
```

Adapt to the file's existing structure — the key behaviors are (a) set `parser_install_dir` conditionally and (b) append the bundled parser dir to `runtimepath` so Neovim finds the `.so` files.

- [ ] **Step 3: Run tests**

```bash
./scripts/test.sh 2>&1 | grep -E "Failed : |Errors : " | sort | uniq -c
./scripts/validate.sh 2>&1 | tail -3
```

Expected: all zeros, validator green.

- [ ] **Step 4: Commit**

```bash
git add packages/luxvim/lua/plugins/editor/treesitter.lua
git commit -m "refactor(treesitter): point parser_install_dir at bundled runtime"
```

### Task 2a.10.3: Extend main package.json — optionalDependencies + files whitelist

**Files:**
- Modify: `packages/luxvim/package.json`

Two edits: declare the 5 runtime packages as optional deps, and extend the `files` allowlist so the generated license artifacts ship in the tarball.

- [ ] **Step 1: Add optionalDependencies**

Add the following top-level key to `packages/luxvim/package.json` (between `"engines"` and `"bin"`, preserving JSON validity):

```json
  "optionalDependencies": {
    "@josstei/luxvim-runtime-darwin-arm64": "=0.0.1",
    "@josstei/luxvim-runtime-darwin-x64": "=0.0.1",
    "@josstei/luxvim-runtime-linux-x64": "=0.0.1",
    "@josstei/luxvim-runtime-linux-arm64": "=0.0.1",
    "@josstei/luxvim-runtime-win32-x64": "=0.0.1"
  },
```

Phase 2a only builds ONE runtime locally (the native one), but declaring all 5 optional deps is the pattern npm consumers expect. `npm install -g` from a local tarball will try to resolve each optional dep from the npm registry and silently skip the ones that don't exist yet (which is all of them, since Phase 2a doesn't publish). The SINGLE runtime tarball installed locally satisfies the native-platform dep through its own `npm install -g` invocation.

- [ ] **Step 2: Extend `files` allowlist**

Replace the `files` array in `packages/luxvim/package.json`:

```json
  "files": [
    "bin/",
    "init.lua",
    "lua/",
    "vendor/",
    "LICENSE",
    "NOTICE",
    "THIRD_PARTY.md",
    "licenses/",
    "README.md"
  ],
```

Rationale:

- `vendor/` — Phase 2a ships the vendored plugin tree so the bundle is self-contained (that's the whole point).
- `NOTICE` / `THIRD_PARTY.md` / `licenses/` — generated by `audit-licenses.mjs`; required by Apache-2.0 / BSD attribution clauses.

- [ ] **Step 3: Validate JSON parses**

```bash
node -e "JSON.parse(require('fs').readFileSync('packages/luxvim/package.json'))"
# Expected: no output
```

- [ ] **Step 4: Sanity-check tarball contents**

```bash
(cd packages/luxvim && npm pack --dry-run 2>&1 | head -30)
```

Expected: output lists `package/bin/`, `package/lua/`, `package/vendor/plugins/...`, `package/NOTICE`, `package/THIRD_PARTY.md`, `package/licenses/...` among the packed entries. If any of those are absent, the `files` array is wrong.

(Note: `--dry-run` reads the filesystem at pack time; the audit-licenses script must have been run already so the artifacts exist.)

- [ ] **Step 5: Commit**

```bash
git add packages/luxvim/package.json
git commit -m "feat(npm): declare runtime optionalDependencies and extend files allowlist"
```

---

## Phase 2a.11 — Gitignore vendored content + end-to-end verification

### Task 2a.11.1: Update `.gitignore`

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Add vendor/runtime/tmp paths**

Append to root `.gitignore`:

```
# Phase 2a vendored content (regenerated by scripts/release.mjs)
packages/luxvim/vendor/
packages/runtime-*/
packages/luxvim/NOTICE
packages/luxvim/THIRD_PARTY.md
packages/luxvim/licenses/
scripts/tmp/
```

Note: NOTICE and THIRD_PARTY.md are generated — if you want them in the published tarball, they'll still be included by `npm pack` (the `files` allowlist in `package.json` takes precedence over `.gitignore` at pack time). Gitignoring them here keeps the repo clean.

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore generated vendor/runtime trees"
```

### Task 2a.11.2: End-to-end install + launch verification

**Files:**
- None modified; controller verification only.

- [ ] **Step 1: Clean build**

```bash
rm -rf packages/luxvim/vendor packages/runtime-*/ packages/luxvim/licenses packages/luxvim/NOTICE packages/luxvim/THIRD_PARTY.md packages/luxvim/*.tgz
node scripts/release.mjs --no-publish --platform=native --version=0.0.1 2>&1 | tail -20
```

Expected: every step runs, two tarballs produced, exit 0.

- [ ] **Step 2: Uninstall any previous npm-installed lux**

```bash
npm uninstall -g @josstei/luxvim 2>&1 | tail -3
which lux 2>&1   # May still show ~/.local/bin/lux from install.sh — that's fine
```

- [ ] **Step 3: Install locally — runtime FIRST, then main**

```bash
NATIVE=$(node -e 'console.log(`${process.platform}-${process.arch}`)')
npm install -g "./packages/runtime-${NATIVE}/josstei-luxvim-runtime-${NATIVE}-0.0.1.tgz" 2>&1 | tail -3
npm install -g "./packages/luxvim/josstei-luxvim-0.0.1.tgz" 2>&1 | tail -3
```

Expected: both install cleanly, no warnings about missing optional deps.

- [ ] **Step 4: Invoke the npm-installed lux**

```bash
/opt/homebrew/bin/lux --version 2>&1 | head -3
# Expected: "NVIM v0.11.3" — proves the bundled nvim is running

/opt/homebrew/bin/lux --headless +LuxVimValidate +qa 2>&1 | tail -3
echo "exit: $?"
# Expected: "LuxVim config validates cleanly" + exit 0
```

- [ ] **Step 5: Interactive smoke test**

```bash
/opt/homebrew/bin/lux
```

Inside the editor, verify:
- [ ] Dashboard or empty buffer opens (no error messages)
- [ ] `:Lazy` opens; every plugin shows as `loaded` or `built-in`; no `not installed` entries
- [ ] `<Space><Space>` opens fzf file finder; it finds files
- [ ] `:TSInstallInfo` shows the 17 bundled parsers as installed
- [ ] `:Themes` opens the theme picker
- [ ] Exit with `<Space>fq`

If any of these fail, investigate which script produced incorrect output and fix.

- [ ] **Step 6: Verify state paths are XDG-compliant**

```bash
ls -d ~/.local/share/LuxVim 2>&1
# Expected: directory exists, created on first launch
ls ~/.local/share/LuxVim/site/parser/ 2>&1 | head -3
# Expected: may be empty (bundled parsers are in LUXVIM_RUNTIME/parsers), that's OK
```

- [ ] **Step 7: Clean up — npm uninstall**

```bash
npm uninstall -g @josstei/luxvim 2>&1 | tail -3
npm uninstall -g "@josstei/luxvim-runtime-${NATIVE}" 2>&1 | tail -3
which lux 2>&1   # Expected: only ~/.local/bin/lux from install.sh remains
```

No commit — verification only. If everything above worked, Phase 2a is complete.

---

## Final Acceptance

- [ ] **F.1: All automated tests green**

```bash
./scripts/test.sh 2>&1 | grep -E "Failed : |Errors : " | sort | uniq -c
./scripts/validate.sh 2>&1 | tail -3 && echo "exit: $?"
(cd packages/luxvim && npm test 2>&1 | tail -5)
node --test scripts/tests/*.test.mjs 2>&1 | tail -5
```

Expected: all zeros / all passing.

- [ ] **F.2: `./install.sh` git-clone path still works**

```bash
rm -rf data/
./install.sh 2>&1 | tail -5
lux --headless +LuxVimValidate +qa
echo "exit: $?"
```

Expected: install completes, lux exits 0.

- [ ] **F.3: Review commit log**

```bash
git log --oneline $(git merge-base main HEAD)..HEAD
```

Expected: ~30-40 focused commits with conventional-commit prefixes.

- [ ] **F.4: Open PR (when ready)**

```bash
gh pr create \
  --title "feat: npm distribution phase 2a — local bundle" \
  --body "$(cat <<'EOF'
## Summary

Phase 2a of the npm distribution: build tooling + runtime package scaffolding + bundle precedence.

After this PR:
- `node scripts/release.mjs --no-publish --platform=native` produces two installable tarballs on the developer's machine.
- Local `npm install -g` of both tarballs results in a working `lux` command that launches the real bundled Neovim.
- Plugins, fzf binary, and the curated 17-parser treesitter set all ship in the tarballs.
- License audit passes against the permissive allowlist (MIT / Apache-2.0 / BSD / ISC / CC0 / Unlicense / Vim / Zlib).

Ref: design spec `docs/design/2026-04-17-npm-distribution-design.md`.

## Scope

- IN: bundle.lua, removal of debug/ precedence, all vendoring scripts, runtime package template, license audit, local end-to-end.
- OUT (Phase 2b): `.github/workflows/release.yml`, npm Trusted Publishing, cross-platform CI matrix (this PR builds only the developer's native platform).
- OUT (Phase 2c): migration guide, README rewrite, README badge updates.

## Test plan

- [ ] `./scripts/test.sh` and `./scripts/validate.sh` green
- [ ] `(cd packages/luxvim && npm test)` green
- [ ] `node --test scripts/tests/*.test.mjs` green
- [ ] `node scripts/release.mjs --no-publish --platform=native --version=0.0.1` exits 0 and produces two tarballs
- [ ] `npm install -g <runtime-tgz>` then `npm install -g <main-tgz>` succeeds
- [ ] `/opt/homebrew/bin/lux --version` reports NVIM v0.11.3
- [ ] `/opt/homebrew/bin/lux --headless +LuxVimValidate +qa` exits 0
- [ ] Interactive smoke: Lazy shows plugins loaded, fzf works, TSInstallInfo shows bundled parsers
- [ ] `./install.sh` git-clone path still works end-to-end
EOF
)"
```

- [ ] **F.5: Post-merge cleanup**

```bash
cd /Users/josstei/Development/lux-workspace/LuxVim
git worktree remove .worktrees/npm-phase-2a
git branch -d feat/npm-phase-2a-local-bundle
```

---

## What's NOT in this plan

Deferred to follow-up plans:

- **Phase 2b — Release pipeline.** `.github/workflows/release.yml` (4-phase pipeline: build → smoke → atomic publish → GitHub release), npm Trusted Publishing (OIDC), cross-platform CI matrix producing all 5 runtime packages, `changesets` integration for auto-CHANGELOG, macOS `codesign -v` verification.
- **Phase 2c — Docs + migration.** `docs/migration-from-git-clone.md`, README rewrite to prefer npm path, Phase 1's deferred legacy-lowercase-config detection (O-11), any NOTICE/THIRD_PARTY.md refinements discovered during real user install.
- **Later:** nightly channel, GitHub Packages mirror, in-editor update UX, Windows arm64, `isSupportedPlatform` re-introduction if consumer emerges.
