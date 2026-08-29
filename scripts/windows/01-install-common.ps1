<#
.SYNOPSIS
    01-install-common.ps1 - Install Common Core Developer Tools on Windows 11
.DESCRIPTION
    Installs Windows Terminal, PowerShell 7, Git for Windows, 7-Zip, and Gitleaks via WinGet
    with silent flags and license agreement acceptance.
    Treats "already installed / no upgrade" WinGet codes as success, and detects
    tools by PATH plus common install directories (7-Zip is often not on PATH).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipExisting = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) ".run\logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "install-common.log"

function Log-Message([string]$msg, [string]$color = "White") {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] $msg"
    Write-Host $msg -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logEntry -Encoding utf8
}

function Refresh-SessionPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Find-ToolPath {
    param(
        [Parameter(Mandatory = $true)][string]$CommandName,
        [string[]]$CandidatePaths = @()
    )
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in $CandidatePaths) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    return $null
}

function Test-WingetSuccess([int]$ExitCode) {
    # 0 = success, 3010 = success reboot required
    # -1978335189 (0x8A15002B) = already installed / no applicable upgrade
    # -1978335135 (0x8A150061) = another install in progress sometimes mapped differently; keep known-good only
    return ($ExitCode -eq 0 -or $ExitCode -eq 3010 -or $ExitCode -eq -1978335189)
}

Log-Message "========================================================" "Cyan"
Log-Message "  Step 1: Installing Common Developer Tools" "Cyan"
Log-Message "========================================================" "Cyan"

Refresh-SessionPath

$Packages = @(
    @{
        Id = "Microsoft.WindowsTerminal"
        Name = "Windows Terminal"
        Cmd = "wt"
        Candidates = @()
    },
    @{
        Id = "Microsoft.PowerShell"
        Name = "PowerShell 7"
        Cmd = "pwsh"
        Candidates = @(
            "${env:ProgramFiles}\PowerShell\7\pwsh.exe"
        )
    },
    @{
        Id = "Git.Git"
        Name = "Git for Windows"
        Cmd = "git"
        Candidates = @(
            "${env:ProgramFiles}\Git\cmd\git.exe"
        )
    },
    @{
        Id = "7zip.7zip"
        Name = "7-Zip"
        Cmd = "7z"
        Candidates = @(
            "${env:ProgramFiles}\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        )
        # Convenience only for archive ops; not required for Python/R analysis core.
        Optional = $true
    },
    @{
        Id = "Gitleaks.Gitleaks"
        Name = "Gitleaks"
        Cmd = "gitleaks"
        Candidates = @(
            "${env:LOCALAPPDATA}\Microsoft\WinGet\Links\gitleaks.exe"
        )
        # Secret scanning for pre-commit; failure is non-fatal for core analysis setup.
        Optional = $true
    }
)

$FailedPackages = @()

foreach ($pkg in $Packages) {
    $id = $pkg.Id
    $name = $pkg.Name
    $cmd = $pkg.Cmd
    $candidates = @($pkg.Candidates)
    $optional = $false
    if ($pkg.ContainsKey("Optional")) { $optional = [bool]$pkg.Optional }

    $existingPath = Find-ToolPath -CommandName $cmd -CandidatePaths $candidates
    if ($existingPath -and $SkipExisting) {
        $dir = Split-Path -Parent $existingPath
        if ($env:Path -notlike "*$dir*") { $env:Path = "$dir;$env:Path" }
        Log-Message "  [✓] $name is already installed ($existingPath). Skipping." "Green"
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

            Refresh-SessionPath
            $foundAfter = Find-ToolPath -CommandName $cmd -CandidatePaths $candidates

            if ((Test-WingetSuccess -ExitCode $process.ExitCode) -or $foundAfter) {
                $success = $true
                if ($foundAfter) {
                    $dir = Split-Path -Parent $foundAfter
                    if ($env:Path -notlike "*$dir*") { $env:Path = "$dir;$env:Path" }
                }
                if ($process.ExitCode -eq -1978335189) {
                    Log-Message "  [✓] $name already present (WinGet: no upgrade needed)." "Green"
                } else {
                    Log-Message "  [✓] $name installed successfully." "Green"
                }
            } else {
                Log-Message "  [!] Attempt $attempts failed with exit code $($process.ExitCode). Retrying..." "Yellow"
                Start-Sleep -Seconds 3
            }
        } catch {
            Log-Message "  [!] Exception during installation of ${name}: $_" "Yellow"
            Start-Sleep -Seconds 3
        }
    }

    if (-not $success) {
        # Final presence check (install may have succeeded even if WinGet code was odd)
        $foundFinal = Find-ToolPath -CommandName $cmd -CandidatePaths $candidates
        if ($foundFinal) {
            Log-Message "  [✓] $name found after install attempts ($foundFinal)." "Green"
            continue
        }
        if ($optional) {
            Log-Message "  [!] Optional package $name failed; continuing setup." "Yellow"
        } else {
            Log-Message "  [✗] Failed to install $name ($id)." "Red"
            $FailedPackages += $name
        }
    }
}

Refresh-SessionPath

if ($FailedPackages.Count -gt 0) {
    Log-Message "`n[ERROR] The following packages failed to install: $($FailedPackages -join ', ')" "Red"
    Log-Message "Step 1 Failed. Check log at: $LogFile" "Red"
    Log-Message "========================================================`n" "Red"
    exit 1
}

Log-Message "`nStep 1 Complete. Check log at: $LogFile" "Cyan"
Log-Message "========================================================`n" "Cyan"
exit 0
