# LuxVim Framework Refactor Design

**Date:** 2026-04-04
**Goal:** Refactor LuxVim from a personal Neovim config into an extensible framework/platform where the plugin spec system and action registry are the product, with full user overridability.

## Guiding Principles

- The declarative spec system and action registry are the framework's public API — refine them for extensibility
- The architecture (data isolation, auto-discovery, self-containment) supports that API
- Every change serves the final framework architecture — no throwaway work
- Bundled plugins are defaults that ship with the framework; users can override or replace any of them
- The theme picker must be buildable as a regular plugin — if it can't, the framework has a gap

## 1. Loader Pipeline

### Current State

`loader.lua` (328 lines) is a monolith handling discovery, loading, validation, transformation, condition evaluation, dependency resolution, build transformation, and error reporting. It uses module-level mutable state (`M._specs`, `M._specs_by_name`, `M._errors`, `M._warnings`).

### Design

Split into a pipeline of focused stages, orchestrated by a thin `pipeline.lua` module.

**Pipeline stages:**

```
discover → load → merge → validate → transform
```

| Module | Responsibility | Input | Output |
|--------|---------------|-------|--------|
| `discover.lua` | Scan plugin directories (framework + user), find `.lua` files | Plugin dir paths | List of `{path, category, defaults}` entries |
| `load.lua` | `dofile` each spec, merge category defaults, tag with source | File entries | List of raw spec tables |
| `merge.lua` | Apply `extends`/`replaces` semantics between user and framework specs | Raw specs (framework + user) | Merged spec list |
| `validate.lua` | Validate specs against schema | Merged specs | Validated specs + errors/warnings |
| `transform.lua` | Convert to lazy.nvim format, resolve deps, handle conditions, builds | Validated specs | lazy.nvim-ready specs |

**Pipeline orchestrator (`pipeline.lua`):**

- Runs stages in order, passing output of each as input to the next
- Exposes pre/post hooks for each stage:

```lua
local pipeline = require("core.lib.pipeline")
pipeline.on("pre_validate", function(specs)
  -- modify specs before validation
  return specs
end)
pipeline.on("post_transform", function(lazy_specs)
  -- modify lazy specs before they reach lazy.nvim
  return lazy_specs
end)
```

- Hook registration is order-dependent: hooks run in the order registered
- Hooks receive the current data and must return it (possibly modified)
- ~30-40 lines total

**Pipeline context:**

The pipeline maintains a shared context object passed through all stages. This replaces the module-level state in the current loader:

```lua
-- context structure
{
  specs = {},           -- current spec list (evolves through stages)
  specs_by_name = {},   -- name-indexed lookup (built by load, used by merge and transform)
  errors = {},          -- accumulated errors
  warnings = {},        -- accumulated warnings
}
```

The `load` stage builds `specs_by_name` as it processes specs. The `merge` stage uses it to match `extends`/`replaces` targets. The `transform` stage uses it for dependency resolution (`resolve_dependencies` needs to look up dependency specs by name). Each stage receives and returns the context — no module-level mutable state.

**Error handling:**

Errors are accumulated in the context rather than module-level state. Each stage can append errors/warnings. The pipeline returns the final context at the end. Error reporting moves to `core/init.lua` where it already conceptually belongs.

**What gets eliminated:**
- Module-level mutable state (`M._specs`, `M._specs_by_name`, etc.)
- The monolithic loader — replaced by 5 focused stage files + orchestrator
- Error reporting mixed into the loader

**What gets enabled:**
- Users can replace any stage entirely
- Users can inject logic between stages
- Each stage is independently understandable

### File Changes

