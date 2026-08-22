<#
.SYNOPSIS
    02-install-analysis.ps1 - Install Statistical & RWD Analysis Toolchain on Windows 11
.DESCRIPTION
    Installs uv, Python 3.12, pinned Copier (9.4.1), Quarto CLI, DuckDB CLI,
    and R 4.4 via rig (R Installation Manager).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path (Split-Path -Parent $ScriptDir) ".run\logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "install-analysis.log"

function Log-Message([string]$msg, [string]$color = "White") {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] $msg"
    Write-Host $msg -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logEntry -Encoding utf8
}

Log-Message "========================================================" "Cyan"
Log-Message "  Step 2: Installing Statistical Analysis Toolchain" "Cyan"
Log-Message "========================================================" "Cyan"

$FailedTools = @()

# 1. Install Astral uv
$uvCmd = Get-Command "uv" -ErrorAction SilentlyContinue
if (-not $uvCmd) {
    Log-Message "  [...] Installing Astral uv via WinGet..." "Yellow"
    $proc = Start-Process -FilePath "winget" `
        -ArgumentList "install", "--id", "astral-sh.uv", "--exact", "--source", "winget", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
        -Wait -PassThru -NoNewWindow
    
    if ($proc.ExitCode -ne 0) {
        Log-Message "  [!] WinGet uv install returned $($proc.ExitCode). Fallback to official script..." "Yellow"
        $TempInstaller = Join-Path $env:TEMP "install-uv.ps1"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            Invoke-WebRequest -Uri "https://astral.sh/uv/install.ps1" -OutFile $TempInstaller -UseBasicParsing -TimeoutSec 30
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TempInstaller
        } catch {
            Log-Message "  [!] Fallback installer failed: $_" "Red"
        } finally {
            if (Test-Path $TempInstaller) { Remove-Item -Path $TempInstaller -Force -ErrorAction SilentlyContinue }
        }
    }
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
}

$uvAvailable = Get-Command "uv" -ErrorAction SilentlyContinue
if ($uvAvailable) {
    Log-Message "  [✓] uv: operational ($((& uv --version) 2>$null))" "Green"
} else {
    Log-Message "  [✗] Failed to install uv." "Red"
    $FailedTools += "uv"
}

# 2. Install Python 3.12 via uv
if ($uvAvailable) {
    Log-Message "  [...] Setting up Python 3.12 via uv..." "Yellow"
    & uv python install 3.12
    if ($LASTEXITCODE -eq 0) {
        Log-Message "  [✓] Python 3.12 installed." "Green"
    } else {
        Log-Message "  [✗] Failed to install Python 3.12 via uv." "Red"
        $FailedTools += "Python 3.12"
    }

    # 3. Install Pinned Global Tools via uv tool
    Log-Message "  [...] Installing pinned Copier (9.4.1), Ruff, and pre-commit..." "Yellow"
    & uv tool install "copier==9.4.1" --force | Out-Null
    & uv tool install "ruff" --force | Out-Null
    & uv tool install "pre-commit" --force | Out-Null
    Log-Message "  [✓] Copier (9.4.1), Ruff, and pre-commit installed via uv tool." "Green"
}

# 4. Install Quarto CLI
$quartoCmd = Get-Command "quarto" -ErrorAction SilentlyContinue
if (-not $quartoCmd) {
    Log-Message "  [...] Installing Quarto CLI..." "Yellow"
    $proc = Start-Process -FilePath "winget" `
        -ArgumentList "install", "--id", "Posit.Quarto", "--exact", "--source", "winget", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
        -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Log-Message "  [✓] Quarto CLI installed." "Green"
    } else {
        Log-Message "  [✗] Failed to install Quarto CLI." "Red"
        $FailedTools += "Quarto"
    }
} else {
    Log-Message "  [✓] Quarto CLI is already installed." "Green"
}

# 5. Install DuckDB CLI
$duckdbCmd = Get-Command "duckdb" -ErrorAction SilentlyContinue
if (-not $duckdbCmd) {
    Log-Message "  [...] Installing DuckDB CLI..." "Yellow"
    $proc = Start-Process -FilePath "winget" `
        -ArgumentList "install", "--id", "DuckDB.cli", "--exact", "--source", "winget", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
        -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Log-Message "  [✓] DuckDB CLI installed." "Green"
    } else {
        Log-Message "  [✗] Failed to install DuckDB CLI." "Red"
        $FailedTools += "DuckDB"
    }
} else {
    Log-Message "  [✓] DuckDB CLI is already installed." "Green"
}

# 6. Install rig (R Installation Manager) & R
$rigCmd = Get-Command "rig" -ErrorAction SilentlyContinue
if (-not $rigCmd) {
    Log-Message "  [...] Installing rig (R Manager)..." "Yellow"
    $proc = Start-Process -FilePath "winget" `
        -ArgumentList "install", "--id", "RProject.rig", "--exact", "--source", "winget", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
        -Wait -PassThru -NoNewWindow
}

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$rigAvailable = Get-Command "rig" -ErrorAction SilentlyContinue
if ($rigAvailable) {
    Log-Message "  [...] Adding R 4.4 and Rtools via rig..." "Yellow"
    & rig add 4.4.1 | Out-Null
    & rig add-rtools 4.4 | Out-Null
    Log-Message "  [✓] R 4.4.1 and Rtools installed via rig." "Green"
} else {
    Log-Message "  [✗] rig command not found. Please install R 4.4 manually." "Red"
    $FailedTools += "R / rig"
}

if ($FailedTools.Count -gt 0) {
    Log-Message "`n[ERROR] The following analysis tools failed to install: $($FailedTools -join ', ')" "Red"
    Log-Message "Step 2 Failed. Check log at: $LogFile" "Red"
    Log-Message "========================================================`n" "Red"
    exit 1
}

Log-Message "`nStep 2 Complete. Check log at: $LogFile" "Cyan"
Log-Message "========================================================`n" "Cyan"
exit 0
