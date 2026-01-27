# shellcheck shell=bash
# XDG Base Directory and User Directory Specifications
#
# This script sets variables according to the XDG specifications to clean up the
# home directory. It is idempotent and safe to source multiple times.
#
# Source (Base Dirs): https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
# Source (User Dirs): https://specifications.freedesktop.org/xdg-user-dirs/latest/

# Temporarily disable 'exit on unset variable' to safely check for existence.
# Save current state to restore at end of file.
_xdg_old_set_u=""; [[ $- == *u* ]] && _xdg_old_set_u="-u"
set +u

# XDG Base Directories
#
# Set core XDG variables for application data, config, and cache if not already defined.
[[ -z $XDG_DATA_HOME ]] && export XDG_DATA_HOME="${HOME}/.local/share"
[[ -z $XDG_CONFIG_HOME ]] && export XDG_CONFIG_HOME="${HOME}/.config"
[[ -z $XDG_STATE_HOME ]] && export XDG_STATE_HOME="${HOME}/.local/state"

if [[ "${PLATFORM}" == "mac" ]]; then
    [[ -z $XDG_CACHE_HOME ]] && export XDG_CACHE_HOME="${HOME}/Library/Caches/org.freedesktop"
    mkdir -p "${XDG_CACHE_HOME}"
else
    [[ -z $XDG_CACHE_HOME ]] && export XDG_CACHE_HOME="${HOME}/.cache"
fi

# Set XDG search path variables if not already defined.
[[ -z $XDG_DATA_DIRS ]] && export XDG_DATA_DIRS="/usr/local/share/:/usr/share/"
[[ -z $XDG_CONFIG_DIRS ]] && export XDG_CONFIG_DIRS="/etc/xdg"


# XDG User Directories
#
# Defines standard paths for user-facing directories like Desktop and Documents.
[[ -z $XDG_DESKTOP_DIR ]]   && export XDG_DESKTOP_DIR="${HOME}/Desktop"
[[ -z $XDG_DOCUMENTS_DIR ]] && export XDG_DOCUMENTS_DIR="${HOME}/Documents"
[[ -z $XDG_DOWNLOAD_DIR ]]  && export XDG_DOWNLOAD_DIR="${HOME}/Downloads"
[[ -z $XDG_MUSIC_DIR ]]     && export XDG_MUSIC_DIR="${HOME}/Music"
[[ -z $XDG_PICTURES_DIR ]]  && export XDG_PICTURES_DIR="${HOME}/Pictures"
[[ -z $XDG_VIDEOS_DIR ]]    && export XDG_VIDEOS_DIR="${HOME}/Videos"

# Optional directories can be enabled by creating them and uncommenting below.
# [[ -z $XDG_TEMPLATES_DIR ]]   && export XDG_TEMPLATES_DIR="${HOME}/Templates"
# [[ -z $XDG_PUBLICSHARE_DIR ]] && export XDG_PUBLICSHARE_DIR="${HOME}/Public"

# No suggested default is given for XDG_RUNTIME_DIR, so we do not set it.
# This is typically managed by the system's login manager (e.g., systemd-logind).
# [[ -z $XDG_RUNTIME_DIR ]] && export XDG_RUNTIME_DIR=""

# Program-Specific XDG Overrides
#
# Set environment variables for specific applications to make them follow the
# XDG Base Directory Specification.

# Readline
export INPUTRC="${XDG_CONFIG_HOME}/readline/inputrc"

# Screen
export SCREENRC="${XDG_CONFIG_HOME}/screen/screenrc"

# Jupyter/ipython
export IPYTHONDIR="${XDG_CONFIG_HOME}/jupyter"
export JUPYTER_CONFIG_DIR="${XDG_CONFIG_HOME}/jupyter"
mkdir -p "${IPYTHONDIR}" "${JUPYTER_CONFIG_DIR}"

# libice (X11)
if [[ "${PLATFORM}" != "mac" && "${PLATFORM}" != "wsl" ]]; then
    export ICEAUTHORITY="${XDG_CACHE_HOME}/X11/iceauthority"
    mkdir -p "${ICEAUTHORITY}"
fi

# Gimp
export GIMP2_DIRECTORY="${XDG_CONFIG_HOME}/gimp"
mkdir -p "${GIMP2_DIRECTORY}"

# GnuPG
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"
mkdir -p "${GNUPGHOME}"

# aspell
export ASPELL_CONF="per-conf ${XDG_CONFIG_HOME}/aspell/aspell.conf; personal ${XDG_CONFIG_HOME}/aspell/en.pws; repl ${XDG_CONFIG_HOME}/aspell/en.prepl"

# Rust Cargo
export CARGO_HOME="${XDG_DATA_HOME}"/cargo

# Docker
export DOCKER_CONFIG="${XDG_CONFIG_HOME}"/docker

# GTK 2
export GTK2_RC_FILES="${XDG_CONFIG_HOME}"/gtk-2.0/gtkrc

# mypy
export MYPY_CACHE_DIR="${XDG_CACHE_HOME}"/mypy

# pidgin
if [[ -x $(command -v pidgin) ]]; then
    pidgindata="$XDG_DATA_HOME"/purple
    mkdir -p "${pidgindata}"

    ln -sf "${HOME}/.purple" "${pidgindata}"

    unset -v pidgindata
fi

# ripgrep
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}"/ripgrep/config

# Ansible
# See https://github.com/ansible/ansible/pull/76114

# Ruff (Linter and Formatter)
export RUFF_CONFIG_DIR="${XDG_CONFIG_HOME}/ruff"
export RUFF_CACHE_DIR="${XDG_CACHE_HOME}/ruff"

# Restore 'set -u' if it was enabled before this file was sourced.
[[ -n "$_xdg_old_set_u" ]] && set -u
unset -v _xdg_old_set_u
