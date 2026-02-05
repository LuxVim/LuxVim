# Windows Compatibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make LuxVim work reliably on Windows PowerShell, including paths with spaces.

**Architecture:** Create a centralized paths.lua module that normalizes all paths to forward slashes (which Neovim handles on all platforms). Update all 24+ path concatenation sites to use this module. Replace the broken install.ps1 with a working version.

**Tech Stack:** Lua, PowerShell, Bash

---

## Task 1: Create paths.lua Module

**Files:**
- Create: `lua/core/lib/paths.lua`

**Step 1: Create the paths utility module**

```lua
local M = {}

M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

function M.normalize(path)
  if not path then
    return nil
  end
  path = path:gsub("\\", "/"):gsub("/+", "/")
  if path:sub(-1) == "/" then
    return path:sub(1, -2)
  end
  return path
end

function M.join(...)
  local parts = { ... }
  local filtered = vim.tbl_filter(function(p)
    return p and p ~= ""
  end, parts)
  return M.normalize(table.concat(filtered, "/"))
end

function M.basename(path)
  if not path then
    return nil
  end
  return M.normalize(path):match("([^/]+)$")
end

return M
```

**Step 2: Verify module loads**

Run: `lux --headless -c "print(require('core.lib.paths').join('a', 'b', 'c'))" +qa`
Expected: `a/b/c`

**Step 3: Commit**

```bash
git add lua/core/lib/paths.lua
git commit -m "feat: add cross-platform path utilities module"
```

---

## Task 2: Update debug.lua

**Files:**
- Modify: `lua/core/lib/debug.lua`

**Step 1: Add paths require and update get_luxvim_root**

Replace entire file with:

```lua
local paths = require("core.lib.paths")

local M = {}

local _luxvim_root = nil

function M.get_luxvim_root()
  if _luxvim_root then
    return _luxvim_root
  end

  local info = debug.getinfo(1, "S")
  if info and info.source and info.source:sub(1, 1) == "@" then
    local this_file = info.source:sub(2)
    _luxvim_root = paths.normalize(vim.fn.fnamemodify(this_file, ":p:h:h:h:h"))
    if vim.fn.isdirectory(paths.join(_luxvim_root, "debug")) == 1 then
      return _luxvim_root
    end
  end

  for _, path in ipairs(vim.opt.runtimepath:get()) do
    local normalized = paths.normalize(path)
    if vim.fn.isdirectory(paths.join(normalized, "debug")) == 1
        and vim.fn.filereadable(paths.join(normalized, "init.lua")) == 1 then
      _luxvim_root = normalized
      return _luxvim_root
    end
  end

  _luxvim_root = paths.normalize(vim.fn.getcwd())
  return _luxvim_root
end

function M.extract_plugin_name(source)
  return paths.basename(source)
end

function M.get_debug_path(plugin_name)
  return paths.join(M.get_luxvim_root(), "debug", plugin_name)
end

function M.has_debug_plugin(plugin_name)
  local debug_path = M.get_debug_path(plugin_name)
  local stat = vim.uv.fs_stat(debug_path)
  if not stat or stat.type ~= "directory" then
    return false
  end

  local plugin_dir = paths.join(debug_path, "plugin")
  local lua_dir = paths.join(debug_path, "lua")
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
  local debug_dir = paths.join(M.get_luxvim_root(), "debug")
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

**Step 2: Verify debug module loads**

Run: `lux --headless -c "print(require('core.lib.debug').get_luxvim_root())" +qa`
Expected: Path to LuxVim directory with forward slashes

**Step 3: Commit**

```bash
git add lua/core/lib/debug.lua
git commit -m "refactor: use paths module in debug.lua for cross-platform support"
```

---

## Task 3: Update loader.lua

**Files:**
- Modify: `lua/core/lib/loader.lua`

**Step 1: Add paths require at top of file**

After line 3 (`local conditions = require("core.registry.conditions")`), add:

```lua
local paths = require("core.lib.paths")
```

**Step 2: Update get_plugin_dirs function (lines 12-33)**

Replace the function with:

```lua
function M.get_plugin_dirs()
  local root = debug_mod.get_luxvim_root()
  local plugins_dir = paths.join(root, "lua", "plugins")
  local dirs = {}

  local handle = vim.uv.fs_scandir(plugins_dir)
  if not handle then
    table.insert(M._errors, {
      level = "critical",
      file = "core.lib.loader",
      message = "Plugin directory not found: " .. plugins_dir ..
          "\nLuxVim root detected as: " .. root ..
          "\nLaunch LuxVim from its directory or check installation.",
    })
    return dirs
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if type == "directory" then
      table.insert(dirs, { name = name, path = paths.join(plugins_dir, name) })
    end
  end

  return dirs
