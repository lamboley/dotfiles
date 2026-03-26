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
$fontDir = "$env:SystemRoot\Fonts"
if (!(Test-Path "$fontDir\FiraCodeNerdFont-Regular.ttf")) {
    $zipPath = "$env:TEMP\FiraCode.zip"
    $extractPath = "$env:TEMP\FiraCode"
    Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Get-ChildItem "$extractPath\*.ttf" | ForEach-Object {
        Copy-Item $_.FullName $fontDir -Force
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
            -Name "$($_.BaseName) (TrueType)" -Value $_.Name -PropertyType String -Force
    }
    Remove-Item $zipPath, $extractPath -Recurse -Force
}

# Configure Neovim (LazyVim)
$nvimDir = "$env:LOCALAPPDATA\nvim"
if (!(Test-Path $nvimDir)) {
    git clone https://github.com/LazyVim/starter $nvimDir
    Remove-Item "$nvimDir\.git" -Recurse -Force
}
Copy-Item "$DOTFILES\nvim\*" $nvimDir -Recurse -Force

# Configure Oh My Posh in PowerShell profile
$profileDir = Split-Path $PROFILE
if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force }
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }

$ompLine = 'oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\dracula.omp.json" | Invoke-Expression'
if (!(Select-String -Path $PROFILE -Pattern "oh-my-posh" -Quiet -ErrorAction SilentlyContinue)) {
    Add-Content -Path $PROFILE -Value "`n$ompLine"
}

# Symlinks
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.wezterm.lua" -Target "$DOTFILES\wezterm\.wezterm.lua" -Force

Write-Host "`nDone! Restart your terminal." -ForegroundColor Green
