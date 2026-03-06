# Playwright E2E Test Suite — Setup Guide

How to scaffold a Playwright-based E2E test framework for a full-stack web
application. Derived from two production implementations (jellico-e2e, feedback-app).

This document is both a reference for humans and step-by-step instructions
an agent can follow to create an E2E suite for a new project.

---

## 1. Placement and directory structure

The E2E suite lives as a **sibling** to the frontend, not inside it. E2E tests
exercise the full stack (frontend + backend + database), so they belong to
neither.

```
project-root/
  backend/           # or src/, or wherever the server lives
  frontend/          # Vite/Next/CRA app
  e2e/               # <-- here, sibling to frontend
    package.json
    tsconfig.json
    playwright.config.ts
    .gitignore
    utils/
      constants.ts
      api.ts
    fixtures/
      global-setup.ts
      auth.ts
    pages/
      login.page.ts
      *.page.ts
    tests/
      auth.spec.ts
      *.spec.ts
    playwright/.auth/  # gitignored, storage state files
```

## 2. Scaffolding files

### package.json

Minimal dependencies. Playwright bundles its own test runner.

```json
{
  "name": "<project>-e2e",
  "private": true,
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed",
    "test:ui": "playwright test --ui"
  },
  "devDependencies": {
    "@playwright/test": "^1.50.0",
    "@types/node": "^22.0.0",
    "typescript": "^5.7.0"
  }
}
```

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "noEmit": true
  },
  "include": ["**/*.ts"]
}
```

### .gitignore

```
node_modules/
test-results/
playwright-report/
blob-report/
playwright/.auth/
```

### playwright.config.ts

This is the most important file. Key decisions encoded here:

```typescript
import { defineConfig, devices } from "@playwright/test";

// Shared across setup and test workers (see §3 on run isolation)
process.env.TEST_RUN_ID = process.env.TEST_RUN_ID || String(Date.now());

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    baseURL: "http://localhost:<FRONTEND_PORT>",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },

  // Setup project runs first, then browser tests depend on it
  projects: [
    {
      name: "setup",
      testDir: "./fixtures",
      testMatch: "global-setup.ts",
    },
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
      dependencies: ["setup"],
    },
  ],

  // Auto-start backend and frontend if not already running
  webServer: [
    {
      command: "<BACKEND_START_COMMAND>",   // e.g. "cd .. && ./gradlew bootRun"
      url: "<BACKEND_HEALTH_URL>",          // e.g. "http://localhost:8080/actuator/health"
      reuseExistingServer: !process.env.CI, // reuse locally, fresh in CI
      timeout: 120_000,                     // backends are slow to start
    },
    {
      command: "<FRONTEND_START_COMMAND>",  // e.g. "cd ../frontend && npm run dev"
      url: "http://localhost:<FRONTEND_PORT>",
      reuseExistingServer: !process.env.CI,
      timeout: 30_000,
    },
  ],
});
```

**Adapt these placeholders** to each project:
- `<FRONTEND_PORT>`: Vite defaults to 5173, Next.js to 3000
- `<BACKEND_START_COMMAND>`: relative to the `e2e/` directory
- `<BACKEND_HEALTH_URL>`: a lightweight endpoint that returns 200 when ready

**`reuseExistingServer: !process.env.CI`** is critical for local DX. Developers
keep servers running and just re-run tests. CI always starts fresh.

After creating these files, run:
```bash
npm install
npx playwright install chromium
```

Verify with `npx playwright test --list` to confirm Playwright discovers the
project structure.

## 3. Utils: constants and API helpers

### utils/constants.ts

Central place for test user definitions, auth-related key names, and storage
state paths. Adapt the structure to what the app actually uses.

```typescript
import path from "path";

// Set once in playwright.config.ts, inherited by all workers
const RUN_ID = process.env.TEST_RUN_ID || String(Date.now());

// If the app stores auth state in localStorage, define the key names here.
// If the app uses httpOnly cookies, you won't need this — cookies are
// handled automatically by the browser context and storageState.
export const LOCAL_STORAGE_KEYS = {
  // ... adapt to your app's actual key names
} as const;

export interface TestUser {
  email: string;
  password: string;
}

