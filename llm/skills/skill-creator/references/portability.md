# Portability checks

Read this when a skill must work in more than one host, or when installation,
invocation, permissions, or tools affect the workflow. Checked 2026-10-14.

## Shared contract

The [Agent Skills specification](https://agentskills.io/specification) defines
files and metadata. It does not standardize installation paths, slash commands,
environment variables, shell execution, tool APIs, or permission enforcement.
The shared entrypoint should describe the work without depending on those
mechanisms. A format-valid skill still needs runtime checks in each target host.

## What to verify

| Area | Portable approach | Verify in the target host |
| --- | --- | --- |
| Discovery | Deliver a directory containing SKILL.md and required resources. | Supported locations, scan depth, symlinks, precedence, reload behavior, and whether skills are enabled. |
| Selection | Put capability and applicability in the description. | Whether automatic selection is available and whether the skill actually loads. |
| Explicit invocation | Keep the body usable as instructions. | Command syntax, visibility controls, and argument handling. |
| Resource paths | Link relative to the skill root; resolve scripts from the loaded skill's location. | How the host communicates that location; do not assume the target project's working directory is the skill root. Goose's load_skill opens supporting files with O_NOFOLLOW and cannot read symlinks inside a skill directory. |
| Scripts | Declare runtime, dependencies, input/output contract, and side effects. | Shell access, sandbox, installed packages, network, and operating system. |
| Tools | Describe required capabilities; isolate a concrete tool binding when necessary. | Exact tool names, schemas, credentials, and availability. |
| Permissions | Preserve user authorization and host policy. | Whether tool hints pre-approve, restrict, prompt, or are ignored. |
| Extensions | Add only when requested or required by the chosen host. | Supported fields, sidecar files, preprocessing, and behavior when unsupported. |
| Evaluation | Use fresh contexts, controlled inputs, observable criteria, and traces. | A supported execution and observation mechanism; no universal evaluation API is specified. |

`allowed-tools` belongs to the specification but is experimental. Its syntax
and effect vary. Do not describe it as a portable sandbox, assume it grants
missing capabilities, or add it merely to suppress prompts.
The spec uses a space-separated string; Claude Code also accepts YAML lists.
The creator warns on other types rather than rejecting a host-supported form.

Single-line descriptions are the safest shared choice. Folded and literal
block strings are valid YAML, but Claude Code has had block-string parsing
bugs across versions. Angle brackets in descriptions and names containing
`claude` or `anthropic` also face restrictions in some hosts or upload paths;
these are compatibility warnings rather than shared format rules.

Unknown fields are not guaranteed to be harmless. Some hosts ignore them;
others validate, interpret, or preprocess them. Host-specific argument
substitution and embedded command execution can change even literal examples.
Avoid those constructs in shared instructions. Use ordinary fenced commands
for examples and consult current host documentation before using extensions.

Do not choose a model, force delegation, set invocation policy, or bundle
host UI metadata as part of generic scaffolding. Preserve intentional existing
extensions when updating a skill unless the request includes removing them.
When an extension is essential, state which host needs it and keep the shared
workflow independently understandable. Provide a separate adapter or package
variant when the host requires incompatible entrypoint metadata.

## Official documentation

Use these as starting points when the user names a target; do not read every
host manual for an ordinary portable skill.

- [GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
- [VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [Gemini CLI](https://geminicli.com/docs/cli/using-agent-skills/)
- [Cursor](https://cursor.com/docs/skills)
- [OpenCode](https://opencode.ai/docs/skills/)
- [Goose](https://goose-docs.ai/docs/guides/context-engineering/using-skills)
- [Pi](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md)
- [Claude Code](https://code.claude.com/docs/en/skills)
- [Codex and ChatGPT](https://learn.chatgpt.com/docs/build-skills)

Several hosts document `.agents/skills/`, but discovery remains a host choice.
In this dotfiles repository, the installer links shared skills into the
configured hosts' native directories. Keep those installation decisions in
the installer rather than embedding them in every skill.
