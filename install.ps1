# **********************************************************
# ********************* LUXVIM INSTALLER *******************
# **********************************************************

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Write-Host is intentional here: this is an interactive installer that relies on colored console output, not a library cmdlet whose output needs to be captured or redirected.'
)]
param()

$ErrorActionPreference = "Stop"

$LuxVimDir = $PSScriptRoot

Write-Host "Installing LuxVim..." -ForegroundColor Blue
Write-Host "LuxVim directory: $LuxVimDir" -ForegroundColor Yellow

# Check prerequisites
# Dependencies are declared once in lua/core/lib/deps.lua and read here via
# scripts/check-deps.lua. Only nvim is checked inline, because running the
# manifest requires nvim.
if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
    Write-Host "Neovim is not installed. Please install Neovim first." -ForegroundColor Red
    Write-Host "Visit: https://neovim.io/" -ForegroundColor Yellow
    exit 1
}

$checkScript = Join-Path $LuxVimDir "scripts\check-deps.lua"
$depsOutput = & nvim -l $checkScript 2>&1
$depsFailed = $LASTEXITCODE -ne 0

$depsRows = 0
$depsNoise = @()
foreach ($line in $depsOutput) {
    $parts = "$line" -split "`t"
    if ($parts.Count -lt 4) {
        if ("$line".Trim() -ne "") { $depsNoise += "$line" }
        continue
    }
    $depsRows++
    $status, $cmd, $version, $message = $parts
    if ($status -eq "ok") {
        Write-Host "$cmd $version" -ForegroundColor Green
    } else {
        Write-Host "$cmd - $message" -ForegroundColor Red
    }
}

if ($depsFailed) {
    Write-Host ""
    if ($depsRows -eq 0) {
        Write-Host "Dependency check could not run — nvim -l scripts\check-deps.lua failed:" -ForegroundColor Red
        foreach ($noise in $depsNoise) {
            Write-Host "    $noise" -ForegroundColor Red
        }
    } else {
        Write-Host "Missing required dependencies. Install them and re-run this script." -ForegroundColor Red
    }
    exit 1
}

# Create data directories
$dataDirs = @("data\lazy", "data\luxlsp", "data\site")
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
`$env:LUXVIM_ROOT = "$LuxVimDirForward"
`$env:NVIM_APPNAME = "LuxVim"
`$env:XDG_DATA_HOME = "$LuxVimDirForward/data"
& nvim --cmd "set rtp+=$LuxVimDirForward" -u "$LuxVimDirForward/init.lua" @args
"@
Set-Content -Path $launcherPs1 -Value $ps1Content -Encoding UTF8
Write-Host "Created lux.ps1" -ForegroundColor Green

# Create CMD launcher (lux.cmd)
$launcherCmd = Join-Path $LuxVimDir "lux.cmd"
$cmdContent = @"
@echo off
set "LUXVIM_ROOT=$LuxVimDirForward"
set "NVIM_APPNAME=LuxVim"
set "XDG_DATA_HOME=$LuxVimDirForward/data"
nvim --cmd "set rtp+=$LuxVimDirForward" -u "$LuxVimDirForward/init.lua" %*
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

# Build the treesitter parsers declared in lua/languages/. Syncing plugins does
# NOT do this: nvim-treesitter installs nothing on its own, and the spec's
# ":TSUpdate" build step only updates parsers that already exist. Without this
# step a fresh install has zero parsers and no file highlights.
Write-Host "Installing treesitter parsers (compiles C, this can take a while)..." -ForegroundColor Blue
& $launcherPs1 --headless "+LuxVimInstallParsers" +qa

if ($LASTEXITCODE -eq 0) {
    Write-Host "Treesitter parsers installed." -ForegroundColor Green
} else {
    Write-Host "Some parsers failed to build. Run ':checkhealth luxvim' for details." -ForegroundColor Yellow
}
