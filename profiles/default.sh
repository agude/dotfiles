# shellcheck shell=bash
# Default profile — personal desktop with everything enabled.
# Other profiles source default.sh first (via install.sh), then override
# specific values.
#
# Profiles control which files install.sh links. They do not affect runtime
# behavior — shell configs detect available tools at startup.

# --- Install Groups (source of truth) ---
# This file is the single source of truth for which groups exist and their
# defaults.  install.sh derives its validation list from these INSTALL_*
# declarations.  Overlay profiles (server.sh, work.sh) override individual
# values.
#
# Groups are used in two ways in install.sh:
#   1. links.conf:      declarative mapping of target → source → groups.
#      Each row is processed by the engine loop; add a row to link a new file.
#   2. Inline blocks:  `if install_group <name>; then ... fi` for procedural
#      tasks (glob loops, plugin install, service management).
#
# To add a new group: add INSTALL_<NAME>=true here, then reference the group
# name in links.conf rows or inline blocks in install.sh.
INSTALL_SHELL=true
INSTALL_VIM=true
INSTALL_GIT=true
INSTALL_SCRIPTS=true
INSTALL_GUI=true
INSTALL_LLM=true
INSTALL_CLEANUP=true

# --- File-path variables (repo-relative paths) ---
# These are relative to DOTFILES_DIR. link() prepends the full path.
# Override these in machine-specific profiles to swap config variants.
CLAUDE_SETTINGS_REL="llm/claude/settings.json"
CLAUDE_AGENTS_REL="llm/AGENTS.md"
GEMINI_SETTINGS_REL="llm/gemini/settings.json"
GEMINI_AGENTS_REL="llm/AGENTS.md"
