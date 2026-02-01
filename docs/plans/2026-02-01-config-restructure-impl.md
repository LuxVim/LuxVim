# Configuration Restructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure LuxVim from scattered config files to a layered architecture with centralized registries, declarative plugin specs, and comprehensive validation.

**Architecture:** Core infrastructure (`core/lib/`) processes declarative data (`core/registry/`, `plugins/*/`). Plugin specs are minimal tables auto-transformed to Lazy.nvim format. Keymaps/autocmds centralized for conflict detection and single-source-of-truth.

**Tech Stack:** Lua, Neovim API, Lazy.nvim plugin manager

---

## Phase 1: Core Infrastructure Foundation

Build the infrastructure layer that will process all declarative specs.

### Task 1.1: Create Directory Structure

**Files:**
- Create: `lua/core/init.lua`
- Create: `lua/core/registry/.gitkeep`
- Create: `lua/core/lib/.gitkeep`
- Create: `lua/plugins/lib/.gitkeep`
- Create: `lua/plugins/ui/.gitkeep`
- Create: `lua/plugins/editor/.gitkeep`
- Create: `lua/plugins/lsp/.gitkeep`
- Create: `lua/plugins/terminal/.gitkeep`
- Create: `lua/plugins/navigation/.gitkeep`
- Create: `lua/types/.gitkeep`

**Step 1: Create directory structure**

```bash
cd /Users/josstei/Development/lux-workspace/LuxVim/.worktrees/config-restructure
mkdir -p lua/core/registry lua/core/lib
mkdir -p lua/plugins/{lib,ui,editor,lsp,terminal,navigation}
mkdir -p lua/types
```

**Step 2: Create placeholder core/init.lua**

```lua
-- lua/core/init.lua
local M = {}

function M.setup()
  -- Will orchestrate all infrastructure loading
end

return M
```

**Step 3: Verify structure**

```bash
find lua/core lua/plugins lua/types -type d | sort
```

Expected output shows all directories created.

**Step 4: Commit**

```bash
git add lua/core lua/plugins lua/types
git commit -m "chore: create new directory structure for config restructure"
```

---

### Task 1.2: Build Schema Definition

**Files:**
- Create: `lua/core/lib/schema.lua`

**Step 1: Create schema module**

```lua
-- lua/core/lib/schema.lua
local M = {}

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
  build = { type = { "string", "table" }, desc = "Build configuration" },
  actions = { type = "table", desc = "Action overrides for keymap resolution" },
  dependencies = { type = "list", of = "string", desc = "References to other plugin specs" },
  cond = { type = { "string", "function" }, desc = "Load condition" },
  event = { type = { "string", "list" }, desc = "Lazy-load on event" },
  cmd = { type = { "string", "list" }, desc = "Lazy-load on command" },
  ft = { type = { "string", "list" }, desc = "Lazy-load on filetype" },
  enabled = { type = "boolean", default = true, desc = "Enable/disable plugin" },
  lazy = { type = "table", passthrough = true, desc = "Lazy.nvim native fields" },
}

M.keymap_entry = {
  action = { type = "string", required = true, desc = "Action to invoke" },
  desc = { type = "string", desc = "Description for which-key" },
  mode = { type = { "string", "list" }, default = "n", desc = "Vim mode(s)" },
}

M.autocmd_entry = {
  action = { type = "string", required = true, desc = "Action to invoke" },
  pattern = { type = { "string", "list" }, default = "*", desc = "File pattern" },
  once = { type = "boolean", default = false, desc = "Run only once" },
}

return M
```

**Step 2: Verify module loads**

```bash
nvim --headless -c "lua print(vim.inspect(require('core.lib.schema').plugin_spec.source))" -c "qa"
```

Expected: `{ desc = "GitHub repo (author/name)", required = true, type = "string" }`

**Step 3: Commit**

```bash
git add lua/core/lib/schema.lua
git commit -m "feat(core): add declarative schema definitions"
```

---

### Task 1.3: Build Validation Module

**Files:**
- Create: `lua/core/lib/validate.lua`

**Step 1: Create validation module**

```lua
-- lua/core/lib/validate.lua
local schema = require("core.lib.schema")

local M = {}

M.errors = {
  CRITICAL = "critical",
  WARNING = "warning",
}

local function type_matches(value, expected_type)
  if type(expected_type) == "string" then
    if expected_type == "list" then
      return type(value) == "table" and vim.islist(value)
    end
    return type(value) == expected_type
  elseif type(expected_type) == "table" then
    if expected_type.type then
      return type_matches(value, expected_type.type)
    end
    for _, t in ipairs(expected_type) do
      if type_matches(value, t) then
        return true
      end
    end
    return false
  end
  return false
end

function M.validate_against(value, schema_def, path)
  local errors = {}
  local warnings = {}
  path = path or "spec"

  if type(value) ~= "table" then
    table.insert(errors, {
      level = M.errors.CRITICAL,
      path = path,
      message = "must be a table, got " .. type(value),
    })
    return errors, warnings
  end

  for field, rules in pairs(schema_def) do
    local field_value = value[field]
    local field_path = path .. "." .. field

    if rules.required and field_value == nil then
      table.insert(errors, {
        level = M.errors.CRITICAL,
        path = field_path,
        message = "missing required field",
      })
    elseif field_value ~= nil and rules.type then
      if not type_matches(field_value, rules.type) then
        table.insert(errors, {
          level = M.errors.CRITICAL,
          path = field_path,
          message = "expected " .. vim.inspect(rules.type) .. ", got " .. type(field_value),
        })
      end
    end
  end

  for field, _ in pairs(value) do
    if not schema_def[field] then
      local known_fields = vim.tbl_keys(schema_def)
      table.sort(known_fields)
      table.insert(warnings, {
        level = M.errors.WARNING,
        path = path .. "." .. field,
        message = "unknown field (known: " .. table.concat(known_fields, ", ") .. ")",
      })
    end
  end

  return errors, warnings
end

function M.validate_plugin_spec(spec, file_path)
  return M.validate_against(spec, schema.plugin_spec, file_path or "plugin")
end

function M.format_errors(errors, warnings)
  local lines = {}
  for _, err in ipairs(errors) do
    table.insert(lines, string.format("[%s] %s: %s", err.level:upper(), err.path, err.message))
  end
  for _, warn in ipairs(warnings) do
    table.insert(lines, string.format("[%s] %s: %s", warn.level:upper(), warn.path, warn.message))
  end
  return table.concat(lines, "\n")
end

return M
```

