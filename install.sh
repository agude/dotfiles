#!/usr/bin/env bash
# shellcheck shell=bash
#
# Dotfiles Installation Script
#
# Phases:
#   1. Helpers     — utility functions (link, ensure_real_dir, etc.)
#   2. Arguments   — parse --profile / --help
#   3. Profile     — load, source XDG, and validate the active profile
#   4. Install     — create symlinks and run setup tasks
#   5. Cleanup     — diff old manifest against new, remove stale links
#   6. Summary     — report what changed

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# ============================================================================
# Phase 1: Helpers
# ============================================================================

# Find the absolute path of the dotfiles directory, so the script can be run
# from anywhere.
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Source the platform detection script to set the PLATFORM variable.
PLATFORM="unknown"
PLATFORM_SCRIPT="${DOTFILES_DIR}/shared/sharedrc.d/000.set_platform.sh"
if [[ -f "${PLATFORM_SCRIPT}" ]]; then
    # shellcheck disable=SC1090
    source "${PLATFORM_SCRIPT}"
fi

# All symlink targets created by link() are recorded here.  After install,
# this array is diffed against the previous manifest to find stale links.
MANAGED_LINKS=()

# Default before helpers that reference it (run() uses $DRY_RUN).
DRY_RUN=false

# Ownership-aware link function.
# - If the source doesn't exist, warn and skip (don't create dangling symlinks).
# - If the target is already a correct symlink, skip silently (idempotent).
# - If the target is a symlink we own (points into DOTFILES_DIR), replace it.
# - If the target is anything else (real file, dir, foreign symlink), back it
#   up with an epoch timestamp before linking.
# Core symlink placement.  All link functions funnel through here.
#   $1 = target path (where the symlink is created)
#   $2 = source path (absolute path the symlink points to)
#   $3 = ownership prefix (symlinks pointing under this prefix are "ours"
#        and safe to replace; anything else gets backed up)
_place_link() {
    local target="$1"
    local source_path="$2"
    local owner_prefix="$3"

    # Validate source exists before doing anything
    if [[ ! -e "$source_path" ]]; then
        echo "  -> Warning: source does not exist, skipping: $source_path" >&2
        return 0
    fi

    # Record after validating the source exists — a missing source must not
    # land in the manifest (it would prevent cleanup of the stale entry).
    MANAGED_LINKS+=("$target")

    # Already correct — skip silently
    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source_path" ]]; then
        return
    fi

    # Something exists that isn't what we want
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "${owner_prefix}/"* ]]; then
            # Our symlink, wrong target — safe to replace
            echo "  -> Updating: $target"
            run rm "$target"
        else
            # Not ours — back up with epoch timestamp, don't destroy
            local backup
            backup="${target}.dotfiles-backup.$(date +%s)"
            echo "  -> Backing up: $target -> ${backup}"
            run mv "$target" "$backup"
        fi
    fi

    echo "  -> Linking: $source_path -> $target"
    run ln -s "$source_path" "$target"
}

# Create a symlink from target to a repo-relative source path.
link() {
    local target="$1"
    local source="$2" # Source is repo-relative; DOTFILES_DIR is prepended below

    # Reject empty source (e.g. unset profile variable → symlink to repo root).
    if [[ -z "$source" ]]; then
        echo "  -> Error: empty source for target: $target" >&2
        return 1
    fi

    _place_link "$target" "${DOTFILES_DIR}/${source}" "${DOTFILES_DIR}"
}

# Create a real directory, removing any existing symlink first.
# This is important when transitioning from "symlink the whole directory"
# to "symlink individual files inside a real directory". Without this guard,
# mkdir -p silently succeeds on symlinks, and subsequent file creation
# ends up in the symlink target (often back in this repo).
ensure_real_dir() {
    local dir="$1"
    if [[ -L "$dir" ]]; then
        echo "  -> Removing symlink to create real directory: $dir"
        run rm "$dir"
    fi
    run mkdir -p "$dir"
}

