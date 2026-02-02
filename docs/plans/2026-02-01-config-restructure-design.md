# LuxVim Configuration Restructure Design

**Date:** 2026-02-01
**Status:** Approved
**Goal:** Restructure configurations, plugins, and core setup for long-term extensibility and maintainability

## Overview

This design restructures LuxVim from scattered configuration files to a layered architecture with:
- Clear separation of concerns (data vs logic)
- Centralized registries for user-facing configuration
- Declarative plugin specs with minimal boilerplate
- Comprehensive validation and error handling
- Generated type annotations for IDE support

## Directory Structure

```
lua/
├── init.lua                          # Minimal entry point
├── config/
│   └── options.lua                   # Vim settings (standalone)
├── core/
│   ├── init.lua                      # Orchestrator
│   ├── registry/                     # User-facing configuration (data)
│   │   ├── keymaps.lua               # All keymap declarations
│   │   ├── autocmds.lua              # Global autocmd declarations
│   │   ├── filetypes.lua             # Filetype-specific settings
│   │   ├── conditions.lua            # Reusable load conditions
│   │   └── actions.lua               # Action overrides (rare)
│   └── lib/                          # Infrastructure (logic)
│       ├── bootstrap.lua             # Lazy.nvim setup
│       ├── loader.lua                # Plugin discovery and transformation
│       ├── schema.lua                # Spec schema definition
│       ├── validate.lua              # Validation logic
│       ├── keymap.lua                # Keymap registration
│       ├── autocmd.lua               # Autocmd registration
│       ├── actions.lua               # Action resolution
│       └── debug.lua                 # Debug plugin detection
├── plugins/                          # Plugin specs by category
│   ├── lib/                          # Utility plugins
│   │   ├── _defaults.lua
│   │   └── plenary.lua
│   ├── ui/                           # UI plugins
│   │   ├── _defaults.lua
│   │   ├── luxdash.lua
│   │   ├── luxline.lua
│   │   ├── luxmotion.lua
│   │   └── nvim-tree.lua
│   ├── editor/                       # Editor enhancement plugins
│   │   ├── _defaults.lua
│   │   ├── treesitter.lua
│   │   ├── easycomment.lua
│   │   └── fzf.lua
│   ├── lsp/                          # LSP plugins
│   │   ├── _defaults.lua
│   │   ├── lspconfig.lua
│   │   └── luxlsp.lua
│   └── terminal/                     # Terminal plugins
│       ├── _defaults.lua
│       └── luxterm.lua
├── types/                            # Generated type annotations
│   └── plugin.lua                    # (generated from schema)
└── utils.lua                         # Shared utilities
```

## Initialization Flow

```
init.lua
   │
   ├─→ config/options.lua        [1] Set vim options first
   │
   └─→ core/init.lua             [2] Bootstrap infrastructure
          │
          ├─→ lib/bootstrap.lua  [3] Install/setup Lazy.nvim
          │
          ├─→ lib/loader.lua     [4] Discover plugins, build specs
          │      │
          │      ├─→ Scan plugins/*/_defaults.lua
          │      ├─→ Scan plugins/*/*.lua
          │      ├─→ lib/debug.lua (check for debug overrides)
          │      └─→ Transform specs → Lazy format
          │
          ├─→ Lazy.setup(specs)  [5] Load plugins
          │
          ├─→ lib/keymap.lua     [6] Register keymaps from registry
          │      └─→ registry/keymaps.lua
          │
          ├─→ lib/autocmd.lua    [7] Register autocmds from registry
          │      ├─→ registry/autocmds.lua
          │      └─→ registry/filetypes.lua
          │
          └─→ lib/actions.lua    [8] Validate all action mappings
```

## Plugin Spec Format

### Minimal Spec

```lua
-- lua/plugins/ui/luxdash.lua
return {
  source = "luxvim/nvim-luxdash",
}
```

### Full Spec

```lua
return {
  -- Required
  source = "author/plugin-name",

  -- Core fields
  opts = {},                              -- passed to setup()
  config = function(opts) end,            -- custom config
  dependencies = { "plenary", "nui" },    -- references to other specs

  -- Loading
  event = "BufReadPost",                  -- override category default
  cmd = { "Command" },
  ft = { "lua", "python" },
  cond = "has_git",                       -- or inline function
  enabled = true,

  -- Build
  build = {
    cmd = "make",
    platforms = { windows = "cmake ..." },
    requires = { "make", "gcc" },
    cond = "has_make",
    on_fail = "warn",
    outputs = { "build/lib.so" },
  },

  -- Actions
  debug_name = "plugin-name",             -- override convention
  actions = {
    toggle = function() ... end,          -- override convention
  },

  -- Lazy.nvim passthrough
  lazy = {
    priority = 1000,
    pin = true,
  },
}
```

