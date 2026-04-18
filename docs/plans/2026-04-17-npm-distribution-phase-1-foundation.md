# LuxVim npm Distribution — Phase 1 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure LuxVim into a `packages/luxvim/` monorepo layout, add the main npm package scaffold with a Node launcher, and migrate all writable state from in-tree `data/` paths to per-user XDG paths, while preserving the existing `./install.sh` git-clone workflow unchanged.

**Architecture:** Move canonical source of truth into `packages/luxvim/`, leave a one-line `dofile` thin-wrapper `init.lua` at the repo root for `git clone + install.sh` compatibility. Build a minimal `bin/lux.js` Node launcher that resolves platform-specific runtime packages via `require.resolve`, and exits with a clear, actionable error when none is present (runtime packages arrive in Phase 2). Refactor `core/lib/data.lua` so all writes resolve to `vim.fn.stdpath('data' | 'cache' | 'state')` scoped by `NVIM_APPNAME=LuxVim`, leaving only read-only reads rooted at `$LUXVIM_ROOT`.

**Tech Stack:** Neovim 0.10+, Lua 5.1, lazy.nvim, plenary.nvim (busted harness), Node.js 18+ (ESM), npm 9.5+, GitHub Actions.

**Design spec:** `docs/design/2026-04-17-npm-distribution-design.md` (commit `dba08cd`).

**Scope boundaries:**
- **IN SCOPE:** repo restructure, top-level thin wrapper, `packages/luxvim/package.json`, `bin/lux.js` launcher, unit tests for the launcher, `core/lib/data.lua` refactor to XDG paths, user-config path capitalization change, installer deprecation banners, CI path updates.
- **OUT OF SCOPE (future plan):** `core/lib/bundle.lua` vendor-transform hook, removal of `debug/` precedence, `scripts/vendor-*.mjs` build tooling, runtime package template, `@josstei/luxvim-runtime-*` packages, treesitter bundling, fzf Go binary, license audit script, `release.yml`, migration guide document.