end
```

**Step 3: Update load_category_defaults function (line 36)**

Change:
```lua
local defaults_path = category_path .. "/_defaults.lua"
```
To:
```lua
local defaults_path = paths.join(category_path, "_defaults.lua")
```

**Step 4: Update load_plugin_specs function (line 63)**

Change:
```lua
local file_path = category_path .. "/" .. name
```
To:
```lua
local file_path = paths.join(category_path, name)
```

**Step 5: Verify loader works**

Run: `lux --headless -c "print(vim.inspect(require('core.lib.loader').get_plugin_dirs()))" +qa`
Expected: List of plugin directories with forward-slash paths

**Step 6: Commit**

```bash
git add lua/core/lib/loader.lua
git commit -m "refactor: use paths module in loader.lua with error reporting"
```

---

## Task 4: Update bootstrap.lua

**Files:**
- Modify: `lua/core/lib/bootstrap.lua`

**Step 1: Replace entire file**

```lua
local debug_mod = require("core.lib.debug")
local paths = require("core.lib.paths")

local M = {}

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

**Step 2: Verify bootstrap paths**

Run: `lux --headless -c "print(require('core.lib.bootstrap').get_lazy_path())" +qa`
Expected: Path with forward slashes ending in `data/lazy/lazy.nvim`

**Step 3: Commit**

```bash
git add lua/core/lib/bootstrap.lua
git commit -m "refactor: use paths module in bootstrap.lua"
```

---

## Task 5: Update actions.lua

**Files:**
- Modify: `lua/core/lib/actions.lua`

**Step 1: Add paths require at top**

After line 1 (`local M = {}`), add:

```lua
local paths = require("core.lib.paths")
```

**Step 2: Update register_from_spec function (line 17)**

Change:
```lua
local plugin_name = spec.debug_name or spec.source:match("([^/]+)$")
```
To:
```lua
local plugin_name = spec.debug_name or paths.basename(spec.source)
```

**Step 3: Commit**

```bash
git add lua/core/lib/actions.lua
git commit -m "refactor: use paths.basename in actions.lua"
```

---

## Task 6: Update typegen.lua

**Files:**
- Modify: `lua/core/lib/typegen.lua`

**Step 1: Add paths require at top**

After line 2 (`local debug_mod = require("core.lib.debug")`), add:

```lua
local paths = require("core.lib.paths")
```

**Step 2: Update write function (lines 69-71)**

Change:
```lua
local root = debug_mod.get_luxvim_root()
local types_dir = root .. "/lua/types"
local output_path = types_dir .. "/plugin.lua"
```
To:
```lua
local root = debug_mod.get_luxvim_root()
local types_dir = paths.join(root, "lua", "types")
local output_path = paths.join(types_dir, "plugin.lua")
```

**Step 3: Commit**

```bash
git add lua/core/lib/typegen.lua
git commit -m "refactor: use paths module in typegen.lua"
```

---

## Task 7: Update persistence.lua

**Files:**
- Modify: `lua/core/theme-picker/persistence.lua`

**Step 1: Add paths require and update get_data_path**

Replace lines 1-9 with:

```lua
local paths = require("core.lib.paths")

local M = {}

local function get_data_path()
  local luxvim_dir = vim.fn.expand("~/.local/share/LuxVim")
  if vim.env.XDG_DATA_HOME then
    luxvim_dir = paths.join(vim.env.XDG_DATA_HOME, "LuxVim")
  end
  return paths.join(luxvim_dir, "data", "installed-themes.lua")
end
```

**Step 2: Commit**

```bash
git add lua/core/theme-picker/persistence.lua
git commit -m "refactor: use paths module in theme persistence"
```

---

## Task 8: Update treesitter.lua

