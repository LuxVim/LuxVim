# LuxVim Framework Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor LuxVim from a personal Neovim config into an extensible framework with a pluggable pipeline, overridable specs, and user config layer.

**Architecture:** Split the monolithic loader into a 5-stage pipeline (discover/load/merge/validate/transform) with hooks. Add a schema registry API for extensibility. Introduce a user config directory with extends/replaces semantics. Extract core actions into a regular plugin spec. Rebuild the theme picker as a framework plugin.

**Tech Stack:** Lua, Neovim API, lazy.nvim

**Design Spec:** `docs/superpowers/specs/2026-04-04-framework-refactor-design.md`

**Validation:** This project has no test suite. Validate each task by launching `lux` and confirming plugins load without errors (`:LuxVimErrors`). Headless smoke test: `lux --headless "+Lazy! sync" +qa`.

---

### Task 1: Schema Registry API

Convert the hardcoded schema module into a registry with `extend`, `replace`, and `get` operations. Add `extends`/`replaces` fields to plugin_spec. Update autocmd_entry to support optional action + callback.

**Files:**
- Modify: `lua/core/lib/schema.lua`

- [ ] **Step 1: Rewrite schema.lua as a registry**

Replace the entire file with the registry-based version. The current fields become defaults registered at load time. A `__index` metamethod on `M` provides backward compatibility so `schema.plugin_spec` still works.

```lua
local M = {}

local _schemas = {}

local function register_defaults()
  _schemas.build_spec = {
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

  _schemas.plugin_spec = {
    source = { type = "string", required = true, desc = "GitHub repo (author/name) or 'virtual'" },
    debug_name = { type = "string", desc = "Override debug folder name" },
    opts = { type = "table", default = {}, desc = "Options passed to setup()" },
    config = { type = "function", desc = "Custom config function" },
    build = { type = { "string", "table" }, desc = "Build configuration" },
    actions = { type = "table", desc = "Action overrides for keymap resolution" },
    globals = { type = "table", desc = "vim.g variables set before plugin loads" },
    dependencies = { type = "list", of = "string", desc = "References to other plugin specs" },
    cond = { type = { "string", "function" }, desc = "Load condition" },
    event = { type = { "string", "list" }, desc = "Lazy-load on event" },
    cmd = { type = { "string", "list" }, desc = "Lazy-load on command" },
    ft = { type = { "string", "list" }, desc = "Lazy-load on filetype" },
    keys = { type = { "string", "list", "table" }, desc = "Lazy-load on keymap" },
    enabled = { type = "boolean", default = true, desc = "Enable/disable plugin" },
    lazy = { type = "table", passthrough = true, desc = "Lazy.nvim native fields" },
    extends = { type = "string", desc = "Name of framework spec to extend (deep merge)" },
    replaces = { type = "string", desc = "Name of framework spec to replace entirely" },
  }

  _schemas.keymap_entry = {
    action = { type = "string", required = true, desc = "Action to invoke" },
    desc = { type = "string", desc = "Description for which-key" },
    mode = { type = { "string", "list" }, default = "n", desc = "Vim mode(s)" },
  }

  _schemas.autocmd_entry = {
    action = { type = "string", desc = "Action to invoke (mutually exclusive with callback)" },
    callback = { type = "function", desc = "Direct callback (mutually exclusive with action)" },
    pattern = { type = { "string", "list" }, default = "*", desc = "File pattern" },
    once = { type = "boolean", default = false, desc = "Run only once" },
  }
end

function M.get(name)
  return _schemas[name]
end

function M.extend(name, fields)
  local schema = _schemas[name]
  if not schema then
    _schemas[name] = fields
    return
  end
  for field, rules in pairs(fields) do
    schema[field] = rules
  end
end

function M.replace(name, fields)
  _schemas[name] = fields
end

register_defaults()

setmetatable(M, {
  __index = function(_, key)
    return _schemas[key]
  end,
})

return M
```

- [ ] **Step 2: Verify backward compatibility**

Run: `lux --headless "+Lazy! sync" +qa`

Expected: exits cleanly with no errors. The `__index` metamethod means all existing code that reads `schema.plugin_spec` still works.

- [ ] **Step 3: Commit**

```bash
git add lua/core/lib/schema.lua
git commit -m "refactor: convert schema to registry with extend/replace/get API"
```

---

### Task 2: Validation Updates

Update validate.lua to use `schema.get()`, cache the known-fields list, and add `validate_autocmd_entry()` for action/callback mutual exclusivity.

**Files:**
- Modify: `lua/core/lib/validate.lua`

- [ ] **Step 1: Rewrite validate.lua**

```lua
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

  local known_fields = nil
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

function M.validate_plugin_spec(spec, file_path)
  return M.validate_against(spec, schema.get("plugin_spec"), file_path or "plugin")
end

function M.validate_autocmd_entry(entry, path)
  local errors, warnings = M.validate_against(entry, schema.get("autocmd_entry"), path or "autocmd")

  local has_action = entry.action ~= nil
  local has_callback = entry.callback ~= nil

  if not has_action and not has_callback then
    table.insert(warnings, {
      level = M.errors.WARNING,
      path = path or "autocmd",
      message = "autocmd entry should have either 'action' or 'callback'",
    })
  elseif has_action and has_callback then
    table.insert(warnings, {
      level = M.errors.WARNING,
      path = path or "autocmd",
      message = "autocmd entry has both 'action' and 'callback'; 'callback' takes precedence",
    })
  end

  return errors, warnings
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

- [ ] **Step 2: Verify**

Run: `lux --headless "+Lazy! sync" +qa`

Expected: exits cleanly. Validation still works because `schema.get("plugin_spec")` returns the same schema that `schema.plugin_spec` did.

- [ ] **Step 3: Commit**

```bash
git add lua/core/lib/validate.lua
git commit -m "refactor: update validate to use schema registry, add autocmd validation"
```

---

### Task 3: Pipeline Orchestrator

Create the pipeline module with hook system and stage runner. This exists alongside the current loader — no behavior change yet.

**Files:**
- Create: `lua/core/lib/pipeline.lua`

- [ ] **Step 1: Create the pipeline orchestrator**

```lua
local M = {}

local _hooks = {}
local _stages = {}

function M.on(hook_name, fn)
  _hooks[hook_name] = _hooks[hook_name] or {}
  table.insert(_hooks[hook_name], fn)
end

local function run_hooks(name, context)
  local hooks = _hooks[name]
  if not hooks then
    return context
  end
  for _, fn in ipairs(hooks) do
    context = fn(context) or context
  end
  return context
end

function M.register_stage(name, fn)
  table.insert(_stages, { name = name, fn = fn })
end

