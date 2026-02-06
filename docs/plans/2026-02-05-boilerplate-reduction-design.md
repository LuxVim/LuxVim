# Boilerplate Reduction Design

Reduce redundant and duplicated code across LuxVim's plugin specs and core system by centralizing shared patterns into focused utility modules and making the loader smarter about defaults.

## Problem

The codebase has three categories of redundancy:

1. **Plugin spec boilerplate** -- `debug_name` is manually declared in 10 specs when 8 of them match what `paths.basename(source)` already produces. Trivial `config` wrappers around `require("x").setup(opts)` exist where `opts` alone suffices.

2. **Scattered infrastructure patterns** -- Data path construction is done 3 different ways across `bootstrap.lua`, `lspconfig.lua`, and `treesitter.lua`. Platform detection (`vim.fn.has`) is duplicated in `loader.lua` and `conditions.lua`. Notifications use `vim.notify` and `vim.api.nvim_echo` inconsistently across 12+ locations.

3. **Architectural splits** -- Keymaps are defined in both `core/registry/keymaps.lua` and inline via `lazy.keys` in plugin specs (`luxterm.lua`, `easyops.lua`). Large option tables (nvim-tree at 152 lines, luxdash at 115 lines) dominate their spec files, mixing loading concerns with behavioral configuration.

## Design

### Stage 1: Infrastructure Utilities

Three new modules in `lua/core/lib/`, each with a single responsibility.

#### 1a. `lua/core/lib/data.lua` -- Data Path Resolution

Single source of truth for all LuxVim data directory paths.

```lua
local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")

local M = {}

local _root

function M.root()
  if _root then
    return _root
  end
  _root = vim.env.XDG_DATA_HOME or debug_mod.get_luxvim_root()
  return _root
end

function M.lazy_path()
  return paths.join(M.root(), "data", "lazy", "lazy.nvim")
end

function M.lazy_root()
  return paths.join(M.root(), "data", "lazy")
end

function M.lockfile_path()
  return paths.join(M.root(), "lazy-lock.json")
end

function M.luxlsp_path()
  return paths.join(M.root(), "data", "luxlsp")
end

function M.parser_path()
  return paths.join(M.root(), "data", "site")
end

return M
```

**Consumers to update:**

| File | Current Pattern | Replacement |
|------|----------------|-------------|
| `bootstrap.lua:7` | `vim.env.XDG_DATA_HOME or debug_mod.get_luxvim_root()` repeated 3x | `data.root()`, `data.lazy_path()`, `data.lazy_root()`, `data.lockfile_path()` |
| `lspconfig.lua:10` | `vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "data", "luxlsp")` | `data.luxlsp_path()` |
| `treesitter.lua:10-11` | `vim.env.XDG_DATA_HOME or vim.fn.stdpath("data")` + manual join | `data.parser_path()` |

**bootstrap.lua before:**
```lua
function M.get_lazy_path()
  local data_dir = vim.env.XDG_DATA_HOME or debug_mod.get_luxvim_root()
  return paths.join(data_dir, "data", "lazy", "lazy.nvim")
end

function M.get_lazy_root()
  local data_dir = vim.env.XDG_DATA_HOME or debug_mod.get_luxvim_root()
  return paths.join(data_dir, "data", "lazy")
end

function M.get_lockfile_path()
  local data_dir = vim.env.XDG_DATA_HOME or debug_mod.get_luxvim_root()
  return paths.join(data_dir, "lazy-lock.json")
end
```

**bootstrap.lua after:**
```lua
local data = require("core.lib.data")

function M.get_lazy_path()
  return data.lazy_path()
end

function M.get_lazy_root()
  return data.lazy_root()
end

function M.get_lockfile_path()
  return data.lockfile_path()
end
```

**lspconfig.lua config before:**
```lua
config = function()
  local ok, luxlsp = pcall(require, "luxlsp")
  if ok then
    luxlsp.setup({
      install_root = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "data", "luxlsp"),
    })
  end
end,
```

