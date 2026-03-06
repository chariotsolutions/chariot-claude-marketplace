---
name: test-spec-format
description: Test spec format reference and spec-first testing workflow. Use when writing or modifying tests, when a hook blocks a test edit for missing spec, or when creating a new test spec file.
user-invocable: true
---

Follow the spec-first testing workflow when writing or modifying tests.

## Workflow

1. **Open or create the spec file** in `test-specs/` (see format reference below for naming and location conventions)
2. **Add or update spec rows** for the behavior you're about to test. Each row needs: ID, Scenario, Assertion, and Risk if broken. If you can't articulate a plausible risk, the test isn't worth writing.
3. **Only then write the test code** — each spec row maps to a test
4. **On test changes** — check the spec first. If rewriting a test file, diff spec IDs against old and new tests to verify nothing was dropped.
5. **On source changes** — update the spec for new/changed behavior, then update tests to match.

This order is enforced by hooks: editing a test file without first updating its spec will be blocked.

## Format reference

See [format.md](format.md) for the full spec format: file locations by language, column definitions, ID conventions, unit vs integration spec structure, and verification checklist.

## Rationale

See [rationale.md](rationale.md) for why this approach exists — real problems encountered with AI-generated tests and the alternatives considered.
