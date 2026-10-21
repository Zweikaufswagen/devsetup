# devsetup

Einmal Windows einrichten, danach im Projektordner **`devsetup init`** ausführen.
Der Befehl holt die Projektvorlage von GitHub, initialisiert Git und öffnet deinen
lokal gemounteten Devcontainer über DevPod in **VSCodium**.

## Einmal installieren

Voraussetzungen: Windows 10/11 (64 Bit), **Git Bash** und **winget**
([App Installer](https://aka.ms/getwinget)). In Git Bash:

```git bash
git clone https://github.com/Zweikaufswagen/devsetup.git
cd devsetup
./install.sh
```

Bei einem vorhandenen Klon genügt `bash install.sh` im Repository.
Der Installer ruft Windows PowerShell auf und erledigt:

- Fehlendes Git, VSCodium und Docker Desktop über winget installieren.
- Fehlende DevPod-CLI aus dem aktuellen offiziellen Windows-Release herunterladen.
- VSCodium-Erweiterung `jeanp413.open-remote-ssh` installieren.
- Befehle und Offline-Vorlage nach `%LOCALAPPDATA%\devsetup` kopieren und dessen
  `bin` zum Benutzer-PATH hinzufügen.
- Profile für Windows PowerShell 5.1 und PowerShell 7 ergänzen. Vorhandene Inhalte
  bleiben erhalten; vor Änderungen wird eine `.bak-*`-Kopie erstellt.
- Docker Desktop starten und den Docker-Provider für DevPod einrichten.

Windows kann für Docker eine Administratorbestätigung, aktivierte Virtualisierung,
WSL 2 und einen Neustart verlangen. Docker Desktop beim ersten Start fertig
konfigurieren und **Linux-Container** verwenden. Dafür brauchst du keine eigene
Ubuntu-Installation und keinen Workflow im WSL-Terminal. Wenn Docker noch nicht
bereit ist, bleiben die Befehle installiert; `devsetup init` versucht die Einrichtung
beim Start erneut. Scheitert eine Programminstallation, nach Beheben der Ursache
`bash install.sh` wiederholen.

Danach ein **neues Terminal** öffnen. Falls PATH noch fehlt, Windows Terminal bzw.
VSCodium vollständig schließen und neu öffnen. Der Installer kann die Umgebung
eines bereits laufenden übergeordneten Terminals nicht ändern.

Alternativ aus Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

## Neues Projekt

Im gewünschten Windows-Ordner, in PowerShell, CMD oder Git Bash:

```text
devsetup init
```

1. Lädt den aktuellen Standardbranch von
   [Zweikaufswagen/devsetup](https://github.com/Zweikaufswagen/devsetup.git) per
   flachem Git-Klon in ein temporäres Verzeichnis.
2. Kopiert **alle Dateien aus `.git-repo-template/`**, einschließlich versteckter
   Dateien und `.devcontainer/`, in den aktuellen Ordner. Fehlende Dateien werden
   auch innerhalb vorhandener Ordner ergänzt. Vorhandene Dateien werden weder
   überschrieben noch ersetzt. Nur neu kopierte READMEs erhalten den Projektnamen.
3. Initialisiert Git auf `main`, sofern im Ordner noch kein Repository vorhanden
   ist. Ein neuer Ordner innerhalb eines anderen Git-Repositorys wird abgelehnt.
4. Startet Docker Desktop bei Bedarf und dann den DevPod-Workspace mit dem lokalen
   Ordner als Quelle und dem Docker-Provider.
5. Korrigiert Windows-Pfade in den von DevPod erzeugten `ProxyCommand`-Zeilen der
   SSH-Konfiguration, sichert die Originaldatei und öffnet VSCodium über Remote SSH.

**Deine Dateien liegen auf Windows.** Der Projektordner wird als Bind Mount unter
`/workspaces/project` eingebunden. Änderungen in VSCodium erscheinen direkt im
Windows-Ordner und umgekehrt. Die Workspace-ID enthält den Ordnernamen und einen
kurzen Hash des vollständigen Pfads; gleichnamige Projekte bleiben getrennt.
Ein verschobener Projektordner erhält eine andere ID.

Ist GitHub nicht erreichbar oder die entfernte Vorlage unvollständig, verwendet
`init` mit einer sichtbaren Warnung die bei der Installation gespeicherte Vorlage.
Es wird kein GitHub-Repository angelegt, kein Commit erstellt und nichts gepusht.

## Weiterarbeiten

Im Projektordner:

```text
devsetup open
```

Dadurch startet der vorhandene Workspace wieder und öffnet VSCodium samt SSH-Fix.
Wenn Docker beim ersten `init` noch nicht bereit war, reicht nach der Einrichtung
auch `devsetup open`: Die Projektdateien sind bereits angelegt.

Weitere Optionen:

```text
devsetup init -Offline          # Gespeicherte Vorlage ohne GitHub verwenden
devsetup init -NoOpen           # Nur Dateien und Git anlegen
devsetup init -Offline -NoOpen  # Beides kombinieren
devsetup help
```

In PowerShell ist außerdem `Open-DevPod -Id NAME -Source .` verfügbar. Für eine
abweichende Containerstruktur lässt sich `-RemoteFolder /anderer/pfad` angeben.

## Alte Devcontainer sauber entfernen

Die folgenden Befehle im **Windows-Terminal** (PowerShell, CMD oder Git Bash)
ausführen; Docker Desktop muss laufen. Das zugehörige VSCodium-Fenster vorher
schließen.

1. Mit `devpod list` die vorhandenen Workspaces anzeigen und die ID des alten
   Projekts auswählen. Nach dem Verschieben eines Projektordners kann noch ein
   Workspace mit der alten, pfadabhängigen ID vorhanden sein.
2. Den ausgewählten Workspace über DevPod löschen, damit sowohl die zugehörige
   Containerumgebung als auch der DevPod-Workspace-Eintrag entfernt werden:

   ```text
   devpod delete DEINE-WORKSPACE-ID
   ```

   `DEINE-WORKSPACE-ID` durch die ID aus der Liste ersetzen und die Rückfrage
   prüfen. Anschließend mit `devpod list` kontrollieren, dass der Eintrag weg ist.

**Der lokale Windows-Projektordner bleibt bei dieser Vorlage erhalten**, da er
nur als Bind Mount eingebunden ist. Dateien und manuell installierte Werkzeuge,
die ausschließlich im Container liegen, gehen beim Löschen verloren; benötigte
Daten vorher in den Projektordner kopieren. Zusätzliche Volumes, etwa für
Datenbanken, vor dem Löschen separat sichern.

Willst du nur pausieren, genügt `devpod stop DEINE-WORKSPACE-ID`.
Mit `devsetup open` im Projektordner kannst du einen gestoppten Workspace wieder
starten oder nach dem Löschen neu erstellen.

### Optional: Docker-Speicher freigeben

Images und Build-Cache können nach dem Löschen erhalten bleiben. Zunächst den
Speicherverbrauch prüfen:

```text
docker system df
```

Bei Bedarf ungetaggte, unbenutzte Images und unbenutzten Build-Cache entfernen;
die Rückfragen jeweils prüfen:

```text
docker image prune
docker builder prune
```

Diese Bereinigung betrifft Docker insgesamt, also auch andere Projekte. Spätere
Builds können dadurch länger dauern. Für einzelne übrig gebliebene Container,
Images oder Volumes in Docker Desktop gezielt die Ressource auswählen, ihre
Zuordnung prüfen und sie erst dann löschen. Container regulärer DevPod-Workspaces
immer zuerst mit `devpod delete` entfernen.

Kein pauschales `docker system prune --volumes` verwenden: Es kann auch Ressourcen
anderer Projekte und unbenutzte Daten-Volumes entfernen.

## Repository-Struktur

```text
devsetup/
├── install.sh                 # Einstieg aus Windows Git Bash
├── install.ps1                # Windows-Installation
├── bin/                       # devsetup für CMD, PowerShell und Git Bash
├── powershell/
│   ├── devsetup.ps1            # init / open / help
│   ├── Microsoft.PowerShell_profile.ps1
│   └── functions/             # Installation, Projektvorlage, DevPod und SSH-Fix
├── .git-repo-template/
│   ├── .devcontainer/         # Einzige Devcontainer-Vorlage
│   ├── .gitignore
│   ├── .pre-commit-config.yaml
│   └── README.md
└── tests/Test-DevSetup.ps1
```

Die Linux-/macOS-Hostinstallation und die bisherigen `newrepo`-/Dotfiles-Loader
entfallen. Der **Container selbst bleibt Linux**. Es wird kein Host-Installer
im Container ausgeführt. Beim Umstieg entfernt der Installer die alten Loader
mit `DOTFILES_HOME` aus den PowerShell-Profilen und leert `DOTFILES_URL` sowie
`DOTFILES_SCRIPT` im aktuellen DevPod-Kontext. Andere Kontexte bleiben bestehen.
Alte manuell eingefügte `Open-DevPod`-Definitionen im persönlichen Profil bei Bedarf
entfernen, damit sie die installierte Funktion nicht überlagern.

## Aktualisieren und anpassen

Die Online-Vorlage wird bei jedem `init` neu geladen. Änderungen hier unter
`.git-repo-template/` committen und auf GitHub veröffentlichen, damit neue Projekte
sie bekommen. Bestehende Projektdateien werden nicht automatisch aktualisiert.

Um installierte Befehle, Profile und die Offline-Vorlage zu aktualisieren:

```bash
git pull --ff-only
bash install.sh
```

Der ursprüngliche Klon darf danach verschoben werden; die Installation verwendet
seine kopierten Dateien. Neue Programme im Container ergänzt du im
[Template-Dockerfile](.git-repo-template/.devcontainer/Dockerfile). Weitere Hinweise
stehen in der [Container-Anleitung](.git-repo-template/.devcontainer/README.md).

## Prüfen

Ohne Installation oder Docker-Start, unter Windows PowerShell 5.1 oder PowerShell 7:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-DevSetup.ps1
```

Die Regressionstests prüfen echte Git-Initialisierung, einen lokalen Git-Remote als
GitHub-Ersatz, Offline-Fallback, bestehende Dateien, Pfade mit Leerzeichen und
Klammern, Profilmigration sowie den SSH-Fix und die Startreihenfolge mit simulierten
externen Programmen. Die GitHub-Actions-Konfiguration führt sie in beiden
Windows-PowerShell-Versionen aus. Eine echte Docker-/VSCodium-Sitzung muss auf
Windows geprüft werden.
