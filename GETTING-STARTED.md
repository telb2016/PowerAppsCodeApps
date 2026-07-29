# Getting Started — Vibe Coding Power Apps at Work

This is your personal quickstart. It assumes no prior Power Apps or command-line
experience. Do the **One-time setup** once on your work machine; after that,
**Building an app** is the loop you'll repeat.

**How this works:** this repo carries instruction files (`CLAUDE.md`,
`docs/power-apps-code-apps.md`, `docs/fluent-ui-conventions.md`,
`.github/copilot-instructions.md`) that teach an AI assistant how to build Power
Apps code apps correctly. You describe the app you want in plain English; the
assistant follows the guides, builds it with fake data first, shows it to you
running locally, and asks before deploying anything.

---

## One-time setup

### 1. Install these on your work machine

| Tool | How |
|---|---|
| **Node.js** (LTS version) | <https://nodejs.org> — the "LTS" download |
| **Git** | <https://git-scm.com/downloads> |
| **VS Code** | <https://code.visualstudio.com> |
| **Power Platform CLI** (`pac`) | Follow <https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction> — on Windows use the MSI installer; on any OS with the .NET SDK: `dotnet tool install --global Microsoft.PowerApps.CLI.Tool` |
| **Claude Code** | In a terminal: `npm install -g @anthropic-ai/claude-code` |

Check they work — open a terminal (in VS Code: **Terminal → New Terminal**) and run
each of these; every one should print a version, not an error:

```bash
node --version
git --version
pac help
claude --version
```

### 2. Two things you may need from IT / your Power Platform admin

1. **Code apps must be enabled on your environment.** An admin turns it on in the
   [Power Platform admin center](https://admin.powerplatform.microsoft.com):
   **Manage → Environments → (your environment) → Settings → Product → Features →
   Enable code apps**. If you don't know who your admin is, ask whoever manages
   Power Apps / Microsoft 365 at your company.
2. **A Power Apps Premium license** — needed by you and by anyone who will *run*
   your apps. Many companies already have these; ask IT.

You'll also need your **environment ID**: go to <https://make.powerapps.com>, click
the environment name (top right), and copy the ID shown (a long
`xxxxxxxx-xxxx-...` value). Keep it handy.

### 3. Get this repo onto your work machine

In a terminal, in the folder where you keep projects:

```bash
git clone https://github.com/telb2016/PowerAppsCodeApps.git
cd PowerAppsCodeApps
git checkout claude/power-apps-work-setup-pr3f2t
```

That last command switches to the branch that contains all the AI setup files.
(Optional, later: on GitHub you can open a pull request from this branch into
`main` in your fork and merge it, after which the checkout step isn't needed.)

### 4. Sign in to Power Platform

```bash
pac auth create
pac env select --environment <paste your environment ID>
pac auth who
```

The first command opens a browser — sign in with your work account. The last one
should show your name and the right environment. That's the whole setup.

---

## Building an app (the fun part)

1. In the terminal, from the `PowerAppsCodeApps` folder, start Claude Code:

   ```bash
   claude
   ```

2. Describe what you want. Example first prompts:

   > Read CLAUDE.md and the build guide it references, then create a new code app
   > in `apps/vacation-tracker`. It's a vacation request tracker: employees submit
   > requests with dates and a reason, and a table shows request status. Use fake
   > data for now and get it running locally so I can see it.

   > Create a new code app in `apps/team-directory` that shows everyone on my team
   > with their photo, title, and contact info from Office 365. Start with mock
   > data.

   > Open the app in `apps/vacation-tracker` and add an approvals page where a
   > manager can approve or reject requests.

3. When the assistant says the app is running, it will point you at a **Local
   Play** URL — open it in the **same browser profile you use for work / Power
   Apps**. If the browser asks for permission to access the local network, allow
   it (Chrome and Edge ask this for local development now).

4. Iterate in plain English: "make the table sortable", "add a search box",
   "it should look good on phones too". The assistant follows the Fluent UI
   conventions, so apps come out looking like Microsoft 365.

5. **Deploying** (publishing so others can use it): just say "deploy it". The
   assistant runs the build, asks you to confirm, then runs `pac code push` and
   gives you the app's Power Apps link. You can also share the app with coworkers
   from <https://make.powerapps.com> like any other Power App.

**Connecting real data** (SQL, SharePoint, Office 365): do this only after the app
looks right with fake data. Create the connection once at
<https://make.powerapps.com> → **Connections** → **New connection**, then tell the
assistant, e.g. "wire the app up to our SQL connection". It will discover the real
table names rather than guessing.

---

## If something goes wrong

- **`pac` not recognized** → the CLI isn't installed or the terminal needs
  restarting after install.
- **Local Play page is blank** → wrong browser profile (must match your work
  account), or the browser blocked local network access — check for a prompt.
- **Deploy fails** → tell the assistant to run `npm run build` and fix the errors
  first; it knows to do this.
- **"Code apps not enabled"-style errors** → the environment toggle from step 2
  isn't on yet.
- Anything else → paste the error into Claude Code and ask. Seriously, that's the
  workflow.

## Links

- [Official code apps docs](https://learn.microsoft.com/en-us/power-apps/developer/code-apps/)
- [Microsoft's official AI-assistant plugin](https://github.com/microsoft/power-platform-skills)
  (a heavier-weight alternative to the instruction files in this repo)
- [This repo's build guide](docs/power-apps-code-apps.md) — what the assistant follows
- [Fluent UI conventions](docs/fluent-ui-conventions.md) — how the apps get their look