**Files:**
- Modify: `lua/plugins/editor/treesitter.lua`

**Step 1: Update config function to use paths**

Replace entire file with:

```lua
return {
  source = "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  lazy = {
    lazy = false,
    priority = 900,
  },
  config = function()
    local paths = require("core.lib.paths")
    local data_dir = vim.env.XDG_DATA_HOME or vim.fn.stdpath("data")
    local parser_install_dir = paths.join(data_dir, "data", "site")

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

**Step 2: Commit**

```bash
git add lua/plugins/editor/treesitter.lua
git commit -m "refactor: use paths module in treesitter config"
```

---

## Task 9: Update fzf.lua with Windows Build

**Files:**
- Modify: `lua/plugins/lib/fzf.lua`

**Step 1: Add Windows platform build command**

Replace entire file with:

```lua
return {
  source = "junegunn/fzf",
  build = {
    cmd = "./install --bin",
    platforms = {
      windows = "powershell -ExecutionPolicy Bypass -File .\\install.ps1",
    },
    requires = { "git" },
  },
}
```

**Step 2: Commit**

```bash
git add lua/plugins/lib/fzf.lua
git commit -m "feat: add Windows build command for fzf"
```

---

## Task 10: Update init.lua

**Files:**
- Modify: `init.lua`

**Step 1: Update package.path construction**

Replace entire file with:

```lua
-- **********************************************************
-- ********************* LUXVIM *****************************
-- **********************************************************

local current_dir = vim.fn.expand("<sfile>:p:h")
current_dir = current_dir:gsub("\\", "/")
vim.opt.runtimepath:prepend(current_dir)

local lua_dir = current_dir .. "/lua"
package.path = lua_dir .. "/?.lua;" .. lua_dir .. "/?/init.lua;" .. package.path

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

local core = require("core")
core.setup()
```

**Step 2: Verify LuxVim starts**

Run: `lux --headless "+Lazy! sync" +qa`
Expected: No errors, plugins sync successfully

**Step 3: Commit**

```bash
git add init.lua
git commit -m "refactor: normalize paths in init.lua for Windows"
```

---

## Task 11: Replace install.ps1

**Files:**
- Replace: `install.ps1`

**Step 1: Replace entire file**

```powershell
# **********************************************************
# ********************* LUXVIM INSTALLER *******************
# **********************************************************

$ErrorActionPreference = "Stop"

$LuxVimDir = $PSScriptRoot

Write-Host "Installing LuxVim..." -ForegroundColor Blue
Write-Host "LuxVim directory: $LuxVimDir" -ForegroundColor Yellow

# Check for nvim
if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
    Write-Host "Neovim is not installed. Please install Neovim first." -ForegroundColor Red
    Write-Host "Visit: https://neovim.io/" -ForegroundColor Yellow
    exit 1
}
Write-Host "Neovim found" -ForegroundColor Green

# Create data directories
$dataDirs = @("data\lazy", "data\mason", "data\nvim", "data\luxlsp")
foreach ($dir in $dataDirs) {
    $fullPath = Join-Path $LuxVimDir $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    }
}
Write-Host "Created data directories" -ForegroundColor Green

# Bootstrap lazy.nvim
$lazyPath = Join-Path $LuxVimDir "data\lazy\lazy.nvim"
if (-not (Test-Path $lazyPath)) {
    Write-Host "Bootstrapping lazy.nvim..." -ForegroundColor Blue
    git clone --filter=blob:none --branch=stable "https://github.com/folke/lazy.nvim.git" $lazyPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to clone lazy.nvim" -ForegroundColor Red
        exit 1
    }
    Write-Host "lazy.nvim installed" -ForegroundColor Green
} else {
    Write-Host "lazy.nvim already exists" -ForegroundColor Green
}

# Convert path to forward slashes for Neovim
$LuxVimDirForward = $LuxVimDir -replace '\\', '/'

