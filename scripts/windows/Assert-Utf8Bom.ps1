<#
.SYNOPSIS
    Assert-Utf8Bom.ps1 - Fail if Windows setup scripts lack UTF-8 BOM
.DESCRIPTION
    Windows PowerShell 5.1 mis-parses UTF-8 without BOM as system ANSI (CP932 on ja-JP).
    Run this before commit/push when editing scripts on macOS.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Targets = @(
    (Join-Path $Root "Setup-Windows.bat")
) + @(Get-ChildItem (Join-Path $Root "scripts\windows\*.ps1")).FullName + @(
    (Join-Path $Root "scripts\project\New-AnalysisProject.ps1")
)

$Failed = @()
foreach ($path in $Targets) {
    if (-not (Test-Path -LiteralPath $path)) {
        $Failed += "missing: $path"
        continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $rel = $path.Substring($Root.Length).TrimStart('\', '/')
    if ($hasBom) {
        Write-Host "[OK] $rel"
    } else {
        Write-Host "[FAIL] $rel (UTF-8 BOM required)" -ForegroundColor Red
        $Failed += $rel
    }
}

if ($Failed.Count -gt 0) {
    Write-Host "`nAssert-Utf8Bom FAILED ($($Failed.Count) file(s))." -ForegroundColor Red
    exit 1
}

Write-Host "`nAssert-Utf8Bom PASSED." -ForegroundColor Green
exit 0
