@echo off
:: ============================================================
::  Roo Code Universal Installer - Double-click to run
:: ============================================================
title Roo Code Installer

:: Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] PowerShell is not installed or not in PATH.
    echo Please install PowerShell and try again.
    pause
    exit /b 1
)

:: Get the directory where this batch file lives
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Install-RooCode.ps1"

:: Check if the PowerShell script exists
if not exist "%PS_SCRIPT%" (
    echo [ERROR] Install-RooCode.ps1 not found in: %SCRIPT_DIR%
    echo Please make sure Install-RooCode.ps1 is in the same folder as this file.
    pause
    exit /b 1
)

echo.
echo  =====================================================
echo   Roo Code Universal Installer
echo   Installing extensions and setting up profiles...
echo  =====================================================
echo.

:: Run PowerShell script with elevated execution policy bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [WARNING] Installer exited with code %ERRORLEVEL%
    echo If you see errors above, try running as Administrator.
    pause
)

exit /b 0
