@echo off
chcp 65001 >nul
title Osaka Univ RWD / AI Agent Setup (Windows 11)

echo ================================================================================
echo   Osaka Univ RWD Analysis / AI Agent Environment
echo   Windows 11 Auto Setup Launcher
echo ================================================================================
echo.

:: Admin check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARN] Not running as Administrator.
    echo Right-click this batch file and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)

echo Administrator confirmed. Starting setup...
echo.

set SCRIPT_PATH=%~dp0scripts\windows\Setup-WindowsEnvironment.ps1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
set SETUP_EXIT_CODE=%errorLevel%

echo.
if %SETUP_EXIT_CODE% equ 0 (
    echo [OK] Setup completed successfully.
    echo.
    echo --------------------------------------------------------------------------------
    echo   [NEXT STEP] 新規の解析プロジェクト(Case Project)を作成するには
    echo               ルートにある "Create-NewProject.bat" をダブルクリックしてください。
    echo --------------------------------------------------------------------------------
    echo.
    echo Press a key to exit.
) else (
    echo [FAIL] Setup ended with error code: %SETUP_EXIT_CODE%
    echo       Check logs under .run\logs\
)

pause
exit /b %SETUP_EXIT_CODE%