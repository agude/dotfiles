#!/usr/bin/env bash
# Claude Code statusLine command.
# Starts with the same segments as ~/.zshrc.d/107.prompt.zsh (user:cwd + git),
# then extends with Claude-specific session data: model and context-window
# size, context usage bar, and 5h / 7d rate-limit bars with resets.
# Rendered dimmed by Claude Code under the prompt.

input=$(cat)

# --- One jq pass: every field we use, empty when absent ---------------------
# Delimiter is ASCII Unit Separator (\x1f), not TAB: bash `read` treats TAB as
# IFS whitespace and collapses consecutive empty fields, which would shift
# optional fields (rate limits) into the wrong variables.
IFS=$'\x1f' read -r cwd model_id ctx_size ctx_pct \
    r5_pct r5_reset r7_pct r7_reset < <(
    jq -r '[
        (.workspace.current_dir // .cwd // ""),
        (.model.id // ""),
        (.context_window.context_window_size // ""),
        (.context_window.used_percentage // ""),
        (.rate_limits.five_hour.used_percentage // ""),
        (.rate_limits.five_hour.resets_at // ""),
        (.rate_limits.seven_day.used_percentage // ""),
        (.rate_limits.seven_day.resets_at // "")
    ] | map(tostring) | join("\u001f")' <<<"$input"
)

# --- Helpers ----------------------------------------------------------------

# bar_color INT -> ANSI code: green <40, yellow <70, red otherwise
bar_color() {
    local p="$1"
    if   (( p < 40 )); then printf 32
    elif (( p < 70 )); then printf 33
    else                    printf 31
    fi
}

# render_bar INT_PCT CELLS -> fractional-block bar of CELLS width
# Uses 8ths for sub-cell precision: █ ▉ ▊ ▋ ▌ ▍ ▎ ▏
render_bar() {
    local pct=$1 cells=$2
    local eighths blocks partial filled empty i
    eighths=$((pct * cells * 8 / 100))
    (( eighths > cells * 8 )) && eighths=$((cells * 8))
    (( eighths < 0 )) && eighths=0
    blocks=$((eighths / 8))
    partial=$((eighths % 8))
    for ((i = 0; i < blocks; i++)); do printf '█'; done
    case "$partial" in
        1) printf '▏' ;; 2) printf '▎' ;; 3) printf '▍' ;; 4) printf '▌' ;;
        5) printf '▋' ;; 6) printf '▊' ;; 7) printf '▉' ;;
    esac
    filled=$((blocks + (partial > 0 ? 1 : 0)))
    empty=$((cells - filled))
    for ((i = 0; i < empty; i++)); do printf ' '; done
}

# human_countdown EPOCH -> "now" | "Nm" | "NhMm" | "Nd" | "NdNh"
human_countdown() {
    local target=$1 now diff days hours
    now=$(date +%s)
    diff=$((target - now))
    if   (( diff < 60 ));    then printf 'now'
    elif (( diff < 3600 ));  then printf '%dm' $((diff / 60))
    elif (( diff < 86400 )); then printf '%dh%dm' $((diff / 3600)) $(((diff % 3600) / 60))
    else
        days=$((diff / 86400))
        hours=$(((diff % 86400) / 3600))
        if (( hours > 0 )); then
            printf '%dd%dh' "$days" "$hours"
        else
            printf '%dd' "$days"
        fi
    fi
}

# rate_segment PCT RESET LABEL -> " [bar LABEL N% ⟳countdown]" in threshold color
rate_segment() {
    local pct=$1 reset=$2 label=$3
    [[ -z "$pct" || -z "$reset" ]] && return
    local int color bar countdown
    int=$(printf '%.0f' "$pct" 2>/dev/null)
    [[ -z "$int" ]] && return
    color=$(bar_color "$int")
    bar=$(render_bar "$int" 5)
    countdown=$(human_countdown "$reset")
    printf ' \033[%sm[%s %s %s%% ⟳%s]\033[0m' \
        "$color" "$bar" "$label" "$int" "$countdown"
}

# --- 1. cwd — collapse $HOME to ~ -------------------------------------------
home="$HOME"
if [[ "$cwd" == "$home"* ]]; then
    display_dir="~${cwd#"$home"}"
else
    display_dir="$cwd"
fi

# --- 2. Git segment (red): branch, optional " *" unstaged, " +" staged ------
git_segment=""
if (cd "$cwd" && git rev-parse --git-dir --no-optional-locks >/dev/null 2>&1); then
    branch=$(cd "$cwd" && { git symbolic-ref --short HEAD 2>/dev/null \
             || git rev-parse --short HEAD 2>/dev/null; })
    if [[ -n "$branch" ]]; then
        unstaged=""
        staged=""
        if ! (cd "$cwd" && git diff --no-ext-diff --quiet 2>/dev/null); then
            unstaged=" *"
        fi
        if ! (cd "$cwd" && git diff --no-ext-diff --cached --quiet 2>/dev/null); then
            staged=" +"
        fi
        git_segment=$(printf ' \033[31m(%s%s%s)\033[0m' "$branch" "$unstaged" "$staged")
    fi
fi

# --- 3. Model + context-window size (cyan), e.g. " opus-4-7·1M" -------------
model_segment=""
if [[ -n "$model_id" ]]; then
    model_short="${model_id#claude-}"
    size_display=""
    if [[ -n "$ctx_size" ]]; then
        if (( ctx_size >= 1000000 )); then
            size_display="·$((ctx_size / 1000000))M"
        else
            size_display="·$((ctx_size / 1000))k"
        fi
    fi
    model_segment=$(printf ' \033[36m%s%s\033[0m' "$model_short" "$size_display")
fi

# --- 4. Context bar + percent (threshold color) -----------------------------
ctx_segment=""
if [[ -n "$ctx_pct" ]]; then
    ctx_int=$(printf '%.0f' "$ctx_pct" 2>/dev/null)
    if [[ -n "$ctx_int" ]]; then
        ctx_color=$(bar_color "$ctx_int")
        ctx_bar=$(render_bar "$ctx_int" 5)
        ctx_segment=$(printf ' \033[%sm[%s ctx %s%%]\033[0m' \
            "$ctx_color" "$ctx_bar" "$ctx_int")
    fi
fi

# --- 5. Rate-limit bars (Pro/Max only; silent otherwise) --------------------
r5_segment=$(rate_segment "$r5_pct" "$r5_reset" "5h")
r7_segment=$(rate_segment "$r7_pct" "$r7_reset" "7d")

# --- Assemble: green user, blue cwd, then appended segments -----------------
printf '\033[32m%s\033[0m:\033[34m%s\033[0m%s%s%s%s%s' \
    "$(whoami)" \
    "$display_dir" \
    "$git_segment" \
    "$model_segment" \
    "$ctx_segment" \
    "$r5_segment" \
    "$r7_segment"
