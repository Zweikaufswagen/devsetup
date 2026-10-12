# Dein persönlicher Devcontainer

Diese Basis ist für DevPod mit dem Docker-Provider gedacht. Kopiere den ganzen
Ordner `.devcontainer/` in das Hauptverzeichnis eines Projekts. DevPod erkennt
ihn dort automatisch. Ein Container pro Projekt hält dessen Umgebung unabhängig
von deinen anderen Projekten.

## Was enthalten ist

| Bestandteil | Zweck |
| --- | --- |
| Debian Bookworm Slim + Bash | Kleine Linux-Basis und Shell für deine vorhandenen Dotfiles |
| `git` | Versionsverwaltung |
| `uv` und `uvx` (0.12.24) | Python-Versionen, Projektabhängigkeiten und Python-Werkzeuge |
| `tmux` | Mehrere Terminalfenster und wieder aufnehmbare Sitzungen |
| `curl`, `unzip` | Downloads und ZIP-Dateien |
| `sudo` | Bei Bedarf administrative Befehle im Container |
| `ca-certificates`, `openssh-client` | HTTPS und Git über SSH |
| `libstdc++6` | Laufzeitbibliothek für den optionalen VS-Code-Server |

Du arbeitest als Benutzer `devpod`, mit passwortlosem `sudo` im Container.
Python wird bei Bedarf von `uv` heruntergeladen. Die Konfiguration verwendet
keine zusätzlichen Devcontainer-Features; die kurze Paketliste im Dockerfile
reicht für den Anfang aus.

## 1. Windows vorbereiten

Für deinen Windows-Rechner empfehle ich **WSL 2 mit Ubuntu**. Führe die folgenden
Linux-Befehle in einem Ubuntu-/WSL-Terminal aus. Docker und DevPod müssen aus
diesem Terminal erreichbar sein.

1. Falls noch nicht vorhanden: In einer PowerShell als Administrator
   `wsl --install -d Ubuntu` ausführen, anschließend bei Aufforderung neu starten
   und Ubuntu öffnen (wsl -d Ubuntu). Beim ersten Start einen Linux-Benutzer anlegen.
