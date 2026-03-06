---
name: playwright-e2e
description: Scaffold a Playwright E2E test suite for a full-stack web app. Use when the user wants to add end-to-end tests, set up Playwright, or automate browser testing for a project.
argument-hint: [optional notes about the project]
---

Scaffold a Playwright-based E2E test suite for this project's web application.

## Reference

Read [guide.md](guide.md) before doing anything else. It contains templates, patterns, and lessons learned from prior implementations.

## Steps

1. **Read the frontend source code.** Understand routes, component labels, heading text, button names, form field labels, error messages, and how auth state is stored (localStorage, cookies, etc.). Do not guess — wrong locators are the #1 source of test failures.

2. **Read the backend API.** Understand auth endpoints, domain CRUD endpoints, health check URL, and how auth tokens/sessions are structured and passed.

3. **Plan test scenarios.** Based on what you learned in steps 1-2, propose a test plan to the user organized by feature area. Use the "Typical test categories" section in the guide as a starting checklist — include only categories that apply to this app. Present the plan and wait for user approval before writing code.

4. **Scaffold** — Create `e2e/` as a sibling to the frontend directory. Create `package.json`, `tsconfig.json`, `playwright.config.ts`, `.gitignore` using the guide's templates, adapted to this project's actual ports, commands, and health endpoints.

5. **Install** — Run `npm install` and `npx playwright install chromium`. Verify with `npx playwright test --list`.

6. **Utils** — Create `constants.ts` and `api.ts`, adapted to this app's actual auth mechanism, storage keys, and API response shapes.

7. **Fixtures** — Create `global-setup.ts` and `auth.ts`. The number and type of auth personas (tenants, roles, or just "logged in vs not") comes from what the app actually needs — see the guide's fixtures section for the pattern.

8. **Page objects** — One per page/region. Use exact labels and roles from the actual frontend components read in step 1.

9. **Test specs** — One file at a time. Write, run, fix, then move to the next. Start with auth tests to validate the fixture system works.

10. **Full run** — `npx playwright test`. All tests must pass before the task is complete.

## Additional context

$ARGUMENTS