**lspconfig.lua config after:**
```lua
config = function()
  local ok, luxlsp = pcall(require, "luxlsp")
  if ok then
    local data = require("core.lib.data")
    luxlsp.setup({
      install_root = data.luxlsp_path(),
    })
  end
end,
```

**treesitter.lua config before:**
```lua
config = function()
  local paths = require("core.lib.paths")
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.stdpath("data")
  local parser_install_dir = paths.join(data_dir, "data", "site")

  require("nvim-treesitter.config").setup({
    install_dir = parser_install_dir,
  })
  -- ...
end,
```

**treesitter.lua config after:**
```lua
config = function()
  local data = require("core.lib.data")

  require("nvim-treesitter.config").setup({
    install_dir = data.parser_path(),
  })
  -- ...
end,
```

#### 1b. `lua/core/lib/platform.lua` -- OS Detection

Detects once, caches, consumed everywhere.

```lua
local M = {}

M.os = vim.fn.has("mac") == 1 and "mac"
    or vim.fn.has("win32") == 1 and "windows"
    or "linux"

M.is_mac = M.os == "mac"
M.is_windows = M.os == "windows"
M.is_linux = M.os == "linux"

return M
```

**Consumers to update:**

| File | Current Pattern | Replacement |
|------|----------------|-------------|
| `loader.lua:222-224` | Inline `vim.fn.has` chain in `transform_build` | `platform.os` |
| `conditions.lua:2-12` | Three separate `vim.fn.has` functions | Delegate to `platform` fields |

**loader.lua transform_build before:**
```lua
if build.platforms then
  local platform = vim.fn.has("mac") == 1 and "mac"
      or vim.fn.has("linux") == 1 and "linux"
      or vim.fn.has("win32") == 1 and "windows"
  if build.platforms[platform] then
    cmd = build.platforms[platform]
  end
end
```

**loader.lua transform_build after:**
```lua
if build.platforms then
  local platform = require("core.lib.platform")
  if build.platforms[platform.os] then
    cmd = build.platforms[platform.os]
  end
end
```

**conditions.lua before:**
```lua
is_mac = function()
  return vim.fn.has("mac") == 1
end,

is_linux = function()
  return vim.fn.has("linux") == 1
end,

is_windows = function()
  return vim.fn.has("win32") == 1
end,
```

**conditions.lua after:**
```lua
local platform = require("core.lib.platform")

-- ...

is_mac = function()
  return platform.is_mac
end,

is_linux = function()
  return platform.is_linux
end,

is_windows = function()
  return platform.is_windows
end,
```

#### 1c. `lua/core/lib/notify.lua` -- Notification Standardization

Consistent notification API with `[LuxVim]` prefix.

```lua
local M = {}

function M.info(msg)
  vim.notify("[LuxVim] " .. msg, vim.log.levels.INFO)
end

function M.warn(msg)
  vim.notify("[LuxVim] " .. msg, vim.log.levels.WARN)
end

function M.error(msg)
  vim.notify("[LuxVim] " .. msg, vim.log.levels.ERROR)
end

return M
```

**Rule:** Use `vim.api.nvim_echo` only in `bootstrap.lua` (before the notification system is available). All other locations use `notify.lua`.

**Consumers to update:**

| File | Line(s) | Current | Replacement |
|------|---------|---------|-------------|
| `loader.lua` | 301 | `vim.api.nvim_echo({{ msg, "ErrorMsg" }}, true, {})` | `notify.error(msg)` |
| `loader.lua` | 310 | `vim.notify("[LuxVim] Plugin skipped: "..e.file, ...)` | `notify.warn("Plugin skipped: "..e.file)` |
| `actions.lua` | 54 | `vim.notify("[LuxVim] "..err, vim.log.levels.WARN)` | `notify.warn(err)` |
| `keymap.lua` | 40 | `vim.notify("[LuxVim] Failed to load keymap registry: "..tostring(registry), ...)` | `notify.warn("Failed to load keymap registry: "..tostring(registry))` |
| `autocmd.lua` | various | `vim.notify("[LuxVim] ..."` patterns | `notify.warn(...)` / `notify.error(...)` |
| `colorschemes.lua` | 14 | `vim.api.nvim_echo({{ "LuxVim: Failed to load colorscheme", "WarningMsg" }}, true, {})` | `notify.warn("Failed to load colorscheme")` |