# Check whether an install group is enabled in the active profile.
# Groups are declared in profiles/default.sh (source of truth) and toggled
# by overlay profiles.
install_group() {
    local varname
    varname="INSTALL_$(echo "$1" | tr '[:lower:]' '[:upper:]')"
    [[ "${!varname}" == "true" ]]
}

# Check whether ANY of a comma-separated list of groups is enabled.
# "*" is unconditional (always returns true).
any_group_enabled() {
    local groups="$1"
    [[ "$groups" == "*" ]] && return 0
    local g
    for g in $(echo "$groups" | tr ',' ' '); do
        # trim whitespace
        g="${g## }"; g="${g%% }"
        [[ -n "$g" ]] && install_group "$g" && return 0
    done
    return 1
}

# Expand only the known set of variables in a string.  This replaces eval,
# which would execute arbitrary code embedded in links.conf or profile vars.
# Add a line here when you introduce a new variable to links.conf.
expand_vars() {
    local s="$1"
    s="${s//\$\{HOME\}/$HOME}"
    s="${s//\$HOME/$HOME}"
    s="${s//\$\{XDG_CONFIG_HOME\}/$XDG_CONFIG_HOME}"
    s="${s//\$\{CLAUDE_SETTINGS_REL\}/$CLAUDE_SETTINGS_REL}"
    s="${s//\$\{CLAUDE_AGENTS_REL\}/$CLAUDE_AGENTS_REL}"
    s="${s//\$\{GEMINI_SETTINGS_REL\}/$GEMINI_SETTINGS_REL}"
    s="${s//\$\{GEMINI_AGENTS_REL\}/$GEMINI_AGENTS_REL}"
    printf '%s' "$s"
}

# Wrap a command so that --dry-run prints instead of executing.
run() {
    if $DRY_RUN; then
        echo "  [dry-run] $*"
    else
        "$@"
    fi
}

# ============================================================================
# Phase 2: Arguments
# ============================================================================

PROFILES_DIR="${DOTFILES_DIR}/profiles"

usage() {
    echo "Usage: install.sh [--profile NAME] [--dry-run] [--show]"
    echo
    echo "Options:"
    echo "  --profile NAME   Set and persist the active profile"
    echo "  --dry-run        Show what would change without modifying anything"
    echo "  --show           Show active profile and enabled groups, then exit"
    echo "  --help           Show this help message"
    echo
    echo "Available profiles:"
    for p in "${PROFILES_DIR}/"*.sh; do
        [[ -f "$p" ]] || continue
        echo "  - $(basename "$p" .sh)"
    done
}

OVERRIDE_PROFILE=""
SHOW_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --dry-run) DRY_RUN=true ;;
        --show) SHOW_ONLY=true ;;
        --profile=*) OVERRIDE_PROFILE="${1#--profile=}" ;;
        --profile)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --profile requires a name (e.g., --profile work)" >&2
                exit 1
            fi
            OVERRIDE_PROFILE="$2"; shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

# ============================================================================
# Phase 3: Load and Validate Profile
# ============================================================================

PROFILE_FILE="${DOTFILES_DIR}/.active-profile"

# --profile flag overrides and persists the active profile.
# With --show, the override is ephemeral (inspect without side effects).
if [[ -n "${OVERRIDE_PROFILE}" ]]; then
    if [[ ! -f "${PROFILES_DIR}/${OVERRIDE_PROFILE}.sh" ]]; then
        echo "Error: Profile '${OVERRIDE_PROFILE}' not found in ${PROFILES_DIR}/" >&2
        exit 1
    fi
    if ! $SHOW_ONLY; then
        if ! $DRY_RUN; then
            echo "${OVERRIDE_PROFILE}" > "${PROFILE_FILE}"
            echo "  -> Saved profile '${OVERRIDE_PROFILE}' to .active-profile"
        else
            echo "  [dry-run] Would save profile '${OVERRIDE_PROFILE}' to .active-profile"
        fi
    fi
    ACTIVE_PROFILE="${OVERRIDE_PROFILE}"
