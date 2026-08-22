<#
.SYNOPSIS
    New-AnalysisProject.ps1 - Case Project Factory for Windows 11
.DESCRIPTION
    Creates an independent, standardized RWD Case Project Git repository using Copier.
    Validates inputs, executes Copier generation, validates PROJECT.yml schema & directory governance
    via 'uv run python validate-project.py', shows preview, requests user confirmation, and initializes Git repository.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Case Project identifier (e.g., case-urology)")]
    [ValidatePattern('^case-[a-z0-9-]+$')]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [ValidateSet("windows-standard", "mac-rwd-expert")]
    [string]$Profile = "windows-standard",

    [Parameter(Mandatory = $false)]
    [ValidateSet("synthetic", "deidentified", "sensitive")]
    [string]$DataClassification = "deidentified",

    [Parameter(Mandatory = $false)]
    [string]$PrimaryLanguage = "sas",

    [Parameter(Mandatory = $false)]
    [string]$SasEncoding = "cp932",

    [Parameter(Mandatory = $false)]
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE "Programing\RWD-Projects"),

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure UTF-8 Console Output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformRoot = Split-Path -Parent $ScriptDir
$TemplateDir = Join-Path $PlatformRoot "templates\analysis-project"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  RWD Case Project Factory (Copier Generator)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Project Name:        $Name"
Write-Host "  Profile:             $Profile"
Write-Host "  Data Classification: $DataClassification"
Write-Host "  Primary Language:    $PrimaryLanguage (SAS Encoding: $SasEncoding)"
Write-Host "  Destination Root:    $DestinationRoot"
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Validation of Prerequisites
if (-not (Test-Path $TemplateDir)) {
    Write-Error "[ERROR] Template directory not found at: $TemplateDir"
    exit 1
}

# Resolve Copier Command: uvx copier or copier
$CopierCmd = Get-Command "copier" -ErrorAction SilentlyContinue
$UseUvx = $false
if (-not $CopierCmd) {
    $UvCmd = Get-Command "uv" -ErrorAction SilentlyContinue
    if ($UvCmd) {
        $UseUvx = $true
    } else {
        Write-Error "[ERROR] Neither 'copier' nor 'uv' found in PATH. Please run .\scripts\windows\Setup-WindowsEnvironment.ps1 first."
        exit 1
    }
}

# 2. Destination Directory Checks & Conflict Prevention
if (-not (Test-Path $DestinationRoot)) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}

