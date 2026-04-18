# LuxVim npm Distribution — Design

**Status:** Approved for implementation planning
**Date:** 2026-04-17
**Owner:** @josstei

## Goal

Distribute LuxVim as a fully self-contained npm application. After `npm install -g @josstei/luxvim` on any supported platform, the user has everything required to run `lux` — no system Neovim, no `git`, no network required at install time or first launch. All bundled software is distributed under permissive licenses compatible with redistribution.

## Non-goals

- **LSP server bundling.** luxlsp's install-at-runtime model remains. Bundling language servers is a separate, larger initiative.
- **Custom plugin compilation.** No Lua minification, treeshaking, or bytecode. Plugins ship as-sourced.
- **Graphical installers, in-editor self-update, telemetry.** Out of scope.
- **Non-permissive licenses.** Any GPL/LGPL/AGPL/SSPL/BUSL/Commons-Clause/proprietary/unknown-licensed plugin fails the build. No runtime bypass.

## Architecture

### Package topology

Six npm packages, all under the `@josstei` scope, published atomically per release:

```
@josstei/luxvim                              Main package. Platform-agnostic.
                                             Lua config, vendored plugins, launcher.
                                             Target size: <15 MB.
  optionalDependencies:
    @josstei/luxvim-runtime-darwin-arm64     Neovim binary + fzf + treesitter parsers
    @josstei/luxvim-runtime-darwin-x64       for the target platform.
    @josstei/luxvim-runtime-linux-x64        Target size: <60 MB each.
    @josstei/luxvim-runtime-linux-arm64
    @josstei/luxvim-runtime-win32-x64
```

Main declares each runtime at an exact version (`"=X.Y.Z"`) with correct `os` and `cpu` gates. npm resolves exactly one runtime at install time for the host platform.

This mirrors the esbuild distribution pattern (`esbuild` main + `@esbuild/<platform>` runtimes).

### Runtime package contents

Each `@josstei/luxvim-runtime-<platform>` contains:

```
neovim/                           Upstream Neovim release, extracted as-is.
  bin/nvim(.exe)
  lib/, share/                    Neovim's runtime files.
fzf/
  bin/fzf(.exe)                   Upstream fzf release binary (MIT).
parsers/                          Curated treesitter parser set, prebuilt.
  <lang>.so | .dll
LICENSE, NOTICE, THIRD_PARTY.md   Attribution for bundled components.
licenses/                         Full license texts, one directory per component.
package.json
  os:  ["darwin" | "linux" | "win32"]
  cpu: ["arm64" | "x64"]
```

### Main package contents

```
packages/luxvim/
├── bin/lux.js                   Node launcher, platform-aware.
├── init.lua                     Neovim entry point (unchanged from today).
├── lua/                         Core + plugin specs (mirrors current lua/).
├── vendor/plugins/<name>/       Build-time-populated vendored plugins.
├── vendor/plugins/.manifest.json  Records {name, source, commit, license} per plugin.
├── tests/                       plenary test suite.
├── LICENSE, NOTICE, THIRD_PARTY.md
├── licenses/                    Full license texts for every vendored plugin.
└── package.json
```

### Repository layout (post-restructure)

```
LuxVim/                                     Repo root (github.com/josstei/luxvim).
├── packages/
│   ├── luxvim/                             Canonical source of truth.
│   │   ├── bin/lux.js
│   │   ├── init.lua
│   │   ├── lua/
│   │   ├── tests/
│   │   └── package.json
│   └── runtime-template/                   Stamped per-platform at CI build time.
│       ├── package.template.json
│       └── README.template.md
├── scripts/                                Build tooling (Node ESM, zero-dep where practical).
│   ├── vendor-plugins.mjs
│   ├── vendor-neovim.mjs
│   ├── vendor-fzf.mjs
│   ├── vendor-parsers.mjs
│   ├── build-runtime-package.mjs
│   ├── audit-licenses.mjs
│   └── release.mjs
├── .github/workflows/
│   ├── test.yml                            Existing, paths updated for packages/luxvim/.
│   └── release.yml                         New, tag-triggered multi-package publish.
├── docs/
│   ├── design/                             Design specs (tracked).
│   └── migration-from-git-clone.md         v0.x-era migration guide.
├── lazy-lock.json                          Single source of truth for plugin SHAs.
├── init.lua                                Thin wrapper (v0.x only). dofile into packages/luxvim/init.lua.
├── install.sh, install.ps1                 Deprecated v0.x, removed at v1.0.
├── README.md
└── LICENSE                                 Apache 2.0 (unchanged).
```

