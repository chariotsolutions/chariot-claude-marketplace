---
name: playwright-e2e
description: Scaffold a Playwright E2E test suite for a full-stack web app. Use when the user wants to add end-to-end tests, set up Playwright, or automate browser testing for a project.
argument-hint: [optional notes about the project]
---

Scaffold a Playwright-based E2E test suite for this project's web application.

## Reference

Read [guide.md](guide.md) before doing anything else. It contains templates, patterns, and lessons learned from prior implementations.

## Steps

Follow section 8 (Implementation sequence) of the guide exactly:

1. **Read the frontend source code first.** Understand routes, component labels, heading text, button names, form field labels, localStorage keys, API response shapes, and error messages. Do not guess — wrong locators are the #1 source of test failures.

2. **Read the backend API.** Understand auth endpoints (register, login, refresh), domain CRUD endpoints, health check URL, and how auth tokens are structured and passed.

3. **Scaffold** — Create `e2e/` as a sibling to the frontend directory. Create `package.json`, `tsconfig.json`, `playwright.config.ts`, `.gitignore` using the guide's templates, adapted to this project's actual ports, commands, and health endpoints.

4. **Install** — Run `npm install` and `npx playwright install chromium`. Verify with `npx playwright test --list`.

5. **Utils** — Create `constants.ts` (match this app's actual localStorage keys and auth response shape) and `api.ts` (one helper per API endpoint needed for setup/seeding).

6. **Fixtures** — Create `global-setup.ts` (register test users via API, inject tokens, save storage state) and `auth.ts` (custom fixtures for each auth persona + unauthenticated).

7. **Page objects** — One per page/region. Use exact labels and roles from the actual frontend components read in step 1.

8. **Test specs** — One file at a time. Write, run, fix, then move to the next. Start with `auth.spec.ts`.

9. **Full run** — `npx playwright test`. All tests must pass before the task is complete.

## Additional context

$ARGUMENTS
