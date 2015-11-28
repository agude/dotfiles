# Set up the XDG Base Directory Specification, but only if they don't exist
[[ -z $XDG_DATA_HOME ]] && export XDG_DATA_HOME="${HOME}/.local/share"
[[ -z $XDG_CONFIG_HOME ]] && export XDG_CONFIG_HOME="${HOME}/.config"
[[ -z $XDG_DATA_DIRS ]] && export XDG_DATA_DIRS="/usr/local/share/:/usr/share/"
[[ -z $XDG_CONFIG_DIRS ]] && export XDG_CONFIG_DIRS="/etc/xdg"
[[ -z $XDG_CACHE_HOME ]] && export XDG_CACHE_HOME="${HOME}/.cache"
# No suggested default is given, so do not set RUNTIME
#[[ -z $XDG_RUNTIME_DIR ]] && export XDG_RUNTIME_DIR=""

# Set up variables for the programs that let us move their configuration files

## Readline
INPUTRC=${XDG_CONFIG_HOME}/readline/inputrc

## Jupyter/ipython
export IPYTHONDIR="${XDG_CONFIG_HOME}"/jupyter
export JUPYTER_CONFIG_DIR="${XDG_CONFIG_HOME}"/jupyter
mkdir -p ${IPYTHONDIR} ${JUPYTER_CONFIG_DIR}

## libice
export ICEAUTHORITY="${XDG_RUNTIME_DIR}"/X11/iceauthority
mkdir -p $(dirname ${ICEAUTHORITY})