Thin wrappers at the top level allow existing `git clone + install.sh` installations to keep working for the v0.x transition period. Removed at v1.0.

## Runtime bootstrap

### Launcher (`packages/luxvim/bin/lux.js`)

Plain Node ESM, no third-party dependencies. Synchronous execution, inherited stdio, clear failure modes.

```js
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { platform, arch } = process;

const runtimePkg = `@josstei/luxvim-runtime-${platform}-${arch}`;

let runtimeRoot;
try {
  runtimeRoot = path.dirname(require.resolve(`${runtimePkg}/package.json`));
} catch {
  process.stderr.write(
    `No LuxVim runtime available for ${platform}/${arch}.\n` +
    `Supported: darwin-arm64, darwin-x64, linux-x64, linux-arm64, win32-x64.\n` +
    `If you installed with --no-optional or --omit=optional, reinstall without those flags.\n`
  );
  process.exit(1);
}

const luxvimRoot = path.dirname(require.resolve('@josstei/luxvim/package.json'));
const nvimBin = path.join(
  runtimeRoot, 'neovim', 'bin',
  platform === 'win32' ? 'nvim.exe' : 'nvim'
);
const fzfDir = path.join(runtimeRoot, 'fzf', 'bin');

const env = {
  ...process.env,
  NVIM_APPNAME:   'LuxVim',
  LUXVIM_ROOT:    luxvimRoot,
  LUXVIM_RUNTIME: runtimeRoot,
  PATH: `${fzfDir}${path.delimiter}${process.env.PATH ?? ''}`,
};

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

Properties:

- `NVIM_APPNAME=LuxVim` scopes Neovim's XDG paths to `LuxVim`-subdirectories. Launcher does **not** override `XDG_DATA_HOME`/`XDG_CONFIG_HOME`/`XDG_CACHE_HOME`/`XDG_STATE_HOME`. Neovim's own path resolution applies.
- `rtp^=` prepends LuxVim's runtimepath so its Lua modules take precedence over Neovim's built-in runtime.
- `LUXVIM_ROOT` resolves to the read-only main package location. Code must not write there.
- `LUXVIM_RUNTIME` resolves to the read-only runtime package. Used to locate bundled parsers and native assets.
- fzf's binary directory is prepended to `PATH` so fzf.vim finds the bundled binary without interfering with user-installed fzf outside `lux` sessions.

### User state paths

With `NVIM_APPNAME=LuxVim`, state lives at XDG-compliant per-user paths:

| OS | Config | Data | Cache | State |
|---|---|---|---|---|
| Linux | `~/.config/LuxVim/` | `~/.local/share/LuxVim/` | `~/.cache/LuxVim/` | `~/.local/state/LuxVim/` |
| macOS | `~/.config/LuxVim/` (when `XDG_CONFIG_HOME` set) else Neovim default | `~/.local/share/LuxVim/` | `~/.cache/LuxVim/` | `~/.local/state/LuxVim/` |
| Windows | `%LOCALAPPDATA%\LuxVim\config\` | `%LOCALAPPDATA%\LuxVim\data\` | `%LOCALAPPDATA%\LuxVim\cache\` | `%LOCALAPPDATA%\LuxVim\state\` |

Contents:

- **Config** — user overrides (plugin specs, keymap registry extensions, pipeline hooks). Identical role to today's `$LUXVIM_CONFIG`, only the path changes. Not written to by LuxVim itself.
- **Data** — `lazy/` (only for plugins added via user config; vendored plugins never touch it), `luxlsp/` (LSP server installs, unchanged), `site/`, `plugins/dynamic/` (theme picker dynamic specs).
- **Cache** — treesitter parser compile cache for user-added parsers; not used for bundled parsers (those live read-only in the runtime package).
- **State** — shada, undo, swap, session (Neovim's defaults, scoped by `NVIM_APPNAME`).

### Lua code audit (implementation task)

Every write operation in the Lua codebase currently rooted at `LUXVIM_ROOT` must migrate to the correct `vim.fn.stdpath(...)` equivalent:

- `LUXVIM_ROOT/data/lazy/` → `vim.fn.stdpath('data') .. '/lazy'`
- `LUXVIM_ROOT/data/luxlsp/` → `vim.fn.stdpath('data') .. '/luxlsp'`
- `LUXVIM_ROOT/data/site/` → `vim.fn.stdpath('data') .. '/site'`
- Theme picker dynamic spec writes → `vim.fn.stdpath('data') .. '/plugins/dynamic'`
- Any shada/undo/swap config → `vim.fn.stdpath('state')`-rooted

Reads from `LUXVIM_ROOT` (e.g., loading plugin specs from `lua/plugins/`) remain valid — that tree is read-only and lives inside the npm package.

## Plugin vendoring

Two-phase design: build-time fetch in CI, runtime consumption via pipeline transform.

### Build-time fetch (`scripts/vendor-plugins.mjs`)

Runs in CI Phase A, before `npm pack`.

1. **Enumerate specs.** Invoke a headless Neovim helper that runs LuxVim's pipeline through the `load` stage and dumps `[{name, source, build?}, ...]` as JSON. Reuses existing discovery/merge logic.
2. **Join with `lazy-lock.json`.** For each name, read `{branch, commit}`.
3. **Fetch tarballs.** `GET https://codeload.github.com/<source>/tar.gz/<commit>`. CI uses `GITHUB_TOKEN` to raise rate limits.
4. **Extract and trim.** Write to `packages/luxvim/vendor/plugins/<name>/`. Strip: `.git/`, `tests/`, `test/`, `.github/`, `spec/`, `benchmarks/`. Keep: `doc/` (enables `:help <plugin>` in editor).
5. **Detect license.** Locate `LICENSE` / `LICENSE.md` / `LICENSE.txt` / `COPYING` / `UNLICENSE`; detect SPDX identifier; fail if not on the allowlist.
6. **Run build steps.** For plugins with a `build` field (e.g., treesitter parser compilation, fzf wrapper scripts), execute in the matrix environment targeting the runtime package's platform. Platform-specific build outputs go into the runtime package, not main.
7. **Write manifest.** `packages/luxvim/vendor/plugins/.manifest.json` records `{name, source, commit, spdx, license_file}` per plugin.

