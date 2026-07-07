# shellcheck shell=zsh
# ------------------------------------------------------------------------------
# macOS-Specific Environment Configuration
#
# This file should only run on macOS. It sets environment variables
# for development tools commonly installed via Homebrew.
# ------------------------------------------------------------------------------
if [[ "$PLATFORM" == "mac" ]]; then

    # Set environment variables for Homebrew-installed packages if brew is available.
    # Single brew --prefix call instead of three (~50-200ms each).
    if type brew &>/dev/null; then
        _brew_prefix="$(brew --prefix)"
        export OPENBLAS="${_brew_prefix}/opt/openblas"
        export HDF5_DIR="${_brew_prefix}/opt/hdf5"
        export LLVM_CONFIG="${_brew_prefix}/opt/llvm/bin/llvm-config"
        unset -v _brew_prefix
    fi

    # Append macOS-specific compiler flags.
    export CFLAGS="-falign-functions=8 ${CFLAGS}"

fi
