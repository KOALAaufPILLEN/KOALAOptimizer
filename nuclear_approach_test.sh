#!/bin/bash

echo "🧪 NUCLEAR APPROACH VERIFICATION TEST"
echo "======================================"
echo

# Test 1: Verify App.xaml has zero resource definitions
echo "Test 1: App.xaml Resource Elimination"
echo "-------------------------------------"
app_resources=$(grep -c "ResourceDictionary\|SolidColorBrush\|Style x:Key" "KOALAOptimizer.Testing/App.xaml" || echo "0")
if [ "$app_resources" -eq 0 ]; then
    echo "✅ PASS: App.xaml has 0 resource definitions"
else
    echo "❌ FAIL: App.xaml still has $app_resources resource definitions"
fi
echo

# Test 2: Verify MinimalMainWindow has zero DynamicResource references
echo "Test 2: MinimalMainWindow Dependency Elimination"
echo "-----------------------------------------------"
minimal_dynamic=$(grep -c "DynamicResource\|StaticResource" "KOALAOptimizer.Testing/Views/MinimalMainWindow.xaml" || echo "0")
if [ "$minimal_dynamic" -eq 0 ]; then
    echo "✅ PASS: MinimalMainWindow has 0 resource references"
else
    echo "❌ FAIL: MinimalMainWindow still has $minimal_dynamic resource references"
fi
echo

# Test 3: Verify default startup logic
echo "Test 3: Default Startup Logic"
echo "-----------------------------"
default_minimal=$(grep -c "CreateMinimalWindow" "KOALAOptimizer.Testing/App.xaml.cs" || echo "0")
if [ "$default_minimal" -gt 0 ]; then
    echo "✅ PASS: Default startup uses MinimalWindow"
else
    echo "❌ FAIL: Default startup logic not implemented"
fi
echo

# Test 4: Count total resource references in project
echo "Test 4: Total Resource Reference Audit"
echo "-------------------------------------"
total_resources=$(find "KOALAOptimizer.Testing" -name "*.xaml" -exec grep -l "DynamicResource\|StaticResource" {} \; | wc -l)
startup_safe_files=$(find "KOALAOptimizer.Testing" -name "*.xaml" -path "*/Views/MinimalMainWindow.xaml" -o -name "App.xaml" | wc -l)
echo "Total XAML files with resource references: $total_resources"
echo "Startup-critical files (should be 0): checking..."

app_refs=$(grep -c "DynamicResource\|StaticResource" "KOALAOptimizer.Testing/App.xaml" 2>/dev/null || echo "0")
minimal_refs=$(grep -c "DynamicResource\|StaticResource" "KOALAOptimizer.Testing/Views/MinimalMainWindow.xaml" 2>/dev/null || echo "0")
startup_critical_refs=$((app_refs + minimal_refs))

if [ "$startup_critical_refs" -eq 0 ]; then
    echo "✅ PASS: Startup-critical files have 0 resource references"
else
    echo "❌ FAIL: Startup-critical files still have $startup_critical_refs resource references"
fi
echo

# Test 5: Verify project structure
echo "Test 5: Project Structure Verification"
echo "-------------------------------------"
if [ -f "KOALAOptimizer.Testing/Views/MinimalMainWindow.xaml" ]; then
    echo "✅ PASS: MinimalMainWindow.xaml exists"
else
    echo "❌ FAIL: MinimalMainWindow.xaml missing"
fi

if [ -f "KOALAOptimizer.Testing/Views/MinimalMainWindow.xaml.cs" ]; then
    echo "✅ PASS: MinimalMainWindow.xaml.cs exists"
else
    echo "❌ FAIL: MinimalMainWindow.xaml.cs missing"
fi

if [ -f "EMERGENCY_LAUNCH.bat" ]; then
    echo "✅ PASS: Emergency launcher exists"
else
    echo "❌ FAIL: Emergency launcher missing"
fi

if [ -f "THEME_LAUNCH.bat" ]; then
    echo "✅ PASS: Theme launcher exists"
else
    echo "❌ FAIL: Theme launcher missing"
fi
echo

echo "🎯 NUCLEAR APPROACH VERIFICATION COMPLETE"
echo "========================================"
echo "The nuclear approach should eliminate ALL FrameworkElement.Style errors"
echo "by ensuring zero resource dependencies in the default startup path."