### Runtime consumption (`packages/luxvim/lua/core/lib/bundle.lua`)

New module, registered as a pipeline `post_merge` hook in `core/init.lua`.

```lua
local M = {}
local paths = require("core.lib.paths")

function M.vendor_transform(ctx)
  local root = vim.env.LUXVIM_ROOT
  if not root then return ctx end

  local vendor_root = root .. "/vendor/plugins"
  if vim.fn.isdirectory(vendor_root) == 0 then return ctx end

  for _, spec in ipairs(ctx.specs) do
    if spec.source then
      local name = spec.debug_name or paths.basename(spec.source)
      local dir = vendor_root .. "/" .. name
      if vim.fn.isdirectory(dir) == 1 then
        spec.dir = dir
      end
    end
  end
  return ctx
end

return M
```

Behavior:

- **Vendored plugin.** `spec.dir` is set; lazy.nvim honors `dir`, skips cloning. All lazy-loading triggers (`event`, `cmd`, `ft`, `keys`) compose with `dir` per lazy.nvim's documentation.
- **User-added plugin** (from `~/.config/LuxVim/plugins/...`). No vendored directory exists; `spec.dir` remains `nil`; lazy.nvim clones into `~/.local/share/LuxVim/lazy/` as usual. User extension mechanism unchanged.

Precedence: `vendor > git clone`. The previous `debug/` override is removed (see §6.3).

### fzf binary

`junegunn/fzf` is a Go binary, not Lua. Handled separately from plugin vendoring:

