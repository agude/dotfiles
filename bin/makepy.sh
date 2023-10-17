#!/bin/sh -e

if [ -n "$1" ]; then
  pyenv_version="$1"
else
  pyenv_version=$(pyenv version-name | sed 's/:.*//')
fi
venv_name="pyenv-temp-${pyenv_version}-${RANDOM}"

pyenv virtualenv "${pyenv_version}" "${venv_name}"

echo
echo "Entering a new shell session with virtualenv '${venv_name}' (${pyenv_version})."
echo "It will be removed when exiting (ctrl+d or 'exit')."

export PYENV_VERSION="${venv_name}"
$SHELL

echo "Destroying temporary virtualenv '${venv_name}'."
pyenv uninstall -f "${venv_name}"