**Milestone (exit criteria for this plan):**
1. `./scripts/test.sh` green — plenary suite passes against the new layout.
2. `./scripts/validate.sh` green — config validation passes.
3. `./install.sh` still completes a full install and `lux` still launches the editor — zero regression on the git-clone path.
4. `cd packages/luxvim && npm pack` produces a `josstei-luxvim-0.0.1.tgz` tarball.
5. `npm install -g ./josstei-luxvim-0.0.1.tgz` installs a `lux` shim on `$PATH`.
6. Running that shim prints the "No LuxVim runtime available" message with exit code 1 (Phase 2 of the design ships the runtime; Phase 1 proves the launcher contract).
7. `NVIM_APPNAME=LuxVim` scoping verified by manual launch of `./install.sh`-installed `lux`: first run populates `~/.local/share/LuxVim/` (not the repo's `data/`).
8. All commits on a dedicated branch, ready for PR.

---

## Prerequisites

- [ ] **P.1: Work in a dedicated worktree** — this plan ships many commits; isolate from any in-flight work.

```bash
cd /Users/josstei/Development/lux-workspace/LuxVim
git worktree add -b feat/npm-foundation .worktrees/npm-foundation
cd .worktrees/npm-foundation
```

Verify: `git branch --show-current` reports `feat/npm-foundation`.

- [ ] **P.2: Verify starting state is clean**

```bash
git status                                 # Expected: "nothing to commit, working tree clean"
./scripts/test.sh 2>&1 | tail -20          # Expected: "SUCCESS" or equivalent plenary success summary
./scripts/validate.sh 2>&1 | tail -5       # Expected: clean exit
```

If any command fails, STOP. The plan assumes a green baseline.

- [ ] **P.3: Verify Node 18+ and npm 9.5+ available**

```bash
node --version   # Expected: v18.x or higher
npm --version    # Expected: 9.5.x or higher
```

If not present, install via `brew install node` (macOS), `apt install nodejs npm` (Linux), etc.

---

## File Structure

Files created, modified, moved, or deleted during this plan.

### Moved (`git mv`, history preserved)

| From | To |
|---|---|
| `init.lua` | `packages/luxvim/init.lua` |
| `lua/` (entire tree) | `packages/luxvim/lua/` |
| `tests/` (entire tree) | `packages/luxvim/tests/` |

### Created

| Path | Responsibility |
|---|---|
| `packages/luxvim/package.json` | npm manifest for the main package |
| `packages/luxvim/.npmignore` | Excludes dev artifacts from published tarball |
| `packages/luxvim/README.md` | One-paragraph package-level readme |
| `packages/luxvim/bin/lux.js` | Node launcher; platform-aware; resolves runtime package |
| `packages/luxvim/bin/lib/runtime-resolver.js` | Pure module: determines runtime package name, resolves its path, emits error text |
| `packages/luxvim/bin/lib/launcher-env.js` | Pure module: constructs env vars for `execFileSync` |
| `packages/luxvim/tests/node/runtime-resolver.test.js` | Node `--test` unit tests for resolver |
| `packages/luxvim/tests/node/launcher-env.test.js` | Node `--test` unit tests for env construction |
| `init.lua` (new root-level thin wrapper) | One-line `dofile` into `packages/luxvim/init.lua` |
| `docs/plans/2026-04-17-npm-distribution-phase-1-foundation.md` | This plan (already written) |

### Modified

| Path | Nature of change |
|---|---|
| `packages/luxvim/lua/core/lib/data.lua` | Route writable paths through `vim.fn.stdpath(...)`; change user-config path from `luxvim` to `LuxVim` |
| `packages/luxvim/tests/unit/core/lib/data_spec.lua` | New tests for XDG-path resolution (file likely does not exist yet; create) |
| `scripts/test.sh` | `cd packages/luxvim` before running plenary |
| `scripts/validate.sh` | `cd packages/luxvim` before running |
| `.github/workflows/test.yml` | Update working-directory / paths |
| `install.sh` | Prepend deprecation banner |
| `install.ps1` | Prepend deprecation banner |
| `tests/minimal_init.lua` (now at `packages/luxvim/tests/minimal_init.lua`) | Update plenary clone path if it references the repo root's `data/` directory |
| `.gitignore` | Add `packages/luxvim/node_modules/`, `packages/luxvim/*.tgz` |

### Unchanged by this plan (but relevant)

- `lazy-lock.json` (stays at repo root — single source of truth).
- `LICENSE` (stays at repo root — Apache 2.0, unchanged).
- `README.md` (top-level, unchanged in this phase; rewrites happen in docs phase).
- `debug/` (unchanged here; precedence removal is a future-phase task).

---

## Phase 1 — Repo Restructure

**Goal:** Move canonical Lua tree into `packages/luxvim/`; leave a thin wrapper at root; keep `./install.sh` and `./scripts/test.sh` green.

### Task 1.1: Create `packages/luxvim/` directory

**Files:**
- Create: `packages/luxvim/` (empty directory; placeholder via `.gitkeep` temporarily)

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/luxvim
touch packages/luxvim/.gitkeep
```

- [ ] **Step 2: Verify**

```bash
ls -la packages/luxvim/
# Expected: directory exists with .gitkeep
```

- [ ] **Step 3: Commit**

```bash
git add packages/luxvim/.gitkeep
git commit -m "chore: scaffold packages/luxvim directory"
```

---

### Task 1.2: Move `init.lua` into `packages/luxvim/`

**Files:**
- Move: `init.lua` → `packages/luxvim/init.lua`

- [ ] **Step 1: Move file preserving git history**

```bash
git mv init.lua packages/luxvim/init.lua
```

- [ ] **Step 2: Verify**

```bash
ls packages/luxvim/init.lua                    # Expected: file exists
test ! -f init.lua && echo "root init.lua moved"  # Expected: printed
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: move init.lua into packages/luxvim/"
```

---

### Task 1.3: Move `lua/` tree into `packages/luxvim/`

**Files:**
- Move: `lua/` → `packages/luxvim/lua/`

- [ ] **Step 1: Move tree**

```bash
git mv lua packages/luxvim/lua
```

- [ ] **Step 2: Verify structure**

```bash
ls packages/luxvim/lua/core/init.lua        # Expected: exists
ls packages/luxvim/lua/plugins/editor       # Expected: exists
test ! -d lua && echo "root lua/ moved"     # Expected: printed
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: move lua/ tree into packages/luxvim/"
```

---

### Task 1.4: Move `tests/` tree into `packages/luxvim/`

**Files:**
- Move: `tests/` → `packages/luxvim/tests/`

- [ ] **Step 1: Move tree**

```bash
git mv tests packages/luxvim/tests
```

- [ ] **Step 2: Verify structure**

```bash
ls packages/luxvim/tests/minimal_init.lua   # Expected: exists
ls packages/luxvim/tests/unit/smoke_spec.lua # Expected: exists
test ! -d tests && echo "root tests/ moved" # Expected: printed
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: move tests/ tree into packages/luxvim/"
```

---

### Task 1.5: Write new root-level `init.lua` thin wrapper

**Files:**
- Create: `init.lua` (at repo root)

- [ ] **Step 1: Write failing test (manual smoke)**

The thin wrapper has no automated test today — it is a one-line delegator. Create a manual verification step after its code lands (see Task 1.7).

- [ ] **Step 2: Write the wrapper**

Create `/Users/josstei/Development/lux-workspace/LuxVim/init.lua`:

```lua
local this_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
dofile(this_dir .. "/packages/luxvim/init.lua")
```

- [ ] **Step 3: Verify file contents**

```bash
cat init.lua
# Expected: the two lines above
wc -l init.lua
# Expected: 2
```

- [ ] **Step 4: Commit**

```bash
git add init.lua
git commit -m "feat: add thin wrapper init.lua delegating into packages/luxvim/"
```

---

### Task 1.5a: Switch `packages/luxvim/init.lua` from `<sfile>` to `debug.getinfo`

**Files:**
- Modify: `packages/luxvim/init.lua`

**Why this task exists:** The moved entry file uses `vim.fn.expand("<sfile>:p:h")` to learn its own directory. When the root-level thin wrapper `dofile`s it, `<sfile>` may resolve to the wrapper's path rather than the delegated file's path. The runtimepath prepend would then target the wrong directory and `require("core.xxx")` would fail. Switch to `debug.getinfo(1, "S").source`, which resolves to the currently-executing file's path regardless of how it was loaded.

- [ ] **Step 1: Read current contents**

```bash
cat packages/luxvim/init.lua
```

Expected (pre-edit): the file opens with `vim.fn.expand("<sfile>:p:h")`.

- [ ] **Step 2: Replace contents**

Replace entire file `packages/luxvim/init.lua` with:

```lua
local function script_dir()
  local info = debug.getinfo(1, "S")
  local source = info and info.source or ""
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  local dir = source:match("(.*[/\\])")
  if not dir then
    return "."
  end
  dir = dir:gsub("\\", "/")
  if dir:sub(-1) == "/" then
    dir = dir:sub(1, -2)
  end
  return dir
end

local current_dir = script_dir()
vim.opt.runtimepath:prepend(current_dir)

local lua_dir = current_dir .. "/lua"
package.path = lua_dir .. "/?.lua;" .. lua_dir .. "/?/init.lua;" .. package.path

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

local core = require("core")
core.setup()
```

- [ ] **Step 3: Verify via both entry points**

Direct invocation via npm-path-equivalent:

```bash
nvim --headless --cmd "set rtp^=$(pwd)/packages/luxvim" -u "$(pwd)/packages/luxvim/init.lua" -c "lua print(vim.opt.runtimepath:get()[1])" -c "qa!" 2>&1 | tail -3
# Expected: the runtimepath's first entry ends with /packages/luxvim
```

Delegated invocation via the root thin wrapper (the install.sh launcher path):

```bash
./scripts/validate.sh 2>&1 | tail -5
# Expected: exit 0
```

Plenary tests still pass:

```bash
./scripts/test.sh 2>&1 | tail -10
# Expected: green
```

- [ ] **Step 4: Commit**

```bash
git add packages/luxvim/init.lua
git commit -m "refactor: resolve script dir via debug.getinfo for robust dofile"
```

---

### Task 1.6: Remove `packages/luxvim/.gitkeep`

**Files:**
- Delete: `packages/luxvim/.gitkeep`

- [ ] **Step 1: Remove placeholder**

```bash
git rm packages/luxvim/.gitkeep
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove packages/luxvim/.gitkeep placeholder"
```

---

### Task 1.7: Update `scripts/test.sh` to `cd` into `packages/luxvim/`

**Files:**
- Modify: `scripts/test.sh`

- [ ] **Step 1: Read current contents**

The current script does `cd "$ROOT"` (the repo root) and calls `nvim -u tests/minimal_init.lua`. After the restructure, `tests/minimal_init.lua` lives at `packages/luxvim/tests/minimal_init.lua`. Two viable edits: either update paths, or `cd packages/luxvim` first and leave the relative paths untouched. We choose the latter for minimal diff to the internals.

- [ ] **Step 2: Replace contents**

Replace entire file `scripts/test.sh` with:

```bash
#!/bin/bash
# Runs the plenary-busted test suite under a clean headless Neovim.
# --clean ignores the user's Neovim config; -u tests/minimal_init.lua
# bootstraps plenary into data/test-plenary/ on first run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/packages/luxvim"

exec nvim --headless --clean -u tests/minimal_init.lua \
  -c "lua require('plenary.test_harness').test_directory('tests/unit', { minimal_init = 'tests/minimal_init.lua', sequential = true })" \
  -c "qa!"
```

- [ ] **Step 3: Run tests**

```bash
./scripts/test.sh 2>&1 | tail -30
```

Expected: all plenary tests report success. If minimal_init.lua fails because it cannot find `lua/core/init.lua`, proceed to Task 1.9 (the minimal_init path check runs against cwd; the cd above should already satisfy it).

- [ ] **Step 4: Commit**

```bash
git add scripts/test.sh
git commit -m "chore: point scripts/test.sh at packages/luxvim/"
```

---

### Task 1.8: Update `scripts/validate.sh` to `cd` into `packages/luxvim/`

**Files:**
- Modify: `scripts/validate.sh`

- [ ] **Step 1: Replace contents**

Replace entire file `scripts/validate.sh` with:

```bash
#!/bin/bash
# Runs LuxVim's pipeline up through the validate stage only (no
# bootstrap, no keymaps, no autocmds). Exits 0 on clean config, 1
# on critical errors. Prints a human-readable report to stdout.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$ROOT/packages/luxvim"
cd "$PKG"

LUXVIM_ROOT="$PKG" NVIM_APPNAME="LuxVim" XDG_DATA_HOME="$PKG/data" \
  exec nvim --headless --cmd "set rtp+=$PKG" -u "$PKG/init.lua" \
  -c "lua require('core').validate_only_or_exit()"
```

- [ ] **Step 2: Run**

```bash
./scripts/validate.sh 2>&1 | tail -10
```

Expected: exits 0 (clean config).

- [ ] **Step 3: Commit**

```bash
git add scripts/validate.sh
git commit -m "chore: point scripts/validate.sh at packages/luxvim/"
```

---

### Task 1.9: Verify `packages/luxvim/tests/minimal_init.lua` resolves new paths

**Files:**
- Inspect: `packages/luxvim/tests/minimal_init.lua`
- Potentially modify if file-existence check references wrong path

- [ ] **Step 1: Read file**

After the `git mv`, `packages/luxvim/tests/minimal_init.lua` should already work because it resolves `cwd .. "/lua/core/init.lua"` and our updated `scripts/test.sh` cds into `packages/luxvim` first.

Verify lines 6-11 say:

```lua
local cwd = vim.fn.getcwd()
if vim.fn.filereadable(cwd .. "/lua/core/init.lua") == 0 then
  io.stderr:write("minimal_init.lua must be run from the LuxVim repo root (cwd=" .. cwd .. ")\n")
  os.exit(1)
end
```

- [ ] **Step 2: Fix the error message**

The error message now references "LuxVim repo root" but the correct cwd is `packages/luxvim`. Update the message for clarity.

Edit `packages/luxvim/tests/minimal_init.lua` — change the error message to:

```lua
io.stderr:write("minimal_init.lua must be run from packages/luxvim (cwd=" .. cwd .. ")\n")
```

- [ ] **Step 3: Verify plenary clone path**

Lines 19-31 clone plenary into `cwd .. "/data/test-plenary/plenary.nvim"`. With cwd=`packages/luxvim`, that becomes `packages/luxvim/data/test-plenary/plenary.nvim`. That's inside the package tree — not ideal for an npm-published package, but acceptable for Phase 1 (the data/ tree is gitignored and will never ship in the tarball — we address it in Task 2.3 via `.npmignore`).

- [ ] **Step 4: Run tests to confirm**

```bash
./scripts/test.sh 2>&1 | tail -20
```

Expected: tests green.

- [ ] **Step 5: Commit**

```bash
git add packages/luxvim/tests/minimal_init.lua
git commit -m "chore: update minimal_init.lua error message for new cwd"
```

---

### Task 1.10: Update `.github/workflows/test.yml` for new paths

**Files:**
- Modify: `.github/workflows/test.yml`

- [ ] **Step 1: Read current contents**

The current workflow calls `./scripts/test.sh` and `./scripts/validate.sh` from repo root. Since those scripts now cd internally, no change to the workflow commands is strictly required. But the `Cache plenary` action keys on `hashFiles('tests/minimal_init.lua')` — that path is now wrong.

- [ ] **Step 2: Replace contents**

Replace entire file `.github/workflows/test.yml` with:

```yaml
name: tests
on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        nvim-version: ['v0.10.0', 'stable', 'nightly']
      fail-fast: false
    steps:
      - uses: actions/checkout@v4

      - uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: ${{ matrix.nvim-version }}

      - name: Cache plenary
        uses: actions/cache@v4
        with:
          path: packages/luxvim/data/test-plenary
          key: plenary-${{ hashFiles('packages/luxvim/tests/minimal_init.lua') }}

      - name: Run tests
        run: ./scripts/test.sh

      - name: Validate sample config
        run: ./scripts/validate.sh
```

- [ ] **Step 3: Verify YAML parses**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))"
# Expected: no output (parse succeeded)
```

If Python is not available, skip — actual validation happens on push.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/test.yml
git commit -m "ci: update test workflow paths for packages/luxvim layout"
```

---

### Task 1.11: Add deprecation banner to `install.sh`

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Locate the insertion point**

`install.sh` prints the logo around line 199. Insert the banner AFTER `print_logo` but BEFORE `# ── System info ──` (around line 201).

- [ ] **Step 2: Edit the file**

In `install.sh`, find this exact block:

```bash
# ── Logo ─────────────────────────────────────────────────
print_logo

# ── System info ──────────────────────────────────────────
```

Replace with:

```bash
# ── Logo ─────────────────────────────────────────────────
print_logo

# ── Deprecation notice ───────────────────────────────────
draw_box "Deprecation notice" \
    "Status" "git-clone path is legacy" \
    "Preferred" "npm install -g @josstei/luxvim" \
    "Removed in" "v1.0 (see docs)"
echo ""

# ── System info ──────────────────────────────────────────
```

- [ ] **Step 3: Run installer manually to confirm banner renders**

In a scratch shell (not CI), run:

```bash
./install.sh 2>&1 | head -40
```

Expected: banner appears between logo and system info. The full install continues to completion.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "chore: add npm deprecation banner to install.sh"
```

---

### Task 1.12: Add deprecation banner to `install.ps1`

**Files:**
- Modify: `install.ps1`

- [ ] **Step 1: Locate the insertion point**

`install.ps1` prints "Installing LuxVim..." around line 9. Insert the banner right after.

- [ ] **Step 2: Edit the file**

In `install.ps1`, find:

```powershell
Write-Host "Installing LuxVim..." -ForegroundColor Blue
Write-Host "LuxVim directory: $LuxVimDir" -ForegroundColor Yellow
```

Replace with:

```powershell
Write-Host "Installing LuxVim..." -ForegroundColor Blue
Write-Host "LuxVim directory: $LuxVimDir" -ForegroundColor Yellow

Write-Host ""
Write-Host "------------------------------------------------" -ForegroundColor DarkGray
Write-Host "DEPRECATION NOTICE" -ForegroundColor Yellow
Write-Host "  The git-clone install path is legacy." -ForegroundColor DarkGray
Write-Host "  Preferred: npm install -g @josstei/luxvim" -ForegroundColor DarkGray
Write-Host "  This path will be removed in LuxVim v1.0." -ForegroundColor DarkGray
Write-Host "------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
```

- [ ] **Step 3: Commit (no direct test; Windows users will validate on their side)**

```bash
git add install.ps1
git commit -m "chore: add npm deprecation banner to install.ps1"
```

---

### Task 1.13: Phase 1 verification

**Files:**
- None modified; verification only.

- [ ] **Step 1: Run test suite**

```bash
./scripts/test.sh 2>&1 | tail -10
```

Expected: plenary reports success for both existing specs (smoke + discover).

- [ ] **Step 2: Run validator**

```bash
./scripts/validate.sh 2>&1 | tail -5
```

Expected: exit 0.

- [ ] **Step 3: Run installer end-to-end**

```bash
./install.sh 2>&1 | tail -20
```

Expected: installer completes; "Installed N plugins"; "LuxVim is ready" message.

- [ ] **Step 4: Launch editor, verify it boots**

```bash
lux --headless +LuxVimValidate +qa 2>&1 | tail -5
echo "exit: $?"
```

Expected: exit 0, no pipeline errors.

- [ ] **Step 5: If all four steps green, tag the phase**

```bash
git log --oneline | head -15
```

Expected: about a dozen Phase 1 commits visible. No tag yet — tags happen at release.

---

## Phase 2 — Main Package Scaffold + Launcher

**Goal:** Deliver `packages/luxvim/package.json` + `bin/lux.js` launcher + unit tests. After this phase, `npm pack && npm install -g <tgz>` produces a working `lux` shim that prints the "no runtime available" error with exit 1 — proving the launcher contract without yet shipping runtime packages.

### Task 2.1: Create `packages/luxvim/package.json`

**Files:**
- Create: `packages/luxvim/package.json`

- [ ] **Step 1: Write the manifest**

Create `packages/luxvim/package.json`:

```json
{
  "name": "@josstei/luxvim",
  "version": "0.0.1",
  "description": "LuxVim — self-contained Neovim distribution.",
  "license": "Apache-2.0",
  "author": "josstei",
  "homepage": "https://github.com/josstei/luxvim",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/josstei/luxvim.git"
  },
  "bugs": {
    "url": "https://github.com/josstei/luxvim/issues"
  },
  "type": "module",
  "engines": {
    "node": ">=18"
  },
  "bin": {
    "lux": "./bin/lux.js"
  },
  "files": [
    "bin/",
    "init.lua",
    "lua/",
    "LICENSE",
    "README.md"
  ],
  "scripts": {
    "test": "node --test tests/node/"
  },
  "keywords": [
    "neovim",
    "nvim",
    "luxvim",
    "editor",
    "distribution"
  ]
}
```

- [ ] **Step 2: Validate**

```bash
cd packages/luxvim && node -e "JSON.parse(require('fs').readFileSync('package.json'))" && cd ../..
# Expected: no output (parse succeeded)
```

- [ ] **Step 3: Commit**

```bash
git add packages/luxvim/package.json
git commit -m "feat(npm): add packages/luxvim/package.json manifest"
```

---

### Task 2.2: Copy `LICENSE` into `packages/luxvim/`

**Files:**
- Create: `packages/luxvim/LICENSE` (copy of repo-root LICENSE)

- [ ] **Step 1: Copy**

```bash
cp LICENSE packages/luxvim/LICENSE
```

- [ ] **Step 2: Verify**

```bash
diff LICENSE packages/luxvim/LICENSE && echo "identical"
# Expected: "identical"
```

- [ ] **Step 3: Commit**

```bash
git add packages/luxvim/LICENSE
git commit -m "chore: copy LICENSE into packages/luxvim/"
```

---

### Task 2.3: Create `packages/luxvim/.npmignore`

**Files:**
- Create: `packages/luxvim/.npmignore`

- [ ] **Step 1: Write the ignore file**

Create `packages/luxvim/.npmignore`:

```
# Exclude dev / runtime-only artifacts from the published tarball.
data/
debug/
tests/
lazy-lock.json