fi

# First-run prompt: if no .active-profile exists and --profile wasn't given.
if [[ -z "${ACTIVE_PROFILE:-}" ]] && [[ ! -f "${PROFILE_FILE}" ]]; then
    echo "No active profile found. Available profiles:"
    echo
    for p in "${PROFILES_DIR}/"*.sh; do
        [[ -f "$p" ]] || continue
        echo "  - $(basename "$p" .sh)"
    done
    echo
    if [[ -t 0 ]]; then
        read -rp "Enter profile name [default]: " chosen_profile
        chosen_profile="${chosen_profile:-default}"
    else
        echo "  -> Non-interactive session detected, using 'default' profile."
        chosen_profile="default"
    fi
    if [[ ! -f "${PROFILES_DIR}/${chosen_profile}.sh" ]]; then
        echo "Error: Profile '${chosen_profile}' not found in ${PROFILES_DIR}/" >&2
        exit 1
    fi
    if ! $DRY_RUN; then
        echo "${chosen_profile}" > "${PROFILE_FILE}"
        echo "  -> Saved profile '${chosen_profile}' to .active-profile"
    else
        echo "  [dry-run] Would save profile '${chosen_profile}' to .active-profile"
    fi
    ACTIVE_PROFILE="${chosen_profile}"
fi

if [[ -z "${ACTIVE_PROFILE:-}" ]]; then
    read -r ACTIVE_PROFILE < "${PROFILE_FILE}"
fi

if [[ -z "${ACTIVE_PROFILE}" ]]; then
    echo "Error: .active-profile is empty. Delete it and re-run, or use --profile NAME." >&2
    exit 1
fi

# Always source default first, then layer the chosen profile on top.
echo "› Active profile: ${ACTIVE_PROFILE} (change with --profile NAME)"
# shellcheck disable=SC1091
source "${PROFILES_DIR}/default.sh"
if [[ "${ACTIVE_PROFILE}" != "default" ]]; then
    PROFILE_OVERLAY="${PROFILES_DIR}/${ACTIVE_PROFILE}.sh"
    if [[ ! -f "${PROFILE_OVERLAY}" ]]; then
        echo "Error: Profile file '${PROFILE_OVERLAY}' does not exist." >&2
        exit 1
    fi
    # shellcheck disable=SC1090
    source "${PROFILE_OVERLAY}"
fi

# Set XDG_CONFIG_HOME if the environment doesn't already provide it.
# We intentionally avoid sourcing 001.xdg_base_directory.sh here — that file
# is designed for interactive shells and has side effects (mkdir for Jupyter,
# Gimp, GnuPG, etc.) that install.sh should not trigger.
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

# Derive the known-groups list once from default.sh (the source of truth).
# Reused by group validation, links.conf validation, and --show.
KNOWN_GROUPS=$(sed -n 's/^INSTALL_\([A-Z_]*\)=.*/\1/p' "${PROFILES_DIR}/default.sh" | tr '[:upper:]' '[:lower:]')

# Validate install-group variables are well-formed.
_known_groups=$KNOWN_GROUPS
_group_errors=0
for _g in $_known_groups; do
    _vn="INSTALL_$(echo "$_g" | tr '[:lower:]' '[:upper:]')"
    case "${!_vn:-}" in
        true|false) ;;
        "")
            echo "Error: ${_vn} not set after sourcing profile '${ACTIVE_PROFILE}'." >&2
            _group_errors=1
            ;;
        *)
            echo "Error: ${_vn}='${!_vn}' — must be 'true' or 'false'." >&2
            _group_errors=1
            ;;
    esac
done
[[ $_group_errors -eq 0 ]] || exit 1
unset _g _vn _known_groups _group_errors