$TargetDir = Join-Path $DestinationRoot $Name
if (Test-Path $TargetDir) {
    $existingFiles = Get-ChildItem -Path $TargetDir -Force
    if ($existingFiles.Count -gt 0) {
        Write-Error "[ERROR] Target directory already exists and is not empty: $TargetDir"
        exit 1
    }
} else {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$Success = $false

try {
    # 3. Execute Copier Generation
    Write-Host "`n[1/6] Generating project scaffold with Copier..." -ForegroundColor Green
    
    $CopierArgs = @(
        "copy",
        $TemplateDir,
        $TargetDir,
        "--defaults",
        "--trust",
        "-d", "project_id=$Name",
        "-d", "project_title=$Name",
        "-d", "data_classification=$DataClassification",
        "-d", "primary_language=$PrimaryLanguage",
        "-d", "sas_encoding=$SasEncoding"
    )

    if ($UseUvx) {
        & uvx --from "copier==9.4.1" copier @CopierArgs
    } else {
        & copier @CopierArgs
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Copier generation failed with exit code $LASTEXITCODE"
    }

    # 4. Copy validation & wrapper scripts to Case Project
    $ProjectScriptsDir = Join-Path $TargetDir "scripts"
    New-Item -ItemType Directory -Path $ProjectScriptsDir -Force | Out-Null

    $InvokeSasSource = Join-Path $PlatformRoot "scripts\windows\invoke-sas.ps1"
    $ValidateSource = Join-Path $PlatformRoot "scripts\project\validate-project.py"
    
    if (Test-Path $InvokeSasSource) {
        Copy-Item -Path $InvokeSasSource -Destination (Join-Path $ProjectScriptsDir "invoke-sas.ps1") -Force
    }
    if (Test-Path $ValidateSource) {
        Copy-Item -Path $ValidateSource -Destination (Join-Path $ProjectScriptsDir "validate-project.py") -Force
    }

    # 5. Integrity & Governance Validation (via uv run python or fallback)
    Write-Host "[2/6] Validating Project Schema & Directory Governance..." -ForegroundColor Green
    $SchemaPath = Join-Path $PlatformRoot "schemas\project.schema.json"
    $ValidateScript = Join-Path $ProjectScriptsDir "validate-project.py"
    
    $UvCmd = Get-Command "uv" -ErrorAction SilentlyContinue
    if ($UvCmd) {
        $ValResult = & uv run --with jsonschema --with pyyaml python $ValidateScript --project-dir $TargetDir --schema $SchemaPath
    } else {
        $PythonCmd = Get-Command "python" -ErrorAction SilentlyContinue
        if (-not $PythonCmd) {
            $PythonCmd = Get-Command "py" -ErrorAction SilentlyContinue
        }
        if ($PythonCmd) {
            $ValResult = & $PythonCmd $ValidateScript --project-dir $TargetDir --schema $SchemaPath
        } else {
            throw "Neither 'uv' nor 'python' was found in PATH to execute validation script."
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Project validation failed. Details:`n$ValResult"
    }

    # 6. Preview Summary
    Write-Host "`n[3/6] Project Generated Successfully:" -ForegroundColor Green
    Write-Host "  - Root: $TargetDir"
    Write-Host "  - Structure: src/, sql/, reports/, outputs/private/, outputs/release/"
    Write-Host "  - Governance: PROJECT.yml, .cursor/rules/, .gitignore, tasks.json"

    # 7. User Confirmation for Git Initialization
    $ProceedWithGit = $true
    if (-not $NonInteractive) {
        $Response = Read-Host "`nDo you want to initialize Git and open in Cursor? (Y/n)"
        if ($Response -and $Response.Trim().ToLower() -eq 'n') {
            $ProceedWithGit = $false
        }
    }

    if ($ProceedWithGit) {
        # 8. Git Initialization & Targeted Staging
        Write-Host "`n[4/6] Initializing local Git repository..." -ForegroundColor Green
        Push-Location $TargetDir
        try {
            & git init | Out-Null
            
            # Check Git user config
            $GitUser = (& git config user.name) 2>$null
            $GitEmail = (& git config user.email) 2>$null

            if ([string]::IsNullOrWhiteSpace($GitUser) -or [string]::IsNullOrWhiteSpace($GitEmail)) {
                Write-Host "[WARN] Git user.name or user.email is not configured." -ForegroundColor Yellow
                Write-Host "       Run: git config --global user.name 'Your Name'"
                Write-Host "            git config --global user.email 'you@example.com'"
                Write-Host "       Skipping automatic initial commit." -ForegroundColor Yellow
            } else {
                & git add .gitignore .cursor .vscode config data reports schemas sql src pyproject.toml package.json PROJECT.yml README.md AGENTS.md scripts | Out-Null
                & git commit -m "feat: initialize case project from template ($Name)" | Out-Null
                Write-Host "[5/6] Initial Git commit created." -ForegroundColor Green
            }
        } finally {
            Pop-Location
        }

        # 9. Launch Cursor
        Write-Host "`n[6/6] Launching Cursor IDE..." -ForegroundColor Green
        $CursorCmd = Get-Command "cursor" -ErrorAction SilentlyContinue
        if (-not $CursorCmd) {
            $CursorUserBin = Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app\bin"
            if (Test-Path $CursorUserBin) {
                $env:Path = "$CursorUserBin;$env:Path"
                $CursorCmd = Get-Command "cursor" -ErrorAction SilentlyContinue
            }
        }

        if ($CursorCmd) {
            & cursor $TargetDir
        } else {
            Write-Host "[INFO] 'cursor' command not in PATH. Please open '$TargetDir' in Cursor." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n[INFO] Git initialization skipped by user." -ForegroundColor Yellow
    }

    $Success = $true
} catch {
    Write-Host "`n[ERROR] Generation failed: $_" -ForegroundColor Red
    if ((Test-Path $TargetDir) -and (-not $Success)) {
        Write-Host "[ROLLBACK] Cleaning up failed generation directory: $TargetDir" -ForegroundColor Yellow
        Remove-Item -Path $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  Case Project Ready: $TargetDir" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan
exit 0