# OS junk
.DS_Store
Thumbs.db

# Editor junk
.vscode/
.idea/
*.swp

# Source control
.git/
.gitignore
```

- [ ] **Step 2: Commit**

```bash
git add packages/luxvim/.npmignore
git commit -m "feat(npm): add .npmignore to exclude dev artifacts"
```

---

### Task 2.4: Create `packages/luxvim/README.md`

**Files:**
- Create: `packages/luxvim/README.md`

- [ ] **Step 1: Write minimal package-level README**

Create `packages/luxvim/README.md`:

```markdown
# @josstei/luxvim

npm distribution of [LuxVim](https://github.com/josstei/luxvim) — a self-contained Neovim distribution.

## Install

```bash
npm install -g @josstei/luxvim
```

## Run

```bash
lux [file]
```

## License

Apache-2.0. See `LICENSE`.
```

- [ ] **Step 2: Commit**

```bash
git add packages/luxvim/README.md
git commit -m "docs: add packages/luxvim/README.md"
```

---

### Task 2.5: Create launcher sub-module — `runtime-resolver.js` — write failing test

**Files:**
- Create: `packages/luxvim/tests/node/runtime-resolver.test.js`

- [ ] **Step 1: Write the test**

Create `packages/luxvim/tests/node/runtime-resolver.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveRuntimePackageName, buildUnsupportedPlatformMessage } from '../../bin/lib/runtime-resolver.js';