# Validate that every group name used in links.conf is a known group (or "*").
# Catches typos like "shel" that would silently skip entries.
LINKS_FILE="${DOTFILES_DIR}/links.conf"
if [[ -f "$LINKS_FILE" ]]; then
    _known_groups=$KNOWN_GROUPS
    _group_errors=0
    _lineno=0
    while IFS='|' read -r _target _source _groups; do
        _lineno=$((_lineno + 1))
        _target="${_target#"${_target%%[! ]*}"}"
        _groups="${_groups#"${_groups%%[! ]*}"}"; _groups="${_groups%"${_groups##*[! ]}"}"
        [[ -z "$_target" || "$_target" == "#"* ]] && continue
        [[ "$_groups" == "*" ]] && continue
        for _g in $(echo "$_groups" | tr ',' ' '); do
            _g="${_g## }"; _g="${_g%% }"
            [[ -z "$_g" ]] && continue
            _match=false
            for _k in $_known_groups; do
                [[ "$_g" == "$_k" ]] && { _match=true; break; }
            done
            if ! $_match; then
                echo "Error: links.conf:${_lineno}: unknown group '${_g}' (known: ${_known_groups//$'\n'/, })" >&2
                _group_errors=1
            fi
        done
    done < "$LINKS_FILE"
    [[ $_group_errors -eq 0 ]] || exit 1
    unset _target _source _groups _g _k _match _lineno _known_groups _group_errors
fi

# --show: print profile state and exit.
if $SHOW_ONLY; then
    echo
    echo "Profile: ${ACTIVE_PROFILE}"
    echo "Groups:"
    for _g in $KNOWN_GROUPS; do
        if install_group "$_g"; then
            echo "  + ${_g}"
        else
            echo "  - ${_g}  (disabled)"
        fi
    done
    unset _g
    exit 0
fi

# ============================================================================
# Phase 4: Install
# ============================================================================

# --- 4a. Declarative links from links.conf ---

echo "› Processing link map..."
while IFS='|' read -r target source groups; do
    # Trim leading and trailing whitespace from each field.
    target="${target#"${target%%[! ]*}"}"; target="${target%"${target##*[! ]}"}"
    source="${source#"${source%%[! ]*}"}"; source="${source%"${source##*[! ]}"}"
    groups="${groups#"${groups%%[! ]*}"}"; groups="${groups%"${groups##*[! ]}"}"
    # Skip comments and blank lines.
    [[ -z "$target" || "$target" == "#"* ]] && continue
    # Skip if none of the listed groups are enabled.
    any_group_enabled "$groups" || continue
    # Expand known variables (HOME, XDG_CONFIG_HOME, profile path vars).
    target="$(expand_vars "$target")"
    source="$(expand_vars "$source")"
    # Ensure parent directory exists as a real directory (not a symlink).
    # Guard: skip if the parent already exists as a real directory (avoids
    # calling ensure_real_dir on $HOME, which would destroy a symlinked home).
    _parent="$(dirname "$target")"
    [[ -d "$_parent" && ! -L "$_parent" ]] || ensure_real_dir "$_parent"
    link "$target" "$source"
done < "$LINKS_FILE"

# --- 4b. Procedural installs (glob loops, runtime setup) ---

if install_group scripts; then
    echo "› Setting up executable scripts in ~/bin..."
    ensure_real_dir "${HOME}/bin"
    for full_path in "$DOTFILES_DIR/bin/"*; do
        script_file=${full_path##*/}
        script_name=${script_file%%.*}
        link "${HOME}/bin/${script_name}" "bin/${script_file}"
    done
fi

if install_group llm; then
    echo "› Setting up LLM tool configurations..."
    # Claude custom commands (individual symlinks so external commands coexist).
    COMMANDS_DIR="${HOME}/.claude/commands"
    ensure_real_dir "$COMMANDS_DIR"
    for cmd_file in "$DOTFILES_DIR/llm/claude/commands/"*.md; do
        [ -f "$cmd_file" ] || continue
        cmd_name=$(basename "$cmd_file")
        [[ "$cmd_name" == "README.md" ]] && continue
        link "${COMMANDS_DIR}/${cmd_name}" "llm/claude/commands/${cmd_name}"
    done

    # Shared Agent Skills (individual symlinks so external skills coexist).
    SKILLS_DIR="${HOME}/.claude/skills"
    ensure_real_dir "$SKILLS_DIR"
    for skill_dir in "$DOTFILES_DIR/llm/skills/"*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        link "${SKILLS_DIR}/${skill_name}" "llm/skills/${skill_name}"
    done

    # Coat tree — modular hook dispatcher for Claude Code.
    # Binary goes on PATH; hook scripts go into XDG config dir.
    COAT_TREE_CONFIG="${XDG_CONFIG_HOME}/coat-tree/hooks.d"
    ensure_real_dir "${HOME}/.local/bin"
    link "${HOME}/.local/bin/coat-tree" "llm/coat-tree/dispatch.sh"
    for event_dir in "$DOTFILES_DIR/llm/coat-tree/hooks.d/"*/; do
        [ -d "$event_dir" ] || continue
        event_name=$(basename "$event_dir")
        ensure_real_dir "${COAT_TREE_CONFIG}/${event_name}"
        for hook_script in "$event_dir"*; do
            [ -f "$hook_script" ] || continue
            hook_name=$(basename "$hook_script")
            link "${COAT_TREE_CONFIG}/${event_name}/${hook_name}" "llm/coat-tree/hooks.d/${event_name}/${hook_name}"
        done
    done
    # Johnny Decimal scripts into ~/bin (needs scripts group too).
    if install_group scripts; then
        ensure_real_dir "${HOME}/bin/johnny-decimal"
        for script in "$DOTFILES_DIR/llm/skills/johnny-decimal/scripts/"*.sh; do
            script_basename=$(basename "$script")
            [[ "$script_basename" == "jd-lib.sh" ]] && continue
            script_name="${script_basename%.sh}"
            link "${HOME}/bin/johnny-decimal/${script_name}" "llm/skills/johnny-decimal/scripts/${script_basename}"
        done
    fi
fi

if install_group vim; then
    if ! $DRY_RUN; then
        if command -v vim &> /dev/null; then
            echo "› Installing Vim plugins..."
            vim +PlugInstall +qall
        fi
        if command -v nvim &> /dev/null; then
            echo "› Installing Neovim plugins..."
            nvim +PlugInstall +qall
        fi
    fi
fi

if install_group gui; then
    echo "› Configuring XDG User Directories..."
    if command -v xdg-user-dirs-update &> /dev/null; then
        run xdg-user-dirs-update --set DESKTOP "${HOME}/Desktop"
        run xdg-user-dirs-update --set DOCUMENTS "${HOME}/Documents"
        run xdg-user-dirs-update --set DOWNLOAD "${HOME}/Downloads"
        run xdg-user-dirs-update --set MUSIC "${HOME}/Music"
        run xdg-user-dirs-update --set PICTURES "${HOME}/Pictures"
        run xdg-user-dirs-update --set VIDEOS "${HOME}/Videos"
        run mkdir -p "${HOME}/Desktop" "${HOME}/Documents" "${HOME}/Downloads" \
                     "${HOME}/Music" "${HOME}/Pictures" "${HOME}/Videos" \
                     "${HOME}/Templates" "${HOME}/Public"
    else
        echo "  -> Skipping: xdg-user-dirs-update command not found."
    fi
fi

if install_group cleanup; then
    echo "› Setting up automated cleanup tasks..."
    if [[ "${PLATFORM}" == "linux" ]]; then
        if command -v systemctl &> /dev/null; then
            echo "  -> Setting up systemd user service for emptying Downloads..."
            SYSTEMD_USER_DIR="${XDG_CONFIG_HOME}/systemd/user"
            SERVICE_FILE="${SYSTEMD_USER_DIR}/empty-downloads.service"
            ensure_real_dir "${SYSTEMD_USER_DIR}"
            echo "  -> Copying systemd service file (required by systemctl)..."
            run cp "${DOTFILES_DIR}/config/systemd/user/empty-downloads.service" "${SERVICE_FILE}"
            if ! $DRY_RUN; then
                systemctl --user daemon-reload || true
                systemctl --user enable --now empty-downloads.service >/dev/null 2>&1 || echo "  -> Warning: Failed to enable systemd service. This may be expected in a non-interactive session."
            fi
        else
            echo "  -> Skipping systemd setup: systemctl command not found."
        fi
    elif [[ "${PLATFORM}" == "mac" ]]; then
        if command -v launchctl &> /dev/null; then
            echo "  -> Setting up launchd agent for emptying Downloads..."
            LAUNCHD_DIR="${HOME}/Library/LaunchAgents"
            PLIST_FILE="${LAUNCHD_DIR}/com.user.empty-downloads.plist"
            ensure_real_dir "${LAUNCHD_DIR}"
            link "${PLIST_FILE}" "config/launchd/com.user.empty-downloads.plist"
            if ! $DRY_RUN; then
                launchctl unload "${PLIST_FILE}" 2>/dev/null || true
                launchctl load "${PLIST_FILE}" >/dev/null 2>&1 || echo "  -> Warning: Failed to load launchd agent. This may be expected in a non-interactive session."
            fi
        fi
    fi
fi

# ============================================================================
# Phase 5: Cleanup (manifest diff)
# ============================================================================

MANIFEST_FILE="${DOTFILES_DIR}/.link-manifest"
REMOVED_LINKS=()

# Read the previous run's manifest (if any).
OLD_MANIFEST=()
if [[ -f "$MANIFEST_FILE" ]]; then
    while IFS= read -r _line; do
        OLD_MANIFEST+=("$_line")
    done < "$MANIFEST_FILE"
    unset _line
fi

# Diff: anything in the old manifest but not in MANAGED_LINKS is stale.
if [[ ${#OLD_MANIFEST[@]} -gt 0 ]]; then
    for old in "${OLD_MANIFEST[@]}"; do
        _found=false
        if [[ ${#MANAGED_LINKS[@]} -gt 0 ]]; then
            for new in "${MANAGED_LINKS[@]}"; do
                [[ "$old" == "$new" ]] && { _found=true; break; }
            done
        fi
        if ! $_found; then
            # Safety: only remove if it's still a symlink pointing into our repo
            if [[ -L "$old" ]] && [[ "$(readlink "$old")" == "${DOTFILES_DIR}/"* ]]; then
                if [[ ${#REMOVED_LINKS[@]} -eq 0 ]]; then
                    echo "› Cleaning up stale symlinks..."
                fi
                REMOVED_LINKS+=("$old")
                run rm "$old"
            fi
        fi
    done
    unset _found
fi

# Write the new manifest for the next run (skip in dry-run mode).
if ! $DRY_RUN; then
    if [[ ${#MANAGED_LINKS[@]} -gt 0 ]]; then
        printf '%s\n' "${MANAGED_LINKS[@]}" > "$MANIFEST_FILE"
    else
        : > "$MANIFEST_FILE"
    fi
fi

# ============================================================================
# Phase 6: Summary
# ============================================================================

if [[ ${#REMOVED_LINKS[@]} -gt 0 ]]; then
    echo
    if $DRY_RUN; then
        echo "› Cleanup summary (would remove):"
    else
        echo "› Cleanup summary:"
    fi
    for removed in "${REMOVED_LINKS[@]}"; do
        echo "  ${removed}"
    done
fi

echo
if $DRY_RUN; then
    echo "✓ Dry run complete — no changes were made."
else
    echo "✓ Dotfiles installation complete!"
    echo "Note: Some changes may require a new shell session or a full logout/login to take effect."
fi