function M.run()
  local context = {
    specs = {},
    specs_by_name = {},
    errors = {},
    warnings = {},
  }

  for _, stage in ipairs(_stages) do
    context = run_hooks("pre_" .. stage.name, context)
    context = stage.fn(context)
    context = run_hooks("post_" .. stage.name, context)
  end

  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, context.errors)

  context.ok = #critical == 0
  context.raw_specs = context.specs
  return context
end

function M.reset()
  _hooks = {}
  _stages = {}
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/core/lib/pipeline.lua
git commit -m "feat: add pipeline orchestrator with hook system"
```

---

### Task 4: Discover Stage

Extract directory scanning from `loader.lua` into a standalone discover stage. Scans framework plugin dirs and (for future) user/dynamic dirs.

**Files:**
- Create: `lua/core/lib/pipeline/discover.lua`

- [ ] **Step 1: Create the discover stage**

```lua
local debug_mod = require("core.lib.debug")
local paths = require("core.lib.paths")

local M = {}

function M.scan_plugin_dirs(base_path)
  local entries = paths.scandir(base_path, function(_, entry_type)
    return entry_type == "directory"
  end)

  local dirs = {}
  for _, entry in ipairs(entries) do
    table.insert(dirs, { name = entry.name, path = paths.join(base_path, entry.name) })
  end
  return dirs
end

function M.scan_category(category_path, category_name)
  local entries = paths.scandir(category_path, function(name, entry_type)
    return entry_type == "file" and name:match("%.lua$") and name ~= "_defaults.lua"
  end)

  local defaults_path = paths.join(category_path, "_defaults.lua")
  local defaults = {}
  if vim.uv.fs_stat(defaults_path) then
    local ok, result = pcall(dofile, defaults_path)
    if ok then
      defaults = result
    end
  end

  local files = {}
  for _, entry in ipairs(entries) do
    table.insert(files, {
      path = paths.join(category_path, entry.name),
      category = category_name,
      defaults = defaults,
      source = "framework",
    })
  end
  return files
end

function M.run(context)
  local root = debug_mod.get_luxvim_root()
  local plugins_dir = paths.join(root, "lua", "plugins")

  local dirs = M.scan_plugin_dirs(plugins_dir)

  if #dirs == 0 then
    table.insert(context.errors, {
      level = "critical",
      file = "core.lib.pipeline.discover",
      message = "Plugin directory not found: " .. plugins_dir
          .. "\nLuxVim root detected as: " .. root
          .. "\nLaunch LuxVim from its directory or check installation.",
    })
    return context
  end

  local files = {}
  for _, dir in ipairs(dirs) do
    local category_files = M.scan_category(dir.path, dir.name)
    for _, f in ipairs(category_files) do
      table.insert(files, f)
    end
  end

  -- Scan dynamic-specs directory (for theme picker and other dynamic plugins)
  local data = require("core.lib.data")
  local dynamic_dir = paths.join(data.root(), "data", "dynamic-specs")
  if vim.uv.fs_stat(dynamic_dir) then
    local dynamic_entries = paths.scandir(dynamic_dir, function(name, entry_type)
      return entry_type == "file" and name:match("%.lua$")
    end)
    for _, entry in ipairs(dynamic_entries) do
      table.insert(files, {
        path = paths.join(dynamic_dir, entry.name),
        category = "dynamic",
        defaults = {},
        source = "dynamic",
      })
    end
  end

  context.discovered_files = files
  return context
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/core/lib/pipeline/discover.lua
git commit -m "feat: add pipeline discover stage"
```

---

### Task 5: Load Stage

Extract spec loading from `loader.lua` into a standalone load stage. Calls `dofile`, merges category defaults, builds `specs_by_name` index.

**Files:**
- Create: `lua/core/lib/pipeline/load.lua`

- [ ] **Step 1: Create the load stage**

```lua
local debug_mod = require("core.lib.debug")
local validate = require("core.lib.validate")

local M = {}

function M.run(context)
  local files = context.discovered_files or {}
  local specs = {}
  local specs_by_name = {}

  for _, file in ipairs(files) do
    local ok, spec = pcall(dofile, file.path)

    if not ok then
      table.insert(context.errors, {
        level = "critical",
        file = file.path,
        message = "failed to load: " .. tostring(spec),
      })
    elseif type(spec) ~= "table" then
      table.insert(context.errors, {
        level = "critical",
        file = file.path,
        message = "spec must be a table, got " .. type(spec),
      })
    else
      local errors, warnings = validate.validate_plugin_spec(spec, file.path)
      for _, e in ipairs(errors) do
        table.insert(context.errors, { level = e.level or "critical", file = file.path, message = e.message })
      end
      for _, w in ipairs(warnings) do
        table.insert(context.warnings, { level = "warning", file = file.path, message = w.message })
      end

      if #errors == 0 then
        spec._file = file.path
        spec._category = file.category
        spec._source = file.source or "framework"
        spec = vim.tbl_deep_extend("keep", spec, file.defaults)

        local name = debug_mod.resolve_debug_name(spec)
        table.insert(specs, spec)
        specs_by_name[name] = spec
      end
    end
  end

  context.specs = specs
  context.specs_by_name = specs_by_name
  return context
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/core/lib/pipeline/load.lua
git commit -m "feat: add pipeline load stage"
```

---

### Task 6: Pipeline Validate Stage

Thin wrapper that filters specs with critical errors. The actual validation happens in the load stage (existing behavior), but this stage provides a hook point for user-injected validation.

**Files:**
- Create: `lua/core/lib/pipeline/validate.lua`

- [ ] **Step 1: Create the validate stage**

```lua
local M = {}

function M.run(context)
  -- Validation already happens in load stage (validate_plugin_spec on each spec).
  -- This stage exists as a hook point: users can register pre_validate/post_validate
  -- hooks to add custom validation, modify specs, or filter specs.
  --
  -- Filter out specs that are disabled.
  local filtered = {}
  for _, spec in ipairs(context.specs) do
    if spec.enabled ~= false then
      table.insert(filtered, spec)
    end
  end
  context.specs = filtered
  return context
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/core/lib/pipeline/validate.lua
git commit -m "feat: add pipeline validate stage"
```

---

### Task 7: Transform Stage

Extract all transformation logic from `loader.lua` — `transform_to_lazy`, `resolve_dependencies`, `transform_build`, `evaluate_condition` — into a standalone transform stage.

**Files:**
- Create: `lua/core/lib/pipeline/transform.lua`

- [ ] **Step 1: Create the transform stage**

```lua
local debug_mod = require("core.lib.debug")
local platform = require("core.lib.platform")
local conditions = require("core.registry.conditions")
local notify = require("core.lib.notify")

local M = {}

local passthrough_fields = { "event", "cmd", "ft", "keys" }