---

### Stage 2: Plugin Spec Cleanup

#### 2a. Auto-derive `debug_name` from `source`

The loader already has `extract_plugin_name(source)` which calls `paths.basename(source)`. This returns the last path component after `/`.

**Current behavior of `basename(source)` vs declared `debug_name`:**

| Spec | Source | basename(source) | Declared debug_name | Match? |
|------|--------|-------------------|---------------------|--------|
| luxterm | `LuxVim/nvim-luxterm` | `nvim-luxterm` | `nvim-luxterm` | YES |
| easyops | `josstei/vim-easyops` | `vim-easyops` | `vim-easyops` | YES |
| quill | `josstei/quill.nvim` | `quill.nvim` | `quill.nvim` | YES |
| luxdash | `LuxVim/nvim-luxdash` | `nvim-luxdash` | `nvim-luxdash` | YES |
| luxline | `LuxVim/nvim-luxline` | `nvim-luxline` | `nvim-luxline` | YES |
| lspconfig | `neovim/nvim-lspconfig` | `nvim-lspconfig` | `nvim-lspconfig` | YES |
| luxpane | `LuxVim/vim-luxpane` | `vim-luxpane` | `vim-luxpane` | YES |
| easyenv | `josstei/vim-easyenv` | `vim-easyenv` | `vim-easyenv` | YES |
| nvim-tree | `nvim-tree/nvim-tree.lua` | `nvim-tree.lua` | `nvim-tree` | NO |
| parallux | `josstei/parallux.nvim` | `parallux.nvim` | `parallux` | NO |

**8 of 10 match exactly.** The 2 mismatches need explicit `debug_name` because their GitHub repo names include `.lua`/`.nvim` suffixes that don't match their debug directory names.

**Change in `loader.lua`:** When `debug_name` is not provided, auto-derive it via `extract_plugin_name(source)`. The `debug_name` field becomes an override for the rare cases where basename doesn't match.

**loader.lua transform_to_lazy change:**
```lua
-- Before: debug_name is required for debug detection
local debug_name = spec.debug_name

-- After: auto-derive from source, allow override
local debug_name = spec.debug_name or M.extract_plugin_name(spec.source)
```

**Specs to simplify (remove redundant `debug_name`):**

| File | Remove Line |
|------|------------|
| `plugins/terminal/luxterm.lua` | `debug_name = "nvim-luxterm",` |
| `plugins/editor/easyops.lua` | `debug_name = "vim-easyops",` |
| `plugins/editor/quill.lua` | `debug_name = "quill.nvim",` |
| `plugins/ui/luxdash.lua` | `debug_name = "nvim-luxdash",` |
| `plugins/ui/luxline.lua` | `debug_name = "nvim-luxline",` |
| `plugins/lsp/lspconfig.lua` | `debug_name = "nvim-lspconfig",` |
| `plugins/navigation/luxpane.lua` | `debug_name = "vim-luxpane",` |
| `plugins/editor/easyenv.lua` | `debug_name = "vim-easyenv",` |

**Specs that keep explicit `debug_name`:**

| File | Reason |
|------|--------|
| `plugins/ui/nvim-tree.lua` | `basename("nvim-tree/nvim-tree.lua")` = `nvim-tree.lua`, debug dir is `nvim-tree` |
| `plugins/lib/parallux.lua` | `basename("josstei/parallux.nvim")` = `parallux.nvim`, debug dir is `parallux` |

