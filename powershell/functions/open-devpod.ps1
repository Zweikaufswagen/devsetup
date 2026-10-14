function Open-DevPod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [string]$Source = ".",

        [string]$RemoteFolder = "/workspaces/project"
    )

    $ErrorActionPreference = "Stop"

    Update-DevSetupProcessPath
    # Benoetigte lokale Programme vorab pruefen
    Get-Command devpod.exe, codium -ErrorAction Stop | Out-Null

    # Erst starten, noch keine IDE-Verbindung aufbauen
    Start-DevSetupDocker
    Initialize-DevSetupProvider
    devpod.exe up $Source --id $Id --provider docker --ide none

    if ($LASTEXITCODE -ne 0) {
        throw "devpod up ist fehlgeschlagen. Siehe Ausgabe oben."
    }

    $configPath = Join-Path $env:USERPROFILE ".ssh\config"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "DevPod hat keine SSH-Konfiguration angelegt: $configPath"
    }
    $lines = [System.IO.File]::ReadAllLines($configPath)

    $insideDevPod = $false
    $changed = $false

    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^# DevPod Start ') {
            $insideDevPod = $true
        }
        elseif ($lines[$i] -match '^# DevPod End ') {
            $insideDevPod = $false
        }
        elseif (
            $insideDevPod -and
            $lines[$i] -match '^\s*ProxyCommand\s+'
        ) {
            # Nur ProxyCommands in automatisch erzeugten DevPod-Bloecken
            $fixedLine = $lines[$i].Replace('\', '/')

            if ($fixedLine -cne $lines[$i]) {
                $lines[$i] = $fixedLine
                $changed = $true
            }
        }
    }

    if ($changed) {
        # Original vor jeder Aenderung sichern
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
        Copy-Item -LiteralPath $configPath `
            -Destination "$configPath.bak-$timestamp"

        # UTF-8 ohne BOM
        $encoding = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllLines($configPath, $lines, $encoding)
    }

    # Erst nach der Korrektur den Editor verbinden
    codium --new-window `
        --remote "ssh-remote+${Id}.devpod" `
        $RemoteFolder

    if ($LASTEXITCODE -ne 0) {
        throw "VSCodium konnte nicht geoeffnet werden. Erneut versuchen: devsetup open"
    }
}
