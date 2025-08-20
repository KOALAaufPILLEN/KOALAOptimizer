using System;
using System.Collections.Generic;
using Microsoft.Win32;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for advanced network optimizations
    /// </summary>
    public class NetworkOptimizationService
    {
        private static readonly Lazy<NetworkOptimizationService> _instance = new Lazy<NetworkOptimizationService>(() => new NetworkOptimizationService());
        public static NetworkOptimizationService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        private readonly Dictionary<string, Dictionary<string, string>> _nicBackup;
        private readonly Dictionary<string, string> _netshTcpBackup;
        
        private NetworkOptimizationService()
        {
            _logger = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _nicBackup = new Dictionary<string, Dictionary<string, string>>();
            _netshTcpBackup = new Dictionary<string, string>();
            _logger.LogInfo("Network optimization service initialized");
        }
        
        /// <summary>
        /// Apply advanced TCP settings for gaming
        /// </summary>
        public bool ApplyAdvancedTcpSettings()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Advanced TCP settings require administrator privileges");
                    return false;
                }
                
                // Advanced TCP optimizations from PowerShell version
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                    "TcpTimedWaitDelay", 30, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                    "MaxUserPort", 65534, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                    "TcpNumConnections", 1024, RegistryValueKind.DWord);
                
                _logger.LogInfo("Advanced TCP settings applied successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply advanced TCP settings: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Enable Receive Side Scaling (RSS)
        /// </summary>
        public bool EnableReceiveSideScaling()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("RSS configuration requires administrator privileges");
                    return false;
                }
                
                // Enable RSS for network adapters
                var interfacesKey = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces";
                
                using (var baseKey = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"))
                {
                    if (baseKey != null)
                    {
                        foreach (var subKeyName in baseKey.GetSubKeyNames())
                        {
                            try
                            {
                                var fullPath = $@"{interfacesKey}\{subKeyName}";
                                SetRegistryValue(fullPath, "EnableRSS", 1, RegistryValueKind.DWord);
                                SetRegistryValue(fullPath, "RSSBaseCpu", 0, RegistryValueKind.DWord);
                                SetRegistryValue(fullPath, "RSSMaxCpus", 4, RegistryValueKind.DWord);
                            }
                            catch (Exception ex)
                            {
                                _logger.LogDebug($"Failed to configure RSS for interface {subKeyName}: {ex.Message}");
                            }
                        }
                    }
                }
                
                _logger.LogInfo("Receive Side Scaling (RSS) enabled successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to enable RSS: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Disable background network throttling
        /// </summary>
        public bool DisableBackgroundNetworkThrottling()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Network throttling configuration requires administrator privileges");
                    return false;
                }
                
                // Disable network throttling for gaming performance
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile", 
                    "NetworkThrottlingIndex", 10, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile", 
                    "SystemResponsiveness", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("Background network throttling disabled successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable network throttling: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize network latency for gaming
        /// </summary>
        public bool OptimizeNetworkLatency()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Network latency optimization requires administrator privileges");
                    return false;
                }
                
                // Gaming-specific network latency optimizations
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                    "EnableTCPChimney", 0, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                    "EnableRSS", 1, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                    "EnableNetDMA", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("Network latency optimizations applied successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize network latency: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Helper method to set registry values safely
        /// </summary>
        private void SetRegistryValue(string keyPath, string valueName, object value, RegistryValueKind valueKind)
        {
            try
            {
                // Convert HKEY_LOCAL_MACHINE path format to proper registry key
                var normalizedPath = keyPath.Replace(@"HKEY_LOCAL_MACHINE\", "");
                
                using (var key = Registry.LocalMachine.CreateSubKey(normalizedPath))
                {
                    if (key != null)
                    {
                        key.SetValue(valueName, value, valueKind);
                        _logger.LogDebug($"Set registry value: {keyPath}\\{valueName} = {value}");
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to set registry value {keyPath}\\{valueName}: {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Backup per-NIC registry settings (from PowerShell)
        /// </summary>
        public bool BackupPerNicSettings()
        {
            if (!_adminService.IsRunningAsAdmin())
            {
                _logger.LogWarning("Per-NIC backup requires administrator privileges");
                return false;
            }
            
            try
            {
                _nicBackup.Clear();
                
                var nicRoot = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces";
                using (var nicKey = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"))
                {
                    if (nicKey != null)
                    {
                        foreach (var subKeyName in nicKey.GetSubKeyNames())
                        {
                            using (var interfaceKey = nicKey.OpenSubKey(subKeyName))
                            {
                                if (interfaceKey != null)
                                {
                                    var settings = new Dictionary<string, string>();
                                    
                                    // Backup critical NIC settings
                                    var tcpAckFreq = interfaceKey.GetValue("TcpAckFrequency");
                                    var tcpNoDelay = interfaceKey.GetValue("TCPNoDelay");
                                    
                                    if (tcpAckFreq != null || tcpNoDelay != null)
                                    {
                                        if (tcpAckFreq != null) settings["TcpAckFrequency"] = tcpAckFreq.ToString();
                                        if (tcpNoDelay != null) settings["TCPNoDelay"] = tcpNoDelay.ToString();
                                        
                                        _nicBackup[$"{nicRoot}\\{subKeyName}"] = settings;
                                    }
                                }
                            }
                        }
                    }
                }
                
                _logger.LogInfo($"Backed up settings for {_nicBackup.Count} network interfaces");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to backup per-NIC settings: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Get netsh TCP global settings (PowerShell equivalent)
        /// </summary>
        public Dictionary<string, string> GetNetshTcpGlobal()
        {
            var settings = new Dictionary<string, string>();
            
            try
            {
                var process = new System.Diagnostics.Process
                {
                    StartInfo = new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = "netsh",
                        Arguments = "int tcp show global",
                        RedirectStandardOutput = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    }
                };
                
                process.Start();
                var output = process.StandardOutput.ReadToEnd();
                process.WaitForExit();
                
                // Parse netsh output
                var lines = output.Split('\n');
                foreach (var line in lines)
                {
                    var trimmedLine = line.Trim();
                    if (trimmedLine.Contains(':'))
                    {
                        var parts = trimmedLine.Split(':', 2);
                        if (parts.Length == 2)
                        {
                            var key = parts[0].Trim();
                            var value = parts[1].Trim();
                            settings[key] = value;
                        }
                    }
                }
                
                _logger.LogInfo($"Retrieved {settings.Count} netsh TCP global settings");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to get netsh TCP global settings: {ex.Message}", ex);
            }
            
            return settings;
        }
        
        /// <summary>
        /// Apply comprehensive network optimizations from PowerShell
        /// </summary>
        public bool ApplyComprehensiveNetworkOptimizations()
        {
            if (!_adminService.IsRunningAsAdmin())
            {
                _logger.LogWarning("Comprehensive network optimizations require administrator privileges");
                return false;
            }
            
            try
            {
                _logger.LogInfo("Applying comprehensive network optimizations from PowerShell...");
                
                // Backup current settings first
                BackupPerNicSettings();
                
                int successCount = 0;
                
                // Apply netsh TCP optimizations
                if (ApplyNetshTcpOptimizations()) successCount++;
                if (OptimizeNetworkLatency()) successCount++;
                if (EnableReceiveSideScaling()) successCount++;
                if (DisableBackgroundNetworkThrottling()) successCount++;
                if (ApplyPerNicOptimizations()) successCount++;
                
                _logger.LogInfo($"Comprehensive network optimizations completed: {successCount}/5 categories applied");
                return successCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply comprehensive network optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply netsh TCP optimizations (from PowerShell)
        /// </summary>
        private bool ApplyNetshTcpOptimizations()
        {
            try
            {
                var netshCommands = new[]
                {
                    "int tcp set global autotuninglevel=normal",
                    "int tcp set global timestamps=disabled", 
                    "int tcp set global ecncapability=disabled",
                    "int tcp set global rss=enabled",
                    "int tcp set global rsc=enabled"
                };
                
                int successCount = 0;
                foreach (var command in netshCommands)
                {
                    try
                    {
                        var process = new System.Diagnostics.Process
                        {
                            StartInfo = new System.Diagnostics.ProcessStartInfo
                            {
                                FileName = "netsh",
                                Arguments = command,
                                RedirectStandardOutput = true,
                                UseShellExecute = false,
                                CreateNoWindow = true
                            }
                        };
                        
                        process.Start();
                        process.WaitForExit();
                        
                        if (process.ExitCode == 0)
                        {
                            successCount++;
                            _logger.LogDebug($"Applied netsh command: {command}");
                        }
                        else
                        {
                            _logger.LogWarning($"Failed netsh command: {command}");
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Failed to execute netsh command '{command}': {ex.Message}");
                    }
                }
                
                _logger.LogInfo($"Applied {successCount}/{netshCommands.Length} netsh TCP optimizations");
                return successCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply netsh TCP optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply per-NIC optimizations
        /// </summary>
        private bool ApplyPerNicOptimizations()
        {
            try
            {
                var nicRoot = @"SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces";
                using (var nicKey = Registry.LocalMachine.OpenSubKey(nicRoot))
                {
                    if (nicKey != null)
                    {
                        int optimizedCount = 0;
                        
                        foreach (var subKeyName in nicKey.GetSubKeyNames())
                        {
                            using (var interfaceKey = Registry.LocalMachine.OpenSubKey($"{nicRoot}\\{subKeyName}", true))
                            {
                                if (interfaceKey != null)
                                {
                                    try
                                    {
                                        // Apply per-NIC optimizations
                                        interfaceKey.SetValue("TcpAckFrequency", 1, RegistryValueKind.DWord);
                                        interfaceKey.SetValue("TCPNoDelay", 1, RegistryValueKind.DWord);
                                        optimizedCount++;
                                    }
                                    catch (Exception ex)
                                    {
                                        _logger.LogDebug($"Failed to optimize interface {subKeyName}: {ex.Message}");
                                    }
                                }
                            }
                        }
                        
                        _logger.LogInfo($"Applied per-NIC optimizations to {optimizedCount} interfaces");
                        return optimizedCount > 0;
                    }
                }
                
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply per-NIC optimizations: {ex.Message}", ex);
                return false;
            }
        }
    }
}