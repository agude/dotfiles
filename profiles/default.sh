# shellcheck shell=bash
# Default profile — personal desktop with everything enabled.
# Other profiles source default.sh first (via install.sh), then override
# specific values.
#
# Profiles control which files install.sh links. They do not affect runtime
# behavior — shell configs detect available tools at startup.

# --- Install Groups ---
# Set to "true" to install, anything else to skip.
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