// Define one user per auth persona the tests need.
// - Single-tenant app: one authenticated user may be enough
// - Multi-tenant app: one user per tenant to test data isolation
// - Role-based app: one user per role (admin, user, viewer)
export const TEST_USERS = {
  userA: {
    email: `e2e-user-a-${RUN_ID}@test.com`,
    password: "Test1234!",
  },
  // userB: { ... },  // add more personas as needed
} as const satisfies Record<string, TestUser>;

export type TestRole = keyof typeof TEST_USERS;

export function storageStatePath(role: TestRole): string {
  return path.join(
    __dirname, "..", "playwright", ".auth", `${role}.storageState.json`,
  );
}
```

**Why `process.env.TEST_RUN_ID`?** Playwright runs global-setup and test files
in separate worker processes. A bare `Date.now()` would produce different values
in each process. Setting the env var in `playwright.config.ts` (which loads
before any worker) ensures a single consistent value across the entire run.

**Why unique emails per run?** If the database persists between runs (e.g.
docker volume), duplicate email registration would fail. The `RUN_ID` suffix
avoids collisions without needing to wipe the DB.

### utils/api.ts

Fast, headless API helpers for seeding data. Used in global-setup and in tests
that need to seed data without going through the UI. The exact functions depend
on the app's API — the pattern is always the same:

```typescript
import type { APIRequestContext } from "@playwright/test";

// Match your API's actual response shape
export interface AuthResponse {
  // token, refreshToken, userId, tenantId, sessionId, etc.
}

export async function loginViaApi(
  request: APIRequestContext,
  email: string,
  password: string,
): Promise<AuthResponse> {
  const response = await request.post("/api/auth/login", {
    data: { email, password },
  });
  if (!response.ok()) {
    throw new Error(
      `Login failed for ${email}: ${response.status()} ${await response.text()}`,
    );
  }
  return response.json();
}

// Add registerViaApi, createItemViaApi, etc. following the same pattern —
// one helper per API action you'll call from global-setup or test seeding.
```

These use Playwright's `APIRequestContext` — not a browser, just HTTP calls.

**Note on request base URL:** The `request` fixture uses `baseURL` from
`playwright.config.ts` (the frontend URL). If the frontend's dev server proxies
`/api` to the backend (e.g. Vite proxy), API calls through `request` go through
that proxy and work. If the frontend does **not** proxy, define a separate
`API_BASE_URL` constant and use full URLs in these helpers.

## 4. Fixtures: global setup and auth

### fixtures/global-setup.ts

Runs once before all tests. Authenticates test users via API, injects auth
state into the browser, and saves storage state files. The core pattern is:

**API for speed → inject auth state → verify in browser → save state.**

This avoids flaky UI interactions during setup while still validating the
auth flow works end-to-end.

```typescript
import { test as setup } from "@playwright/test";
import { TEST_USERS, storageStatePath, type TestRole } from "../utils/constants";

const roles: TestRole[] = Object.keys(TEST_USERS) as TestRole[];

for (const role of roles) {
  setup(`authenticate ${role}`, async ({ page, request }) => {
    const user = TEST_USERS[role];

    // 1. Authenticate via API (fast, no browser interaction)
    //    This might be register, login, or both — depends on the app.
    //    Adapt to your app's auth endpoints and response shape.
    const auth = await loginViaApi(request, user.email, user.password);

    // 2. Inject auth state into the browser.
    //    HOW this works depends on the app:
    //
    //    localStorage tokens (JWT apps):
    //      await page.goto("/login");
    //      await page.evaluate(({ token }) => {
    //        localStorage.setItem("auth_token", token);
    //      }, auth);
    //
    //    httpOnly cookies (session apps):
    //      Cookies are captured automatically — just login via the
    //      browser or use page.context().addCookies() with cookies
    //      from the API response headers.
    //
    // The key requirement: after this step, navigating to a protected
    // page should work without any login interaction.

    // 3. Navigate to app and verify auth works
    await page.goto("/");
    await page.getByRole("heading", { name: "<LANDING_PAGE_HEADING>", exact: true }).waitFor();

    // 4. Save storage state (captures localStorage + cookies)
    await page.context().storageState({ path: storageStatePath(role) });
  });
}
```

### fixtures/auth.ts

Custom Playwright fixtures that provide pre-authenticated browser pages.
Tests request these by name (e.g. `{ authenticatedPage: page }`).

The number and naming of fixtures depends on what the app needs:
- **Single-tenant, no roles:** `authenticatedPage` + `unauthenticatedPage`
- **Single-tenant, roles:** `adminPage` + `userPage` + `unauthenticatedPage`
- **Multi-tenant:** `tenantAPage` + `tenantBPage` + `unauthenticatedPage`

The pattern for each fixture is identical — only the storage state file differs:

```typescript
import { test as base, type Page } from "@playwright/test";
import { storageStatePath } from "../utils/constants";

