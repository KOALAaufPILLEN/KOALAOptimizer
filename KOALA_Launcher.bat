@echo off
REM KOALA Gaming Optimizer v2.3 Launcher with UAC support
REM This demonstrates the UAC elevation functionality

echo KOALA Gaming Optimizer v2.3 - Enhanced Launcher
echo ==============================================
echo.

REM Check if we're already running as admin
net session >nul 2>&1
if %errorLevel% == 0 (
    echo ✓ Running with Administrator privileges
    echo Starting KOALA Gaming Optimizer v2.3 with full functionality...
    powershell.exe -ExecutionPolicy Bypass -File "koalaoptimizerps1.ps1"
) else (
    echo ⚠ Not running as Administrator
    echo.
    echo For full functionality, the KOALA Gaming Optimizer v2.3 needs Administrator privileges.
    echo This will allow:
    echo   • System registry modifications (HKEY_LOCAL_MACHINE)
    echo   • Windows service configuration  
    echo   • Power plan and hibernation settings
    echo   • Advanced memory and CPU optimizations
    echo.
    choice /C YN /M "Would you like to restart with Administrator privileges"
    if errorlevel 2 goto limited_mode
    if errorlevel 1 goto elevate
)

:elevate
echo Requesting Administrator privileges...
powershell.exe -Command "Start-Process cmd.exe -ArgumentList '/c cd /d %CD% && powershell.exe -ExecutionPolicy Bypass -File koalaoptimizerps1.ps1' -Verb RunAs"
exit

:limited_mode
echo Starting in Limited Mode...
echo Some optimizations will be unavailable without Administrator privileges.
echo Available: User-level settings, process priority, visual effects
echo Unavailable: System settings, services, power management
powershell.exe -ExecutionPolicy Bypass -File "koalaoptimizerps1.ps1"

pause