#### 2b. Eliminate Trivial Config Wrappers

**quill.lua before:**
```lua
return {
  source = "josstei/quill.nvim",
  debug_name = "quill.nvim",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("quill").setup({
      warn_on_override = false,
    })
  end,
}
```

**quill.lua after:**
```lua
return {
  source = "josstei/quill.nvim",
  opts = {
    warn_on_override = false,
  },
}
```

The `event` field is removed because `editor/_defaults.lua` already provides `{ "BufReadPost", "BufNewFile" }`. The `config` function is removed because lazy.nvim automatically calls `require("quill").setup(opts)` when only `opts` is provided.

**Note:** This requires the loader's `transform_to_lazy` to pass `opts` through to lazy.nvim correctly when no `config` is provided. Verify this path works before applying.

**Specs that keep their config functions (justified):**

| File | Reason |
|------|--------|
| `colorschemes.lua` | Applies colorscheme via `vim.cmd` after setup, with error handling |
| `lspconfig.lua` | Conditional `pcall(require, "luxlsp")` guard |
| `treesitter.lua` | Custom path resolution + autocmd registration |
| `easyops.lua` | Sets multiple `vim.g` global tables |
| `luxpane.lua` | Sets `vim.g` variables (could move to opts if plugin supports it) |

#### 2c. Extract Large Option Tables

Create `lua/plugins/<category>/config/` directories for specs where opts dominate the file.

**New files:**

| File | Source | Lines Extracted |
|------|--------|----------------|
| `lua/plugins/ui/config/nvim-tree.lua` | `nvim-tree.lua` opts | 152 lines |
| `lua/plugins/ui/config/luxdash.lua` | `luxdash.lua` opts | 115 lines |

**luxline.lua** (27 lines of opts) stays inline -- the threshold for extraction is roughly 50+ lines of opts. Below that, extraction adds indirection without meaningful benefit.

**nvim-tree.lua before (165 lines):**
```lua
return {
  source = "nvim-tree/nvim-tree.lua",
  debug_name = "nvim-tree",
  dependencies = { "nvim-web-devicons" },
  cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeOpen" },
  actions = {
    toggle = function()
      require("nvim-tree.api").tree.toggle()
    end,
    focus = function()
      require("nvim-tree.api").tree.focus()
    end,
  },
  opts = {
    disable_netrw = true,
    -- ... 152 lines of configuration ...
  },
}
```

**nvim-tree.lua after (~15 lines):**
```lua
return {
  source = "nvim-tree/nvim-tree.lua",
  debug_name = "nvim-tree",
  dependencies = { "nvim-web-devicons" },
  cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeOpen" },
  actions = {
    toggle = function()
      require("nvim-tree.api").tree.toggle()
    end,
    focus = function()
      require("nvim-tree.api").tree.focus()
    end,
  },
  opts = require("plugins.ui.config.nvim-tree"),
}
```

**`lua/plugins/ui/config/nvim-tree.lua`** contains the extracted opts table:
```lua
return {
  disable_netrw = true,
  -- ... full 152-line configuration table ...
}
```

Same pattern for luxdash. The spec file focuses on *what* the plugin is and *how* it loads. The config file owns *how* it behaves.

---

### Stage 3: Minor Cleanups

#### 3a. Window Navigation Loop

**actions.lua before (lines 95-123):**
```lua
local function goto_win(n)
  if n <= vim.fn.winnr("$") then
    vim.cmd(n .. "wincmd w")
  end
end

M.register("core", "win1", function() goto_win(1) end)
M.register("core", "win2", function() goto_win(2) end)
M.register("core", "win3", function() goto_win(3) end)
M.register("core", "win4", function() goto_win(4) end)
M.register("core", "win5", function() goto_win(5) end)
M.register("core", "win6", function() goto_win(6) end)
```

