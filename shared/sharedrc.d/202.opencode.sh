# shellcheck shell=bash
#
# OpenCode: local LLM coding assistant
#
# Adds ~/.opencode/bin to PATH and provides the `oc` alias.

if [[ -d "${HOME}/.opencode/bin" ]]; then
    PATH="${HOME}/.opencode/bin:${PATH}"
fi

# Quick launch with default local model
if command -v opencode &> /dev/null; then
    alias oc='opencode -m ollama/qwen3.5:9b-32k'
fi
