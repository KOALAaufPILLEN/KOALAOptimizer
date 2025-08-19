# KOALA Gaming Optimizer - WPF Error Fix Testing Guide

## Emergency Mode Testing

This document provides comprehensive testing instructions for the new emergency mode and systematic theme loading fixes.

### Phase 1: Emergency Mode Testing

#### Test 1: Manual Emergency Mode Activation
```cmd
# Run application with emergency flag
KOALAOptimizer.Testing.exe --emergency
```

**Expected Results:**
- ✅ EmergencyMainWindow should appear with dark theme
- ✅ No FrameworkElement.Style exceptions should occur
- ✅ Window should show error details and system information
- ✅ Emergency log should be accessible via button
- ✅ Restart functionality should work

#### Test 2: Automatic Emergency Mode Trigger
1. Manually corrupt a theme file or introduce a style error
2. Start application normally
3. DispatcherUnhandledException should trigger automatic emergency mode

**Expected Results:**
- ✅ Application should detect FrameworkElement.Style error
- ✅ Should automatically close main window and show emergency window
- ✅ Should log detailed diagnostic information
- ✅ Should provide recovery options

#### Test 3: Diagnostic Logging Validation
```powershell
# Check emergency log location
$logPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "koala-emergency-$(Get-Date -Format 'yyyy-MM-dd').txt")
Get-Content $logPath -Tail 50
```

**Expected Results:**
- ✅ Comprehensive startup logging from static constructor
- ✅ Diagnostic snapshots at PRE_THEME_LOAD, POST_THEME_LOAD, THEME_LOAD_FAILURE
- ✅ Detailed resource validation logs
- ✅ Progressive theme loading steps logged

### Phase 2: Systematic Theme Loading Testing

#### Test 4: Theme Loading Resilience
1. Start application normally
2. Check logs for systematic loading phases

**Expected Results:**
- ✅ `CaptureResourceSnapshot` should log rollback point creation
- ✅ `ValidateResourcesInIsolation` should validate theme before application
- ✅ `ApplyResourcesProgressively` should apply brushes, then styles, then complete theme
- ✅ Any failures should trigger rollback and emergency mode

#### Test 5: Resource Validation Testing
Monitor logs for these validation phases:
- ✅ Essential resources validation
- ✅ Style integrity validation
- ✅ Individual resource access testing
- ✅ Progressive application (brushes → styles → complete theme)

### Phase 3: Error Recovery Testing

#### Test 6: Recovery Scenarios
Test various failure points:

1. **Theme File Missing**: Rename SciFiTheme.xaml
   - Expected: Should trigger emergency mode immediately

2. **Corrupted Theme**: Add invalid XAML to theme file
   - Expected: Should detect and recover gracefully

3. **Missing Style Resources**: Remove key styles from theme
   - Expected: Should validate and handle missing resources

4. **Resource Reference Errors**: Create circular references
   - Expected: Should detect during integrity validation

### Phase 4: User Experience Testing

#### Test 7: Emergency Mode Functionality
In emergency mode, test these features:

1. **System Information Display**: Should show OS, CLR, processor info
2. **Emergency Log Access**: Button should open log file
3. **Application Restart**: Should restart normally
4. **Basic Optimizations**: Should apply basic gaming optimizations
5. **Clean Exit**: Should log shutdown properly

#### Test 8: Normal Mode Recovery
1. Start in emergency mode
2. Use restart button
3. Verify normal mode starts successfully

### Phase 5: Performance and Stability Testing

#### Test 9: Startup Performance
Monitor startup times:
- Normal startup with systematic loading
- Emergency mode startup
- Compare with previous versions

#### Test 10: Memory Usage
Check for memory leaks in:
- Resource snapshot capture/rollback
- Emergency mode operation
- Theme switching

### Validation Checklist

#### Critical Success Criteria:
- [ ] Application never crashes due to FrameworkElement.Style errors
- [ ] Emergency mode provides fully functional interface
- [ ] Automatic error detection and recovery works
- [ ] Diagnostic logging captures all necessary information
- [ ] User can restart and recover from any theme error
- [ ] No regression in normal operation performance

#### Advanced Success Criteria:
- [ ] Systematic theme loading provides better error isolation
- [ ] Progressive application reduces failure surface area
- [ ] Rollback capability maintains application stability
- [ ] Detailed diagnostics enable better troubleshooting
- [ ] Emergency mode provides basic gaming optimization functionality

### Debugging Commands

```powershell
# Get all emergency logs
Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter "koala-emergency-*.txt" | Sort-Object LastWriteTime -Descending

# Monitor real-time logging
Get-Content $logPath -Wait -Tail 10

# Check for specific error patterns
Select-String -Path $logPath -Pattern "FrameworkElement.Style|CRITICAL|FAILED"

# Validate diagnostic snapshots
Select-String -Path $logPath -Pattern "DIAGNOSTIC_SNAPSHOT"
```

### Common Issues and Solutions

#### Issue: Emergency mode doesn't activate
- Check if --emergency flag is properly passed
- Verify EmergencyMainWindow XAML has no style dependencies
- Check emergency log for initialization errors

#### Issue: Theme loading still fails
- Verify systematic loading phases in log
- Check resource validation results
- Test rollback functionality

#### Issue: Performance degradation
- Monitor diagnostic snapshot frequency
- Check for excessive logging
- Validate resource cleanup

### Success Metrics

1. **Zero startup crashes** due to style errors
2. **100% emergency mode activation** when style errors occur
3. **Complete diagnostic coverage** of startup phases
4. **Successful recovery** in all test scenarios
5. **Maintained performance** in normal operation

This comprehensive testing approach ensures the WPF runtime error fix is robust and addresses all the requirements from the problem statement.