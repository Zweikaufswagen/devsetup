function Get-DevSetupWorkspaceId {
    param([Parameter(Mandatory)][string]$Path)
    $normalized = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/').ToLowerInvariant()
    $name = (Split-Path $normalized -Leaf) -replace '[^a-z0-9-]', '-'
    $name = $name.Trim('-')
    if (-not $name) { $name = 'project' }
    # DevPod allows at most 48 characters, including the separator and hash.
    if ($name.Length -gt 37) { $name = $name.Substring(0, 37).TrimEnd('-') }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized)) }
    finally { $sha.Dispose() }
    return "$name-$(([BitConverter]::ToString($hash) -replace '-', '').Substring(0, 10).ToLowerInvariant())"
}

function Copy-DevSetupTemplate {
    param([string]$Source, [string]$Destination, [string]$ProjectName)
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        if ($item.Name -eq '.git' -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Unzulaessiger Template-Eintrag: $($item.FullName)"
        }
        $target = Join-Path $Destination $item.Name
        if (Test-Path -LiteralPath $target) {
            $existing = Get-Item -LiteralPath $target -Force
            if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Ziel ist ein Link, Kopieren abgebrochen: $target"
            }
            if ($item.PSIsContainer -and $existing.PSIsContainer) {
                Copy-DevSetupTemplate $item.FullName $target $ProjectName
            }
            elseif ($item.PSIsContainer -ne $existing.PSIsContainer) {
                throw "Datei-/Ordnerkonflikt: $target"
            }
            else { Write-Host "Beibehalten: $target" }
            continue
        }
        if ($item.PSIsContainer) {
            [IO.Directory]::CreateDirectory($target) | Out-Null
            Copy-DevSetupTemplate $item.FullName $target $ProjectName
        }
        else {
            Copy-Item -LiteralPath $item.FullName -Destination $target
            if ($item.Name -eq 'README.md') {
                $content = [IO.File]::ReadAllText($target).Replace('{{PROJECT_NAME}}', $ProjectName)
                [IO.File]::WriteAllText($target, $content, [Text.UTF8Encoding]::new($false))
            }
        }
    }
}

function Get-DevSetupGitRoot {
    param([string]$Path)
    $ErrorActionPreference = 'Continue'
    $root = & git -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0) { return $root }
}

function Initialize-DevSetupRepository {
    [CmdletBinding()]
    param([switch]$Offline, [switch]$NoOpen)
    $ErrorActionPreference = 'Stop'
    Get-Command git -ErrorAction Stop | Out-Null
    if ((Get-Location).Provider.Name -ne 'FileSystem') { throw 'Einen lokalen Projektordner verwenden.' }
    $repoPath = (Get-Location).ProviderPath
    $projectName = Split-Path $repoPath -Leaf
    if (-not $projectName) { throw 'Ein Laufwerkswurzelverzeichnis ist kein Projektordner.' }

    if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
        $parentRepo = Get-DevSetupGitRoot $repoPath
        if ($parentRepo) { throw "Der Ordner liegt bereits in einem anderen Git-Repository: $parentRepo" }
    }

    $installRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $template = Join-Path $installRoot '.git-repo-template'
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('devsetup-' + [guid]::NewGuid().ToString('N'))
    try {
        if (-not $Offline) {
            Write-Host 'Lade aktuelle Vorlage von https://github.com/Zweikaufswagen/devsetup.git ...'
            # A fresh shallow clone follows the default branch and uses existing Git credentials.
            & git clone --depth 1 --quiet -- https://github.com/Zweikaufswagen/devsetup.git $temporary
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath "$temporary/.git-repo-template/.devcontainer/devcontainer.json")) {
                $template = Join-Path $temporary '.git-repo-template'
            }
            else {
                Write-Warning 'GitHub-Vorlage nicht erreichbar oder noch unvollstaendig. Verwende die installierte Vorlage.'
            }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $template '.devcontainer/devcontainer.json'))) {
            throw 'Keine vollstaendige Vorlage gefunden. devsetup erneut installieren.'
        }
        Copy-DevSetupTemplate $template $repoPath $projectName
        if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
            & git -C $repoPath init --initial-branch=main
            if ($LASTEXITCODE -ne 0) { throw 'git init fehlgeschlagen.' }
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
    }
    Write-Host "Repository bereit: $repoPath"
    if (-not $NoOpen) {
        Open-DevPod -Id (Get-DevSetupWorkspaceId $repoPath) -Source $repoPath
    }
}
