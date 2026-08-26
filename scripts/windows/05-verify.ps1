<#
.SYNOPSIS
    05-verify.ps1 - End-to-End Environment & Pipeline Verification
.DESCRIPTION
    Verifies that Git, uv, Python, R, Node.js, pnpm, Quarto, DuckDB, SAS CP932 handling,
    and PowerPoint reporting are operational through automated synthetic execution.
    NOTE: Do not name parameters $args (PowerShell automatic variable) — that drops
    "--version" and can launch interactive CLIs (e.g. duckdb) which hang the setup.
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

function Invoke-ToolCapture {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutSec = 30,
        [string]$ProgressLabel = ""
    )
    # Strict exit-code capture via PowerShell call operator + $LASTEXITCODE.
    # Do not map missing codes to 0. Do not soft-pass on stdout text.
    $argList = @($ArgumentList)
    if ($TimeoutSec -gt 0 -and $ProgressLabel -ne "") {
        $job = Start-Job -ScriptBlock {
            param($Exe, $JobArgs, $WorkDir)
            Set-Location -LiteralPath $WorkDir
            $output = & $Exe @JobArgs 2>&1 | ForEach-Object { "$_" }
            $code = $LASTEXITCODE
            if ($null -eq $code) {
                throw "LASTEXITCODE unavailable after running: $Exe"
            }
            [pscustomobject]@{
                ExitCode = [int]$code
                Output   = (($output | Where-Object { $_ -ne $null }) -join " ").Trim()
            }
        } -ArgumentList $FilePath, $argList, ((Get-Location).Path)

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($job.State -eq "Running") {
            if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) {
                Stop-Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                throw "Timed out after ${TimeoutSec}s (possible interactive CLI hang)."
            }
            $sec = [int]$sw.Elapsed.TotalSeconds
            if ($sec -gt 0 -and ($sec % 15) -eq 0) {
                Write-Host "      ... still running: $ProgressLabel (${sec}s)" -ForegroundColor DarkGray
                Start-Sleep -Milliseconds 1100
            }
            Start-Sleep -Milliseconds 400
        }
        if ($job.State -ne "Completed") {
            $err = Receive-Job $job -ErrorAction SilentlyContinue | Out-String
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            throw "Background tool job failed ($($job.State)): $err"
        }
        $result = Receive-Job $job
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        if ($null -eq $result -or $null -eq $result.ExitCode) {
            throw "Tool job returned no exit code: $FilePath"
        }
        return @{
            ExitCode = [int]$result.ExitCode
            Output   = [string]$result.Output
        }
    }

    $output = & $FilePath @argList 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    if ($null -eq $code) {
        throw "LASTEXITCODE unavailable after running: $FilePath"
    }
    return @{
        ExitCode = [int]$code
        Output   = (($output | Where-Object { $_ -ne $null }) -join " ").Trim()
    }
}

function Resolve-NativeCommandPath {
    param([Parameter(Mandatory = $true)][string]$CommandName)
    # Prefer real Win32 entrypoints. On Windows, Get-Command may return
    # extensionless Node shims or *.ps1 first; Process.Start cannot run those.
    $all = @(Get-Command $CommandName -All -ErrorAction SilentlyContinue)
    $preferred = $all | Where-Object {
        $_.CommandType -eq 'Application' -and $_.Source -match '\.(exe|cmd|bat)$'
    } | Select-Object -First 1
    if ($preferred) { return $preferred.Source }

    $app = $all | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
    if ($app) { return $app.Source }

    $any = $all | Select-Object -First 1
    if ($any) { return $any.Source }
    return $null
}

