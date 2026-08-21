# shellcheck shell=bash
#
# OpenCode: local LLM coding assistant
#
# Adds ~/.opencode/bin to PATH and provides the `oc` alias.
#
# Knowledge base capture is handled by llm/opencode/plugin/knowledge.ts, which
# defaults to on; run `KNOWLEDGE_OBSERVE=0 opencode` to opt out.

if [[ -d "${HOME}/.opencode/bin" ]] && [[ ":${PATH}:" != *":${HOME}/.opencode/bin:"* ]]; then
    PATH="${HOME}/.opencode/bin:${PATH}"
fi

# Quick launch with default local model
if command -v opencode &> /dev/null; then
    alias oc='opencode -m ollama/qwen3.5:9b-32k'
fi