2. [Docker Desktop](https://www.docker.com/products/docker-desktop/) installieren
   und starten. In den Einstellungen die WSL-2-Engine und unter
   **Resources → WSL Integration** deine Ubuntu-Distribution aktivieren.
3. In Ubuntu die benötigten Host-Werkzeuge bereitstellen:

   ```bash
   sudo apt-get update
   sudo apt-get install -y git curl ca-certificates
   ```

4. Die DevPod-CLI **in WSL** installieren. Für einen üblichen Windows-PC mit
   x86-64-Prozessor (`uname -m` zeigt `x86_64`):

   ```bash
   curl -fL https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64 -o /tmp/devpod
   sudo install -m 0755 /tmp/devpod /usr/local/bin/devpod
   rm /tmp/devpod
   ```

   Bei ARM64 (`uname -m` zeigt `aarch64`) im Downloadnamen `amd64` durch `arm64`
   ersetzen. Weitere Installationswege:
   [DevPod installieren](https://devpod.sh/docs/getting-started/install).

5. Prüfen und den Docker-Provider einmal einrichten:

   ```bash
   docker version
   devpod version
   devpod provider add docker
   devpod provider use docker
   ```

   `docker version` muss Informationen zu **Client und Server** anzeigen.
   Ist der Provider schon eingerichtet, musst du ihn nicht erneut hinzufügen.
   Ein besonderes Docker-Netzwerk oder `DOTFILES_DIR` ist für diese Basis nicht nötig.

### Falls Docker „permission denied“ meldet

Wenn `docker version` nur den Client anzeigt und den Zugriff auf
`/var/run/docker.sock` verweigert, zuerst im **Host-/WSL-Terminal** prüfen:

```bash
ls -l /var/run/docker.sock
id -nG
```

Gehört der Socket zur Gruppe `docker` (typisch: `srw-rw---- … root docker …`)
und fehlt diese Gruppe bei `id -nG`, deinen WSL-Benutzer hinzufügen:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

`newgrp docker` öffnet eine neue Shell mit der aktualisierten Gruppenzugehörigkeit.
Danach getrennt ausführen:

```bash
docker version
```

Erst wenn **Client und Server ohne sudo** angezeigt werden, mit DevPod fortfahren.
Bei einem bereits angelegten Workspace genügt `devpod up erstes-projekt --ide none`.
Gehört der Socket zu einer anderen Gruppe oder bleibt der Fehler bestehen,
die Ausgaben von `ls -l /var/run/docker.sock`, `id -nG` und `sudo docker version`
zur Diagnose verwenden. DevPod weiterhin als normalen Benutzer starten.

Unter Linux bzw. macOS genügen ebenfalls ein laufendes Docker, Git und die
DevPod-CLI; WSL entfällt dort.

## 2. Deine Dotfiles einmalig mit DevPod verbinden

Im **Host-/WSL-Terminal**:

```bash
devpod context set-options -o DOTFILES_URL=https://github.com/Zweikaufswagen/dotfiles.git -o DOTFILES_SCRIPT=install.sh
```

Diese Einstellung gilt im aktuellen DevPod-Kontext auch für weitere Workspaces.
Beim Start klont DevPod deine Dotfiles nach `~/dotfiles` **im Container** und führt
`install.sh` als Containerbenutzer aus. Dein vorhandener Installer legt den Link
`~/.dotfiles` an und lädt `shell/init.sh` über `.bashrc`. Damit ist zum Beispiel
deine Funktion `newrepo` verfügbar. Die PowerShell-Konfiguration wird ebenfalls
verlinkt; PowerShell selbst ist in dieser schlanken Basis nicht installiert.

Alternativ kannst du die Dotfiles nur für einen Start explizit angeben:

```bash
devpod up . --id erstes-projekt --ide none --dotfiles https://github.com/Zweikaufswagen/dotfiles.git --dotfiles-script install.sh
```

Die Dotfiles bleiben persönliche DevPod-Einstellungen und werden nicht in das
Image eingebaut. Das Image und derselbe `.devcontainer/` funktionieren daher auch
ohne Dotfiles, etwa beim direkten Start mit VS Code. Die automatische
Dotfiles-Installation in dieser Anleitung übernimmt DevPod.

## 3. Dein erstes Projekt starten

Im **Host-/WSL-Terminal** einen Projektordner im Linux-Dateisystem anlegen und
die neue Konfiguration aus deinem aktuellen Windows-Arbeitsordner kopieren:

```bash
mkdir -p ~/projekte/erstes-projekt
cp -R "/mnt/c/Users/LZieboll/Documents/Lucas Workspace/Projekte/dev_setup_test/.devcontainer" ~/projekte/erstes-projekt/
cd ~/projekte/erstes-projekt
git init --initial-branch=main
devpod up . --id erstes-projekt --ide none
devpod ssh erstes-projekt
```

`--id` setzt einen eindeutigen Workspace-Namen. Der erste Build lädt Images und
Pakete herunter und dauert deshalb länger. `--ide none` startet einen Workflow
ohne automatisch geöffneten Editor. Nach `devpod ssh` arbeitest du **im Container**.
Das Projekt liegt unter `/workspaces/…`; `pwd` zeigt den tatsächlichen Pfad.
Falls du im Home-Verzeichnis landest, wechsle mit `cd /workspaces/erstes-projekt`
in das Projekt.

Jetzt im **Container** prüfen:

```bash
whoami
git --version
uv --version
tmux -V
curl --version
unzip -v
sudo -n true
type newrepo
```

`whoami` sollte `devpod` ausgeben. Bei den Dotfiles muss `newrepo` als Funktion
erkannt werden. Falls du schon eine Shell geöffnet hattest: `source ~/.bashrc`.

## 4. Mit Python entwickeln

Im **Projektverzeichnis im Container** ein neues Python-Projekt vorbereiten:

```bash
uv python install 3.13
uv init --bare --python 3.13
uv add --dev ruff pytest
uv sync
uv run python -c 'print("Hallo aus meinem Devcontainer!")'
```

`uv init` ist nur für ein neues Projekt erforderlich. In einem bestehenden
Projekt mit `pyproject.toml` startest du mit `uv sync`; `uv` verwendet dessen
Python-Vorgaben. Bei vorhandenem, aktuellem Lockfile kannst du mit
`uv sync --locked` sicherstellen, dass es nicht verändert wird.

Für ein Skript `main.py` und spätere Abhängigkeiten:

```bash
uv run main.py
uv add requests
uv run ruff check .
uv run ruff format .
```

`uv` legt die virtuelle Umgebung `.venv/` im Projekt an. `pyproject.toml`,
`uv.lock` und gegebenenfalls `.python-version` kommen in Git; `.venv/`,
`__pycache__/`, `.ruff_cache/` und `.pytest_cache/` gehören in `.gitignore`.
Eine vorhandene Windows- oder macOS-`.venv` muss für Linux neu angelegt werden.
Vorübergehend installierte Pakete werden durch einen Rebuild nicht zu dauerhaft
definierten Abhängigkeiten: Nutze dafür `uv add`.

Vor dem ersten Commit deinen Namen und deine tatsächliche Commit-E-Mail
eintragen, sofern sie noch nicht konfiguriert sind:

```bash
git config --global user.name "Lucas Zieboll"
git config --global user.email "DEINE-COMMIT-EMAIL"
```

Langfristig kannst du diese Einstellungen in deinen Dotfiles verwalten.
Für GitHub über SSH nutzt du einen SSH-Agent auf dem Host; DevPod unterstützt
dessen Weiterleitung. Prüfe im Container mit `ssh-add -l`, ob Schlüssel verfügbar
sind. Git-Autor und GitHub-Anmeldung sind zwei getrennte Einstellungen.

## 5. Terminal, Editor und tägliche Arbeit

Eine tmux-Sitzung im **Container** starten oder wieder aufnehmen:

```bash
tmux new-session -A -s dev
```

`Ctrl+b`, dann `d` löst dich von der Sitzung. Bei der nächsten Verbindung mit
`devpod ssh erstes-projekt` und dem gleichen tmux-Befehl kannst du weiterarbeiten.
Die Sitzung bleibt beim Trennen der SSH-Verbindung bestehen; ein Stoppen oder
Neuerstellen des Containers beendet seine laufenden Prozesse.

Die Minimalbasis enthält noch keinen Terminaleditor. Für einen grafischen
Editor kannst du im **Host-/WSL-Terminal** den Workspace so öffnen:

```bash
devpod up erstes-projekt --ide vscode
# Alternativ bei installiertem VSCodium:
devpod up erstes-projekt --ide codium
```

Für Python im Editor den Interpreter `.venv/bin/python` im Projekt auswählen.
Mit `exit` verlässt du die Container-Shell. Die folgenden Befehle laufen wieder
auf dem **Host**:

```bash
devpod list
devpod stop erstes-projekt
devpod up erstes-projekt --ide none
devpod ssh erstes-projekt
```

Bei dieser Anleitung verwendet DevPod einen lokalen Projektordner: Änderungen
an den Projektdateien landen auch im Ordner `~/projekte/erstes-projekt` auf dem
Host. Das Container-Home mit dem separaten Dotfiles-Klon und dort installierten
Tools wird bei `--recreate` neu angelegt. Sichere Änderungen dort vorher in Git.
Die Umgebung lässt sich mit `uv sync` und der Dotfiles-Installation wiederherstellen.

## 6. Diesen Ordner in dein Dotfiles-Repo übernehmen

Im **Host-/WSL-Terminal**, falls du dort noch keinen Dotfiles-Klon hast:

```bash
mkdir -p ~/projekte
git clone https://github.com/Zweikaufswagen/dotfiles.git ~/projekte/dotfiles
cp -R "/mnt/c/Users/LZieboll/Documents/Lucas Workspace/Projekte/dev_setup_test/.devcontainer" ~/projekte/dotfiles/
cd ~/projekte/dotfiles
git diff --no-index /dev/null .devcontainer/devcontainer.json
```

Der letzte Befehl zeigt die neue Konfiguration; Exitcode 1 bedeutet hier, dass
Unterschiede gefunden wurden. Bei einem vorhandenen Klon nutze dessen Pfad und
prüfe vor dem Kopieren, ob bereits ein `.devcontainer/` existiert.

Du kannst den ganzen Ordner anschließend wie deine anderen Dotfiles committen.
Nach dem Kopieren zum Beispiel die neuen Dateien gezielt prüfen und committen:

```bash
git status --short
git add .devcontainer
git diff --cached
git commit -m "feat(devcontainer): add minimal DevPod environment"
git push
```

Ein Push setzt deine GitHub-Anmeldung im Host-/WSL-Terminal voraus. Erst danach
stehen die neuen Dateien auch dem separat geklonten Dotfiles-Repo im Container
zur Verfügung.

Der Root-Ordner `.devcontainer/` ist deine persönliche Vorlage und erlaubt auch,
das Dotfiles-Repo selbst mit `devpod up . --ide none` zu öffnen.

Für andere Projekte genügt künftig:

```bash
cp -R ~/projekte/dotfiles/.devcontainer ~/projekte/mein-projekt/
cd ~/projekte/mein-projekt
devpod up . --id mein-projekt --ide none
```

`~/projekte/mein-projekt` muss bereits existieren. Die Kopie wird mit dem jeweiligen
Projekt versioniert; spätere Änderungen an deiner Vorlage werden nicht automatisch
in bestehende Projekte übertragen.

Damit deine vorhandene Funktion `newrepo` den Devcontainer automatisch mitkopiert,
kannst du zusätzlich eine Kopie in dein bestehendes Repo-Template legen:

```bash
cp -R ~/projekte/dotfiles/.devcontainer ~/projekte/dotfiles/.git-repo-template/
```

Deine Funktion kopiert bereits sämtliche Template-Dateien einschließlich
versteckter Ordner. Bei Änderungen die beiden Kopien bewusst gemeinsam pflegen.

## 7. Programme und Dotfiles später ergänzen

**Systemprogramme:** In `Dockerfile` die alphabetische `apt-get install`-Liste
erweitern. Zum Beispiel `ripgrep` für schnelle Textsuche, `nano` als einfacher
Terminaleditor oder `build-essential` sobald ein Paket Compiler benötigt.
Diese Vorschläge sind zunächst nicht installiert.

**Python-Werkzeuge:** Projektbezogen `uv add --dev ruff` verwenden.
Für ein persönliches, projektunabhängiges Python-CLI kannst du beispielsweise
`uv tool install pre-commit` nutzen. Solche Installationen im Container-Home
musst du nach einem Rebuild wiederholen; dauerhaft benötigte Werkzeuge gehören
in eine bewusst ergänzte Build- oder Setup-Anweisung.

**Weitere Laufzeiten:** Später lassen sich in `devcontainer.json` standardisierte
Features ergänzen, etwa das offizielle Node.js-Feature:

```json
"features": {
  "ghcr.io/devcontainers/features/node:1": {
    "version": "lts"
  }
}
```

Dies ist ein zusätzlicher Eintrag im bestehenden JSON-Objekt. Zwischen den
Einträgen ein Komma setzen. Für den Anfang brauchst du ihn nicht.

**uv aktualisieren:** Nur `ARG UV_VERSION` im Dockerfile ändern. Die Version ist
festgelegt; Debian-Pakete beziehen beim frischen Build die im Bookworm-Repository
verfügbaren Versionen. Für vollständig eingefrorene Builds wären zusätzlich
Image-Digests und Paket-Snapshots nötig.

Nach einer Änderung an Dockerfile oder Devcontainer-Konfiguration im
**Host-Terminal** aus dem betroffenen Projektverzeichnis neu erstellen:

```bash
devpod up . --id erstes-projekt --recreate --ide none
devpod ssh erstes-projekt
```

**Persönliche Konfiguration:** Dein `install.sh` im Dotfiles-Repo bleibt der
zentrale Einstiegspunkt. Neue Shell-Funktionen unter `shell/` anlegen und in
`shell/init.sh` laden. Für eine spätere tmux-Konfiguration könntest du eine Datei
`tmux/.tmux.conf` versionieren und im Installer ergänzen:

```bash
if [ -f "$DOTFILES_DIR/tmux/.tmux.conf" ]; then
    ln -sfn "$DOTFILES_LINK/tmux/.tmux.conf" "$HOME/.tmux.conf"
fi
```

Im **Container** aktualisierst du einen schon vorhandenen Dotfiles-Klon ausdrücklich:

```bash
git -C ~/dotfiles pull --ff-only
bash ~/dotfiles/install.sh
source ~/.bashrc
```

DevPod klont nur, wenn `~/dotfiles` noch nicht existiert; ein normaler Start zieht
keine neuen Commits automatisch. Der Container-Klon und dein Host-Klon sind
getrennte Git-Arbeitskopien. Änderungen per Commit/Push/Pull synchronisieren.
Passwörter, Tokens und private Schlüssel gehören nicht in das Dotfiles-Repo.

## Wenn etwas nicht funktioniert

- **Docker-Server nicht erreichbar:** Docker Desktop starten und die
  WSL-Integration für die verwendete Distribution prüfen.
- **Docker meldet „permission denied“:** Socket-Gruppe und Benutzergruppen wie
  in Abschnitt 1 prüfen und bei Bedarf die Mitgliedschaft in `docker` aktivieren.
- **Dotfiles-Installation schlägt fehl:** Im Container
  `bash ~/dotfiles/install.sh` ausführen und die konkrete Fehlermeldung prüfen.
  Der Installer benötigt Linux-Zeilenenden. Bei einer Pflege unter Windows im
  Dotfiles-Repo eine `.gitattributes` mit `*.sh text eol=lf` ergänzen.
- **`newrepo` fehlt:** `ls -l ~/.dotfiles` prüfen und `source ~/.bashrc` ausführen.
- **Schreibrechte im Projekt:** Projekt vorzugsweise unter `~/projekte` in WSL
  ablegen. DevPod darf die UID des Benutzers an den Linux-Host anpassen.
- **Neue Pakete fehlen:** Nach Änderungen den Container mit `--recreate`
  neu erstellen. Ein bloßer Neustart baut das Image nicht neu.

## Dateien und Quellen

- `devcontainer.json`: Build, Containerbenutzer und optionale Editor-Einstellungen.
- `Dockerfile`: Basisimage, uv-Version und zentrale Liste der Systemprogramme.
- `Dockerfile.dockerignore`: Hält lokale Dateien aus dem Build-Kontext heraus.
- `.gitattributes`: Linux-Zeilenenden für diesen Ordner beim Checkout aus Git.
- Anleitung als Grundlage: `development_setup/README.md`,
  `development_setup/docs/devpod.md` und `development_setup/docs/dotfiles.md`.
- [Deine Dotfiles](https://github.com/Zweikaufswagen/dotfiles)
- [DevPod-Dotfiles](https://devpod.sh/docs/developing-in-workspaces/dotfiles-in-a-workspace)
- [Devcontainer-Spezifikation](https://containers.dev/implementors/json_reference/)
