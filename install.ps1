[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Dieser Installer unterstuetzt ausschliesslich Windows.' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$sourceRoot = $PSScriptRoot
$installRoot = Join-Path $env:LOCALAPPDATA 'devsetup'
$bin = Join-Path $installRoot 'bin'
. (Join-Path $sourceRoot 'powershell/functions/host.ps1')
. (Join-Path $sourceRoot 'powershell/functions/install-helpers.ps1')

Update-DevSetupProcessPath
Install-DevSetupPackage -Command 'git' -Package 'Git.Git'
Install-DevSetupPackage -Command 'codium' -Package 'VSCodium.VSCodium'
Install-DevSetupPackage -Command 'docker' -Package 'Docker.DockerDesktop'

# Copy runtime and an offline template; no symlinks or administrator profile required.
[IO.Directory]::CreateDirectory($installRoot) | Out-Null
if ([IO.Path]::GetFullPath($sourceRoot).TrimEnd('\') -ne [IO.Path]::GetFullPath($installRoot).TrimEnd('\')) {
    foreach ($name in @('bin', 'powershell', '.git-repo-template')) {
        $target = Join-Path $installRoot $name
        [IO.Directory]::CreateDirectory($target) | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $sourceRoot $name) -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
        }
    }
}

if (-not (Get-Command devpod.exe -ErrorAction SilentlyContinue)) {
    $architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $architecture = switch ($architecture) {
        'AMD64' { 'amd64' }
        'ARM64' { 'arm64' }
        default { throw "Nicht unterstuetzte Windows-Architektur: $architecture" }
    }
    $asset = "devpod-windows-$architecture.exe"
    $release = Invoke-RestMethod 'https://api.github.com/repos/loft-sh/devpod/releases/latest'
    $download = @($release.assets | Where-Object name -eq $asset)
    if ($download.Count -ne 1) { throw "DevPod-Release enthaelt $asset nicht." }
    $temporary = Join-Path $bin 'devpod.download'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $download[0].browser_download_url -OutFile $temporary
        # Recent GitHub releases expose an asset digest; verify it when available.
        if ($download[0].digest -match '^sha256:(.+)$') {
            if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $Matches[1]) {
                throw 'DevPod-Download: SHA256 stimmt nicht ueberein.'
            }
        }
        Move-Item -LiteralPath $temporary -Destination (Join-Path $bin 'devpod.exe') -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

[Environment]::SetEnvironmentVariable('DEVSETUP_HOME', $installRoot, 'User')
$env:DEVSETUP_HOME = $installRoot
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';').TrimEnd('\') -notcontains $bin.TrimEnd('\')) {
    [Environment]::SetEnvironmentVariable('Path', (($bin, $userPath | Where-Object { $_ }) -join ';'), 'User')
}
Update-DevSetupProcessPath
Get-Command git, docker, devpod.exe, codium -ErrorAction Stop | Out-Null

# User profiles need scripts enabled; leave stricter company policy in control.
if ((Get-ExecutionPolicy -Scope MachinePolicy) -ne 'Undefined' -or (Get-ExecutionPolicy -Scope UserPolicy) -ne 'Undefined') {
    Write-Host 'Die Ausfuehrungsrichtlinie wird durch die vorhandene Gruppenrichtlinie bestimmt.'
}
elseif ((Get-ExecutionPolicy -Scope CurrentUser) -in @('Undefined', 'Restricted')) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

$documents = [Environment]::GetFolderPath('MyDocuments')
foreach ($edition in @('WindowsPowerShell', 'PowerShell')) {
    $profileDirectory = Join-Path $documents $edition
    [IO.Directory]::CreateDirectory($profileDirectory) | Out-Null
    # Remove only this repository's legacy loader, retaining other profile content.
    foreach ($oldProfile in Get-ChildItem -LiteralPath $profileDirectory -Filter '*profile.ps1' -File) {
        Update-DevSetupProfile -Path $oldProfile.FullName -RemoveLegacyOnly
    }
    Update-DevSetupProfile -Path (Join-Path $profileDirectory 'profile.ps1')
}

& codium --install-extension jeanp413.open-remote-ssh
if ($LASTEXITCODE -ne 0) { throw 'VSCodium Remote-SSH-Erweiterung konnte nicht installiert werden. Installer erneut ausfuehren.' }

# Migrate the old context: install.sh now belongs on the Windows host only.
& devpod.exe context set-options -o 'DOTFILES_URL=' -o 'DOTFILES_SCRIPT='
if ($LASTEXITCODE -ne 0) { throw 'Alte DevPod-Dotfiles-Einstellungen konnten nicht entfernt werden.' }

# Runtime is installed even if Docker needs its first-run dialog or a reboot.
try {
    Start-DevSetupDocker
    Initialize-DevSetupProvider
}
catch {
    Write-Warning $_.Exception.Message
    Write-Warning 'Befehle und Profile sind installiert. Docker bereitstellen; devsetup init richtet den Provider beim ersten Start ein.'
}

Write-Host ''
Write-Host "devsetup installiert: $installRoot"
Write-Host 'Ein neues Terminal oeffnen (ggf. Windows Terminal/VSCodium ganz neu starten).'
Write-Host 'Im gewuenschten Projektordner: devsetup init'