**Step 2: Test validation**

```bash
nvim --headless -c "lua local v = require('core.lib.validate'); local e,w = v.validate_plugin_spec({source='a/b'}); print('errors:', #e, 'warnings:', #w)" -c "qa"
```

Expected: `errors: 0 warnings: 0`

**Step 3: Test validation catches missing source**

```bash
nvim --headless -c "lua local v = require('core.lib.validate'); local e,w = v.validate_plugin_spec({}); print('errors:', #e)" -c "qa"
```

Expected: `errors: 1`

**Step 4: Commit**

```bash
git add lua/core/lib/validate.lua
git commit -m "feat(core): add spec validation with tiered strictness"
```

---

### Task 1.4: Build Debug Detection Module

**Files:**
- Create: `lua/core/lib/debug.lua`

**Step 1: Create debug module**

```lua
-- lua/core/lib/debug.lua
local M = {}

local _luxvim_root = nil

function M.get_luxvim_root()
  if _luxvim_root then
    return _luxvim_root
  end

  local config_path = vim.fn.stdpath("config")
  if config_path and vim.fn.isdirectory(config_path) == 1 then
    _luxvim_root = config_path
    return _luxvim_root
  end

  local init_path = vim.fn.findfile("init.lua", ".;")
  if init_path ~= "" then
    _luxvim_root = vim.fn.fnamemodify(init_path, ":p:h")
    return _luxvim_root
  end

  _luxvim_root = vim.fn.getcwd()
  return _luxvim_root
end

function M.extract_plugin_name(source)
  return source:match("([^/]+)$")
end

function M.get_debug_path(plugin_name)
  return M.get_luxvim_root() .. "/debug/" .. plugin_name
end

function M.has_debug_plugin(plugin_name)
  local debug_path = M.get_debug_path(plugin_name)
  local stat = vim.uv.fs_stat(debug_path)
  if not stat or stat.type ~= "directory" then
    return false
  end

  local plugin_dir = debug_path .. "/plugin"
  local lua_dir = debug_path .. "/lua"
  local plugin_stat = vim.uv.fs_stat(plugin_dir)
  local lua_stat = vim.uv.fs_stat(lua_dir)

  return (plugin_stat and plugin_stat.type == "directory")
      or (lua_stat and lua_stat.type == "directory")
end

function M.resolve_debug_name(spec)
  if spec.debug_name then
    return spec.debug_name
  end
  return M.extract_plugin_name(spec.source)
end

function M.list_debug_plugins()
  local debug_dir = M.get_luxvim_root() .. "/debug"
  local handle = vim.uv.fs_scandir(debug_dir)
  if not handle then
    return {}
  end

  local plugins = {}
  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if (type == "directory" or type == "link") and M.has_debug_plugin(name) then
      table.insert(plugins, name)
    end
  end
  return plugins
end

return M
```

**Step 2: Test debug detection**

```bash
nvim --headless -c "lua local d = require('core.lib.debug'); print('root:', d.get_luxvim_root()); print('extract:', d.extract_plugin_name('folke/lazy.nvim'))" -c "qa"
```

Expected: Shows root path and `lazy.nvim`

**Step 3: Commit**

```bash
git add lua/core/lib/debug.lua
git commit -m "feat(core): add debug plugin detection with convention + override"
```

---

### Task 1.5: Build Conditions Registry

**Files:**
- Create: `lua/core/registry/conditions.lua`

**Step 1: Create conditions registry**

```lua
-- lua/core/registry/conditions.lua
return {
  is_mac = function()
    return vim.fn.has("mac") == 1
  end,

  is_linux = function()
    return vim.fn.has("linux") == 1
  end,

  is_windows = function()
    return vim.fn.has("win32") == 1
  end,

  has_git = function()
    return vim.fn.executable("git") == 1
  end,

  has_node = function()
    return vim.fn.executable("node") == 1
  end,

  has_npm = function()
    return vim.fn.executable("npm") == 1
  end,

  has_cargo = function()
    return vim.fn.executable("cargo") == 1
  end,

  has_make = function()
    return vim.fn.executable("make") == 1
  end,

  has_go = function()
    return vim.fn.executable("go") == 1
  end,

  is_gui = function()
    return vim.fn.has("gui_running") == 1
  end,

  is_vscode = function()
    return vim.g.vscode ~= nil
  end,
}
```

**Step 2: Test conditions**

```bash
nvim --headless -c "lua local c = require('core.registry.conditions'); print('has_git:', c.has_git())" -c "qa"
```

Expected: `has_git: true` (assuming git is installed)

**Step 3: Commit**

```bash
git add lua/core/registry/conditions.lua
git commit -m "feat(registry): add reusable load conditions"
```

---

### Task 1.6: Build Actions Resolution Module

**Files:**
- Create: `lua/core/lib/actions.lua`

**Step 1: Create actions module**

