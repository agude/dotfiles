# Set the cargo path
RUST_BIN_PATH="${HOME}/.cargo/bin"

if [[ -d ${RUST_BIN_PATH} ]]; then
    export PATH="${RUST_BIN_PATH}:${PATH}"
fi

unset -v RUST_BIN_PATH
