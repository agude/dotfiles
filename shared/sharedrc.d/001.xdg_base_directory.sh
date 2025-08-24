# Set up the XDG Base Directory Specification, but only if they don't exist
# We un-set `set -u` here because the whole point is the variables might be
# unset at this point
set +u

[[ -z $XDG_DATA_HOME ]] && export XDG_DATA_HOME="${HOME}/.local/share"

[[ -z $XDG_CONFIG_HOME ]] && export XDG_CONFIG_HOME="${HOME}/.config"
if [[ "${PLATFORM}" == "mac" ]]; then
    [[ -z $XDG_CACHE_HOME ]] && export XDG_CACHE_HOME="${HOME}/Library/Caches/org.freedesktop"
    mkdir -p "${XDG_CACHE_HOME}"
else
    [[ -z $XDG_CACHE_HOME ]] && export XDG_CACHE_HOME="${HOME}/.cache"
fi

[[ -z $XDG_STATE_HOME ]] && export XDG_STATE_HOME="${HOME}/.local/state"

[[ -z $XDG_DATA_DIRS ]] && export XDG_DATA_DIRS="/usr/local/share/:/usr/share/"

[[ -z $XDG_CONFIG_DIRS ]] && export XDG_CONFIG_DIRS="/etc/xdg"

# No suggested default is given, so do not set RUNTIME
#[[ -z $XDG_RUNTIME_DIR ]] && export XDG_RUNTIME_DIR=""

# Set up variables for the programs that let us move their configuration files

## Readline
export INPUTRC="${XDG_CONFIG_HOME}/readline/inputrc"

## Screen
export SCREENRC="${XDG_CONFIG_HOME}/screen/screenrc"

## Jupyter/ipython
export IPYTHONDIR="${XDG_CONFIG_HOME}/jupyter"
export JUPYTER_CONFIG_DIR="${XDG_CONFIG_HOME}/jupyter"
mkdir -p "${IPYTHONDIR}" "${JUPYTER_CONFIG_DIR}"

## libice
if [[ "${PLATFORM}" != "mac" && "${PLATFORM}" != "wsl" ]]; then
    export ICEAUTHORITY="${XDG_CACHE_HOME}/X11/iceauthority"
    mkdir -p "${ICEAUTHORITY}"
fi

## Gimp
export GIMP2_DIRECTORY="${XDG_CONFIG_HOME}/gimp"
mkdir -p "${GIMP2_DIRECTORY}"

## GnuPG
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"
mkdir -p "${GNUPGHOME}"

## aspell
export ASPELL_CONF="per-conf ${XDG_CONFIG_HOME}/aspell/aspell.conf; personal ${XDG_CONFIG_HOME}/aspell/en.pws; repl ${XDG_CONFIG_HOME}/aspell/en.prepl"

## Rust Cargo
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

    ln -sf "${HOME}/".purple ${pidgindata}

    unset -v pidgindata
fi

# ripgrep
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}"/ripgrep/config

# Ansible
# See https://github.com/ansible/ansible/pull/76114


# Ruff (Linter and Formatter)
# Override the default config and cache paths to ensure they follow our
# custom XDG Base Directory Specification on all platforms.
export RUFF_CONFIG_DIR="${XDG_CONFIG_HOME}/ruff"
export RUFF_CACHE_DIR="${XDG_CACHE_HOME}/ruff"
