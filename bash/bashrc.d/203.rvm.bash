# shellcheck shell=bash
# ------------------------------------------------------------------------------
# RVM (Ruby Version Manager) Setup
#
# This sources the RVM script, which adds its functions and shims to the PATH.
# It checks for the existence of the script before sourcing to avoid errors.
# ------------------------------------------------------------------------------

# RVM's standard installation paths.
RVM_PATHS=(
    "$HOME/.rvm/scripts/rvm"
    "/usr/local/rvm/scripts/rvm"
)

# Find the first valid RVM script and source it.
for rvm_script in "${RVM_PATHS[@]}"; do
    if [[ -s "$rvm_script" ]]; then
        # shellcheck disable=SC1090
        source "$rvm_script"
        break
    fi
done

unset -v rvm_script RVM_PATHS
