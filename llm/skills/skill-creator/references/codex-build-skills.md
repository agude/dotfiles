# Codex Skill Extensions

Codex uses the shared `SKILL.md` format and supports optional Codex metadata in
`agents/openai.yaml`. Keep the skill instructions and frontmatter portable;
put Codex-only UI, invocation policy, and tool dependencies in that file.

## Skill layout

```text
skill-name/
├── SKILL.md
├── agents/openai.yaml       # Optional Codex metadata
├── scripts/                 # Optional deterministic helpers
├── references/              # Optional on-demand documentation
└── assets/                  # Optional supporting files
```

Codex discovers skills from repository `.agents/skills` directories, the user
`~/.agents/skills` directory, and configured system directories. It follows
symlinked skill directories, so a shared repository can be installed without
copying its contents.

## Optional metadata

```yaml
interface:
  display_name: "User-facing name"
  short_description: "User-facing description"

policy:
  allow_implicit_invocation: false
```

`allow_implicit_invocation: false` disables automatic triggering while keeping
explicit `$skill-name` invocation available. Most skills do not need this file.

## Authoring rules

- Use only portable frontmatter in `SKILL.md`; Codex does not require a
  Claude-specific environment variable for bundled files.
- Reference bundled files with paths relative to the skill directory.
- Keep scripts deterministic, self-contained, and tested.
- Invoke bundled scripts through their interpreter when executable permissions
  are not guaranteed, for example `bash scripts/check.sh` or
  `python3 scripts/check.py`.
- Test explicit `$skill-name` invocation, implicit triggering where enabled,
  and realistic inputs in a fresh session.

See the [Codex skill documentation](https://developers.openai.com/codex/skills/)
for the current product-specific details.
