<#
.SYNOPSIS
    03-install-reporting.ps1 - Install Reporting & Slidev/PPTX Stack
.DESCRIPTION
    Installs Node.js LTS and pnpm, and configures global/project tooling for Slidev and PptxGenJS.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) ".run\logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "install-reporting.log"

function Log-Message([string]$msg, [string]$color = "White") {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] $msg"
    Write-Host $msg -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logEntry -Encoding utf8
}

Log-Message "========================================================" "Cyan"
Log-Message "  Step 3: Installing Reporting & Slidev/PPTX Stack" "Cyan"
Log-Message "========================================================" "Cyan"

$FailedTools = @()

# 1. Install Node.js LTS
$nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Log-Message "  [...] Installing Node.js LTS via WinGet..." "Yellow"
    $proc = Start-Process -FilePath "winget" `
        -ArgumentList "install", "--id", "OpenJS.NodeJS.LTS", "--exact", "--source", "winget", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
        -Wait -PassThru -NoNewWindow
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

$nodeAvailable = Get-Command "node" -ErrorAction SilentlyContinue
if ($nodeAvailable) {
    $nodeVer = (& node --version) 2>$null
    Log-Message "  [✓] Node.js: operational ($nodeVer)" "Green"
} else {
    Log-Message "  [✗] Failed to install Node.js LTS." "Red"
    $FailedTools += "Node.js"
}

# 2. Enable pnpm via Corepack or npm
$pnpmCmd = Get-Command "pnpm" -ErrorAction SilentlyContinue
if (-not $pnpmCmd) {
    Log-Message "  [...] Enabling pnpm via corepack..." "Yellow"
    try {
        & corepack enable pnpm 2>$null
    } catch {
        Log-Message "  [INFO] Corepack failed, installing pnpm globally via npm..." "Yellow"
        & npm install -g pnpm 2>$null
    }
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

$pnpmAvailable = Get-Command "pnpm" -ErrorAction SilentlyContinue
if ($pnpmAvailable) {
    $pnpmVer = (& pnpm --version) 2>$null
    Log-Message "  [✓] pnpm: operational ($pnpmVer)" "Green"
} else {
    Log-Message "  [✗] Failed to enable/install pnpm." "Red"
    $FailedTools += "pnpm"
}

# 3. Install/Verify TypeScript & Global Slidev CLI support
$GlobalCommands = @("slidev", "tsc", "ts-node")
$MissingGlobalCommands = @($GlobalCommands | Where-Object {
    -not (Get-Command $_ -ErrorAction SilentlyContinue)
})
if ($MissingGlobalCommands.Count -eq 0) {
    Log-Message "  [✓] Slidev, TypeScript, and ts-node already available; skipping global reinstall." "Green"
} else {
    Log-Message "  [...] Installing missing reporting tools ($($MissingGlobalCommands -join ', '))..." "Yellow"
    & pnpm add -g @slidev/cli @slidev/theme-default typescript ts-node 2>$null
    if ($LASTEXITCODE -ne 0) {
        Log-Message "  [✗] Global reporting tool installation failed (exit $LASTEXITCODE)." "Red"
        $FailedTools += "Slidev/TypeScript"
    } else {
        Log-Message "  [✓] Slidev & TypeScript tooling installed." "Green"
    }
}

if ($FailedTools.Count -gt 0) {
    Log-Message "`n[ERROR] The following reporting tools failed to install: $($FailedTools -join ', ')" "Red"
    Log-Message "Step 3 Failed. Check log at: $LogFile" "Red"
    Log-Message "========================================================`n" "Red"
    exit 1
}

Log-Message "`nStep 3 Complete. Check log at: $LogFile" "Cyan"
Log-Message "========================================================`n" "Cyan"
exit 0
