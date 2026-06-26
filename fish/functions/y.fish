function y --description "yazi : ouvre le gestionnaire de fichiers, cd dans le dossier quitté"
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file=$tmp
    set -l cwd (command cat -- $tmp)
    rm -f -- $tmp
    if test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- $cwd
    end
end
