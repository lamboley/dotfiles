# Lucas's Dotfiles Installer (Windows)
#
# Run in PowerShell as Administrator:
#   irm https://raw.githubusercontent.com/lamboley/dotfiles/master/install.ps1 | iex
#
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$DOTFILES = "$env:USERPROFILE\.dotfiles"
$REPO = "https://github.com/lamboley/dotfiles.git"

function Write-Error-Msg($msg) {
    Write-Host "Error: $msg" -ForegroundColor Red
}

# Get the repo
if (Test-Path $DOTFILES) {
    git -C $DOTFILES pull --rebase origin master
} else {
    git clone --depth=1 $REPO $DOTFILES
    if ($LASTEXITCODE -ne 0) { Write-Error-Msg "Failed to clone dotfiles"; exit 1 }
}

# Install packages via winget
$packages = @(
    "Neovim.Neovim"
    "wez.wezterm"
    "JesseDuffield.lazygit"
    "BurntSushi.ripgrep"
    "sharkdp.fd"
    "junegunn.fzf"
    "eza-community.eza"
    "JanDeDobbeleer.OhMyPosh"
)

foreach ($pkg in $packages) {
    winget install --id $pkg --accept-source-agreements --accept-package-agreements --silent
}

# Install FiraCode Nerd Font
$systemFontDir = "$env:SystemRoot\Fonts"
$userFontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$fontInstalled = (Test-Path "$systemFontDir\FiraCodeNerdFont-Regular.ttf") -or `
                 (Test-Path "$userFontDir\FiraCodeNerdFont-Regular.ttf") -or `
                 (Test-Path "$userFontDir\FiraCodeNerdFontMono-Regular.ttf")

if (!$fontInstalled) {
    Write-Host "Installing FiraCode Nerd Font..." -ForegroundColor Cyan
    $zipPath = "$env:TEMP\FiraCode.zip"
    $extractPath = "$env:TEMP\FiraCodeNerd"
    Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # Install using Shell.Application (registers fonts properly)
    $shellApp = New-Object -ComObject Shell.Application
    $fontFolder = $shellApp.Namespace(0x14) # Windows Fonts folder
    Get-ChildItem "$extractPath\*.ttf" | ForEach-Object {
        $fontFolder.CopyHere($_.FullName, 0x14) # 0x14 = no prompt + overwrite
    }

    Remove-Item $zipPath, $extractPath -Recurse -Force
    Write-Host "FiraCode Nerd Font installed. You may need to restart WezTerm." -ForegroundColor Green
}

# Configure Neovim (LazyVim)
$nvimDir = "$env:LOCALAPPDATA\nvim"
if (!(Test-Path $nvimDir)) {
    git clone https://github.com/LazyVim/starter $nvimDir
    Remove-Item "$nvimDir\.git" -Recurse -Force
}
if (Test-Path "$DOTFILES\nvim") {
    Copy-Item "$DOTFILES\nvim\*" $nvimDir -Recurse -Force
}

# Configure Oh My Posh in PowerShell profile
$profileDir = Split-Path $PROFILE
if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force }
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }

# Write a safe profile that checks if oh-my-posh exists before loading
$profileContent = @'
# Oh My Posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $theme = "$env:POSH_THEMES_PATH\dracula.omp.json"
    if (!(Test-Path $theme)) {
        $theme = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\dracula.omp.json"
    }
    if (Test-Path $theme) {
        oh-my-posh init pwsh --config $theme | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}
'@

# Only write if not already configured
if (!(Select-String -Path $PROFILE -Pattern "oh-my-posh" -Quiet -ErrorAction SilentlyContinue)) {
    Add-Content -Path $PROFILE -Value "`n$profileContent"
}

# Symlink WezTerm config
$weztermSource = "$DOTFILES\wezterm\.wezterm.lua"
$weztermDest = "$env:USERPROFILE\.wezterm.lua"

# Remove broken symlink if exists
if (Test-Path $weztermDest) { Remove-Item $weztermDest -Force }

if (Test-Path $weztermSource) {
    New-Item -ItemType SymbolicLink -Path $weztermDest -Target $weztermSource -Force
} else {
    Write-Host "Warning: $weztermSource not found, skipping WezTerm symlink" -ForegroundColor Yellow
    Write-Host "Create the file in your dotfiles repo and re-run the script" -ForegroundColor Yellow
}

Write-Host "`nDone! Restart your terminal." -ForegroundColor Green