```lua
-- lua/core/lib/actions.lua
local M = {}

M._registry = {}
M._cache = {}

function M.register(namespace, name, fn)
  M._registry[namespace] = M._registry[namespace] or {}
  M._registry[namespace][name] = fn
  M._cache[namespace .. "." .. name] = fn
end

function M.register_from_spec(spec)
  if not spec.actions then
    return
  end

  local plugin_name = spec.debug_name or spec.source:match("([^/]+)$")
  for action_name, fn in pairs(spec.actions) do
    M.register(plugin_name, action_name, fn)
  end
end

function M.resolve(action_string)
  if M._cache[action_string] then
    return M._cache[action_string]
  end

  local namespace, method = action_string:match("^([^.]+)%.(.+)$")
  if not namespace or not method then
    return nil, "invalid action format: " .. action_string
  end

  if M._registry[namespace] and M._registry[namespace][method] then
    local fn = M._registry[namespace][method]
    M._cache[action_string] = fn
    return fn
  end

  local ok, module = pcall(require, namespace)
  if ok and type(module) == "table" and type(module[method]) == "function" then
    M._cache[action_string] = function()
      module[method]()
    end
    return M._cache[action_string]
  end

  return nil, "could not resolve action: " .. action_string
end

function M.invoke(action_string)
  local fn, err = M.resolve(action_string)
  if not fn then
    vim.notify("[LuxVim] " .. err, vim.log.levels.WARN)
    return false
  end

  local ok, result = pcall(fn)
  if not ok then
    vim.notify("[LuxVim] Action error: " .. tostring(result), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.register_core_actions()
  M.register("core", "save", function()
    vim.cmd("write")
  end)

  M.register("core", "quit", function()
    vim.cmd("quit")
  end)

  M.register("core", "force_quit", function()
    vim.cmd("quit!")
  end)

  M.register("core", "quit_all", function()
    vim.cmd("quitall!")
  end)

  M.register("core", "save_quit", function()
    vim.cmd("wq")
  end)
end

return M
```

**Step 2: Test action resolution**

```bash
nvim --headless -c "lua local a = require('core.lib.actions'); a.register_core_actions(); local fn = a.resolve('core.save'); print('resolved:', fn ~= nil)" -c "qa"
```

Expected: `resolved: true`

**Step 3: Commit**

```bash
git add lua/core/lib/actions.lua
git commit -m "feat(core): add action resolution with convention + override"
```

---

## Phase 2: Plugin Loading Infrastructure

Build the plugin discovery and transformation system.

### Task 2.1: Build Plugin Loader Module

**Files:**
- Create: `lua/core/lib/loader.lua`

**Step 1: Create loader module**

```lua
-- lua/core/lib/loader.lua
local debug_mod = require("core.lib.debug")
local validate = require("core.lib.validate")
local conditions = require("core.registry.conditions")

local M = {}

M._specs = {}
M._specs_by_name = {}
M._errors = {}
M._warnings = {}

function M.get_plugin_dirs()
  local root = debug_mod.get_luxvim_root()
  local plugins_dir = root .. "/lua/plugins"
  local dirs = {}

  local handle = vim.uv.fs_scandir(plugins_dir)
  if not handle then
    return dirs
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if type == "directory" then
      table.insert(dirs, { name = name, path = plugins_dir .. "/" .. name })
    end
  end

  return dirs
end

function M.load_category_defaults(category_path)
  local defaults_path = category_path .. "/_defaults.lua"
  local stat = vim.uv.fs_stat(defaults_path)
  if not stat then
    return {}
  end

  local ok, defaults = pcall(dofile, defaults_path)
  if ok then
    return defaults
  end
  return {}
end

function M.load_plugin_specs(category_path, category_name, defaults)
  local specs = {}
  local handle = vim.uv.fs_scandir(category_path)
  if not handle then
    return specs
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if type == "file" and name:match("%.lua$") and name ~= "_defaults.lua" then
      local file_path = category_path .. "/" .. name
      local ok, spec = pcall(dofile, file_path)

      if not ok then
        table.insert(M._errors, {
          level = "critical",
          file = file_path,
          message = "failed to load: " .. tostring(spec),
        })
      elseif type(spec) ~= "table" then
        table.insert(M._errors, {
          level = "critical",
          file = file_path,
          message = "spec must be a table, got " .. type(spec),
        })
      else
        spec._file = file_path
        spec._category = category_name

        local errors, warnings = validate.validate_plugin_spec(spec, file_path)
        for _, e in ipairs(errors) do
          table.insert(M._errors, { level = e.level, file = file_path, message = e.message })
        end
        for _, w in ipairs(warnings) do
          table.insert(M._warnings, { level = w.level, file = file_path, message = w.message })
        end

        if #errors == 0 then
          spec = vim.tbl_deep_extend("keep", spec, defaults)
          table.insert(specs, spec)
        end
      end
    end
  end

  return specs
end

function M.evaluate_condition(cond)
  if cond == nil then
    return true
  end

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

function M.transform_to_lazy(spec)
  if not M.evaluate_condition(spec.cond) then
    return nil
  end

  if spec.enabled == false then
    return nil
  end

  local debug_name = debug_mod.resolve_debug_name(spec)
  local use_debug = debug_mod.has_debug_plugin(debug_name)

  local lazy_spec = {}

  if use_debug then
    lazy_spec.dir = debug_mod.get_debug_path(debug_name)
    lazy_spec.name = debug_name .. "-debug"
  else
    lazy_spec[1] = spec.source
  end

  if spec.opts then
    lazy_spec.opts = spec.opts
  end

  if spec.config then
    lazy_spec.config = spec.config
  elseif spec.opts and not spec.config then
    lazy_spec.config = true
  end

  if spec.dependencies then
    lazy_spec.dependencies = M.resolve_dependencies(spec.dependencies)
  end

  if spec.event then
    lazy_spec.event = spec.event
  end
  if spec.cmd then
    lazy_spec.cmd = spec.cmd
  end
  if spec.ft then
    lazy_spec.ft = spec.ft
  end

  if spec.build then
    lazy_spec.build = M.transform_build(spec.build)
  end

  if spec.lazy then
    lazy_spec = vim.tbl_deep_extend("force", lazy_spec, spec.lazy)
  end

  M._specs_by_name[debug_name] = spec

  return lazy_spec
end

function M.resolve_dependencies(deps)
  local resolved = {}
  for _, dep in ipairs(deps) do
    if type(dep) == "string" then
      if M._specs_by_name[dep] then
        local dep_spec = M._specs_by_name[dep]
        local lazy_dep = M.transform_to_lazy(dep_spec)
        if lazy_dep then
          table.insert(resolved, lazy_dep)
        end
      else
        table.insert(resolved, dep)
      end
    elseif type(dep) == "table" then
      table.insert(resolved, dep)
    end
  end
  return resolved
end

function M.transform_build(build)
  if type(build) == "string" then
    return build
  end

  if type(build) == "table" then
    local cmd = build.cmd
    if build.platforms then
      local platform = vim.fn.has("mac") == 1 and "mac"
          or vim.fn.has("linux") == 1 and "linux"
          or vim.fn.has("win32") == 1 and "windows"
      if build.platforms[platform] then
        cmd = build.platforms[platform]
      end
    end

    if build.requires then
      for _, exe in ipairs(build.requires) do
        if vim.fn.executable(exe) ~= 1 then
          if build.on_fail == "error" then
            error("Build requires " .. exe .. " but it's not available")
          elseif build.on_fail ~= "ignore" then
            vim.notify("[LuxVim] Build skipped: missing " .. exe, vim.log.levels.WARN)
          end
          return nil
        end
      end
    end

    if build.cond then
      if not M.evaluate_condition(build.cond) then
        return nil
      end
    end

    return cmd
  end

  return nil
end

function M.discover_all()
  M._specs = {}
  M._specs_by_name = {}
  M._errors = {}
  M._warnings = {}

  local dirs = M.get_plugin_dirs()

  for _, dir in ipairs(dirs) do
    local defaults = M.load_category_defaults(dir.path)
    local specs = M.load_plugin_specs(dir.path, dir.name, defaults)

    for _, spec in ipairs(specs) do
      table.insert(M._specs, spec)
      local name = debug_mod.resolve_debug_name(spec)
      M._specs_by_name[name] = spec
    end
  end

  return M._specs
end

function M.get_lazy_specs()
  local lazy_specs = {}

  for _, spec in ipairs(M._specs) do
    local lazy_spec = M.transform_to_lazy(spec)
    if lazy_spec then
      table.insert(lazy_specs, lazy_spec)
    end
  end

  return lazy_specs
end

function M.report_errors()
  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, M._errors)

  if #critical > 0 then
    local msg = "[LuxVim] FATAL: Cannot start\n"
    for _, e in ipairs(critical) do
      msg = msg .. "  " .. e.file .. ": " .. e.message .. "\n"
    end
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
    return false
  end

  local non_critical = vim.tbl_filter(function(e)
    return e.level ~= "critical"
  end, M._errors)

  for _, e in ipairs(non_critical) do
    vim.notify("[LuxVim] Plugin skipped: " .. e.file .. "\n  " .. e.message, vim.log.levels.WARN)
  end

  if #M._warnings > 0 then
    vim.defer_fn(function()
      vim.notify("[LuxVim] Started with " .. #M._warnings .. " warnings. Run :LuxVimErrors for details.", vim.log.levels.INFO)
    end, 100)
  end

  return true
end

function M.get_errors()
  return M._errors
end

function M.get_warnings()
  return M._warnings
end

return M
```