### Spec Fields Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source` | string | Yes | GitHub repo (author/name) |
| `opts` | table | No | Options passed to setup() |
| `config` | function | No | Custom config function |
| `dependencies` | string[] | No | References to other plugin specs |
| `event` | string/string[] | No | Lazy-load on event |
| `cmd` | string/string[] | No | Lazy-load on command |
| `ft` | string/string[] | No | Lazy-load on filetype |
| `cond` | string/function | No | Load condition |
| `enabled` | boolean | No | Enable/disable plugin (default: true) |
| `build` | string/BuildSpec | No | Build configuration |
| `debug_name` | string | No | Override debug folder detection |
| `actions` | table | No | Action function overrides |
| `lazy` | table | No | Lazy.nvim native fields (passthrough) |

### Build Spec Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cmd` | string | Yes | Default build command |
| `platforms` | table | No | OS-specific commands (linux, mac, windows) |
| `requires` | string[] | No | Required executables |
| `cond` | string | No | Condition from registry |
| `on_fail` | string | No | "warn", "error", or "ignore" |
| `outputs` | string[] | No | Expected output files |

## Registries

### Keymaps Registry

```lua
-- lua/core/registry/keymaps.lua
return {
  editor = {
    ["<leader>fs"] = { action = "core.save", desc = "Save file" },
    ["<leader>fq"] = { action = "core.quit", desc = "Quit" },
  },
  ui = {
    ["<leader>h"] = { action = "luxdash.toggle", desc = "Home dashboard" },
    ["<leader>e"] = { action = "nvim-tree.toggle", desc = "File explorer" },
  },
  lsp = {
    ["gd"] = { action = "lsp.definition", desc = "Go to definition" },
    ["K"] = { action = "lsp.hover", desc = "Hover info" },
  },
}
```

### Autocmds Registry

```lua
-- lua/core/registry/autocmds.lua
return {
  VimEnter = { action = "luxdash.show" },
  VimLeavePre = { action = "core.save_session" },
}
```

### Filetypes Registry

```lua
-- lua/core/registry/filetypes.lua
return {
  lua = { tabstop = 2, shiftwidth = 2, expandtab = true },
  python = { tabstop = 4, shiftwidth = 4, colorcolumn = "88" },
  markdown = { wrap = true, spell = true },
}
```

### Conditions Registry

```lua
-- lua/core/registry/conditions.lua
return {
  is_mac = function() return vim.fn.has("mac") == 1 end,
  is_linux = function() return vim.fn.has("linux") == 1 end,
  is_windows = function() return vim.fn.has("win32") == 1 end,
  has_git = function() return vim.fn.executable("git") == 1 end,
  has_node = function() return vim.fn.executable("node") == 1 end,
  has_make = function() return vim.fn.executable("make") == 1 end,
  is_gui = function() return vim.fn.has("gui_running") == 1 end,
}
```

## Category Defaults

Each category has a `_defaults.lua` that defines default lazy-loading behavior:

```lua
-- lua/plugins/ui/_defaults.lua
return {
  event = "VimEnter",
}

-- lua/plugins/editor/_defaults.lua
return {
  event = { "BufReadPost", "BufNewFile" },
}

-- lua/plugins/lsp/_defaults.lua
return {
  event = "LspAttach",
}

-- lua/plugins/lib/_defaults.lua
return {
  lazy = true,  -- only load when required as dependency
}
```

## Action Resolution

Actions resolve using convention with explicit override:

1. Check if plugin spec has explicit action → use it
2. Try convention: `"pluginname.method"` → `require("pluginname").method()`
3. Neither works → startup warning

### Convention Examples

```lua
"luxdash.toggle"     → require("luxdash").toggle()
"nvim-tree.toggle"   → require("nvim-tree.api").tree.toggle()  -- needs override
"telescope.files"    → require("telescope.builtin").find_files()  -- needs override
```

### Override in Spec

```lua
return {
  source = "nvim-tree/nvim-tree.lua",
  actions = {
    toggle = function() require("nvim-tree.api").tree.toggle() end,
    focus = function() require("nvim-tree.api").tree.focus() end,
  },
}
```

## Debug Plugin Detection

Debug plugins auto-detected using convention with explicit override:

**Convention:** Extract name from source after `/`
```
"luxvim/nvim-luxdash" → debug/nvim-luxdash/
"folke/lazy.nvim"     → debug/lazy.nvim/
```

**Override:** Use `debug_name` field when convention fails
```lua
return {
  source = "nvim-tree/nvim-tree.lua",
  debug_name = "nvim-tree",  -- debug/nvim-tree/ instead of debug/nvim-tree.lua/
}
```

## Dependencies

Dependencies reference other spec files:

```lua
return {
  source = "nvim-telescope/telescope.nvim",
  dependencies = {
    "plenary",        -- → plugins/lib/plenary.lua
    "telescope-fzf",  -- → plugins/ui/telescope-fzf.lua
  },
}
```

Resolution searches `plugins/*/` for matching filename or source.

## Validation

### Tiered Strictness

| Severity | Behavior | Examples |
|----------|----------|----------|
| Critical | Block startup | Missing `source`, malformed spec, circular deps |
| Non-critical | Warn, skip plugin | Unknown fields, missing dependency, build failure |