local function safe_eval(fn)
  local ok, result = pcall(fn)
  return ok and result
end

function M.evaluate_condition(cond)
  if cond == nil then
    return true
  end

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

function M.transform_build(build)
  if type(build) == "string" then
    return build
  end

  if type(build) == "table" then
    local cmd = build.cmd
    if build.platforms then
      if build.platforms[platform.os] then
        cmd = build.platforms[platform.os]
      end
    end

    if build.requires then
      for _, exe in ipairs(build.requires) do
        if vim.fn.executable(exe) ~= 1 then
          if build.on_fail == "error" then
            error("Build requires " .. exe .. " but it's not available")
          elseif build.on_fail ~= "ignore" then
            notify.warn("Build skipped: missing " .. exe)
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

function M.resolve_dependencies(deps, specs_by_name)
  local resolved = {}
  for _, dep in ipairs(deps) do
    if type(dep) == "string" then
      if specs_by_name[dep] then
        local dep_spec = specs_by_name[dep]
        local lazy_dep = M.transform_one(dep_spec, specs_by_name)
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

function M.transform_one(spec, specs_by_name)
  local debug_name = debug_mod.resolve_debug_name(spec)
  local use_debug = debug_mod.has_debug_plugin(debug_name)

  local lazy_spec = {}

  if use_debug then
    lazy_spec.dir = debug_mod.get_debug_path(debug_name)
    lazy_spec.name = debug_name .. "-debug"
  elseif spec.source == "virtual" then
    lazy_spec.dir = debug_mod.get_luxvim_root()
    lazy_spec.name = spec.debug_name or "virtual"
  else
    lazy_spec[1] = spec.source
  end

  if spec.opts then
    lazy_spec.opts = spec.opts
  end

  if spec.config ~= nil then
    lazy_spec.config = spec.config
  elseif spec.opts then
    lazy_spec.config = true
  end

  if spec.dependencies then
    lazy_spec.dependencies = M.resolve_dependencies(spec.dependencies, specs_by_name)
  end

  for _, field in ipairs(passthrough_fields) do
    if spec[field] then
      lazy_spec[field] = spec[field]
    end
  end

  if spec.build then
    lazy_spec.build = M.transform_build(spec.build)
  end

  if spec.lazy then
    if type(spec.lazy) == "table" then
      lazy_spec = vim.tbl_deep_extend("force", lazy_spec, spec.lazy)
    elseif spec.lazy == true then
      lazy_spec.lazy = true
    end
  end

  if spec.globals then
    local lazy_init = lazy_spec.init
    lazy_spec.init = function()
      for key, value in pairs(spec.globals) do
        vim.g[key] = value
      end
      if lazy_init then
        lazy_init()
      end
    end
  end

  -- Defer condition evaluation to lazy.nvim
  if spec.cond ~= nil then
    local cond = spec.cond
    lazy_spec.cond = function()
      return M.evaluate_condition(cond)
    end
  end

  return lazy_spec
end

function M.run(context)
  local lazy_specs = {}

  for _, spec in ipairs(context.specs) do
    local lazy_spec = M.transform_one(spec, context.specs_by_name)
    if lazy_spec then
      table.insert(lazy_specs, lazy_spec)
    end
  end

  context.lazy_specs = lazy_specs
  return context
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/core/lib/pipeline/transform.lua
git commit -m "feat: add pipeline transform stage"
```

---

### Task 8: Wire Pipeline Into Core + Delete Loader

Register all pipeline stages, switch `core/init.lua` to use the pipeline, and delete `loader.lua`.

**Files:**
- Modify: `lua/core/init.lua`
- Delete: `lua/core/lib/loader.lua`

- [ ] **Step 1: Rewrite core/init.lua to use pipeline**

```lua
local M = {}

local function setup_pipeline()
  local pipeline = require("core.lib.pipeline")
  local discover = require("core.lib.pipeline.discover")
  local load_stage = require("core.lib.pipeline.load")
  local validate_stage = require("core.lib.pipeline.validate")
  local transform = require("core.lib.pipeline.transform")

  pipeline.register_stage("discover", discover.run)
  pipeline.register_stage("load", load_stage.run)
  pipeline.register_stage("validate", validate_stage.run)
  pipeline.register_stage("transform", transform.run)

  return pipeline
end

