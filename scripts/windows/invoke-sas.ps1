<#
.SYNOPSIS
    invoke-sas.ps1 - SAS Batch Execution Wrapper for Windows & Cursor Tasks
.DESCRIPTION
    Discovers local SAS installation, runs current .sas program in batch mode,
    isolates .log and .lst outputs to .run/sas/<program>/<timestamp>/, and parses ERROR/WARNINGs.
.PARAMETER SysIn
    Path to the .sas program to execute
.PARAMETER SasExe
    Optional override path to sas.exe
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SysIn,

    [Parameter(Mandatory = $false)]
    [string]$SasExe = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $SysIn)) {
    Write-Error "[ERROR] Specified SAS program file does not exist: $SysIn"
    exit 1
}

$SysInPath = (Resolve-Path $SysIn).Path
$ProgramName = [System.IO.Path]::GetFileNameWithoutExtension($SysInPath)
$Timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

# Find Project Root (where PROJECT.yml or .git exists)
$CurrentDir = Split-Path -Parent $SysInPath
while ($CurrentDir -and (-not (Test-Path (Join-Path $CurrentDir "PROJECT.yml"))) -and (-not (Test-Path (Join-Path $CurrentDir ".git")))) {
    $parent = Split-Path -Parent $CurrentDir
    if ($parent -eq $CurrentDir) { break }
    $CurrentDir = $parent
}
if (-not $CurrentDir) { $CurrentDir = Get-Location }

# 1. Discover sas.exe Path
if ([string]::IsNullOrWhiteSpace($SasExe)) {
    # Check config/local.paths.yml if present
    $LocalConfig = Join-Path $CurrentDir "config\local.paths.yml"
    if (Test-Path $LocalConfig) {
        $raw = Get-Content -Path $LocalConfig -Raw
        if ($raw -match 'sas_executable:\s*["'']?([^"'']+)["'']?') {
            $configured = $matches[1].Trim()
            if (Test-Path $configured) {
                $SasExe = $configured
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($SasExe)) {
    # Check Standard Installation Locations
    $Candidates = @(
        "C:\Program Files\SASHome\SASFoundation\9.4\sas.exe",
        "C:\Program Files\SASHome2\SASFoundation\9.4\sas.exe",
        "C:\SASHome\SASFoundation\9.4\sas.exe",
        "C:\Program Files (x86)\SASHome\SASFoundation\9.4\sas.exe"
    )
    foreach ($cand in $Candidates) {
        if (Test-Path $cand) {
            $SasExe = $cand
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($SasExe)) {
    # Check Command in PATH
    $cmd = Get-Command "sas.exe" -ErrorAction SilentlyContinue
    if ($cmd) { $SasExe = $cmd.Source }
}

if ([string]::IsNullOrWhiteSpace($SasExe) -or (-not (Test-Path $SasExe))) {
    Write-Host "`n[ERROR] SAS Foundation (sas.exe) was not found in standard paths or config." -ForegroundColor Red
    Write-Host "        Please specify the path in 'config/local.paths.yml' or install SAS Foundation." -ForegroundColor Yellow
    exit 2
}

# 2. Prepare Isolated Run Output Directory
$RunDir = Join-Path $CurrentDir ".run\sas\$ProgramName\$Timestamp"
New-Item -ItemType Directory -Path $RunDir -Force | Out-Null

$LogFile = Join-Path $RunDir "$ProgramName.log"
$LstFile = Join-Path $RunDir "$ProgramName.lst"
$MetaFile = Join-Path $RunDir "run-metadata.json"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  SAS Execution: $ProgramName.sas" -ForegroundColor Cyan
Write-Host "  SAS Engine: $SasExe" -ForegroundColor Cyan
Write-Host "  Output Dir: $RunDir" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 3. Execute SAS Process
$SasArgs = @(
    "-SYSIN", "`"$SysInPath`"",
    "-LOG", "`"$LogFile`"",
    "-PRINT", "`"$LstFile`"",
    "-NOSPLASH",
    "-NONOTES" # Optional, standard batch execution
)

$StartTime = Get-Date
$Process = Start-Process -FilePath $SasExe -ArgumentList $SasArgs -Wait -PassThru -NoNewWindow
$EndTime = Get-Date
$DurationSec = ($EndTime - $StartTime).TotalSeconds

# 4. Parse Log for Errors & Warnings
$ErrorLines = @()
$WarningLines = @()

if (Test-Path $LogFile) {
    # Read as CP932 / Shift-JIS
    $Encoding = [System.Text.Encoding]::GetEncoding(932)
    $LogContent = [System.IO.File]::ReadAllLines($LogFile, $Encoding)

    foreach ($line in $LogContent) {
        if ($line -match '^ERROR:') {
            $ErrorLines += $line
        } elseif ($line -match '^WARNING:') {
            $WarningLines += $line
        }
    }
}

$Status = "SUCCESS"
if ($Process.ExitCode -ne 0 -or $ErrorLines.Count -gt 0) {
    $Status = "ERROR"
} elseif ($WarningLines.Count -gt 0) {
    $Status = "WARNING"
}

# 5. Write Run Metadata
$Meta = @{
    program = $SysInPath
    timestamp = $Timestamp
    status = $Status
    exit_code = $Process.ExitCode
    duration_seconds = [math]::Round($DurationSec, 2)
    error_count = $ErrorLines.Count
    warning_count = $WarningLines.Count
    log_path = $LogFile
    lst_path = $LstFile
}
$Meta | ConvertTo-Json -Depth 3 | Out-File -FilePath $MetaFile -Encoding utf8

# 6. Display Result Summary
Write-Host "`n--------------------------------------------------------" -ForegroundColor Cyan
if ($Status -eq "SUCCESS") {
    Write-Host "  Execution Status: [✓] SUCCESS" -ForegroundColor Green
} elseif ($Status -eq "WARNING") {
    Write-Host "  Execution Status: [⚠️] WARNING ($($WarningLines.Count) warnings)" -ForegroundColor Yellow
} else {
    Write-Host "  Execution Status: [✗] ERROR ($($ErrorLines.Count) errors)" -ForegroundColor Red
}

Write-Host "  Duration: $([math]::Round($DurationSec, 2))s | Exit Code: $($Process.ExitCode)" -ForegroundColor Gray
Write-Host "  Log: $LogFile" -ForegroundColor Cyan
Write-Host "  LST: $LstFile" -ForegroundColor Cyan

if ($ErrorLines.Count -gt 0) {
    Write-Host "`n  [Errors Detected in Log]:" -ForegroundColor Red
    foreach ($err in $ErrorLines | Select-Object -First 5) {
        Write-Host "    $err" -ForegroundColor Red
    }
    if ($ErrorLines.Count -gt 5) {
        Write-Host "    ... ($($ErrorLines.Count - 5) more errors in log)" -ForegroundColor Gray
    }
}

Write-Host "========================================================`n" -ForegroundColor Cyan

exit $(if ($Status -eq "ERROR") { 1 } else { 0 })
