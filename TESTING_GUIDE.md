# Testing Guide for Enhanced KOALA Gaming Optimizer

## Pre-Testing Checklist
- [ ] Run on Windows 10/11 with Administrator privileges
- [ ] Have at least one supported game installed
- [ ] Backup important system settings before testing
- [ ] Ensure PowerShell 5.1+ is available

## Testing Scenarios

### 1. Battlefield 6 Support Testing
```powershell
# Test BF6 detection
Get-Process -Name "bf6event" -ErrorAction SilentlyContinue
Get-Process -Name "bf6" -ErrorAction SilentlyContinue

# Expected: BF6 profile should be detected and selected automatically
```

### 2. New Game Profiles Testing
Test auto-detection for each new game:
- Call of Duty: Modern Warfare II (`cod`, `cod22-cod`, `modernwarfare2`)
- Call of Duty: Modern Warfare III (`cod23-cod`, `modernwarfare3`, `mw3`)
- Rainbow Six Siege (`rainbowsix`, `rainbowsix_vulkan`)
- Overwatch 2 (`overwatch`)
- League of Legends (`league of legends`, `leagueoflegends`)
- Rocket League (`rocketleague`)
- PUBG: Battlegrounds (`tslgame`)
- Destiny 2 (`destiny2`)

### 3. Enhanced Gaming Optimizations Testing

#### CPU Affinity Management
- [ ] Verify `ThreadDpcEnable` and `DpcQueueDepth` registry settings
- [ ] Check CPU core assignment for game processes
- [ ] Monitor CPU usage during gaming

#### Advanced Memory Optimization
- [ ] Check `FeatureSettings*` registry keys
- [ ] Verify prefetcher disabled (`EnablePrefetcher=0`)
- [ ] Monitor memory usage improvements

#### GPU Driver Optimizations
- [ ] Verify TDR settings (`TdrLevel=0`, `TdrDelay=60`)
- [ ] Check additional TDR parameters
- [ ] Test graphics stability

#### Network Latency Improvements
- [ ] Verify TCP parameter changes
- [ ] Test network latency in supported games
- [ ] Check MTU discovery settings

#### Gaming Power Plan
- [ ] Verify Ultimate Performance activation
- [ ] Check standby/hibernate timeouts
- [ ] Monitor power consumption

### 4. Real-Time Monitoring Testing
- [ ] Enable real-time monitoring option
- [ ] Start a game and verify CPU/memory logging
- [ ] Check 30-second interval reporting
- [ ] Verify garbage collection for .NET games

### 5. Error Handling Testing
- [ ] Test without Administrator privileges (should show warning)
- [ ] Test on systems with insufficient RAM/CPU
- [ ] Verify log levels (Info, Warning, Error) display correctly
- [ ] Test registry access denied scenarios

### 6. System Requirements Check
- [ ] Verify Windows version detection
- [ ] Check RAM detection and warnings
- [ ] Verify CPU core count detection
- [ ] Test PowerShell version reporting

### 7. Backup and Restore Testing
- [ ] Apply optimizations and verify backup creation
- [ ] Test restore functionality
- [ ] Verify all 47 registry keys are backed up
- [ ] Test service state restoration

## Performance Validation

### Before/After Comparison
1. **Baseline Measurements:**
   - Game FPS (frames per second)
   - Input latency
   - Memory usage
   - CPU utilization
   - Network ping times

2. **With Optimizations:**
   - Re-measure all baseline metrics
   - Compare improvements
   - Document any regressions

### Game-Specific Testing
- **Battlefield 6**: Test BF6-specific optimizations
- **Competitive Games**: Test network latency improvements
- **Resource-Heavy Games**: Test memory and CPU optimizations

## Expected Results

### Performance Improvements
- 5-15% FPS improvement in most games
- 10-30ms reduction in input latency
- Reduced memory fragmentation
- Lower CPU scheduling overhead
- Improved network responsiveness

### System Stability
- No system crashes or BSODs
- Stable game performance
- Proper service functionality
- Correct registry state management

## Troubleshooting Common Issues

### If Optimizations Don't Apply
1. Check Administrator privileges
2. Verify Windows version compatibility
3. Check registry permissions
4. Review error logs

### If Game Detection Fails
1. Verify game process names
2. Check game is actually running
3. Review supported process list
4. Add custom process name if needed

### If Performance Degrades
1. Use "Revert All" function
2. Check system event logs
3. Restart the system
4. Re-apply optimizations selectively

## Reporting Issues
When reporting issues, include:
- Windows version and build
- Game being optimized
- Specific optimization settings used
- Error messages from activity log
- System specifications (CPU, RAM, GPU)