<#
.SYNOPSIS
    01-install-common.ps1 - Install Common Core Developer Tools on Windows 11
.DESCRIPTION
    Installs Windows Terminal, PowerShell 7, Git for Windows, and 7-Zip via WinGet
    with silent flags and license agreement acceptance.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipExisting = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path (Split-Path -Parent $ScriptDir) ".run\logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "install-common.log"

function Log-Message([string]$msg, [string]$color = "White") {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] $msg"
    Write-Host $msg -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logEntry -Encoding utf8
}

Log-Message "========================================================" "Cyan"
Log-Message "  Step 1: Installing Common Developer Tools" "Cyan"
Log-Message "========================================================" "Cyan"

$Packages = @(
    @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal"; Cmd = "wt" },
    @{ Id = "Microsoft.PowerShell"; Name = "PowerShell 7"; Cmd = "pwsh" },
    @{ Id = "Git.Git"; Name = "Git for Windows"; Cmd = "git" },
    @{ Id = "7zip.7zip"; Name = "7-Zip"; Cmd = "7z" }
)

$FailedPackages = @()

foreach ($pkg in $Packages) {
    $id = $pkg.Id
    $name = $pkg.Name
    $cmd = $pkg.Cmd

    # Check if already installed
    $existing = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($existing -and $SkipExisting) {
        Log-Message "  [✓] $name is already installed ($cmd). Skipping." "Green"
        continue
    }

    Log-Message "  [...] Installing $name ($id)..." "Yellow"
    
    $attempts = 0
    $success = $false
    while ($attempts -lt 2 -and -not $success) {
        $attempts++
        try {
            $process = Start-Process -FilePath "winget" `
                -ArgumentList "install", "--id", $id, "--exact", "--source", "winget", "--silent", "--disable-interactivity", "--accept-package-agreements", "--accept-source-agreements" `
                -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                $success = $true
                Log-Message "  [✓] $name installed successfully." "Green"
            } else {
                Log-Message "  [!] Attempt $attempts failed with exit code $($process.ExitCode). Retrying..." "Yellow"
                Start-Sleep -Seconds 3
            }
        } catch {
            Log-Message "  [!] Exception during installation of $name: $_" "Yellow"
            Start-Sleep -Seconds 3
        }
    }

    if (-not $success) {
        Log-Message "  [✗] Failed to install $name ($id)." "Red"
        $FailedPackages += $name
    }
}

# Update Current Session PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

if ($FailedPackages.Count -gt 0) {
    Log-Message "`n[ERROR] The following packages failed to install: $($FailedPackages -join ', ')" "Red"
    Log-Message "Step 1 Failed. Check log at: $LogFile" "Red"
    Log-Message "========================================================`n" "Red"
    exit 1
}

Log-Message "`nStep 1 Complete. Check log at: $LogFile" "Cyan"
Log-Message "========================================================`n" "Cyan"
exit 0
