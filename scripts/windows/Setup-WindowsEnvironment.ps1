<#
.SYNOPSIS
    Setup-WindowsEnvironment.ps1 - Master Setup Orchestrator for Clean Windows 11
.DESCRIPTION
    Fully automated, beginner-friendly setup script that installs and configures
    all required tools (Terminal, PowerShell 7, Git, uv, Python 3.12, Copier 9.4.1,
    rig, R 4.4, Quarto, DuckDB, Node.js, pnpm, Cursor IDE, CP932/UTF-8 mappings)
    and verifies the entire environment with synthetic datasets.
    Aggregates failures and halts safely if any step fails.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure UTF-8 Console Output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# scripts/windows -> repo root
$PlatformRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

Write-Host @"
================================================================================
  阪大・統計専門家向け RWD 解析 / AI Agent 開発環境
  【Windows 11 初期自動セットアップ（ゼロから一括導入）】
================================================================================
"@ -ForegroundColor Cyan

# 1. Administrator Privilege Check
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "`n[⚠️ 警告] 管理者権限（Administrator）で実行されていません。" -ForegroundColor Yellow
    Write-Host "         PowerShell を右クリックして「管理者として実行」を選択してください。`n" -ForegroundColor Yellow
    
    $choice = Read-Host "このまま標準ユーザーとして続行を試みますか？ (Y/N)"
    if ($choice -notmatch '^[Yy]$') {
        exit 2
    }
}

$Steps = @(
    @{ id = "00"; name = "環境 / ハードウェア非破壊診断"; script = "00-diagnose.ps1" },
    @{ id = "01"; name = "共通開発ツール導入 (Terminal, PS7, Git, 7-Zip)"; script = "01-install-common.ps1" },
    @{ id = "02"; name = "統計・RWD解析スタック導入 (uv, Python 3.12, Copier, rig, R, Quarto, DuckDB)"; script = "02-install-analysis.ps1" },
    @{ id = "03"; name = "報告・スライドスタック導入 (Node.js, pnpm, Slidev/TypeScript)"; script = "03-install-reporting.ps1" },
    @{ id = "04"; name = "Cursor IDE 設定 / 拡張機能・CP932マッピング構成"; script = "04-configure.ps1" },
    @{ id = "05"; name = "全ツール稼働 / 合成データエンドツーエンド自動検証"; script = "05-verify.ps1" }
)

$TotalSteps = $Steps.Count
$CurrentIndex = 0
$FailedSteps = @()

foreach ($step in $Steps) {
    $CurrentIndex++
    $stepScriptPath = Join-Path $ScriptDir $step.script
    
    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  [$CurrentIndex / $TotalSteps] $($step.name)" -ForegroundColor Yellow
    Write-Host "  実行ファイル: $($step.script)" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

    if (-not (Test-Path $stepScriptPath)) {
        Write-Host "`n[✗ エラー] 必要なスクリプトファイルが見つかりません: $stepScriptPath" -ForegroundColor Red
        $FailedSteps += @{ id = $step.id; name = $step.name; error = "ファイル未検出" }
        break
    }

    $stepSuccess = $false
    while (-not $stepSuccess) {
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stepScriptPath
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq 0) {
                $stepSuccess = $true
            } else {
                Write-Host "`n[⚠️ エラー] ステップ $($step.id) は失敗しました (終了コード: $exitCode)。" -ForegroundColor Red
                Write-Host "ログファイルを確認してください: .run\logs\" -ForegroundColor Yellow
                
                $action = Read-Host "選択してください: [R] 再試行 / [S] このステップをスキップ / [A] セットアップ中止 (デフォルト: A)"
                if ($action -match '^[Rr]$') {
                    Write-Host "ステップ $($step.id) を再試行します..." -ForegroundColor Yellow
                    continue
                } elseif ($action -match '^[Ss]$') {
                    Write-Host "ステップ $($step.id) をスキップして後続処理に進みます。" -ForegroundColor Yellow
                    $FailedSteps += @{ id = $step.id; name = $step.name; error = "スキップ (ExitCode $exitCode)" }
                    break
                } else {
                    Write-Host "セットアップを中止します。" -ForegroundColor Red
                    $FailedSteps += @{ id = $step.id; name = $step.name; error = "ユーザー中止 (ExitCode $exitCode)" }
                    break
                }
            }
        } catch {
            Write-Host "`n[✗ 例外発生] ステップ $($step.id) で例外が発生しました: $_" -ForegroundColor Red
            $FailedSteps += @{ id = $step.id; name = $step.name; error = $_.ToString() }
            break
        }
    }

    if ($FailedSteps.Count -gt 0 -and $FailedSteps[-1].error -match "中止") {
        break
    }
}

# Final Result Evaluation
if ($FailedSteps.Count -gt 0) {
    Write-Host @"

================================================================================
  ❌ セットアップ中にエラーまたは未完了のステップが発生しました
================================================================================
【失敗 / スキップされたステップ】
"@ -ForegroundColor Red

    foreach ($f in $FailedSteps) {
        Write-Host "  - ステップ $($f.id) [$($f.name)]: $($f.error)" -ForegroundColor Red
    }

    Write-Host @"

【トラブルシューティング手順】
1. ログファイルを確認してください: .run\logs\
2. インターネット接続および管理者権限を確認してください。
3. エラー原因を解消後、再度 Setup-Windows.bat を「管理者として実行」してください。
================================================================================
"@ -ForegroundColor Yellow
    exit 1
}

# Final Success Summary
Write-Host @"

================================================================================
  🎉 Windows 11 解析環境の自動セットアップが正常に完了しました！
================================================================================

【導入完了スタック】
  [✓] 共通ツール: Windows Terminal, PowerShell 7, Git, 7-Zip
  [✓] 統計・解析: uv, Python 3.12, Copier 9.4.1, rig, R 4.4, Quarto, DuckDB
  [✓] 報告・スライド: Node.js LTS, pnpm, Slidev, PptxGenJS
  [✓] AI Agent IDE: Cursor, 推奨拡張機能, CP932/UTF-8 マッピング設定
  [✓] 合成データ検証: 全言語E2E動作確認済み

【次のステップ: 最初の解析案件（Case Project）を作成する】
プラットフォームリポジトリのルートで、主解析言語に応じて実行してください
（既定生成先: %USERPROFILE%\Programing\RWD-Projects\<Name>）:

  # パターン A: Python 主解析（推奨）
  .\scripts\project\New-AnalysisProject.ps1 -Name "case-urology" -PrimaryLanguage "python"

  # パターン B: R 主解析（推奨）
  .\scripts\project\New-AnalysisProject.ps1 -Name "case-urology" -PrimaryLanguage "r"

  # パターン C: 既存SAS併用（SAS保有時のみ）
  .\scripts\project\New-AnalysisProject.ps1 -Name "case-urology" -PrimaryLanguage "sas" -SasEncoding "cp932"

【ドキュメント案内】
- 初心者向けチートシート: docs/beginner-cheatsheet.md
- 日常運用マニュアル: docs/daily-operations.md
- ソフトウェア構成表: docs/software-matrix.md
================================================================================
"@ -ForegroundColor Green
exit 0