**Step 2: Verify module loads**

```bash
nvim --headless -c "lua print('loader:', require('core.lib.loader') ~= nil)" -c "qa"
```

Expected: `loader: true`

**Step 3: Commit**

```bash
git add lua/core/lib/loader.lua
git commit -m "feat(core): add plugin loader with discovery and transformation"
```

---

### Task 2.2: Build Bootstrap Module

**Files:**
- Create: `lua/core/lib/bootstrap.lua`

**Step 1: Create bootstrap module**

```lua
-- lua/core/lib/bootstrap.lua
local debug_mod = require("core.lib.debug")

local M = {}

function M.get_lazy_path()
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share/LuxVim")
  return data_dir .. "/data/lazy/lazy.nvim"
end

function M.get_lazy_root()
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share/LuxVim")
  return data_dir .. "/data/lazy"
end

function M.get_lockfile_path()
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share/LuxVim")
  return data_dir .. "/lazy-lock.json"
end

function M.ensure_lazy()
  local lazypath = M.get_lazy_path()

  if not vim.uv.fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "--branch=stable",
      lazyrepo,
      lazypath,
    })

    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({
        { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
        { out, "WarningMsg" },
        { "\nPress any key to exit..." },
      }, true, {})
      vim.fn.getchar()
      os.exit(1)
    end
  end

  vim.opt.rtp:prepend(lazypath)
end

function M.setup_lazy(specs)
  M.ensure_lazy()

  require("lazy").setup({
    spec = specs,
    defaults = {
      lazy = false,
      version = false,
    },
    install = { colorscheme = { "lux", "habamax" } },
    checker = { enabled = false },
    performance = {
      cache = { enabled = true },
      reset_packpath = true,
      rtp = {
        reset = true,
        disabled_plugins = {
          "gzip",
          "matchit",
          "matchparen",
          "netrwPlugin",
          "tarPlugin",
          "tohtml",
          "tutor",
          "zipPlugin",
        },
      },
    },
    root = M.get_lazy_root(),
    lockfile = M.get_lockfile_path(),
  })
end

return M
```

**Step 2: Verify module loads**

```bash
nvim --headless -c "lua print('bootstrap:', require('core.lib.bootstrap') ~= nil)" -c "qa"
```

Expected: `bootstrap: true`

**Step 3: Commit**

```bash
git add lua/core/lib/bootstrap.lua
git commit -m "feat(core): add Lazy.nvim bootstrap module"
```

---

### Task 2.3: Build Keymap Registration Module

**Files:**
- Create: `lua/core/lib/keymap.lua`
- Create: `lua/core/registry/keymaps.lua`

**Step 1: Create keymap module**

```lua
-- lua/core/lib/keymap.lua
local actions = require("core.lib.actions")

local M = {}

function M.register_all(registry)
  for section_name, section in pairs(registry) do
    for lhs, mapping in pairs(section) do
      M.register_one(lhs, mapping, section_name)
    end
  end
end

function M.register_one(lhs, mapping, section)
  local mode = mapping.mode or "n"
  local desc = mapping.desc or mapping.action

  local rhs = function()
    actions.invoke(mapping.action)
  end

  local opts = {
    desc = desc,
    silent = true,
    noremap = true,
  }

  if type(mode) == "table" then
    for _, m in ipairs(mode) do
      vim.keymap.set(m, lhs, rhs, opts)
    end
  else
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

function M.setup()
  local ok, registry = pcall(require, "core.registry.keymaps")
  if not ok then
    vim.notify("[LuxVim] Failed to load keymap registry: " .. tostring(registry), vim.log.levels.WARN)
    return
  end

  actions.register_core_actions()
  M.register_all(registry)
end

return M
```

