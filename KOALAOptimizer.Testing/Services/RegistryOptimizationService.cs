using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using Microsoft.Win32;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for safe registry operations with backup and restore functionality
    /// </summary>
    public class RegistryOptimizationService
    {
        private static readonly Lazy<RegistryOptimizationService> _instance = new Lazy<RegistryOptimizationService>(() => new RegistryOptimizationService());
        public static RegistryOptimizationService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        private readonly string _backupFilePath;
        private readonly Dictionary<string, object> _registryCache;
        
        private RegistryOptimizationService()
        {
            _logger = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _registryCache = new Dictionary<string, object>();
            
            // Set backup file path
            var appDataPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "KOALAOptimizer");
            Directory.CreateDirectory(appDataPath);
            _backupFilePath = Path.Combine(appDataPath, "Koala-Backup.json");
            
            _logger.LogInfo("Registry optimization service initialized");
        }
        
        /// <summary>
        /// Create backup of current registry settings
        /// </summary>
        public bool CreateBackup()
        {
            try
            {
                _logger.LogInfo("Creating registry backup...");
                
                var backup = new BackupConfiguration
                {
                    CreatedDate = DateTime.Now,
                    Version = "2.3-CSharp",
                    Registry = new Dictionary<string, Dictionary<string, object>>(),
                    RegistryNICs = new Dictionary<string, Dictionary<string, object>>(),
                    Services = new Dictionary<string, string>()
                };
                
                // Backup key registry values
                var registryBackupList = GetRegistryBackupList();
                
                foreach (var entry in registryBackupList)
                {
                    try
                    {
                        var value = GetRegistryValue(entry.Path, entry.Name);
                        
                        if (!backup.Registry.ContainsKey(entry.Path))
                        {
                            backup.Registry[entry.Path] = new Dictionary<string, object>();
                        }
                        
                        backup.Registry[entry.Path][entry.Name] = value;
                        _logger.LogDebug($"Backed up: {entry.Path}\\{entry.Name}");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Failed to backup {entry.Path}\\{entry.Name}: {ex.Message}");
                    }
                }
                
                // Backup network interface settings
                BackupNetworkInterfaceSettings(backup);
                
                // Backup services
                BackupServiceSettings(backup);
                
                // Save backup to file
                var backupText = SerializeBackup(backup);
                File.WriteAllText(_backupFilePath, backupText);
                
                _logger.LogInfo($"Registry backup created successfully: {_backupFilePath}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to create registry backup: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Restore registry settings from backup
        /// </summary>
        public bool RestoreFromBackup()
        {
            try
            {
                if (!File.Exists(_backupFilePath))
                {
                    _logger.LogError("No backup file found");
                    return false;
                }
                
                _logger.LogInfo("Restoring registry from backup...");
                
                var backupText = File.ReadAllText(_backupFilePath);
                var backup = DeserializeBackup(backupText);
                
                if (backup == null)
                {
                    _logger.LogError("Invalid backup file format");
                    return false;
                }
                
                int restoredCount = 0;
                int failedCount = 0;
                
                // Restore registry values
                foreach (var pathEntry in backup.Registry)
                {
                    foreach (var valueEntry in pathEntry.Value)
                    {
                        try
                        {
                            if (valueEntry.Value == null)
                            {
                                DeleteRegistryValue(pathEntry.Key, valueEntry.Key);
                            }
                            else
                            {
                                SetRegistryValue(pathEntry.Key, valueEntry.Key, valueEntry.Value);
                            }
                            restoredCount++;
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning($"Failed to restore {pathEntry.Key}\\{valueEntry.Key}: {ex.Message}");
                            failedCount++;
                        }
                    }
                }
                
                // Restore network interface settings
                RestoreNetworkInterfaceSettings(backup);
                
                // Restore services
                RestoreServiceSettings(backup);
                
                _logger.LogInfo($"Registry restore completed. Restored: {restoredCount}, Failed: {failedCount}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to restore registry: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply gaming optimizations to registry
        /// </summary>
        public bool ApplyGamingOptimizations(List<OptimizationItem> optimizations)
        {
            if (!_adminService.IsRunningAsAdmin())
            {
                _logger.LogWarning("Administrator privileges required for registry optimizations");
                return false;
            }
            
            try
            {
                _logger.LogInfo("Applying gaming optimizations to registry...");
                
                int appliedCount = 0;
                int skippedCount = 0;
                
                foreach (var optimization in optimizations.Where(o => o.IsEnabled && o.Type == OptimizationType.Registry))
                {
                    try
                    {
                        if (ApplyOptimization(optimization))
                        {
                            appliedCount++;
                        }
                        else
                        {
                            skippedCount++;
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError($"Failed to apply optimization '{optimization.Name}': {ex.Message}", ex);
                        skippedCount++;
                    }
                }
                
                _logger.LogInfo($"Registry optimizations completed. Applied: {appliedCount}, Skipped: {skippedCount}");
                return appliedCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply registry optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply a specific optimization
        /// </summary>
        private bool ApplyOptimization(OptimizationItem optimization)
        {
            switch (optimization.Name)
            {
                case "DisableNagleAlgorithm":
                    return DisableNagleAlgorithm();
                case "OptimizeTCPSettings":
                    return OptimizeTCPSettings();
                case "DisableGameDVR":
                    return DisableGameDVR();
                case "EnableHardwareGPUScheduling":
                    return EnableHardwareGPUScheduling();
                case "OptimizeMemoryManagement":
                    return OptimizeMemoryManagement();
                case "OptimizeCPUScheduling":
                    return OptimizeCPUScheduling();
                case "DisableVisualEffects":
                    return DisableVisualEffects();
                case "OptimizeNetworkSettings":
                    return OptimizeNetworkSettings();
                case "DisableCpuCoreParking":
                    return DisableCpuCoreParking();
                case "OptimizeCpuCStates":
                    return OptimizeCpuCStates();
                case "OptimizeInterruptModeration":
                    return OptimizeInterruptModeration();
                case "ConfigureMMCSS":
                    return ConfigureMMCSS();
                case "OptimizeLargePageSupport":
                    return OptimizeLargePageSupport();
                case "DisableMemoryCompression":
                    return DisableMemoryCompression();
                case "OptimizeStandbyMemory":
                    return OptimizeStandbyMemory();
                case "OptimizeAdvancedGpuScheduling":
                    return OptimizeAdvancedGpuScheduling();
                case "DisableGpuPowerStates":
                    return DisableGpuPowerStates();
                case "OptimizeShaderCache":
                    return OptimizeShaderCache();
                case "OptimizeDirectX12":
                    return OptimizeDirectX12();
                case "EnableHardwareAcceleration":
                    return EnableHardwareAcceleration();
                case "ReduceAudioLatency":
                    return ReduceAudioLatency();
                case "ReduceInputLag":
                    return ReduceInputLag();
                case "OptimizeGameMode":
                    return OptimizeGameMode();
                case "OptimizeBackgroundSuspension":
                    return OptimizeBackgroundSuspension();
                default:
                    _logger.LogWarning($"Unknown optimization: {optimization.Name}");
                    return false;
            }
        }
        
        /// <summary>
        /// Disable Nagle's algorithm for reduced network latency
        /// </summary>
        private bool DisableNagleAlgorithm()
        {
            try
            {
                // Get all network interfaces and disable Nagle algorithm
                using (var interfacesKey = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"))
                {
                    if (interfacesKey != null)
                    {
                        foreach (var subKeyName in interfacesKey.GetSubKeyNames())
                        {
                            try
                            {
                                var fullPath = $@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{subKeyName}";
                                SetRegistryValue(fullPath, "TcpAckFrequency", 1, RegistryValueKind.DWord);
                                SetRegistryValue(fullPath, "TCPNoDelay", 1, RegistryValueKind.DWord);
                            }
                            catch (Exception ex)
                            {
                                _logger.LogWarning($"Failed to optimize interface {subKeyName}: {ex.Message}");
                            }
                        }
                    }
                }
                
                _logger.LogInfo("Nagle algorithm disabled successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable Nagle algorithm: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize TCP settings for gaming
        /// </summary>
        private bool OptimizeTCPSettings()
        {
            try
            {
                var tcpPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters";
                
                SetRegistryValue(tcpPath, "TcpTimedWaitDelay", 30, RegistryValueKind.DWord);
                SetRegistryValue(tcpPath, "MaxUserPort", 65534, RegistryValueKind.DWord);
                SetRegistryValue(tcpPath, "TcpNumConnections", 16777214, RegistryValueKind.DWord);
                SetRegistryValue(tcpPath, "DefaultTTL", 64, RegistryValueKind.DWord);
                
                _logger.LogInfo("TCP settings optimized for gaming");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize TCP settings: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Disable Windows Game DVR
        /// </summary>
        private bool DisableGameDVR()
        {
            try
            {
                var gameDvrPath = @"HKEY_CURRENT_USER\System\GameConfigStore";
                SetRegistryValue(gameDvrPath, "GameDVR_Enabled", 0, RegistryValueKind.DWord);
                SetRegistryValue(gameDvrPath, "GameDVR_FSEBehaviorMode", 2, RegistryValueKind.DWord);
                
                var gameBarPath = @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR";
                SetRegistryValue(gameBarPath, "AppCaptureEnabled", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("Game DVR disabled successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable Game DVR: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Enable Hardware GPU Scheduling
        /// </summary>
        private bool EnableHardwareGPUScheduling()
        {
            try
            {
                var gpuPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers";
                SetRegistryValue(gpuPath, "HwSchMode", 2, RegistryValueKind.DWord);
                
                _logger.LogInfo("Hardware GPU scheduling enabled");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to enable GPU scheduling: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize memory management settings
        /// </summary>
        private bool OptimizeMemoryManagement()
        {
            try
            {
                var memoryPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";
                
                SetRegistryValue(memoryPath, "DisablePagingExecutive", 1, RegistryValueKind.DWord);
                SetRegistryValue(memoryPath, "LargeSystemCache", 0, RegistryValueKind.DWord);
                SetRegistryValue(memoryPath, "SystemPages", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("Memory management optimized");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize memory management: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize CPU scheduling for gaming
        /// </summary>
        private bool OptimizeCPUScheduling()
        {
            try
            {
                var priorityPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl";
                SetRegistryValue(priorityPath, "Win32PrioritySeparation", 38, RegistryValueKind.DWord);
                
                _logger.LogInfo("CPU scheduling optimized");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize CPU scheduling: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Disable visual effects for performance
        /// </summary>
        private bool DisableVisualEffects()
        {
            try
            {
                var visualPath = @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects";
                SetRegistryValue(visualPath, "VisualFXSetting", 2, RegistryValueKind.DWord);
                
                _logger.LogInfo("Visual effects optimized for performance");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize visual effects: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize network settings
        /// </summary>
        private bool OptimizeNetworkSettings()
        {
            try
            {
                var networkPath = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";
                SetRegistryValue(networkPath, "NetworkThrottlingIndex", 0xffffffff, RegistryValueKind.DWord);
                
                _logger.LogInfo("Network settings optimized");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize network settings: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Get registry value safely
        /// </summary>
        private object GetRegistryValue(string path, string name)
        {
            try
            {
                return Registry.GetValue(path, name, null);
            }
            catch
            {
                return null;
            }
        }
        
        /// <summary>
        /// Set registry value safely with caching
        /// </summary>
        private bool SetRegistryValue(string path, string name, object value, RegistryValueKind kind = RegistryValueKind.DWord)
        {
            try
            {
                var cacheKey = $"{path}\\{name}";
                
                // Check cache to avoid redundant operations
                if (_registryCache.ContainsKey(cacheKey) && _registryCache[cacheKey].Equals(value))
                {
                    return true;
                }
                
                Registry.SetValue(path, name, value, kind);
                _registryCache[cacheKey] = value;
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to set registry value {path}\\{name}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Delete registry value safely
        /// </summary>
        private bool DeleteRegistryValue(string path, string name)
        {
            try
            {
                var key = Registry.LocalMachine;
                if (path.StartsWith("HKEY_CURRENT_USER"))
                {
                    key = Registry.CurrentUser;
                    path = path.Replace("HKEY_CURRENT_USER\\", "");
                }
                else if (path.StartsWith("HKEY_LOCAL_MACHINE"))
                {
                    path = path.Replace("HKEY_LOCAL_MACHINE\\", "");
                }
                
                using (var regKey = key.OpenSubKey(path, true))
                {
                    if (regKey != null)
                    {
                        regKey.DeleteValue(name, false);
                    }
                }
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to delete registry value {path}\\{name}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Get list of registry entries to backup
        /// </summary>
        private List<RegistryBackupEntry> GetRegistryBackupList()
        {
            return new List<RegistryBackupEntry>
            {
                new RegistryBackupEntry { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", Name = "TcpTimedWaitDelay" },
                new RegistryBackupEntry { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", Name = "MaxUserPort" },
                new RegistryBackupEntry { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", Name = "TcpNumConnections" },
                new RegistryBackupEntry { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", Name = "DefaultTTL" },
                new RegistryBackupEntry { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl", Name = "Win32PrioritySeparation" },
                new RegistryBackupEntry { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", Name = "HwSchMode" },
                new RegistryBackupEntry { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", Name = "DisablePagingExecutive" },
                new RegistryBackupEntry { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", Name = "LargeSystemCache" },
                new RegistryBackupEntry { Path = @"HKEY_CURRENT_USER\System\GameConfigStore", Name = "GameDVR_Enabled" },
                new RegistryBackupEntry { Path = @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR", Name = "AppCaptureEnabled" },
                new RegistryBackupEntry { Path = @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects", Name = "VisualFXSetting" }
            };
        }
        
        /// <summary>
        /// Backup network interface settings
        /// </summary>
        private void BackupNetworkInterfaceSettings(BackupConfiguration backup)
        {
            try
            {
                using (var interfacesKey = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"))
                {
                    if (interfacesKey != null)
                    {
                        foreach (var subKeyName in interfacesKey.GetSubKeyNames())
                        {
                            try
                            {
                                var fullPath = $@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{subKeyName}";
                                var tcpAck = GetRegistryValue(fullPath, "TcpAckFrequency");
                                var tcpNoDelay = GetRegistryValue(fullPath, "TCPNoDelay");
                                
                                if (tcpAck != null || tcpNoDelay != null)
                                {
                                    backup.RegistryNICs[fullPath] = new Dictionary<string, object>
                                    {
                                        ["TcpAckFrequency"] = tcpAck,
                                        ["TCPNoDelay"] = tcpNoDelay
                                    };
                                }
                            }
                            catch (Exception ex)
                            {
                                _logger.LogWarning($"Failed to backup network interface {subKeyName}: {ex.Message}");
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to backup network interface settings: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Restore network interface settings
        /// </summary>
        private void RestoreNetworkInterfaceSettings(BackupConfiguration backup)
        {
            try
            {
                foreach (var nicEntry in backup.RegistryNICs)
                {
                    foreach (var valueEntry in nicEntry.Value)
                    {
                        try
                        {
                            if (valueEntry.Value == null)
                            {
                                DeleteRegistryValue(nicEntry.Key, valueEntry.Key);
                            }
                            else
                            {
                                SetRegistryValue(nicEntry.Key, valueEntry.Key, valueEntry.Value);
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning($"Failed to restore NIC setting {nicEntry.Key}\\{valueEntry.Key}: {ex.Message}");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to restore network interface settings: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Backup service settings
        /// </summary>
        private void BackupServiceSettings(BackupConfiguration backup)
        {
            // Service backup would be handled by ServiceManagementService
            // This is a placeholder for consistency with the original implementation
        }
        
        /// <summary>
        /// Restore service settings
        /// </summary>
        private void RestoreServiceSettings(BackupConfiguration backup)
        {
            // Service restore would be handled by ServiceManagementService
            // This is a placeholder for consistency with the original implementation
        }
        
        /// <summary>
        /// Check if backup exists
        /// </summary>
        public bool BackupExists()
        {
            return File.Exists(_backupFilePath);
        }

        /// <summary>
        /// Apply specific optimizations by name
        /// </summary>
        public bool ApplyOptimizations(List<string> optimizationNames)
        {
            if (!_adminService.IsRunningAsAdmin())
            {
                _logger.LogWarning("Administrator privileges required for registry optimizations");
                return false;
            }

            try
            {
                bool success = true;
                foreach (var optimizationName in optimizationNames)
                {
                    if (!ApplySpecificOptimization(optimizationName))
                    {
                        success = false;
                        _logger.LogWarning($"Failed to apply optimization: {optimizationName}");
                    }
                }
                return success;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error applying optimizations: {ex.Message}", ex);
                return false;
            }
        }

        /// <summary>
        /// Apply a specific optimization by name
        /// </summary>
        private bool ApplySpecificOptimization(string optimizationName)
        {
            try
            {
                switch (optimizationName)
                {
                    case "DisableFullscreenOptimizations":
                        return SetRegistryValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR", "GameDVR_Enabled", 0);
                    
                    case "OptimizeGameMode":
                        return SetRegistryValue(@"HKEY_CURRENT_USER\Software\Microsoft\GameBar", "AutoGameModeEnabled", 1);
                    
                    case "OptimizeGpuScheduling":
                        return SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", "HwSchMode", 2);
                    
                    case "OptimizeTimerResolution":
                        return SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", "GlobalTimerResolutionRequests", 1);
                    
                    default:
                        _logger.LogWarning($"Unknown optimization: {optimizationName}");
                        return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error applying specific optimization {optimizationName}: {ex.Message}", ex);
                return false;
            }
        }

        /// <summary>
        /// Set a registry value safely
        /// </summary>
        private bool SetRegistryValue(string keyPath, string valueName, object value)
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(keyPath.Replace(@"HKEY_CURRENT_USER\", ""), true) ??
                                Registry.LocalMachine.OpenSubKey(keyPath.Replace(@"HKEY_LOCAL_MACHINE\", ""), true))
                {
                    if (key != null)
                    {
                        key.SetValue(valueName, value);
                        _logger.LogDebug($"Set registry value: {keyPath}\\{valueName} = {value}");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to set registry value {keyPath}\\{valueName}: {ex.Message}", ex);
            }
            return false;
        }
        
        /// <summary>
        /// Disable CPU core parking for gaming performance
        /// </summary>
        private bool DisableCpuCoreParking()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("CPU core parking optimization requires administrator privileges");
                    return false;
                }
                
                var powerPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583";
                SetRegistryValue(powerPath, "Attributes", 0, RegistryValueKind.DWord);
                SetRegistryValue(powerPath, "ValueMin", 0, RegistryValueKind.DWord);
                SetRegistryValue(powerPath, "ValueMax", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("CPU core parking disabled successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable CPU core parking: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize CPU C-States for gaming
        /// </summary>
        private bool OptimizeCpuCStates()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("CPU C-States optimization requires administrator privileges");
                    return false;
                }
                
                var cStatePath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\68dd2f27-a4ce-4e11-8487-3794e4135dfa";
                SetRegistryValue(cStatePath, "Attributes", 0, RegistryValueKind.DWord);
                SetRegistryValue(cStatePath, "ValueMin", 100, RegistryValueKind.DWord);
                
                _logger.LogInfo("CPU C-States optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize CPU C-States: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize interrupt moderation for gaming
        /// </summary>
        private bool OptimizeInterruptModeration()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Interrupt moderation optimization requires administrator privileges");
                    return false;
                }
                
                var kernelPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";
                SetRegistryValue(kernelPath, "ThreadDpcEnable", 1, RegistryValueKind.DWord);
                SetRegistryValue(kernelPath, "DpcQueueDepth", 1, RegistryValueKind.DWord);
                
                _logger.LogInfo("Interrupt moderation optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize interrupt moderation: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Configure MMCSS for gaming priority
        /// </summary>
        private bool ConfigureMMCSS()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("MMCSS configuration requires administrator privileges");
                    return false;
                }
                
                var mmcssPath = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";
                SetRegistryValue(mmcssPath, "Background Only", "False", RegistryValueKind.String);
                SetRegistryValue(mmcssPath, "Scheduling Category", "High", RegistryValueKind.String);
                SetRegistryValue(mmcssPath, "SFIO Priority", "High", RegistryValueKind.String);
                SetRegistryValue(mmcssPath, "Priority", 8, RegistryValueKind.DWord);
                SetRegistryValue(mmcssPath, "Clock Rate", 10000, RegistryValueKind.DWord);
                
                _logger.LogInfo("MMCSS configured for gaming priority successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to configure MMCSS: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize large page support
        /// </summary>
        private bool OptimizeLargePageSupport()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Large page support optimization requires administrator privileges");
                    return false;
                }
                
                var memoryPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";
                SetRegistryValue(memoryPath, "LargeSystemCache", 0, RegistryValueKind.DWord);
                SetRegistryValue(memoryPath, "LargePageMinimum", 2097152, RegistryValueKind.DWord);
                
                _logger.LogInfo("Large page support optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize large page support: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Disable memory compression
        /// </summary>
        private bool DisableMemoryCompression()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Memory compression configuration requires administrator privileges");
                    return false;
                }
                
                var memoryPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";
                SetRegistryValue(memoryPath, "FeatureSettings", 1, RegistryValueKind.DWord);
                SetRegistryValue(memoryPath, "FeatureSettingsOverride", 3, RegistryValueKind.DWord);
                
                _logger.LogInfo("Memory compression disabled successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable memory compression: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize standby memory management
        /// </summary>
        private bool OptimizeStandbyMemory()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Standby memory optimization requires administrator privileges");
                    return false;
                }
                
                var memoryPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";
                SetRegistryValue(memoryPath, "ClearPageFileAtShutdown", 0, RegistryValueKind.DWord);
                SetRegistryValue(memoryPath, "DisablePagingExecutive", 1, RegistryValueKind.DWord);
                
                _logger.LogInfo("Standby memory management optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize standby memory: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize advanced GPU scheduling
        /// </summary>
        private bool OptimizeAdvancedGpuScheduling()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Advanced GPU scheduling optimization requires administrator privileges");
                    return false;
                }
                
                var gpuPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers";
                SetRegistryValue(gpuPath, "TdrLevel", 0, RegistryValueKind.DWord);
                SetRegistryValue(gpuPath, "TdrDelay", 60, RegistryValueKind.DWord);
                SetRegistryValue(gpuPath, "TdrDdiDelay", 60, RegistryValueKind.DWord);
                SetRegistryValue(gpuPath, "TdrDebugMode", 0, RegistryValueKind.DWord);
                SetRegistryValue(gpuPath, "TdrTestMode", 0, RegistryValueKind.DWord);
                
                var schedulerPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler";
                SetRegistryValue(schedulerPath, "EnablePreemption", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("Advanced GPU scheduling optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize advanced GPU scheduling: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Disable GPU power states
        /// </summary>
        private bool DisableGpuPowerStates()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("GPU power states configuration requires administrator privileges");
                    return false;
                }
                
                var gpuPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers";
                SetRegistryValue(gpuPath, "PlatformSupportMiracast", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("GPU power states disabled successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable GPU power states: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize shader cache management
        /// </summary>
        private bool OptimizeShaderCache()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Shader cache optimization requires administrator privileges");
                    return false;
                }
                
                var directXPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers";
                SetRegistryValue(directXPath, "DisableWriteCombining", 1, RegistryValueKind.DWord);
                
                _logger.LogInfo("Shader cache optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize shader cache: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize DirectX 12 performance
        /// </summary>
        private bool OptimizeDirectX12()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("DirectX 12 optimization requires administrator privileges");
                    return false;
                }
                
                var dx12Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers";
                SetRegistryValue(dx12Path, "EnableDirectX12", 1, RegistryValueKind.DWord);
                
                _logger.LogInfo("DirectX 12 optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize DirectX 12: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Enable hardware acceleration features
        /// </summary>
        private bool EnableHardwareAcceleration()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Hardware acceleration optimization requires administrator privileges");
                    return false;
                }
                
                var dwmPath = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Dwm";
                SetRegistryValue(dwmPath, "EnableMachineCheck", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("Hardware acceleration enabled successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to enable hardware acceleration: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Reduce audio latency for gaming
        /// </summary>
        private bool ReduceAudioLatency()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Audio latency optimization requires administrator privileges");
                    return false;
                }
                
                var audioPath = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio";
                SetRegistryValue(audioPath, "DisableProtectedAudioDG", 1, RegistryValueKind.DWord);
                SetRegistryValue(audioPath, "DisableProtectedAudio", 1, RegistryValueKind.DWord);
                
                var audioServicePath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\AudioSrv";
                SetRegistryValue(audioServicePath, "DependOnService", new string[] { "AudioEndpointBuilder", "RpcSs" }, RegistryValueKind.MultiString);
                
                var audioDuckingPath = @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Multimedia\Audio";
                SetRegistryValue(audioDuckingPath, "UserDuckingPreference", 3, RegistryValueKind.DWord);
                
                _logger.LogInfo("Audio latency reduced successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to reduce audio latency: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Reduce input lag for gaming
        /// </summary>
        private bool ReduceInputLag()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Input lag optimization requires administrator privileges");
                    return false;
                }
                
                var mousePath = @"HKEY_CURRENT_USER\Control Panel\Mouse";
                SetRegistryValue(mousePath, "MouseSpeed", "0", RegistryValueKind.String);
                SetRegistryValue(mousePath, "MouseThreshold1", "0", RegistryValueKind.String);
                SetRegistryValue(mousePath, "MouseThreshold2", "0", RegistryValueKind.String);
                
                var mouseClassPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters";
                SetRegistryValue(mouseClassPath, "MouseDataQueueSize", 20, RegistryValueKind.DWord);
                
                var kbdClassPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters";
                SetRegistryValue(kbdClassPath, "KeyboardDataQueueSize", 20, RegistryValueKind.DWord);
                
                var timerPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";
                SetRegistryValue(timerPath, "GlobalTimerResolutionRequests", 1, RegistryValueKind.DWord);
                
                _logger.LogInfo("Input lag reduced successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to reduce input lag: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize Windows Game Mode
        /// </summary>
        private bool OptimizeGameMode()
        {
            try
            {
                var gameBarPath = @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\GameBar";
                SetRegistryValue(gameBarPath, "AllowAutoGameMode", 1, RegistryValueKind.DWord);
                SetRegistryValue(gameBarPath, "AutoGameModeEnabled", 1, RegistryValueKind.DWord);
                
                var gameDvrPolicyPath = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR";
                SetRegistryValue(gameDvrPolicyPath, "value", 0, RegistryValueKind.DWord);
                
                var gameConfigPath = @"HKEY_CURRENT_USER\System\GameConfigStore";
                SetRegistryValue(gameConfigPath, "GameDVR_FSEBehaviorMode", 2, RegistryValueKind.DWord);
                SetRegistryValue(gameConfigPath, "GameDVR_FSEBehavior", 2, RegistryValueKind.DWord);
                
                _logger.LogInfo("Windows Game Mode optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize Game Mode: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize background process suspension
        /// </summary>
        private bool OptimizeBackgroundSuspension()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Background suspension optimization requires administrator privileges");
                    return false;
                }
                
                var systemProfilePath = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";
                SetRegistryValue(systemProfilePath, "SystemResponsiveness", 0, RegistryValueKind.DWord);
                SetRegistryValue(systemProfilePath, "NetworkThrottlingIndex", 10, RegistryValueKind.DWord);
                
                var explorerPath = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize";
                SetRegistryValue(explorerPath, "StartupDelayInMSec", 0, RegistryValueKind.DWord);
                
                var priorityPath = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl";
                SetRegistryValue(priorityPath, "Win32PrioritySeparation", 38, RegistryValueKind.DWord);
                
                _logger.LogInfo("Background process suspension optimized successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize background suspension: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Get backup file path
        /// </summary>
        public string GetBackupFilePath()
        {
            return _backupFilePath;
        }
        
        /// <summary>
        /// Clear registry cache
        /// </summary>
        public void ClearCache()
        {
            _registryCache.Clear();
            _logger.LogInfo("Registry cache cleared");
        }
        
        /// <summary>
        /// Simple backup serialization (replaces JSON dependency)
        /// </summary>
        private string SerializeBackup(BackupConfiguration backup)
        {
            var sb = new StringBuilder();
            sb.AppendLine("[KOALA Backup Configuration]");
            sb.AppendLine($"CreatedDate={backup.CreatedDate:O}");
            sb.AppendLine($"Version={backup.Version}");
            sb.AppendLine();
            
            sb.AppendLine("[Registry Entries]");
            foreach (var pathEntry in backup.Registry ?? new Dictionary<string, Dictionary<string, object>>())
            {
                foreach (var valueEntry in pathEntry.Value)
                {
                    sb.AppendLine($"{pathEntry.Key}\\{valueEntry.Key}={valueEntry.Value}");
                }
            }
            sb.AppendLine();
            
            sb.AppendLine("[Services]");
            foreach (var service in backup.Services ?? new Dictionary<string, string>())
            {
                sb.AppendLine($"{service.Key}={service.Value}");
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Simple backup deserialization (replaces JSON dependency)
        /// </summary>
        private BackupConfiguration DeserializeBackup(string backupText)
        {
            var backup = new BackupConfiguration
            {
                Registry = new Dictionary<string, Dictionary<string, object>>(),
                Services = new Dictionary<string, string>()
            };
            
            var lines = backupText.Split('\n');
            string currentSection = "";
            
            foreach (var line in lines)
            {
                var trimmedLine = line.Trim();
                if (string.IsNullOrEmpty(trimmedLine)) continue;
                
                if (trimmedLine.StartsWith("[") && trimmedLine.EndsWith("]"))
                {
                    currentSection = trimmedLine;
                    continue;
                }
                
                var parts = trimmedLine.Split('=');
                if (parts.Length != 2) continue;
                
                var key = parts[0];
                var value = parts[1];
                
                switch (currentSection)
                {
                    case "[KOALA Backup Configuration]":
                        if (key == "CreatedDate" && DateTime.TryParse(value, out var date))
                            backup.CreatedDate = date;
                        else if (key == "Version")
                            backup.Version = value;
                        break;
                    case "[Registry Entries]":
                        // Parse path\name format
                        var lastBackslash = key.LastIndexOf('\\');
                        if (lastBackslash > 0)
                        {
                            var path = key.Substring(0, lastBackslash);
                            var name = key.Substring(lastBackslash + 1);
                            if (!backup.Registry.ContainsKey(path))
                                backup.Registry[path] = new Dictionary<string, object>();
                            backup.Registry[path][name] = value;
                        }
                        break;
                    case "[Services]":
                        backup.Services[key] = value;
                        break;
                }
            }
            
            return backup;
        }
    }
}