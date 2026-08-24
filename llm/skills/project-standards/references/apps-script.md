# Google Apps Script Repositories

Use this reference for JavaScript that runs in a Google Sheets, Docs, Forms,
or standalone Apps Script project.

## Layout

```text
src/
  appsscript.json
  main.js
  main_test.js
fixtures/
  README.md
AGENTS.md
README.md
LICENSE
.gitignore
```

Keep Apps Script source in `src/`, including tests that must execute in the
bound project. Keep only anonymized input and output examples in `fixtures/`.
Never commit Form exports, generated receipts, script IDs, OAuth tokens, or
customer data.

Use `src/appsscript.json` to pin the V8 runtime and exception logging. The
Apps Script editor calls source files `.gs`; local `.js` filenames remain
JavaScript and work with `clasp`.

## Validation

Write pure parsing and rendering functions where possible, then expose one
test entry point such as `runReceiptCoreTests()`. Run it in the bound Apps
Script editor before deploying a change. Document the exact entry point in
both `README.md` and `AGENTS.md`.

Do not add a local test runner, `justfile`, pre-commit hook, or GitHub Actions
workflow until it executes a real check. A recipe that only prints manual
instructions is not a check.

## Optional clasp Workflow

Adopt `clasp` only after the bound project is established. It makes the local
repository the source of truth by pulling and pushing Apps Script source.

- Keep `.clasp.json` and `.clasprc.json` ignored and untracked.
- Pull and compare the bound project before the first push.
- Do not use `clasp push --force` until the local and bound copies agree.
- Add `just test`, `just push`, and `just check` only when their clasp
  commands are configured and executable.

## Annual Form Schemas

When Forms change each year, isolate field names, item-column boundaries,
prices, and output labels in a year-specific configuration. Convert each raw
row into a stable order object before generating a receipt. Add an anonymized
fixture and tests for every new schema.