- `scripts/vendor-fzf.mjs` downloads `github.com/junegunn/fzf/releases/download/<ver>/fzf-<ver>-<os>_<arch>.tar.gz` into `packages/runtime-<platform>/fzf/bin/`.
- The `lua/plugins/lib/fzf.lua` spec file drops its `build` field (the Go compile step). When the launcher runs, `PATH` already contains the bundled `fzf` binary.
- `fzf.vim` (Vim-script wrapper) is vendored as a regular plugin — it is not a binary.

### Treesitter parsers

Parsers are compiled `.so` / `.dll` artifacts. Curated set bundled per platform (see O-2 in §9 for the specific list).

- `scripts/vendor-parsers.mjs` clones each parser grammar at a pinned SHA, runs `tree-sitter generate` and the platform C compiler, outputs `parsers/<lang>.<ext>` into the runtime package.
- `lua/plugins/editor/treesitter.lua` is updated to point nvim-treesitter at `LUXVIM_RUNTIME/parsers/` for the curated set, and at `$XDG_DATA_HOME/LuxVim/site/parser/` for user-installed additions.
- Each parser's license is audited and attributed in the runtime package's `THIRD_PARTY.md`.

## CI/CD pipeline

### Workflows

Two workflows, clean separation.

**`test.yml`** — existing. Triggers on PR + push to main. Runs plenary suite against `packages/luxvim/tests/` on the Neovim matrix (`v0.10.0` / `stable` / `nightly`). Paths updated after repo restructure. No publishing.

**`release.yml`** — new. Triggers on tag push matching `v*.*.*`. Four sequential phases.

### Phase A — Build & vendor (parallel, 6 jobs)

| Job | Runner | Output |
|---|---|---|
| `build-main` | `ubuntu-latest` | `luxvim-X.Y.Z.tgz` |
| `build-darwin-arm64` | `macos-14` | `luxvim-runtime-darwin-arm64-X.Y.Z.tgz` |
| `build-darwin-x64` | `macos-13` | `luxvim-runtime-darwin-x64-X.Y.Z.tgz` |
| `build-linux-x64` | `ubuntu-latest` | `luxvim-runtime-linux-x64-X.Y.Z.tgz` |
| `build-linux-arm64` | `ubuntu-latest` + QEMU | `luxvim-runtime-linux-arm64-X.Y.Z.tgz` |
| `build-win32-x64` | `windows-latest` | `luxvim-runtime-win32-x64-X.Y.Z.tgz` |

`build-main` runs `vendor-plugins.mjs` + `audit-licenses.mjs` + `npm pack`.

Each platform job runs `vendor-neovim.mjs` + `vendor-fzf.mjs` + `vendor-parsers.mjs` + `audit-licenses.mjs --platform=<target>` + `build-runtime-package.mjs --platform=<target>` + `npm pack`.

All six jobs upload their `.tgz` as workflow artifacts.

Linux arm64 builds go through QEMU since native arm Linux runners are not available. Accept ~5 minute overhead per build.

### Phase B — Smoke test (parallel, 5 jobs)

One job per platform runner. Each job:

1. Downloads the matching runtime artifact + the main artifact.
2. Installs into a scratch `npm init -y` directory.
3. Runs `node_modules/.bin/lux --version` and verifies the expected Neovim version.
4. Runs `node_modules/.bin/lux --headless "+LuxVimValidate" +qa`; exits non-zero on any validation error.
5. macOS jobs additionally run `codesign -v neovim/bin/nvim` and report pass/fail.

Any smoke test failure aborts the release.

### Phase C — Atomic publish (sequential, 1 job)

Downloads all 6 artifacts. Publishes in this strict order so Main's `optionalDependencies` always resolve:

1. `@josstei/luxvim-runtime-darwin-arm64@X.Y.Z`
2. `@josstei/luxvim-runtime-darwin-x64@X.Y.Z`
3. `@josstei/luxvim-runtime-linux-x64@X.Y.Z`
4. `@josstei/luxvim-runtime-linux-arm64@X.Y.Z`
5. `@josstei/luxvim-runtime-win32-x64@X.Y.Z`
6. `@josstei/luxvim@X.Y.Z`

All publishes use `npm publish --provenance` with npm Trusted Publishing (OIDC). No `NPM_TOKEN`.