test('resolveRuntimePackageName: darwin/arm64', () => {
  assert.equal(
    resolveRuntimePackageName('darwin', 'arm64'),
    '@josstei/luxvim-runtime-darwin-arm64'
  );
});

test('resolveRuntimePackageName: linux/x64', () => {
  assert.equal(
    resolveRuntimePackageName('linux', 'x64'),
    '@josstei/luxvim-runtime-linux-x64'
  );
});

test('resolveRuntimePackageName: win32/x64', () => {
  assert.equal(
    resolveRuntimePackageName('win32', 'x64'),
    '@josstei/luxvim-runtime-win32-x64'
  );
});

test('buildUnsupportedPlatformMessage: names the platform and supported list', () => {
  const msg = buildUnsupportedPlatformMessage('openbsd', 'x64');
  assert.match(msg, /openbsd\/x64/);
  assert.match(msg, /darwin-arm64/);
  assert.match(msg, /linux-x64/);
  assert.match(msg, /win32-x64/);
});

test('buildUnsupportedPlatformMessage: mentions --no-optional hazard', () => {
  const msg = buildUnsupportedPlatformMessage('darwin', 'arm64');
  assert.match(msg, /--no-optional|--omit=optional/);
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/luxvim && node --test tests/node/runtime-resolver.test.js 2>&1 | tail -20
```

Expected: FAIL with "Cannot find module '../../bin/lib/runtime-resolver.js'" (or similar — module doesn't exist yet).

- [ ] **Step 3: Commit the failing test**

```bash
cd ../..
git add packages/luxvim/tests/node/runtime-resolver.test.js
git commit -m "test(npm): failing test for runtime-resolver module"
```

---

### Task 2.6: Implement `runtime-resolver.js` to pass tests

**Files:**
- Create: `packages/luxvim/bin/lib/runtime-resolver.js`

- [ ] **Step 1: Write the module**

Create `packages/luxvim/bin/lib/runtime-resolver.js`:

```js
const SUPPORTED = Object.freeze([
  'darwin-arm64',
  'darwin-x64',
  'linux-arm64',
  'linux-x64',
  'win32-x64',
]);

export function resolveRuntimePackageName(platform, arch) {
  return `@josstei/luxvim-runtime-${platform}-${arch}`;
}

export function isSupportedPlatform(platform, arch) {
  return SUPPORTED.includes(`${platform}-${arch}`);
}

export function buildUnsupportedPlatformMessage(platform, arch) {
  return (
    `No LuxVim runtime available for ${platform}/${arch}.\n` +
    `Supported: ${SUPPORTED.join(', ')}.\n` +
    `If you installed with --no-optional or --omit=optional, reinstall without those flags.\n`
  );
}
```

- [ ] **Step 2: Run tests**

```bash
cd packages/luxvim && node --test tests/node/runtime-resolver.test.js 2>&1 | tail -15
```

Expected: PASS — all 5 tests green.

- [ ] **Step 3: Commit**

```bash
cd ../..
git add packages/luxvim/bin/lib/runtime-resolver.js
git commit -m "feat(npm): implement runtime-resolver module"
```

---

### Task 2.7: Create launcher sub-module — `launcher-env.js` — write failing test

**Files:**
- Create: `packages/luxvim/tests/node/launcher-env.test.js`

- [ ] **Step 1: Write the test**

Create `packages/luxvim/tests/node/launcher-env.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { buildLauncherEnv } from '../../bin/lib/launcher-env.js';

test('buildLauncherEnv: sets NVIM_APPNAME=LuxVim', () => {
  const env = buildLauncherEnv({
    platform: 'darwin',
    base: {},
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.NVIM_APPNAME, 'LuxVim');
});

test('buildLauncherEnv: sets LUXVIM_ROOT and LUXVIM_RUNTIME', () => {
  const env = buildLauncherEnv({
    platform: 'linux',
    base: {},
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.LUXVIM_ROOT, '/pkg/luxvim');
  assert.equal(env.LUXVIM_RUNTIME, '/pkg/runtime');
});

test('buildLauncherEnv: prepends fzf dir to PATH (unix)', () => {
  const env = buildLauncherEnv({
    platform: 'linux',
    base: { PATH: '/usr/bin:/bin' },
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.PATH, `/pkg/runtime/fzf/bin${path.delimiter}/usr/bin:/bin`);
});

test('buildLauncherEnv: prepends fzf dir to Path (windows)', () => {
  const env = buildLauncherEnv({
    platform: 'win32',
    base: { Path: 'C:\\Windows\\System32' },
    luxvimRoot: 'C:\\pkg\\luxvim',
    runtimeRoot: 'C:\\pkg\\runtime',
  });
  const expected = `C:\\pkg\\runtime\\fzf\\bin${path.delimiter}C:\\Windows\\System32`;
  assert.equal(env.Path, expected);
});

test('buildLauncherEnv: preserves other env keys', () => {
  const env = buildLauncherEnv({
    platform: 'linux',
    base: { HOME: '/home/user', LANG: 'en_US.UTF-8' },
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.HOME, '/home/user');
  assert.equal(env.LANG, 'en_US.UTF-8');
});

test('buildLauncherEnv: does not set XDG_* overrides', () => {
  const env = buildLauncherEnv({
    platform: 'linux',
    base: {},
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.XDG_DATA_HOME, undefined);
  assert.equal(env.XDG_CONFIG_HOME, undefined);
  assert.equal(env.XDG_CACHE_HOME, undefined);
  assert.equal(env.XDG_STATE_HOME, undefined);
});
```

- [ ] **Step 2: Run test — expect failure**

```bash
cd packages/luxvim && node --test tests/node/launcher-env.test.js 2>&1 | tail -20
```

Expected: FAIL — module does not exist.

- [ ] **Step 3: Commit failing test**

```bash
cd ../..
git add packages/luxvim/tests/node/launcher-env.test.js
git commit -m "test(npm): failing test for launcher-env module"
```

---

### Task 2.8: Implement `launcher-env.js` to pass tests

**Files:**
- Create: `packages/luxvim/bin/lib/launcher-env.js`

- [ ] **Step 1: Write the module**

Create `packages/luxvim/bin/lib/launcher-env.js`:

```js
import path from 'node:path';

export function buildLauncherEnv({ platform, base, luxvimRoot, runtimeRoot }) {
  const env = { ...base };
  env.NVIM_APPNAME = 'LuxVim';
  env.LUXVIM_ROOT = luxvimRoot;
  env.LUXVIM_RUNTIME = runtimeRoot;

  const fzfDir = path.join(runtimeRoot, 'fzf', 'bin');
  const pathKey = platform === 'win32' ? 'Path' : 'PATH';
  const existing = env[pathKey] ?? '';
  env[pathKey] = `${fzfDir}${path.delimiter}${existing}`;

  return env;
}
```

- [ ] **Step 2: Run tests**

```bash
cd packages/luxvim && node --test tests/node/launcher-env.test.js 2>&1 | tail -10
```

Expected: PASS — all 6 tests green.

- [ ] **Step 3: Commit**

```bash
cd ../..
git add packages/luxvim/bin/lib/launcher-env.js
git commit -m "feat(npm): implement launcher-env module"
```

---

### Task 2.9: Write top-level launcher `bin/lux.js`

**Files:**
- Create: `packages/luxvim/bin/lux.js`

Note: the top-level launcher orchestrates the two helper modules. Its logic is thin (no branching except try/catch). A unit test would need to mock `require.resolve` and `execFileSync`; the cost-vs-value isn't worth it for Phase 1. It is validated end-to-end via Task 2.11.

- [ ] **Step 1: Write the launcher**

Create `packages/luxvim/bin/lux.js`:

```js
#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';
import { createRequire } from 'node:module';
import {
  resolveRuntimePackageName,
  buildUnsupportedPlatformMessage,
} from './lib/runtime-resolver.js';
import { buildLauncherEnv } from './lib/launcher-env.js';

const require = createRequire(import.meta.url);
const { platform, arch } = process;
const runtimePkg = resolveRuntimePackageName(platform, arch);

let runtimeRoot;
try {
  runtimeRoot = path.dirname(require.resolve(`${runtimePkg}/package.json`));
} catch {
  process.stderr.write(buildUnsupportedPlatformMessage(platform, arch));
  process.exit(1);
}

const luxvimRoot = path.dirname(require.resolve('@josstei/luxvim/package.json'));
const nvimBin = path.join(
  runtimeRoot, 'neovim', 'bin',
  platform === 'win32' ? 'nvim.exe' : 'nvim'
);

const env = buildLauncherEnv({
  platform,
  base: process.env,
  luxvimRoot,
  runtimeRoot,
});

execFileSync(
  nvimBin,
  [
    '--cmd', `set rtp^=${luxvimRoot}`,
    '-u', path.join(luxvimRoot, 'init.lua'),
    ...process.argv.slice(2),
  ],
  { stdio: 'inherit', env }
);
```

- [ ] **Step 2: Make executable**

```bash
chmod +x packages/luxvim/bin/lux.js
```

- [ ] **Step 3: Verify executable bit**

```bash
ls -l packages/luxvim/bin/lux.js
# Expected: permissions include the 'x' bit, e.g. -rwxr-xr-x
```

- [ ] **Step 4: Commit**

```bash
git add packages/luxvim/bin/lux.js
git commit -m "feat(npm): implement bin/lux.js launcher"
```

---

### Task 2.10: Run the full Node test suite

**Files:**
- None modified.

- [ ] **Step 1: Run tests**

```bash
cd packages/luxvim && node --test tests/node/ 2>&1 | tail -20
```

Expected: all 11 tests pass (5 resolver + 6 env), no failures.

- [ ] **Step 2: Return to repo root**

```bash
cd ../..
```

No commit — verification only.

---

### Task 2.11: Verify `npm pack` + `npm install -g` end-to-end

**Files:**
- None modified; this is an end-to-end smoke test.

- [ ] **Step 1: Pack the package**

```bash
cd packages/luxvim
npm pack 2>&1 | tail -10
ls *.tgz
# Expected: josstei-luxvim-0.0.1.tgz exists
```

- [ ] **Step 2: Inspect tarball contents**

```bash
tar -tzf josstei-luxvim-0.0.1.tgz | sort
```

Expected: lists of `package/bin/`, `package/bin/lib/`, `package/bin/lux.js`, `package/init.lua`, `package/lua/...`, `package/LICENSE`, `package/README.md`, `package/package.json`. **Must not** include `package/data/`, `package/tests/`, `package/debug/`, `package/lazy-lock.json`.

If `data/` is present, fix `.npmignore` and re-pack.

- [ ] **Step 3: Install globally**

```bash
npm install -g ./josstei-luxvim-0.0.1.tgz 2>&1 | tail -15
# Expected: "added 1 package" or similar, no errors
```

- [ ] **Step 4: Check the shim exists**

```bash
which lux
# Expected: path inside your global npm prefix, e.g., /usr/local/bin/lux or similar
```

- [ ] **Step 5: Run and verify the expected error**

```bash
lux 2>&1
echo "exit: $?"
```

Expected output: the "No LuxVim runtime available" message with exit 1. This is the correct Phase 1 behavior — the main package is installed, the launcher works, it correctly reports that no runtime package exists yet.

- [ ] **Step 6: Uninstall to leave environment clean**

```bash
npm uninstall -g @josstei/luxvim
which lux
# Expected: no output (lux is gone)
```

- [ ] **Step 7: Remove local tarball**

```bash
rm packages/luxvim/josstei-luxvim-0.0.1.tgz
```

- [ ] **Step 8: Add tgz to .gitignore**

Append to root `.gitignore`:

```
packages/luxvim/*.tgz
packages/luxvim/node_modules/
```

- [ ] **Step 9: Commit gitignore update**

```bash
cd ../..
git add .gitignore
git commit -m "chore: gitignore npm pack output and node_modules under packages/luxvim"
```

---

### Task 2.12: Phase 2 verification

**Files:**
- None modified; end-of-phase sanity check.

- [ ] **Step 1: Run full plenary suite**

```bash
./scripts/test.sh 2>&1 | tail -10
```

Expected: green.

- [ ] **Step 2: Run Node test suite**

```bash
cd packages/luxvim && node --test tests/node/ 2>&1 | tail -10 && cd ../..
```

Expected: green.

- [ ] **Step 3: Run git-clone install path**

```bash
./install.sh 2>&1 | tail -10
```

Expected: success.

---

## Phase 3 — Runtime Bootstrap Migration (XDG paths)

**Goal:** Refactor `packages/luxvim/lua/core/lib/data.lua` so all writable paths resolve via `vim.fn.stdpath(...)`, scoped by `NVIM_APPNAME=LuxVim`. Read-only paths (lockfile, package root) keep using `$LUXVIM_ROOT`. User-config path casing changes from `luxvim` to `LuxVim` to match `NVIM_APPNAME`.

### Task 3.1: Read and catalog current `data.lua` behavior

**Files:**
- Inspect: `packages/luxvim/lua/core/lib/data.lua`

- [ ] **Step 1: Read the current module**

```bash
cat packages/luxvim/lua/core/lib/data.lua
```

Expected shape:

```lua
local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")
local M = {}
local _root
function M.root() ... end
function M.lazy_path() return paths.join(M.root(), "data", "lazy", "lazy.nvim") end
function M.lazy_root() return paths.join(M.root(), "data", "lazy") end
function M.lockfile_path() return paths.join(M.root(), "lazy-lock.json") end
function M.luxlsp_path() return paths.join(M.root(), "data", "luxlsp") end
function M.parser_path() return paths.join(M.root(), "data", "site") end
function M.user_config_path() return ... "luxvim" end
return M
```

- [ ] **Step 2: Catalog the call sites (for reference, not modification)**

```bash
grep -rn "require(\"core.lib.data\")" packages/luxvim/lua packages/luxvim/tests
grep -rn "data\\.\\(root\\|join\\|ensure\\|lazy\\|luxlsp\\|site\\|lockfile\\|user_config\\)" packages/luxvim/lua
```

Expected matches in:
- `packages/luxvim/lua/core/init.lua`
- `packages/luxvim/lua/core/lib/bootstrap.lua` (uses `lazy_path`, `lazy_root`)
- `packages/luxvim/lua/core/lib/registry.lua`
- `packages/luxvim/lua/core/lib/pipeline/discover.lua` (uses `data.root() .. /data/dynamic-specs`)
- `packages/luxvim/lua/plugins/editor/treesitter.lua` (likely `parser_path`)
- `packages/luxvim/lua/plugins/lsp/lspconfig.lua` (`luxlsp_path`)
- `packages/luxvim/lua/plugins/ui/config/theme-picker.lua` (hardcoded `data.root() .. /data/...`)
- `packages/luxvim/tests/unit/core/lib/pipeline/discover_spec.lua`

No commit — catalog only.

---

### Task 3.2: Write failing tests for new `data.lua` contract

**Files:**
- Create: `packages/luxvim/tests/unit/core/lib/data_spec.lua`

- [ ] **Step 1: Write the tests**

Create `packages/luxvim/tests/unit/core/lib/data_spec.lua`:

```lua
describe("core.lib.data", function()
  local data
  local original_stdpath

  before_each(function()
    package.loaded["core.lib.data"] = nil
    data = require("core.lib.data")
    original_stdpath = vim.fn.stdpath
  end)

  after_each(function()
    vim.fn.stdpath = original_stdpath
  end)

  local function stub_stdpath(map)
    vim.fn.stdpath = function(name)
      return map[name] or error("unexpected stdpath(" .. tostring(name) .. ")")
    end
  end

  describe("state_root", function()
    it("returns vim.fn.stdpath('data')", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data", data.state_root())
    end)
  end)

  describe("lazy_root", function()
    it("is under state_root (not $LUXVIM_ROOT/data)", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/lazy", data.lazy_root())
    end)
  end)

  describe("lazy_path", function()
    it("is state_root/lazy/lazy.nvim", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/lazy/lazy.nvim", data.lazy_path())
    end)
  end)

  describe("luxlsp_path", function()
    it("is state_root/luxlsp", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/luxlsp", data.luxlsp_path())
    end)
  end)

  describe("parser_path", function()
    it("is state_root/site", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/site", data.parser_path())
    end)
  end)

  describe("installed_themes_path", function()
    it("is state_root/installed-themes.json", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/installed-themes.json", data.installed_themes_path())
    end)
  end)

  describe("dynamic_specs_dir", function()
    it("is state_root/dynamic-specs", function()
      stub_stdpath({ data = "/fake/data" })
      assert.equal("/fake/data/dynamic-specs", data.dynamic_specs_dir())
    end)
  end)

  describe("lockfile_path", function()
    it("stays under the LuxVim package root (read-only)", function()
      local original = vim.env.LUXVIM_ROOT
      vim.env.LUXVIM_ROOT = "/fake/pkg"
      assert.equal("/fake/pkg/lazy-lock.json", data.lockfile_path())
      vim.env.LUXVIM_ROOT = original
    end)
  end)

  describe("user_config_path", function()
    it("respects $LUXVIM_CONFIG when set", function()
      local original = vim.env.LUXVIM_CONFIG
      vim.env.LUXVIM_CONFIG = "/custom/luxvim-config"
      assert.equal("/custom/luxvim-config", data.user_config_path())
      vim.env.LUXVIM_CONFIG = original
    end)

    it("uses $XDG_CONFIG_HOME/LuxVim (capitalized) by default", function()
      local orig_lc = vim.env.LUXVIM_CONFIG
      local orig_xdg = vim.env.XDG_CONFIG_HOME
      vim.env.LUXVIM_CONFIG = nil
      vim.env.XDG_CONFIG_HOME = "/fake/config"
      assert.equal("/fake/config/LuxVim", data.user_config_path())
      vim.env.LUXVIM_CONFIG = orig_lc
      vim.env.XDG_CONFIG_HOME = orig_xdg
    end)
  end)
end)
```

- [ ] **Step 2: Run tests — expect failures**

```bash
./scripts/test.sh 2>&1 | tail -40
```

Expected: many failures in `data_spec` describing: `state_root is not a function`, `lazy_root == /fake/pkg/data/lazy (got)`, `user_config_path == /fake/config/luxvim (got)`, etc.

- [ ] **Step 3: Commit failing tests**

```bash
git add packages/luxvim/tests/unit/core/lib/data_spec.lua
git commit -m "test(data): failing tests for XDG path migration"
```

---

### Task 3.3: Refactor `data.lua` to XDG paths

**Files:**
- Modify: `packages/luxvim/lua/core/lib/data.lua`

- [ ] **Step 1: Rewrite the module**

Replace entire file `packages/luxvim/lua/core/lib/data.lua` with:

```lua
local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")

local M = {}

local _root

function M.root()
  if _root then
    return _root
  end
  _root = vim.env.LUXVIM_ROOT or debug_mod.get_luxvim_root()
  return _root
end

function M.state_root()
  return vim.fn.stdpath("data")
end

function M.lazy_path()
  return paths.join(M.state_root(), "lazy", "lazy.nvim")
end

function M.lazy_root()
  return paths.join(M.state_root(), "lazy")
end

function M.lockfile_path()
  return paths.join(M.root(), "lazy-lock.json")
end

function M.luxlsp_path()
  return paths.join(M.state_root(), "luxlsp")
end

function M.parser_path()
  return paths.join(M.state_root(), "site")
end

function M.installed_themes_path()
  return paths.join(M.state_root(), "installed-themes.json")
end

function M.dynamic_specs_dir()
  return paths.join(M.state_root(), "dynamic-specs")
end

function M.user_config_path()
  if vim.env.LUXVIM_CONFIG and vim.env.LUXVIM_CONFIG ~= "" then
    return vim.env.LUXVIM_CONFIG
  end
  local base = vim.env.XDG_CONFIG_HOME or paths.join(vim.env.HOME or "", ".config")
  return paths.join(base, "LuxVim")
end

return M
```

- [ ] **Step 2: Run tests — expect pass**

```bash
./scripts/test.sh 2>&1 | tail -30
```

Expected: all data_spec tests pass. **Existing tests (discover_spec, smoke_spec) must also still pass.** If discover_spec fails, see Task 3.4.

- [ ] **Step 3: Commit refactor**

```bash
git add packages/luxvim/lua/core/lib/data.lua
git commit -m "refactor(data): route writable paths through vim.fn.stdpath"
```

---

### Task 3.3a: Update `install.sh` data paths for `NVIM_APPNAME` scoping

**Files:**
- Modify: `install.sh`

**Why this task exists:** `install.sh` pre-creates `<repo>/data/{lazy,luxlsp,site}` and bootstraps `lazy.nvim` into `<repo>/data/lazy/lazy.nvim`. After the `data.lua` refactor (Task 3.3), `data.lazy_path()` resolves via `vim.fn.stdpath('data')`, which — with `NVIM_APPNAME=LuxVim` and `XDG_DATA_HOME=<repo>/data` — returns `<repo>/data/LuxVim/lazy/lazy.nvim`. The installer's pre-created path no longer matches what the runtime looks for, so plugins would be re-cloned elsewhere and the manual bootstrap becomes invisible. Update the installer to target the scoped path.

- [ ] **Step 1: Read current relevant lines**

```bash
grep -n "LUXVIM_DATA_DIR" install.sh
```

Expected matches: the variable definition `LUXVIM_DATA_DIR="$LUXVIM_DIR/data"` and downstream uses for `mkdir`, `LAZY_PATH`, etc.

- [ ] **Step 2: Edit the variable**

In `install.sh`, find the line:

```bash
LUXVIM_DATA_DIR="$LUXVIM_DIR/data"
```

Replace with:

```bash
LUXVIM_DATA_DIR="$LUXVIM_DIR/data/LuxVim"
```

All downstream uses (`mkdir "$LUXVIM_DATA_DIR/lazy" ...` and `LAZY_PATH="$LUXVIM_DATA_DIR/lazy/lazy.nvim"`) automatically inherit the new path.

- [ ] **Step 3: Verify**

```bash
grep -n "LUXVIM_DATA_DIR" install.sh
# Expected: first line ends with "/data/LuxVim", downstream lines unchanged
```

- [ ] **Step 4: End-to-end re-run**

```bash
rm -rf data/
./install.sh 2>&1 | tail -15
ls -d data/LuxVim/lazy/lazy.nvim   # Expected: directory exists
test ! -d data/lazy && echo "no legacy data/lazy at repo root" || echo "FAIL: legacy path present"
```

Expected: lazy lives under `data/LuxVim/lazy/`; no `data/lazy/` at repo root.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "fix(install): scope data dir by NVIM_APPNAME=LuxVim"
```

---

### Task 3.3b: Update `install.ps1` data paths for `NVIM_APPNAME` scoping

**Files:**
- Modify: `install.ps1`

- [ ] **Step 1: Edit the dataDirs array**

In `install.ps1`, find:

```powershell
$dataDirs = @("data\lazy", "data\luxlsp", "data\site")
```

Replace with:

```powershell
$dataDirs = @("data\LuxVim\lazy", "data\LuxVim\luxlsp", "data\LuxVim\site")
```

- [ ] **Step 2: Edit the lazyPath assignment**

Find:

```powershell
$lazyPath = Join-Path $LuxVimDir "data\lazy\lazy.nvim"
```

Replace with:

```powershell
$lazyPath = Join-Path $LuxVimDir "data\LuxVim\lazy\lazy.nvim"
```

- [ ] **Step 3: Commit (no direct test on non-Windows hosts)**

```bash
git add install.ps1
git commit -m "fix(install): scope Windows data dir by NVIM_APPNAME=LuxVim"
```

---

### Task 3.4: Update call sites that built paths inline

**Files:**
- Modify: `packages/luxvim/lua/plugins/ui/config/theme-picker.lua`
- Modify: `packages/luxvim/lua/core/lib/pipeline/discover.lua`

The spec files hardcoded `data.root() .. "/data/installed-themes.json"` and `data.root() .. "/data/dynamic-specs"`. Switch them to use the new `data.installed_themes_path()` and `data.dynamic_specs_dir()` accessors.

- [ ] **Step 1: Edit `theme-picker.lua`**

In `packages/luxvim/lua/plugins/ui/config/theme-picker.lua`, find lines around 17 and 21. Replace:

```lua
return paths.join(data.root(), "data", "installed-themes.json")
```

with:

```lua
return data.installed_themes_path()
```

And replace:

```lua
return paths.join(data.root(), "data", "dynamic-specs")
```

with:

```lua
return data.dynamic_specs_dir()
```

- [ ] **Step 2: Edit `discover.lua`**

In `packages/luxvim/lua/core/lib/pipeline/discover.lua`, find line 70-71:

```lua
local data = require("core.lib.data")
local dynamic_dir = paths.join(data.root(), "data", "dynamic-specs")
```

Replace with:

```lua
local data = require("core.lib.data")
local dynamic_dir = data.dynamic_specs_dir()
```

- [ ] **Step 3: Run tests**

```bash
./scripts/test.sh 2>&1 | tail -20
```

Expected: all tests green (smoke + discover + data).

- [ ] **Step 4: Commit call-site updates**

```bash
git add packages/luxvim/lua/plugins/ui/config/theme-picker.lua packages/luxvim/lua/core/lib/pipeline/discover.lua
git commit -m "refactor(data): route theme-picker and discover through new accessors"
```

---

### Task 3.5: Update `with_luxvim_data_root` helper in `discover_spec.lua`

**Files:**
- Modify: `packages/luxvim/tests/unit/core/lib/pipeline/discover_spec.lua`

**Why this task exists:** The existing `discover_spec.lua` has a helper `with_luxvim_data_root(root, fn)` that sets `vim.env.LUXVIM_ROOT = root` and reloads the `data` module. Before Task 3.3, `data.root()` returned `LUXVIM_ROOT`, so `data.root() .. "/data/dynamic-specs"` resolved to `<tmpdir>/data/dynamic-specs`. After the refactor, `data.dynamic_specs_dir()` derives its path from `vim.fn.stdpath("data")`, which is unrelated to `LUXVIM_ROOT`. The helper must additionally stub `vim.fn.stdpath("data")` so the dynamic-specs test's fixture tree (which nests `dynamic-specs` under `data/`) still resolves correctly.

- [ ] **Step 1: Replace the `with_luxvim_data_root` helper**

In `packages/luxvim/tests/unit/core/lib/pipeline/discover_spec.lua`, find the current helper:

```lua
local function with_luxvim_data_root(root, fn)
  local orig_env = vim.env.LUXVIM_ROOT
  vim.env.LUXVIM_ROOT = root
  package.loaded["core.lib.data"] = nil
  data_mod = require("core.lib.data")
  local ok, err = pcall(fn)
  vim.env.LUXVIM_ROOT = orig_env
  package.loaded["core.lib.data"] = nil
  data_mod = require("core.lib.data")
  if not ok then error(err) end
end
```

Replace with:

```lua
local function with_luxvim_data_root(root, fn)
  local orig_env = vim.env.LUXVIM_ROOT
  local orig_stdpath = vim.fn.stdpath
  vim.env.LUXVIM_ROOT = root
  vim.fn.stdpath = function(name)
    if name == "data" then
      return root .. "/data"
    end
    return orig_stdpath(name)
  end
  package.loaded["core.lib.data"] = nil
  data_mod = require("core.lib.data")
  local ok, err = pcall(fn)
  vim.env.LUXVIM_ROOT = orig_env
  vim.fn.stdpath = orig_stdpath
  package.loaded["core.lib.data"] = nil
  data_mod = require("core.lib.data")
  if not ok then error(err) end
end
```

This preserves the test fixture layout (`data.dynamic-specs.dyn.lua`) while routing `data.dynamic_specs_dir()` to the tmpdir via the stubbed `stdpath`.

- [ ] **Step 2: Run tests**

```bash
./scripts/test.sh 2>&1 | tail -15
```

Expected: all discover_spec tests green, all data_spec tests green.

- [ ] **Step 3: Commit**

```bash
git add packages/luxvim/tests/unit/core/lib/pipeline/discover_spec.lua
git commit -m "test(discover): stub vim.fn.stdpath in data-root helper"
```

---

### Task 3.6: Verify install.sh still works after data-path migration

**Files:**
- None modified; end-to-end verification.

When `install.sh` runs, it sets `NVIM_APPNAME=LuxVim` and `XDG_DATA_HOME=<repo>/data` — so `vim.fn.stdpath("data")` resolves to `<repo>/data/LuxVim`. The subdirectories `lazy`, `luxlsp`, etc. land under that path.

**This is a subtle change from before.** Previously the tree was `<repo>/data/lazy`. Now it's `<repo>/data/LuxVim/lazy`. Pre-existing installations' plugin state effectively becomes invisible — first launch after this change triggers a fresh plugin sync.

- [ ] **Step 1: Wipe existing `data/` for clean test**

```bash
rm -rf data/
```

- [ ] **Step 2: Run installer**

```bash
./install.sh 2>&1 | tail -20
```

Expected: completes; "Installed N plugins" reported.

- [ ] **Step 3: Verify new tree shape**

```bash
ls -d data/LuxVim/lazy 2>&1
# Expected: directory exists
```

Note the extra `LuxVim/` level — that is the `NVIM_APPNAME` scoping. Correct behavior.

- [ ] **Step 4: Launch editor, validate**

```bash
lux --headless +LuxVimValidate +qa
echo "exit: $?"
```

Expected: exit 0.

- [ ] **Step 5: Clean slate re-verify**

```bash
./scripts/test.sh 2>&1 | tail -10
./scripts/validate.sh 2>&1 | tail -5
```

Expected: both green.

No commit — verification only.

---

### Task 3.7: User-facing compatibility note (code-only; no docs changes in this plan)

**Files:**
- Modify: `packages/luxvim/lua/core/lib/notify.lua` or wherever startup messages live (optional, safer: skip)

The path-capitalization change (`~/.config/luxvim` → `~/.config/LuxVim`) breaks existing users silently — their old config is no longer read. Because documentation changes are explicitly out of scope for this plan, we surface the issue via a one-time startup check: if an old lowercase `~/.config/luxvim` directory exists AND the new `~/.config/LuxVim` directory does not, print a one-line notice.

**Decision: implement this as an optional polish task.** Skip for the minimal Phase 1 plan; track under the implementation-phase notebook. The deprecation banner in `install.sh` (Task 1.11) already references the v1.0 migration guide where this rename is called out.

- [ ] **Step 1: No-op — skip this task for Phase 1**

Add a TODO line to the plan's completion report (not to the codebase):

> O-11 (new): detect legacy lowercase user-config dir on boot and emit a one-line notice. Scope for the phase-2 plan (docs stream #7).

No commit.

---

### Task 3.8: Phase 3 verification

**Files:**
- None modified.

- [ ] **Step 1: Full plenary suite**

```bash
./scripts/test.sh 2>&1 | tail -10
```

Expected: green, test count increased by the data_spec additions.

- [ ] **Step 2: Validator**

```bash
./scripts/validate.sh 2>&1 | tail -5
```

Expected: exit 0.

- [ ] **Step 3: Installer**

```bash
./install.sh 2>&1 | tail -10
```

Expected: success, plugins installed under `data/LuxVim/`.

- [ ] **Step 4: npm pack + install + expected-error smoke**

```bash
cd packages/luxvim
npm pack
npm install -g ./josstei-luxvim-0.0.1.tgz
lux 2>&1
echo "exit: $?"
# Expected: "No LuxVim runtime available..." then exit 1
npm uninstall -g @josstei/luxvim
rm *.tgz
cd ../..
```

Expected: exactly as in Task 2.11.

- [ ] **Step 5: Node test suite**

```bash
cd packages/luxvim && node --test tests/node/ 2>&1 | tail -10 && cd ../..
```

Expected: 11 tests pass.

---

## Final Phase Acceptance

- [ ] **F.1: All tests green in a single sitting**

```bash
./scripts/test.sh 2>&1 | tail -5
./scripts/validate.sh 2>&1 | tail -5
cd packages/luxvim && node --test tests/node/ 2>&1 | tail -5 && cd ../..
```

All three must report success.

- [ ] **F.2: Both install paths work**

```bash
./install.sh 2>&1 | tail -5                                  # git-clone path
cd packages/luxvim && npm pack && cd ../..                   # npm path — pack
npm install -g ./packages/luxvim/josstei-luxvim-0.0.1.tgz    # npm path — install
lux 2>&1 | head -3                                            # npm path — expected error message
npm uninstall -g @josstei/luxvim                              # cleanup
rm packages/luxvim/*.tgz                                      # cleanup
```

- [ ] **F.3: Review the commit log for clean, focused commits**

```bash
git log --oneline main..HEAD
```

Expected: ~20–25 commits, each scoped, with conventional-commit-style prefixes (`chore:`, `feat(npm):`, `refactor(data):`, `test(data):`, `ci:`).

- [ ] **F.4: Open a PR**

```bash
gh pr create \
  --title "feat: npm distribution foundation (phase 1)" \
  --body "$(cat <<'EOF'
## Summary
- Restructure: move `lua/`, `init.lua`, `tests/` into `packages/luxvim/`; add thin-wrapper `init.lua` at repo root.
- Scaffold: `packages/luxvim/package.json` + `bin/lux.js` + launcher unit tests.
- Migrate: `core/lib/data.lua` writable paths now resolve via `vim.fn.stdpath(...)` under `NVIM_APPNAME=LuxVim`.

Ref: design spec `docs/design/2026-04-17-npm-distribution-design.md` (commit dba08cd).

## Scope
- IN: repo restructure, launcher scaffold, XDG path migration, deprecation banners, CI path updates.
- OUT (future plans): build tooling, runtime packages, CI release workflow, license audit, migration guide, removal of debug/ precedence.

## Test plan
- [ ] `./scripts/test.sh` green (plenary suite).
- [ ] `./scripts/validate.sh` green.
- [ ] `./install.sh` completes and `lux` launches the editor.
- [ ] `cd packages/luxvim && node --test tests/node/` green (launcher unit tests).
- [ ] `npm pack && npm install -g ./josstei-luxvim-0.0.1.tgz && lux` prints "No LuxVim runtime available" with exit 1.
- [ ] Verified `data/LuxVim/lazy/` populated (NVIM_APPNAME scoping).
EOF
)"
```

- [ ] **F.5: Clean up the worktree after merge**

```bash
cd ../..                                             # back to main clone
git worktree remove .worktrees/npm-foundation
git branch -d feat/npm-foundation
```

---

## What's NOT in this plan

These items appear in the design spec but are intentionally deferred to follow-up plans. Each is a substantive work item of its own:

- `core/lib/bundle.lua` + `vendor_transform` pipeline hook.
- Removal of `debug/` precedence (and simplification of `core/lib/debug.lua`).
- `scripts/vendor-plugins.mjs`, `scripts/vendor-neovim.mjs`, `scripts/vendor-fzf.mjs`, `scripts/vendor-parsers.mjs`.
- `scripts/audit-licenses.mjs` and the permissive-only license allowlist.
- `scripts/build-runtime-package.mjs` and `packages/runtime-template/`.
- The five `@josstei/luxvim-runtime-<platform>` packages themselves.
- `.github/workflows/release.yml` — 4-phase multi-package publish pipeline.
- Treesitter parser bundling.
- fzf Go binary bundling (including the `lua/plugins/lib/fzf.lua` `build:` field removal).
- `docs/migration-from-git-clone.md`.
- NOTICE / THIRD_PARTY.md emission and `licenses/` subdirectories.
- Legacy-lowercase user-config detection (O-11).
- v0.1.0-beta tag + first real release.

A Phase 2 plan (to be written after this plan is merged and soak-tested) will cover build tooling + runtime packages + CI/CD + first release.