# Create PowerShell launcher (lux.ps1)
$launcherPs1 = Join-Path $LuxVimDir "lux.ps1"
$ps1Content = @"
`$env:NVIM_APPNAME = "LuxVim"
& nvim --cmd "set rtp+=$LuxVimDirForward" -u "$LuxVimDir\init.lua" @args
"@
Set-Content -Path $launcherPs1 -Value $ps1Content -Encoding UTF8
Write-Host "Created lux.ps1" -ForegroundColor Green

# Create CMD launcher (lux.cmd)
$launcherCmd = Join-Path $LuxVimDir "lux.cmd"
$cmdContent = @"
@echo off
set "NVIM_APPNAME=LuxVim"
nvim --cmd "set rtp+=$LuxVimDirForward" -u "$LuxVimDir\init.lua" %*
"@
Set-Content -Path $launcherCmd -Value $cmdContent -Encoding ASCII
Write-Host "Created lux.cmd" -ForegroundColor Green

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To use LuxVim, either:" -ForegroundColor Yellow
Write-Host "  1. Add $LuxVimDir to your PATH, then run: lux" -ForegroundColor Cyan
Write-Host "  2. Run directly: & '$launcherPs1'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Running initial plugin sync..." -ForegroundColor Blue

# Initial sync
& $launcherPs1 --headless "+Lazy! sync" +qa

if ($LASTEXITCODE -eq 0) {
    Write-Host "All plugins installed! LuxVim is ready." -ForegroundColor Green
} else {
    Write-Host "Plugin sync completed with warnings. Run 'lux' to check status." -ForegroundColor Yellow
}
```

**Step 2: Commit**

```bash
git add install.ps1
git commit -m "fix: replace install.ps1 with working Windows installer"
```

---

## Task 12: Update install.sh (Remove sed)

**Files:**
- Modify: `install.sh`

**Step 1: Remove lines 76-90 (the sed-based config modification)**

Delete these lines:
```bash
# Update the lazy.nvim configuration to use our custom path
LAZY_CONFIG="$LUXVIM_DIR/lua/config/lazy.lua"
if [ -f "$LAZY_CONFIG" ]; then
    # Create a backup
    cp "$LAZY_CONFIG" "$LAZY_CONFIG.backup"

    # Update the lazy path to use our custom data directory (cross-platform)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i "" "s|local lazypath = vim.fn.stdpath(\"data\") .. \"/lazy/lazy.nvim\"|local lazypath = \"$LUXVIM_DATA_DIR/lazy/lazy.nvim\"|" "$LAZY_CONFIG"
    else
        sed -i "s|local lazypath = vim.fn.stdpath(\"data\") .. \"/lazy/lazy.nvim\"|local lazypath = \"$LUXVIM_DATA_DIR/lazy/lazy.nvim\"|" "$LAZY_CONFIG"
    fi

    echo -e "${GREEN}✅ Updated lazy.nvim configuration${NC}"
fi
```

**Step 2: Commit**

```bash
git add install.sh
git commit -m "refactor: remove sed-based config modification from install.sh"
```

---

## Task 13: Final Verification

**Step 1: Verify LuxVim starts correctly on Unix**

Run: `lux`
Expected: LuxVim starts with all plugins loaded

**Step 2: Check for errors**

Run: `:LuxVimErrors`
Expected: No critical errors

**Step 3: Check debug plugins**

Run: `:LuxDevStatus`
Expected: Shows debug plugins if any exist

**Step 4: Create final commit summarizing all changes**

```bash
git add -A
git commit -m "feat: complete Windows PowerShell compatibility

- Add cross-platform paths.lua utility module
- Update all path concatenations to use paths.join()
- Add error reporting when plugin directory not found
- Fix install.ps1 for Windows with proper path handling
- Add Windows build command for fzf
- Remove fragile sed-based config modification

Fixes: plugins not loading on Windows, pre-vimrc errors,
path issues with spaces in directory names"
```

---

## Testing Checklist

After implementation, verify on Windows:

- [ ] Install on Windows with spaces in path (e.g., `C:\Users\John Doe\LuxVim`)
- [ ] Run `.\install.ps1` completes without errors
- [ ] Launch from different directory (`cd C:\Projects; lux`)
- [ ] Verify plugins load (`:Lazy` shows plugins)
- [ ] Verify debug plugins detected (`:LuxDevStatus`)
- [ ] Test fzf installation (`:Lazy build fzf`)

After implementation, verify on Unix/macOS:

- [ ] Run `./install.sh` completes without errors
- [ ] Launch `lux` works correctly
- [ ] All plugins load (`:Lazy`)
- [ ] No regressions in functionality