Recovery: mid-publish network failure leaves some runtimes published but main unpublished — re-running with the same tag resumes from the first un-published package (npm rejects duplicate versions as a soft error). Users never see a partial release because main is gated behind all runtimes.

### Phase D — GitHub Release

Create GitHub Release at tag. Auto-generated CHANGELOG via changesets (conventional commits). Attach all 6 `.tgz` artifacts plus a source tarball for offline installation.

### Runners & caching

- macOS arm64: `macos-14`
- macOS x64: `macos-13` (or `macos-14` with Rosetta cross-build)
- Linux x64: `ubuntu-latest`
- Linux arm64: `ubuntu-latest` + QEMU (`docker/setup-qemu-action`)
- Windows x64: `windows-latest`

Cache keys:

| Cache | Key |
|---|---|
| npm global cache | `hashFiles('package-lock.json')` |
| Vendored plugin tarballs | `hashFiles('lazy-lock.json')` |
| Neovim release tarballs | `NVIM_VERSION` constant in `vendor-neovim.mjs` |
| fzf release tarballs | fzf version constant in `vendor-fzf.mjs` |
| Treesitter parser sources | per-parser pinned SHA |

First full release build: ~15 min. Cached rebuild: ~3 min.

### Secrets & trust

- npm Trusted Publishing (OIDC) configured on the npm side, scoped to `release.yml`. No long-lived tokens.
- `GITHUB_TOKEN` auto-provided for release creation and provenance attestations.
- Branch protection on `main`: require `test.yml` green. Tags that trigger `release.yml` are pushed only by repo owner.

## License compliance

### Allowlist

Only these SPDX identifiers are acceptable for bundled components:

```
MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC,
CC0-1.0, Unlicense, Vim, Zlib
```

Any other license (GPL family, LGPL, AGPL, MPL, SSPL, BUSL, Commons-Clause, proprietary, unknown) causes `audit-licenses.mjs` to exit non-zero and fail the build.

### Audit script (`scripts/audit-licenses.mjs`)

Runs in Phase A of `release.yml`.

1. **Plugin audit loop** over `packages/luxvim/vendor/plugins/<name>/`:
   - Locate license file (`LICENSE`, `LICENSE.md`, `LICENSE.txt`, `COPYING`, `UNLICENSE`).
   - Detect SPDX identifier by pattern matching against canonical license texts.
   - Validate against allowlist. Fail build on mismatch.
2. **Native asset audit** per runtime package:
   - Neovim: verify Apache-2.0 + Vim license texts bundled.
   - fzf: verify MIT text bundled.
   - Each treesitter parser: verify license independently.
3. **Emit artifacts** into each package:

```
packages/luxvim/
├── LICENSE                   Apache-2.0 (LuxVim's own, unchanged)
├── NOTICE                    Aggregated Apache-2.0 attribution
├── THIRD_PARTY.md            SBOM: name | version | spdx | upstream | license_file
└── licenses/<name>/LICENSE   Full license text, one per vendored component

packages/luxvim-runtime-<platform>/
├── LICENSE                   MIT (runtime packaging's own)
├── NOTICE                    Neovim + fzf + per-parser attributions
├── THIRD_PARTY.md            Per-platform SBOM
└── licenses/<component>/LICENSE
```

Bundled license texts satisfy the attribution requirements of Apache-2.0, BSD, and MIT.

### Platform signature handling

- **macOS.** Upstream Neovim macOS tarballs ship signed + notarized. Extraction + re-tar for `npm pack` should preserve embedded signatures (signatures live in the binary itself, not xattrs). Phase B includes `codesign -v` smoke test to verify. If verification fails, fallback is Apple Developer ID self-signing — tracked as O-4.
- **Windows.** Upstream Neovim Windows binaries are not notarized. Launcher invocation via Node `execFileSync` typically bypasses SmartScreen prompts on subsequent runs. Documented caveat; no blocker.

## Versioning

- **SemVer** for `@josstei/luxvim` and all runtime packages.
  - Major: breaking config/API changes (schema changes, removed plugins, removed keymaps).
  - Minor: new features, added plugins, Neovim minor version bumps.
  - Patch: bug fixes, plugin SHA bumps, Neovim patch bumps.