**actions.lua after:**
```lua
local function goto_win(n)
  if n <= vim.fn.winnr("$") then
    vim.cmd(n .. "wincmd w")
  end
end

for i = 1, 6 do
  M.register("core", "win" .. i, function() goto_win(i) end)
end
```

**keymaps.lua before (lines 12-19):**
```lua
["<leader>1"] = { action = "core.win1", desc = "Go to window 1" },
["<leader>2"] = { action = "core.win2", desc = "Go to window 2" },
["<leader>3"] = { action = "core.win3", desc = "Go to window 3" },
["<leader>4"] = { action = "core.win4", desc = "Go to window 4" },
["<leader>5"] = { action = "core.win5", desc = "Go to window 5" },
["<leader>6"] = { action = "core.win6", desc = "Go to window 6" },
```

**keymaps.lua after:**
```lua
-- Generated in a loop at the bottom of the file or inline:
local navigation = {
  ["<leader>wv"] = { action = "core.vsplit", desc = "Vertical split" },
  ["<leader>wh"] = { action = "core.hsplit", desc = "Horizontal split" },
}

for i = 1, 6 do
  navigation["<leader>" .. i] = { action = "core.win" .. i, desc = "Go to window " .. i }
end
```

Note: The registry currently returns a static table. This change requires the file to build the table procedurally before returning it. The `editor` and `ui` sections remain static tables; only `navigation` uses the loop.

#### 3b. Condition Evaluation Dedup

**loader.lua evaluate_condition before (lines 108-128):**
```lua
function M.evaluate_condition(cond)
  if cond == nil then return true end

  if type(cond) == "function" then
    local ok, result = pcall(cond)
    return ok and result
  end

  if type(cond) == "string" then
    local condition_fn = conditions[cond]
    if condition_fn then
      local ok, result = pcall(condition_fn)
      return ok and result
    end
    return false
  end

  return true
end
```

**loader.lua evaluate_condition after:**
```lua
local function safe_eval(fn)
  local ok, result = pcall(fn)
  return ok and result
end

function M.evaluate_condition(cond)
  if cond == nil then return true end

  if type(cond) == "function" then
    return safe_eval(cond)
  end

  if type(cond) == "string" then
    local condition_fn = conditions[cond]
    if condition_fn then
      return safe_eval(condition_fn)
    end
    return false
  end

  return true
end
```

---

### Stage 4: Keymap Unification

Move inline `lazy.keys` definitions from plugin specs into the central keymap registry, and have the loader generate `lazy.keys` entries from registry mappings.

#### Current State

Keymaps are split across two systems:

1. **Registry keymaps** (`core/registry/keymaps.lua`) -- Resolved via the action system at startup. Used for nvim-tree toggle, window navigation, file operations.
2. **Inline `lazy.keys`** (plugin specs) -- Passed directly to lazy.nvim for lazy-load triggering. Used for luxterm, easyops.

This means some keymaps are discoverable in the registry, others are buried in spec files.

#### Target State

All keymaps live in the registry. The loader reads the registry and generates `lazy.keys` entries for specs that need lazy-load key triggers.

#### Changes Required

**1. Expand `core/registry/keymaps.lua` with new sections:**

