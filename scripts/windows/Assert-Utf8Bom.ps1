<#
.SYNOPSIS
    Assert-Utf8Bom.ps1 - Validate UTF-8 text and legacy Windows PowerShell BOM requirements
.DESCRIPTION
    Windows PowerShell 5.1 mis-parses UTF-8 without BOM as system ANSI (CP932 on ja-JP).
    Require BOM for legacy Windows setup entrypoints; allow BOM-less UTF-8 for modern PowerShell project scripts.
    Validate all targets using strict UTF-8 decoding.
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
    $rel = $path.Substring($Root.Length).TrimStart('\\', '/')
    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    try {
        $null = $utf8.GetString($bytes)
    } catch [System.Text.DecoderFallbackException] {
        Write-Host "[FAIL] $rel (invalid UTF-8)" -ForegroundColor Red
        $Failed += $rel
        continue
    }
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $requiresBom = ($path -ne (Join-Path $Root "scripts\project\New-AnalysisProject.ps1"))
    if (-not $requiresBom -or $hasBom) {
        Write-Host "[OK] $rel (valid UTF-8$(if ($hasBom) { ', BOM' } else { ', no BOM' }))"
    } else {
        Write-Host "[FAIL] $rel (UTF-8 BOM required for Windows PowerShell 5.1)" -ForegroundColor Red
        $Failed += $rel
    }
}

if ($Failed.Count -gt 0) {
    Write-Host "`nAssert-Utf8Bom FAILED ($($Failed.Count) file(s))." -ForegroundColor Red
    exit 1
}

Write-Host "`nAssert-Utf8Bom PASSED." -ForegroundColor Green
exit 0
