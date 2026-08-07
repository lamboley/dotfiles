function ssh-b64 --description "Encode les clés SSH de ~/.ssh en fichiers .base64"
    if test "$argv[1]" = -h
        echo "Usage:"
        echo "  ssh-b64 [-h] [-l] [-c] [<clé>...]"
        echo ""
        echo "Sans argument, encode toutes les clés privées de \$HOME/.ssh en"
        echo "\$HOME/.ssh/<clé>.base64 (base64 sur une seule ligne, droits 600)."
        echo ""
        echo "Options:"
        echo "    -h       Affiche l'aide."
        echo "    -l       Liste les clés SSH disponibles dans \$HOME/.ssh."
        echo "    -c       Supprime les fichiers .base64 de \$HOME/.ssh."
        echo "    <clé>... Limite l'encodage aux clés indiquées."
        return
    else if test "$argv[1]" = -l
        __ssh_b64_keys
        return
    else if test "$argv[1]" = -c
        set -l files $HOME/.ssh/*.base64
        if test (count $files) -eq 0
            echo "ssh-b64 : aucun fichier .base64 à supprimer"
            return
        end
        rm -f -- $files
        echo "ssh-b64 : "(count $files)" fichier(s) .base64 supprimé(s)"
        return
    end

    set -l keys $argv
    test (count $keys) -eq 0; and set keys (__ssh_b64_keys)

    if test (count $keys) -eq 0
        echo "ssh-b64 : aucune clé privée trouvée dans $HOME/.ssh" >&2
        return 1
    end

    set -l failed 0
    for key in $keys
        set -l path $HOME/.ssh/$key
        if not test -f $path
            echo "ssh-b64 : clé introuvable ($path)" >&2
            set failed 1
            continue
        end

        set -l out $path.base64
        rm -f -- $out
        touch $out; and chmod 600 $out
        if base64 -w 0 <$path >$out
            echo >>$out
            echo "$key -> $out"
        else
            echo "ssh-b64 : échec de l'encodage de $key" >&2
            rm -f -- $out
            set failed 1
        end
    end

    return $failed
end

# Noms des clés privées de ~/.ssh : chaque *.pub dont la clé privée existe.
function __ssh_b64_keys
    for pubkey in (find $HOME/.ssh -maxdepth 1 -name '*.pub' 2>/dev/null)
        set -l key (string replace -r '\.pub$' '' -- $pubkey)
        test -f $key; and basename $key
    end
end
