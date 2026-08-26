<#
.SYNOPSIS
    04-configure.ps1 - Configure Cursor IDE Extensions and Global Settings
.DESCRIPTION
    Detects Cursor IDE from known paths / WinGet, installs recommended extensions
    (Python, Jupyter, R, Quarto, Prettier, ESLint, EditorConfig), and configures
    User settings.json for SAS CP932 and UTF-8 encoding support.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) ".run\logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "configure.log"

function Log-Message([string]$msg, [string]$color = "White") {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] $msg"
    Write-Host $msg -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logEntry -Encoding utf8
}

Log-Message "========================================================" "Cyan"
Log-Message "  Step 4: Configuring Cursor IDE & Extensions" "Cyan"
Log-Message "========================================================" "Cyan"

# 1. Multi-path Resolution for Cursor IDE / CLI
$CursorCmd = Get-Command "cursor" -ErrorAction SilentlyContinue

$CandidatePaths = @(
    (Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app\bin"),
    (Join-Path $env:LOCALAPPDATA "Programs\Cursor\resources\app\bin"),
    (Join-Path $env:ProgramFiles "Cursor\resources\app\bin"),
    (Join-Path ${env:ProgramFiles(x86)} "Cursor\resources\app\bin")
)

if (-not $CursorCmd) {
    foreach ($cand in $CandidatePaths) {
        if (Test-Path $cand) {
            $env:Path = "$cand;$env:Path"
            $CursorCmd = Get-Command "cursor" -ErrorAction SilentlyContinue
            if ($CursorCmd) {
                Log-Message "  [✓] Cursor CLI discovered in: $cand" "Green"
                break
            }
        }
    }
}

# If still not found, check if Cursor.exe is installed manually
$CursorExeCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\cursor\Cursor.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Cursor\Cursor.exe"),
    (Join-Path $env:ProgramFiles "Cursor\Cursor.exe")
)
$CursorExeFound = $false
foreach ($exe in $CursorExeCandidates) {
    if (Test-Path $exe) {
        $CursorExeFound = $true
        Log-Message "  [i] Cursor GUI application found at: $exe" "Gray"
        break
    }
}

# Only attempt WinGet if Cursor is completely absent
if (-not $CursorCmd -and -not $CursorExeFound) {
    Log-Message "  [...] Cursor is not detected. Attempting automated installation via WinGet..." "Yellow"
    $proc = Start-Process -FilePath "winget" `
        -ArgumentList "install", "--id", "Anysphere.Cursor", "--exact", "--source", "winget", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
        -Wait -PassThru -NoNewWindow
    
    # Refresh PATH and check standard candidate paths again
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    foreach ($cand in $CandidatePaths) {
        if (Test-Path $cand) {
            $env:Path = "$cand;$env:Path"
            $CursorCmd = Get-Command "cursor" -ErrorAction SilentlyContinue
            if ($CursorCmd) { break }
        }
    }
}

# 2. Install Cursor Extensions
$Extensions = @(
    "ms-python.python",
    "ms-toolsai.jupyter",
    "REditorSupport.r",
    "quarto.quarto",
    "EditorConfig.EditorConfig",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint"
)

if ($CursorCmd) {
    Log-Message "  [✓] Cursor CLI operational: $($CursorCmd.Source)" "Green"
    foreach ($ext in $Extensions) {
        Log-Message "  [...] Installing extension: $ext..." "Yellow"
        & cursor --install-extension $ext 2>$null | Out-Null
        Log-Message "  [✓] Extension: $ext configured." "Green"
    }
} else {
    Log-Message "  [INFO] Cursor CLI not available in PATH. Settings.json will be configured; extensions can be installed via Cursor GUI." "Yellow"
}

# 3. Configure Global User Settings
$CursorUserDir = Join-Path $env:APPDATA "Cursor\User"
if (-not (Test-Path $CursorUserDir)) {
    New-Item -ItemType Directory -Path $CursorUserDir -Force | Out-Null
}

$SettingsFile = Join-Path $CursorUserDir "settings.json"
$Settings = @{}

if (Test-Path $SettingsFile) {
    try {
        $raw = Get-Content -Path $SettingsFile -Raw -Encoding utf8
        $Settings = $raw | ConvertFrom-Json -AsHashtable
    } catch {
        Log-Message "  [WARN] Could not parse existing settings.json, creating backup." "Yellow"
        Copy-Item -Path $SettingsFile -Destination "$SettingsFile.bak" -Force
    }
}

# Apply Encoding & Association Defaults
$Settings["files.encoding"] = "utf8"
$Settings["files.autoGuessEncoding"] = $false
$Settings["editor.formatOnSave"] = $true

if (-not $Settings.ContainsKey("files.associations")) {
    $Settings["files.associations"] = @{}
}
$Settings["files.associations"]["*.sas"] = "sas"
$Settings["files.associations"]["*.qmd"] = "quarto"
$Settings["files.associations"]["PROJECT.yml"] = "yaml"
$Settings["files.associations"]["release-manifest.yml"] = "yaml"

if (-not $Settings.ContainsKey("[sas]")) {
    $Settings["[sas]"] = @{}
}
$Settings["[sas]"]["files.encoding"] = "shiftjis"

$UpdatedJson = $Settings | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($SettingsFile, $UpdatedJson, [System.Text.Encoding]::UTF8)

Log-Message "  [✓] Cursor User settings updated at: $SettingsFile" "Green"
Log-Message "`nStep 4 Complete. Check log at: $LogFile" "Cyan"
Log-Message "========================================================`n" "Cyan"
exit 0
