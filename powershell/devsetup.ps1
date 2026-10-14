[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'open', 'help')]
    [string]$Command = 'help',
    [switch]$Offline,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
try {
    if ($env:OS -ne 'Windows_NT') { throw 'devsetup unter Windows ausfuehren.' }
    . (Join-Path $PSScriptRoot 'functions/host.ps1')
    . (Join-Path $PSScriptRoot 'functions/open-devpod.ps1')
    . (Join-Path $PSScriptRoot 'functions/repository.ps1')
    Update-DevSetupProcessPath

    switch ($Command) {
        'init' { Initialize-DevSetupRepository -Offline:$Offline -NoOpen:$NoOpen }
        'open' {
            $path = (Get-Location).ProviderPath
            if (-not (Test-Path -LiteralPath (Join-Path $path '.devcontainer/devcontainer.json'))) {
                throw 'Keine .devcontainer/devcontainer.json gefunden. Zuerst devsetup init ausfuehren.'
            }
            Open-DevPod -Id (Get-DevSetupWorkspaceId $path) -Source $path
        }
        'help' {
            Write-Host @'
devsetup init           GitHub-Vorlage im aktuellen Ordner anlegen und VSCodium oeffnen
devsetup init -Offline  Mit der bei der Installation gespeicherten Vorlage arbeiten
devsetup init -NoOpen   Nur Projekt anlegen, ohne Docker/DevPod zu starten
devsetup open           Bestehendes Projekt erneut in VSCodium oeffnen
'@
        }
    }
}
catch {
    [Console]::Error.WriteLine("devsetup: $($_.Exception.Message)")
    exit 1
}
