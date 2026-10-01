# Shared shell initialization for Bash and Zsh.

DOTFILES_HOME="${DOTFILES_HOME:-$HOME/.dotfiles}"
export DOTFILES_HOME

if [ -f "$DOTFILES_HOME/shell/git-repo.sh" ]; then
    . "$DOTFILES_HOME/shell/git-repo.sh"
fi
