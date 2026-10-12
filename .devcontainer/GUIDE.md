# Setup (Windows):
1. Devpod Installieren:
```powershell
# Installationsordner im eigenen Benutzerprofil erstellen
$devpodBin = Join-Path $env:LOCALAPPDATA "Programs\DevPod"
New-Item -ItemType Directory -Force -Path $devpodBin | Out-Null

# Windows-Version herunterladen
Invoke-WebRequest `
    -Uri "https://github.com/loft-sh/devpod/releases/latest/download/devpod-windows-amd64.exe" `
    -OutFile (Join-Path $devpodBin "devpod.exe")

# Dauerhaft zum Benutzer-PATH hinzufügen
$userPath = [string][Environment]::GetEnvironmentVariable("Path", "User")

if (($userPath -split ";") -notcontains $devpodBin) {
    $updatedPath = (@($userPath, $devpodBin) |
        Where-Object { $_ }) -join ";"

    [Environment]::SetEnvironmentVariable("Path", $updatedPath, "User")
}

# Auch im aktuellen PowerShell-Fenster verfügbar machen
$env:Path += ";$devpodBin"
```

2. Prüfen:
```powershell
devpod version
docker version

devpod provider add docker
devpod provider use docker
```

3. Dotfiles verbinden:
```powershell
devpod context set-options -o DOTFILES_URL=https://github.com/Zweikaufswagen/dotfiles.git -o DOTFILES_SCRIPT=install.sh
```

4. IDE
```powershell
devpod ide use codium
```

3. Einmalig: fix in ps Profil hinzufügen
```powershell
if (-not (Test-Path -LiteralPath $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

notepad $PROFILE
```

```powershell
function Open-DevPod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [string]$Source = ".",

        [string]$RemoteFolder = "/workspaces"
    )

    $ErrorActionPreference = "Stop"

    # Benoetigte lokale Programme vorab pruefen
    Get-Command devpod.exe, codium -ErrorAction Stop | Out-Null

    # Erst starten, noch keine IDE-Verbindung aufbauen
    devpod.exe up $Source --id $Id --ide none

    if ($LASTEXITCODE -ne 0) {
        throw "devpod up ist fehlgeschlagen. Siehe Ausgabe oben."
    }

    $configPath = Join-Path $env:USERPROFILE ".ssh\config"
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
}
```

4. Projekt erstellen:
```powershell
devpod up . --id NAME --ide none
ssh NAME.devpod
```

# Täglicher Betrieb:
