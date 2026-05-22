# AvePoint Fly — Migration Toolkit

A single-script GUI toolkit for automating the end-to-end AvePoint Fly
migration setup: target tenant app registration, connection creation, and
migration execution.

> **Entry point:** `menu.ps1` — run this and choose from the menu.

---

## Files

| File                        | Purpose                                                                 |
|-----------------------------|-------------------------------------------------------------------------|
| `menu.ps1`                  | **Main entry point.** Merged GUI — menu, app registration, connections, and migration runner in one script. |
| `fly-connector.js`          | Playwright automation backend for portal-driven connection creation (Node.js) |
| `package.json`              | Node dependencies                                                       |
| `ourvolaris.png`            | OurVolaris logo displayed in all form headers                           |
| `workloads.json`            | Per-workload connection and policy config, auto-written by the Connections screen |
| `auth/storageState.json`    | Created on first AOS sign-in. Holds cookies/session.                   |
| `logs/`                     | Playwright failure screenshots + Migration Runner log files             |

> `New-FlyConnectionsGUI.ps1` and `Fly-Migrationrunner.ps1` remain as
> backups but are no longer launched directly — all three screens are
> embedded in `menu.ps1`.

---

## One-time setup

1. Install **Node.js 18 or later** from https://nodejs.org. Confirm with
   `node -v` in a fresh PowerShell window.
2. In this folder, run:
   ```
   npm install
   npx playwright install chromium
   ```
3. Install the Fly PowerShell module (required for the Migration Runner):
   ```powershell
   Install-Module Fly.Client -Scope CurrentUser
   ```
4. Launch the toolkit:
   ```powershell
   .\menu.ps1
   ```

---

## Menu options

### 1 · Create App Registration

Registers (or records) an Azure AD app in the **target tenant** and grants
it the permissions required by Fly.

**Workflow:**

1. Enter the target tenant domain and the desired app name.
2. Choose **Register new app** or **Use existing app**.
   - *New app* — authenticates via device code flow (Global Admin required),
     registers the app, creates a client secret, assigns all required Graph
     and Exchange API permissions, grants admin consent, and assigns the
     Exchange Administrator directory role to the service principal.
   - *Existing app* — paste in the Client ID and Secret; the form validates
     the tenant and records the values.
3. Copy the **Tenant ID**, **App (Client) ID**, and secret (via *Copy Secret*)
   into the Fly portal connections.

Tenant domain and app name are persisted to a shared config
(`%LOCALAPPDATA%\FlyMigration\shared-config.json`) and pre-filled on the
next run.

---

### 2 · Create Connections

Browser-automates the AOS portal (`fly.avepointonlineservices.com`) to create
Fly connections for up to six M365 workloads. Uses Playwright (Chromium).

This screen exists because the `Fly.Client` PowerShell module has no cmdlet
for creating connections — that is a portal-only operation.

**Workflow:**

1. **Sign in to AOS** — first run, or when the saved session expires. Chrome
   opens; complete Microsoft SSO + MFA, then close Chrome (or wait — the
   script detects the post-login page automatically).
2. **Enter Tenant**:
   - *Display Name* — used in the connection name, e.g. `OurVolaris`
   - *Search Code* — short code shown in the AOS Tenant dropdown, e.g. `ourvolaris`
   - *Credentials Name* — substring matched against the App profile and
     Service account dropdowns, e.g. `ITVolaris`
3. **Pick workloads** — defaults to all six.
4. **Create Connections** — Chrome drives the portal for each workload;
   the results grid updates live.

Connections are named `<DisplayName> - <Workload>` (e.g.
`OurVolaris - Microsoft Teams`). Successfully created destination connections
are written automatically to `workloads.json` for use by the Migration Runner.

**Behaviour:**

- **Idempotent.** Connections matched by name are skipped, not recreated.
- **Failure screenshots.** Failures capture a full-page screenshot to
  `logs/fail-<id>-<timestamp>.png` and reference it in the result message.
- **Stop button.** Kills the underlying Chrome and Node process immediately.
- **Save Log.** Exports the current results grid to CSV.

---

### 3 · Create and Load Mapping Files

Runs migrations against the Fly API for each configured workload.

**Workflow:**

1. **Connect** — enter the Fly API URL, AOS Client ID, and Client Secret, then
   click *Connect*. Credentials are saved encrypted for the next run.
2. **Customer Prefix** — used as the project name prefix, e.g. `OurVolaris`.
   Pre-filled from shared config if set by the App Registration screen.
3. **Workloads** — for each workload, select a mapping CSV, verify the
   pre-populated Source / Destination connections (loaded from `workloads.json`),
   and choose an operation:
   - *Import Only* — import the mapping CSV into the project.
   - *Verification* — import then start verification.
   - *Pre-Scan* — import then start a pre-scan.
   - *Migration* — import then start a full migration.
4. **Report folder** — where mapping status CSV reports are saved (defaults to Desktop).
5. **Run Selected Workloads.**

Each run appends a timestamped log file to `logs/FlyRunner_<timestamp>.log`.

---

## Shared config

Settings are shared between screens via two locations:

| Location | Content |
|---|---|
| `%LOCALAPPDATA%\FlyMigration\shared-config.json` | Tenant domain, app name, tenant name, search code, credentials name |
| `%APPDATA%\FlyMigration\config.json` | Fly API URL and client credentials (secret stored encrypted) |
| `workloads.json` (next to `menu.ps1`) | Per-workload policy, source connection, destination connection |

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| *"Session appears stale"* | Re-run **Sign in to AOS** on the Connections screen. |
| *Selector failures (FAILED with "locator timeout")* | The AOS portal UI has changed. Check the failure screenshot in `logs/`, then update the selectors in `fly-connector.js → createOneConnection()`. |
| *Chrome not opening* | Run `npx playwright install chromium` in this folder. |
| *Node.js not found* | Install Node 18+ from https://nodejs.org and open a new PowerShell window. |
| *Fly.Client module not found* | Run `Install-Module Fly.Client -Scope CurrentUser`. |
| *404 from Fly API* | Verify the API URL ends with `/fly`, e.g. `https://graph.avepointonlineservices.com/fly`. |
| *App registration: authentication timed out* | Device code expired (15 min limit). Click *Authenticate and Register* again. |

## Known limitations

- The target tenant must already be registered in **AOS Tenant Management**
  before connections can be created. That registration is not automated here.
- The *Container for auto map* field is left at **None** for all connections.
  To set it per workload, extend the task schema in `fly-connector.js`.
- The Migration Runner requires `Fly.Client` version that exposes
  `Connect-Fly` and the per-workload `Import-Fly*`, `Start-Fly*`, and
  `Export-Fly*` cmdlets.
