<#
.SYNOPSIS
    00-diagnose.ps1 - Windows 11 Environment & Hardware Diagnostic Script
.DESCRIPTION
    Non-destructively inspects OS, CPU, RAM, GPU, VRAM, disk space, Admin privileges,
    PowerShell version, WinGet status, and outputs structured JSON to .run/reports/diagnose-report.json
    and .run/diagnose-report.json.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
$Report = @{
    timestamp = $Timestamp
    environment = "windows-standard"
    status = "PASS"
    checks = @()
    hardware = @{}
    errors = @()
    warnings = @()
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Windows 11 Environment Diagnostic" -ForegroundColor Cyan
Write-Host "  Time: $Timestamp" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Administrator Privilege Check
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($IsAdmin) {
    $Report.checks += @{ id = "admin_privilege"; name = "Administrator Rights"; status = "PASS"; message = "Running with elevated administrator privileges" }
    Write-Host "  [✓] Administrator Rights: PASS" -ForegroundColor Green
} else {
    $Report.status = "WARN"
    $Report.warnings += "Running as standard user. Some installations may require elevation."
    $Report.checks += @{ id = "admin_privilege"; name = "Administrator Rights"; status = "WARN"; message = "Standard user privileges detected" }
    Write-Host "  [⚠️] Administrator Rights: WARN (Standard user)" -ForegroundColor Yellow
}

# 2. OS Version & Architecture
$OS = Get-CimInstance Win32_OperatingSystem
$Arch = $env:PROCESSOR_ARCHITECTURE
$Report.hardware.os_caption = $OS.Caption
$Report.hardware.os_version = $OS.Version
$Report.hardware.os_build = $OS.BuildNumber
$Report.hardware.architecture = $Arch

Write-Host "  [✓] OS: $($OS.Caption) (Build $($OS.BuildNumber), $Arch)" -ForegroundColor Green

# 3. CPU & RAM
$CPU = Get-CimInstance Win32_Processor | Select-Object -First 1
$TotalRAM_GB = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 1)
$FreeRAM_GB = [math]::Round($OS.FreePhysicalMemory / 1MB, 1)

$Report.hardware.cpu = $CPU.Name
$Report.hardware.total_ram_gb = $TotalRAM_GB
$Report.hardware.free_ram_gb = $FreeRAM_GB

Write-Host "  [✓] CPU: $($CPU.Name)" -ForegroundColor Green
Write-Host "  [✓] RAM: $TotalRAM_GB GB Total ($FreeRAM_GB GB Free)" -ForegroundColor Green

# 4. Storage Space
$SystemDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
$FreeSpaceGB = [math]::Round($SystemDrive.Free / 1GB, 1)
$Report.hardware.c_drive_free_gb = $FreeSpaceGB

if ($FreeSpaceGB -ge 20) {
    $Report.checks += @{ id = "storage"; name = "Free Storage Space"; status = "PASS"; free_gb = $FreeSpaceGB }
    Write-Host "  [✓] Free Storage (C:): $FreeSpaceGB GB (PASS)" -ForegroundColor Green
} else {
    $Report.status = "WARN"
    $Report.warnings += "Low disk space on C: ($FreeSpaceGB GB). Recommended: >= 20 GB."
    $Report.checks += @{ id = "storage"; name = "Free Storage Space"; status = "WARN"; free_gb = $FreeSpaceGB }
    Write-Host "  [⚠️] Free Storage (C:): $FreeSpaceGB GB (Low space)" -ForegroundColor Yellow
}

# 5. GPU & VRAM
$GPUs = Get-CimInstance Win32_VideoController
$Report.hardware.gpus = @()
foreach ($g in $GPUs) {
    $AdapterRAM_GB = if ($g.AdapterRAM) { [math]::Round($g.AdapterRAM / 1GB, 1) } else { 0 }
    $Report.hardware.gpus += @{ name = $g.Name; vram_gb = $AdapterRAM_GB; driver = $g.DriverVersion }
    Write-Host "  [i] GPU: $($g.Name) (VRAM: $AdapterRAM_GB GB)" -ForegroundColor Gray
}

# 6. PowerShell Version & ExecutionPolicy
$PSVer = $PSVersionTable.PSVersion.ToString()
$ExecPolicy = (Get-ExecutionPolicy).ToString()
$Report.hardware.powershell_version = $PSVer
$Report.hardware.execution_policy = $ExecPolicy

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $Report.checks += @{ id = "powershell"; name = "PowerShell 7+"; status = "PASS"; version = $PSVer }
    Write-Host "  [✓] PowerShell: $PSVer (PASS)" -ForegroundColor Green
} else {
    $Report.checks += @{ id = "powershell"; name = "PowerShell 7+"; status = "WARN"; version = $PSVer; message = "PowerShell 7 will be installed" }
    Write-Host "  [i] PowerShell: $PSVer (PS7 recommended)" -ForegroundColor Gray
}

# 7. WinGet Check
$WinGetCmd = Get-Command "winget" -ErrorAction SilentlyContinue
if ($WinGetCmd) {
    $WinGetVer = (& winget --version) 2>$null
    $Report.checks += @{ id = "winget"; name = "WinGet Package Manager"; status = "PASS"; version = "$WinGetVer" }
    Write-Host "  [✓] WinGet: $WinGetVer (PASS)" -ForegroundColor Green
} else {
    $Report.status = "WARN"
    $Report.warnings += "WinGet not found. Please install App Installer from Microsoft Store or https://aka.ms/getwinget"
    $Report.checks += @{ id = "winget"; name = "WinGet Package Manager"; status = "WARN"; message = "Not found" }
    Write-Host "  [⚠️] WinGet: 未検出 (Microsoft Store から「アプリ インストーラー」を導入、または https://aka.ms/getwinget より入手してください)" -ForegroundColor Yellow
}

# 8. Output Report JSON (to both .run/reports/diagnose-report.json and .run/diagnose-report.json)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $PlatformRoot ".run\reports"
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$ReportFile1 = Join-Path $OutputDir "diagnose-report.json"
$ReportFile2 = Join-Path (Join-Path $PlatformRoot ".run") "diagnose-report.json"

$ReportJson = $Report | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($ReportFile1, $ReportJson, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($ReportFile2, $ReportJson, [System.Text.Encoding]::UTF8)

Write-Host "`nDiagnostic report saved to: $ReportFile1" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

exit 0