local function report_errors(result)
  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, result.errors)

  if #critical > 0 then
    local msg = "[LuxVim] FATAL: Cannot start\n"
    for _, e in ipairs(critical) do
      msg = msg .. "  " .. (e.file or "unknown") .. ": " .. e.message .. "\n"
    end
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
    return false
  end

  local notify = require("core.lib.notify")
  local non_critical = vim.tbl_filter(function(e)
    return e.level ~= "critical"
  end, result.errors)

  for _, e in ipairs(non_critical) do
    notify.warn("Plugin skipped: " .. (e.file or "unknown") .. "\n  " .. e.message)
  end

  if #result.warnings > 0 then
    vim.defer_fn(function()
      notify.info("Started with " .. #result.warnings .. " warnings. Run :LuxVimErrors for details.")
    end, 100)
  end

  return true
end

function M.setup()
  local pipeline = setup_pipeline()
  local bootstrap = require("core.lib.bootstrap")
  local actions = require("core.lib.actions")
  local keymap = require("core.lib.keymap")
  local autocmd = require("core.lib.autocmd")

  local result = pipeline.run()

  if not report_errors(result) then
    return false
  end

  bootstrap.setup_lazy(result.lazy_specs)

  actions.register_core_actions()

  for _, spec in ipairs(result.raw_specs) do
    actions.register_from_spec(spec)
  end

  keymap.setup()
  autocmd.setup()

  M._result = result
  M._create_commands()

  return true
end

function M._create_commands()
  local notify = require("core.lib.notify")

  vim.api.nvim_create_user_command("SearchText", function()
    local actions = require("core.lib.actions")
    actions.invoke("core.search_text")
  end, { desc = "Search text in current directory" })

  vim.api.nvim_create_user_command("LuxVimErrors", function()
    local errors = M._result and M._result.errors or {}
    local warnings = M._result and M._result.warnings or {}

    if #errors == 0 and #warnings == 0 then
      notify.info("No errors or warnings")
      return
    end

    local lines = { "=== LuxVim Errors ===" }
    for _, e in ipairs(errors) do
      table.insert(lines, string.format("[%s] %s: %s", (e.level or "error"):upper(), e.file or "unknown", e.message))
    end
    table.insert(lines, "\n=== LuxVim Warnings ===")
    for _, w in ipairs(warnings) do
      table.insert(lines, string.format("[%s] %s: %s", "WARNING", w.file or "unknown", w.message))
    end

    notify.warn(table.concat(lines, "\n"))
  end, { desc = "Show LuxVim errors and warnings" })

  vim.api.nvim_create_user_command("LuxDevStatus", function()
    local debug_mod = require("core.lib.debug")
    local plugins = debug_mod.list_debug_plugins()

    local lines = { "LuxVim Development Status", "============================" }

    if #plugins == 0 then
      table.insert(lines, "No debug plugins found in /debug directory")
    else
      table.insert(lines, "Active debug plugins:")
      for _, plugin in ipairs(plugins) do
        local path = debug_mod.get_debug_path(plugin)
        table.insert(lines, "  " .. plugin .. " -> " .. path)
      end
    end

    notify.info(table.concat(lines, "\n"))
  end, { desc = "Show LuxVim development status" })

  vim.api.nvim_create_user_command("LuxVimGenerateTypes", function()
    local typegen = require("core.lib.typegen")
    typegen.write()
  end, { desc = "Generate LuxVim type annotations" })
end

return M
```

Note: This version still calls `actions.register_core_actions()` and keeps `SearchText` — those are removed in Task 10 after core-actions plugin exists.

- [ ] **Step 2: Delete the old loader**

```bash
rm lua/core/lib/loader.lua
```

- [ ] **Step 3: Launch and verify**

Run: `lux`

Expected: LuxVim starts normally. All plugins load. `:LuxVimErrors` shows no critical errors. Run `:Lazy` to confirm all plugins are listed.

- [ ] **Step 4: Run headless smoke test**

Run: `lux --headless "+Lazy! sync" +qa`

Expected: exits with code 0.

- [ ] **Step 5: Commit**

```bash
git add lua/core/init.lua && git rm lua/core/lib/loader.lua
git commit -m "refactor: replace monolithic loader with pipeline"
```

---

### Task 9: Action Registry Refactor

Strip `actions.lua` to mechanism only. Create `core-actions.lua` plugin spec. Update `fzf.lua` to use `:Rg`.

**Files:**
- Modify: `lua/core/lib/actions.lua`
- Create: `lua/plugins/editor/core-actions.lua`
- Modify: `lua/plugins/editor/fzf.lua`

- [ ] **Step 1: Rewrite actions.lua as mechanism only**

```lua
local M = {}
local notify = require("core.lib.notify")

M._registry = {}

function M.register(namespace, name, fn)
  M._registry[namespace] = M._registry[namespace] or {}
  M._registry[namespace][name] = fn
end

function M.register_namespace(namespace, actions_table)
  for name, fn in pairs(actions_table) do
    M.register(namespace, name, fn)
  end
end

function M.unregister(namespace, name)
  if M._registry[namespace] then
    M._registry[namespace][name] = nil
  end
end

local function split_action(action_string)
  -- Longest-prefix match against registered namespaces.
  -- Namespaces can contain dots (e.g., "fzf.vim"), so simple first-dot
  -- split would break. Sort by length descending for longest match.
  local sorted_ns = vim.tbl_keys(M._registry)
  table.sort(sorted_ns, function(a, b) return #a > #b end)

  for _, ns in ipairs(sorted_ns) do
    local prefix = ns .. "."
    if action_string:sub(1, #prefix) == prefix then
      return ns, action_string:sub(#prefix + 1)
    end
  end

  -- Fallback: simple dot split for unregistered namespaces
  local namespace, method = action_string:match("^([^.]+)%.(.+)$")
  return namespace, method
end

function M.resolve(action_string)
  local namespace, method = split_action(action_string)
  if not namespace or not method then
    return nil, "invalid action format: " .. action_string
  end

  if M._registry[namespace] and M._registry[namespace][method] then
    return M._registry[namespace][method]
  end

  -- Fallback: try requiring the namespace as a module
  local ok, module = pcall(require, namespace)
  if ok and type(module) == "table" and type(module[method]) == "function" then
    return function() module[method]() end
  end

  return nil, "could not resolve action: " .. action_string
end

function M.invoke(action_string)
  local fn, err = M.resolve(action_string)
  if not fn then
    notify.warn(err)
    return false
  end

  local ok, result = pcall(fn)
  if not ok then
    notify.error("Action error: " .. tostring(result))
    return false
  end
  return true
end

function M.register_from_spec(spec)
  if not spec.actions then
    return
  end

  local debug_mod = require("core.lib.debug")
  local plugin_name = debug_mod.resolve_debug_name(spec)
  for action_name, fn in pairs(spec.actions) do
    if type(fn) == "string" and fn:sub(1, 1) == ":" then
      local cmd = fn:sub(2)
      fn = function()
        vim.cmd(cmd)
      end
    elseif type(fn) ~= "function" then
      notify.warn("Invalid action type for " .. plugin_name .. "." .. action_name .. ": expected function or :command string")
      fn = nil
    end
    if fn then
      M.register(plugin_name, action_name, fn)
    end
  end
end

-- Temporary: kept for backward compat until core-actions plugin is wired
function M.register_core_actions()
  -- no-op: core actions now come from plugins/editor/core-actions.lua spec
end

return M
```

- [ ] **Step 2: Create core-actions plugin spec**

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

- [ ] **Step 3: Update fzf.lua — change SearchText to Rg**

Change `lua/plugins/editor/fzf.lua` line 7 from `search_text = ":SearchText"` to `search_text = ":Rg"`:

```lua
return {
  source = "junegunn/fzf.vim",
  dependencies = { "fzf" },
  cmd = { "Files", "GFiles", "Buffers", "Rg", "Lines", "History", "Commits", "Commands" },
  actions = {
    files = ":Files",
    search_text = ":Rg",
  },
  globals = {
    fzf_layout = { down = "20%" },
  },
}
```

- [ ] **Step 4: Launch and verify**

Run: `lux`

Expected: LuxVim starts. Press `<leader>fs` to save (tests core.save action). Press `<leader>st` to search text (should open `:Rg` instead of old `:SearchText`). Press `<leader>e` to toggle tree.

- [ ] **Step 5: Commit**

```bash
git add lua/core/lib/actions.lua lua/plugins/editor/core-actions.lua lua/plugins/editor/fzf.lua
git commit -m "refactor: separate action registry from core actions, create core-actions plugin"
```

---

### Task 10: Autocmd Callback Support + Cleanup

Add `callback` support to `autocmd.lua`. Rewrite `autocmds.lua` registry to use inline callbacks. Remove `SearchText` command and `register_core_actions()` from core/init.lua. Move diagnostic config to options.lua.

**Files:**
- Modify: `lua/core/lib/autocmd.lua`
- Modify: `lua/core/registry/autocmds.lua`
- Modify: `lua/core/init.lua`
- Modify: `lua/config/options.lua`

- [ ] **Step 1: Update autocmd.lua to support callback field**

```lua
local actions = require("core.lib.actions")

local M = {}

local augroup = vim.api.nvim_create_augroup("LuxVimCore", { clear = true })

function M.register_autocmds(registry)
  for event, config in pairs(registry) do
    if event == "extends" or event == "replaces" then
      goto continue
    end

    local pattern = config.pattern or "*"
    local once = config.once or false

    local callback
    if config.callback then
      callback = config.callback
    elseif config.action then
      callback = function()
        actions.invoke(config.action)
      end
    end

    if callback then
      vim.api.nvim_create_autocmd(event, {
        group = augroup,
        pattern = pattern,
        once = once,
        callback = callback,
      })
    end

    ::continue::
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

- [ ] **Step 2: Rewrite autocmds registry with inline callbacks**

```lua
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
  BufLeave = {
    callback = function()
      if vim.bo.filetype == "fzf" then
        vim.opt.laststatus = 3
        vim.opt.showmode = true
        vim.opt.ruler = true
      end
    end,
  },
}
```

- [ ] **Step 3: Add diagnostic config to options.lua**

Append to the end of `lua/config/options.lua`:

```lua
-- Diagnostic virtual text configuration
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local current_config = vim.diagnostic.config()
      if current_config.virtual_text == false then
        local bullet = vim.fn.nr2char(0x25CF)
        vim.diagnostic.config({
          virtual_text = {
            prefix = bullet,
            spacing = 4,
          },
          signs = current_config.signs,
          underline = current_config.underline,
          update_in_insert = current_config.update_in_insert,
          severity_sort = current_config.severity_sort,
          float = current_config.float,
        })
      end
    end, 100)
  end,
})
```

- [ ] **Step 4: Clean up core/init.lua**

Remove the `actions.register_core_actions()` call and the `SearchText` command from `core/init.lua`. In the `M.setup()` function, delete the line:

```lua
  actions.register_core_actions()
```

In `M._create_commands()`, delete the `SearchText` command block (lines creating the `SearchText` user command).

- [ ] **Step 5: Launch and verify**

Run: `lux`

Expected: LuxVim starts. Open an fzf window (`<leader><leader>`), confirm statusbar hides. Close it, confirm statusbar returns. Open a quickfix window, confirm Enter closes it. Check `:LuxVimErrors` for no errors.

- [ ] **Step 6: Commit**

```bash
git add lua/core/lib/autocmd.lua lua/core/registry/autocmds.lua lua/config/options.lua lua/core/init.lua
git commit -m "refactor: add autocmd callback support, inline filetype/diagnostic logic, remove SearchText"
```

---

### Task 11: User Config Layer

Add `user_config_path()` to data.lua. Update discover to scan user dirs. Create the merge stage. Wire user init.lua loading and package.path into core/init.lua. Add registry override support to keymap.lua and autocmd.lua.

**Files:**
- Modify: `lua/core/lib/data.lua`
- Create: `lua/core/lib/pipeline/merge.lua`
- Modify: `lua/core/lib/pipeline/discover.lua`
- Modify: `lua/core/init.lua`
- Modify: `lua/core/lib/keymap.lua`
- Modify: `lua/core/lib/autocmd.lua`

- [ ] **Step 1: Add user_config_path to data.lua**

Add after the existing `parser_path()` function in `lua/core/lib/data.lua`:

```lua
function M.user_config_path()
  return vim.env.LUXVIM_CONFIG
      or paths.join(vim.env.XDG_CONFIG_HOME or paths.join(vim.env.HOME or "", ".config"), "luxvim")
end
```

- [ ] **Step 2: Create merge stage**

```lua
-- lua/core/lib/pipeline/merge.lua
local debug_mod = require("core.lib.debug")

local M = {}

function M.run(context)
  local framework_specs = {}
  local user_specs = {}

  -- Separate framework and user specs
  for _, spec in ipairs(context.specs) do
    if spec._source == "user" then
      table.insert(user_specs, spec)
    else
      table.insert(framework_specs, spec)
    end
  end

  -- If no user specs, nothing to merge
  if #user_specs == 0 then
    return context
  end

  -- Index framework specs by name
  local fw_by_name = {}
  for i, spec in ipairs(framework_specs) do
    local name = debug_mod.resolve_debug_name(spec)
    fw_by_name[name] = { index = i, spec = spec }
  end

  local merged = {}
  for _, spec in ipairs(framework_specs) do
    table.insert(merged, spec)
  end

  for _, user_spec in ipairs(user_specs) do
    if user_spec.extends then
      -- Deep merge user onto framework spec
      local target = fw_by_name[user_spec.extends]
      if target then
        local base = merged[target.index]
        -- Remove extends field before merging
        user_spec.extends = nil
        user_spec._source = nil
        user_spec._file = user_spec._file
        user_spec._category = base._category
        merged[target.index] = vim.tbl_deep_extend("force", base, user_spec)
      else
        table.insert(context.warnings, {
          level = "warning",
          file = user_spec._file or "user",
          message = "extends target '" .. user_spec.extends .. "' not found, treating as new spec",
        })
        table.insert(merged, user_spec)
      end
    elseif user_spec.replaces then
      -- Replace framework spec entirely
      local target = fw_by_name[user_spec.replaces]
      if target then
        user_spec.replaces = nil
        merged[target.index] = user_spec
      else
        table.insert(context.warnings, {
          level = "warning",
          file = user_spec._file or "user",
          message = "replaces target '" .. user_spec.replaces .. "' not found, treating as new spec",
        })
        table.insert(merged, user_spec)
      end
    else
      -- New user plugin
      table.insert(merged, user_spec)
    end
  end

  context.specs = merged

  -- Rebuild specs_by_name
  context.specs_by_name = {}
  for _, spec in ipairs(merged) do
    local name = debug_mod.resolve_debug_name(spec)
    context.specs_by_name[name] = spec
  end

  return context
end

return M
```

- [ ] **Step 3: Update discover.lua to scan user plugin dirs**

Add after the dynamic-specs scanning block in `discover.lua`, before `context.discovered_files = files`:

```lua
  -- Scan user plugin directories
  local user_config = data.user_config_path()
  local user_plugins_dir = paths.join(user_config, "plugins")
  if vim.uv.fs_stat(user_plugins_dir) then
    local user_dirs = M.scan_plugin_dirs(user_plugins_dir)
    for _, dir in ipairs(user_dirs) do
      local category_files = M.scan_category(dir.path, dir.name)
      for _, f in ipairs(category_files) do
        f.source = "user"
        table.insert(files, f)
      end
    end
  end
```

Note: the `data` require is already in discover.lua from the dynamic-specs block.

- [ ] **Step 4: Register merge stage in core/init.lua**

In the `setup_pipeline()` function in `lua/core/init.lua`, add the merge stage require and registration between load and validate:

```lua
  local merge = require("core.lib.pipeline.merge")
  -- ...
  pipeline.register_stage("load", load_stage.run)
  pipeline.register_stage("merge", merge.run)
  pipeline.register_stage("validate", validate_stage.run)
```

Also add user init.lua loading and package.path setup at the start of `M.setup()`, before `setup_pipeline()`:

```lua
  -- Prepend user config lua/ to package.path for require() overrides
  local data = require("core.lib.data")
  local user_config = data.user_config_path()
  local user_lua = user_config .. "/lua"
  if vim.uv.fs_stat(user_lua) then
    package.path = user_lua .. "/?.lua;" .. user_lua .. "/?/init.lua;" .. package.path
  end

  -- Load user init.lua early (schema extensions, pipeline hooks)
  local user_init = user_config .. "/init.lua"
  if vim.uv.fs_stat(user_init) then
    dofile(user_init)
  end
```

- [ ] **Step 5: Update keymap.lua for registry overrides**

```lua
local actions = require("core.lib.actions")
local notify = require("core.lib.notify")

local M = {}

function M.register_all(registry)
  for section_name, section in pairs(registry) do
    if section_name == "extends" or section_name == "replaces" then
      goto continue
    end
    if #section > 0 then
      for _, mapping in ipairs(section) do
        M.register_one(mapping.lhs, mapping, section_name)
      end
    else
      for lhs, mapping in pairs(section) do
        M.register_one(lhs, mapping, section_name)
      end
    end
    ::continue::
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

local function merge_registries(framework, user)
  if user.replaces then
    user.replaces = nil
    return user
  end

  if user.extends then
    user.extends = nil
    local merged = vim.deepcopy(framework)
    for section_name, section in pairs(user) do
      if merged[section_name] then
        merged[section_name] = vim.tbl_deep_extend("force", merged[section_name], section)
      else
        merged[section_name] = section
      end
    end
    return merged
  end

  return framework
end

function M.setup()
  local ok, registry = pcall(require, "core.registry.keymaps")
  if not ok then
    notify.warn("Failed to load keymap registry: " .. tostring(registry))
    return
  end

  -- Try loading user keymaps
  local data = require("core.lib.data")
  local paths = require("core.lib.paths")
  local user_keymaps_path = paths.join(data.user_config_path(), "registry", "keymaps.lua")
  if vim.uv.fs_stat(user_keymaps_path) then
    local uok, user_registry = pcall(dofile, user_keymaps_path)
    if uok and type(user_registry) == "table" then
      registry = merge_registries(registry, user_registry)
    end
  end

  M.register_all(registry)
end

return M
```

- [ ] **Step 6: Update autocmd.lua for registry overrides**

Add the same merge logic pattern to `autocmd.lua`. Add a `merge_registries` function and user registry loading in `M.setup()`. In the autocmds setup block:

```lua
function M.setup()
  local data = require("core.lib.data")
  local paths = require("core.lib.paths")

  local ok_autocmds, autocmds = pcall(require, "core.registry.autocmds")
  if ok_autocmds then
    local user_path = paths.join(data.user_config_path(), "registry", "autocmds.lua")
    if vim.uv.fs_stat(user_path) then
      local uok, user_autocmds = pcall(dofile, user_path)
      if uok and type(user_autocmds) == "table" then
        if user_autocmds.replaces then
          user_autocmds.replaces = nil
          autocmds = user_autocmds
        elseif user_autocmds.extends then
          user_autocmds.extends = nil
          autocmds = vim.tbl_deep_extend("force", autocmds, user_autocmds)
        end
      end
    end
    M.register_autocmds(autocmds)
  end

  local ok_filetypes, filetypes = pcall(require, "core.registry.filetypes")
  if ok_filetypes then
    local user_ft_path = paths.join(data.user_config_path(), "registry", "filetypes.lua")
    if vim.uv.fs_stat(user_ft_path) then
      local uok, user_ft = pcall(dofile, user_ft_path)
      if uok and type(user_ft) == "table" then
        if user_ft.replaces then
          user_ft.replaces = nil
          filetypes = user_ft
        elseif user_ft.extends then
          user_ft.extends = nil
          filetypes = vim.tbl_deep_extend("force", filetypes, user_ft)
        end
      end
    end
    M.register_filetypes(filetypes)
  end
end
```

- [ ] **Step 7: Launch and verify**

Run: `lux`

Expected: LuxVim starts normally (no user config dir exists yet, so all overrides are skipped gracefully). All plugins load. All keymaps work.

- [ ] **Step 8: Commit**

```bash
git add lua/core/lib/data.lua lua/core/lib/pipeline/merge.lua lua/core/lib/pipeline/discover.lua lua/core/init.lua lua/core/lib/keymap.lua lua/core/lib/autocmd.lua
git commit -m "feat: add user config layer with extends/replaces override semantics"
```

---

### Task 12: Theme Picker Plugin

Create the theme picker as a regular plugin spec with config module. Delete the old core theme-picker directory.

**Files:**
- Create: `lua/plugins/ui/theme-picker.lua`
- Create: `lua/plugins/ui/config/theme-picker.lua`
- Delete: `lua/core/theme-picker/` (entire directory)

- [ ] **Step 1: Create theme-picker plugin spec**

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
      { repo = "LuxVim/nami.nvim", name = "nami", description = "LuxVim default theme", colorscheme = "nami" },
      { repo = "catppuccin/nvim", name = "catppuccin", description = "Soothing pastel theme, 4 variants", colorscheme = "catppuccin",
        variants = { "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha" } },
      { repo = "folke/tokyonight.nvim", name = "tokyonight", description = "Clean dark theme, multiple styles", colorscheme = "tokyonight",
        variants = { "tokyonight-night", "tokyonight-storm", "tokyonight-day", "tokyonight-moon" } },
      { repo = "morhetz/gruvbox", name = "gruvbox", description = "Retro groove color scheme", colorscheme = "gruvbox" },
      { repo = "dracula/vim", name = "dracula", description = "Dark theme for vampires", colorscheme = "dracula" },
    },
    optional_themes = {
      { repo = "rose-pine/neovim", name = "rose-pine", description = "Minimal, dark and light variants", colorscheme = "rose-pine",
        variants = { "rose-pine", "rose-pine-moon", "rose-pine-dawn" } },
      { repo = "sainnhe/everforest", name = "everforest", description = "Green-based, easy on eyes", colorscheme = "everforest" },
      { repo = "EdenEast/nightfox.nvim", name = "nightfox", description = "Soft dark theme, many variants", colorscheme = "nightfox",
        variants = { "nightfox", "dayfox", "dawnfox", "duskfox", "nordfox", "terafox", "carbonfox" } },
      { repo = "rebelot/kanagawa.nvim", name = "kanagawa", description = "Wave-inspired, dark theme", colorscheme = "kanagawa",
        variants = { "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus" } },
      { repo = "navarasu/onedark.nvim", name = "onedark", description = "Atom One Dark inspired", colorscheme = "onedark" },
      { repo = "nyoom-engineering/oxocarbon.nvim", name = "oxocarbon", description = "IBM Carbon design inspired", colorscheme = "oxocarbon" },
      { repo = "sainnhe/sonokai", name = "sonokai", description = "Monokai Pro inspired", colorscheme = "sonokai" },
      { repo = "marko-cerovac/material.nvim", name = "material", description = "Material design colors", colorscheme = "material" },
      { repo = "sainnhe/edge", name = "edge", description = "Clean and elegant", colorscheme = "edge" },
    },
  },
}
```

- [ ] **Step 2: Create theme-picker config module**

```lua
-- lua/plugins/ui/config/theme-picker.lua
local notify = require("core.lib.notify")
local data = require("core.lib.data")
local paths = require("core.lib.paths")

local M = {}

local _opts = {}
local _buf = nil
local _win = nil
local _cursor_line = 1
local _items = {}
local _original_colorscheme = nil

-- Persistence

local function get_data_path()
  return paths.join(data.root(), "data", "installed-themes.json")
end

local function get_dynamic_specs_dir()
  return paths.join(data.root(), "data", "dynamic-specs")
end

local function load_installed()
  local path = get_data_path()
  local file = io.open(path, "r")
  if not file then
    return {}
  end
  local content = file:read("*a")
  file:close()

  local ok, result = pcall(vim.json.decode, content)
  if not ok or type(result) ~= "table" then
    return {}
  end
  return result
end

local function save_installed(installed_names)
  local path = get_data_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local file = io.open(path, "w")
  if not file then
    notify.error("Failed to save installed themes")
    return false
  end
  file:write(vim.json.encode(installed_names))
  file:close()
  return true
end

local function write_dynamic_spec(theme)
  local dir = get_dynamic_specs_dir()
  vim.fn.mkdir(dir, "p")
  local path = paths.join(dir, "theme-" .. theme.name .. ".lua")
  local file = io.open(path, "w")
  if not file then
    return false
  end
  file:write('return {\n')
  file:write('  source = "' .. theme.repo .. '",\n')
  file:write('  lazy = { lazy = true, priority = 1000 },\n')
  file:write('}\n')
  file:close()
  return true
end

local function delete_dynamic_spec(theme_name)
  local path = paths.join(get_dynamic_specs_dir(), "theme-" .. theme_name .. ".lua")
  os.remove(path)
end

-- Theme lookup

local function find_theme(name)
  for _, t in ipairs(_opts.default_themes or {}) do
    if t.name == name then return t end
  end
  for _, t in ipairs(_opts.optional_themes or {}) do
    if t.name == name then return t end
  end
  return nil
end

-- Preview

local function preview_apply(colorscheme)
  local ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
  if not ok then
    notify.warn("Failed to preview: " .. colorscheme)
  end
end

local function preview_restore()
  if _original_colorscheme then
    pcall(vim.cmd, "colorscheme " .. _original_colorscheme)
  end
end

-- UI

local function get_installed_themes()
  local installed = {}
  for _, theme in ipairs(_opts.default_themes or {}) do
    table.insert(installed, { theme = theme, is_default = true })
  end
  local user_installed = load_installed()
  for _, name in ipairs(user_installed) do
    local theme = find_theme(name)
    if theme then
      table.insert(installed, { theme = theme, is_default = false })
    end
  end
  return installed
end

local function get_available_themes()
  local user_installed = load_installed()
  local installed_set = {}
  for _, name in ipairs(user_installed) do
    installed_set[name] = true
  end

  local available = {}
  for _, theme in ipairs(_opts.optional_themes or {}) do
    if not installed_set[theme.name] then
      table.insert(available, theme)
    end
  end
  return available
end

local function build_items()
  _items = {}
  local current = vim.g.colors_name or ""

  table.insert(_items, { type = "header", text = "  INSTALLED" })

  local installed = get_installed_themes()
  for _, entry in ipairs(installed) do
    local prefix = "    "
    if entry.theme.colorscheme == current or
        (entry.theme.variants and vim.tbl_contains(entry.theme.variants, current)) then
      prefix = "  * "
    end
    table.insert(_items, {
      type = "installed",
      theme = entry.theme,
      is_default = entry.is_default,
      text = prefix .. entry.theme.name,
    })
  end

  table.insert(_items, { type = "separator", text = "" })
  table.insert(_items, { type = "header", text = "  AVAILABLE" })

  local available = get_available_themes()
  if #available == 0 then
    table.insert(_items, { type = "empty", text = "    (all themes installed)" })
  else
    for _, theme in ipairs(available) do
      local desc = theme.description or ""
      if #desc > 25 then
        desc = desc:sub(1, 22) .. "..."
      end
      table.insert(_items, {
        type = "available",
        theme = theme,
        text = string.format("    %-14s %s", theme.name, desc),
      })
    end
  end
end

local function render()
  if not _buf or not vim.api.nvim_buf_is_valid(_buf) then return end

  vim.bo[_buf].modifiable = true
  local lines = {}
  for _, item in ipairs(_items) do
    table.insert(lines, item.text)
  end
  table.insert(lines, "")
  table.insert(lines, "  [Enter] Apply  [x] Uninstall  [q] Close")

  vim.api.nvim_buf_set_lines(_buf, 0, -1, false, lines)
  vim.bo[_buf].modifiable = false

  if _win and vim.api.nvim_win_is_valid(_win) then
    vim.api.nvim_win_set_cursor(_win, { _cursor_line, 0 })
  end
end

local function find_first_selectable()
  for i, item in ipairs(_items) do
    if item.type == "installed" or item.type == "available" then
      return i
    end
  end
  return 1
end

local function move_cursor(direction)
  local new_line = _cursor_line + direction
  while new_line >= 1 and new_line <= #_items do
    local item = _items[new_line]
    if item.type == "installed" or item.type == "available" then
      _cursor_line = new_line
      if _win and vim.api.nvim_win_is_valid(_win) then
        vim.api.nvim_win_set_cursor(_win, { _cursor_line, 0 })
      end
      if item.type == "installed" then
        preview_apply(item.theme.colorscheme)
      end
      return
    end
    new_line = new_line + direction
  end
end

local function close()
  if _win and vim.api.nvim_win_is_valid(_win) then
    vim.api.nvim_win_close(_win, true)
  end
  if _buf and vim.api.nvim_buf_is_valid(_buf) then
    vim.api.nvim_buf_delete(_buf, { force = true })
  end
  _win = nil
  _buf = nil
end

local function on_select()
  local item = _items[_cursor_line]
  if not item then return end

  if item.type == "installed" then
    preview_apply(item.theme.colorscheme)
    _original_colorscheme = vim.g.colors_name
    close()
  elseif item.type == "available" then
    local installed = load_installed()
    table.insert(installed, item.theme.name)
    save_installed(installed)
    write_dynamic_spec(item.theme)
    build_items()
    _cursor_line = find_first_selectable()
    render()
    notify.info(item.theme.name .. " added. Restart LuxVim to activate.")
  end
end

local function on_uninstall()
  local item = _items[_cursor_line]
  if not item or item.type ~= "installed" then return end

  if item.is_default then
    notify.warn("Cannot uninstall default theme")
    return
  end

  local installed = load_installed()
  local new_list = {}
  for _, n in ipairs(installed) do
    if n ~= item.theme.name then
      table.insert(new_list, n)
    end
  end
  save_installed(new_list)
  delete_dynamic_spec(item.theme.name)
  notify.info("Removed " .. item.theme.name .. ". Run :Lazy clean to delete files.")
  build_items()
  _cursor_line = find_first_selectable()
  render()
end

local function open()
  _original_colorscheme = vim.g.colors_name
  build_items()

  local width = 50
  local height = #_items + 3
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  _buf = vim.api.nvim_create_buf(false, true)

  _win = vim.api.nvim_open_win(_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Themes ",
    title_pos = "center",
  })

  vim.bo[_buf].bufhidden = "wipe"
  vim.wo[_win].cursorline = true

  _cursor_line = find_first_selectable()
  render()

  local opts = { buffer = _buf, silent = true }
  vim.keymap.set("n", "j", function() move_cursor(1) end, opts)
  vim.keymap.set("n", "k", function() move_cursor(-1) end, opts)
  vim.keymap.set("n", "<Down>", function() move_cursor(1) end, opts)
  vim.keymap.set("n", "<Up>", function() move_cursor(-1) end, opts)
  vim.keymap.set("n", "<CR>", on_select, opts)
  vim.keymap.set("n", "x", on_uninstall, opts)
  vim.keymap.set("n", "q", function() preview_restore(); close() end, opts)
  vim.keymap.set("n", "<Esc>", function() preview_restore(); close() end, opts)

  if _items[_cursor_line] and _items[_cursor_line].type == "installed" then
    preview_apply(_items[_cursor_line].theme.colorscheme)
  end
