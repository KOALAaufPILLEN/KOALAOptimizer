using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.Win32;
using Newtonsoft.Json;
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
                var json = JsonConvert.SerializeObject(backup, Formatting.Indented);
                File.WriteAllText(_backupFilePath, json);
                
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
                
                var json = File.ReadAllText(_backupFilePath);
                var backup = JsonConvert.DeserializeObject<BackupConfiguration>(json);
                
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
    }
}