| Action | File |
|--------|------|
| Delete | `lua/core/lib/loader.lua` |
| Create | `lua/core/lib/pipeline.lua` (~35 lines) |
| Create | `lua/core/lib/pipeline/discover.lua` (~60 lines) |
| Create | `lua/core/lib/pipeline/load.lua` (~50 lines) |
| Create | `lua/core/lib/pipeline/merge.lua` (~80 lines) |
| Create | `lua/core/lib/pipeline/validate.lua` (~40 lines, thin wrapper calling validate.lua) |
| Create | `lua/core/lib/pipeline/transform.lua` (~100 lines, from loader's transform + deps + build logic; depends on `core.lib.debug`, `core.lib.platform`, `core.lib.paths`, `core.registry.conditions`) |
| Modify | `lua/core/init.lua` (call pipeline instead of loader) |

## 2. Pluggable Schema & Validation

### Current State

`schema.lua` (47 lines) hardcodes all spec field definitions. `validate.lua` (95 lines) validates against it. Unknown fields produce warnings. No way to add custom fields without triggering warnings.

### Design

Make the schema a registry with `extend`, `replace`, and `get` operations.

**New schema.lua API:**

```lua
local schema = require("core.lib.schema")

-- Existing schemas remain as defaults (plugin_spec, build_spec, keymap_entry, autocmd_entry)

-- Extend a schema with additional fields
schema.extend("plugin_spec", {
  priority = { type = "number", desc = "Load priority" },
  my_field = { type = "string", desc = "Custom field" },
})

-- Replace a schema entirely
schema.replace("plugin_spec", { ... })

-- Get current schema (used by validate.lua, typegen.lua)
schema.get("plugin_spec")
```

**New built-in fields added to plugin_spec schema:**

- `extends` — `{ type = "string", desc = "Name of framework spec to extend (deep merge)" }`
- `replaces` — `{ type = "string", desc = "Name of framework spec to replace entirely" }`

The `source = "virtual"` convention is handled in the transform stage, not as a schema field — it's a sentinel value for the existing `source` field.

**Implementation:**

- Internal storage switches from `M.plugin_spec = {...}` to a registry table `M._schemas = {}`
- Default schemas are registered at module load time (same field definitions as today, plus `extends`/`replaces`)
- `extend()` deep-merges new fields into the existing schema
- `replace()` substitutes entirely
- `get()` returns the current state
- Backward compat: `schema.plugin_spec` still works via `__index` metamethod on `M` that calls `get()`

**Changes to validate.lua:**

- `validate_plugin_spec()` calls `schema.get("plugin_spec")` instead of importing `schema.plugin_spec` directly
- Core validation logic unchanged
- Cache `vim.tbl_keys(schema_def)` once per `validate_against` call instead of rebuilding per unknown field

**Changes to typegen.lua:**

- Uses `schema.get()` instead of direct field access — automatically picks up user-extended schemas

### File Changes

| Action | File |
|--------|------|
| Modify | `lua/core/lib/schema.lua` (+~20 lines for registry API) |
| Modify | `lua/core/lib/validate.lua` (use `schema.get()`, cache known_fields) |
| Modify | `lua/core/lib/typegen.lua` (use `schema.get()`) |

## 3. User Config Layer & Override System

### Current State

No user config directory. All specs live in `lua/plugins/`. No way to override or extend defaults without editing framework files.

### Design

An XDG-based user config directory that mirrors the framework structure. Discovered and merged by the loader pipeline.

**User config location:**

`$XDG_CONFIG_HOME/luxvim/` (defaults to `~/.config/luxvim/`)

**Directory structure:**

```
~/.config/luxvim/
  plugins/
    ui/
      nvim-tree.lua      -- extends or replaces the default
      my-plugin.lua      -- new plugin
    editor/
      _defaults.lua      -- override category defaults
  registry/
    keymaps.lua          -- extends or replaces default keymaps
    autocmds.lua         -- extends or replaces default autocmds
    filetypes.lua        -- extends or replaces default filetypes
    conditions.lua       -- extends or replaces default conditions
  options.lua            -- user vim options (loaded after framework options)
  init.lua               -- early init: schema extensions, pipeline hooks
```

**Plugin spec override semantics:**

`extends` and `replaces` match by plugin name — the `debug_name` field if set, otherwise `basename(source)`. This is the same key the framework uses internally for `_specs_by_name`.

```lua
-- EXTEND: deep-merge with framework default
return {
  extends = "nvim-tree",
  opts = { view = { width = 40 } },     -- merged into default opts
  actions = { my_action = ":MyCommand" }, -- added alongside existing actions
}

-- REPLACE: full control, no merging
return {
  replaces = "nvim-tree",
  source = "nvim-tree/nvim-tree.lua",
  opts = { ... },
}

-- NEW: no extends/replaces field = brand new plugin
return {
  source = "author/my-plugin",
  opts = { ... },
}
```

**Registry override semantics:**

```lua
-- EXTEND: merge with framework keymaps
return {
  extends = true,
  editor = {
    ["<leader>ff"] = { action = "fzf.vim.files", desc = "Find files" },
  },
}

-- REPLACE: framework keymaps ignored
return {
  replaces = true,
  editor = { ... },
}
```

For `extends` registries, merge behavior per type:

- **Keymaps**: Merged per section (`editor`, `navigation`, `ui`, `terminal`). Within a section, user entries with the same lhs override the framework entry. New lhs bindings are added. Sections not present in the user registry are left unchanged. Uses `vim.tbl_deep_extend("force", framework_section, user_section)`.
- **Autocmds**: Merged by event name key (`FileType`, `BufLeave`, etc.). User entry for an event replaces the framework entry for that event entirely. New events are added.
- **Filetypes**: Merged by filetype key. User entry for a filetype replaces framework settings for that filetype. New filetypes are added. Uses `vim.tbl_deep_extend("force", framework, user)`.
- **Conditions**: Merged by condition name. User functions override framework functions with the same name. New conditions are added.

**Pipeline integration:**

1. `discover.lua` scans both framework `lua/plugins/` and user `plugins/` directories
2. User specs are tagged with `_source = "user"`
3. `merge.lua` stage (between load and validate) handles the override logic:
   - `extends` specs: deep-merge user fields onto the matching framework spec
   - `replaces` specs: substitute entirely, discard the framework spec
   - New specs (no `extends`/`replaces`): pass through as additions
4. Validation runs on the merged result

**User init.lua:**

Loaded early — before the pipeline runs — so users can:
- Register schema extensions (`schema.extend(...)`)
- Register pipeline hooks (`pipeline.on(...)`)
- Set framework-level options

Loading order in `core/init.lua`:
1. Load user `init.lua` (if it exists)
2. Run pipeline (discover → load → merge → validate → transform)
3. Setup lazy.nvim
4. Register actions
5. Setup keymaps/autocmds (with user registry overrides applied)

**User config discovery:**

A new function in `data.lua` (or a `user.lua` module) resolves the user config path:

```lua
function M.user_config_path()
  return vim.env.LUXVIM_CONFIG
      or paths.join(vim.env.XDG_CONFIG_HOME or paths.join(vim.env.HOME, ".config"), "luxvim")
end
```

`LUXVIM_CONFIG` env var allows override for testing or non-standard setups.

**Config file overrides:**

Some plugin specs load config via `require()` (e.g., `opts = require("plugins.ui.config.luxdash")`). Users can override these by placing files at the same require path under their config directory's `lua/` subdirectory. The user config path is prepended to `package.path` early in `core/init.lua`, so user modules shadow framework modules:

```
~/.config/luxvim/
  lua/
    plugins/ui/config/luxdash.lua   -- shadows framework's luxdash config
```

This works because `require()` searches `package.path` in order — user path first, framework path second.

### File Changes

| Action | File |
|--------|------|
| Create | `lua/core/lib/pipeline/merge.lua` (~80 lines, covered in Section 1) |
| Modify | `lua/core/lib/pipeline/discover.lua` (scan user dirs too) |
| Modify | `lua/core/lib/data.lua` (add `user_config_path()`) |
| Modify | `lua/core/init.lua` (load user init.lua early, apply registry overrides) |
| Modify | `lua/core/lib/keymap.lua` (support extends/replaces in registry) |
| Modify | `lua/core/lib/autocmd.lua` (support extends/replaces in registry) |

## 4. Action Registry

### Current State

`actions.lua` (203 lines) mixes two concerns: the registry/resolution mechanism (~75 lines) and hardcoded core actions (~125 lines). Core actions aren't overridable through the normal plugin system. The `split_action` function iterates all namespaces to find prefix matches — O(n) per resolve.

### Design

Separate the registry mechanism from the core actions. Core actions become a regular plugin spec.

**Registry (`actions.lua` → ~50 lines):**

Keep:
- `register(namespace, name, fn)` — unchanged
- `resolve(action_string)` — simplified, see below
- `invoke(action_string)` — unchanged
- `register_from_spec(spec)` — unchanged

Add:
- `register_namespace(namespace, actions_table)` — bulk registration (public API for what `register_from_spec` does internally)
- `unregister(namespace, name)` — remove an action (also clears cache entry)

Simplify:
- `split_action()`: the current implementation iterates all registered namespaces to find a prefix match, which is O(n). However, namespaces CAN contain dots (e.g., `fzf.vim` from `basename("junegunn/fzf.vim")`), so a naive first-dot split would break `"fzf.vim.files"` into `("fzf", "vim.files")` instead of `("fzf.vim", "files")`. Replace with a longest-prefix match: sort registered namespaces by length descending, check each as a prefix. This is still O(n) but predictable and correct. With <20 namespaces the performance difference is negligible. Alternatively, maintain a trie of namespace segments — but that's over-engineering at this scale.

Remove:
- `register_core_actions()` and all hardcoded action functions (window, search, filetype, diagnostic)
- The `_cache` dual-storage — the registry lookup via namespace + name is already O(1). The string-keyed cache adds complexity for no measurable gain with <100 actions. Remove it.

**Virtual specs:**

Some specs (like core-actions, theme-picker) don't have a real GitHub repo — they're framework-internal. These use `source = "virtual"` to signal that the transform stage should handle them differently.

Transform stage logic for virtual specs:

```lua
if spec.source == "virtual" then
  -- Don't set lazy_spec[1] (no repo to clone)
  -- Use dir pointing to LuxVim root so lazy.nvim has a valid local plugin
  lazy_spec.dir = debug_mod.get_luxvim_root()
  lazy_spec.name = spec.debug_name or "virtual"
else
  lazy_spec[1] = spec.source
end
```

This gives lazy.nvim a valid spec without attempting to clone. The framework still processes virtual specs for actions, config functions, and other framework features. Virtual specs with a `config` function will have it called by lazy.nvim like any other plugin.

**Core actions as a plugin spec:**

```lua
-- lua/plugins/editor/core-actions.lua
return {
  source = "virtual",
  debug_name = "core",
  actions = {
    save = ":write",
    quit = ":quit",
    force_quit = ":quit!",
    quit_all = ":quitall!",
    save_quit = ":wq",
    vsplit = ":rightbelow vs new",
    hsplit = ":rightbelow split new",
  },
  config = function()
    -- Window navigation (win1-win6)
    local actions = require("core.lib.actions")
    for i = 1, 6 do
      actions.register("core", "win" .. i, function()
        if i <= vim.fn.winnr("$") then
          vim.cmd(i .. "wincmd w")
        end
      end)
    end
  end,
}
```

**Filetype and diagnostic actions:**

These are better expressed as autocmd callbacks than named actions. They don't need to be invokable by name — they're internal reactions to events.

Move the filetype setup logic (fzf/qf handling) into the autocmd registry directly:

```lua
-- registry/autocmds.lua
return {
  FileType = {
    pattern = { "fzf", "qf" },
    callback = function()
      local ft = vim.bo.filetype
      if ft == "fzf" then
        vim.opt_local.laststatus = 0
        vim.opt_local.showmode = false
        vim.opt_local.ruler = false
      elseif ft == "qf" then
        vim.keymap.set("n", "<CR>", "<CR>:cclose<CR>", { buffer = true })
      end
    end,
  },
  -- ...
}
```

This requires two changes:

1. **`autocmd.lua`**: support a `callback` field as an alternative to `action`. If `callback` is present, use it directly; if `action` is present, resolve and invoke it. This is cleaner — not every autocmd needs to go through the action registry.

2. **`schema.lua` autocmd_entry update**: `action` is currently `required = true`, but it can't be required if `callback` is an alternative. Update the schema:

```lua
M.autocmd_entry = {
  action = { type = "string", desc = "Action to invoke (mutually exclusive with callback)" },
  callback = { type = "function", desc = "Direct callback (mutually exclusive with action)" },
  pattern = { type = { "string", "list" }, default = "*", desc = "File pattern" },
  once = { type = "boolean", default = false, desc = "Run only once" },
}
```

Validation should warn if neither `action` nor `callback` is present, or if both are. This mutual-exclusivity check lives in `lua/core/lib/validate.lua` as a dedicated `validate_autocmd_entry()` function (alongside the existing `validate_plugin_spec()`). It runs the standard schema validation first via `validate_against()`, then applies the custom action/callback rule.

The diagnostic config (`ensure_diagnostic_virtual_text`) moves to `options.lua` or the user's `init.lua` — it's a vim setting, not an action.

**Search action:**

The `core.search_text` action and `SearchText` command are redundant with fzf's `:Rg`. Remove both. Additionally, update `lua/plugins/editor/fzf.lua` to point `search_text` at `:Rg` instead of the removed `:SearchText`:

```lua
-- fzf.lua actions (updated)
actions = {
  files = ":Files",
  search_text = ":Rg",  -- was :SearchText, now uses fzf's built-in
},
```

This keeps the `fzf.vim.search_text` action working (keymaps.lua references it) while removing the custom grep implementation.

### File Changes

| Action | File |
|--------|------|
| Modify | `lua/core/lib/actions.lua` (strip to ~50 lines, add unregister) |
| Create | `lua/plugins/editor/core-actions.lua` (~30 lines) |
| Modify | `lua/plugins/editor/fzf.lua` (change `search_text` action from `:SearchText` to `:Rg`) |
| Modify | `lua/core/registry/autocmds.lua` (inline filetype/diagnostic logic) |
| Modify | `lua/core/lib/autocmd.lua` (support `callback` field alongside `action`) |
| Modify | `lua/core/lib/schema.lua` (update autocmd_entry: action optional, add callback field) |
| Modify | `lua/core/init.lua` (remove `register_core_actions()` call, remove SearchText command) |

## 5. Theme Picker as Plugin

### Current State

499 lines across 5 files in `lua/core/theme-picker/`. Hardcoded in core. Uses `loadstring()` for persistence. Has a baked-in theme catalog. Not fully functional.

### Design

Rebuild as a regular plugin spec at `lua/plugins/ui/theme-picker.lua`. No special core access.

**Plugin spec:**

```lua
-- lua/plugins/ui/theme-picker.lua
return {
  source = "virtual",
  debug_name = "theme-picker",
  cmd = { "Themes" },
  actions = {
    open = ":Themes",
  },
  config = function(_, opts)
    local picker = require("plugins.ui.config.theme-picker")
    picker.setup(opts)
  end,
  opts = {
    default_themes = {
      { repo = "LuxVim/nami.nvim", name = "nami", colorscheme = "nami" },
      { repo = "catppuccin/nvim", name = "catppuccin", colorscheme = "catppuccin",
        variants = { "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha" } },
      { repo = "folke/tokyonight.nvim", name = "tokyonight", colorscheme = "tokyonight",
        variants = { "tokyonight-night", "tokyonight-storm", "tokyonight-day", "tokyonight-moon" } },
      { repo = "morhetz/gruvbox", name = "gruvbox", colorscheme = "gruvbox" },
      { repo = "dracula/vim", name = "dracula", colorscheme = "dracula" },
    },
    optional_themes = {
      { repo = "rose-pine/neovim", name = "rose-pine", colorscheme = "rose-pine",
        variants = { "rose-pine", "rose-pine-moon", "rose-pine-dawn" } },
      { repo = "sainnhe/everforest", name = "everforest", colorscheme = "everforest" },
      { repo = "EdenEast/nightfox.nvim", name = "nightfox", colorscheme = "nightfox",
        variants = { "nightfox", "dayfox", "dawnfox", "duskfox", "nordfox", "terafox", "carbonfox" } },
      { repo = "rebelot/kanagawa.nvim", name = "kanagawa", colorscheme = "kanagawa",
        variants = { "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus" } },
      { repo = "navarasu/onedark.nvim", name = "onedark", colorscheme = "onedark" },
      { repo = "nyoom-engineering/oxocarbon.nvim", name = "oxocarbon", colorscheme = "oxocarbon" },
      { repo = "sainnhe/sonokai", name = "sonokai", colorscheme = "sonokai" },
      { repo = "marko-cerovac/material.nvim", name = "material", colorscheme = "material" },
      { repo = "sainnhe/edge", name = "edge", colorscheme = "edge" },
    },
  },
}
```

**Internal structure — collapses 5 files into config module:**

| Current file | Becomes | Lines |
|-------------|---------|-------|
| `catalog.lua` (119 lines) | `opts.default_themes` / `opts.optional_themes` in spec | 0 (data in spec) |
| `persistence.lua` (85 lines) | `vim.json.encode`/`vim.json.decode` helper in config | ~30 lines |
| `preview.lua` (30 lines) | Inlined into UI logic | ~10 lines |
| `ui.lua` (232 lines) | Rewritten cleaner in config module | ~130 lines |
| `init.lua` (33 lines) | Replaced by spec + config function | 0 |

Config module lives at `lua/plugins/ui/config/theme-picker.lua` (~170 lines total).

**Key UI simplifications:**

- `build_items()` and `render()` only run on state changes (install/uninstall/open), not on cursor movement
- Cursor movement only calls `nvim_win_set_cursor` + preview apply — no rebuild
- Persistence uses `vim.json.encode`/`vim.json.decode` instead of hand-written Lua table serialization and `loadstring`

**Installed theme injection:**

The theme picker needs to inject lazy.nvim specs for user-installed themes so they're available at startup. This creates a timing challenge: the theme picker's `config` function runs AFTER the pipeline (lazy.nvim calls config after `setup_lazy()`), so it can't register pipeline hooks at that point.

Solution: the discover stage scans a known `data/dynamic-specs/` directory for additional spec files. The theme picker writes spec files to this directory when themes are installed/uninstalled. On next startup, discover finds them naturally alongside the regular plugin specs.

```
data/dynamic-specs/
  theme-catppuccin.lua    -- written by theme picker on install
  theme-rose-pine.lua     -- written by theme picker on install
```

Each file is a standard spec:

```lua
-- data/dynamic-specs/theme-catppuccin.lua (auto-generated by theme picker)
return {
  source = "catppuccin/nvim",
  lazy = { lazy = true, priority = 1000 },
}
```

The theme picker's install/uninstall actions write and delete these files. On next `lux` launch, discover picks them up automatically. No hooks needed, no timing issues, and it proves the auto-discovery system works for dynamic plugin management.

The discover stage change is minimal: scan `data/dynamic-specs/` as an additional directory (no category, no defaults). If the directory doesn't exist, discover returns an empty list for it — no error.

**Note on `.gitignore`:** The `data/` directory is gitignored, so `data/dynamic-specs/` is local state that won't be committed. This is intentional — installed themes are a per-machine preference, not a framework concern. Users who want to sync theme preferences across machines can do so via their user config (`~/.config/luxvim/`) by adding theme plugin specs there.

**Relationship to `colorschemes.lua`:**

The existing `lua/plugins/ui/colorschemes.lua` spec loads fathom.nvim as the active default colorscheme. This is a separate concern from the theme picker — colorschemes.lua sets "which colorscheme is active right now," while the theme picker manages "which colorschemes are available to choose from." Both files remain:

- `colorschemes.lua` — stays as-is, loads the default active colorscheme (fathom)
- `theme-picker.lua` — new plugin for browsing, installing, and switching themes

When a user selects a theme via the picker, the picker updates persistence and writes a dynamic spec. On restart, the new theme is available. If the user wants to change the default startup colorscheme, they override `colorschemes.lua` via the user config layer (`extends = "fathom.nvim"` with a different colorscheme in config).

**In-session install behavior:**

When a user installs a theme via the picker during a session, the spec file is written to `data/dynamic-specs/` immediately. However, the theme is not available until the next `lux` restart — the pipeline and lazy.nvim have already run for the current session. The picker UI should display a message: "Theme added. Restart LuxVim to activate." This matches the current behavior (`"Run :Lazy sync to install, then restart LuxVim"`).

**What gets deleted:**

The entire `lua/core/theme-picker/` directory (5 files, 499 lines).

### File Changes

| Action | File |
|--------|------|
| Delete | `lua/core/theme-picker/` (entire directory) |
| Create | `lua/plugins/ui/theme-picker.lua` (~40 lines, spec with full catalog in opts) |
| Create | `lua/plugins/ui/config/theme-picker.lua` (~170 lines, implementation) |
| Modify | `lua/core/lib/pipeline/discover.lua` (scan `data/dynamic-specs/` directory) |

## 6. Micro-Optimizations & Cleanup

### Deferred Condition Evaluation

Currently `evaluate_condition()` runs eagerly during transform, shelling out to `vim.fn.executable` synchronously at startup. For 14 plugins this is fast, but it scales poorly.

Change: pass conditions through to lazy.nvim's native `cond` field as functions instead of evaluating eagerly:

```lua
-- In transform stage, instead of:
if not evaluate_condition(spec.cond) then return nil end

-- Pass through:
lazy_spec.cond = function() return evaluate_condition(spec.cond) end
```

Lazy.nvim handles the deferred evaluation. `evaluate_condition()` moves to a shared utility used by the transform stage.

### Dead Code Removal

| File | Action | Reason |
|------|--------|--------|
| `lua/plugins/lib/parallux.lua` | Delete | Disabled (`enabled = false`), not referenced |
| `lua/core/theme-picker/` | Delete | Replaced by plugin (Section 5) |
| `SearchText` command in `core/init.lua` | Remove | Redundant with fzf `:Rg` |

### Typegen Update

`typegen.lua` switches from direct `schema.plugin_spec` access to `schema.get("plugin_spec")`. Picks up user-extended fields automatically. No logic change.

### Validation Cache

In `validate.lua`, `vim.tbl_keys(schema_def)` and `table.sort()` are called per unknown field in the warning path. Cache once per `validate_against` call:

```lua
function M.validate_against(value, schema_def, path)
  local errors = {}
  local warnings = {}
  path = path or "spec"
  local known_fields = nil  -- lazy cache

  -- ... existing required/type checks ...

  for field, _ in pairs(value) do
    if not schema_def[field] then
      if not known_fields then
        known_fields = vim.tbl_keys(schema_def)
        table.sort(known_fields)
      end
      table.insert(warnings, {
        level = M.errors.WARNING,
        path = path .. "." .. field,
        message = "unknown field (known: " .. table.concat(known_fields, ", ") .. ")",
      })
    end
  end

  return errors, warnings
end
```

## 7. Updated Core Orchestration

`core/init.lua` changes to reflect the new architecture:

```lua
function M.setup()
  local pipeline = require("core.lib.pipeline")
  local bootstrap = require("core.lib.bootstrap")
  local actions = require("core.lib.actions")
  local keymap = require("core.lib.keymap")
  local autocmd = require("core.lib.autocmd")
  local data = require("core.lib.data")

  -- Load user init.lua early (schema extensions, pipeline hooks)
  local user_init = data.user_config_path() .. "/init.lua"
  if vim.uv.fs_stat(user_init) then
    dofile(user_init)
  end

  -- Run pipeline
  local result = pipeline.run()

  if not result.ok then
    -- report critical errors and bail
    return false
  end

  -- Setup lazy.nvim with transformed specs
  bootstrap.setup_lazy(result.specs)

  -- Register actions from all specs
  for _, spec in ipairs(result.raw_specs) do
    actions.register_from_spec(spec)
  end

  -- Setup keymaps and autocmds (with user overrides)
  keymap.setup()
  autocmd.setup()

  M._create_commands()
  return true
end
```

**Remaining commands in `_create_commands()`:**

- `:LuxVimErrors` — show pipeline errors/warnings (reads from `result.errors`/`result.warnings`)
- `:LuxDevStatus` — show active debug plugins (unchanged)
- `:LuxVimGenerateTypes` — generate type annotations (unchanged, uses `schema.get()`)
- `:SearchText` — removed (redundant with fzf `:Rg`)

## Summary

| Area | Current Lines | Estimated After | Change |
|------|--------------|----------------|--------|
| Loader (monolith) | 328 | 0 (replaced by pipeline) | -328 |
| Pipeline (new) | 0 | ~365 (orchestrator + 5 stages) | +365 |
| Schema | 47 | ~65 | +18 |
| Validate | 95 | ~95 (same logic, minor cache) | 0 |
| Actions | 203 | ~50 | -153 |
| Core actions plugin (new) | 0 | ~30 | +30 |
| Theme picker (core) | 499 | 0 (deleted) | -499 |
| Theme picker (plugin, new) | 0 | ~195 | +195 |
| Core init | 88 | ~50 | -38 |
| Autocmd | 50 | ~60 | +10 |
| Dead code removed | ~20 | 0 | -20 |
| **Total** | **~1330** | **~910** | **~-420 lines** |

Net reduction of ~420 lines while adding: pipeline hooks, pluggable schema, user config layer, override semantics, and a working theme picker. Every module gets smaller and more focused.
