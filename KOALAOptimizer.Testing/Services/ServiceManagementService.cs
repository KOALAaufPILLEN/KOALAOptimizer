using System;
using System.Collections.Generic;
using System.ServiceProcess;
using System.Linq;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for managing Windows services and their configurations
    /// </summary>
    public class ServiceManagementService
    {
        private static readonly Lazy<ServiceManagementService> _instance = new Lazy<ServiceManagementService>(() => new ServiceManagementService());
        public static ServiceManagementService Instance => _instance.Value;

        private readonly LoggingService _logger;
        private readonly Dictionary<string, ServiceBackupInfo> _serviceBackups;

        public event EventHandler<string> ServiceModified;

        private ServiceManagementService()
        {
            try
            {
                LoggingService.EmergencyLog("ServiceManagementService: Initializing...");
                _logger = LoggingService.Instance;
                _serviceBackups = new Dictionary<string, ServiceBackupInfo>();
                LoggingService.EmergencyLog("ServiceManagementService: Initialization completed");
                _logger?.LogInfo("Service management service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ServiceManagementService: Initialization failed - {ex.Message}");
                _logger?.LogError($"Failed to initialize ServiceManagementService: {ex.Message}", ex);
                
                // Initialize with minimal state to prevent null reference errors
                _serviceBackups = new Dictionary<string, ServiceBackupInfo>();
            }
        }

        /// <summary>
        /// Get all Windows services
        /// </summary>
        public List<ServiceInfo> GetAllServices()
        {
            try
            {
                var services = new List<ServiceInfo>();
                var serviceControllers = ServiceController.GetServices();

                foreach (var service in serviceControllers)
                {
                    try
                    {
                        services.Add(new ServiceInfo
                        {
                            ServiceName = service.ServiceName,
                            DisplayName = service.DisplayName,
                            Status = service.Status.ToString(),
                            StartType = GetServiceStartMode(service.ServiceName)
                        });
                    }
                    catch (Exception ex)
                    {
                        _logger?.LogWarning($"Failed to get info for service {service.ServiceName}: {ex.Message}");
                    }
                    finally
                    {
                        service?.Dispose();
                    }
                }

                return services;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get services: {ex.Message}", ex);
                return new List<ServiceInfo>();
            }
        }

        /// <summary>
        /// Get service startup mode
        /// </summary>
        private string GetServiceStartMode(string serviceName)
        {
            try
            {
                using (var service = new ServiceController(serviceName))
                {
                    // Note: ServiceStartMode is part of System.ServiceProcess
                    // This would require additional implementation to get startup mode
                    // For now, return a placeholder
                    return "Unknown";
                }
            }
            catch (Exception ex)
            {
                _logger?.LogWarning($"Failed to get start mode for service {serviceName}: {ex.Message}");
                return "Unknown";
            }
        }

        /// <summary>
        /// Backup service configuration before modification
        /// </summary>
        public bool BackupServiceConfiguration(string serviceName)
        {
            try
            {
                if (_serviceBackups.ContainsKey(serviceName))
                {
                    _logger?.LogInfo($"Service {serviceName} already backed up");
                    return true;
                }

                using (var service = new ServiceController(serviceName))
                {
                    var backup = new ServiceBackupInfo
                    {
                        ServiceName = serviceName,
                        DisplayName = service.DisplayName,
                        OriginalStatus = service.Status.ToString(),
                        OriginalStartType = GetServiceStartMode(serviceName),
                        BackupTime = DateTime.Now
                    };

                    _serviceBackups[serviceName] = backup;
                    _logger?.LogInfo($"Backed up configuration for service: {serviceName}");
                    return true;
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to backup service {serviceName}: {ex.Message}", ex);
                return false;
            }
        }

        /// <summary>
        /// Stop a Windows service
        /// </summary>
        public bool StopService(string serviceName, bool backup = true)
        {
            try
            {
                if (backup)
                {
                    BackupServiceConfiguration(serviceName);
                }

                using (var service = new ServiceController(serviceName))
                {
                    if (service.Status == ServiceControllerStatus.Stopped)
                    {
                        _logger?.LogInfo($"Service {serviceName} is already stopped");
                        return true;
                    }

                    service.Stop();
                    service.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30));
                    
                    _logger?.LogInfo($"Successfully stopped service: {serviceName}");
                    ServiceModified?.Invoke(this, serviceName);
                    return true;
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to stop service {serviceName}: {ex.Message}", ex);
                return false;
            }
        }

        /// <summary>
        /// Start a Windows service
        /// </summary>
        public bool StartService(string serviceName)
        {
            try
            {
                using (var service = new ServiceController(serviceName))
                {
                    if (service.Status == ServiceControllerStatus.Running)
                    {
                        _logger?.LogInfo($"Service {serviceName} is already running");
                        return true;
                    }

                    service.Start();
                    service.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30));
                    
                    _logger?.LogInfo($"Successfully started service: {serviceName}");
                    ServiceModified?.Invoke(this, serviceName);
                    return true;
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to start service {serviceName}: {ex.Message}", ex);
                return false;
            }
        }

        /// <summary>
        /// Restore service from backup
        /// </summary>
        public bool RestoreServiceConfiguration(string serviceName)
        {
            try
            {
                if (!_serviceBackups.ContainsKey(serviceName))
                {
                    _logger?.LogWarning($"No backup found for service: {serviceName}");
                    return false;
                }

                var backup = _serviceBackups[serviceName];
                
                // Restore service to its original state
                if (backup.OriginalStatus == "Running")
                {
                    StartService(serviceName);
                }
                else if (backup.OriginalStatus == "Stopped")
                {
                    StopService(serviceName, false);
                }

                _logger?.LogInfo($"Restored service configuration: {serviceName}");
                return true;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to restore service {serviceName}: {ex.Message}", ex);
                return false;
            }
        }

        /// <summary>
        /// Get service backup information
        /// </summary>
        public ServiceBackupInfo GetServiceBackup(string serviceName)
        {
            return _serviceBackups.ContainsKey(serviceName) ? _serviceBackups[serviceName] : null;
        }

        /// <summary>
        /// Get all backed up services
        /// </summary>
        public List<ServiceBackupInfo> GetAllBackups()
        {
            return _serviceBackups.Values.ToList();
        }

        /// <summary>
        /// Clear all service backups
        /// </summary>
        public void ClearBackups()
        {
            _serviceBackups.Clear();
            _logger?.LogInfo("Cleared all service backups");
        }

        /// <summary>
        /// Check if service exists
        /// </summary>
        public bool ServiceExists(string serviceName)
        {
            try
            {
                using (var service = new ServiceController(serviceName))
                {
                    _ = service.Status; // This will throw if service doesn't exist
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Get specific gaming-related services that can be optimized
        /// </summary>
        public List<ServiceInfo> GetGamingOptimizableServices()
        {
            var gamingServices = new List<string>
            {
                "XboxGipSvc",
                "XblAuthManager", 
                "XblGameSave",
                "XboxNetApiSvc",
                "Spooler",
                "Fax",
                "WSearch",
                "SysMain",
                "Themes"
            };

            var allServices = GetAllServices();
            return allServices.Where(s => gamingServices.Contains(s.ServiceName)).ToList();
        }
    }
}