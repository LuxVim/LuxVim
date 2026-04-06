# Core Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate duplication in the registry system, standardize APIs, and harden the core framework for extensibility.

**Architecture:** Extract a registry base module that encapsulates the load → merge → register lifecycle. Refactor keymaps, autocmds, and filetypes to use it. Standardize keymap entries to list format. Remove the dynamic require fallback from actions. Add pipeline early exit on critical errors.

**Tech Stack:** Lua, Neovim API

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lua/core/lib/registry.lua` | Create | Factory module: load framework + user registries, merge with replaces/extends, delegate to register function |
| `lua/core/registry/keymaps.lua` | Modify | Migrate dict-style sections to list format |
| `lua/core/lib/keymap.lua` | Modify | Thin wrapper using registry.new(), simplified register_one() |
| `lua/core/lib/autocmd.lua` | Modify | Two registry instances, remove duplicated merge logic |
| `lua/core/lib/actions.lua` | Modify | Remove dynamic require() fallback |
| `lua/core/lib/pipeline.lua` | Modify | Add early exit on critical errors |

---

### Task 1: Create Registry Base Module

**Files:**
- Create: `lua/core/lib/registry.lua`

- [ ] **Step 1: Create `lua/core/lib/registry.lua`**

```lua
local notify = require("core.lib.notify")
local data = require("core.lib.data")
local paths = require("core.lib.paths")

local M = {}

local function merge(framework, user)
  if user.replaces then
    user.replaces = nil
    return user
  end

  if user.extends then
    user.extends = nil
    local merged = vim.deepcopy(framework)
    for key, value in pairs(user) do
      if merged[key] then
        if type(merged[key]) == "table" and type(value) == "table" then
          merged[key] = vim.tbl_deep_extend("force", merged[key], value)
        else
          merged[key] = value
        end
      else
        merged[key] = value
      end
    end
    return merged
  end

  return framework
end

function M.new(config)
  local instance = {
    name = config.name,
    framework_module = config.framework_module,
    user_file = config.user_file,
    register = config.register,
  }

  function instance:load()
    local ok, framework = pcall(require, self.framework_module)
    if not ok then
      notify.warn("Failed to load " .. self.name .. " registry: " .. tostring(framework))
      return nil
    end

    local user_path = paths.join(data.user_config_path(), self.user_file)
    if vim.uv.fs_stat(user_path) then
      local uok, user = pcall(dofile, user_path)
      if uok and type(user) == "table" then
        return merge(framework, user)
      end
    end

    return framework
  end

  function instance:setup()
    local entries = self:load()
    if entries then
      self.register(entries)
    end
  end

  return instance
end

return M
```

- [ ] **Step 2: Verify the file loads without errors**

Run: `lux --headless -c "lua require('core.lib.registry'); print('ok')" +qa`
Expected: prints "ok" with no errors.

- [ ] **Step 3: Commit**

```bash
git add lua/core/lib/registry.lua
git commit -m "feat(core): add registry base module with load/merge/setup lifecycle"
```

---

### Task 2: Migrate Keymaps Registry to List Format

**Files:**
- Modify: `lua/core/registry/keymaps.lua`

- [ ] **Step 1: Rewrite `lua/core/registry/keymaps.lua` to list format**

Replace the entire file with:

```lua
local navigation = {}
for i = 1, 6 do
  table.insert(navigation, { lhs = "<leader>" .. i, action = "core.win" .. i, desc = "Go to window " .. i })
end
table.insert(navigation, { lhs = "<leader>wv", action = "core.vsplit", desc = "Vertical split" })
table.insert(navigation, { lhs = "<leader>wh", action = "core.hsplit", desc = "Horizontal split" })

