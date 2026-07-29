# CLAUDE.md

## What this repo is

A fork of `microsoft/PowerAppsCodeApps` used as a workspace for building Power Apps
code apps with AI assistance. New apps are scaffolded into `apps/<app-name>/` from the
official templates in `templates/`.

## Stack

React 18 + TypeScript + Vite, Fluent UI v9, `@microsoft/power-apps` SDK with the
`@microsoft/power-apps-vite` plugin.

> Pin React 18 in any app that uses Fluent UI v9 — its peer range does not include
> React 19. `samples/FluentSample` is the reference for this pairing. The templates
> ship React 19, so downgrade after scaffolding (see the build guide, step 2).

## Commands (run inside the app folder, e.g. `apps/my-app/`)

```bash
npm run dev      # Vite dev server + Power Apps local harness — open the "Local Play" URL
npm run build    # tsc -b && vite build — must pass before any push
pac code push    # deploy — ask the user first
pac auth who     # verify the active auth/environment before any pac command
```

## Repo map

- `templates/vite` — minimal template; scaffold new Fluent apps from this
- `templates/starter` — Tailwind/Radix template (not the default here; we use Fluent)
- `samples/FluentSample` — reference implementation for Fluent UI v9 patterns
- `docs/power-apps-code-apps.md` — full 7-step build and deploy guide
- `docs/fluent-ui-conventions.md` — DataGrid, a11y, responsive, perf rules

Read the docs on demand; don't preload.

## Code standards

- Prefer the simple, maintainable solution.
- Search for existing logic before writing new logic. No duplication.
- Introduce a new pattern or library only after exhausting the current
  implementation — and if you do, delete the old one in the same change.
- Refactor files past 200–300 lines.
- Consistent naming and formatting. Use the configured linter/formatter.
- No one-off scripts in the main codebase.

## Workflow rules

- Touch only code relevant to the current task. Do not fix unrelated things you
  notice unless asked.
- No large refactors or architectural changes without approval first.
- Before changing shared code, check downstream dependents and say what you found.
- If a change spans multiple components, summarize the reasoning in your response.
- Show the app version in the UI and increment it on every deploy (the user can
  opt out of this).
- Never edit files under `src/generated/` — they are produced by
  `pac code add-data-source`. If a schema changes, delete and re-add the data source.

## Hard stops — ask before proceeding

- Overwriting `.env`
- Running `pac code push` or any deploy
- Anything destructive to Power Platform environments or connections

## Data rules

- Build every app against mock services first; wire real connectors only after the
  UI works end-to-end with mocks (build guide, steps 4–6).
- Never invent connector, table, dataset, or stored procedure names. Discover them
  with `pac code list-datasets` / `list-tables` / `list-sql-stored-procedures`, or
  ask the user.
