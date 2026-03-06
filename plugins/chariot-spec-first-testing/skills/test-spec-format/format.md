# Test Spec Format

Test specifications use structured markdown tables — one file per test class/module, committed to the repo alongside the tests.

## File location

Specs live in a `test-specs/` directory near the test files:

| Language | Spec location | Example |
|----------|--------------|---------|
| Java | `src/test/resources/test-specs/` | `FeedbackServiceTest.md` |
| TypeScript | `src/__test-specs__/` or `test-specs/` | `feedback-service.test.md` |
| Python | `tests/test-specs/` | `test_feedback_service.md` |

The spec filename matches the test filename with the extension replaced by `.md`. This convention is enforced by the plugin's hooks.

---

## Unit Test Specs

One file per test class/module, one section per function under test.

### Header

```markdown
# <TestFileName> Spec

Source: `<path to source file>`
Test: `<path to test file>`
```

### Methods not tested

An optional section documenting functions that are intentionally skipped, with rationale:

```markdown
## Methods not tested (and why)

| Method | Reason |
|---|---|
| `getById()` | Pass-through to repository. No branching logic. |
| `delete()` | One-liner with no conditional paths. |
```

### Method sections

One H2 section per function under test:

```markdown
## methodName(args)

| ID | Scenario | Assertion | Risk if broken |
|----|----------|-----------|----------------|
| C1 | Normal create, no status | Saved entity has status='OPEN' | Default status missing, downstream filtering breaks |
| C2 | Duplicate email | Throws conflict error | Silent data overwrite, two users share an identity |
```

---

## Integration Test Specs

One file per test class/module, one section per logical flow (not per function).

### Header

```markdown
# <TestFileName> Spec

App: `<application name>`
Test: `<path to test file>`
```

### Flow sections

One H2 section per scenario group:

```markdown
## Authentication

| ID | Scenario | Assertion | Risk if broken |
|----|----------|-----------|----------------|
| AUTH-1 | POST /api/auth/register with email+password | 200 with token and userId | Registration broken — no users can onboard |
| AUTH-2 | POST /api/auth/login with valid credentials | 200 with fresh token | Users cannot log in |

## Data Isolation

| ID | Scenario | Assertion | Risk if broken |
|----|----------|-----------|----------------|
| ISO-1 | User A creates item, User B lists items | User B sees empty list | Data leaks between users |
```

---

## Column definitions

| Column | Purpose | Example |
|--------|---------|---------|
| **ID** | Stable identifier (prefix + number). Survives test restructuring. | `V1`, `AUTH-3`, `ISO-1` |
| **Scenario** | The specific input, condition, or state being tested. Concrete enough to write a test from. | `POST /api/auth/register with email+password` |
| **Assertion** | What the test checks — the expected outcome. | `200 with token, refreshToken, userId` |
| **Risk if broken** | Real-world consequence if this behavior is wrong. Must be a plausible business or technical impact, not a restatement of the assertion. | `Tenant data leaks — users see other tenants' data` |

The **Risk if broken** column is the key field. It forces articulation of why each test exists. If you can't fill it in with a plausible consequence, the test probably isn't worth writing.

## ID conventions

### Unit tests

Use a short prefix tied to the function: `V` for validation, `C` for create, `D` for toDto, `P` for password, `S` for search, etc. Number sequentially within each section: `V1`, `V2`, `V3`.

### Integration tests

Use flow-oriented prefixes that describe the domain area. Extend with project-specific prefixes as needed:

| Prefix | Domain |
|--------|--------|
| `AUTH` | Authentication (register, login, refresh) |
| `SEC` | Security (unauthorized access, authorization) |
| `ISO` | Data isolation enforcement |
| `OPS` | Operational endpoints (health, metrics) |

### General rules

- IDs are stable — if a test is removed, don't renumber
- If a test is added, use the next available number

## Mapping to test code

Each spec row maps to a test function. The spec ID should be traceable from the test's display name or description:

| Spec row | Test |
|----------|------|
| `AUTH-1 \| POST /api/auth/register ...` | `"Register returns tokens"` |
| `V1 \| personId=null` | `"Null personId throws"` |

The mapping doesn't need to be mechanical — no need to embed the ID in the test name. The connection should be obvious from the scenario description.

## Verification checklist

When writing or modifying tests:

- [ ] Every spec row has a corresponding test
- [ ] Every test traces back to a spec row
- [ ] Every spec row has a non-trivial "Risk if broken" entry
- [ ] If a test file was rewritten, diff spec IDs against old and new tests to verify nothing was dropped
- [ ] No test is redundant with another test (same bug caught twice = one test is wasted)
