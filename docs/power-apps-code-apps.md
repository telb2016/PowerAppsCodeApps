# Building a Power Apps Code App

Order matters. Confirm each step works before moving on.

1. Scaffold from the official template
2. Install Fluent UI v9 (pin React 18)
3. Connect to Power Platform (`pac auth` + `pac code init`)
4. Build against mocked data
5. Run locally in Power Apps
6. Wire up real connectors
7. Test and deploy

This guide reflects the GA release of code apps (the `@microsoft/power-apps` npm SDK
and its Vite plugin). Official docs: <https://learn.microsoft.com/en-us/power-apps/developer/code-apps/>

> Note: `@microsoft/power-apps` v1.0.4+ ships an npm-based CLI that will eventually
> replace the `pac code` commands used below. Both work today; this guide uses `pac`.

---

## Step 1 — Scaffold from the official template

Create new apps under `apps/` in this repo:

```bash
npx degit github:microsoft/PowerAppsCodeApps/templates/vite apps/my-app
cd apps/my-app
npm install
```

Replace `my-app` with the name the user gave.

The template is pre-configured for code apps: `@microsoft/power-apps` is already a
dependency and `vite.config.ts` already loads the `powerApps()` plugin from
`@microsoft/power-apps-vite`. No manual port, base-path, `PowerProvider`, or
`tsconfig` changes are needed — those legacy steps are obsolete.

---

## Step 2 — Install Fluent UI v9 (pin React 18)

The template ships React 19, but Fluent UI v9 requires React 18. Downgrade first:

```bash
npm install react@^18.3.1 react-dom@^18.3.1
npm install --save-dev @types/react@^18 @types/react-dom@^18
```

Then install Fluent UI:

```bash
npm install @fluentui/react-components @fluentui/react-icons
```

Wrap the app in `FluentProvider`:

```typescript
import { FluentProvider, webLightTheme } from '@fluentui/react-components';

function App() {
  return <FluentProvider theme={webLightTheme}>{/* app */}</FluentProvider>;
}
```

Verify `npm run build` passes after the downgrade before continuing.

Conventions for DataGrid, accessibility, responsiveness, and performance live in
`docs/fluent-ui-conventions.md`. `samples/FluentSample` in this repo is the
reference implementation.

---

## Step 3 — Connect to Power Platform

The target environment must have code apps enabled (an admin toggle in the Power
Platform admin center — see `GETTING-STARTED.md`). No special "First Release"
environment is needed anymore.

```bash
pac auth create                                  # sign in with the work account
pac env select --environment <environment id>    # the environment to publish into
pac auth who                                     # verify before proceeding
```

Then initialize the app (from inside the app folder):

```bash
pac code init --displayName "My App"
```

Substitute the real app name. This creates `power.config.json` — never edit it by hand.

---

## Step 4 — Build against mocked data

### Service layer

- Define TypeScript interfaces for every data operation (CRUD, search, pagination)
  with strongly typed params and returns.
- Both mock and real services implement the same contract.
- Singleton factory manages instances and allows runtime switching between mock and
  real. One configuration point for the whole app.

### Mock services — build these first

- Simulate real operations, including pagination and filtering.
- Realistic test data.
- Verbose logging for debugging.

### Real services — not yet

Do not implement until the app works end-to-end against mocks and the user asks.
Table and stored procedure names come from discovery (step 6) or the user — never
invent them.

---

## Step 5 — Run locally in Power Apps

```bash
npm run dev
```

Open the URL labelled **Local Play** in the terminal output, in the **same browser
profile** as the Power Platform tenant.

> Chrome and Edge (since December 2025) block requests from public origins to
> localhost by default. If the Local Play page can't reach the dev server, allow
> local network access when the browser prompts, or ask IT about the enterprise
> policy for it.

---

## Step 6 — Wire up real connectors

Only after everything works against mocks. Connections are created in the Power Apps
maker portal (<https://make.powerapps.com> → Connections), then attached to the app
with the CLI.

```bash
pac connection list        # Connection ID + API name for each connection
```

Non-tabular (example — Office 365 Users):

```bash
pac code add-data-source -a "shared_office365users" -c <connectionId>
```

Tabular (SQL, SharePoint): discover names first — never guess them:

```bash
pac code list-datasets -a "shared_sql" -c <connectionId>
pac code list-tables   -a "shared_sql" -c <connectionId> -d <datasetName>
pac code list-sql-stored-procedures    -c <connectionId> -d <datasetName>
```

Then add, using the exact names from the output (case-sensitive):

```bash
# table
pac code add-data-source -a "shared_sql" -c <connectionId> \
  -t "[dbo].[TableName]" -d "server.database.windows.net,database"

# stored procedure
pac code add-data-source -a "shared_sql" -c <connectionId> \
  -d "server.database.windows.net,database" -sp "[dbo].[ProcName]"
```

Each `add-data-source` generates typed model and service files under
`src/generated/`. Use them via their service classes (e.g.
`Office365UsersService.MyProfile()`); never edit generated files. If a schema
changes, `pac code delete-data-source` and re-add — there is no refresh command.

Swap the mock service for a real implementation behind the same interface, keeping
the factory as the single switch point.

---

## Step 7 — Test and deploy

```bash
npm run build     # must pass — fix errors before pushing
pac code push     # ask the user before running this
```

A successful push prints the Power Apps URL for the deployed app. Show the app
version in the UI and increment it on every deploy.

### Troubleshooting

| Symptom | Check |
|---|---|
| Local Play page is blank or can't connect | Same browser profile as the tenant; allow the browser's local-network-access prompt |
| `pac` commands hit the wrong environment | `pac auth who`, then `pac env select --environment <id>` |
| Push rejected | Run `npm run build` first and fix errors |
| Fluent UI type/peer-dependency errors | React must be 18.x, including `@types/react` (step 2) |
| Auth loops | Use the same browser profile as the Power Platform tenant |

### Reference links

- [Code apps documentation](https://learn.microsoft.com/en-us/power-apps/developer/code-apps/)
- [Create an app from scratch](https://learn.microsoft.com/en-us/power-apps/developer/code-apps/how-to/create-an-app-from-scratch)
- [Connect your code app to data](https://learn.microsoft.com/en-us/power-apps/developer/code-apps/how-to/connect-to-data)
- [Official AI-assistant plugin](https://github.com/microsoft/power-platform-skills)
