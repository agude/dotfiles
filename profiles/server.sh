# shellcheck shell=bash disable=SC2034
# Server profile — headless Raspberry Pi, no GUI, no scheduled cleanup.
# The llm group stays on, so the knowledge base sync units are deployed.

INSTALL_GUI=false
INSTALL_CLEANUP=false