function Assert-Tool {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Command,
        # NEVER name this $args — that is a PowerShell automatic variable.
        [string[]]$VersionArgs = @("--version"),
        [int]$TimeoutSec = 30
    )
    try {
        $resolved = Resolve-NativeCommandPath -CommandName $Command
        if (-not $resolved) {
            $script:Report.status = "FAIL"
            $script:Report.errors += "$Name ($Command) is not installed or not in PATH."
            $script:Report.checks += @{ id = $Id; name = $Name; status = "FAIL"; error = "Command not found" }
            Write-Host "  [x] $Name ($Command): NOT FOUND" -ForegroundColor Red
            return
        }

        $result = Invoke-ToolCapture -FilePath $resolved -ArgumentList $VersionArgs -TimeoutSec $TimeoutSec
        if ($result.ExitCode -ne 0) {
            throw "Command exited $($result.ExitCode). Output: $($result.Output)"
        }
        $verClean = ($result.Output -split "[\r\n]+" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
        if (-not $verClean) { $verClean = "(exit $($result.ExitCode))" }

        $script:Report.checks += @{ id = $Id; name = $Name; status = "PASS"; version = $verClean; path = $resolved }
        Write-Host "  [OK] ${Name}: $verClean" -ForegroundColor Green
    } catch {
        $script:Report.status = "FAIL"
        $script:Report.errors += "Error checking ${Name}: $_"
        $script:Report.checks += @{ id = $Id; name = $Name; status = "FAIL"; error = "$_" }
        Write-Host "  [x] ${Name}: EXCEPTION ($_)" -ForegroundColor Red
    }
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Step 5: End-to-End Verification (Full Multi-Language Stack)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Refresh PATH for tools installed earlier in the same setup session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "Machine")
foreach ($extra in @(
    "${env:ProgramFiles}\7-Zip",
    "${env:ProgramFiles}\DuckDB",
    "${env:LOCALAPPDATA}\Microsoft\WinGet\Links"
)) {
    if ((Test-Path $extra) -and ($env:Path -notlike "*$extra*")) {
        $env:Path = "$extra;$env:Path"
    }
}

# 1. Tool Binary Checks (non-interactive version probes only)
Assert-Tool -Id "git" -Name "Git" -Command "git" -VersionArgs @("--version")
Assert-Tool -Id "uv" -Name "uv Package Manager" -Command "uv" -VersionArgs @("--version")
Assert-Tool -Id "quarto" -Name "Quarto CLI" -Command "quarto" -VersionArgs @("--version")
Assert-Tool -Id "duckdb" -Name "DuckDB CLI" -Command "duckdb" -VersionArgs @("--version")
Assert-Tool -Id "node" -Name "Node.js" -Command "node" -VersionArgs @("--version")
Assert-Tool -Id "pnpm" -Name "pnpm" -Command "pnpm" -VersionArgs @("--version")

# 2. Copier Check
$copierCmd = Get-Command "copier" -ErrorAction SilentlyContinue
if ($copierCmd) {
    $cRes = Invoke-ToolCapture -FilePath $copierCmd.Source -ArgumentList @("--version")
    $cVer = $cRes.Output
    $Report.checks += @{ id = "copier"; name = "Copier"; status = "PASS"; version = "$cVer" }
    Write-Host "  [OK] Copier: $cVer" -ForegroundColor Green
} else {
    $uvCmd = Get-Command "uv" -ErrorAction SilentlyContinue
    $uvxCmd = Get-Command "uvx" -ErrorAction SilentlyContinue
    $uvxExe = if ($uvxCmd) { $uvxCmd.Source } elseif ($uvCmd) { $uvCmd.Source } else { $null }
    if ($uvxExe) {
        $uvxArgs = if ($uvxCmd) {
            @("--from", "copier==9.4.1", "copier", "--version")
        } else {
            @("tool", "run", "--from", "copier==9.4.1", "copier", "--version")
        }
        $uvxRes = Invoke-ToolCapture -FilePath $uvxExe -ArgumentList $uvxArgs -TimeoutSec 120
        if ($uvxRes.ExitCode -eq 0) {
            $Report.checks += @{ id = "copier"; name = "Copier (via uvx)"; status = "PASS"; version = $uvxRes.Output }
            Write-Host "  [OK] Copier (via uvx): $($uvxRes.Output)" -ForegroundColor Green
        } else {
            $Report.status = "FAIL"
            $Report.errors += "Copier could not be executed."
            Write-Host "  [x] Copier: FAILED" -ForegroundColor Red
        }
    } else {
        $Report.status = "FAIL"
        $Report.errors += "Copier could not be executed (uv/uvx missing)."
        Write-Host "  [x] Copier: FAILED" -ForegroundColor Red
    }
}

