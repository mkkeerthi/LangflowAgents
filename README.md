## Structure

```
LangflowAgents/
├── .venv/                          # Python 3.13 + Langflow 1.12.1 (gitignored)
├── Agents/                         # Agent write-ups exported from Langflow
│   ├── BugTriage/                  # BugTriageAgentDetails.md + screenshots
│   └── EdgeCase/                   # EdgeCasesAgentDetails.md + screenshots
├── Components/                     # Custom Langflow components (Python)
│   ├── Groq.py                     # Groq chat-completion component
│   └── Jira.py                     # Fetches a Jira work item description by key
├── Flows/                          # Flow exports (JSON)
│   ├── Bug Triage Agent.json
│   └── Edge Cases Agent.json
├── langflow_data/                  # Langflow runtime data (gitignored)
│   ├── langflow.db                 # SQLite DB: flows, global variables, credentials, chat history
│   └── secret_key                  # Encrypts the CREDENTIAL-type variables in the DB
├── scripts/
│   ├── run_langflow.ps1            # Starts the server against langflow_data/
│   └── stop_langflow.ps1           # Stops the server
├── .env                            # Runtime config (gitignored)
├── .env.example                    # Template for the runtime config
├── .gitignore
└── README.md
```

## The two flows

| Flow | Chain | What it does |
|------|-------|--------------|
| **Bug Triage Agent** | Chat Input → Jira → Language Model (Open Router) → Chat Output, with a Prompt Template wired in as the system message | Takes a Jira work item key (e.g. `SCRUM-3`), fetches the issue, and returns `SEVERITY`, `PRIORITY`, `IMPACT_AREAS`, `ROOT_CAUSE_ANALYSIS` and `JUSTIFICATION`. |
| **Edge Cases Agent** | Chat Input → Groq → Chat Output, with a Prompt Template wired in as the system prompt | Takes a software requirement and returns a RICEPOT-grouped list of edge cases. |

Both flows live in the `Starter Project` folder inside the Langflow UI.

## Data and credentials

Everything the flows need is already stored in `langflow_data/langflow.db`, so they run
without any re-configuration:

| Global variable | Type | Used for |
|-----------------|------|----------|
| `Groq_Api_Key` | Credential | Groq API key used by the Edge Cases Agent |
| `Groq_Model` | Generic | Groq model id (`qwen/qwen3.8-27b`) |
| `jira_url` | Generic | Jira site (`https://<your-site>.atlassian.net`) |
| `jira_email` | Generic | Atlassian account email |
| `jira_api_token` | Credential | Jira API token (also embedded in the Bug Triage Jira node) |
| `OPENROUTER_API_KEY` | Credential | Open Router key used by the Bug Triage model node |
| `__enabled_models__` | Generic | Enabled Open Router model list |

> **Keep `langflow_data/secret_key` with the database.** The `Credential` rows are
> Fernet-encrypted with that key. Copying `langflow.db` without `secret_key` makes the
> stored API keys undecryptable and the flows will fail to authenticate.

The database also carries the 45 saved chat messages and the sample "Starter Projects"
that shipped with the original install.

## Prerequisites

- Windows with PowerShell.
- Network access to `api.groq.com`, `<your-site>.atlassian.net` and `openrouter.ai`.
- Nothing else — Python and Langflow are already inside `.venv/` (Python 3.13.15,
  Langflow 1.12.1).

## Run

1. **Open a terminal at the project root.**

   ```powershell
   cd C:\LangflowAgents
   ```

2. **Confirm the virtualenv and data are present.**

   ```powershell
   Test-Path .\.venv\Scripts\python.exe          # -> True
   Test-Path .\langflow_data\langflow.db         # -> True
   Test-Path .\langflow_data\secret_key          # -> True
   ```

3. **Check that the port is free** (see [Notes](#notes) — the Chapter 9 instance may
   already hold port 7860):

   ```powershell
   Get-NetTCPConnection -LocalPort 7860 -State Listen -ErrorAction SilentlyContinue
   # no output = port is free
   ```

4. **Start the server.** The script points Langflow at this project's `langflow_data/`
   and `Components/` folder automatically:

   ```powershell
   .\scripts\run_langflow.ps1
   ```

   To run it on another port, or in the background:

   ```powershell
   .\scripts\run_langflow.ps1 -Port 7861

   Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','.\scripts\run_langflow.ps1'
   ```

   Equivalent to the script, if you prefer the raw command:

   ```powershell
   $env:LANGFLOW_CONFIG_DIR      = "$PWD\langflow_data"
   $env:LANGFLOW_DATABASE_URL    = "sqlite:///$($PWD.Path.Replace('\','/'))/langflow_data/langflow.db"
   $env:LANGFLOW_COMPONENTS_PATH = "$PWD\Components"
   .\.venv\Scripts\python.exe -m langflow run --host 127.0.0.1 --port 7860
   ```

5. **Wait for startup.** The first run is slow (it initialises the database and builds
   the component catalog) and may print nothing for a minute or more. It is ready when it
   logs a banner with the access URL.

6. **Verify the server is healthy.**

   ```powershell
   Invoke-WebRequest http://127.0.0.1:7860/health_check -UseBasicParsing
   # -> {"status":"ok","chat":"ok","db":"ok"}
   ```

7. **Open the UI** in a browser: <http://127.0.0.1:7860>. It auto-logs in as the
   superuser `langflow`. Open **Starter Project** and pick either agent flow, then run it
   from the Playground.

8. **Try a flow.** Use these inputs to reproduce the chapter results:

   - **Edge Cases Agent** — paste a requirement (e.g. *"Manage Orders for an e-commerce
     checkout"*).
   - **Bug Triage Agent** — enter a Jira key, e.g. `SCRUM-3`.

## Stop

```powershell
.\scripts\stop_langflow.ps1
# or, for a different port
.\scripts\stop_langflow.ps1 -Port 7861
```

Manually, if you prefer:

```powershell
Get-NetTCPConnection -LocalPort 7860 -State Listen |
  Select-Object -ExpandProperty OwningProcess |
  ForEach-Object { Stop-Process -Id $_ -Force }
```

## Notes

- **The `Credential` variables are encrypted** with `langflow_data/secret_key`. Treat that
  file as a secret and never commit either it or `langflow.db`.
- **Do not delete `.venv/` casually** — it is the only Python environment for this
  project. Because the database lives in `langflow_data/` (and not inside `.venv/`),
  rebuilding the venv will **not** wipe the flows.
- **PyTorch is not installed**, so embedding/document components that need it will warn
  and be unavailable.
- `.venv/`, `langflow_data/` and `.env` are gitignored; only project content
  (`Agents/`, `Components/`, `Flows/`, `scripts/`, docs) is meant to be committed.
