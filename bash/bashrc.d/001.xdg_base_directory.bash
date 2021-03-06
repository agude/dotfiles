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
