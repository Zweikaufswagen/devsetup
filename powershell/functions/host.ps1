function Update-DevSetupProcessPath {
    $directories = @(
        $env:Path
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
        [Environment]::GetEnvironmentVariable('Path', 'User')
    )
    # Existing applications do not always register their CLI directory in PATH.
    foreach ($directory in @(
        "$env:ProgramFiles/Docker/Docker/resources/bin",
        "$env:ProgramFiles/Git/cmd",
        "$env:WINDIR/System32/OpenSSH",
        "$env:ProgramFiles/Git/usr/bin",
        "$env:ProgramFiles/VSCodium/bin",
        "$env:LOCALAPPDATA/Programs/VSCodium/bin",
        "$env:LOCALAPPDATA/Programs/DevPod"
    )) {
        if (Test-Path -LiteralPath $directory) { $directories += $directory }
    }
    $env:Path = (($directories -join ';') -split ';' | Where-Object { $_ } | Select-Object -Unique) -join ';'
}

function Get-DevSetupDockerType {
    # Windows PowerShell turns redirected native stderr into ErrorRecords.
    $ErrorActionPreference = 'Continue'
    $result = & docker info --format '{{.OSType}}' 2>$null
    if ($LASTEXITCODE -eq 0) { return "$result".Trim() }
    return ''
}

function Start-DevSetupDocker {
    Get-Command docker -ErrorAction Stop | Out-Null
    $type = Get-DevSetupDockerType
    if (-not $type) {
        $desktop = Join-Path $env:ProgramFiles 'Docker/Docker/Docker Desktop.exe'
        if (-not (Test-Path -LiteralPath $desktop)) {
            throw 'Docker nicht erreichbar. Docker Desktop starten und devsetup open erneut ausfuehren.'
        }
        if (-not (Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue)) {
            Start-Process -FilePath $desktop
        }
        Write-Host 'Warte auf Docker Desktop (maximal 3 Minuten). Eventuelle Ersteinrichtung im Docker-Fenster abschliessen ...'
        $deadline = (Get-Date).AddMinutes(3)
        do {
            Start-Sleep -Seconds 3
            $type = Get-DevSetupDockerType
        } until ($type -or (Get-Date) -ge $deadline)
    }
    if ($type -ne 'linux') {
        throw 'Docker muss mit Linux-Containern laufen. Docker Desktop/WSL-2-Engine einrichten, ggf. Windows neu starten, dann devsetup open ausfuehren.'
    }
}

function Initialize-DevSetupProvider {
    $providers = & devpod.exe provider list --output json
    if ($LASTEXITCODE -ne 0) { throw 'DevPod-Provider konnten nicht gelesen werden.' }
    $configuration = ($providers -join "`n") | ConvertFrom-Json
    if (-not $configuration.PSObject.Properties['docker']) {
        & devpod.exe provider add docker
        if ($LASTEXITCODE -ne 0) { throw 'Docker-Provider konnte nicht eingerichtet werden.' }
    }
}
