# Dotfiles PowerShell profile

$dotfilesHome = if ($env:DOTFILES_HOME) {
    $env:DOTFILES_HOME
} else {
    Join-Path $HOME ".dotfiles"
}

$functionsDir = Join-Path $dotfilesHome "powershell/functions"

if (Test-Path $functionsDir) {
    Get-ChildItem -Path $functionsDir -Filter "*.ps1" -File | ForEach-Object {
        . $_.FullName
    }
}