end

function M.setup(opts)
  _opts = opts or {}

  vim.api.nvim_create_user_command("Themes", function()
    open()
  end, { desc = "Open theme picker" })
end

return M
```

- [ ] **Step 3: Delete old theme picker**

```bash
rm -rf lua/core/theme-picker/
```

- [ ] **Step 4: Launch and verify**

Run: `lux`

Expected: LuxVim starts. Run `:Themes` — the theme picker modal opens. Navigate with j/k. Press Enter on an installed theme to apply. Press q to close and restore. Press Enter on an available theme to install (writes to `data/dynamic-specs/`). Check `:LuxVimErrors` for no errors.

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/ui/theme-picker.lua lua/plugins/ui/config/theme-picker.lua && git rm -rf lua/core/theme-picker/
git commit -m "feat: rebuild theme picker as framework plugin"
```

---

### Task 13: Dead Code Removal + Typegen Update + Final Verification

Delete parallux.lua. Update typegen.lua to use schema.get(). Run final comprehensive verification.

**Files:**
- Delete: `lua/plugins/lib/parallux.lua`
- Modify: `lua/core/lib/typegen.lua`

- [ ] **Step 1: Delete parallux.lua**

```bash
rm lua/plugins/lib/parallux.lua
```

- [ ] **Step 2: Update typegen.lua to use schema.get()**

