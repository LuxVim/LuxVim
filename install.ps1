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
`$env:XDG_DATA_HOME = "$LuxVimDirForward"
`$env:XDG_CONFIG_HOME = "$LuxVimDirForward"
& nvim --cmd "set rtp+=$LuxVimDirForward" -u "$LuxVimDirForward/init.lua" @args
"@
Set-Content -Path $launcherPs1 -Value $ps1Content -Encoding UTF8
Write-Host "Created lux.ps1" -ForegroundColor Green

# Create CMD launcher (lux.cmd)
$launcherCmd = Join-Path $LuxVimDir "lux.cmd"
$cmdContent = @"
@echo off
set "NVIM_APPNAME=LuxVim"
set "XDG_DATA_HOME=$LuxVimDirForward"
set "XDG_CONFIG_HOME=$LuxVimDirForward"
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
