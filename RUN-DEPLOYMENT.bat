@echo off
setlocal enabledelayedexpansion

REM Check if PowerShell is available
where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set PS_CMD=pwsh
) else (
    set PS_CMD=powershell
)

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Run the PowerShell script
echo.
echo ============================================
echo  SPoW Cockpit - Full Deployment
echo ============================================
echo.

%PS_CMD% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%DEPLOY-ALL.ps1"

echo.
echo ============================================
echo  Deployment Complete!
echo ============================================
echo.
pause
