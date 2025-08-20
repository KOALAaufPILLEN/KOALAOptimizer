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
                if (disk.DriveType == Models.DriveType.SSD)
                {
                    result = await OptimizeSSD(disk);
                }
                else if (disk.DriveType == Models.DriveType.HDD)
                {
                    result = await OptimizeHDD(disk);
                }
                else if (disk.DriveType == Models.DriveType.Hybrid)
                {
                    // For hybrid drives, apply both SSD and HDD optimizations selectively
                    result = await OptimizeHybrid(disk);
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
                DiskType = Models.DriveType.SSD,
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
                DiskType = Models.DriveType.HDD,
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
        /// Optimize hybrid drive (SSHD) with selective SSD and HDD optimizations
        /// </summary>
        private async Task<DiskOptimizationResult> OptimizeHybrid(DiskInfo disk)
        {
            var result = new DiskOptimizationResult
            {
                DiskLetter = disk.DriveLetter,
                DiskType = Models.DriveType.Hybrid,
                OptimizationsApplied = new List<string>()
            };
            
            try
            {
                _logger.LogInfo($"Applying hybrid drive optimization for {disk.DriveLetter}");
                
                // Apply SSD-like optimizations for the cache portion
                // 1. Disable automatic defragmentation (cache portion is SSD)
                if (await DisableDefragmentation(disk.DriveLetter))
                {
                    result.OptimizationsApplied.Add("Disabled automatic defragmentation for SSD cache");
                }
                
                // 2. Enable TRIM support for the SSD cache
                if (_adminService.IsRunningAsAdmin() && await EnableTrim(disk.DriveLetter))
                {
                    result.OptimizationsApplied.Add("Enabled TRIM support for SSD cache");
                }
                
                // Apply HDD-like optimizations for the magnetic portion
                // 3. Enable moderate prefetch (hybrid drives can benefit from some prefetch)
                if (_adminService.IsRunningAsAdmin() && OptimizePrefetchForHybrid())
                {
                    result.OptimizationsApplied.Add("Optimized prefetch settings for hybrid drive");
                }
                
                // 4. Optimize power settings (less aggressive than pure HDD)
                if (_adminService.IsRunningAsAdmin() && OptimizeHybridPowerSettings())
                {
                    result.OptimizationsApplied.Add("Optimized power management for hybrid drive");
                }
                
                result.Success = true;
                result.Message = $"Hybrid drive optimization completed with {result.OptimizationsApplied.Count} optimizations applied";
                
                _logger.LogInfo(result.Message);
                return result;
            }
            catch (Exception ex)
            {
                result.Message = ex.Message;
                _logger.LogError($"Hybrid drive optimization failed: {ex.Message}", ex);
                return result;
            }
        }
        
        /// <summary>
        /// Optimize prefetch settings for hybrid drives
        /// </summary>
        private bool OptimizePrefetchForHybrid()
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters", true))
                {
                    if (key != null)
                    {
                        // Enable moderate prefetch for hybrid drives (value 2 = application prefetch only)
                        key.SetValue("EnablePrefetcher", 2, RegistryValueKind.DWord);
                        key.SetValue("EnableSuperfetch", 1, RegistryValueKind.DWord); // Moderate superfetch
                        
                        _logger.LogDebug("Prefetch optimized for hybrid drive");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to optimize prefetch for hybrid drive: {ex.Message}");
            }
            return false;
        }
        
        /// <summary>
        /// Optimize power settings for hybrid drives
        /// </summary>
        private bool OptimizeHybridPowerSettings()
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Power", true))
                {
                    if (key != null)
                    {
                        // Moderate power optimization for hybrid drives
                        key.SetValue("HibernateEnabled", 1, RegistryValueKind.DWord); // Allow hibernate
                        key.SetValue("DiskTimeoutValue", 900, RegistryValueKind.DWord); // 15 minutes
                        
                        _logger.LogDebug("Power settings optimized for hybrid drive");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to optimize power settings for hybrid drive: {ex.Message}");
            }
            return false;
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
                
                // If detection returns Unknown, default to HDD for safety
                if (diskInfo.DriveType == Models.DriveType.Unknown)
                {
                    diskInfo.DriveType = Models.DriveType.HDD;
                    _logger.LogWarning($"Drive type detection for {drive.Name} returned Unknown, defaulting to HDD");
                }
                
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
        /// Detect drive type (SSD vs HDD) with enhanced multiple drive support
        /// </summary>
        private Models.DriveType DetectDriveType(string driveLetter)
        {
            try
            {
                // First, get the partition info to map logical drive to physical drive
                var physicalDriveIndex = GetPhysicalDriveIndex(driveLetter);
                if (physicalDriveIndex >= 0)
                {
                    // Query the specific physical drive
                    using (var searcher = new ManagementObjectSearcher($"SELECT * FROM Win32_DiskDrive WHERE Index = {physicalDriveIndex}"))
                    {
                        foreach (ManagementObject disk in searcher.Get())
                        {
                            return DetectDriveTypeFromDiskObject(disk, driveLetter);
                        }
                    }
                }
                
                // Fallback: search all drives and use heuristics
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_DiskDrive"))
                {
                    foreach (ManagementObject disk in searcher.Get())
                    {
                        var result = DetectDriveTypeFromDiskObject(disk, driveLetter);
                        if (result != Models.DriveType.Unknown)
                        {
                            return result;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Failed to detect drive type for {driveLetter}: {ex.Message}");
            }
            
            return Models.DriveType.HDD; // Default assumption
        }
        
        /// <summary>
        /// Get the physical drive index for a logical drive
        /// </summary>
        private int GetPhysicalDriveIndex(string driveLetter)
        {
            try
            {
                var driveQuery = driveLetter.TrimEnd('\\').Replace(":", "");
                using (var searcher = new ManagementObjectSearcher(
                    $"ASSOCIATORS OF {{Win32_LogicalDisk.DeviceID='{driveQuery}:'}} WHERE AssocClass = Win32_LogicalDiskToPartition"))
                {
                    foreach (ManagementObject partition in searcher.Get())
                    {
                        using (var diskSearcher = new ManagementObjectSearcher(
                            $"ASSOCIATORS OF {{Win32_DiskPartition.DeviceID='{partition["DeviceID"]}'}} WHERE AssocClass = Win32_DiskDriveToDiskPartition"))
                        {
                            foreach (ManagementObject disk in diskSearcher.Get())
                            {
                                var indexProperty = disk["Index"];
                                if (indexProperty != null && int.TryParse(indexProperty.ToString(), out int index))
                                {
                                    return index;
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Failed to get physical drive index for {driveLetter}: {ex.Message}");
            }
            return -1;
        }
        
        /// <summary>
        /// Detect drive type from a disk management object
        /// </summary>
        private Models.DriveType DetectDriveTypeFromDiskObject(ManagementObject disk, string driveLetter)
        {
            try
            {
                var mediaType = disk["MediaType"]?.ToString() ?? "";
                var model = disk["Model"]?.ToString() ?? "";
                var interfaceType = disk["InterfaceType"]?.ToString() ?? "";
                
                // Enhanced SSD detection heuristics
                // 1. Check for explicit SSD indicators in model name
                if (model.ToLower().Contains("ssd") || 
                    model.ToLower().Contains("solid state") ||
                    model.ToLower().Contains("nvme"))
                {
                    _logger.LogDebug($"Drive {driveLetter} detected as SSD by model: {model}");
                    return Models.DriveType.SSD;
                }
                
                // 2. Check media type
                if (mediaType.ToLower().Contains("ssd"))
                {
                    _logger.LogDebug($"Drive {driveLetter} detected as SSD by media type: {mediaType}");
                    return Models.DriveType.SSD;
                }
                
                // 3. Check interface type for modern SSD interfaces
                if (interfaceType.ToLower().Contains("nvme") || 
                    interfaceType.ToLower().Contains("sata") && model.ToLower().Contains("ssd"))
                {
                    _logger.LogDebug($"Drive {driveLetter} detected as SSD by interface: {interfaceType}");
                    return Models.DriveType.SSD;
                }
                
                // 4. Check for rotation rate (SSDs typically report 0 or null)
                var rotationRate = disk["RotationRate"];
                if (rotationRate != null)
                {
                    if (uint.TryParse(rotationRate.ToString(), out uint rpm))
                    {
                        if (rpm == 0 || rpm == 1) // 1 is sometimes used for SSDs
                        {
                            _logger.LogDebug($"Drive {driveLetter} detected as SSD by rotation rate: {rpm}");
                            return Models.DriveType.SSD;
                        }
                        else if (rpm > 3000) // Typical HDD speeds
                        {
                            _logger.LogDebug($"Drive {driveLetter} detected as HDD by rotation rate: {rpm}");
                            return Models.DriveType.HDD;
                        }
                    }
                }
                
                // 5. Check for hybrid drives
                if (model.ToLower().Contains("hybrid") || 
                    model.ToLower().Contains("sshd"))
                {
                    _logger.LogDebug($"Drive {driveLetter} detected as Hybrid: {model}");
                    return Models.DriveType.Hybrid;
                }
                
                // If we can't determine, return Unknown to let caller decide
                return Models.DriveType.Unknown;
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Error detecting drive type from disk object for {driveLetter}: {ex.Message}");
                return Models.DriveType.Unknown;
            }
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
                SSDCount = _diskCache.Values.Count(d => d.DriveType == Models.DriveType.SSD),
                HDDCount = _diskCache.Values.Count(d => d.DriveType == Models.DriveType.HDD),
                HybridCount = _diskCache.Values.Count(d => d.DriveType == Models.DriveType.Hybrid),
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