type AuthFixtures = {
  authenticatedPage: Page;
  unauthenticatedPage: Page;
  // add more personas as needed
};

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ browser }, use) => {
    const context = await browser.newContext({
      storageState: storageStatePath("userA"),
    });
    const page = context.pages()[0] ?? (await context.newPage());
    await use(page);
    await context.close();
  },

  unauthenticatedPage: async ({ browser }, use) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    await use(page);
    await context.close();
  },
});

export { expect } from "@playwright/test";
```

**Every test file** imports `{ test, expect }` from this module, not from
`@playwright/test`. This is what makes the fixture system work.

**One fixture per auth persona.** Each gets its own browser context with its
own storage state, so they never interfere with each other.

## 5. Page Object Model

Each page (or significant UI region) gets a class in `pages/`.

### Structure

```typescript
import type { Page, Locator } from "@playwright/test";
import { expect } from "@playwright/test";

export class LoginPage {
  // All locators as readonly properties — defined once in constructor
  readonly heading: Locator;
  readonly emailField: Locator;
  readonly passwordField: Locator;
  readonly submitButton: Locator;
  readonly errorAlert: Locator;

  constructor(private page: Page) {
    this.heading = page.getByRole("heading", { name: "Login" });
    this.emailField = page.getByLabel("Email");
    this.passwordField = page.getByLabel("Password");
    this.submitButton = page.getByRole("button", { name: "Login" });
    this.errorAlert = page.getByRole("alert");
  }

  // goto() navigates AND asserts the page loaded
  async goto() {
    await this.page.goto("/login");
    await expect(this.heading).toBeVisible();
  }

  // Action methods — perform user interactions
  async login(email: string, password: string) {
    await this.emailField.fill(email);
    await this.passwordField.fill(password);
    await this.submitButton.click();
  }

