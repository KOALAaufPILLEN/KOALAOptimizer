@echo off
REM KOALA Gaming Optimizer - Manual Testing Script
REM This script should be run on a Windows system with .NET Framework 4.8

echo ===================================================
echo KOALA Gaming Optimizer - WPF Error Fix Testing
echo ===================================================
echo.

echo This script tests the FrameworkElement.Style error fixes.
echo.

echo Prerequisites:
echo - Windows operating system
echo - .NET Framework 4.8 runtime installed
echo - Application built successfully
echo.

set APP_EXE=KOALAOptimizer.Testing.exe

if not exist "%APP_EXE%" (
    echo ERROR: %APP_EXE% not found!
    echo Please build the application first using Visual Studio or MSBuild:
    echo   msbuild KOALAOptimizer.Testing.csproj /p:Configuration=Release
    echo.
    pause
    exit /b 1
)

echo Found application executable: %APP_EXE%
echo.

:MAIN_MENU
echo ========================================
echo Select test scenario:
echo ========================================
echo 1. Normal Startup Test
echo 2. Emergency Mode Test  
echo 3. Theme Corruption Simulation
echo 4. View Logs
echo 5. Exit
echo.
set /p choice=Enter your choice (1-5): 

if "%choice%"=="1" goto NORMAL_STARTUP
if "%choice%"=="2" goto EMERGENCY_MODE
if "%choice%"=="3" goto THEME_CORRUPTION
if "%choice%"=="4" goto VIEW_LOGS
if "%choice%"=="5" goto EXIT
echo Invalid choice. Please try again.
goto MAIN_MENU

:NORMAL_STARTUP
echo.
echo ========================================
echo TEST 1: Normal Startup
echo ========================================
echo Starting application normally...
echo Expected: Application should start with SciFi theme
echo Expected: No FrameworkElement.Style errors should occur
echo.
echo Starting %APP_EXE%...
start "" "%APP_EXE%"
echo.
echo Did the application start successfully? (Y/N)
set /p result=
if /i "%result%"=="Y" (
    echo ✅ PASS: Normal startup successful
) else (
    echo ❌ FAIL: Normal startup failed
    echo Check the emergency log in %%TEMP%% folder for details
)
echo.
pause
goto MAIN_MENU

:EMERGENCY_MODE
echo.
echo ========================================
echo TEST 2: Emergency Mode
echo ========================================
echo Starting application in emergency mode...
echo Expected: EmergencyMainWindow should appear
echo Expected: Dark theme with hardcoded colors
echo Expected: Basic functionality available
echo.
echo Starting %APP_EXE% --emergency...
start "" "%APP_EXE%" --emergency
echo.
echo Did the emergency mode start successfully? (Y/N)
set /p result=
if /i "%result%"=="Y" (
    echo ✅ PASS: Emergency mode successful
) else (
    echo ❌ FAIL: Emergency mode failed
)
echo.
pause
goto MAIN_MENU

:THEME_CORRUPTION
echo.
echo ========================================
echo TEST 3: Theme Corruption Simulation
echo ========================================
echo This test simulates theme file corruption.
echo WARNING: This will temporarily modify theme files!
echo.
echo Do you want to proceed? (Y/N)
set /p proceed=
if /i not "%proceed%"=="Y" goto MAIN_MENU

REM Backup original theme
if exist "Themes\SciFiTheme.xaml" (
    copy "Themes\SciFiTheme.xaml" "Themes\SciFiTheme.xaml.backup" >nul
    echo Backed up SciFiTheme.xaml
    
    REM Corrupt the theme file
    echo ^<InvalidXML^> > "Themes\SciFiTheme.xaml"
    echo Corrupted SciFiTheme.xaml
    
    echo.
    echo Starting application with corrupted theme...
    echo Expected: Application should detect error and fall back to emergency mode
    echo.
    start "" "%APP_EXE%"
    
    echo.
    echo Press any key after testing to restore the original theme...
    pause >nul
    
    REM Restore original theme
    copy "Themes\SciFiTheme.xaml.backup" "Themes\SciFiTheme.xaml" >nul
    del "Themes\SciFiTheme.xaml.backup" >nul
    echo Restored original SciFiTheme.xaml
) else (
    echo Theme file not found. Cannot perform corruption test.
)
echo.
pause
goto MAIN_MENU

:VIEW_LOGS
echo.
echo ========================================
echo TEST 4: View Logs
echo ========================================
echo Opening emergency log location...
echo Emergency logs are stored in: %TEMP%
echo Look for files starting with "KOALA_Emergency_"
echo.
explorer "%TEMP%"
echo.
pause
goto MAIN_MENU

:EXIT
echo.
echo ========================================
echo Testing Complete
echo ========================================
echo.
echo Summary of expected behavior:
echo ✅ Normal startup: Application loads with SciFi theme
echo ✅ Emergency mode: Safe fallback interface available
echo ✅ Theme corruption: Automatic fallback without crashes
echo ✅ Error logging: Detailed diagnostics in emergency logs
echo.
echo The FrameworkElement.Style error should no longer occur!
echo.
pause
exit /b 0