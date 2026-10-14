# Devcontainer

Dieses Projekt wird vom Windows-Host mit `devsetup init` eingerichtet und mit
`devsetup open` in VSCodium geöffnet. DevPod verwendet den Docker-Provider.
Der Windows-Projektordner ist unter **`/workspaces/project`** eingebunden.

## Enthalten

- Debian Bookworm Slim, Bash, Git und SSH-Client
- `uv`/`uvx` für Python und Werkzeuge
- `tmux`, Midnight Commander (`mc`), curl und unzip
- Benutzer `devpod` mit passwortlosem sudo im Container
- `pre-commit`, das beim Erstellen installiert und für das Projekt aktiviert wird

Git-Befehle und Commits im Container ausführen: Die Hooks werden für dessen
Python-Umgebung installiert. Beim ersten Commit lädt pre-commit seine Hook-Umgebungen.
Für einen anderen Git-Autor im Container `git config user.name` und
`git config user.email` im Projekt setzen. Zugangsdaten gehören nicht ins Repository.

## Python verwenden

Im Terminal von VSCodium:

```bash
uv init --bare --python 3.13
uv add --dev ruff pytest
uv sync
uv run python -c 'print("Hallo aus dem Devcontainer")'
```

Bei einem vorhandenen Python-Projekt genügt `uv sync`. Die virtuelle Umgebung
`.venv/` ist für Linux; nicht dieselbe Umgebung mit Windows-Python verwenden.

## Umgebung ändern

Systempakete in `Dockerfile` ergänzen. Die uv-Version steht in `ARG UV_VERSION`.
Nach einer Änderung im Windows-Projektordner zuerst mit `devpod list` die
Workspace-ID nachsehen, dann:

```powershell
devpod up . --id DEINE-WORKSPACE-ID --provider docker --recreate --ide none
devsetup open
```

Projektdateien im Bind Mount bleiben erhalten. Änderungen im Container außerhalb
des Projektordners können beim Neuaufbau verloren gehen. Zusätzliche Pakete deshalb
im Dockerfile oder in der Projektkonfiguration festhalten.

`workspaceMount` und `workspaceFolder` in `devcontainer.json` gehören zusammen.
`devsetup open` erwartet den Standardpfad `/workspaces/project`. Bei bewusst
abweichendem Pfad `Open-DevPod -Id DEINE-WORKSPACE-ID -RemoteFolder /dein/pfad`
in PowerShell verwenden.
