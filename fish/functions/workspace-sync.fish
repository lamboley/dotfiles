function workspace-sync --description "Synchronise les dépôts git : fetch, stash, rebase, push --force-with-lease"
    if contains -- -h $argv; or contains -- --help $argv
        echo "Usage:"
        echo "  workspace-sync [-h] [-n] [<dossier>...]"
        echo ""
        echo "Parcourt chaque dépôt git trouvé (3 niveaux max) et, pour chacun :"
        echo "fetch, stash des modifications locales, rebase sur l'upstream, puis"
        echo "push --force-with-lease si la branche est en avance, et dépile le"
        echo "stash. En cas de conflit, le rebase est annulé, le stash restauré et"
        echo "le dépôt signalé : rien n'est poussé."
        echo ""
        echo "Options:"
        echo "    -h          Affiche l'aide."
        echo "    -n          Simulation : fetch seul, affiche l'état sans rien modifier."
        echo "    <dossier>   Racines à parcourir (défaut : dossier courant)."
        return
    end

    set -l dry 0
    set -l roots
    for arg in $argv
        switch $arg
            case -n --dry-run
                set dry 1
            case '-*'
                echo "workspace-sync : option inconnue ($arg)" >&2
                return 1
            case '*'
                set -a roots $arg
        end
    end
    test (count $roots) -eq 0; and set roots $PWD

    set -l repos
    for root in $roots
        if not test -d $root
            echo "workspace-sync : dossier introuvable ($root)" >&2
            return 1
        end
        for gitdir in (find $root -maxdepth 3 -name node_modules -prune -o -name .git -print 2>/dev/null | sort)
            set -a repos (dirname $gitdir)
        end
    end

    if test (count $repos) -eq 0
        echo "workspace-sync : aucun dépôt git trouvé dans $roots" >&2
        return 1
    end

    test $dry -eq 1; and echo "workspace-sync : simulation ("(count $repos)" dépôt(s)), aucune modification"

    set -l alerts
    for repo in $repos
        __workspace_sync_repo $repo $dry; or set -a alerts $repo
    end

    echo ""
    if test (count $alerts) -eq 0
        set_color green
        echo (count $repos)" dépôt(s) synchronisé(s), rien à signaler."
        set_color normal
    else
        set_color yellow
        echo (count $alerts)"/"(count $repos)" dépôt(s) demandent une intervention :"
        set_color normal
        for repo in $alerts
            echo "  $repo"
        end
    end
end

# Traite un dépôt. Retourne 1 si le dépôt demande une intervention manuelle.
function __workspace_sync_repo --argument-names dir dry
    # Mode batch : on échoue plutôt que de bloquer sur une demande de mot de
    # passe ou de passphrase au milieu d'une boucle sur des dizaines de dépôts.
    set -lx GIT_TERMINAL_PROMPT 0
    set -lx GIT_SSH_COMMAND "ssh -oBatchMode=yes"

    set -l name (string replace -r "^$HOME/" '~/' -- $dir)

    set -l branch (git -C $dir branch --show-current 2>/dev/null)
    if test -z "$branch"
        __workspace_sync_line yellow $name "HEAD détachée — ignoré"
        return 1
    end

    if not git -C $dir fetch --all --prune --quiet >/dev/null 2>&1
        __workspace_sync_line red $name "$branch : fetch impossible"
        return 1
    end

    set -l upstream (git -C $dir rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    if test -z "$upstream"
        __workspace_sync_line yellow $name "$branch : pas d'upstream — ignoré"
        return 1
    end

    # Le SHA de l'upstream tel qu'on vient de le fetcher : c'est la valeur
    # attendue par --force-with-lease, plus sûre que la forme sans argument.
    set -l expect (git -C $dir rev-parse $upstream)
    set -l counts (git -C $dir rev-list --left-right --count $upstream...HEAD | string split -- \t)
    set -l behind $counts[1]
    set -l ahead $counts[2]

    set -l changes (git -C $dir status --porcelain)
    set -l dirty (count $changes)

    if test $dry -eq 1
        set -l plan "$branch : $behind derrière, $ahead devant"
        test $dirty -gt 0; and set plan "$plan, $dirty fichier(s) à stasher"
        test $behind -gt 0 -a $ahead -gt 0; and set plan "$plan -> rebase + push forcé"
        __workspace_sync_line cyan $name $plan
        return 0
    end

    set -l stashed 0
    if test $dirty -gt 0
        if git -C $dir stash push --include-untracked --quiet --message workspace-sync
            set stashed 1
        else
            __workspace_sync_line red $name "$branch : stash impossible — ignoré"
            return 1
        end
    end

    set -l rebased 0
    if test $behind -gt 0
        if not git -C $dir rebase --quiet $upstream >/dev/null 2>&1
            git -C $dir rebase --abort >/dev/null 2>&1
            test $stashed -eq 1; and git -C $dir stash pop --quiet >/dev/null 2>&1
            __workspace_sync_line red $name "$branch : CONFLIT de rebase sur $upstream — dépôt inchangé"
            return 1
        end
        set rebased 1
    end

    set -l pushed 0
    set ahead (git -C $dir rev-list --count $upstream..HEAD)
    if test $ahead -gt 0
        set -l remote (git -C $dir config branch.$branch.remote)
        set -l remote_branch (string replace -r "^$remote/" '' -- $upstream)
        if git -C $dir push --force-with-lease=$remote_branch:$expect --quiet $remote $branch >/dev/null 2>&1
            set pushed 1
        else
            test $stashed -eq 1; and git -C $dir stash pop --quiet >/dev/null 2>&1
            __workspace_sync_line red $name "$branch : push refusé ($ahead commit(s) en local) — le remote a bougé ?"
            return 1
        end
    end

    if test $stashed -eq 1
        if not git -C $dir stash pop --quiet >/dev/null 2>&1
            __workspace_sync_line red $name "$branch : CONFLIT au dépilage du stash — à résoudre (git status)"
            return 1
        end
    end

    set -l done
    test $rebased -eq 1; and set -a done "rebasé sur $upstream"
    test $pushed -eq 1; and set -a done "poussé ($ahead commit(s))"
    test $stashed -eq 1; and set -a done "stash restauré"
    test (count $done) -eq 0; and set done "à jour"
    __workspace_sync_line green $name "$branch : "(string join ", " $done)
    return 0
end

function __workspace_sync_line --argument-names color name message
    set_color $color
    printf "%-38s" $name
    set_color normal
    echo " $message"
end