In `lua/core/lib/typegen.lua`, change line 1 from:

```lua
local schema = require("core.lib.schema")
```

to the same import (unchanged), but update `M.generate()` to use `schema.get()`:

Replace the `M.generate()` function body — change `schema.build_spec` to `schema.get("build_spec")`, `schema.plugin_spec` to `schema.get("plugin_spec")`, etc.:

```lua
function M.generate()
  local output = {
    "-- lua/types/plugin.lua",
    "-- GENERATED FILE - DO NOT EDIT",
    "-- Run :LuxVimGenerateTypes to regenerate",
    "",
  }

  table.insert(output, generate_class("BuildSpec", schema.get("build_spec")))
  table.insert(output, "")
  table.insert(output, generate_class("PluginSpec", schema.get("plugin_spec")))
  table.insert(output, "")
  table.insert(output, generate_class("KeymapEntry", schema.get("keymap_entry")))
  table.insert(output, "")
  table.insert(output, generate_class("AutocmdEntry", schema.get("autocmd_entry")))

  return table.concat(output, "\n")
end
```

- [ ] **Step 3: Launch and full verification**

Run: `lux`

Verify each of these:
1. LuxVim starts with no errors — `:LuxVimErrors` shows clean
2. All keymaps work: `<leader>fs` (save), `<leader>fq` (quit), `<leader><leader>` (fzf files), `<leader>st` (Rg search), `<leader>e` (tree toggle), `<C-/>` (terminal)
3. `:Themes` opens the theme picker, navigation works, q closes
4. `:LuxDevStatus` shows debug status
5. `:LuxVimGenerateTypes` generates types without error
6. `:Lazy` shows all plugins loaded

