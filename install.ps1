$ErrorActionPreference = "Stop"

$DotfilesDir = Split-Path -Parent $MyInvocation.MyCommand.Path

[Environment]::SetEnvironmentVariable("DOTFILES_HOME", $DotfilesDir, "User")
$env:DOTFILES_HOME = $DotfilesDir

$profileDir = Split-Path -Parent $PROFILE
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

$loader = '. "$env:DOTFILES_HOME/powershell/Microsoft.PowerShell_profile.ps1"'

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$current = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
if ($current -notlike "*$loader*") {
    Add-Content -Path $PROFILE -Value "`n# Load personal dotfiles`n$loader"
}

Write-Host "Dotfiles configured."
Write-Host "DOTFILES_HOME=$DotfilesDir"
Write-Host "Reload with: . `$PROFILE"
