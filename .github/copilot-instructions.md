# Copilot Instructions

This fork of `microsoft/PowerAppsCodeApps` is a workspace for building Power Apps
code apps. New apps live in `apps/<app-name>/`, scaffolded from `templates/vite`.

## Stack

React 18 + TypeScript + Vite, Fluent UI v9, `@microsoft/power-apps` SDK with the
`@microsoft/power-apps-vite` plugin. Pin React 18 in any app using Fluent UI v9
(the templates ship React 19 — downgrade after scaffolding).

## Follow the repo guides

- `docs/power-apps-code-apps.md` — the 7-step build and deploy flow. Follow it in
  order; confirm each step before the next.
- `docs/fluent-ui-conventions.md` — DataGrid, accessibility, responsive, and
  performance rules. Non-negotiable for UI work.
- `samples/FluentSample` — reference implementation for Fluent UI patterns.

## Rules

- Build against mock services first; wire real connectors only after the UI works
  end-to-end with mocks.
- Never invent connector, table, dataset, or stored procedure names — discover
  them with `pac code list-datasets` / `list-tables` /
  `list-sql-stored-procedures`, or ask.
- Never edit files under `src/generated/` — delete and re-add the data source if
  a schema changes.
- `npm run build` must pass before any `pac code push`.
- Show the app version in the UI and increment it on every deploy.
- Ask before: overwriting `.env`, running `pac code push` or any deploy, or
  anything destructive to Power Platform environments or connections.
- Prefer simple, maintainable solutions; no duplication; refactor files past
  200–300 lines; touch only code relevant to the current task.
