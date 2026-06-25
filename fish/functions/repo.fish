function repo --description "Parcourt les repos ghq avec yazi ; cd dans le dossier quitté"
    if not command -q ghq; or not command -q yazi
        echo "repo: ghq et yazi sont requis" >&2
        return 1
    end

    set -l tmp (mktemp -t repo-cwd.XXXXXX)
    yazi (ghq root) --cwd-file=$tmp
    set -l cwd (command cat -- $tmp)
    rm -f -- $tmp
    if test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- $cwd
    end
end