### Error Output

```
-- Critical (startup blocked):
[LuxVim] FATAL: Cannot start
  plugins/ui/broken.lua: spec must be a table, got string

-- Non-critical (startup continues):
[LuxVim] Plugin skipped: plugins/ui/telescope.lua
  Dependency "plenary" not found

-- Summary at end:
[LuxVim] Started with 2 warnings. Run :checkhealth luxvim for details.
```

## Schema Definition

Declarative schema generates validation and type annotations:

```lua
-- lua/core/lib/schema.lua
M.build_spec = {
  cmd = { type = "string", required = true, desc = "Build command" },
  platforms = {
    type = "table",
    keys = { "linux", "mac", "windows" },
    values = "string",
    desc = "Platform-specific build commands",
  },
  requires = { type = "list", of = "string", desc = "Required executables" },
  cond = { type = "string", desc = "Condition from registry" },
  on_fail = { type = "enum", values = { "warn", "error", "ignore" }, default = "warn" },
  outputs = { type = "list", of = "string", desc = "Expected output files" },
}

M.plugin_spec = {
  source = { type = "string", required = true, desc = "GitHub repo (author/name)" },
  debug_name = { type = "string", desc = "Override debug folder name" },
  opts = { type = "table", default = {}, desc = "Options passed to setup()" },
  config = { type = "function", desc = "Custom config function" },
  build = { type = { "string", M.build_spec }, desc = "Build configuration" },
  actions = { type = "table", desc = "Action overrides for keymap resolution" },
  dependencies = { type = "list", of = "string", desc = "References to other plugin specs" },
  cond = { type = { "string", "function" }, desc = "Load condition" },
  event = { type = { "string", "list" }, desc = "Lazy-load on event" },
  cmd = { type = { "string", "list" }, desc = "Lazy-load on command" },
  ft = { type = { "string", "list" }, desc = "Lazy-load on filetype" },
  enabled = { type = "boolean", default = true, desc = "Enable/disable plugin" },
  lazy = { type = "table", passthrough = true, desc = "Lazy.nvim native fields" },
}
```

### Generated Type Annotations

```lua
-- lua/types/plugin.lua (GENERATED - DO NOT EDIT)
---@class BuildSpec
---@field cmd string Build command
---@field platforms? table<string, string> Platform-specific build commands
---@field requires? string[] Required executables
---@field cond? string Condition from registry
---@field on_fail? "warn"|"error"|"ignore" Failure handling (default: warn)
---@field outputs? string[] Expected output files

---@class PluginSpec
---@field source string GitHub repo (author/name)
---@field debug_name? string Override debug folder name
---@field opts? table Options passed to setup()
---@field config? function Custom config function
---@field build? string|BuildSpec Build configuration
---@field actions? table<string, function> Action overrides
---@field dependencies? string[] References to other plugin specs
---@field cond? string|function Load condition
---@field event? string|string[] Lazy-load on event
---@field cmd? string|string[] Lazy-load on command
---@field ft? string|string[] Lazy-load on filetype
---@field enabled? boolean Enable/disable plugin (default: true)
---@field lazy? table Lazy.nvim native fields (passthrough)
```

## Design Decisions Summary

| Concern | Decision | Rationale |
|---------|----------|-----------|
| Directory structure | Category-based plugins, split registry/lib | Scalable, clear boundaries |
| Keymaps | Centralized registry | Single source of truth, conflict detection |
| Autocmds | Hybrid (global + plugin-internal) | User-facing centralized, implementation colocated |
| Category defaults | Per-category `_defaults.lua` | Avoids monolithic config |
| Debug detection | Convention + override | Zero-config common case, explicit edge cases |
| Actions | Convention + override | DRY with escape hatch |
| Conditions | Named registry + inline fallback | Reusable with flexibility |
| Build system | Comprehensive structured spec | Future-proof, cross-platform |
| Lazy.nvim fields | Namespaced passthrough | Clear boundaries, future-proof |
| Dependencies | References to spec files | DRY, first-class plugins |
| Validation | Tiered strictness | Usable editor, clear errors |
| Schema | Declarative + generated | Single source of truth |

## Migration Path

1. Create new directory structure
2. Build core/lib infrastructure
3. Create registries from existing config
4. Migrate plugins one category at a time
5. Validate and test each category
6. Remove old structure

## Health Check Integration

```
:checkhealth luxvim

LuxVim Configuration
- OK: 24 plugins loaded
- OK: 45 keymaps registered
- OK: 12 autocmds registered
- WARNING: 2 plugins skipped (run :LuxVimErrors for details)

Plugin Builds
- OK: telescope-fzf-native: build/libfzf.so exists
- WARNING: markdown-preview: missing npm, build skipped

Debug Plugins
- ACTIVE: nvim-luxdash (debug/nvim-luxdash)
- ACTIVE: nvim-tree (debug/nvim-tree)
```