**Step 2: Create initial keymaps registry**

```lua
-- lua/core/registry/keymaps.lua
return {
  editor = {
    ["<leader>fs"] = { action = "core.save", desc = "Save file" },
    ["<leader>fq"] = { action = "core.quit", desc = "Quit" },
    ["<leader>FQ"] = { action = "core.force_quit", desc = "Force quit" },
    ["<leader>bye"] = { action = "core.quit_all", desc = "Quit all" },
  },

  navigation = {
    ["<leader>wv"] = { action = "core.vsplit", desc = "Vertical split" },
    ["<leader>wh"] = { action = "core.hsplit", desc = "Horizontal split" },
    ["<leader>1"] = { action = "core.win1", desc = "Go to window 1" },
    ["<leader>2"] = { action = "core.win2", desc = "Go to window 2" },
    ["<leader>3"] = { action = "core.win3", desc = "Go to window 3" },
    ["<leader>4"] = { action = "core.win4", desc = "Go to window 4" },
    ["<leader>5"] = { action = "core.win5", desc = "Go to window 5" },
    ["<leader>6"] = { action = "core.win6", desc = "Go to window 6" },
  },

  ui = {
    ["<leader>e"] = { action = "nvim-tree.toggle", desc = "File explorer" },
  },
}
```

**Step 3: Update actions to include navigation**

Add to `lua/core/lib/actions.lua` in the `register_core_actions` function:

```lua
  M.register("core", "vsplit", function()
    vim.cmd("rightbelow vs new")
  end)

  M.register("core", "hsplit", function()
    vim.cmd("rightbelow split new")
  end)

  M.register("core", "win1", function()
    vim.cmd("1wincmd w")
  end)

  M.register("core", "win2", function()
    vim.cmd("2wincmd w")
  end)

  M.register("core", "win3", function()
    vim.cmd("3wincmd w")
  end)

  M.register("core", "win4", function()
    vim.cmd("4wincmd w")
  end)

  M.register("core", "win5", function()
    vim.cmd("5wincmd w")
  end)

  M.register("core", "win6", function()
    vim.cmd("6wincmd w")
  end)
```

**Step 4: Commit**

```bash
git add lua/core/lib/keymap.lua lua/core/registry/keymaps.lua lua/core/lib/actions.lua
git commit -m "feat(core): add centralized keymap registry and registration"
```

---

### Task 2.4: Build Autocmd Registration Module

**Files:**
- Create: `lua/core/lib/autocmd.lua`
- Create: `lua/core/registry/autocmds.lua`
- Create: `lua/core/registry/filetypes.lua`

**Step 1: Create autocmd module**

```lua
-- lua/core/lib/autocmd.lua
local actions = require("core.lib.actions")

local M = {}

local augroup = vim.api.nvim_create_augroup("LuxVimCore", { clear = true })

function M.register_autocmds(registry)
  for event, config in pairs(registry) do
    local pattern = config.pattern or "*"
    local once = config.once or false

    vim.api.nvim_create_autocmd(event, {
      group = augroup,
      pattern = pattern,
      once = once,
      callback = function()
        actions.invoke(config.action)
      end,
    })
  end
end

function M.register_filetypes(filetypes)
  for ft, settings in pairs(filetypes) do
    vim.api.nvim_create_autocmd("FileType", {
      group = augroup,
      pattern = ft,
      callback = function()
        for option, value in pairs(settings) do
          vim.opt_local[option] = value
        end
      end,
    })
  end
end

function M.setup()
  local ok_autocmds, autocmds = pcall(require, "core.registry.autocmds")
  if ok_autocmds then
    M.register_autocmds(autocmds)
  end

  local ok_filetypes, filetypes = pcall(require, "core.registry.filetypes")
  if ok_filetypes then
    M.register_filetypes(filetypes)
  end
end

return M
```

**Step 2: Create autocmds registry**

```lua
-- lua/core/registry/autocmds.lua
return {
  -- Global autocmds only
  -- Plugin-specific autocmds stay with plugins
}
```

**Step 3: Create filetypes registry**

```lua
-- lua/core/registry/filetypes.lua
return {
  lua = {
    tabstop = 2,
    shiftwidth = 2,
    expandtab = true,
  },

  python = {
    tabstop = 4,
    shiftwidth = 4,
    expandtab = true,
    colorcolumn = "88",
  },

  markdown = {
    wrap = true,
    spell = true,
    conceallevel = 2,
  },

  json = {
    tabstop = 2,
    shiftwidth = 2,
    expandtab = true,
  },

  yaml = {
    tabstop = 2,
    shiftwidth = 2,
    expandtab = true,
  },

  javascript = {
    tabstop = 2,
    shiftwidth = 2,
    expandtab = true,
  },

  typescript = {
    tabstop = 2,
    shiftwidth = 2,
    expandtab = true,
  },
}
```

**Step 4: Commit**

```bash
git add lua/core/lib/autocmd.lua lua/core/registry/autocmds.lua lua/core/registry/filetypes.lua
git commit -m "feat(core): add autocmd and filetype registries"
```

---

### Task 2.5: Build Core Orchestrator

**Files:**
- Modify: `lua/core/init.lua`

**Step 1: Update core orchestrator**

