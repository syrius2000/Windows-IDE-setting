<#
.SYNOPSIS
    02-install-analysis.ps1 - Install Statistical & RWD Analysis Toolchain on Windows 11
.DESCRIPTION
    Installs uv, Python 3.12, pinned Copier (9.4.1), Quarto CLI, DuckDB CLI,
    and R 4.6.1 from the official CRAN Windows installer; optionally adds Rtools via rig.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) ".run\logs"
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

# 6. Install R 4.6.1 from the official CRAN Windows installer
# CRAN URL is intentionally pinned so the installed R version is reproducible.
$RVersion = "4.6.1"
$RInstallerUrl = "https://cran.r-project.org/bin/windows/base/R-4.6.1-win.exe"
$RInstallDir = Join-Path $env:ProgramFiles "R\\R-$RVersion"
$RBinDir = Join-Path $RInstallDir "bin"
$RExe = Join-Path $RBinDir "R.exe"
$RscriptExe = Join-Path $RBinDir "Rscript.exe"

if (-not (Test-Path -LiteralPath $RExe)) {
    $RInstaller = Join-Path $env:TEMP "R-$RVersion-win.exe"
    try {
        Log-Message "  [...] Downloading R $RVersion from official CRAN..." "Yellow"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $RInstallerUrl -OutFile $RInstaller -UseBasicParsing -TimeoutSec 180
        if (-not (Test-Path -LiteralPath $RInstaller) -or ((Get-Item -LiteralPath $RInstaller).Length -lt 1MB)) {
            throw "CRAN R installer was not downloaded completely."
        }
        Log-Message "  [...] Installing R $RVersion silently..." "Yellow"
        $rProc = Start-Process -FilePath $RInstaller -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait -PassThru
        if ($rProc.ExitCode -ne 0 -and $rProc.ExitCode -ne 3010) {
            throw "R installer exited with code $($rProc.ExitCode)"
        }
    } catch {
        Log-Message "  [✗] R $RVersion installation failed: $_" "Red"
        $FailedTools += "R $RVersion"
    } finally {
        if (Test-Path -LiteralPath $RInstaller) {
            Remove-Item -LiteralPath $RInstaller -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Log-Message "  [✓] R $RVersion is already installed ($RExe)." "Green"
}

if (Test-Path -LiteralPath $RBinDir) {
    if ($env:Path -notlike "*$RBinDir*") { $env:Path = "$RBinDir;$env:Path" }
    if (Test-Path -LiteralPath $RscriptExe) {
        Log-Message "  [✓] R $RVersion is operational ($RscriptExe)." "Green"
    } else {
        Log-Message "  [✗] Rscript.exe was not found after installing R $RVersion." "Red"
        $FailedTools += "R $RVersion"
    }
} else {
    Log-Message "  [✗] R installation directory not found: $RInstallDir" "Red"
    $FailedTools += "R $RVersion"
}

# 7. Optional Rtools installation through rig (R itself does not depend on rig).
function Refresh-SessionPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $extra = @(
        "${env:ProgramFiles}\\Rig",
        "${env:LOCALAPPDATA}\\Programs\\Rig",
        "${env:USERPROFILE}\\.local\\bin"
    ) | Where-Object { Test-Path $_ }
    foreach ($p in $extra) {
        if ($env:Path -notlike "*$p*") { $env:Path = "$p;$env:Path" }
    }
}

$rigCmd = Get-Command "rig" -ErrorAction SilentlyContinue
if ($rigCmd) {
    Log-Message "  [...] Adding matching Rtools via rig..." "Yellow"
    & rig add rtools
    if ($LASTEXITCODE -ne 0) {
        Log-Message "  [!] rig add rtools returned $LASTEXITCODE (R itself is already operational)." "Yellow"
    } else {
        Log-Message "  [✓] Rtools installed via rig." "Green"
    }
} else {
    Log-Message "  [i] rig not found; skipping optional Rtools installation." "Gray"
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
