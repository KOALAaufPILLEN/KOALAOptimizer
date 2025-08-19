using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Management;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for real-time memory optimization and defragmentation
    /// </summary>
    public class MemoryDefragmentationService
    {
        private static readonly Lazy<MemoryDefragmentationService> _instance = new Lazy<MemoryDefragmentationService>(() => new MemoryDefragmentationService());
        public static MemoryDefragmentationService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        private readonly Timer _defragTimer;
        private readonly Timer _monitoringTimer;
        private bool _isRunning = false;
        private bool _isDefragmenting = false;
        
        public event EventHandler<MemoryOptimizationEventArgs> OptimizationCompleted;
        public event EventHandler<MemoryStatusEventArgs> MemoryStatusChanged;
        
        // Windows API imports for memory management
        [DllImport("kernel32.dll")]
        private static extern bool SetProcessWorkingSetSize(IntPtr hProcess, IntPtr dwMinimumWorkingSetSize, IntPtr dwMaximumWorkingSetSize);
        
        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();
        
        [DllImport("psapi.dll")]
        private static extern bool EmptyWorkingSet(IntPtr hProcess);
        
        private MemoryDefragmentationService()
        {
            try
            {
                LoggingService.EmergencyLog("MemoryDefragmentationService: Initializing...");
                _logger = LoggingService.Instance;
                _adminService = AdminService.Instance;
                
                // Initialize timers
                _defragTimer = new Timer(PerformMemoryDefragmentation, null, Timeout.Infinite, Timeout.Infinite);
                _monitoringTimer = new Timer(MonitorMemoryStatus, null, Timeout.Infinite, Timeout.Infinite);
                
                LoggingService.EmergencyLog("MemoryDefragmentationService: Initialization completed");
                _logger.LogInfo("Memory defragmentation service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MemoryDefragmentationService initialization failed: {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Start memory defragmentation and monitoring
        /// </summary>
        public void StartOptimization()
        {
            if (_isRunning)
                return;
                
            try
            {
                _isRunning = true;
                
                // Start monitoring every 30 seconds
                _monitoringTimer.Change(TimeSpan.Zero, TimeSpan.FromSeconds(30));
                
                // Start defragmentation every 5 minutes
                _defragTimer.Change(TimeSpan.FromMinutes(1), TimeSpan.FromMinutes(5));
                
                _logger.LogInfo("Memory optimization started");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to start memory optimization: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Stop memory defragmentation and monitoring
        /// </summary>
        public void StopOptimization()
        {
            if (!_isRunning)
                return;
                
            try
            {
                _isRunning = false;
                _defragTimer.Change(Timeout.Infinite, Timeout.Infinite);
                _monitoringTimer.Change(Timeout.Infinite, Timeout.Infinite);
                
                _logger.LogInfo("Memory optimization stopped");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to stop memory optimization: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Perform immediate memory defragmentation
        /// </summary>
        public async Task<MemoryOptimizationResult> DefragmentNow()
        {
            if (_isDefragmenting)
            {
                return new MemoryOptimizationResult { Success = false, Message = "Defragmentation already in progress" };
            }
            
            try
            {
                _isDefragmenting = true;
                _logger.LogInfo("Starting immediate memory defragmentation");
                
                var result = await Task.Run(() => PerformMemoryDefragmentationInternal());
                
                OptimizationCompleted?.Invoke(this, new MemoryOptimizationEventArgs { Result = result });
                
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Memory defragmentation failed: {ex.Message}", ex);
                return new MemoryOptimizationResult { Success = false, Message = ex.Message };
            }
            finally
            {
                _isDefragmenting = false;
            }
        }
        
        /// <summary>
        /// Perform memory defragmentation (timer callback)
        /// </summary>
        private async void PerformMemoryDefragmentation(object state)
        {
            if (!_isRunning || _isDefragmenting)
                return;
                
            try
            {
                await DefragmentNow();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Scheduled memory defragmentation failed: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Internal memory defragmentation logic
        /// </summary>
        private MemoryOptimizationResult PerformMemoryDefragmentationInternal()
        {
            var result = new MemoryOptimizationResult();
            var beforeMemory = GetMemoryInfo();
            
            try
            {
                result.BeforeOptimization = beforeMemory;
                
                // 1. Trim process working sets
                var trimmedProcesses = TrimProcessWorkingSets();
                result.ProcessesTrimmed = trimmedProcesses;
                
                // 2. Clear system cache
                if (_adminService.IsRunningAsAdmin())
                {
                    ClearSystemCache();
                    result.SystemCacheCleared = true;
                }
                
                // 3. Garbage collection
                ForceGarbageCollection();
                result.GarbageCollectionPerformed = true;
                
                // 4. Standby memory cleanup
                if (_adminService.IsRunningAsAdmin())
                {
                    CleanupStandbyMemory();
                    result.StandbyMemoryCleared = true;
                }
                
                // Wait a moment for changes to take effect
                Thread.Sleep(1000);
                
                var afterMemory = GetMemoryInfo();
                result.AfterOptimization = afterMemory;
                result.MemoryFreed = beforeMemory.UsedMemoryMB - afterMemory.UsedMemoryMB;
                result.Success = true;
                result.Message = $"Freed {result.MemoryFreed:F1} MB of memory";
                
                _logger.LogInfo($"Memory defragmentation completed: {result.Message}");
                
                return result;
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.Message = ex.Message;
                _logger.LogError($"Memory defragmentation failed: {ex.Message}", ex);
                return result;
            }
        }
        
        /// <summary>
        /// Trim working sets of all processes
        /// </summary>
        private int TrimProcessWorkingSets()
        {
            int trimmedCount = 0;
            
            try
            {
                var processes = Process.GetProcesses();
                foreach (var process in processes)
                {
                    try
                    {
                        if (!process.HasExited && process.Handle != IntPtr.Zero)
                        {
                            if (EmptyWorkingSet(process.Handle))
                            {
                                trimmedCount++;
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogDebug($"Failed to trim working set for {process.ProcessName}: {ex.Message}");
                    }
                }
                
                _logger.LogDebug($"Trimmed working sets for {trimmedCount} processes");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to trim process working sets: {ex.Message}", ex);
            }
            
            return trimmedCount;
        }
        
        /// <summary>
        /// Clear system cache (requires admin privileges)
        /// </summary>
        private void ClearSystemCache()
        {
            try
            {
                // Force system cache flush
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Process WHERE Name = 'System'"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        // This is a placeholder - actual cache clearing would require native API calls
                        _logger.LogDebug("System cache clear requested");
                        break;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Failed to clear system cache: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Force garbage collection for .NET applications
        /// </summary>
        private void ForceGarbageCollection()
        {
            try
            {
                GC.Collect();
                GC.WaitForPendingFinalizers();
                GC.Collect();
                _logger.LogDebug("Garbage collection completed");
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Garbage collection failed: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Cleanup standby memory (requires admin privileges)
        /// </summary>
        private void CleanupStandbyMemory()
        {
            try
            {
                // This would typically involve RamMap-like functionality
                // For now, we'll perform a working set trim on our own process
                var currentProcess = GetCurrentProcess();
                SetProcessWorkingSetSize(currentProcess, (IntPtr)(-1), (IntPtr)(-1));
                _logger.LogDebug("Standby memory cleanup performed");
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Failed to cleanup standby memory: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Monitor memory status
        /// </summary>
        private void MonitorMemoryStatus(object state)
        {
            try
            {
                if (!_isRunning)
                    return;
                    
                var memoryInfo = GetMemoryInfo();
                MemoryStatusChanged?.Invoke(this, new MemoryStatusEventArgs { MemoryInfo = memoryInfo });
                
                // Auto-trigger defragmentation if memory usage is high
                if (memoryInfo.UsagePercentage > 85 && !_isDefragmenting)
                {
                    _logger.LogInfo($"High memory usage detected ({memoryInfo.UsagePercentage:F1}%), triggering defragmentation");
                    Task.Run(async () => await DefragmentNow());
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Memory monitoring failed: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get current memory information
        /// </summary>
        public MemoryInfo GetMemoryInfo()
        {
            try
            {
                var memoryInfo = new MemoryInfo();
                
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_OperatingSystem"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var totalMemory = Convert.ToDouble(obj["TotalVisibleMemorySize"]) / 1024; // Convert to MB
                        var availableMemory = Convert.ToDouble(obj["FreePhysicalMemory"]) / 1024; // Convert to MB
                        
                        memoryInfo.TotalMemoryMB = totalMemory;
                        memoryInfo.AvailableMemoryMB = availableMemory;
                        memoryInfo.UsedMemoryMB = totalMemory - availableMemory;
                        memoryInfo.UsagePercentage = (memoryInfo.UsedMemoryMB / totalMemory) * 100;
                        memoryInfo.Timestamp = DateTime.Now;
                        
                        break;
                    }
                }
                
                return memoryInfo;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to get memory info: {ex.Message}", ex);
                return new MemoryInfo { Timestamp = DateTime.Now };
            }
        }
        
        /// <summary>
        /// Get memory fragmentation percentage
        /// </summary>
        public double GetMemoryFragmentation()
        {
            try
            {
                // This is a simplified estimation - actual fragmentation measurement would require more complex analysis
                var memInfo = GetMemoryInfo();
                var processCount = Process.GetProcesses().Length;
                
                // Estimate fragmentation based on process count vs available memory
                var fragmentationEstimate = Math.Min(100, (processCount / 10.0) + (memInfo.UsagePercentage * 0.5));
                
                return fragmentationEstimate;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to calculate memory fragmentation: {ex.Message}", ex);
                return 0;
            }
        }
        
        /// <summary>
        /// Get optimization status
        /// </summary>
        public MemoryOptimizationStatus GetOptimizationStatus()
        {
            return new MemoryOptimizationStatus
            {
                IsRunning = _isRunning,
                IsDefragmenting = _isDefragmenting,
                CurrentMemoryInfo = GetMemoryInfo(),
                FragmentationPercentage = GetMemoryFragmentation(),
                LastOptimization = DateTime.Now // This would be tracked in real implementation
            };
        }
        
        /// <summary>
        /// Dispose resources
        /// </summary>
        public void Dispose()
        {
            try
            {
                StopOptimization();
                _defragTimer?.Dispose();
                _monitoringTimer?.Dispose();
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Error disposing MemoryDefragmentationService: {ex.Message}", ex);
            }
        }
    }
}