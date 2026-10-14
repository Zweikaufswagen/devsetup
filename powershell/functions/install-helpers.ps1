function Install-DevSetupPackage {
    param([string]$Command, [string]$Package)
    if (Get-Command $Command -ErrorAction SilentlyContinue) { return }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget fehlt. Microsoft App Installer installieren/aktualisieren und install.sh erneut ausfuehren. Fehlendes Paket: $Package"
    }
    Write-Host "Installiere $Package ..."
    & winget.exe install --id $Package --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -notin @(0, 3010, 1641)) { throw "Installation von $Package fehlgeschlagen (Exitcode $LASTEXITCODE)." }
    Update-DevSetupProcessPath
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Package installiert, aber $Command noch nicht verfuegbar. Windows ggf. neu starten und install.sh erneut ausfuehren."
    }
}

function Update-DevSetupProfile {
    param([string]$Path, [switch]$RemoveLegacyOnly)
    $current = if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path) } else { '' }
    $legacyLoaders = @(
        '. "$env:DOTFILES_HOME/powershell/Microsoft.PowerShell_profile.ps1"',
        '. "$env:DOTFILES_HOME\powershell\Microsoft.PowerShell_profile.ps1"'
    )
    $lines = @($current -split '\r?\n' | Where-Object {
        $_.Trim() -notin $legacyLoaders -and $_.Trim() -ne '# Load personal dotfiles'
    })
    $updated = $lines -join "`r`n"
    $loader = 'if (Test-Path -LiteralPath "$env:DEVSETUP_HOME/powershell/Microsoft.PowerShell_profile.ps1") { . "$env:DEVSETUP_HOME/powershell/Microsoft.PowerShell_profile.ps1" }'
    if (-not $RemoveLegacyOnly -and $updated -notmatch [regex]::Escape($loader)) {
        $updated = $updated.TrimEnd() + "`r`n`r`n# Load devsetup`r`n$loader`r`n"
    }
    if ($updated -cne $current) {
        if (Test-Path -LiteralPath $Path) {
            Copy-Item -LiteralPath $Path -Destination "$Path.bak-$([guid]::NewGuid().ToString('N'))"
        }
        # BOM keeps non-ASCII paths/content readable in Windows PowerShell 5.1.
        [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($true))
    }
}
