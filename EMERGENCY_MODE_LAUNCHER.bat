@echo off
echo.
echo =====================================================
echo KOALA Gaming Optimizer - Emergency Mode Launcher
echo =====================================================
echo.
echo This script demonstrates the emergency mode functionality
echo that provides a robust fallback when WPF theming fails.
echo.

:menu
echo Available Options:
echo.
echo 1. Launch in Emergency Mode (--emergency)
echo 2. Launch in Normal Mode
echo 3. View Emergency Logs
echo 4. Clean Emergency Logs
echo 5. Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto emergency
if "%choice%"=="2" goto normal
if "%choice%"=="3" goto viewlogs
if "%choice%"=="4" goto cleanlogs
if "%choice%"=="5" goto exit
echo Invalid choice. Please try again.
goto menu

:emergency
echo.
echo Launching KOALA Gaming Optimizer in Emergency Mode...
echo This will bypass all theme loading and show the emergency interface.
echo.
if exist "KOALAOptimizer.Testing.exe" (
    start "KOALA Emergency Mode" "KOALAOptimizer.Testing.exe" --emergency
) else if exist "bin\Release\KOALAOptimizer.Testing.exe" (
    start "KOALA Emergency Mode" "bin\Release\KOALAOptimizer.Testing.exe" --emergency
) else if exist "bin\Debug\KOALAOptimizer.Testing.exe" (
    start "KOALA Emergency Mode" "bin\Debug\KOALAOptimizer.Testing.exe" --emergency
) else (
    echo ERROR: KOALAOptimizer.Testing.exe not found!
    echo Please build the project first or run from the correct directory.
)
goto menu

:normal
echo.
echo Launching KOALA Gaming Optimizer in Normal Mode...
echo If theme errors occur, emergency mode should activate automatically.
echo.
if exist "KOALAOptimizer.Testing.exe" (
    start "KOALA Normal Mode" "KOALAOptimizer.Testing.exe"
) else if exist "bin\Release\KOALAOptimizer.Testing.exe" (
    start "KOALA Normal Mode" "bin\Release\KOALAOptimizer.Testing.exe"
) else if exist "bin\Debug\KOALAOptimizer.Testing.exe" (
    start "KOALA Normal Mode" "bin\Debug\KOALAOptimizer.Testing.exe"
) else (
    echo ERROR: KOALAOptimizer.Testing.exe not found!
    echo Please build the project first or run from the correct directory.
)
goto menu

:viewlogs
echo.
echo Opening Emergency Logs...
echo.
set logdir=%TEMP%
echo Log directory: %logdir%
echo.
dir "%logdir%\koala-emergency-*.txt" 2>nul
if errorlevel 1 (
    echo No emergency logs found.
    echo Emergency logs are created when the application encounters startup errors.
) else (
    echo.
    echo Opening most recent emergency log...
    for /f "delims=" %%i in ('dir /b /od "%logdir%\koala-emergency-*.txt" 2^>nul') do set "latest=%%i"
    if defined latest (
        start notepad "%logdir%\!latest!"
    )
)
goto menu

:cleanlogs
echo.
echo Cleaning Emergency Logs...
echo.
del "%TEMP%\koala-emergency-*.txt" 2>nul
if errorlevel 1 (
    echo No emergency logs found to clean.
) else (
    echo Emergency logs cleaned successfully.
)
goto menu

:exit
echo.
echo Thank you for using KOALA Gaming Optimizer Emergency Mode Launcher!
echo.
pause