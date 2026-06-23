function keychain-add --description "Ajoute une clé SSH dans l'agent via keychain"
    if test "$argv[1]" = -l
        for pubkey in (find $HOME/.ssh -maxdepth 1 -name '*.pub' 2>/dev/null)
            string replace -r '\.pub$' '' (basename "$pubkey")
        end
        return
    else if test "$argv[1]" = -h
        echo "Usage:"
        echo "  keychain-add [-h] [-l] [<clé>]"
        echo ""
        echo "Options:"
        echo "    -h    Affiche l'aide."
        echo "    -l    Liste les clés SSH disponibles dans \$HOME/.ssh."
        echo "    <clé> Nom de la clé à charger (défaut: id_ed25519)."
        return
    end

    set -l key id_ed25519
    test -n "$argv[1]"; and set key $argv[1]
    keychain --agents ssh $key
    set -l kf $HOME/.keychain/(hostname)-fish
    test -e $kf; and source $kf
end
