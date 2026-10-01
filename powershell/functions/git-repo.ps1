function New-GitRepo {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name = "."
    )

    $dotfilesHome = if ($env:DOTFILES_HOME) {
        $env:DOTFILES_HOME
    } else {
        Join-Path $HOME ".dotfiles"
    }

    $template = Join-Path $dotfilesHome ".git-repo-template"

    if (-not (Test-Path $template -PathType Container)) {
        throw "Git-Repo-Template nicht gefunden: $template"
    }

    if ($Name -eq ".") {
        $repoPath = (Get-Location).Path
        $projectName = Split-Path $repoPath -Leaf
    } else {
        $repoPath = Join-Path (Get-Location) $Name
        $projectName = $Name

        if (Test-Path $repoPath) {
            throw "Ziel existiert bereits: $repoPath"
        }

        New-Item -ItemType Directory -Path $repoPath | Out-Null
    }

    Get-ChildItem -Path $template -Force | ForEach-Object {
        $destination = Join-Path $repoPath $_.Name
        if (-not (Test-Path $destination)) {
            Copy-Item -Path $_.FullName -Destination $destination -Recurse
        } else {
            Write-Warning "Übersprungen, existiert bereits: $($_.Name)"
        }
    }

    $readme = Join-Path $repoPath "README.md"
    if (Test-Path $readme) {
        $content = [System.IO.File]::ReadAllText($readme)
        $content = $content.Replace("{{PROJECT_NAME}}", $projectName)
        [System.IO.File]::WriteAllText(
            $readme,
            $content,
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    Push-Location $repoPath
    try {
        if (-not (Test-Path ".git" -PathType Container)) {
            git init --initial-branch=main
            if ($LASTEXITCODE -ne 0) {
                throw "git init ist fehlgeschlagen."
            }
        } else {
            Write-Host "Git-Repository existiert bereits."
        }

        if (Get-Command pre-commit -ErrorAction SilentlyContinue) {
            pre-commit install
        } else {
            Write-Warning "pre-commit ist nicht installiert. Konfiguration wurde trotzdem angelegt."
        }
    }
    finally {
        Pop-Location
    }

    Write-Host ""
    Write-Host "Repository bereit: $repoPath"
    Write-Host "  .gitignore"
    Write-Host "  README.md"
    Write-Host "  .pre-commit-config.yaml"
}

Set-Alias -Name newrepo -Value New-GitRepo