- **Version alignment.** All 6 packages share the same version per release. Main's `optionalDependencies` use exact `=X.Y.Z` pins.
- **Upstream Neovim pin** lives in a single constant in `scripts/vendor-neovim.mjs`. Bumping Neovim requires a LuxVim release.
- **No dynamic "latest"** for upstream components. Every LuxVim version embeds specific versions of Neovim, fzf, and each treesitter parser.
- **CHANGELOG** generated automatically via changesets tooling from conventional commits.
- **Nightly channel** deferred to post-v1.0 (see O-6).

## Phasing

| Version | Scope | Exit criteria |
|---|---|---|
| **v0.1.0-beta** | All 6 packages publishable, all 5 platforms. End-to-end install works. License audit passes. Smoke tests pass on all platforms. `install.sh` still works in parallel. | `npm install -g @josstei/luxvim && lux` works cleanly on each of the 5 platforms; plenary suite still green. |
| **v0.2.0** | Bundled treesitter parser set live. macOS signature verification passes in CI. Migration guide published. Deprecation banner in `install.sh` runs. | 5/5 platforms ship parsers; `codesign -v` passes on darwin packages; README linked migration guide. |
| **v0.3.0–v0.9.x** | Stabilization. Bug fixes, plugin SHA bumps, Neovim version bumps, install-size reductions, community feedback. | Bug backlog cleared; install success rate high across reported platforms. |
| **v1.0.0** | Cutover. Top-level `init.lua`, `lua/`, `tests/`, `install.sh`, `install.ps1` removed. Repo becomes npm-only. | Zero references to in-tree data model. All wrappers deleted. v1.0 tag marks API stability. |

Target cadence: v0.1 → v0.2 in ~2 weeks; v0.x → v1.0 in ~8–12 weeks of real-world soak. These are targets driven by defect rate, not contracts.

## Migration for existing git-clone users

During v0.x, both install paths coexist. Thin wrappers at the repo root preserve today's behavior:

```
LuxVim/                       Repo root (git clone target).
├── init.lua                  Thin: one-line dofile into packages/luxvim/init.lua.
├── install.sh                Prints deprecation banner; runs as today.
├── install.ps1               Prints deprecation banner; runs as today.
├── scripts/test.sh           Runs cd packages/luxvim && plenary harness.
├── scripts/validate.sh       Same cd-then-invoke shim.
└── packages/luxvim/          Canonical source of truth.
```

No top-level `lua/` or `tests/` is required. Top-level `init.lua` delegates via a single `dofile(".../packages/luxvim/init.lua")` line; the delegated `init.lua` prepends the runtimepath so all `require("core.xxx")` calls resolve inside `packages/luxvim/lua/`. `scripts/test.sh` and `scripts/validate.sh` `cd packages/luxvim/` before running, so no top-level `tests/` copy or symlink is needed.

### Deprecation banner

Printed at the top of every `install.sh` run:

```
┌────────────────────────────────────────────────┐
│ NOTICE: LuxVim is moving to npm.              │
│                                                │
│ For new installs, prefer:                      │
│   npm install -g @josstei/luxvim               │
│                                                │
│ This git-clone path will be removed in v1.0    │
│ (target: <date>). Migration guide:             │
│ github.com/josstei/luxvim/blob/main/docs/      │
│         migration-from-git-clone.md            │
└────────────────────────────────────────────────┘
```

### Migration guide (`docs/migration-from-git-clone.md`)

1. **Uninstall git-clone version.** Remove `~/.local/bin/lux` and delete the clone directory.
2. **Rename user config.** `~/.config/luxvim/` → `~/.config/LuxVim/` to match `NVIM_APPNAME=LuxVim`. Supplied as a one-liner.
3. **Install npm version.** `npm install -g @josstei/luxvim`. First run of `lux` populates `~/.local/share/LuxVim/`.
4. **LSP servers.** `~/.local/share/LuxVim/luxlsp/` starts empty. Reinstall via `:LuxLsp`. No automatic state migration.
5. **Verify.** Run `:LuxVimValidate` — must report no errors.

At v1.0, the thin wrappers, `install.sh`, and `install.ps1` are deleted. Users who have not migrated are instructed via the v0.9.x final deprecation release.

## Work decomposition

