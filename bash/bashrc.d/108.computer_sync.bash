# Sync Computers
case $HOSTNAME in
    # From Einstein
    (einstein)
        REMOTE="dirac"
    ;;

    # From Dirac
    (dirac)
        REMOTE="einstein"
    ;;

    # Anything else
    * )
        REMOTE=""
    ;;
esac

if [[ -n "$REMOTE" ]]; then
    # Pidgin
    srpull='\n\nRemote Pull\n\n'
    srpush='\n\nRemote Push\n\n'
    slpull='\n\nLocal Pull\n\n'
    slpush='\n\nLocal Push\n\n'
    # Local
    alias pidgin-pull='printf %b ${srpull} && ${HOME}/bin/sync --pull --delete-after --remote ${REMOTE} --directory ${HOME}/.purple/logs/'
    alias pidgin-push='printf %b ${srpush} && ${HOME}/bin/sync --push --delete-after --remote ${REMOTE} --directory ${HOME}/.purple/logs/'
    # Local windows
    alias pidgin-winpull='printf %b ${slpull} && rsync -rDvhh --modify-window=1 --itemize-changes --append-verify /mnt/win/c/Users/Alexander\ Gude/AppData/Roaming/.purple/logs/ ${HOME}/.purple/logs/'
    alias pidgin-winpush='printf %b ${slpush} && rsync -rDvhh --modify-window=1 --itemize-changes --append-verify ${HOME}/.purple/logs/ /mnt/win/c/Users/Alexander\ Gude/AppData/Roaming/.purple/logs/'
    # Combined
    alias pidgin-sync='pidgin-winpull && pidgin-pull && pidgin-push && pidgin-winpush'

    # Documents
    # All - Email
    alias docs-push='${HOME}/bin/sync --push --delete-after --remote ${REMOTE} --exclude email/ google_docs/ --directory ${HOME}/Documents/'
    alias docs-pull='${HOME}/bin/sync --pull --delete-after --remote ${REMOTE} --exclude email/ google_docs/ --directory ${HOME}/Documents/'
    # Email
    alias email-push='${HOME}/bin/sync --push --delete-after --remote ${REMOTE} --directory ${HOME}/Documents/email/'
    alias email-pull='${HOME}/bin/sync --pull --delete-after --remote ${REMOTE} --directory ${HOME}/Documents/email/'

    # Projects
    alias projects-push='${HOME}/bin/sync --push --delete-after --remote ${REMOTE} --exclude .mypy_cache/ --directory ${HOME}/Projects/'
    alias projects-pull='${HOME}/bin/sync --pull --delete-after --remote ${REMOTE} --exclude .mypy_cache/ --directory ${HOME}/Projects/'

    # Music
    # TODO: Fix me
    #alias music-push='${HOME}/bin/sync --push --remote ${REMOTE} --directory ${HOME}/.config/banshee-1/ ${HOME}/Music/'
    #alias music-pull='${HOME}/bin/sync --pull --remote ${REMOTE} --directory ${HOME}/.config/banshee-1/ ${HOME}/Music/'
    alias music-push=':'  # the do nothing operator
    alias music-pull=':'

    # Dotfiles
    alias dot-push='${HOME}/bin/sync --push --delete-after --remote ${REMOTE} --exclude tmp/ .mypy_cache/ --directory ${HOME}/.dotfiles/'
    alias dot-pull='${HOME}/bin/sync --pull --delete-after --remote ${REMOTE} --exclude tmp/ .mypy_cache/ --directory ${HOME}/.dotfiles/'

    # $HOME/bin
    alias bin-push='${HOME}/bin/sync --push --delete-after --remote ${REMOTE} --directory ${HOME}/bin/'
    alias bin-pull='${HOME}/bin/sync --pull --delete-after --remote ${REMOTE} --directory ${HOME}/bin/'

    # Systemfiles
    alias system-push='${HOME}/bin/sync --push --delete-after --remote ${REMOTE} --directory ${HOME}/.systemfiles/'
    alias system-pull='${HOME}/bin/sync --pull --delete-after --remote ${REMOTE} --directory ${HOME}/.systemfiles/'

    # Games
    alias game-push='${HOME}/bin/sync --push --delete-after --remote ${REMOTE} --directory ${HOME}/Games/'
    alias game-pull='${HOME}/bin/sync --pull --delete-after --remote ${REMOTE} --directory ${HOME}/Games/'
fi

# Sync Computers
case $HOSTNAME in
    # From Einstein
    (einstein)
        alias push-to-dirac='dot-push && bin-push && system-push && projects-push && docs-push && email-push && music-push && game-push'
        alias pull-from-dirac='dot-pull && bin-pull && system-pull && projects-pull && docs-pull && music-pull && game-pull'
    ;;

    # From Dirac
    (dirac)
        alias push-to-einstein='dot-push && bin-push && system-push && projects-push && docs-push && music-push'
        alias pull-from-einstein='dot-pull && bin-pull && system-pull && projects-pull && docs-pull && email-pull && music-pull'
    ;;
esac

# Remove the helper variables
unset -v REMOTE
