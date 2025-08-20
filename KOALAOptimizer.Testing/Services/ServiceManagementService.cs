using System;
using System.Collections.Generic;
using System.ServiceProcess;
using Microsoft.Win32;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for managing Windows services for gaming optimization
    /// </summary>
    public class ServiceManagementService
    {
        private static readonly Lazy<ServiceManagementService> _instance = new Lazy<ServiceManagementService>(() => new ServiceManagementService());
        public static ServiceManagementService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        private readonly Dictionary<string, ServiceBackupEntry> _serviceBackups;
        
        private ServiceManagementService()
        {
            _logger = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _serviceBackups = new Dictionary<string, ServiceBackupEntry>();
            _logger.LogInfo("Service management service initialized");
        }
        
        /// <summary>
        /// Disable unnecessary services for gaming performance
        /// </summary>
        public bool DisableUnnecessaryServices()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Service management requires administrator privileges");
                    return false;
                }
                
                var servicesToDisable = new Dictionary<string, string>
                {
                    // Xbox services (from PowerShell)
                    { "XboxNetApiSvc", "Xbox Live Networking Service" },
                    { "XboxGipSvc", "Xbox Accessory Management Service" },
                    { "XblAuthManager", "Xbox Live Auth Manager" },
                    { "XblGameSave", "Xbox Live Game Save Service" },
                    
                    // System services (from PowerShell)
                    { "Spooler", "Print Spooler" },
                    { "SysMain", "SysMain (Superfetch)" },
                    { "DiagTrack", "Connected User Experiences and Telemetry" },
                    { "WSearch", "Windows Search" },
                    { "Fax", "Fax Service" },
                    { "RemoteRegistry", "Remote Registry" },
                    { "MapsBroker", "Downloaded Maps Manager" },
                    { "WMPNetworkSvc", "Windows Media Player Network Sharing Service" },
                    { "WpnUserService", "Windows Push Notifications User Service" },
                    { "bthserv", "Bluetooth Support Service" },
                    { "TabletInputService", "Tablet PC Input Service" },
                    { "TouchKeyboard", "Touch Keyboard and Handwriting Panel Service" },
                    { "WerSvc", "Windows Error Reporting Service" },
                    { "PcaSvc", "Program Compatibility Assistant Service" },
                    { "Themes", "Themes Service" },
                    { "BITS", "Background Intelligent Transfer Service" },
                    { "CryptSvc", "Cryptographic Services" },
                    
                    // GPU vendor services (from PowerShell)
                    { "NvTelemetryContainer", "NVIDIA Telemetry Container" },
                    { "AMD External Events", "AMD External Events Utility" },
                    
                    // Audio services (conditional)
                    { "AudioSrv", "Windows Audio" },
                    { "AudioEndpointBuilder", "Windows Audio Endpoint Builder" },
                    { "Audiosrv", "Windows Audio Service" }
                };
                    { "WSearch", "Windows Search" },
                    { "TabletInputService", "Tablet PC Input Service" },
                    { "Themes", "Themes Service" },
                    { "Fax", "Fax Service" },
                    { "MapsBroker", "Downloaded Maps Manager" },
                    { "lfsvc", "Geolocation Service" },
                    { "SharedAccess", "Internet Connection Sharing (ICS)" },
                    { "TrkWks", "Distributed Link Tracking Client" },
                    { "WbioSrvc", "Windows Biometric Service" }
                };
                
                int disabledCount = 0;
                foreach (var service in servicesToDisable)
                {
                    if (DisableService(service.Key, service.Value))
                    {
                        disabledCount++;
                    }
                }
                
                _logger.LogInfo($"Disabled {disabledCount} unnecessary services for gaming optimization");
                return disabledCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable unnecessary services: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Disable a specific Windows service
        /// </summary>
        public bool DisableService(string serviceName, string displayName = null)
        {
            try
            {
                using (var service = new ServiceController(serviceName))
                {
                    // Backup current service state
                    var backup = new ServiceBackupEntry
                    {
                        ServiceName = serviceName,
                        Status = service.Status.ToString(),
                        BackupTime = DateTime.Now
                    };
                    
                    // Get startup type from registry
                    using (var key = Registry.LocalMachine.OpenSubKey($@"SYSTEM\CurrentControlSet\Services\{serviceName}"))
                    {
                        if (key != null)
                        {
                            var startValue = key.GetValue("Start");
                            backup.StartType = startValue?.ToString() ?? "Unknown";
                        }
                    }
                    
                    _serviceBackups[serviceName] = backup;
                    
                    // Stop the service if it's running
                    if (service.Status == ServiceControllerStatus.Running)
                    {
                        service.Stop();
                        service.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30));
                        _logger.LogInfo($"Stopped service: {displayName ?? serviceName}");
                    }
                    
                    // Set service to disabled
                    SetServiceStartType(serviceName, ServiceStartMode.Disabled);
                    _logger.LogInfo($"Disabled service: {displayName ?? serviceName}");
                    
                    return true;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to disable service {serviceName}: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Configure MMCSS (Multimedia Class Scheduler Service) for gaming
        /// </summary>
        public bool ConfigureMMCSSForGaming()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("MMCSS configuration requires administrator privileges");
                    return false;
                }
                
                // Configure gaming task priority
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                    "Background Only", "False", RegistryValueKind.String);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                    "Scheduling Category", "High", RegistryValueKind.String);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                    "SFIO Priority", "High", RegistryValueKind.String);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                    "Priority", 8, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                    "Clock Rate", 10000, RegistryValueKind.DWord);
                
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
        /// Restore service states from backup
        /// </summary>
        public bool RestoreServiceStates()
        {
            try
            {
                int restoredCount = 0;
                foreach (var backup in _serviceBackups.Values)
                {
                    try
                    {
                        if (int.TryParse(backup.StartType, out int startType))
                        {
                            SetServiceStartType(backup.ServiceName, (ServiceStartMode)startType);
                            restoredCount++;
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Failed to restore service {backup.ServiceName}: {ex.Message}");
                    }
                }
                
                _logger.LogInfo($"Restored {restoredCount} services from backup");
                return restoredCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to restore service states: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Set service startup type
        /// </summary>
        private void SetServiceStartType(string serviceName, ServiceStartMode startMode)
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey($@"SYSTEM\CurrentControlSet\Services\{serviceName}", true))
                {
                    if (key != null)
                    {
                        key.SetValue("Start", (int)startMode, RegistryValueKind.DWord);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to set start type for service {serviceName}: {ex.Message}");
                throw;
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