# Windows PowerShell Compatibility Design

**Date:** 2026-02-05
**Status:** Approved
**Scope:** Full Windows support - Lua path handling + PowerShell installer/launcher

## Problem Statement

LuxVim fails on Windows PowerShell with:
- Plugins not loading when launched from outside the repo directory
- Pre-vimrc errors related to path handling
- Failures when LuxVim is installed in directories with spaces

### Root Causes

1. **Path concatenation uses hardcoded `/`** - Creates mixed-separator paths on Windows (e.g., `C:\Users\John Doe\LuxVim/debug`)
2. **Silent plugin discovery failure** - When root detection fails, loader returns empty list with no error
3. **Broken install.ps1** - Uses Unix-style space escaping, PowerShell variables leak into batch output
4. **Root detection fallback to getcwd()** - When launched from different directory, wrong root is used

## Solution Architecture

```
Part A: Lua Path Handling
├── Create core/lib/paths.lua utility module
├── Update 24 path concatenation sites
├── Fix 2 pattern matching sites
└── Add error reporting for failed root detection

Part B: Windows Installation
├── Replace install.ps1 (PowerShell installer)
├── Create lux.ps1 launcher
├── Create lux.cmd launcher
└── Remove sed-based config modification from install.sh
```

## Part A: Lua Path Handling

### New Module: `lua/core/lib/paths.lua`

Centralized path utilities that normalize all paths to forward slashes (which Neovim handles on all platforms).

```lua
local M = {}

M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

function M.normalize(path)
  if not path then return nil end
  path = path:gsub("\\", "/"):gsub("/+", "/")
  return path:sub(-1) == "/" and path:sub(1, -2) or path
end

function M.join(...)
  local parts = {...}
  local filtered = vim.tbl_filter(function(p) return p and p ~= "" end, parts)
  return M.normalize(table.concat(filtered, "/"))
end

function M.basename(path)
  if not path then return nil end
  return M.normalize(path):match("([^/]+)$")
end

return M
```

### Files to Update

#### `lua/core/lib/debug.lua` (7 path sites + 1 pattern)

| Line | Before | After |
|------|--------|-------|
| 13 | `vim.fn.fnamemodify(this_file, ":p:h:h:h:h")` | `paths.normalize(vim.fn.fnamemodify(...))` |
| 14 | `_luxvim_root .. "/debug"` | `paths.join(_luxvim_root, "debug")` |
| 20 | `path .. "/debug"` and `path .. "/init.lua"` | `paths.join(path, "debug")` etc. |
| 31 | `source:match("([^/]+)$")` | `paths.basename(source)` |
| 35 | `.. "/debug/" .. plugin_name` | `paths.join(..., "debug", plugin_name)` |
| 45-46 | `debug_path .. "/plugin"` | `paths.join(debug_path, "plugin")` |
| 62 | `.. "/debug"` | `paths.join(..., "debug")` |

#### `lua/core/lib/loader.lua` (4 path sites + error reporting)

| Line | Before | After |
|------|--------|-------|
| 14 | `root .. "/lua/plugins"` | `paths.join(root, "lua", "plugins")` |
| 28 | `plugins_dir .. "/" .. name` | `paths.join(plugins_dir, name)` |
| 36 | `category_path .. "/_defaults.lua"` | `paths.join(category_path, "_defaults.lua")` |
| 63 | `category_path .. "/" .. name` | `paths.join(category_path, name)` |

Add error reporting when plugin directory not found:

```lua
if not handle then
  table.insert(M._errors, {
    level = "critical",
    file = "core.lib.loader",
    message = "Plugin directory not found: " .. plugins_dir ..
              "\nLuxVim root detected as: " .. root ..
              "\nLaunch LuxVim from its directory or check installation.",
  })
  return {}
end
```

#### `lua/core/lib/bootstrap.lua` (3 path sites)

| Line | Before | After |
|------|--------|-------|
| 7 | `data_dir .. "/data/lazy/lazy.nvim"` | `paths.join(data_dir, "data", "lazy", "lazy.nvim")` |
| 12 | `data_dir .. "/data/lazy"` | `paths.join(data_dir, "data", "lazy")` |
| 17 | `data_dir .. "/lazy-lock.json"` | `paths.join(data_dir, "lazy-lock.json")` |

#### `lua/core/lib/actions.lua` (1 pattern site)

| Line | Before | After |
|------|--------|-------|
| 17 | `spec.source:match("([^/]+)$")` | `paths.basename(spec.source)` |

#### `lua/core/lib/typegen.lua` (2 path sites)

| Line | Before | After |
|------|--------|-------|
| 70 | `root .. "/lua/types"` | `paths.join(root, "lua", "types")` |
| 71 | `types_dir .. "/plugin.lua"` | `paths.join(types_dir, "plugin.lua")` |

#### `lua/core/theme-picker/persistence.lua` (2 path sites)

