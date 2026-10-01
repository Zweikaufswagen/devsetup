# Dotfiles

Small, scalable dotfiles setup for DevPod/devcontainers and local shells.

## Structure

```text
.dotfiles/
├── .git-repo-template/
│   ├── .gitignore
│   ├── README.md
│   └── .pre-commit-config.yaml
├── powershell/
│   ├── Microsoft.PowerShell_profile.ps1
│   └── functions/
│       └── git-repo.ps1
├── shell/
│   ├── init.sh
│   └── git-repo.sh
├── install.sh
└── install.ps1
```

## DevPod setup once (Powershell)

```powershell
devpod context set-options `
    -o DOTFILES_URL=https://github.com/Zweikaufswagen/dotfiles `
    -o DOTFILES_SCRIPT=install.sh
```

## DevPod / Linux devcontainer

Run once after the dotfiles repository is cloned:

```bash
./install.sh
```

The installer configures Bash, Zsh and PowerShell (`pwsh`).

## Windows PowerShell

```powershell
./install.ps1
. $PROFILE
```

## Create a repository

Bash / Zsh:

```bash
newrepo my-project
```

PowerShell:

```powershell
New-GitRepo my-project
# or
newrepo my-project
```

To initialize the current directory:

```text
newrepo .
```

The command copies the repository template, replaces `{{PROJECT_NAME}}` in
`README.md`, initializes Git with the `main` branch and runs `pre-commit install`
when `pre-commit` is available.

## Extending later

- Add PowerShell functions as separate `.ps1` files under `powershell/functions/`.
- Add shared Bash/Zsh functions under `shell/` and source them from `shell/init.sh`.
- Add more standard project files under `.git-repo-template/`.
