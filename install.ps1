# **********************************************************
# ********************* LUXVIM INSTALLER ******************
# **********************************************************

# Set error action preference
$ErrorActionPreference = "Stop"

# Define colors for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Get the absolute path of LuxVim directory
$LuxVimDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

Write-ColorOutput "🚀 Installing LuxVim..." "Blue"
Write-ColorOutput "LuxVim directory: $LuxVimDir" "Yellow"

# Check if nvim is installed
try {
    $null = Get-Command nvim -ErrorAction Stop
    Write-ColorOutput "✅ Neovim found" "Green"
} catch {
    Write-ColorOutput "❌ Neovim is not installed. Please install Neovim first." "Red"
    Write-ColorOutput "Visit: https://neovim.io/" "Yellow"
    exit 1
}

# Create the lux batch script
$AliasScriptDir = "$env:USERPROFILE\.local\bin"
$AliasScript = "$AliasScriptDir\lux.bat"

# Create .local/bin directory if it doesn't exist
if (!(Test-Path -Path $AliasScriptDir)) {
    New-Item -ItemType Directory -Path $AliasScriptDir -Force | Out-Null
}

# Create the lux.bat script
$LuxVimDirEscaped = $LuxVimDir -replace ' ', '\ ' -replace '\\', '/'
$BatchContent = @"
@echo off
set NVIM_APPNAME=LuxVim
set "XDG_DATA_HOME=$($LuxVimDir)"
set "XDG_CONFIG_HOME=$($LuxVimDir)"
nvim --cmd "set rtp+=$($LuxVimDirEscaped)" -u "$($LuxVimDir)\init.lua" %*
"@

$BatchContent | Out-File -FilePath $AliasScript -Encoding ASCII

Write-ColorOutput "✅ Created lux command at $AliasScript" "Green"

# Check if ~/.local/bin is in PATH
$CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($CurrentPath -notlike "*$AliasScriptDir*") {
    Write-ColorOutput "⚠️  $AliasScriptDir is not in your PATH" "Yellow"
    Write-ColorOutput "Adding $AliasScriptDir to your user PATH..." "Yellow"
    
    try {
        $NewPath = "$AliasScriptDir;$CurrentPath"
        [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
        Write-ColorOutput "✅ Added to PATH. You may need to restart your terminal." "Green"
    } catch {
        Write-ColorOutput "❌ Failed to add to PATH. Please add manually:" "Red"
        Write-ColorOutput "$AliasScriptDir" "Blue"
    }
}

# Create data directories within LuxVim
$LuxVimDataDir = "$LuxVimDir\data"
$DataDirs = @(
    "$LuxVimDataDir\lazy",
    "$LuxVimDataDir\mason",
    "$LuxVimDataDir\nvim"
)

foreach ($dir in $DataDirs) {
    if (!(Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Write-ColorOutput "✅ Created data directories in LuxVim" "Green"

# Bootstrap lazy.nvim within LuxVim
$LazyPath = "$LuxVimDataDir\lazy\lazy.nvim"
if (!(Test-Path -Path $LazyPath)) {
    Write-ColorOutput "📦 Bootstrapping lazy.nvim..." "Blue"
    try {
        git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$LazyPath"
        Write-ColorOutput "✅ lazy.nvim installed" "Green"
    } catch {
        Write-ColorOutput "❌ Failed to clone lazy.nvim. Please check your git installation." "Red"
        exit 1
    }
} else {
    Write-ColorOutput "✅ lazy.nvim already exists" "Green"
}

# Update the lazy.nvim configuration to use our custom path
$LazyConfig = "$LuxVimDir\lua\config\lazy.lua"
if (Test-Path -Path $LazyConfig) {
    # Create a backup
    Copy-Item -Path $LazyConfig -Destination "$LazyConfig.backup" -Force
    
    # Update the lazy path to use our custom data directory (convert backslashes to forward slashes for Lua)
    $LuxVimDataDirLua = $LuxVimDataDir -replace '\\', '/'
    $Content = Get-Content -Path $LazyConfig -Raw
    $UpdatedContent = $Content -replace 'local lazypath = vim\.fn\.stdpath\("data"\) \.\. "/lazy/lazy\.nvim"', "local lazypath = \`"$LuxVimDataDirLua/lazy/lazy.nvim\`""
    $UpdatedContent | Out-File -FilePath $LazyConfig -Encoding UTF8
    
    Write-ColorOutput "✅ Updated lazy.nvim configuration" "Green"
}

Write-ColorOutput "🎉 LuxVim installation complete!" "Green"
Write-ColorOutput "Usage: lux [file]" "Blue"
Write-ColorOutput "Note: Plugins will auto-download on first run" "Yellow"

# Test if lux command is available
try {
    $null = Get-Command lux -ErrorAction Stop
    Write-ColorOutput "✅ 'lux' command is ready to use" "Green"
} catch {
    Write-ColorOutput "⚠️  'lux' command not found in PATH. You may need to restart your terminal." "Yellow"
}

Write-ColorOutput "Starting LuxVim for initial plugin installation..." "Blue"
try {
    & "$AliasScript" --headless "+Lazy! sync" +qa
    Write-ColorOutput "🎉 All plugins installed! LuxVim is ready to use." "Green"
} catch {
    Write-ColorOutput "⚠️  Initial plugin installation may have encountered issues. You can run ``lux`` to complete setup manually." "Yellow"
}