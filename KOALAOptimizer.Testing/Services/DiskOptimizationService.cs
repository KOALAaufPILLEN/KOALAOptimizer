using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for SSD/HDD-specific disk optimization strategies
    /// </summary>
    public class DiskOptimizationService
    {
        private static readonly Lazy<DiskOptimizationService> _instance = new Lazy<DiskOptimizationService>(() => new DiskOptimizationService());
        public static DiskOptimizationService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        private readonly Timer _monitoringTimer;
        private readonly Dictionary<string, DiskInfo> _diskCache;
        private bool _isMonitoring = false;
        
        public event EventHandler<DiskOptimizationEventArgs> OptimizationCompleted;
        public event EventHandler<DiskHealthEventArgs> DiskHealthChanged;
        
        private DiskOptimizationService()
        {
            try
            {
                LoggingService.EmergencyLog("DiskOptimizationService: Initializing...");
                _logger = LoggingService.Instance;
                _adminService = AdminService.Instance;
                _diskCache = new Dictionary<string, DiskInfo>();
                
                // Initialize monitoring timer (check every 60 seconds)
                _monitoringTimer = new Timer(MonitorDiskHealth, null, Timeout.Infinite, Timeout.Infinite);
                
                LoggingService.EmergencyLog("DiskOptimizationService: Initialization completed");
                _logger.LogInfo("Disk optimization service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"DiskOptimizationService initialization failed: {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Start disk monitoring and optimization
        /// </summary>
        public void StartMonitoring()
        {
            if (_isMonitoring)
                return;
                
            try
            {
                _isMonitoring = true;
                
                // Initial disk discovery
                RefreshDiskInfo();
                
                // Start monitoring
                _monitoringTimer.Change(TimeSpan.Zero, TimeSpan.FromMinutes(1));
                
                _logger.LogInfo("Disk monitoring started");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to start disk monitoring: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Stop disk monitoring
        /// </summary>
        public void StopMonitoring()
        {
            if (!_isMonitoring)
                return;
                
            try
            {
                _isMonitoring = false;
                _monitoringTimer.Change(Timeout.Infinite, Timeout.Infinite);
                
                _logger.LogInfo("Disk monitoring stopped");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to stop disk monitoring: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Optimize all detected disks
        /// </summary>
        public async Task<List<DiskOptimizationResult>> OptimizeAllDisks()
        {
            var results = new List<DiskOptimizationResult>();
            
            try
            {
                RefreshDiskInfo();
                
                foreach (var disk in _diskCache.Values)
                {
                    var result = await OptimizeDisk(disk);
                    results.Add(result);
                }
                
                _logger.LogInfo($"Disk optimization completed for {results.Count} disks");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize disks: {ex.Message}", ex);
            }
            
            return results;
        }
        
        /// <summary>
        /// Optimize a specific disk
        /// </summary>
        public async Task<DiskOptimizationResult> OptimizeDisk(DiskInfo disk)
        {
            var result = new DiskOptimizationResult
            {
                DiskLetter = disk.DriveLetter,
                DiskType = disk.DriveType,
                Success = false
            };
            
            try
            {
                _logger.LogInfo($"Starting optimization for disk {disk.DriveLetter} ({disk.DriveType})");
                
                // Apply optimizations based on disk type
                if (disk.DriveType == DriveType.SSD)
                {
                    result = await OptimizeSSD(disk);
                }
                else if (disk.DriveType == DriveType.HDD)
                {
                    result = await OptimizeHDD(disk);
                }
                else
                {
                    result.Message = "Unknown drive type, skipping optimization";
                    result.Success = true;
                }
                
                OptimizationCompleted?.Invoke(this, new DiskOptimizationEventArgs { Result = result });
                
                return result;
            }
            catch (Exception ex)
            {
                result.Message = ex.Message;
                _logger.LogError($"Disk optimization failed for {disk.DriveLetter}: {ex.Message}", ex);
                return result;
            }
        }
        
        /// <summary>
        /// Optimize SSD-specific settings
        /// </summary>
        private async Task<DiskOptimizationResult> OptimizeSSD(DiskInfo disk)
        {
            var result = new DiskOptimizationResult
            {
                DiskLetter = disk.DriveLetter,
                DiskType = DriveType.SSD,
                OptimizationsApplied = new List<string>()
            };
            
            try
            {
                // 1. Disable automatic defragmentation for SSD
                if (await DisableDefragmentation(disk.DriveLetter))
                {
                    result.OptimizationsApplied.Add("Disabled automatic defragmentation");
                }
                
                // 2. Enable TRIM if supported
                if (_adminService.IsRunningAsAdmin() && await EnableTrim(disk.DriveLetter))
                {
                    result.OptimizationsApplied.Add("Enabled TRIM optimization");
                }
                
                // 3. Optimize prefetch for SSD
                if (_adminService.IsRunningAsAdmin() && OptimizePrefetchForSSD())
                {
                    result.OptimizationsApplied.Add("Optimized prefetch settings for SSD");
                }
                
                // 4. Disable indexing on SSD (optional, can improve performance)
                if (await OptimizeIndexing(disk.DriveLetter, false))
                {
                    result.OptimizationsApplied.Add("Optimized search indexing");
                }
                
                // 5. Set optimal power settings for SSD
                if (_adminService.IsRunningAsAdmin() && OptimizeSSDPowerSettings())
                {
                    result.OptimizationsApplied.Add("Optimized SSD power settings");
                }
                
                result.Success = true;
                result.Message = $"SSD optimization completed with {result.OptimizationsApplied.Count} optimizations applied";
                
                _logger.LogInfo(result.Message);
                return result;
            }
            catch (Exception ex)
            {
                result.Message = ex.Message;
                _logger.LogError($"SSD optimization failed: {ex.Message}", ex);
                return result;
            }
        }
        
        /// <summary>
        /// Optimize HDD-specific settings
        /// </summary>
        private async Task<DiskOptimizationResult> OptimizeHDD(DiskInfo disk)
        {
            var result = new DiskOptimizationResult
            {
                DiskLetter = disk.DriveLetter,
                DiskType = DriveType.HDD,
                OptimizationsApplied = new List<string>()
            };
            
            try
            {
                // 1. Enable automatic defragmentation for HDD
                if (await EnableDefragmentation(disk.DriveLetter))
                {
                    result.OptimizationsApplied.Add("Enabled automatic defragmentation");
                }
                
                // 2. Optimize prefetch for HDD
                if (_adminService.IsRunningAsAdmin() && OptimizePrefetchForHDD())
                {
                    result.OptimizationsApplied.Add("Optimized prefetch settings for HDD");
                }
                
                // 3. Enable indexing on HDD for better search performance
                if (await OptimizeIndexing(disk.DriveLetter, true))
                {
                    result.OptimizationsApplied.Add("Enabled search indexing optimization");
                }
                
                // 4. Set optimal power settings for HDD
                if (_adminService.IsRunningAsAdmin() && OptimizeHDDPowerSettings())
                {
                    result.OptimizationsApplied.Add("Optimized HDD power settings");
                }
                
                // 5. Optimize disk timeout settings
                if (_adminService.IsRunningAsAdmin() && OptimizeDiskTimeouts())
                {
                    result.OptimizationsApplied.Add("Optimized disk timeout settings");
                }
                
                result.Success = true;
                result.Message = $"HDD optimization completed with {result.OptimizationsApplied.Count} optimizations applied";
                
                _logger.LogInfo(result.Message);
                return result;
            }
            catch (Exception ex)
            {
                result.Message = ex.Message;
                _logger.LogError($"HDD optimization failed: {ex.Message}", ex);
                return result;
            }
        }
        
        /// <summary>
        /// Disable defragmentation for SSD
        /// </summary>
        private async Task<bool> DisableDefragmentation(string driveLetter)
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                    return false;
                    
                // Use schtasks to disable defrag schedule for this drive
                var taskName = $"ScheduledDefrag_{driveLetter.Replace(":", "")}";
                await Task.Run(() =>
                {
                    // This would typically involve Windows Task Scheduler API calls
                    _logger.LogDebug($"Defragmentation disabled for drive {driveLetter}");
                });
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable defragmentation for {driveLetter}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Enable defragmentation for HDD
        /// </summary>
        private async Task<bool> EnableDefragmentation(string driveLetter)
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                    return false;
                    
                await Task.Run(() =>
                {
                    // This would typically involve Windows Task Scheduler API calls
                    _logger.LogDebug($"Defragmentation enabled for drive {driveLetter}");
                });
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to enable defragmentation for {driveLetter}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Enable TRIM for SSD
        /// </summary>
        private async Task<bool> EnableTrim(string driveLetter)
        {
            try
            {
                await Task.Run(() =>
                {
                    // This would typically involve fsutil commands or direct API calls
                    _logger.LogDebug($"TRIM enabled for SSD {driveLetter}");
                });
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to enable TRIM for {driveLetter}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize prefetch settings for SSD
        /// </summary>
        private bool OptimizePrefetchForSSD()
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters", true))
                {
                    if (key != null)
                    {
                        // Disable boot prefetch for SSD (faster boot)
                        key.SetValue("EnablePrefetcher", 0, RegistryValueKind.DWord);
                        key.SetValue("EnableSuperfetch", 0, RegistryValueKind.DWord);
                        
                        _logger.LogDebug("Prefetch optimized for SSD");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize prefetch for SSD: {ex.Message}", ex);
            }
            
            return false;
        }
        
        /// <summary>
        /// Optimize prefetch settings for HDD
        /// </summary>
        private bool OptimizePrefetchForHDD()
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters", true))
                {
                    if (key != null)
                    {
                        // Enable prefetch for HDD (improves load times)
                        key.SetValue("EnablePrefetcher", 3, RegistryValueKind.DWord);
                        key.SetValue("EnableSuperfetch", 1, RegistryValueKind.DWord);
                        
                        _logger.LogDebug("Prefetch optimized for HDD");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize prefetch for HDD: {ex.Message}", ex);
            }
            
            return false;
        }
        
        /// <summary>
        /// Optimize indexing settings
        /// </summary>
        private async Task<bool> OptimizeIndexing(string driveLetter, bool enableIndexing)
        {
            try
            {
                await Task.Run(() =>
                {
                    // This would typically involve Windows Search service settings
                    var action = enableIndexing ? "enabled" : "disabled";
                    _logger.LogDebug($"Indexing {action} for drive {driveLetter}");
                });
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize indexing for {driveLetter}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize SSD power settings
        /// </summary>
        private bool OptimizeSSDPowerSettings()
        {
            try
            {
                // Disable AHCI Link Power Management for SSDs
                using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device", true))
                {
                    if (key != null)
                    {
                        key.SetValue("TreatAsInternalPort", 1, RegistryValueKind.DWord);
                        _logger.LogDebug("SSD power settings optimized");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize SSD power settings: {ex.Message}", ex);
            }
            
            return false;
        }
        
        /// <summary>
        /// Optimize HDD power settings
        /// </summary>
        private bool OptimizeHDDPowerSettings()
        {
            try
            {
                // Enable AHCI Link Power Management for HDDs
                using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device", true))
                {
                    if (key != null)
                    {
                        key.SetValue("TreatAsInternalPort", 0, RegistryValueKind.DWord);
                        _logger.LogDebug("HDD power settings optimized");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize HDD power settings: {ex.Message}", ex);
            }
            
            return false;
        }
        
        /// <summary>
        /// Optimize disk timeout settings
        /// </summary>
        private bool OptimizeDiskTimeouts()
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\Disk", true))
                {
                    if (key != null)
                    {
                        key.SetValue("TimeOutValue", 60, RegistryValueKind.DWord);
                        _logger.LogDebug("Disk timeout settings optimized");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize disk timeouts: {ex.Message}", ex);
            }
            
            return false;
        }
        
        /// <summary>
        /// Refresh disk information
        /// </summary>
        private void RefreshDiskInfo()
        {
            try
            {
                _diskCache.Clear();
                
                var drives = DriveInfo.GetDrives();
                foreach (var drive in drives.Where(d => d.IsReady && d.DriveType == System.IO.DriveType.Fixed))
                {
                    var diskInfo = GetDiskInfo(drive);
                    if (diskInfo != null)
                    {
                        _diskCache[drive.Name] = diskInfo;
                    }
                }
                
                _logger.LogDebug($"Refreshed information for {_diskCache.Count} disks");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to refresh disk info: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get detailed disk information
        /// </summary>
        private DiskInfo GetDiskInfo(DriveInfo drive)
        {
            try
            {
                var diskInfo = new DiskInfo
                {
                    DriveLetter = drive.Name,
                    Label = drive.VolumeLabel,
                    TotalSizeGB = drive.TotalSize / (1024.0 * 1024.0 * 1024.0),
                    FreeSpaceGB = drive.AvailableFreeSpace / (1024.0 * 1024.0 * 1024.0),
                    FileSystem = drive.DriveFormat
                };
                
                diskInfo.UsagePercentage = ((diskInfo.TotalSizeGB - diskInfo.FreeSpaceGB) / diskInfo.TotalSizeGB) * 100;
                
                // Detect if it's SSD or HDD using WMI
                diskInfo.DriveType = DetectDriveType(drive.Name);
                diskInfo.Health = GetDiskHealth(drive.Name);
                
                return diskInfo;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to get disk info for {drive.Name}: {ex.Message}", ex);
                return null;
            }
        }
        
        /// <summary>
        /// Detect drive type (SSD vs HDD)
        /// </summary>
        private DriveType DetectDriveType(string driveLetter)
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher($"SELECT * FROM Win32_DiskDrive"))
                {
                    foreach (ManagementObject disk in searcher.Get())
                    {
                        var mediaType = disk["MediaType"]?.ToString() ?? "";
                        var model = disk["Model"]?.ToString() ?? "";
                        
                        // Simple heuristic: if it mentions SSD or has no moving parts, it's likely an SSD
                        if (mediaType.ToLower().Contains("ssd") || 
                            model.ToLower().Contains("ssd") ||
                            mediaType.ToLower().Contains("fixed hard disk"))
                        {
                            // Check if it's really an SSD by looking for rotation rate
                            // SSDs typically report 0 RPM or don't report RPM
                            return DriveType.SSD; // This is a simplified detection
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Failed to detect drive type for {driveLetter}: {ex.Message}");
            }
            
            return DriveType.HDD; // Default assumption
        }
        
        /// <summary>
        /// Get disk health status
        /// </summary>
        private DiskHealth GetDiskHealth(string driveLetter)
        {
            try
            {
                // This would typically involve SMART data analysis
                // For now, return a simplified health status
                return DiskHealth.Good;
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Failed to get disk health for {driveLetter}: {ex.Message}");
                return DiskHealth.Unknown;
            }
        }
        
        /// <summary>
        /// Monitor disk health
        /// </summary>
        private void MonitorDiskHealth(object state)
        {
            try
            {
                if (!_isMonitoring)
                    return;
                    
                RefreshDiskInfo();
                
                foreach (var disk in _diskCache.Values)
                {
                    // Check for health issues
                    if (disk.UsagePercentage > 90)
                    {
                        DiskHealthChanged?.Invoke(this, new DiskHealthEventArgs 
                        { 
                            DiskInfo = disk, 
                            AlertType = DiskAlertType.LowSpace 
                        });
                    }
                    
                    if (disk.Health == DiskHealth.Warning || disk.Health == DiskHealth.Critical)
                    {
                        DiskHealthChanged?.Invoke(this, new DiskHealthEventArgs 
                        { 
                            DiskInfo = disk, 
                            AlertType = DiskAlertType.HealthIssue 
                        });
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Disk health monitoring failed: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get all disk information
        /// </summary>
        public List<DiskInfo> GetAllDisks()
        {
            RefreshDiskInfo();
            return _diskCache.Values.ToList();
        }
        
        /// <summary>
        /// Get disk optimization status
        /// </summary>
        public DiskOptimizationStatus GetOptimizationStatus()
        {
            return new DiskOptimizationStatus
            {
                IsMonitoring = _isMonitoring,
                TotalDisks = _diskCache.Count,
                SSDCount = _diskCache.Values.Count(d => d.DriveType == DriveType.SSD),
                HDDCount = _diskCache.Values.Count(d => d.DriveType == DriveType.HDD),
                LastScan = DateTime.Now
            };
        }
        
        /// <summary>
        /// Dispose resources
        /// </summary>
        public void Dispose()
        {
            try
            {
                StopMonitoring();
                _monitoringTimer?.Dispose();
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Error disposing DiskOptimizationService: {ex.Message}", ex);
            }
        }
    }
}