  // Assertion methods — verify state, prefixed with expect*
  async expectError(message: string) {
    await expect(this.errorAlert).toContainText(message);
  }
}
```

### Rules

1. **Locators as readonly constructor properties.** Lazy evaluation — they
   don't query the DOM until used. Define them all up front.

2. **`goto()` always includes an assertion.** Navigate then verify the page
   is actually loaded. Catches routing misconfigurations early.

3. **Separate action methods from assertion methods.** Actions do things
   (`login()`, `submitForm()`, `logout()`). Assertions verify things
   (`expectError()`, `expectItemVisible()`). Tests compose both.

4. **Dynamic locators as methods.** When a locator depends on a parameter,
   use a method that returns a `Locator`:
   ```typescript
   feedbackRow(title: string): Locator {
     return this.page.getByRole("row").filter({ hasText: title });
   }
   ```

5. **Instantiate in the test, not in the fixture.** Page objects are cheap
   to create and tests may need multiple POMs in one test:
   ```typescript
   test("login then see dashboard", async ({ unauthenticatedPage: page }) => {
     const loginPage = new LoginPage(page);
     const dashboard = new DashboardPage(page);
     await loginPage.goto();
     await loginPage.login(email, password);
     await expect(dashboard.heading).toBeVisible();
   });
   ```

## 6. Locator strategy

Priority order — use the first one that works:

| Priority | Method | When |
|----------|--------|------|
| 1 | `getByRole("button", { name: "Submit" })` | Buttons, headings, links, checkboxes, etc. |
| 2 | `getByLabel("Email")` | Form fields with labels |
| 3 | `getByPlaceholder("Search...")` | Fields without visible labels |
| 4 | `getByText("No items yet")` | Static text content |
| 5 | `.locator(".MuiChip-root")` | CSS selector — last resort |

### Pitfalls

**Strict mode violations.** Playwright fails if a locator matches multiple
elements. Common traps:

- `getByRole("heading", { name: "Feedback" })` matches both
  "Feedback App" (h6) and "Feedback" (h5). Fix: add `{ exact: true }`.

- `locator("[class*='MuiChip']")` matches both the chip container and its
  inner label span. Fix: use `.MuiChip-root` (the actual component class)
  or narrow with `.first()`.

- `getByRole("button", { name: "Save" })` might match a dialog button and
  a toolbar button. Fix: scope to a parent — `dialog.getByRole("button", { name: "Save" })`.

**Rule of thumb:** if a locator could plausibly match more than one element
on the page, add `exact: true`, scope it to a container, or use a more
specific selector.

## 7. Test organization

### Typical test categories

Use this as a checklist when planning tests. Include only what applies to the
app — not every app has registration, multi-tenancy, or token refresh.

| Category | What to test | When it applies |
|----------|-------------|-----------------|
| **Auth flows** | Login valid/invalid, register (if public), logout + re-entry blocked, route guards for protected paths, navigation links between auth pages | Every app with authentication |
| **CRUD** | Empty state, create + appears in list, create multiple, edit, delete, cancel without saving | Every app with data entry |
| **Data isolation** | Seed data for multiple users/tenants via API, verify each sees only their data | Multi-tenant apps or apps where users have private data |
| **Auth edge cases** | Corrupted/expired tokens, missing tokens, token refresh behavior | Apps with client-side token management |
| **Navigation** | Deep links work when authenticated, breadcrumbs, back button behavior | Apps with multiple routes |

### File structure

Group tests by feature area, not by page:

```
tests/
  auth.spec.ts              # login, register, logout, route guards
  <feature>.spec.ts         # CRUD for the main domain object
  data-isolation.spec.ts    # if applicable: multi-user/tenant separation
```

### Serial vs parallel

Most test files run in parallel (`fullyParallel: true` in config). For tests
that mutate shared database state and depend on prior tests' side effects,
opt in to serial mode per describe block:

```typescript
test.describe("CRUD", () => {
  test.describe.configure({ mode: "serial" });

  test("create item", async ({ authenticatedPage: page }) => { ... });
  test("edit item", async ({ authenticatedPage: page }) => { ... });
  test("item persists after reload", async ({ authenticatedPage: page }) => { ... });
});
```

**Default to parallel. Use serial only when tests have data dependencies.**

### Test anatomy

```typescript
import { test, expect } from "../fixtures/auth";  // always from fixtures
import { SomePage } from "../pages/some.page";
import { TEST_USERS } from "../utils/constants";

test.describe("Feature name", () => {
  test("scenario description", async ({ authenticatedPage: page }) => {
    // Arrange: instantiate page objects
    const somePage = new SomePage(page);

    // Act: navigate and interact
    await somePage.goto();
    await somePage.doSomething();

    // Assert: verify outcome
    await expect(somePage.result).toBeVisible();
  });
});
```

### Data isolation patterns

For tests that create data, prefix with a unique value to avoid collisions
with other test files running in parallel:

```typescript
const prefix = `crud-${Date.now()}`;