```lua
local navigation = { --[[ existing entries ]] }

for i = 1, 6 do
  navigation["<leader>" .. i] = { action = "core.win" .. i, desc = "Go to window " .. i }
end

return {
  editor = {
    ["<leader>fs"] = { action = "core.save", desc = "Save file" },
    ["<leader>fq"] = { action = "core.quit", desc = "Quit" },
    ["<leader>FQ"] = { action = "core.force_quit", desc = "Force quit" },
    ["<leader>bye"] = { action = "core.quit_all", desc = "Quit all" },
    ["<leader>m"] = { action = "vim-easyops.open", desc = "Command palette" },
  },

  navigation = navigation,

  ui = {
    ["<leader>e"] = { action = "nvim-tree.toggle", desc = "File explorer" },
  },

  terminal = {
    ["<C-/>"] = { action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    ["<C-_>"] = { action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    ["<C-`>"] = { action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    ["<C-/>"] = { action = "nvim-luxterm.toggle", desc = "Toggle terminal", mode = "t" },
    ["<C-_>"] = { action = "nvim-luxterm.toggle", desc = "Toggle terminal", mode = "t" },
    ["<C-`>"] = { action = "nvim-luxterm.toggle", desc = "Toggle terminal", mode = "t" },
    ["<C-n>"] = { action = "nvim-luxterm.exit_mode", desc = "Exit terminal mode", mode = "t" },
  },
}
```

**2. Add corresponding actions to plugin specs:**

**luxterm.lua:**
```lua
actions = {
  toggle = function()
    vim.cmd("LuxtermToggle")
  end,
  exit_mode = function()
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true), "n", false
    )
  end,
},
```

**easyops.lua:**
```lua
actions = {
  open = function()
    vim.cmd("EasyOps")
  end,
},
```

**3. Update `loader.lua` transform_to_lazy to generate `lazy.keys`:**

After building the lazy spec, scan the keymap registry for entries whose action namespace matches the current plugin. For each match, add a `lazy.keys` entry so lazy.nvim still triggers lazy-loading on keypress.

```lua
local function generate_lazy_keys(plugin_name, registry)
  local keys = {}
  for _, section in pairs(registry) do
    for lhs, mapping in pairs(section) do
      local ns = mapping.action:match("^(.+)%.")
      if ns == plugin_name then
        table.insert(keys, {
          lhs,
          desc = mapping.desc,
          mode = mapping.mode or "n",
        })
      end
    end
  end
  return #keys > 0 and keys or nil
