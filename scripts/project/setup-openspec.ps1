<#
.SYNOPSIS
    Initializes or retries the pinned OpenSpec CLI for a generated Case Project.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),

    [Parameter(Mandatory = $false)]
    [switch]$Skip,

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$StatusPath = Join-Path $ProjectRoot "AI_FRAMEWORK_STATUS.yml"
$ConfigPath = Join-Path $ProjectRoot "config\ai-framework-versions.json"
$OpenSpecPath = Join-Path $ProjectRoot "openspec"
$BackupRoot = Join-Path $ProjectRoot ".ai-backup"

function Quote-Yaml([string]$Value) {
    if ($null -eq $Value) { return "''" }
    return "'" + ($Value -replace "'", "''") + "'"
}

function Write-FrameworkStatus(
    [string]$Status,
    [string]$Package = "",
    [string]$Version = "",
    [string]$Message = "",
    [string]$RetryCommand = ".\scripts\setup-openspec.ps1"
) {
    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    @(
        "openspec:"
        "  status: $(Quote-Yaml $Status)"
        "  cli_package: $(Quote-Yaml $Package)"
        "  cli_version: $(Quote-Yaml $Version)"
        "  initialized_at: $(Quote-Yaml $timestamp)"
        "  command: $(Quote-Yaml ('npx --yes ' + $Package + '@' + $Version + ' init'))"
        "  message: $(Quote-Yaml $Message)"
        "  retry_command: $(Quote-Yaml $RetryCommand)"
    ) | Set-Content -Path $StatusPath -Encoding utf8
}

if (-not (Test-Path $ProjectRoot)) {
    Write-Error "Project root not found: $ProjectRoot"
    exit 1
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "[FAIL] OpenSpec version configuration not found: $ConfigPath" -ForegroundColor Red
    Write-FrameworkStatus -Status "failed" -Message "OpenSpec version configuration was not found."
    exit 1
}

$Config = Get-Content -Path $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
$Package = [string]$Config.openspec.package
$Version = [string]$Config.openspec.version
if ([string]::IsNullOrWhiteSpace($Package) -or [string]::IsNullOrWhiteSpace($Version) -or $Version -eq "latest") {
    Write-Host "[FAIL] OpenSpec package/version configuration is invalid or unpinned." -ForegroundColor Red
    Write-FrameworkStatus -Status "failed" -Package $Package -Version $Version -Message "OpenSpec package/version configuration is invalid or unpinned."
    exit 1
}

if ($Skip) {
    Write-Host "[SKIP] OpenSpec initialization skipped by user." -ForegroundColor Yellow
    Write-FrameworkStatus -Status "skipped" -Package $Package -Version $Version -Message "OpenSpec initialization was skipped by the user."
    exit 0
}

foreach ($commandName in @("node", "npm", "npx")) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        $message = "$commandName is not installed or not available in PATH."
        Write-Host "[FAIL] $message" -ForegroundColor Red
        Write-FrameworkStatus -Status "failed" -Package $Package -Version $Version -Message $message
        exit 1
    }
}

if (-not $NonInteractive) {
    $answer = Read-Host "OpenSpecを初期化しますか？ (Y/n)"
    if ($answer -and $answer.Trim().ToLower() -eq "n") {
        Write-Host "[SKIP] OpenSpec initialization skipped by user." -ForegroundColor Yellow
        Write-FrameworkStatus -Status "skipped" -Package $Package -Version $Version -Message "OpenSpec initialization was skipped by the user."
        exit 0
    }
}

Push-Location $ProjectRoot
try {
    if (Test-Path $OpenSpecPath) {
        $backupTimestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $BackupPath = Join-Path $BackupRoot "$backupTimestamp\openspec"
        New-Item -ItemType Directory -Path (Split-Path -Parent $BackupPath) -Force | Out-Null
        Copy-Item -Path $OpenSpecPath -Destination $BackupPath -Recurse -Force
        Write-Host "[BACKUP] OpenSpec managed files: $OpenSpecPath" -ForegroundColor Yellow
        Write-Host "         Backup: $BackupPath" -ForegroundColor Yellow
        Remove-Item -Path $OpenSpecPath -Recurse -Force
    }

    Write-Host "[INFO] Initializing OpenSpec $Version in $ProjectRoot" -ForegroundColor Cyan
    & npx --yes "$Package@$Version" init
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $message = "OpenSpec initialization failed with exit code $exitCode."
        Write-Host "[FAIL] $message" -ForegroundColor Red
        Write-FrameworkStatus -Status "failed" -Package $Package -Version $Version -Message $message
        exit 1
    }

    Write-FrameworkStatus -Status "success" -Package $Package -Version $Version -Message "OpenSpec initialized successfully."
    Write-Host "[PASS] OpenSpec initialized. Next: enter your first theme and create a Change Artifact." -ForegroundColor Green
    exit 0
} catch {
    $message = "OpenSpec initialization failed: $($_.Exception.Message)"
    Write-Host "[FAIL] $message" -ForegroundColor Red
    Write-FrameworkStatus -Status "failed" -Package $Package -Version $Version -Message $message
    exit 1
} finally {
    Pop-Location
}
