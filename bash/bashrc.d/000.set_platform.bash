# Check the operating system
#
# PLATFORM is set instead of using OSTYPE in latter statements because Windows
# Subsystem for Linux (WSL) does not set a unqiue value and so must be checked
# in a different way.
#
# WSL must be first, because it reports the same OSTYPE as real Linux.
if grep -qE "(Microsoft|WSL)" /proc/version &> /dev/null ; then
    export PLATFORM="wsl";
elif [[ "${OSTYPE}" == "linux-gnu" ]]; then
    export PLATFORM="linux";
elif [[ "${OSTYPE}" == "darwin"* ]]; then
    # Mac OSX
    export PLATFORM="mac";
elif [[ "${OSTYPE}" == "win32" ]]; then
    # I'm not sure this can happen.
    export PLATFORM="win32";
else
    # Unknown
    export PLATFORM="";
fi