| Line | Before | After |
|------|--------|-------|
| 6 | `vim.env.XDG_DATA_HOME .. "/LuxVim"` | `paths.join(vim.env.XDG_DATA_HOME, "LuxVim")` |
| 8 | `luxvim_dir .. "/data/installed-themes.lua"` | `paths.join(luxvim_dir, "data", "installed-themes.lua")` |

#### `lua/plugins/editor/treesitter.lua` (1 path site)

| Line | Before | After |
|------|--------|-------|
| 10 | `data_dir .. "/data/site"` | `paths.join(data_dir, "data", "site")` |

#### `init.lua` (1 path site)

| Line | Before | After |
|------|--------|-------|
| 8 | `current_dir .. "/lua/?.lua;"...` | Use `paths.join()` for lua_dir construction |

#### `lua/plugins/lib/fzf.lua` (platform-specific build)

Add Windows build command:

```lua
build = {
  cmd = "./install --bin",
  platforms = {
    windows = "powershell -ExecutionPolicy Bypass -File .\\install.ps1",
  },
  requires = { "git" },
},
```

## Part B: Windows Installation

### Replace `install.ps1`

```powershell
# LuxVim Installer for Windows
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
    git clone --filter=blob:none --branch=stable `
        "https://github.com/folke/lazy.nvim.git" $lazyPath
    Write-Host "lazy.nvim installed" -ForegroundColor Green
} else {
    Write-Host "lazy.nvim already exists" -ForegroundColor Green
}

# Create PowerShell launcher (lux.ps1)
$launcherPs1 = Join-Path $LuxVimDir "lux.ps1"
$rtp = $LuxVimDir -replace '\\', '/'
@"
`$env:NVIM_APPNAME = "LuxVim"
& nvim --cmd "set rtp+=$rtp" -u "$LuxVimDir\init.lua" @args
"@ | Set-Content -Path $launcherPs1 -Encoding UTF8
Write-Host "Created lux.ps1" -ForegroundColor Green

# Create CMD launcher (lux.cmd)
$launcherCmd = Join-Path $LuxVimDir "lux.cmd"
@"
@echo off
set "NVIM_APPNAME=LuxVim"
nvim --cmd "set rtp+=$rtp" -u "$LuxVimDir\init.lua" %*
"@ | Set-Content -Path $launcherCmd -Encoding ASCII
Write-Host "Created lux.cmd" -ForegroundColor Green

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To use LuxVim, either:" -ForegroundColor Yellow
Write-Host "  1. Add $LuxVimDir to your PATH, then run: lux" -ForegroundColor Cyan
Write-Host "  2. Run directly: $launcherPs1" -ForegroundColor Cyan
Write-Host ""
Write-Host "Running initial plugin sync..." -ForegroundColor Blue

# Initial sync
& $launcherPs1 --headless "+Lazy! sync" +qa

Write-Host "All plugins installed! LuxVim is ready." -ForegroundColor Green
```

### Update `install.sh`

Remove lines 77-90 (sed-based config modification). The Lua code now handles path detection at runtime.

## Implementation Order

### Phase 1: Create paths.lua module
- Create `lua/core/lib/paths.lua` with normalize, join, basename functions

### Phase 2: Update core modules
- `lua/core/lib/debug.lua`
- `lua/core/lib/loader.lua` (including error reporting)
- `lua/core/lib/bootstrap.lua`
- `lua/core/lib/actions.lua`
- `lua/core/lib/typegen.lua`

### Phase 3: Update other Lua files
- `init.lua`
- `lua/core/theme-picker/persistence.lua`
- `lua/plugins/editor/treesitter.lua`
- `lua/plugins/lib/fzf.lua`

### Phase 4: Update installation scripts
- Replace `install.ps1`
- Update `install.sh` (remove sed commands)

## Testing Checklist

- [ ] Install on Windows with spaces in path (e.g., `C:\Users\John Doe\LuxVim`)
- [ ] Launch from different directory (`cd C:\Projects && lux`)
- [ ] Verify plugins load (`:Lazy` shows plugins)
- [ ] Verify debug plugins detected (`:LuxDevStatus`)
- [ ] Test fzf installation (`:Lazy build fzf`)
- [ ] Test on Unix/macOS to ensure no regressions
- [ ] Test error message when root detection fails

## Files Changed Summary

| File | Action |
|------|--------|
| `lua/core/lib/paths.lua` | **CREATE** |
| `lua/core/lib/debug.lua` | EDIT |
| `lua/core/lib/loader.lua` | EDIT |
| `lua/core/lib/bootstrap.lua` | EDIT |
| `lua/core/lib/actions.lua` | EDIT |
| `lua/core/lib/typegen.lua` | EDIT |
| `lua/core/theme-picker/persistence.lua` | EDIT |
| `lua/plugins/editor/treesitter.lua` | EDIT |
| `lua/plugins/lib/fzf.lua` | EDIT |
| `init.lua` | EDIT |
| `install.ps1` | **REPLACE** |
| `install.sh` | EDIT |