return {
  editor = {
    { lhs = "<leader>fs", action = "core.save", desc = "Save file" },
    { lhs = "<leader>fq", action = "core.quit", desc = "Quit" },
    { lhs = "<leader>FQ", action = "core.force_quit", desc = "Force quit" },
    { lhs = "<leader>bye", action = "core.quit_all", desc = "Quit all" },
    { lhs = "<leader><leader>", action = "fzf.vim.files", desc = "Find files" },
    { lhs = "<leader>st", action = "fzf.vim.search_text", desc = "Search text" },
  },

  navigation = navigation,

  ui = {
    { lhs = "<leader>e", action = "nvim-tree.toggle", desc = "File explorer" },
  },

  terminal = {
    { lhs = "<C-/>", action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    { lhs = "<C-_>", action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    { lhs = "<C-`>", action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    { lhs = "<C-/>", action = "nvim-luxterm.toggle_from_terminal", desc = "Toggle terminal", mode = "t" },
    { lhs = "<C-_>", action = "nvim-luxterm.toggle_from_terminal", desc = "Toggle terminal", mode = "t" },
    { lhs = "<C-`>", action = "nvim-luxterm.toggle_from_terminal", desc = "Toggle terminal", mode = "t" },
    { lhs = "<C-n>", action = "nvim-luxterm.exit_terminal_mode", desc = "Exit terminal mode", mode = "t" },
  },
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/core/registry/keymaps.lua
git commit -m "refactor(registry): migrate keymaps to list format"
```

---

### Task 3: Refactor Keymap Module to Use Registry Base

**Files:**
- Modify: `lua/core/lib/keymap.lua`

- [ ] **Step 1: Rewrite `lua/core/lib/keymap.lua`**

Replace the entire file with:

```lua
local actions = require("core.lib.actions")
local registry = require("core.lib.registry")

local M = {}

function M.register_one(mapping)
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
      vim.keymap.set(m, mapping.lhs, rhs, opts)
    end
  else
    vim.keymap.set(mode, mapping.lhs, rhs, opts)
  end
end

local function register_all(entries)
  for section_name, section in pairs(entries) do
    for _, mapping in ipairs(section) do
      M.register_one(mapping)
    end
  end
end

local keymap_registry = registry.new({
  name = "keymaps",
  framework_module = "core.registry.keymaps",
  user_file = "registry/keymaps.lua",
  register = register_all,
})

function M.setup()
  keymap_registry:setup()
end

return M
```

- [ ] **Step 2: Validate keymaps work**

Run: `lux`
Test: Press `<leader>fs` to save, `<leader>e` to toggle file explorer, `<C-/>` to toggle terminal. Confirm all bindings work.
Run: `:LuxVimErrors`
Expected: No errors related to keymaps.

- [ ] **Step 3: Commit**

```bash
git add lua/core/lib/keymap.lua
git commit -m "refactor(keymap): use registry base module, list-only format"
```

---

### Task 4: Refactor Autocmd Module to Use Registry Base

**Files:**
- Modify: `lua/core/lib/autocmd.lua`

- [ ] **Step 1: Rewrite `lua/core/lib/autocmd.lua`**

Replace the entire file with:

```lua
local actions = require("core.lib.actions")
local registry = require("core.lib.registry")

local M = {}

local augroup = vim.api.nvim_create_augroup("LuxVimCore", { clear = true })

local function register_autocmds(entries)
  for event, config in pairs(entries) do
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
  end
end

local function register_filetypes(entries)
  for ft, settings in pairs(entries) do
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

local autocmd_registry = registry.new({
  name = "autocmds",
  framework_module = "core.registry.autocmds",
  user_file = "registry/autocmds.lua",
  register = register_autocmds,
})

local filetype_registry = registry.new({
  name = "filetypes",
  framework_module = "core.registry.filetypes",
  user_file = "registry/filetypes.lua",
  register = register_filetypes,
})

function M.setup()
  autocmd_registry:setup()
  filetype_registry:setup()
end

return M
```

- [ ] **Step 2: Validate autocmds and filetypes work**

Run: `lux`
Test: Open a Python file (`:e test.py`) — confirm `tabstop` is 4 (`set tabstop?`), `colorcolumn` is 88 (`set colorcolumn?`).
Test: Open a Lua file (`:e test.lua`) — confirm `tabstop` is 2.
Test: Open fzf (`:FZF`) — confirm laststatus hides. Close it — confirm laststatus restores.
Run: `:LuxVimErrors`
Expected: No errors related to autocmds or filetypes.

- [ ] **Step 3: Commit**

```bash
git add lua/core/lib/autocmd.lua
git commit -m "refactor(autocmd): use registry base module, split into two registry instances"
```

---

### Task 5: Remove Dynamic Require Fallback from Actions

**Files:**
- Modify: `lua/core/lib/actions.lua`

- [ ] **Step 1: Edit `lua/core/lib/actions.lua` — remove the fallback require block from `resolve()`**

In the `resolve()` function, remove lines 52-56 (the `pcall(require, namespace)` fallback). The function should become:

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

- [ ] **Step 2: Validate actions still resolve**

Run: `lux`
Test: Press `<leader>fs` (core.save), `<leader>e` (nvim-tree.toggle), `<C-/>` (nvim-luxterm.toggle). All should work — these are all explicitly registered via plugin specs.
Run: `:LuxVimErrors`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lua/core/lib/actions.lua
git commit -m "refactor(actions): remove dynamic require fallback, single resolution path"
```

---

### Task 6: Add Pipeline Early Exit on Critical Errors

**Files:**
- Modify: `lua/core/lib/pipeline.lua`

- [ ] **Step 1: Edit `lua/core/lib/pipeline.lua` — add early exit check in `run()`**

Replace the stage loop in the `run()` function. The full updated `run()` function:

```lua
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

    local critical = vim.tbl_filter(function(e)
      return e.level == "critical"
    end, context.errors)
    if #critical > 0 then
      break
    end
  end

  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, context.errors)

  context.ok = #critical == 0
  context.raw_specs = context.specs
  return context
end
```

- [ ] **Step 2: Validate normal boot still works**

Run: `lux`
Run: `:LuxVimErrors`
Expected: No errors — the early exit only triggers on critical errors, which don't occur during normal boot.

- [ ] **Step 3: Commit**

```bash
git add lua/core/lib/pipeline.lua
git commit -m "refactor(pipeline): add early exit on critical errors"
```

---

### Task 7: Final Validation

- [ ] **Step 1: Full validation**

Run: `lux`
Verify:
1. All keybindings work (`<leader>fs`, `<leader>e`, `<leader><leader>`, `<C-/>`, `<leader>st`)
2. Filetype options apply (open .py, .lua, .md files, check tabstop/shiftwidth/spell)
3. Autocmds fire (open fzf, check laststatus hides/restores)
4. `:LuxVimErrors` shows no errors
5. `:LuxDevStatus` works
6. `:Lazy` shows plugins loaded correctly

- [ ] **Step 2: Sync plugins headless**

Run: `lux --headless "+Lazy! sync" +qa`
Expected: Exits cleanly with no errors.
