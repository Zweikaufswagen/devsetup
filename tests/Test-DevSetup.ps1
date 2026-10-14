# No test dependencies. Runs on Windows PowerShell 5.1 and PowerShell 7.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'powershell/functions/repository.ps1')
. (Join-Path $root 'powershell/functions/install-helpers.ps1')
. (Join-Path $root 'powershell/functions/open-devpod.ps1')
. (Join-Path $root 'powershell/functions/host.ps1')

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAILED: $Message" }
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
    try { & $Action } catch {
        Assert-True ($_.Exception.Message -like $Pattern) "Unexpected failure: $($_.Exception.Message)"
        return
    }
    throw "FAILED: Expected failure matching $Pattern"
}

$temporary = Join-Path ([IO.Path]::GetTempPath()) ('devsetup-tests-' + [guid]::NewGuid().ToString('N'))
$originalUserProfile = $env:USERPROFILE
$originalGitPrompt = $env:GIT_TERMINAL_PROMPT
$gitExecutable = (Get-Command git -CommandType Application | Select-Object -First 1).Source
[IO.Directory]::CreateDirectory($temporary) | Out-Null
try {
    # Parse every PowerShell script, including installer and CLI entrypoint.
    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1') {
        $tokens = $null
        $parseErrors = $null
        [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
        Assert-True (-not $parseErrors) "PowerShell syntax: $($file.FullName): $parseErrors"
    }

    $project = Join-Path $temporary 'Project [one] with spaces'
    [IO.Directory]::CreateDirectory($project) | Out-Null
    Push-Location -LiteralPath $project
    try {
        Initialize-DevSetupRepository -Offline -NoOpen
        Assert-True (Test-Path -LiteralPath '.devcontainer/devcontainer.json') 'Devcontainer copied'
        Assert-True (Test-Path -LiteralPath '.pre-commit-config.yaml') 'Hidden template files copied'
        Assert-True ((& $gitExecutable branch --show-current) -eq 'main') 'Git initialized on main'
        Assert-True ((Get-Content -LiteralPath README.md -Raw) -match [regex]::Escape('Project [one] with spaces')) 'Project name substituted'
        $config = Get-Content -LiteralPath '.devcontainer/devcontainer.json' -Raw | ConvertFrom-Json
        Assert-True ($config.workspaceMount -eq 'source=${localWorkspaceFolder},target=/workspaces/project,type=bind') 'Local workspace bind mount'
        Assert-True ($config.workspaceFolder -eq '/workspaces/project') 'Editor folder matches mount'

        [IO.File]::WriteAllText((Join-Path $project 'README.md'), 'User content {{PROJECT_NAME}}')
        [IO.File]::WriteAllText((Join-Path $project '.devcontainer/custom.txt'), 'Keep me')
        Remove-Item -LiteralPath '.devcontainer/Dockerfile'
        Initialize-DevSetupRepository -Offline -NoOpen
        Assert-True ((Get-Content -LiteralPath README.md -Raw) -ceq 'User content {{PROJECT_NAME}}') 'Existing README untouched'
        Assert-True (Test-Path -LiteralPath '.devcontainer/custom.txt') 'Existing nested files preserved'
        Assert-True (Test-Path -LiteralPath '.devcontainer/Dockerfile') 'Missing nested template files restored'
        $id = Get-DevSetupWorkspaceId $project
        Assert-True ($id -match '^[a-z0-9][a-z0-9-]{0,47}$') 'Workspace ID safe for DevPod and SSH'
        $longId = Get-DevSetupWorkspaceId (Join-Path $temporary ('project' * 20))
        Assert-True ($longId.Length -le 48) 'Long names fit DevPod workspace limit'
        Assert-True ($id -eq (Get-DevSetupWorkspaceId $project)) 'Workspace ID stable'
        Assert-True ($id -ne (Get-DevSetupWorkspaceId (Join-Path $temporary 'other/Project [one] with spaces'))) 'Equal folder names get unique IDs'

        $nested = Join-Path $project 'nested'
        [IO.Directory]::CreateDirectory($nested) | Out-Null
        Push-Location -LiteralPath $nested
        try { Assert-Throws { Initialize-DevSetupRepository -Offline -NoOpen } '*anderen Git-Repository*' }
        finally { Pop-Location }
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $nested 'README.md'))) 'Nested repository rejected before copying'
    }
    finally { Pop-Location }

    # Exercise the GitHub branch with a real local Git remote, avoiding network in tests.
    $remote = Join-Path $temporary 'template remote'
    [IO.Directory]::CreateDirectory($remote) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root '.git-repo-template') -Destination $remote -Recurse -Force
    [IO.File]::WriteAllText((Join-Path $remote '.git-repo-template/from-remote.txt'), 'fresh template')
    & $gitExecutable -C $remote init --initial-branch=main | Out-Null
    & $gitExecutable -C $remote add --all
    & $gitExecutable -C $remote -c user.name=Test -c user.email=test@example.invalid -c core.hooksPath=/dev/null commit -qm 'test fixture'
    $script:cloneCount = 0
    $script:failClone = $false
    function git {
        if ($args[0] -eq 'clone') {
            $script:cloneCount++
            Assert-True ($args[-2] -eq 'https://github.com/Zweikaufswagen/devsetup.git') 'Canonical remote requested'
            if ($script:failClone) { $global:LASTEXITCODE = 1; return }
            & $gitExecutable clone --quiet -- $remote $args[-1]
        }
        else { & $gitExecutable @args }
    }
    $onlineProject = Join-Path $temporary 'online'
    [IO.Directory]::CreateDirectory($onlineProject) | Out-Null
    Push-Location -LiteralPath $onlineProject
    try {
        Initialize-DevSetupRepository -NoOpen
        Assert-True (Test-Path -LiteralPath 'from-remote.txt') 'Downloaded template used'
        Initialize-DevSetupRepository -NoOpen
        Assert-True ($script:cloneCount -eq 2) 'Fresh clone on every init'
        $script:failClone = $true
        Remove-Item -LiteralPath '.devcontainer/Dockerfile'
        Initialize-DevSetupRepository -NoOpen -WarningVariable fallbackWarning
        Assert-True ($fallbackWarning -match 'installierte Vorlage') 'Fallback explicitly reported'
        Assert-True (Test-Path -LiteralPath '.devcontainer/Dockerfile') 'Offline fallback still complete'
    }
    finally { Pop-Location; Remove-Item Function:git }

    $profilePath = Join-Path $temporary 'profile.ps1'
    [IO.File]::WriteAllText($profilePath, @'
# User setting
$env:MY_SETTING = 'keep'
# Load personal dotfiles
. "$env:DOTFILES_HOME/powershell/Microsoft.PowerShell_profile.ps1"
'@)
    Update-DevSetupProfile $profilePath
    $profileContent = [IO.File]::ReadAllText($profilePath)
    Assert-True ($profileContent -match 'MY_SETTING') 'Personal profile content retained'
    Assert-True ($profileContent -notmatch 'DOTFILES_HOME') 'Legacy loader removed'
    Assert-True ($profileContent -match 'DEVSETUP_HOME') 'New loader installed'
    Update-DevSetupProfile $profilePath
    Assert-True ([IO.File]::ReadAllText($profilePath) -ceq $profileContent) 'Profile installation idempotent'
    Assert-True (@(Get-ChildItem -LiteralPath $temporary -Filter 'profile.ps1.bak-*').Count -eq 1) 'Profile backed up only when changed'

    # Provider setup must be repeatable and report a failed external command.
    $script:hasProvider = $false
    $script:providerAdds = 0
    $script:failProvider = $false
    function devpod.exe {
        if ($args[1] -eq 'list') {
            if ($script:hasProvider) { '{"docker": {"default": true}}' } else { '{}' }
        }
        elseif ($args[1] -eq 'add') {
            $script:providerAdds++
            $script:hasProvider = $true
        }
        $global:LASTEXITCODE = if ($script:failProvider) { 1 } else { 0 }
    }
    Initialize-DevSetupProvider
    Initialize-DevSetupProvider
    Assert-True ($script:providerAdds -eq 1) 'Docker provider added once'
    $script:failProvider = $true
    Assert-Throws { Initialize-DevSetupProvider } '*Provider konnten nicht gelesen*'
    Remove-Item Function:devpod.exe

    function docker { 'linux'; $global:LASTEXITCODE = 0 }
    Start-DevSetupDocker
    function docker { 'windows'; $global:LASTEXITCODE = 0 }
    Assert-Throws { Start-DevSetupDocker } '*Linux-Containern*'
    Remove-Item Function:docker

    # Mock the external applications, execute the actual SSH repair and opening sequence.
    $env:USERPROFILE = Join-Path $temporary 'Windows User'
    [IO.Directory]::CreateDirectory((Join-Path $env:USERPROFILE '.ssh')) | Out-Null
    $sshConfig = Join-Path $env:USERPROFILE '.ssh/config'
    $originalSsh = @'
Host private
  ProxyCommand "C:\Custom Tool\proxy.exe"
# DevPod Start project.devpod
Host project.devpod
  ProxyCommand "C:\Users\Windows User\devpod.exe" ssh --stdio project
# DevPod End project.devpod
'@
    [IO.File]::WriteAllText($sshConfig, $originalSsh)
    $script:events = @()
    $script:failUp = $false
    function Start-DevSetupDocker { $script:events += 'docker' }
    function Update-DevSetupProcessPath { }
    function Initialize-DevSetupProvider { $script:events += 'provider' }
    function devpod.exe {
        $script:events += 'up'
        Assert-True ($args[0] -eq 'up' -and $args[1] -eq $project) 'Windows source path passed as one argument'
        Assert-True (($args -join '|') -match '\|--provider\|docker\|--ide\|none$') 'Docker used with IDE launch deferred'
        $global:LASTEXITCODE = if ($script:failUp) { 1 } else { 0 }
    }
    function codium {
        $script:events += 'codium'
        $content = [IO.File]::ReadAllText($sshConfig)
        Assert-True ($content.Contains('"C:/Users/Windows User/devpod.exe"')) 'SSH paths fixed before editor opens'
        Assert-True ($content.Contains('"C:\Custom Tool\proxy.exe"')) 'Non-DevPod SSH configuration unchanged'
        Assert-True ($args[-1] -eq '/workspaces/project') 'Editor opens exact workspace'
        Assert-True ($args[2] -eq 'ssh-remote+project.devpod') 'Editor connects to correct SSH host'
        $global:LASTEXITCODE = 0
    }
    Open-DevPod -Id project -Source $project
    Assert-True (($script:events -join ',') -eq 'docker,provider,up,codium') 'Startup order'
    $backups = @(Get-ChildItem -LiteralPath (Split-Path $sshConfig) -Filter 'config.bak-*')
    Assert-True ($backups.Count -eq 1) 'SSH configuration backed up'
    Assert-True ([IO.File]::ReadAllText($backups[0].FullName) -ceq $originalSsh) 'SSH backup byte content preserved'
    Open-DevPod -Id project -Source $project
    Assert-True (@(Get-ChildItem -LiteralPath (Split-Path $sshConfig) -Filter 'config.bak-*').Count -eq 1) 'No unnecessary SSH writes'
    $script:failUp = $true
    $script:events = @()
    Assert-Throws { Open-DevPod -Id project -Source $project } '*devpod up ist fehlgeschlagen*'
    Assert-True ($script:events -notcontains 'codium') 'Editor not opened after failed container start'
    Write-Host 'All devsetup regression checks passed.'
}
finally {
    $env:USERPROFILE = $originalUserProfile
    $env:GIT_TERMINAL_PROMPT = $originalGitPrompt
    Remove-Item -LiteralPath $temporary -Recurse -Force
}
