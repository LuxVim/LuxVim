# Core Hardening: Clean Architecture Refactor

**Date:** 2026-04-06
**Scope:** `core/lib/` and `core/registry/` (excludes theme picker)
**Goal:** Eliminate duplication, standardize APIs, and establish a registry contract that makes the framework easier to extend.

## 1. Registry Base Module

**New file:** `core/lib/registry.lua`

A factory function `registry.new(config)` returns a registry instance with built-in load, merge, and setup lifecycle. Config fields:

- `name` — identifier (e.g., `"keymaps"`)
- `framework_module` — `require()` path to the framework registry (e.g., `"core.registry.keymaps"`)
- `user_file` — relative path under user config (e.g., `"registry/keymaps.lua"`)
- `register(entries)` — type-specific function that does the actual vim API calls

### Lifecycle

1. **Load** — `pcall(require, framework_module)` for framework registry, then `fs_stat` + `pcall(dofile)` for user registry file
2. **Merge** — single implementation of replaces/extends semantics:
   - User returns `{ replaces = true, ... }` → user table wins entirely
   - User returns `{ extends = true, ... }` → deep merge (user overrides framework)
   - No user file → framework only
3. **Register** — calls the provided `register(entries)` with merged result
4. **setup()** — runs load → merge → register in sequence

### Merge Contract

The replaces/extends flags are stripped before passing data to `register()`. The merge function handles section-level merging: for each section in the user registry, if a matching section exists in the framework registry, `vim.tbl_deep_extend("force", framework_section, user_section)` is used. New sections from the user are added directly.

## 2. Keymap Format Standardization

Migrate `core/registry/keymaps.lua` from mixed dict/list format to **list-only**. Every entry becomes a self-contained record with an explicit `lhs` field:

```lua
-- Before (dict style)
editor = {
  ["<leader>fs"] = { action = "core.save", desc = "Save file" },
}

-- After (list style)
editor = {
  { lhs = "<leader>fs", action = "core.save", desc = "Save file" },
}
```

The `register_one()` function simplifies — `lhs` comes from `mapping.lhs`, no separate parameter needed. The dual-format iteration (`#section > 0` check, `goto` statements) is replaced with a single `ipairs` loop.

## 3. Actions Cleanup

Remove the dynamic `require()` fallback from `actions.resolve()`. Resolution becomes a single path: look up `namespace.method` in the action registry. If not found, return an error.

The `split_action()` function retains its longest-prefix matching logic for namespace resolution. The simple dot-split fallback stays as a parsing mechanism for unregistered namespaces — it just flows into a "not found" error instead of attempting a dynamic `require()`.

```lua
function M.resolve(action_string)
  local namespace, method = split_action(action_string)
  if not namespace or not method then
    return nil, "invalid action format: " .. action_string
  end
  if M._registry[namespace] and M._registry[namespace][method] then
    return M._registry[namespace][method]
  end
  return nil, "unregistered action: " .. action_string
end
```

## 4. Pipeline Early Exit

Add early exit to `pipeline.run()` when a stage produces a critical error. After each stage executes (including its post-hooks), check for critical errors. If found, break the loop — subsequent stages and their hooks are skipped.

The existing `context.ok` assignment at the end of `run()` stays unchanged for the caller's benefit.

```lua
for _, stage in ipairs(_stages) do
  context = run_hooks("pre_" .. stage.name, context)
  context = stage.fn(context)
  context = run_hooks("post_" .. stage.name, context)

  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, context.errors)
  if #critical > 0 then
    break
  end
end
```

## 5. Autocmd Module Simplification

Split `autocmd.lua` into two distinct registry instances using the new base module:

- **Autocmds registry** — `registry.new()` with `register_autocmds()` as its register function, loading from `core.registry.autocmds` and user's `registry/autocmds.lua`
- **Filetypes registry** — `registry.new()` with `register_filetypes()` as its register function, loading from `core.registry.filetypes` and user's `registry/filetypes.lua`

The `register_autocmds()` and `register_filetypes()` functions keep their current vim API logic. The augroup stays local to this module.

`setup()` becomes two calls:

```lua
function M.setup()
  autocmd_registry:setup()
  filetype_registry:setup()
end
```

## File Change Summary

| File | Change |
|---|---|
| `core/lib/registry.lua` | **New** — factory module with load/merge/setup lifecycle |
| `core/lib/keymap.lua` | Thin wrapper using `registry.new()`, simplified `register_one()` |
| `core/lib/autocmd.lua` | Two registry instances, remove duplicated merge logic |
| `core/lib/actions.lua` | Remove dynamic `require()` fallback |
| `core/lib/pipeline.lua` | Early exit on critical errors |
| `core/registry/keymaps.lua` | Dict sections migrated to list format |

**Not touched:** schema.lua, validate.lua, bootstrap.lua, pipeline stages, plugin specs, theme picker, init.lua, core/init.lua, config/options.lua.

## Migration Impact

The keymaps.lua format change is the only breaking change for users with a custom `registry/keymaps.lua` in their user config. Dict-style entries must become list-style. This is a one-time migration.
