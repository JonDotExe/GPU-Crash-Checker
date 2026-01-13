@echo off
title GPU Crash Checker - Launcher

echo ========================================
echo GPU Crash Event Viewer Checker
echo ========================================
echo.
echo Starting PowerShell script (will request Admin rights)...
echo.

REM Run the PowerShell script - it will self-elevate to admin
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GPU-Crash-Checker.ps1"

REM If PowerShell failed before elevation, show error
if errorlevel 1 (
    echo.
    echo NOTE: If a UAC prompt appeared, click Yes to run as Administrator.
    echo If no prompt appeared, make sure PowerShell is installed.
    echo.
    pause
)