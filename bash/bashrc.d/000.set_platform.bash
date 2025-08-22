# ------------------------------------------------------------------------------
# OS Platform Detection
#
# Sets a single, reliable PLATFORM variable for use in other scripts.
# We check for WSL first, as it identifies as Linux but requires special handling.
# ------------------------------------------------------------------------------

# Check for Windows Subsystem for Linux (WSL)
# The $WSL_DISTRO_NAME env var and WSLInterop file are reliable indicators.
# As a fallback, we check the kernel release info in /proc/version.
if [[ -n "$WSL_DISTRO_NAME" || -f /proc/sys/fs/binfmt_misc/WSLInterop ]] || grep -qE "(Microsoft|WSL)" /proc/version &> /dev/null; then
    export PLATFORM="wsl"

# Check for macOS (OS X)
# The 'darwin' string is the key indicator for all macOS versions.
elif [[ "$OSTYPE" == "darwin"* ]]; then
    export PLATFORM="mac"

# Check for standard Linux
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    export PLATFORM="linux"

# Check for other common Unix-like environments on Windows
elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
    export PLATFORM="windows"

# As a final fallback, use the 'uname' command, which is more portable than $OSTYPE.
# We lowercase the output for consistency.
else
    platform_name=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
    if [[ -n "$platform_name" ]]; then
        export PLATFORM="$platform_name"
    else
        export PLATFORM="unknown"
    fi
fi

# Clean up temporary variable
unset platform_name
