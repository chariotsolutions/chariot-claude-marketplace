# Why Spec-First Testing

Lessons from real projects where AI-generated unit tests went through multiple rounds of review before reaching acceptable quality. These problems motivated the spec-first approach.

## What went wrong

### 1. Testing the easy code, not the important code

The first pass gravitated toward the simplest things to test — null checks, range checks, one-liner methods. These are low-effort to write but also low-probability to break. Meanwhile the real risk areas went untested:

| Tested (low value) | Missed (high value) |
|---|---|
| 5 null/range checks on a validation method | `create()` — default values, foreign key mapping, audit fields |
| 9 tests for a one-liner role check | `toDto()` — null-safe handling of optional relationships |
| Testing framework behavior (`isEnabled`) | `changePassword` — security-critical password verification |
| Testing stdlib behavior (SHA-1 determinism) | `create` — duplicate detection, password encoding |

The pattern: test count was optimized over bug-catching value.

### 2. Losing existing coverage during rewrites

When a test file was restructured (e.g., reorganized into nested groups), existing tests were silently dropped. Three tests disappeared during one rewrite:

- A null-vs-zero distinction on a numeric field (different code path)
- A null-vs-blank distinction on a string field (different branch)
- A boundary condition documenting `> 24` not `>= 24`

These were only caught on a third review pass. The root cause: there was no durable specification to check the rewrite against. The only record of what tests should exist was in the previous version of the file, which was overwritten.

### 3. Not asking "what bug does this test catch?"

Several tests were written without a clear answer to this question:

- Testing that a hash function is deterministic — it is by definition
- Testing `assertNotNull` on a value already proven valid by another test
- Testing stdlib/framework behavior, not application code

If you can't name a plausible code change that would make the test fail, the test isn't earning its place.

## Root cause

Tests were written directly from source code — read the function, write a test for each branch. This bottom-up approach produces tests that mirror code structure rather than requirements. It also means there's no durable artifact that survives a rewrite. When a test file is regenerated, the only "spec" is in the previous file contents (now overwritten) or in conversation context (which gets compacted and can lose details).

## The fix: spec-first testing

### The process

1. **Write the spec** — enumerate what needs testing and WHY (what breaks if this is wrong)
2. **Write tests from the spec** — each spec row maps to a test
3. **On any test change** — check the spec first, update if needed, verify nothing is dropped
4. **On any source change** — update the spec for new/changed behavior, then update tests to match

### Why markdown tables

We evaluated Gherkin/Cucumber and Gauge before settling on plain markdown tables.

**Gherkin/Cucumber** — verbose without payoff for unit tests. The "Given" is usually just "service with mocked dependencies" (same for every test), the "When" is a single method call. No "Risk if broken" field. Requires glue code. Step reuse doesn't materialize for unit tests where setups vary too much. Well-suited for E2E specs, less so for unit tests.

**Gauge** — markdown-native and less rigid, but still requires a full runtime framework, glue code, and has the same lack of a "Risk if broken" field.

**Plain markdown tables** — scannable, diffable, zero framework overhead, "Risk if broken" is a first-class column. The spec is a planning and verification artifact, not an executable one — keeping it non-executable means no glue code to maintain.
