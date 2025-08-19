@echo off
echo Testing XAML compilation fix for InitializeComponent issue...
echo.

cd KOALAOptimizer.Testing

echo Building project to test InitializeComponent generation...
dotnet build --configuration Debug --verbosity normal

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ BUILD SUCCESS: InitializeComponent issue fixed!
    echo The App.xaml now properly generates InitializeComponent method.
    echo.
) else (
    echo.
    echo ❌ BUILD FAILED: InitializeComponent issue still exists.
    echo Check the build output above for specific errors.
    echo.
)

echo Checking for generated files...
if exist "obj\Debug\App.g.cs" (
    echo ✅ Found App.g.cs - InitializeComponent should be generated
    findstr /C:"InitializeComponent" "obj\Debug\App.g.cs" && echo ✅ InitializeComponent method found in generated code
) else (
    echo ❌ App.g.cs not found - XAML compilation failed
)

pause