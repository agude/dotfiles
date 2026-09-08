# Pi Harness Migration Plan

## Goal

Make Pi the primary coding harness while preserving the useful parts of the
current multi-harness setup: shared instructions, shared skills, knowledge
capture, repository conventions, and safe installation of mutable local state.

Pi is a good fit when the goal is to own the workflow. It is not a drop-in
replacement for Claude Code. Pi keeps the core small and moves plan mode,
subagents, MCP, to-dos, background work, and permission prompts into
extensions or external tools. See the [Pi design principles](https://pi.dev/docs/latest/usage).

## Constraints

- Keep `install.sh` compatible with Bash 3.2.
- Keep `~/.pi/agent` as Pi's canonical runtime directory.
- Do not export `PI_CODING_AGENT_DIR` globally; launches that skip shell setup
  must still use the canonical state directory.
- Preserve Pi-owned mutable files: `auth.json`, `sessions/`, `trust.json`,
  installed package state, and `models-store.json`.
- Keep shared skills harness-neutral. Add Pi-specific behavior only in a
  clearly marked adapter section or in Pi extensions.
- Do not treat project trust as a sandbox. Pi and its extensions run with the
  permissions of the launching user. See the [Pi security model](https://pi.dev/docs/latest/security).

## Target layout

```text
llm/pi/
├── settings.json          # Copy-once mutable baseline
├── extensions/
│   ├── knowledge.ts
│   └── safety.ts
├── agents/                # Optional subagent role definitions
├── prompts/               # Explicit slash-command workflows
├── themes/                # Optional Pi themes
├── packages.manifest      # Pinned third-party packages
└── tests/                 # Extension and integration tests
```

The installer should link repository-owned resources into `~/.pi/agent/` while
leaving Pi-owned mutable state in place. Do not replace the whole agent
directory during installation.

## Phase 1: Establish safety

### Deliverables

- Add a global Pi `tool_call` safety extension.
- Protect writes and edits to:
  - `.env` and other secret files.
  - Private keys and credential directories.
  - `.git/`.
  - Package or dependency directories where accidental writes are unsafe.
- Inspect reads as well as writes when the path contains sensitive material.
- Confirm or block destructive shell commands.
- Block dangerous commands by default in print, JSON, RPC, and child-agent
  modes where no interactive confirmation is available.
- Canonicalize paths before applying path rules.
- Reuse the policy intent of the existing Claude command guard, but implement
  the enforcement at Pi's tool boundary.

The official [permission gate example](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/examples/extensions/permission-gate.ts)
and [protected-paths example](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/examples/extensions/protected-paths.ts)
provide starting points. Their simple pattern checks are not a complete
security boundary.

### Acceptance criteria

- Interactive dangerous commands require explicit confirmation.
- Non-interactive dangerous commands are blocked.
- Protected reads, writes, and edits are blocked consistently.
- Symlink, traversal, quoting, and nested-Pi cases have tests.
- The extension reports a clear reason for every block.

For stronger isolation, evaluate the official [containerization patterns](https://pi.dev/docs/latest/containerization):
Gondolin, Docker, or OpenShell. A tool-routing extension does not sandbox
other custom extensions that continue to run on the host.

## Phase 2: Add installation and diagnostics

### `pi-doctor`

Create a diagnostic script that checks:

- Pi is installed and reports its version.
- The current package scope is `@earendil-works/pi-coding-agent`.
- Node and npm are available through the expected Pi toolchain.
- `~/.pi/agent` exists with the expected permissions.
- Required symlinks point into the dotfiles repository.
- Pi settings are valid JSON.
- Extensions can load in an isolated test invocation.
- Required credentials or models are available without printing secrets.
- External packages are installed at the expected versions.
- No resource is loaded through both a local path and a package entry.

### Package manifest

Track third-party Pi packages separately from repository-owned extensions.
Use `pi install`, `pi list`, and `pi update --extensions`. Pin npm versions or
Git tags/commits where reproducibility matters. Pi supports npm and Git package
sources and filtered resource lists; see the [Pi package documentation](https://pi.dev/docs/latest/packages).

Do not load the same extension through both a static local path and a Git
package. Pi treats those as independent resources and can register commands,
skills, and tools twice. See the [codingfragments package guidance](https://github.com/codingfragments/pi-extensions).

### Acceptance criteria

- A fresh machine can install Pi resources with one repository command.
- A second run is idempotent.
- Existing auth, sessions, trust decisions, and Pi-managed settings survive.
- `--dry-run` reports changes before making them.
- `pi-doctor` identifies missing, stale, duplicate, or conflicting resources.

## Phase 3: Separate workflow primitives

Use each Pi mechanism for one purpose:

| Mechanism | Use it for |
|---|---|
| `AGENTS.md` | Stable project rules, commands, safety constraints, and preferences |
| Skill | Reusable methodology and helper scripts loaded on demand |
| Prompt template | Explicit slash command with arguments, such as `/review <scope>` |
| Extension | Events, tool interception, custom tools, UI, or persisted state |
| Script | Deterministic work that should not require an LLM |
| Agent definition | A focused role with its own prompt, model, and tool restrictions |

Add these prompt templates first:

- `/plan` — read-only exploration and an actionable implementation plan.
- `/review` — inspect the current diff for correctness, security, tests, and
  unnecessary complexity.
- `/finish` — run the relevant checks, inspect the diff, and summarize evidence.
- `/release-audit` — review release notes, versioning, tests, and working-tree
  state.

Pi prompt templates are Markdown files with optional frontmatter and positional
  arguments. See the [prompt template documentation](https://pi.dev/docs/latest/prompt-templates).

## Phase 4: Add focused delegation

Start with the following workflow:

```text
scout → worker → reviewer
```

Use:

- `scout` for broad repository exploration.
- `worker` for implementation.
- `reviewer` for independent review with read-only tools.
- `oracle` for a second opinion on a risky design decision.

Do not delegate every small edit. Use delegation for broad searches,
independent review, parallel audits, and work that benefits from a separate
context window.

Evaluate one subagent package at a time:

- [nicobailon/pi-subagents](https://github.com/nicobailon/pi-subagents) for a
  relatively direct delegation workflow.
- [tintinweb/pi-subagents](https://github.com/tintinweb/pi-subagents) for more
  elaborate orchestration, background execution, and fleet management.

Keep role-specific tools narrow. A reviewer should not receive write access
unless the workflow explicitly requires it.

## Phase 5: Add verification and observability

Evaluate [pi-lens](https://github.com/apmantza/pi-lens) or a smaller local
equivalent for language-server diagnostics, linting, formatting, and type
checking.

Recommended verification behavior:

- Run the formatter or linter on changed files after edits.
- Run type checking at the end of a turn when practical.
- Run the full test suite at explicit checkpoints.
- Require fresh command output before claiming completion.

Add optional session features only after the core workflow is stable:

- Session naming.
- Desktop or terminal notifications.
- Context and token usage display.
- Git status in the footer.
- Git checkpoints before risky branches or forks.

The official [git checkpoint example](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/examples/extensions/git-checkpoint.ts)
can be evaluated before implementing a local version.

The existing `llm/pi/extensions/knowledge.ts` should remain the single Pi
knowledge-capture extension. Keep its session-start, message, context-injection,
and shutdown behavior aligned with the existing Claude and OpenCode semantics.

## Phase 6: Build automation interfaces

Use Pi's supported interfaces instead of scraping terminal output:

```bash
pi -p "Summarize this repository"
pi --mode json "Run a read-only audit"
pi --mode rpc
```

- Use print mode for one-shot scripts.
- Use JSON mode for structured event streams and lightweight integrations.
- Use RPC for a long-lived subprocess controlled by another program.
- Use the SDK when building a Node application that embeds Pi.

See the [JSON event stream documentation](https://pi.dev/docs/latest/json),
[RPC documentation](https://pi.dev/docs/latest/rpc), and [SDK documentation](https://pi.dev/docs/latest/sdk).

Do not build new tooling around undocumented session-file assumptions. Pi
stores sessions as JSONL trees, but RPC and SDK APIs are the appropriate
interfaces for active sessions. ([Session format](https://pi.dev/docs/latest/session-format))

Candidate scripts:

- `pi-doctor` — validate the installation.
- `pi-update` — update Pi and manifest-tracked packages.
- `pi-run` — standardize one-shot print/JSON invocations.
- `pi-session-report` — summarize local session usage and costs.
- `pi-test-extension` — run an extension in an isolated config directory.

## Provider and model policy

Pi supports OAuth and API-key providers, including ChatGPT Plus/Pro (Codex),
Claude Pro/Max, GitHub Copilot, OpenRouter, and other providers. See the
[provider documentation](https://pi.dev/docs/latest/providers).

The current settings template pins an OpenRouter model. Keep that as a personal
default only if the model is intentionally part of the portable setup. If the
template must work across machines and accounts, move the model choice into a
local profile or post-install override. A public Pi setup explicitly leaves
personal provider and model selections out of its shared example configuration;
see [abhinand5/pi-setup](https://github.com/abhinand5/pi-setup).

## Testing strategy

### Extension unit tests

- Mock the `ExtensionAPI` and verify event registration.
- Test block/allow decisions independently from the TUI.
- Test session lifecycle cleanup and reload behavior.
- Test duplicate event delivery and retry behavior for capture extensions.

### Integration tests

Run extensions in a throwaway configuration:

```bash
PI_CODING_AGENT_DIR=/tmp/pi-test-config \
  pi --no-extensions -e ./llm/pi/extensions/safety.ts --no-session
```

Use `/reload` during local development. Pi's extension examples and tests are
the reference for the supported lifecycle and tool APIs.

### Safety matrix

Test at least:

- Interactive and non-interactive operation.
- `bash`, `read`, `write`, and `edit` tool calls.
- Relative, absolute, symlinked, and traversal paths.
- Shell pipelines, substitutions, quoting, and command wrappers.
- Session fork, resume, reload, and shutdown.
- Subagent processes and restricted tool lists.
- Missing knowledge-base scripts and failed flushes.

## Migration sequence

1. Run Pi and the current harness side by side.
2. Complete the safety extension and `pi-doctor`.
3. Add the package manifest and idempotent installer flow.
4. Port `/plan`, `/review`, and `/finish` workflows.
5. Add scout, worker, and reviewer roles.
6. Run representative tasks through both harnesses and compare:
   - Correctness.
   - Tool behavior.
   - Context usage.
   - Cost.
   - Recovery after interruption.
   - Knowledge capture.
7. Add LSP, status, notifications, and memory features only where the test
   tasks demonstrate a measurable benefit.
8. Make Pi the default launcher after the acceptance criteria pass.

## Research notes

Public Pi setups consistently converge on a few patterns:

- `~/.pi/agent` is treated as the live runtime.
- Extensions, skills, prompts, agents, and themes are versioned separately.
- External packages are installed through a manifest or pinned package list.
- Safety extensions are added because Pi has no built-in permission system.
- Prompt templates handle fixed workflows; skills handle reusable methodology.
- Subagent setups use narrow roles such as scout, worker, planner, reviewer, and
  oracle.
- Copy/link/sync workflows are more suitable for a dotfiles repository than
  replacing the entire Pi agent directory.

Useful references:

- [Pi documentation](https://pi.dev/docs/latest)
- [Pi package catalog](https://pi.dev/packages)
- [Pi extensions documentation](https://pi.dev/docs/latest/extensions)
- [pcaro/pcaropi](https://github.com/pcaro/pcaropi)
- [danchamorro/pi-agent-toolkit](https://github.com/danchamorro/pi-agent-toolkit)
- [codingfragments/pi-extensions](https://github.com/codingfragments/pi-extensions)
- [s1lver091/pi-agent-config](https://github.com/s1lver091/pi-agent-config)
- [mogassama/pi-agent-config](https://github.com/mogassama/pi-agent-config)
