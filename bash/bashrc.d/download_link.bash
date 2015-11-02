#!/usr/bin/env bash
# Set up a download folder for the user in /tmp and link to it from ~/Downloads
DOWNLOAD_DIR="/tmp/${USER}/downloads"
mkdir -p ${DOWNLOAD_DIR}
unset -v DOWNLOAD_DIR
