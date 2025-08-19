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
        
        private NetworkOptimizationService()
        {
            _logger = LoggingService.Instance;
            _adminService = AdminService.Instance;
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
    }
}