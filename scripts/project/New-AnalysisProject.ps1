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
    [Parameter(Mandatory = $false, HelpMessage = "Case Project identifier (e.g., case-urology)")]
    [string]$Name = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("windows-standard", "mac-rwd-expert")]
    [string]$Profile = "windows-standard",

    [Parameter(Mandatory = $false)]
    [ValidateSet("synthetic", "deidentified", "sensitive")]
    [string]$DataClassification = "deidentified",

    [Parameter(Mandatory = $false)]
    [ValidateSet("python", "r", "sas")]
    [string]$PrimaryLanguage = "python",

    [Parameter(Mandatory = $false)]
    [ValidateSet("cp932", "utf-8", "none")]
    [string]$SasEncoding = $(if ($PrimaryLanguage -eq "sas") { "cp932" } else { "none" }),

    [Parameter(Mandatory = $false)]
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE "Programing\RWD-Projects"),

    [Parameter(Mandatory = $false)]
    [string]$DestinationPath,

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure UTF-8 Console Output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Interactive Prompt Wizard if $Name is not provided and not NonInteractive
if ([string]::IsNullOrWhiteSpace($Name) -and -not $NonInteractive) {
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "  新規 RWD 解析プロジェクト (Case Project) 作成ガイド" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "【1】プロジェクト名を入力してください（小文字英数字・ハイフン）" -ForegroundColor Yellow
    Write-Host "     例: urology -> 自動的に 'case-urology' と命名されます" -ForegroundColor Gray
    $rawName = Read-Host "  プロジェクト名 [既定: urology]"
    if ([string]::IsNullOrWhiteSpace($rawName)) { $rawName = "urology" }
    
    # Auto-fix: convert to lowercase, replace invalid characters with hyphen, ensure case- prefix
    $cleanName = $rawName.Trim().ToLower() -replace '[^a-z0-9-]', '-'
    if (-not ($cleanName.StartsWith("case-"))) {
        $cleanName = "case-$cleanName"
    }
    $Name = $cleanName
    Write-Host "  -> 設定された名前: $Name" -ForegroundColor Green
    Write-Host ""

    Write-Host "【2】主に使用する解析言語を選択してください" -ForegroundColor Yellow
    Write-Host "  1) Python  (推奨・標準データ解析環境)" -ForegroundColor White
    Write-Host "  2) R       (推奨・統計解析環境)" -ForegroundColor White
    Write-Host "  3) SAS     (CP932文字コード・既存SAS資産併用)" -ForegroundColor White
    $langChoice = Read-Host "  選択 [1-3] (既定: 1)"
    switch ($langChoice.Trim()) {
        "2" { $PrimaryLanguage = "r"; $SasEncoding = "none" }
        "3" { $PrimaryLanguage = "sas"; $SasEncoding = "cp932" }
        default { $PrimaryLanguage = "python"; $SasEncoding = "none" }
    }
    Write-Host "  -> 解析言語: $PrimaryLanguage" -ForegroundColor Green
    Write-Host ""

    Write-Host "【3】扱うデータのセキュリティ区分を選択してください" -ForegroundColor Yellow
    Write-Host "  1) deidentified (匿名化データ・標準)" -ForegroundColor White
    Write-Host "  2) synthetic    (テスト用合成データ)" -ForegroundColor White
    Write-Host "  3) sensitive    (高セキュリティ機微データ)" -ForegroundColor White
    $dataChoice = Read-Host "  選択 [1-3] (既定: 1)"
    switch ($dataChoice.Trim()) {
        "2" { $DataClassification = "synthetic" }
        "3" { $DataClassification = "sensitive" }
        default { $DataClassification = "deidentified" }
    }
    Write-Host "  -> データ区分: $DataClassification" -ForegroundColor Green
    Write-Host ""
} else {
    # If $Name was supplied without 'case-' prefix, auto-fix it
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $cleanName = $Name.Trim().ToLower() -replace '[^a-z0-9-]', '-'
        if (-not ($cleanName.StartsWith("case-"))) {
            $cleanName = "case-$cleanName"
        }
        $Name = $cleanName
    }
}

# Validate $Name format
if ([string]::IsNullOrWhiteSpace($Name) -or $Name -notmatch '^case-[a-z0-9-]+$') {
    Write-Error "[ERROR] Project Name must match pattern '^case-[a-z0-9-]+$' (e.g., case-urology). Provided: '$Name'"
    exit 1
}

