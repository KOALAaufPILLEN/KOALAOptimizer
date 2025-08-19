using System;
using System.Management;
using Microsoft.Win32;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for power management optimizations
    /// </summary>
    public class PowerManagementService
    {
        private static readonly Lazy<PowerManagementService> _instance = new Lazy<PowerManagementService>(() => new PowerManagementService());
        public static PowerManagementService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        
        private PowerManagementService()
        {
            _logger = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _logger.LogInfo("Power management service initialized");
        }
        
        /// <summary>
        /// Apply ultimate performance power plan optimizations
        /// </summary>
        public bool ApplyUltimatePerformancePowerPlan()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Power plan optimization requires administrator privileges");
                    return false;
                }
                
                // Enable ultimate performance mode
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\943c8cb6-6f93-4227-ad87-e9a3feec08d1", 
                    "Attributes", 2, RegistryValueKind.DWord);
                
                // Disable CPU core parking
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583", 
                    "ValueMin", 0, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583", 
                    "ValueMax", 0, RegistryValueKind.DWord);
                
                // Disable CPU frequency scaling
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\75b0ae3f-bce0-45a7-8c89-c9611c25e100", 
                    "ValueMin", 100, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\75b0ae3f-bce0-45a7-8c89-c9611c25e100", 
                    "ValueMax", 100, RegistryValueKind.DWord);
                
                _logger.LogInfo("Ultimate performance power plan optimizations applied successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply power plan optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Disable CPU core parking for gaming performance
        /// </summary>
        public bool DisableCpuCoreParking()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("CPU core parking configuration requires administrator privileges");
                    return false;
                }
                
                // Disable CPU core parking
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583", 
                    "Attributes", 0, RegistryValueKind.DWord);
                
                // Set core parking to minimum
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling", 
                    "PowerThrottlingOff", 1, RegistryValueKind.DWord);
                
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
        public bool OptimizeCpuCStates()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("CPU C-States optimization requires administrator privileges");
                    return false;
                }
                
                // Disable CPU C-States for lower latency
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\68dd2f27-a4ce-4e11-8487-3794e4135dfa", 
                    "Attributes", 0, RegistryValueKind.DWord);
                
                // Set processor idle threshold
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\68dd2f27-a4ce-4e11-8487-3794e4135dfa", 
                    "ValueMin", 100, RegistryValueKind.DWord);
                
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
        /// Disable GPU power states for gaming
        /// </summary>
        public bool DisableGpuPowerStates()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("GPU power states configuration requires administrator privileges");
                    return false;
                }
                
                // Disable GPU power management
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", 
                    "TdrLevel", 0, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", 
                    "PlatformSupportMiracast", 0, RegistryValueKind.DWord);
                
                // Disable GPU preemption for lower latency
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler", 
                    "EnablePreemption", 0, RegistryValueKind.DWord);
                
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
        /// Helper method to set registry values safely
        /// </summary>
        private void SetRegistryValue(string keyPath, string valueName, object value, RegistryValueKind valueKind)
        {
            try
            {
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