end
```

This function runs during `transform_to_lazy` and merges its output into the spec's existing `lazy.keys` (if any).

**4. Remove inline `lazy.keys` from plugin specs:**

| File | Lines Removed |
|------|--------------|
| `luxterm.lua` | Lines 5-15 (entire `lazy.keys` block) |
| `easyops.lua` | Lines 5-9 (entire `lazy.keys` block) |

#### Risk Mitigation

This stage modifies how lazy-loading triggers work. The key risk is that a keymap in the registry doesn't produce a valid `lazy.keys` entry, causing the plugin to never load on keypress.

**Mitigation:**
- Test each migrated keymap individually after the change
- Keep the `cmd` declarations on plugin specs as a fallback trigger
- Implement in a single commit so it can be reverted cleanly

#### Terminal Mode Consideration

The luxterm keymaps include terminal-mode (`mode = "t"`) bindings that use `<C-\><C-n>` escape sequences. These are more complex than normal-mode keymaps. The action system needs to handle the `mode` field from registry entries, and the `keymap.lua` module already supports `mode` as a field -- it just needs the registry entries to declare it.

For the `<C-n>` exit binding specifically, the action wraps `nvim_feedkeys` with `nvim_replace_termcodes` rather than a simple command. This is valid as an action function.

---

## Execution Plan

### Stage 1 -- Foundation Utilities

| Task | Files Created | Files Modified | Risk |
|------|--------------|----------------|------|
| Create `data.lua` | `lua/core/lib/data.lua` | -- | LOW |
| Create `platform.lua` | `lua/core/lib/platform.lua` | -- | LOW |
| Create `notify.lua` | `lua/core/lib/notify.lua` | -- | LOW |

### Stage 2 -- Consume Utilities

| Task | Files Modified | Risk |
|------|---------------|------|
| Update `bootstrap.lua` to use `data.lua` | `lua/core/lib/bootstrap.lua` | LOW |
| Update `lspconfig.lua` to use `data.lua` | `lua/plugins/lsp/lspconfig.lua` | LOW |
| Update `treesitter.lua` to use `data.lua` | `lua/plugins/editor/treesitter.lua` | LOW |
| Update `loader.lua` to use `platform.lua` | `lua/core/lib/loader.lua` | LOW |
| Update `conditions.lua` to use `platform.lua` | `lua/core/registry/conditions.lua` | LOW |
| Update notification call sites to use `notify.lua` | `loader.lua`, `actions.lua`, `keymap.lua`, `autocmd.lua`, `colorschemes.lua` | LOW |

### Stage 3 -- Plugin Spec Cleanup

| Task | Files Modified | Risk |
|------|---------------|------|
| Auto-derive `debug_name` in loader | `lua/core/lib/loader.lua` | LOW |
| Remove redundant `debug_name` from 8 specs | 8 plugin spec files | LOW |
| Convert `quill.lua` to use `opts` | `lua/plugins/editor/quill.lua` | LOW |
| Extract nvim-tree opts | Create `lua/plugins/ui/config/nvim-tree.lua`, modify `nvim-tree.lua` | LOW |
| Extract luxdash opts | Create `lua/plugins/ui/config/luxdash.lua`, modify `luxdash.lua` | LOW |

### Stage 4 -- Minor Cleanups

| Task | Files Modified | Risk |
|------|---------------|------|
| Window navigation loop | `lua/core/lib/actions.lua` | LOW |
| Keymap registry loop | `lua/core/registry/keymaps.lua` | LOW |
| Condition eval dedup | `lua/core/lib/loader.lua` | LOW |

### Stage 5 -- Keymap Unification

| Task | Files Modified | Risk |
|------|---------------|------|
| Add terminal/editor sections to registry | `lua/core/registry/keymaps.lua` | MEDIUM |
| Add actions to luxterm, easyops specs | `luxterm.lua`, `easyops.lua` | LOW |
| Generate `lazy.keys` from registry in loader | `lua/core/lib/loader.lua` | HIGH |
| Remove inline `lazy.keys` from specs | `luxterm.lua`, `easyops.lua` | MEDIUM |

### Validation

After each stage, launch LuxVim and verify:
- `:LuxDevStatus` reports correct debug plugin detection
- `:LuxVimErrors` shows no new errors
- All keymaps work (especially terminal toggle after Stage 5)
- Lazy-loading triggers correctly (open a file, check that LSP/treesitter load)

### Commit Strategy

One commit per stage. Stage 5 gets its own branch for testing before merge.

## Files Summary

### New Files (5)
- `lua/core/lib/data.lua`
- `lua/core/lib/platform.lua`
- `lua/core/lib/notify.lua`
- `lua/plugins/ui/config/nvim-tree.lua`
- `lua/plugins/ui/config/luxdash.lua`

### Modified Files (16)
- `lua/core/lib/bootstrap.lua`
- `lua/core/lib/loader.lua`
- `lua/core/lib/actions.lua`
- `lua/core/lib/keymap.lua`
- `lua/core/lib/autocmd.lua`
- `lua/core/registry/keymaps.lua`
- `lua/core/registry/conditions.lua`
- `lua/plugins/terminal/luxterm.lua`
- `lua/plugins/editor/easyops.lua`
- `lua/plugins/editor/quill.lua`
- `lua/plugins/editor/treesitter.lua`
- `lua/plugins/editor/easyenv.lua`
- `lua/plugins/lsp/lspconfig.lua`
- `lua/plugins/ui/nvim-tree.lua`
- `lua/plugins/ui/luxdash.lua`
- `lua/plugins/ui/colorschemes.lua`

### Lines Removed (estimated)
- ~8 redundant `debug_name` declarations
- ~5 lines trivial config wrapper (quill)
- ~267 lines moved to config files (nvim-tree 152 + luxdash 115)
- ~18 lines repetitive window registrations replaced with loops
- ~12 lines inline `lazy.keys` moved to registry
- ~15 lines duplicated path construction
- ~6 lines duplicated platform detection

### Lines Added (estimated)
- ~45 lines new utility modules (data + platform + notify)
- ~267 lines config files (moved, not new)
- ~20 lines loader enhancement for lazy.keys generation