```lua
-- lua/core/init.lua
local M = {}

function M.setup()
  local bootstrap = require("core.lib.bootstrap")
  local loader = require("core.lib.loader")
  local keymap = require("core.lib.keymap")
  local autocmd = require("core.lib.autocmd")
  local actions = require("core.lib.actions")

  loader.discover_all()

  if not loader.report_errors() then
    return false
  end

  local lazy_specs = loader.get_lazy_specs()
  bootstrap.setup_lazy(lazy_specs)

  actions.register_core_actions()

  for _, spec in ipairs(loader._specs) do
    actions.register_from_spec(spec)
  end

  keymap.setup()
  autocmd.setup()

  M._create_commands()

  return true
end

function M._create_commands()
  vim.api.nvim_create_user_command("LuxVimErrors", function()
    local loader = require("core.lib.loader")
    local errors = loader.get_errors()
    local warnings = loader.get_warnings()

    if #errors == 0 and #warnings == 0 then
      print("No errors or warnings")
      return
    end

    print("=== LuxVim Errors ===")
    for _, e in ipairs(errors) do
      print(string.format("[%s] %s: %s", e.level:upper(), e.file, e.message))
    end

    print("\n=== LuxVim Warnings ===")
    for _, w in ipairs(warnings) do
      print(string.format("[%s] %s: %s", w.level:upper(), w.file, w.message))
    end
  end, { desc = "Show LuxVim errors and warnings" })

  vim.api.nvim_create_user_command("LuxDevStatus", function()
    local debug_mod = require("core.lib.debug")
    local plugins = debug_mod.list_debug_plugins()

    print("🔧 LuxVim Development Status")
    print("============================")

    if #plugins == 0 then
      print("No debug plugins found in /debug directory")
    else
      print("Active debug plugins:")
      for _, plugin in ipairs(plugins) do
        local path = debug_mod.get_debug_path(plugin)
        print("  • " .. plugin .. " -> " .. path)
      end
    end
  end, { desc = "Show LuxVim development status" })
end

return M
```

**Step 2: Commit**

```bash
git add lua/core/init.lua
git commit -m "feat(core): complete orchestrator with full initialization flow"
```

---

## Phase 3: Migrate Plugin Specs

Convert existing plugin configurations to new declarative format.

### Task 3.1: Create Category Defaults

**Files:**
- Create: `lua/plugins/lib/_defaults.lua`
- Create: `lua/plugins/ui/_defaults.lua`
- Create: `lua/plugins/editor/_defaults.lua`
- Create: `lua/plugins/lsp/_defaults.lua`
- Create: `lua/plugins/terminal/_defaults.lua`
- Create: `lua/plugins/navigation/_defaults.lua`

**Step 1: Create all category defaults**

```lua
-- lua/plugins/lib/_defaults.lua
return {
  lazy = true,
}
```

```lua
-- lua/plugins/ui/_defaults.lua
return {
  event = "VimEnter",
}
```

```lua
-- lua/plugins/editor/_defaults.lua
return {
  event = { "BufReadPost", "BufNewFile" },
}
```

```lua
-- lua/plugins/lsp/_defaults.lua
return {
  event = { "BufReadPre", "BufNewFile" },
}
```

```lua
-- lua/plugins/terminal/_defaults.lua
return {
  cmd = true,
}
```

```lua
-- lua/plugins/navigation/_defaults.lua
return {
  event = "VeryLazy",
}
```

**Step 2: Commit**

```bash
git add lua/plugins/*/_defaults.lua
git commit -m "feat(plugins): add category defaults for lazy loading"
```

---

### Task 3.2: Migrate UI Plugins

**Files:**
- Create: `lua/plugins/ui/nvim-tree.lua`
- Create: `lua/plugins/ui/luxdash.lua`
- Create: `lua/plugins/ui/luxline.lua`
- Create: `lua/plugins/ui/luxmotion.lua`
- Create: `lua/plugins/ui/colorschemes.lua`

**Step 1: Create nvim-tree spec**

```lua
-- lua/plugins/ui/nvim-tree.lua
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
    hijack_netrw = true,
    sync_root_with_cwd = true,
    respect_buf_cwd = true,
    update_focused_file = {
      enable = true,
      update_root = false,
    },
    view = {
      width = 30,
      side = "left",
    },
    renderer = {
      group_empty = true,
      highlight_git = false,
      indent_markers = { enable = true },
      icons = {
        show = {
          git = false,
          modified = false,
        },
      },
    },
    filters = {
      dotfiles = false,
      custom = { "^.git$", "^node_modules$", "^.cache$" },
    },
    git = { enable = false },
    filesystem_watchers = {
      enable = true,
      debounce_delay = 50,
      ignore_dirs = { "node_modules", ".git", ".cache", "target", "build", "dist" },
    },
    diagnostics = { enable = false },
    modified = { enable = false },
  },
}
```

**Step 2: Create luxdash spec**

```lua
-- lua/plugins/ui/luxdash.lua
return {
  source = "LuxVim/nvim-luxdash",
  debug_name = "nvim-luxdash",
  event = "VimEnter",
  opts = {
    name = "LuxVim",
    logo_color = {
      row_gradient = {
        start = "#ff7801",
        bottom = "#db2dee",
      },
    },
    performance = {
      debounce_resize = 100,
      lazy_render = true,
      cache_logo = true,
    },
    sections = {
      main = {
        type = "logo",
        config = {
          show_title = false,
          show_underline = false,
          alignment = { horizontal = "center", vertical = "center" },
        },
      },
      bottom = {
        {
          id = "actions",
          type = "menu",
          title = "⚡ Actions",
          config = {
            show_title = true,
            show_underline = true,
            menu_items = { "newfile", "fzf", "closelux" },
            alignment = { horizontal = "center", vertical = "top" },
          },
        },
        {
          id = "recent",
          type = "recent_files",
          title = "📁 Recent Files",
          config = {
            show_title = true,
            show_underline = true,
            max_files = 8,
            alignment = { horizontal = "center", vertical = "top" },
          },
        },
        {
          id = "git",
          type = "git_status",
          title = "🌿 Git Status",
          config = {
            show_title = true,
            show_underline = true,
            alignment = { horizontal = "center", vertical = "top" },
          },
        },
      },
    },
    layout_config = {
      main_height_ratio = 0.8,
      bottom_sections_equal_width = true,
      section_spacing = 4,
    },
  },
}
```

**Step 3: Create remaining UI plugin specs**

```lua
-- lua/plugins/ui/luxline.lua
return {
  source = "LuxVim/nvim-luxline",
  debug_name = "nvim-luxline",
  event = "VeryLazy",
  opts = {},
}
```

```lua
-- lua/plugins/ui/luxmotion.lua
return {
  source = "LuxVim/nvim-luxmotion",
  debug_name = "nvim-luxmotion",
  event = "VeryLazy",
  opts = {},
}
```