test("create item", async ({ authenticatedPage: page }) => {
  await createPage.fillForm({ title: `${prefix} My Item` });
  // ...
});
```

For data isolation tests, seed data via API in a setup test rather than through
the UI:

```typescript
test("seed data for both users", async ({ request }) => {
  const authA = await loginViaApi(request, TEST_USERS.userA.email, TEST_USERS.userA.password);
  await createItemViaApi(request, authA.token, { title: "User A item" });

  const authB = await loginViaApi(request, TEST_USERS.userB.email, TEST_USERS.userB.password);
  await createItemViaApi(request, authB.token, { title: "User B item" });
});
```

## 8. Implementation sequence

When building the suite for a new project, follow this order:

1. **Read the frontend code.** Before writing anything, read the actual
   components to understand exact labels, button text, heading levels,
   route paths, how auth state is stored, and error messages. Do not
   guess — wrong locators are the #1 source of test failures.

2. **Read the backend API.** Understand auth endpoints, domain CRUD
   endpoints, health check URL, and how auth tokens/sessions work.

3. **Plan test scenarios.** Using the "Typical test categories" table in
   §7, decide which categories apply to this app and list specific
   scenarios for each. Present the plan for review before writing code.

4. **Scaffold** — `package.json`, `tsconfig.json`, `playwright.config.ts`,
   `.gitignore`. Run `npm install && npx playwright install chromium`.

5. **Verify scaffold** — `npx playwright test --list` should discover the
   setup project (even with no tests yet, confirm no config errors).

6. **Utils** — `constants.ts` (match your app's actual auth storage and
   response shape), `api.ts` (one function per API endpoint you'll call
   from tests/setup).

7. **Fixtures** — `global-setup.ts` then `auth.ts`. Run
   `npx playwright test --project=setup` to verify auth works and
   storage state files are created in `playwright/.auth/`.

8. **Page objects** — one per page. Use exact labels and roles from the
   actual frontend components read in step 1.

9. **Test specs** — one file at a time. Write, run, fix, move to the next.
   Start with auth tests (validates the fixture system works).

10. **Full run** — `npx playwright test` to verify everything together.

## 9. Lessons learned

These are real problems encountered across two projects, with fixes.

### `exact: true` on ambiguous headings

If the app bar says "Feedback App" and the page heading says "Feedback",
`getByRole("heading", { name: "Feedback" })` matches both. Always use
`{ exact: true }` when a heading's text is a substring of another heading
on the same page.

### MUI component locators match nested elements

A Material UI `<Chip>` renders as `<div class="MuiChip-root"><span
class="MuiChip-label">text</span></div>`. Using `[class*='MuiChip']`
matches both. Use `.MuiChip-root` to target only the outer container.

### React Query retries change error messages

If your frontend uses React Query with `retry: 1`, the first API call might
fail with "Session expired" (from the auth refresh logic), but React Query
retries the call. On the second attempt, tokens are already cleared, so the
backend returns a raw 403, and the error message is now "Request failed: 403".

**Fix:** either set `retry: 0` for E2E, or assert on the error alert being
visible rather than matching a specific message.

### Vite proxy works for Playwright's `request` fixture

Playwright's `APIRequestContext` sends plain HTTP requests (not through a
browser). If the `baseURL` points to the Vite dev server and Vite has a
proxy configured for `/api`, API calls through `request.post("/api/...")` go
through Vite's proxy and reach the backend. This means you can use relative
URLs everywhere — no need for a separate backend URL constant.

### `Date.now()` in module scope vs across processes

Node.js caches modules, so `Date.now()` in a top-level `const` evaluates
once per process. But Playwright runs global-setup and test files in
**separate worker processes**. If both import a module with `Date.now()`,
they get different values.

**Fix:** set `process.env.TEST_RUN_ID = String(Date.now())` in
`playwright.config.ts` (which loads before workers start). In `constants.ts`,
read `process.env.TEST_RUN_ID`.

### Storage state includes localStorage AND cookies

`page.context().storageState()` captures both cookies and localStorage
origins. After injecting tokens via `page.evaluate()`, you must navigate to
a page on the correct origin so the localStorage is associated with the
right domain before saving state.

### Backend startup timeout

Java/Spring backends can take 30-90 seconds to start. Set `timeout: 120_000`
for the backend webServer entry. The frontend is usually fast (5-10s) but
give it 30s. The `url` health check should be a lightweight endpoint (e.g.
`/actuator/health`, `/api/health`).

## 10. Running tests

```bash
# Full run (auto-starts servers)
cd e2e && npx playwright test

# With servers already running (faster iteration)
cd e2e && npx playwright test

# Single file
npx playwright test tests/auth.spec.ts

# Headed mode (watch the browser)
npx playwright test --headed

# Interactive UI mode (best for debugging)
npx playwright test --ui

# List tests without running
npx playwright test --list
```
