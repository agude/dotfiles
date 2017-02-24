# Check for anaconda and miniconda installs in $HOME/bin
for CONDA in anaconda miniconda; do
    LOCATION="${HOME}"/bin/${CONDA}/bin
    if [[ -d $LOCATION ]]; then
        export PATH="$LOCATION:$PATH"
    fi
done

# Remove the helper variables
unset -v LOCATION
