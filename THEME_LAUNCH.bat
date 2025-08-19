@echo off
echo 🐨 KOALA Gaming Optimizer - Theme Loading Launcher
echo.
echo ⚠️ WARNING: This launcher attempts to load themes which may cause
echo FrameworkElement.Style errors on some systems.
echo.
echo If the application crashes with theme errors, use EMERGENCY_LAUNCH.bat instead.
echo.
echo Starting application with theme loading...
echo.

if exist "KOALAOptimizer.Testing.exe" (
    start "" "KOALAOptimizer.Testing.exe" --normal
) else if exist "bin\Release\KOALAOptimizer.Testing.exe" (
    start "" "bin\Release\KOALAOptimizer.Testing.exe" --normal
) else if exist "bin\Debug\KOALAOptimizer.Testing.exe" (
    start "" "bin\Debug\KOALAOptimizer.Testing.exe" --normal
) else (
    echo ERROR: Could not find KOALAOptimizer.Testing.exe
    echo Please make sure the application is built.
    pause
)