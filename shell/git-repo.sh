# Shared by Bash and Zsh.

newrepo() {
    local name="${1:-.}"
    local dotfiles_home="${DOTFILES_HOME:-$HOME/.dotfiles}"
    local template="$dotfiles_home/.git-repo-template"
    local repo_path
    local project_name

    if [ ! -d "$template" ]; then
        printf 'Git-Repo-Template nicht gefunden: %s\n' "$template" >&2
        return 1
    fi

    if [ "$name" = "." ]; then
        repo_path="$PWD"
        project_name="$(basename "$PWD")"
    else
        repo_path="$PWD/$name"
        project_name="$name"

        if [ -e "$repo_path" ]; then
            printf 'Ziel existiert bereits: %s\n' "$repo_path" >&2
            return 1
        fi

        mkdir -p "$repo_path" || return 1
    fi

    # Copy the complete template, including dotfiles, but do not overwrite
    # files that already exist when initializing the current directory.
    (
        cd "$template" || exit 1
        find . -mindepth 1 -maxdepth 1 -print0 | while IFS= read -r -d '' item; do
            item="${item#./}"
            if [ -e "$repo_path/$item" ] || [ -L "$repo_path/$item" ]; then
                printf 'Übersprungen, existiert bereits: %s\n' "$item" >&2
            else
                cp -a "$template/$item" "$repo_path/$item"
            fi
        done
    ) || return 1

    if [ -f "$repo_path/README.md" ]; then
        local escaped_name
        escaped_name="$(printf '%s' "$project_name" | sed 's/[\\/&]/\\&/g')"

        if sed --version >/dev/null 2>&1; then
            sed -i "s/{{PROJECT_NAME}}/$escaped_name/g" "$repo_path/README.md"
        else
            sed -i '' "s/{{PROJECT_NAME}}/$escaped_name/g" "$repo_path/README.md"
        fi
    fi

    if [ ! -d "$repo_path/.git" ]; then
        git -C "$repo_path" init --initial-branch=main || return 1
    else
        printf 'Git-Repository existiert bereits.\n'
    fi

    if command -v pre-commit >/dev/null 2>&1; then
        (
            cd "$repo_path" || exit 1
            pre-commit install
        ) || return 1
    else
        printf 'Hinweis: pre-commit ist nicht installiert; Konfiguration wurde trotzdem angelegt.\n'
    fi

    printf '\nRepository bereit: %s\n' "$repo_path"
    printf '  .gitignore\n  README.md\n  .pre-commit-config.yaml\n'
}
