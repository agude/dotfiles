# shellcheck shell=zsh
# ------------------------------------------------------------------------------
# macOS-Specific Environment Configuration
#
# This file should only run on macOS. It sets environment variables
# for development tools commonly installed via Homebrew.
# ------------------------------------------------------------------------------
if [[ "$PLATFORM" == "mac" ]]; then

    # Set environment variables for Homebrew-installed packages if brew is available.
    # This helps compilers and build tools find these libraries.
    if type brew &>/dev/null; then
        export OPENBLAS=$(brew --prefix openblas)
        export HDF5_DIR=$(brew --prefix hdf5)
        export LLVM_CONFIG=$(brew --prefix llvm)/bin/llvm-config
    fi

    # Append macOS-specific compiler flags.
    export CFLAGS="-falign-functions=8 ${CFLAGS}"

fi
