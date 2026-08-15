function git-remote-ssh --description "Bascule un remote git de HTTPS vers SSH"
    if test "$argv[1]" = -h
        echo "Usage:"
        echo "  git-remote-ssh [-h] [<remote>]"
        echo ""
        echo "Convertit l'URL d'un remote git de la forme HTTPS"
        echo "(https://hôte/owner/repo[.git]) vers SSH (git@hôte:owner/repo.git),"
        echo "pour pousser via la clé de l'agent SSH plutôt qu'un mot de passe."
        echo ""
        echo "Options:"
        echo "    -h        Affiche l'aide."
        echo "    <remote>  Nom du remote à convertir (défaut: origin)."
        return
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "git-remote-ssh: pas dans un dépôt git" >&2
        return 1
    end

    set -l remote origin
    test -n "$argv[1]"; and set remote $argv[1]

    set -l url (git remote get-url $remote 2>/dev/null)
    if test -z "$url"
        echo "git-remote-ssh: remote « $remote » introuvable" >&2
        return 1
    end

    if string match -q 'git@*' -- $url
        echo "git-remote-ssh: « $remote » est déjà en SSH ($url)"
        return 0
    end

    # https://hôte/owner/repo[.git] -> git@hôte:owner/repo.git
    set -l new (string replace -r '^https?://([^/]+)/(.+?)(\.git)?$' 'git@$1:$2.git' -- $url)
    if test "$new" = "$url"
        echo "git-remote-ssh: URL non reconnue (attendu https://…) : $url" >&2
        return 1
    end

    git remote set-url $remote $new
    echo "git-remote-ssh: « $remote » : $url -> $new"
end