- [ ] **Step 4: Headless smoke test**

Run: `lux --headless "+Lazy! sync" +qa`

Expected: exits with code 0.

- [ ] **Step 5: Commit**

```bash
git rm lua/plugins/lib/parallux.lua && git add lua/core/lib/typegen.lua
git commit -m "chore: remove dead code, update typegen for schema registry"
```

---

## Implementation Order Summary

| Task | Description | Dependencies |
|------|-------------|--------------|
| 1 | Schema Registry API | None |
| 2 | Validation Updates | Task 1 |
| 3 | Pipeline Orchestrator | None |
| 4 | Discover Stage | Task 3 |
| 5 | Load Stage | Task 3 |
| 6 | Validate Stage | Task 3 |
| 7 | Transform Stage | Task 3 |
| 8 | Wire Pipeline + Delete Loader | Tasks 1-7 |
| 9 | Action Registry Refactor | Task 8 |
| 10 | Autocmd Callback + Cleanup | Task 9 |
| 11 | User Config Layer | Task 8 |
| 12 | Theme Picker Plugin | Tasks 8, 11 |
| 13 | Dead Code + Final Verification | Tasks 9-12 |

Tasks 3-7 can be done in parallel (no interdependencies). Task 11 can run in parallel with Tasks 9-10 after Task 8 is complete.
