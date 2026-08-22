@echo off
chcp 65001 >nul
title 阪大 RWD & AI Agent 環境セットアップ (Windows 11)

echo ================================================================================
echo   阪大・統計専門家向け RWD 解析 ＆ AI Agent 開発環境
echo   Windows 11 自動セットアップランチャー
echo ================================================================================
echo.

:: 管理者権限チェック
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [⚠️ 警告] 管理者権限で実行されていません。
    echo 本バッチファイルを右クリックし、「管理者として実行」を選択してください。
    echo.
    pause
    exit /b 1
)

echo 管理者権限を確認しました。セットアップを開始します...
echo.

set SCRIPT_PATH=%~dp0scripts\windows\Setup-WindowsEnvironment.ps1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
set SETUP_EXIT_CODE=%errorLevel%

echo.
if %SETUP_EXIT_CODE% equ 0 (
    echo [✓] セットアップが正常に完了しました。キーを押して終了してください。
) else (
    echo [✗] セットアップがエラー（終了コード: %SETUP_EXIT_CODE%）で終了しました。
    echo     ログファイル（.run\logs\）を確認してください。
)

pause
exit /b %SETUP_EXIT_CODE%
