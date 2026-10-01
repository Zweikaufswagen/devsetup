#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_LINK="$HOME/.dotfiles"

printf 'Installing dotfiles from %s\n' "$DOTFILES_DIR"

# Stable location used by all profiles/functions.
if [ "$DOTFILES_DIR" != "$DOTFILES_LINK" ]; then
    if [ -e "$DOTFILES_LINK" ] && [ ! -L "$DOTFILES_LINK" ]; then
        printf 'ERROR: %s exists and is not a symlink.\n' "$DOTFILES_LINK" >&2
        exit 1
    fi
    ln -sfn "$DOTFILES_DIR" "$DOTFILES_LINK"
fi

# PowerShell profile for pwsh on Linux/macOS.
mkdir -p "$HOME/.config/powershell"
ln -sfn \
    "$DOTFILES_LINK/powershell/Microsoft.PowerShell_profile.ps1" \
    "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"

add_shell_loader() {
    local rc_file="$1"
    local loader='[ -f "$HOME/.dotfiles/shell/init.sh" ] && . "$HOME/.dotfiles/shell/init.sh"'

    touch "$rc_file"
    if ! grep -Fqx "$loader" "$rc_file"; then
        printf '\n# Load personal dotfiles\n%s\n' "$loader" >> "$rc_file"
    fi
}

add_shell_loader "$HOME/.bashrc"
add_shell_loader "$HOME/.zshrc"

printf '\nDotfiles installed.\n'
printf 'Open a new shell or run:\n'
printf '  source ~/.bashrc   # Bash\n'
printf '  source ~/.zshrc    # Zsh\n'
printf '  . $PROFILE         # PowerShell\n'
