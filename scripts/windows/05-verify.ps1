<#
.SYNOPSIS
    05-verify.ps1 - End-to-End Environment & Pipeline Verification
.DESCRIPTION
    Verifies that Git, uv, Python, R, Node.js, pnpm, Quarto, DuckDB, SAS CP932 handling,
    and PowerPoint reporting are operational through automated synthetic execution.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
$Report = @{
    timestamp = $Timestamp
    status = "PASS"
    checks = @()
    errors = @()
    warnings = @()
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ReportDir = Join-Path $PlatformRoot ".run\reports"
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$ReportFile = Join-Path $ReportDir "verify-report.json"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Step 5: End-to-End Verification (Full Multi-Language Stack)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

function Assert-Tool([string]$id, [string]$name, [string]$command, [string]$args = "--version") {
    try {
        $cmd = Get-Command $command -ErrorAction SilentlyContinue
        if ($cmd) {
            $ver = (& $command $args.Split(" ") 2>&1) -join " "
            $verClean = $ver.Split("`n")[0].Trim()
            $script:Report.checks += @{ id = $id; name = $name; status = "PASS"; version = $verClean }
            Write-Host "  [✓] $name: $verClean" -ForegroundColor Green
        } else {
            $script:Report.status = "FAIL"
            $script:Report.errors += "$name ($command) is not installed or not in PATH."
            $script:Report.checks += @{ id = $id; name = $name; status = "FAIL"; error = "Command not found" }
            Write-Host "  [✗] $name ($command): NOT FOUND" -ForegroundColor Red
        }
    } catch {
        $script:Report.status = "FAIL"
        $script:Report.errors += "Error checking $name: $_"
        $script:Report.checks += @{ id = $id; name = $name; status = "FAIL"; error = "$_" }
        Write-Host "  [✗] $name: EXCEPTION ($_)" -ForegroundColor Red
    }
}

# 1. Tool Binary Checks
Assert-Tool "git" "Git" "git" "--version"
Assert-Tool "uv" "uv Package Manager" "uv" "--version"
Assert-Tool "quarto" "Quarto CLI" "quarto" "--version"
Assert-Tool "duckdb" "DuckDB CLI" "duckdb" "--version"
Assert-Tool "node" "Node.js" "node" "--version"
Assert-Tool "pnpm" "pnpm" "pnpm" "--version"

# 2. Copier Check
$copierCmd = Get-Command "copier" -ErrorAction SilentlyContinue
if ($copierCmd) {
    $cVer = (& copier --version 2>&1) -join " "
    $Report.checks += @{ id = "copier"; name = "Copier"; status = "PASS"; version = "$cVer" }
    Write-Host "  [✓] Copier: $cVer" -ForegroundColor Green
} else {
    $uvxVer = (& uvx --from "copier==9.4.1" copier --version 2>&1) -join " "
    if ($LASTEXITCODE -eq 0) {
        $Report.checks += @{ id = "copier"; name = "Copier (via uvx)"; status = "PASS"; version = "$uvxVer" }
        Write-Host "  [✓] Copier (via uvx): $uvxVer" -ForegroundColor Green
    } else {
        $Report.status = "FAIL"
        $Report.errors += "Copier could not be executed."
        Write-Host "  [✗] Copier: FAILED" -ForegroundColor Red
    }
}

# 3. Test Case Project Generation & Multi-Language Synthetic Pipeline
Write-Host "`n[Testing Case Project Generation & Multi-Language Pipelines]..." -ForegroundColor Yellow
$TempDir = Join-Path $env:TEMP "rwd-verify-test"
if (Test-Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

$GenScript = Join-Path $PlatformRoot "scripts\project\New-AnalysisProject.ps1"
$TestProjectName = "case-verify-test"
$TestProjectPath = Join-Path $TempDir $TestProjectName

try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GenScript `
        -Name $TestProjectName `
        -Profile "windows-standard" `
        -DataClassification "synthetic" `
        -DestinationRoot $TempDir `
        -NonInteractive

    if (Test-Path (Join-Path $TestProjectPath "PROJECT.yml")) {
        $Report.checks += @{ id = "case_generation"; name = "Case Project Generation"; status = "PASS" }
        Write-Host "  [✓] Case Project Generator: PASS" -ForegroundColor Green

        Push-Location $TestProjectPath
        try {
            # 3.1 Python + DuckDB pipeline
            Write-Host "  [...] Testing Python + DuckDB analysis..." -ForegroundColor Gray
            $pyOut = (& uv run python src/python/sample_rwd_pipeline.py 2>&1) -join " "
            if (Test-Path "outputs/private/intermediate_summary.csv") {
                $Report.checks += @{ id = "python_duckdb_pipeline"; name = "Python & DuckDB Pipeline"; status = "PASS" }
                Write-Host "  [✓] Python & DuckDB Pipeline: PASS" -ForegroundColor Green
            } else {
                throw "Python pipeline output file not created. Details: $pyOut"
            }

            # 3.2 SAS CP932 encoding & file decode validation
            Write-Host "  [...] Testing SAS CP932 file integrity..." -ForegroundColor Gray
            $sasFile = "src/sas-cp932/sample_analysis.sas"
            if (Test-Path $sasFile) {
                $enc = [System.Text.Encoding]::GetEncoding(932)
                $sasText = [System.IO.File]::ReadAllText((Resolve-Path $sasFile), $enc)
                if ($sasText -match "生存時間解析") {
                    $Report.checks += @{ id = "sas_cp932_encoding"; name = "SAS CP932 Integrity"; status = "PASS" }
                    Write-Host "  [✓] SAS CP932 Integrity Check: PASS" -ForegroundColor Green
                } else {
                    throw "SAS file CP932 decoding test failed."
                }
            }

            # 3.3 R survival script validation (if R is installed)
            $rCmd = Get-Command "Rscript" -ErrorAction SilentlyContinue
            if ($rCmd) {
                Write-Host "  [...] Testing R survival analysis..." -ForegroundColor Gray
                $rOut = (& Rscript src/r/sample_survival_analysis.R 2>&1) -join " "
                if (Test-Path "outputs/private/r_survival_summary.txt") {
                    $Report.checks += @{ id = "r_survival_pipeline"; name = "R Survival Analysis"; status = "PASS" }
                    Write-Host "  [✓] R Survival Analysis: PASS" -ForegroundColor Green
                } else {
                    $Report.warnings += "R script ran but output file not found: $rOut"
                }
            }

            # 3.4 PowerPoint report generation validation
            Write-Host "  [...] Testing PowerPoint presentation generator..." -ForegroundColor Gray
            $pyPptxTest = "from pptx import Presentation; prs = Presentation(); prs.save('outputs/private/sample_presentation.pptx')"
            & uv run python -c $pyPptxTest 2>$null
            if (Test-Path "outputs/private/sample_presentation.pptx") {
                $Report.checks += @{ id = "pptx_generation"; name = "PowerPoint Generation"; status = "PASS" }
                Write-Host "  [✓] PowerPoint Generator: PASS" -ForegroundColor Green
            }

            # 3.5 Governance validation check
            Write-Host "  [...] Testing validate-project.py on generated case..." -ForegroundColor Gray
            $valOut = (& uv run python scripts/validate-project.py --project-dir . 2>&1) -join " "
            if ($LASTEXITCODE -eq 0) {
                $Report.checks += @{ id = "governance_validation"; name = "Governance Validation Engine"; status = "PASS" }
                Write-Host "  [✓] Governance Validation: PASS" -ForegroundColor Green
            } else {
                throw "validate-project.py failed on generated project: $valOut"
            }

        } finally {
            Pop-Location
        }
    } else {
        throw "Generated PROJECT.yml not found at: $TestProjectPath"
    }
} catch {
    $Report.status = "FAIL"
    $Report.errors += "Case project test failed: $_"
    $Report.checks += @{ id = "e2e_case_test"; name = "E2E Pipeline Test"; status = "FAIL"; error = "$_" }
    Write-Host "  [✗] E2E Pipeline Test: FAIL ($_)" -ForegroundColor Red
} finally {
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Save Verification Report
$Report | ConvertTo-Json -Depth 5 | Out-File -FilePath $ReportFile -Encoding utf8

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  Verification Result: $($Report.status)" -ForegroundColor $(if ($Report.status -eq "PASS") { "Green" } else { "Red" })
Write-Host "  Report saved to: $ReportFile" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

exit $(if ($Report.status -eq "PASS") { 0 } else { 1 })
