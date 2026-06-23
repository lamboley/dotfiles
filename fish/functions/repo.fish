function repo --description "Saute dans un repo géré par ghq (sélection fuzzy via fzf)"
    if not command -q ghq; or not command -q fzf
        echo "repo: ghq et fzf sont requis" >&2
        return 1
    end

    set -l dir (ghq list -p | fzf)
    test -n "$dir"; and cd -- "$dir"
end