```lua
-- lua/plugins/ui/colorschemes.lua
return {
  source = "LuxVim/lux.nvim",
  debug_name = "lux.nvim",
  lazy = {
    priority = 1000,
  },
  opts = {
    variant = "vesper",
  },
  config = function(_, opts)
    require("lux").setup(opts)
    vim.cmd.colorscheme("lux-vesper")
  end,
}
```

**Step 4: Commit**

```bash
git add lua/plugins/ui/*.lua
git commit -m "feat(plugins): migrate UI plugins to new spec format"
```

---

### Task 3.3: Migrate Editor Plugins

**Files:**
- Create: `lua/plugins/editor/treesitter.lua`
- Create: `lua/plugins/editor/easycomment.lua`
- Create: `lua/plugins/editor/fzf.lua`
- Create: `lua/plugins/editor/easyops.lua`

**Step 1: Create treesitter spec**

```lua
-- lua/plugins/editor/treesitter.lua
return {
  source = "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  lazy = {
    priority = 900,
    lazy = false,
  },
  config = function()
    local data_dir = vim.env.XDG_DATA_HOME or vim.fn.stdpath("data")
    local parser_install_dir = data_dir .. "/data/site"

    require("nvim-treesitter.config").setup({
      install_dir = parser_install_dir,
    })

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
```

**Step 2: Create remaining editor specs**

```lua
-- lua/plugins/editor/easycomment.lua
return {
  source = "LuxVim/vim-easycomment",
  debug_name = "vim-easycomment",
  opts = {},
}
```

```lua
-- lua/plugins/editor/fzf.lua
return {
  source = "junegunn/fzf.vim",
  dependencies = { "fzf" },
  cmd = { "Files", "GFiles", "Buffers", "Rg", "Lines" },
  opts = {},
}
```

```lua
-- lua/plugins/editor/easyops.lua
return {
  source = "LuxVim/vim-easyops",
  debug_name = "vim-easyops",
  cmd = { "EasyOps" },
  opts = {},
}
```

**Step 3: Commit**

```bash
git add lua/plugins/editor/*.lua
git commit -m "feat(plugins): migrate editor plugins to new spec format"
```

---

### Task 3.4: Migrate LSP Plugins

**Files:**
- Create: `lua/plugins/lsp/lspconfig.lua`
- Create: `lua/plugins/lsp/luxlsp.lua`

**Step 1: Create lspconfig spec**

```lua
-- lua/plugins/lsp/lspconfig.lua
return {
  source = "neovim/nvim-lspconfig",
  debug_name = "nvim-lspconfig",
  dependencies = { "plenary" },
  config = function()
    local ok, luxlsp = pcall(require, "luxlsp")
    if ok then
      luxlsp.setup({
        install_root = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "data", "luxlsp"),
      })
    end
  end,
}
```

**Step 2: Create luxlsp spec**

```lua
-- lua/plugins/lsp/luxlsp.lua
return {
  source = "LuxVim/nvim-luxlsp",
  debug_name = "nvim-luxlsp",
  cmd = { "LuxLsp", "LuxLspInstall", "LuxLspUninstall", "LuxLspList" },
  opts = {},
}
```

**Step 3: Commit**

```bash
git add lua/plugins/lsp/*.lua
git commit -m "feat(plugins): migrate LSP plugins to new spec format"
```

---

### Task 3.5: Migrate Terminal and Library Plugins

**Files:**
- Create: `lua/plugins/terminal/luxterm.lua`
- Create: `lua/plugins/lib/plenary.lua`
- Create: `lua/plugins/lib/nvim-web-devicons.lua`
- Create: `lua/plugins/lib/fzf.lua`

**Step 1: Create terminal plugin spec**

