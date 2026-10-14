# Loaded by Windows PowerShell 5.1 and PowerShell 7 (all hosts).
. (Join-Path $PSScriptRoot 'functions/host.ps1')
. (Join-Path $PSScriptRoot 'functions/open-devpod.ps1')

function global:devsetup {
    & (Join-Path $env:DEVSETUP_HOME 'bin/devsetup.cmd') @args
}
