@echo off
chcp 65001 >nul
title Osaka Univ RWD / Case Project Factory

echo ================================================================================
echo   Osaka Univ RWD Analysis / Case Project Factory
echo   新規解析リポジトリ作成ランチャー
echo ================================================================================
echo.

set SCRIPT_PATH=%~dp0scripts\project\New-AnalysisProject.ps1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
set SCRIPT_EXIT_CODE=%errorLevel%

echo.
if %SCRIPT_EXIT_CODE% equ 0 (
    echo [OK] 処理が正常に完了しました。キーを押して終了します。
) else (
    echo [FAIL] エラーが発生しました (終了コード: %SCRIPT_EXIT_CODE%)
)

pause
exit /b %SCRIPT_EXIT_CODE%