Seven work streams. Dependencies noted; streams without dependencies can run in parallel.

1. **Repo restructure.** Blocker for everything else. Move `lua/`, `init.lua`, `tests/` into `packages/luxvim/`; add thin wrappers at root; update `test.yml` paths; verify `install.sh` still green.
2. **Launcher + main package scaffold.** `packages/luxvim/package.json` (with `optionalDependencies` stubs), `bin/lux.js`, `.npmignore`; Node-level unit tests for launcher resolution, env construction, and error paths.
3. **Runtime bootstrap migration.** Depends on #1. Audit every Lua write currently rooted at `LUXVIM_ROOT`; migrate to `vim.fn.stdpath(...)`. Add `core/lib/bundle.lua` with `vendor_transform` pipeline hook. Remove `debug/` precedence (simplifies or deletes `debug.lua`). Update affected tests.
4. **Build tooling.** Parallel with #3. `scripts/`: `vendor-plugins.mjs`, `vendor-neovim.mjs`, `vendor-fzf.mjs`, `vendor-parsers.mjs`, `audit-licenses.mjs`, `build-runtime-package.mjs`, `release.mjs`. Each testable locally without CI.
5. **Runtime package template.** Depends on #4. `packages/runtime-template/package.template.json`; `build-runtime-package.mjs` stamps it per platform.
6. **CI/CD.** Depends on #2, #4, #5. `.github/workflows/release.yml` with all four phases; npm Trusted Publishing configured; branch protection; changesets integration for auto-CHANGELOG.
7. **Documentation.** Parallel with all others; final polish runs last. README rewrite, `docs/migration-from-git-clone.md`, NOTICE/THIRD_PARTY templates, release notes format.

## Open issues

Decisions to log during implementation. None block the design.

| ID | Issue | Resolves in |
|---|---|---|
| O-1 | Exact Neovim version for v0.1.0 (latest stable at implementation time). | Stream #4 |
| O-2 | Exact curated treesitter parser set. Draft: `lua, python, javascript, typescript, tsx, rust, go, bash, json, yaml, toml, markdown, markdown_inline, html, css, vim, vimdoc` (17 parsers). | Stream #4 |
| O-3 | Install-size targets. Proposed: main <15 MB; each runtime <60 MB including parsers. | Stream #5 |
| O-4 | Does `codesign -v` survive `tar → npm pack → npm install → extract` on macOS? If no, fall back to Apple Developer ID self-signing (adds secret management). | Before v0.1.0 tag |
| O-5 | Windows arm64 support. Add when Neovim ships official builds. | Post-v1.0 |
| O-6 | Nightly channel (`@josstei/luxvim@nightly` tracking Neovim nightly). | Post-v1.0 |
| O-7 | GitHub Packages mirror. | Post-v1.0 |
| O-8 | In-editor update UX (e.g., `:LuxVimUpdate` wrapping `npm update -g`). Docs-only for v1.0. | Post-v1.0 |
| O-9 | fzf version pin. Track `junegunn/fzf` latest stable. | Stream #4 |
| O-10 | Support `npm install` (project-local) alongside `npm install -g` (global). Implementation identical; docs only. | Stream #7 |

## Glossary

- **Main package** — `@josstei/luxvim`. Platform-agnostic npm package containing Lua config, vendored plugins, and the Node launcher.
- **Runtime package** — `@josstei/luxvim-runtime-<os>-<arch>`. Platform-specific npm package containing the Neovim binary, fzf binary, and treesitter parsers.
- **Vendored plugin** — A plugin whose source tree lives inside `packages/luxvim/vendor/plugins/`, populated at CI build time from `lazy-lock.json`-pinned SHAs.
- **User-added plugin** — A plugin declared in `~/.config/LuxVim/plugins/...`, fetched by lazy.nvim at runtime into `~/.local/share/LuxVim/lazy/`.
- **Thin wrapper** — A top-level file or directory that `dofile`s or re-exports from `packages/luxvim/`, preserving compatibility with `git clone + install.sh` installations during the v0.x transition.
- **Trusted Publishing** — npm's OIDC-based publish mechanism that replaces long-lived tokens with short-lived credentials minted from the GitHub Actions workflow identity.