# Prefer $PSScriptRoot (reliable under powershell -File). Walk up until repo root.
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$PlatformRoot = $null
$probe = $ScriptDir
for ($i = 0; $i -lt 6; $i++) {
    $candidateTpl = Join-Path $probe "templates\analysis-project"
    $candidateCopier = Join-Path $candidateTpl "copier.yml"
    if ((Test-Path -LiteralPath $candidateTpl) -and (Test-Path -LiteralPath $candidateCopier)) {
        $PlatformRoot = $probe
        break
    }
    $parent = Split-Path -Parent $probe
    if (-not $parent -or $parent -eq $probe) { break }
    $probe = $parent
}
if (-not $PlatformRoot) {
    # Fallback: scripts/project -> ../..
    $PlatformRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
}
$TemplateDir = Join-Path $PlatformRoot "templates\analysis-project"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  RWD Case Project Factory (Copier Generator)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Project Name:        $Name"
Write-Host "  Profile:             $Profile"
Write-Host "  Data Classification: $DataClassification"
Write-Host "  Primary Language:    $PrimaryLanguage (SAS Encoding: $SasEncoding)"
Write-Host "  Destination Root:    $DestinationRoot"
Write-Host "  Platform Root:       $PlatformRoot"
Write-Host "  Template Dir:        $TemplateDir"
if ($DestinationPath) {
    Write-Host "  Destination Path:    $DestinationPath"
} else {
    Write-Host "  Destination Root:    $DestinationRoot"
}
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Validation of Prerequisites
if (-not (Test-Path -LiteralPath $TemplateDir)) {
    Write-Error "[ERROR] Template directory not found at: $TemplateDir (ScriptDir=$ScriptDir)"
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

# 2. Destination Directory Resolution & Conflict Prevention
if ($NonInteractive -and (-not $DestinationPath) -and (-not $PSBoundParameters.ContainsKey("DestinationRoot"))) {
    throw "-NonInteractive requires -DestinationPath or an explicit -DestinationRoot."
}

if (-not $DestinationPath -and (-not $PSBoundParameters.ContainsKey("DestinationRoot")) -and (-not $NonInteractive)) {
    $enteredRoot = Read-Host "保存先ルートを入力してください（Enterで $DestinationRoot）"
    if ($enteredRoot -and $enteredRoot.Trim()) {
        $DestinationRoot = $enteredRoot.Trim()
    }
}

if ($DestinationPath) {
    $TargetDir = [System.IO.Path]::GetFullPath($DestinationPath)
    $TargetLeaf = Split-Path -Leaf $TargetDir
    if ($TargetLeaf -ne $Name) {
        throw "-DestinationPath の末尾 '$TargetLeaf' が -Name '$Name' と一致しません。"
    }
    if ($PSBoundParameters.ContainsKey("DestinationRoot")) {
        $ExpectedPath = [System.IO.Path]::GetFullPath((Join-Path $DestinationRoot $Name))
        if ($ExpectedPath.TrimEnd('\') -ne $TargetDir.TrimEnd('\')) {
            throw "-DestinationPath と -DestinationRoot/-Name の指定が矛盾しています。"
        }
    }
    $DestinationRoot = Split-Path -Parent $TargetDir
} else {
    $TargetDir = [System.IO.Path]::GetFullPath((Join-Path $DestinationRoot $Name))
}

if (-not (Test-Path $DestinationRoot)) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}
if (Test-Path $TargetDir) {
    $existingFiles = @(Get-ChildItem -Path $TargetDir -Force -ErrorAction SilentlyContinue)
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
        "-d", "profile=$Profile",
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

    # Ship schema with the Case Project so validate-project.py works offline/out-of-tree
    $SchemaSource = Join-Path $PlatformRoot "schemas\project.schema.json"
    $ProjectSchemaDir = Join-Path $TargetDir "schemas"
    if (Test-Path $SchemaSource) {
        New-Item -ItemType Directory -Path $ProjectSchemaDir -Force | Out-Null
        Copy-Item -Path $SchemaSource -Destination (Join-Path $ProjectSchemaDir "project.schema.json") -Force
    }

    # Copy repository-managed skills into the generated Case Project.
    # .agents/skills is the canonical source recognized by Cursor & AI agents.
    $SourceAgentsSkills = Join-Path $PlatformRoot ".agents\skills"
    $TargetAgentsSkills = Join-Path $TargetDir ".agents\skills"

    if (Test-Path -LiteralPath $SourceAgentsSkills) {
        New-Item -ItemType Directory -Path $TargetAgentsSkills -Force | Out-Null
        Copy-Item -Path (Join-Path $SourceAgentsSkills "*") -Destination $TargetAgentsSkills -Recurse -Force
        Write-Host "[✓] Repository skills automatically deployed to .agents\skills." -ForegroundColor Green
    } else {
        Write-Host "[INFO] No repository-managed .agents\skills found; skipping skill copy." -ForegroundColor Gray
    }
    $OpenSpecSetupSource = Join-Path $ScriptDir "setup-openspec.ps1"
    $OpenSpecSetupTarget = Join-Path $ProjectScriptsDir "setup-openspec.ps1"
    $OpenSpecConfigSource = Join-Path $PlatformRoot "config\ai-framework-versions.json"
    $OpenSpecConfigTargetDir = Join-Path $TargetDir "config"
    if (-not (Test-Path $OpenSpecSetupSource)) {
        throw "OpenSpec setup script not found at: $OpenSpecSetupSource"
    }
    if (-not (Test-Path $OpenSpecConfigSource)) {
        throw "OpenSpec version configuration not found at: $OpenSpecConfigSource"
    }
    New-Item -ItemType Directory -Path $OpenSpecConfigTargetDir -Force | Out-Null
    Copy-Item -Path $OpenSpecSetupSource -Destination $OpenSpecSetupTarget -Force
    Copy-Item -Path $OpenSpecConfigSource -Destination (Join-Path $OpenSpecConfigTargetDir "ai-framework-versions.json") -Force

    # 5. Integrity & Governance Validation (via uv run python or fallback)
    Write-Host "[2/6] Validating Project Schema & Directory Governance..." -ForegroundColor Green
    $SchemaPath = Join-Path $PlatformRoot "schemas\project.schema.json"
    if (-not (Test-Path -LiteralPath $SchemaPath)) {
        $SchemaPath = Join-Path $ProjectSchemaDir "project.schema.json"
    }
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
 Write-Host "  - Governance: PROJECT.yml, .cursor/rules/, .agents/skills/, .pre-commit-config.yaml, .gitignore, tasks.json"
    Write-Host "  - OpenSpec: npx project-scoped initialization before Git"

    # 7. User Confirmation for OpenSpec and Git Initialization
    $RunOpenSpec = $true
    $ProceedWithGit = $true
    if (-not $NonInteractive) {
        $OpenSpecResponse = Read-Host "`nOpenSpecを初期化しますか？ (Y/n)"
        if ($OpenSpecResponse -and $OpenSpecResponse.Trim().ToLower() -eq 'n') {
            $RunOpenSpec = $false
        }
        $Response = Read-Host "Gitを初期化してCursorで開きますか？ (Y/n)"
        if ($Response -and $Response.Trim().ToLower() -eq 'n') {
            $ProceedWithGit = $false
        }
    }

    # 8. OpenSpec Initialization (failure is recorded and does not delete the project)
    Write-Host "`n[4/7] Initializing OpenSpec..." -ForegroundColor Green
    $OpenSpecArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $OpenSpecSetupTarget,
        "-ProjectRoot", $TargetDir,
        "-NonInteractive"
    )
    if (-not $RunOpenSpec) {
        $OpenSpecArgs += "-Skip"
    }
    & powershell.exe @OpenSpecArgs
    $OpenSpecExitCode = $LASTEXITCODE
    if ($OpenSpecExitCode -ne 0) {
        Write-Host "[WARN] OpenSpec initialization did not complete. The project is retained; see AI_FRAMEWORK_STATUS.yml." -ForegroundColor Yellow
    }

    if ($ProceedWithGit) {
        # 9. Git Initialization & Targeted Staging
        Write-Host "`n[5/7] Initializing local Git repository..." -ForegroundColor Green
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
                $StagePaths = @(
                    ".gitignore", ".pre-commit-config.yaml", ".cursor", ".agents", ".vscode", "config", "data", "reports", "schemas", "sql", "src",
                    "pyproject.toml", "package.json", "PROJECT.yml", "README.md", "AGENTS.md", "AI_FRAMEWORK_STATUS.yml", "scripts"
                )
                if (Test-Path "openspec") {
                    $StagePaths += "openspec"
                }
                & git add @StagePaths | Out-Null
                & git commit -m "feat: initialize case project from template ($Name)" | Out-Null
                Write-Host "[6/7] Initial Git commit created." -ForegroundColor Green

                $PreCommitCmd = Get-Command "pre-commit" -ErrorAction SilentlyContinue
                if ($PreCommitCmd -and (Test-Path -LiteralPath ".pre-commit-config.yaml")) {
                    & pre-commit install 2>$null | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[INFO] pre-commit hooks installed for secret scanning." -ForegroundColor Gray
                    }
                }
            }
        } finally {
            Pop-Location
        }

        # 9. Launch Cursor (skip in NonInteractive / E2E to avoid file locks)
        if (-not $NonInteractive) {
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
            Write-Host "`n[6/6] NonInteractive: skipping Cursor launch." -ForegroundColor Gray
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
