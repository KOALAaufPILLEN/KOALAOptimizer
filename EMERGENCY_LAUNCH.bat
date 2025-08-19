@echo off
echo 🐨 KOALA Gaming Optimizer - Emergency Launcher
echo.
echo This launcher starts the application in EMERGENCY MODE
echo with zero theme dependencies to prevent FrameworkElement.Style errors.
echo.
echo Starting application in emergency mode...
echo.

if exist "KOALAOptimizer.Testing.exe" (
    start "" "KOALAOptimizer.Testing.exe" --emergency
) else if exist "bin\Release\KOALAOptimizer.Testing.exe" (
    start "" "bin\Release\KOALAOptimizer.Testing.exe" --emergency
) else if exist "bin\Debug\KOALAOptimizer.Testing.exe" (
    start "" "bin\Debug\KOALAOptimizer.Testing.exe" --emergency
) else (
    echo ERROR: Could not find KOALAOptimizer.Testing.exe
    echo Please make sure the application is built.
    pause
)