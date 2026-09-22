<#
.SYNOPSIS
    Start the Langflow server for this project.

.DESCRIPTION
    Boots Langflow from the project-local virtualenv and points it at the
    project-local data directory (flows, credentials, chat history), so this
    instance is fully self-contained and independent of any other install.

.EXAMPLE
    .\scripts\run_langflow.ps1
    .\scripts\run_langflow.ps1 -LangflowHost 0.0.0.0 -Port 7861
#>
[CmdletBinding()]
param(
    [string]$LangflowHost = '127.0.0.1',
    [int]$Port = 7860
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root '.venv\Scripts\python.exe'
$dataDir = Join-Path $root 'langflow_data'
$dbPath = (Join-Path $dataDir 'langflow.db').Replace('\', '/')

if (-not (Test-Path $python)) {
    throw "Virtualenv Python not found at $python. See README.md setup steps."
}
if (-not (Test-Path (Join-Path $dataDir 'langflow.db'))) {
    throw "Langflow database not found at $dataDir\langflow.db. See README.md setup steps."
}

$env:LANGFLOW_CONFIG_DIR = $dataDir
$env:LANGFLOW_DATABASE_URL = "sqlite:///$dbPath"
$env:LANGFLOW_COMPONENTS_PATH = Join-Path $root 'Components'

Write-Host "Langflow data dir : $dataDir"
Write-Host "Langflow database : $dbPath"
Write-Host "Custom components : $env:LANGFLOW_COMPONENTS_PATH"
Write-Host "Starting server on http://${LangflowHost}:$Port (first start is slow) ..."

& $python -m langflow run --host $LangflowHost --port $Port
