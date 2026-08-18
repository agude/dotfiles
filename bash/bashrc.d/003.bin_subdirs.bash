# shellcheck shell=bash
# Add visible subdirectories of ~/bin to PATH without changing glob settings.

if [[ -d "${HOME}/bin" ]]; then
    _bin_subdirs_nullglob=false
    _bin_subdirs_dotglob=false
    shopt -q nullglob && _bin_subdirs_nullglob=true
    shopt -q dotglob && _bin_subdirs_dotglob=true

    shopt -s nullglob
    shopt -u dotglob
    for _bin_subdir in "${HOME}/bin"/*/; do
        _bin_subdir="${_bin_subdir%/}"
        if [[ ":${PATH}:" != *":${_bin_subdir}:"* ]]; then
            PATH="${_bin_subdir}:${PATH}"
        fi
    done

    $_bin_subdirs_nullglob || shopt -u nullglob
    $_bin_subdirs_dotglob && shopt -s dotglob
    unset -v _bin_subdir _bin_subdirs_nullglob _bin_subdirs_dotglob
fi