# 3. Test Case Project Generation & Multi-Language Synthetic Pipeline
Write-Host "`n[Testing Case Project Generation & Multi-Language Pipelines]..." -ForegroundColor Yellow
$TempDir = Join-Path $env:TEMP "rwd-verify-test"
if (Test-Path $TempDir) {
    try {
        # Clear read-only / locked leftovers from prior Cursor launches
        Get-ChildItem -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Attributes = 'Normal' }
    } catch { }
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    if (Test-Path $TempDir) {
        $stamp = Get-Date -Format "yyyyMMddHHmmss"
        $TempDir = Join-Path $env:TEMP "rwd-verify-test-$stamp"
        Write-Host "  [!] Prior temp dir locked; using $TempDir" -ForegroundColor Yellow
    }
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
        Write-Host "  [OK] Case Project Generator: PASS" -ForegroundColor Green

        Push-Location $TestProjectPath
        try {
            # 3.1 Python + DuckDB pipeline
            # Use --no-project + explicit --with to avoid syncing the full pyproject
            # (polars/pyarrow/jupyterlab etc. can hang the first run for many minutes).
            Write-Host "  [...] Testing Python + DuckDB analysis..." -ForegroundColor Gray
            Write-Host "      (lightweight: uv --no-project --with duckdb --with pandas)" -ForegroundColor DarkGray
            $uv = (Get-Command "uv").Source
            $pyRes = Invoke-ToolCapture -FilePath $uv -ArgumentList @(
                "run", "--no-project",
                "--with", "duckdb",
                "--with", "pandas",
                "python", "src/python/sample_rwd_pipeline.py"
            ) -TimeoutSec 180 -ProgressLabel "python+duckdb pipeline"
            $pyOut = $pyRes.Output
            if (Test-Path "outputs/private/intermediate_summary.csv") {
                $Report.checks += @{ id = "python_duckdb_pipeline"; name = "Python & DuckDB Pipeline"; status = "PASS" }
                Write-Host "  [OK] Python & DuckDB Pipeline: PASS" -ForegroundColor Green
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
                    Write-Host "  [OK] SAS CP932 Integrity Check: PASS" -ForegroundColor Green
                } else {
                    throw "SAS file CP932 decoding test failed."
                }
            }

            # 3.3 R survival script validation (if R is installed)
            $rCmd = Get-Command "Rscript" -ErrorAction SilentlyContinue
            if ($rCmd) {
                Write-Host "  [...] Testing R survival analysis..." -ForegroundColor Gray
                $rRes = Invoke-ToolCapture -FilePath $rCmd.Source -ArgumentList @("src/r/sample_survival_analysis.R") -TimeoutSec 300
                $rOut = $rRes.Output
                if (Test-Path "outputs/private/r_survival_summary.txt") {
                    $Report.checks += @{ id = "r_survival_pipeline"; name = "R Survival Analysis"; status = "PASS" }
                    Write-Host "  [OK] R Survival Analysis: PASS" -ForegroundColor Green
                } else {
                    $Report.warnings += "R script ran but output file not found: $rOut"
                }
            }

            # 3.4 PowerPoint report generation validation
            Write-Host "  [...] Testing PowerPoint presentation generator..." -ForegroundColor Gray
            $pyPptxTest = "from pptx import Presentation; prs = Presentation(); prs.save('outputs/private/sample_presentation.pptx')"
            $pptxRes = Invoke-ToolCapture -FilePath $uv -ArgumentList @(
                "run", "--no-project", "--with", "python-pptx",
                "python", "-c", $pyPptxTest
            ) -TimeoutSec 120 -ProgressLabel "python-pptx"
            if (($pptxRes.ExitCode -eq 0) -and (Test-Path "outputs/private/sample_presentation.pptx")) {
                $Report.checks += @{ id = "pptx_generation"; name = "PowerPoint Generation"; status = "PASS" }
                Write-Host "  [OK] PowerPoint Generator: PASS" -ForegroundColor Green
            } else {
                throw "PowerPoint generation failed (exit=$($pptxRes.ExitCode)): $($pptxRes.Output)"
            }

            # 3.5 Governance validation check
            Write-Host "  [...] Testing validate-project.py on generated case..." -ForegroundColor Gray
            $SchemaPath = Join-Path $PlatformRoot "schemas\project.schema.json"
            if (-not (Test-Path -LiteralPath $SchemaPath)) {
                throw "Platform schema not found at: $SchemaPath"
            }
            $valRes = Invoke-ToolCapture -FilePath $uv -ArgumentList @(
                "run", "--no-project",
                "--with", "jsonschema", "--with", "pyyaml",
                "python", "scripts/validate-project.py",
                "--project-dir", ".",
                "--schema", $SchemaPath
            ) -TimeoutSec 120 -ProgressLabel "validate-project"
            $valOut = $valRes.Output
            # Strict criterion: process exit code only (validate-project.py returns 0=PASS, 1=FAIL).
            # Do not soften with output-text matching.
            if ($valRes.ExitCode -eq 0) {
                $Report.checks += @{ id = "governance_validation"; name = "Governance Validation Engine"; status = "PASS"; exit_code = $valRes.ExitCode }
                Write-Host "  [OK] Governance Validation: PASS (exit=$($valRes.ExitCode))" -ForegroundColor Green
            } else {
                throw "validate-project.py failed on generated project (exit=$($valRes.ExitCode)): $valOut"
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
    Write-Host "  [x] E2E Pipeline Test: FAIL ($_)" -ForegroundColor Red
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