```lua
-- lua/plugins/terminal/luxterm.lua
return {
  source = "LuxVim/nvim-luxterm",
  debug_name = "nvim-luxterm",
  cmd = { "LuxtermToggle", "LuxtermNew", "LuxtermNext", "LuxtermPrev" },
  keys = {
    { "<C-/>", "<cmd>LuxtermToggle<cr>", desc = "Toggle terminal" },
    { "<C-_>", "<cmd>LuxtermToggle<cr>", desc = "Toggle terminal" },
    { "<C-`>", "<cmd>LuxtermToggle<cr>", desc = "Toggle terminal" },
  },
  opts = {},
}
```

**Step 2: Create library plugin specs**

```lua
-- lua/plugins/lib/plenary.lua
return {
  source = "nvim-lua/plenary.nvim",
}
```

```lua
-- lua/plugins/lib/nvim-web-devicons.lua
return {
  source = "nvim-tree/nvim-web-devicons",
}
```

```lua
-- lua/plugins/lib/fzf.lua
return {
  source = "junegunn/fzf",
  build = {
    cmd = "./install --bin",
    requires = { "git" },
  },
}
```

**Step 3: Commit**

```bash
git add lua/plugins/terminal/*.lua lua/plugins/lib/*.lua
git commit -m "feat(plugins): migrate terminal and library plugins"
```

---

## Phase 4: Update Entry Point and Remove Old Structure

### Task 4.1: Update init.lua

**Files:**
- Modify: `init.lua`

**Step 1: Update entry point**

```lua
-- init.lua
-- **********************************************************
-- ********************* LUXVIM *****************************
-- **********************************************************

local current_dir = vim.fn.expand("<sfile>:p:h")
vim.opt.runtimepath:prepend(current_dir)

package.path = current_dir .. "/lua/?.lua;" .. current_dir .. "/lua/?/init.lua;" .. package.path

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

local core = require("core")
core.setup()
```

**Step 2: Test that LuxVim loads**

```bash
cd /Users/josstei/Development/lux-workspace/LuxVim/.worktrees/config-restructure
NVIM_APPNAME="LuxVim-test" nvim --headless -c "echo 'LuxVim loads'" -c "qa" 2>&1
```

Expected: `LuxVim loads`

**Step 3: Commit**

```bash
git add init.lua
git commit -m "feat: update entry point to use new core infrastructure"
```

---

### Task 4.2: Remove Old Structure

**Files:**
- Delete: `lua/config/lazy.lua`
- Delete: `lua/config/keymaps.lua`
- Delete: `lua/config/autocmds.lua`
- Delete: `lua/dev.lua`
- Delete: `lua/plugins/*.lua` (old flat files)

**Step 1: Remove old config files**

```bash
rm lua/config/lazy.lua
rm lua/config/keymaps.lua
rm lua/config/autocmds.lua
rm lua/dev.lua
```

**Step 2: Remove old plugin files (flat structure)**

```bash
rm lua/plugins/luxlsp.lua
rm lua/plugins/luxterm.lua
rm lua/plugins/fzf.lua
rm lua/plugins/lspconfig.lua
rm lua/plugins/easyenv.lua
rm lua/plugins/luxpane.lua
rm lua/plugins/luxdash.lua
rm lua/plugins/easycomment.lua
rm lua/plugins/nvim-tree.lua
rm lua/plugins/colorschemes.lua
rm lua/plugins/luxline.lua
rm lua/plugins/easyops.lua
rm lua/plugins/treesitter.lua
rm lua/plugins/luxmotion.lua
```

**Step 3: Verify clean state**

```bash
ls lua/plugins/
```

Expected: Only category directories (lib, ui, editor, lsp, terminal, navigation)

**Step 4: Test LuxVim still works**

```bash
NVIM_APPNAME="LuxVim-test" nvim --headless -c "lua print('Plugins:', #require('lazy').plugins())" -c "qa" 2>&1
```

Expected: Shows plugin count

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: remove old configuration structure"
```

---

## Phase 5: Generate Type Annotations

### Task 5.1: Create Type Generator

**Files:**
- Create: `lua/core/lib/typegen.lua`

**Step 1: Create type generator**

```lua
-- lua/core/lib/typegen.lua
local schema = require("core.lib.schema")
local debug_mod = require("core.lib.debug")

local M = {}

local function lua_type_to_annotation(type_def)
  if type(type_def) == "string" then
    if type_def == "list" then
      return "any[]"
    end
    return type_def
  end

  if type(type_def) == "table" then
    if type_def.type then
      return lua_type_to_annotation(type_def.type)
    end
    local types = {}
    for _, t in ipairs(type_def) do
      table.insert(types, lua_type_to_annotation(t))
    end
    return table.concat(types, "|")
  end

  return "any"
end

local function generate_class(name, schema_def)
  local lines = { "---@class " .. name }

  local fields = {}
  for field, rules in pairs(schema_def) do
    table.insert(fields, field)
  end
  table.sort(fields)

  for _, field in ipairs(fields) do
    local rules = schema_def[field]
    local type_str = lua_type_to_annotation(rules.type or "any")
    local optional = not rules.required and "?" or ""
    local desc = rules.desc or ""

    table.insert(lines, string.format("---@field %s%s %s %s", field, optional, type_str, desc))
  end

  return table.concat(lines, "\n")
end

function M.generate()
  local output = {
    "-- lua/types/plugin.lua",
    "-- GENERATED FILE - DO NOT EDIT",
    "-- Run :LuxVimGenerateTypes to regenerate",
    "",
  }

  table.insert(output, generate_class("BuildSpec", schema.build_spec))
  table.insert(output, "")
  table.insert(output, generate_class("PluginSpec", schema.plugin_spec))
  table.insert(output, "")
  table.insert(output, generate_class("KeymapEntry", schema.keymap_entry))
  table.insert(output, "")
  table.insert(output, generate_class("AutocmdEntry", schema.autocmd_entry))

  return table.concat(output, "\n")
end

function M.write()
  local root = debug_mod.get_luxvim_root()
  local types_dir = root .. "/lua/types"
  local output_path = types_dir .. "/plugin.lua"

  vim.fn.mkdir(types_dir, "p")

  local content = M.generate()
  local file = io.open(output_path, "w")
  if file then
    file:write(content)
    file:close()
    print("Generated: " .. output_path)
  else
    print("Failed to write: " .. output_path)
  end
end

vim.api.nvim_create_user_command("LuxVimGenerateTypes", function()
  M.write()
end, { desc = "Generate LuxVim type annotations" })

return M
```

**Step 2: Generate types**

```bash
nvim --headless -c "require('core.lib.typegen').write()" -c "qa"
```

**Step 3: Verify generated file**

```bash
cat lua/types/plugin.lua
```

**Step 4: Commit**

```bash
git add lua/core/lib/typegen.lua lua/types/plugin.lua
git commit -m "feat(core): add type annotation generator"
```

---

## Phase 6: Final Validation

### Task 6.1: Full System Test

**Step 1: Test complete startup**

```bash
NVIM_APPNAME="LuxVim-test" nvim --headless -c "lua print('Plugins:', #require('lazy').plugins())" -c "qa"
```

**Step 2: Test keymaps registered**

```bash
NVIM_APPNAME="LuxVim-test" nvim --headless -c "lua print('Keymaps work:', vim.fn.maparg('<leader>fs', 'n') ~= '')" -c "qa"
```

**Step 3: Test commands exist**

```bash
NVIM_APPNAME="LuxVim-test" nvim --headless -c "LuxVimErrors" -c "qa"
NVIM_APPNAME="LuxVim-test" nvim --headless -c "LuxDevStatus" -c "qa"
```

**Step 4: Commit final state**

```bash
git add -A
git commit -m "feat: complete configuration restructure

- Layered architecture with core/lib (logic) and core/registry (data)
- Declarative plugin specs with minimal boilerplate
- Centralized keymaps and filetypes registries
- Schema-driven validation with tiered strictness
- Debug plugin detection with convention + override
- Generated type annotations for IDE support"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1.1-1.6 | Core infrastructure foundation |
| 2 | 2.1-2.5 | Plugin loading infrastructure |
| 3 | 3.1-3.5 | Migrate plugin specs |
| 4 | 4.1-4.2 | Update entry point, remove old |
| 5 | 5.1 | Generate type annotations |
| 6 | 6.1 | Final validation |

Total: 18 tasks across 6 phases
