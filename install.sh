#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *) printf 'devsetup unter Windows in Git Bash installieren: bash install.sh\n' >&2; exit 1 ;;
esac

setup_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MSYS_NO_PATHCONV=1 powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass \
    -File "$(cygpath -w "$setup_root/install.ps1")" "$@"
