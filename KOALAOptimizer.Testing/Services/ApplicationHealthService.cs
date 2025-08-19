using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Threading;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for monitoring application health and system state
    /// </summary>
    public class ApplicationHealthService
    {
        private static readonly Lazy<ApplicationHealthService> _instance = new Lazy<ApplicationHealthService>(() => new ApplicationHealthService());
        public static ApplicationHealthService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly DispatcherTimer _healthCheckTimer;
        private readonly Dictionary<string, HealthCheck> _healthChecks;
        private bool _isMonitoring = false;
        
        public event EventHandler<HealthStatusChangedEventArgs> HealthStatusChanged;
        public event EventHandler<HealthCheckEventArgs> HealthCheckCompleted;
        
        public ApplicationHealthStatus CurrentStatus { get; private set; }
        public DateTime LastHealthCheck { get; private set; }
        
        private ApplicationHealthService()
        {
            try
            {
                LoggingService.EmergencyLog("ApplicationHealthService: Initializing...");
                _logger = LoggingService.Instance;
                _healthChecks = new Dictionary<string, HealthCheck>();
                CurrentStatus = new ApplicationHealthStatus();
                
                // Initialize health check timer (every 30 seconds)
                _healthCheckTimer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromSeconds(30)
                };
                _healthCheckTimer.Tick += HealthCheckTimer_Tick;
                
                InitializeHealthChecks();
                LoggingService.EmergencyLog("ApplicationHealthService: Initialization completed");
                _logger?.LogInfo("Application health service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ApplicationHealthService: Initialization failed - {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Initialize built-in health checks
        /// </summary>
        private void InitializeHealthChecks()
        {
            // Memory usage check
            RegisterHealthCheck("MemoryUsage", () =>
            {
                try
                {
                    var process = Process.GetCurrentProcess();
                    var memoryMB = process.WorkingSet64 / (1024 * 1024);
                    
                    if (memoryMB > 1000) // Over 1GB
                    {
                        return new HealthCheckResult
                        {
                            IsHealthy = false,
                            Message = $"High memory usage: {memoryMB} MB",
                            Recommendation = "Consider restarting the application if performance degrades"
                        };
                    }
                    else if (memoryMB > 500) // Over 500MB
                    {
                        return new HealthCheckResult
                        {
                            IsHealthy = true,
                            Message = $"Elevated memory usage: {memoryMB} MB",
                            Recommendation = "Memory usage is elevated but within acceptable limits"
                        };
                    }
                    
                    return new HealthCheckResult
                    {
                        IsHealthy = true,
                        Message = $"Memory usage normal: {memoryMB} MB"
                    };
                }
                catch (Exception ex)
                {
                    return new HealthCheckResult
                    {
                        IsHealthy = false,
                        Message = $"Memory check failed: {ex.Message}",
                        Recommendation = "Unable to monitor memory usage"
                    };
                }
            });
            
            // Service availability check
            RegisterHealthCheck("ServiceAvailability", () =>
            {
                try
                {
                    var issues = new List<string>();
                    
                    // Check logging service
                    try
                    {
                        _logger?.LogDebug("Health check: Testing logging service");
                    }
                    catch (Exception ex)
                    {
                        issues.Add($"Logging service: {ex.Message}");
                    }
                    
                    // Check admin service
                    try
                    {
                        var adminService = AdminService.Instance;
                        adminService.IsRunningAsAdmin();
                    }
                    catch (Exception ex)
                    {
                        issues.Add($"Admin service: {ex.Message}");
                    }
                    
                    // Check performance monitoring
                    try
                    {
                        var perfService = PerformanceMonitoringService.Instance;
                        // Non-intrusive check
                    }
                    catch (Exception ex)
                    {
                        issues.Add($"Performance monitoring: {ex.Message}");
                    }
                    
                    if (issues.Count == 0)
                    {
                        return new HealthCheckResult
                        {
                            IsHealthy = true,
                            Message = "All core services operational"
                        };
                    }
                    else
                    {
                        return new HealthCheckResult
                        {
                            IsHealthy = false,
                            Message = $"Service issues detected: {string.Join(", ", issues)}",
                            Recommendation = "Some services may need recovery. Check application logs for details."
                        };
                    }
                }
                catch (Exception ex)
                {
                    return new HealthCheckResult
                    {
                        IsHealthy = false,
                        Message = $"Service availability check failed: {ex.Message}",
                        Recommendation = "Unable to verify service status"
                    };
                }
            });
            
            // Thread pool health check
            RegisterHealthCheck("ThreadPoolHealth", () =>
            {
                try
                {
                    ThreadPool.GetAvailableThreads(out int workerThreads, out int completionPortThreads);
                    ThreadPool.GetMaxThreads(out int maxWorkerThreads, out int maxCompletionPortThreads);
                    
                    var workerUtilization = (double)(maxWorkerThreads - workerThreads) / maxWorkerThreads * 100;
                    
                    if (workerUtilization > 80)
                    {
                        return new HealthCheckResult
                        {
                            IsHealthy = false,
                            Message = $"Thread pool heavily utilized: {workerUtilization:F1}%",
                            Recommendation = "High thread usage detected. Application may be under stress."
                        };
                    }
                    else if (workerUtilization > 50)
                    {
                        return new HealthCheckResult
                        {
                            IsHealthy = true,
                            Message = $"Thread pool moderately utilized: {workerUtilization:F1}%",
                            Recommendation = "Thread usage is elevated but manageable"
                        };
                    }
                    
                    return new HealthCheckResult
                    {
                        IsHealthy = true,
                        Message = $"Thread pool healthy: {workerUtilization:F1}% utilized"
                    };
                }
                catch (Exception ex)
                {
                    return new HealthCheckResult
                    {
                        IsHealthy = false,
                        Message = $"Thread pool check failed: {ex.Message}",
                        Recommendation = "Unable to monitor thread pool status"
                    };
                }
            });
            
            // Disk space check
            RegisterHealthCheck("DiskSpace", () =>
            {
                try
                {
                    var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                    var drive = new DriveInfo(Path.GetPathRoot(appDataPath));
                    
                    var freeSpaceGB = drive.AvailableFreeSpace / (1024 * 1024 * 1024);
                    var totalSpaceGB = drive.TotalSize / (1024 * 1024 * 1024);
                    var usagePercent = (double)(totalSpaceGB - freeSpaceGB) / totalSpaceGB * 100;
                    
                    if (freeSpaceGB < 1) // Less than 1GB free
                    {
                        return new HealthCheckResult
                        {
                            IsHealthy = false,
                            Message = $"Critical disk space: {freeSpaceGB:F1} GB free ({usagePercent:F1}% used)",
                            Recommendation = "Free up disk space immediately to prevent application issues"
                        };
                    }
                    else if (freeSpaceGB < 5) // Less than 5GB free
                    {
                        return new HealthCheckResult
                        {
                            IsHealthy = true,
                            Message = $"Low disk space: {freeSpaceGB:F1} GB free ({usagePercent:F1}% used)",
                            Recommendation = "Consider freeing up disk space soon"
                        };
                    }
                    
                    return new HealthCheckResult
                    {
                        IsHealthy = true,
                        Message = $"Disk space adequate: {freeSpaceGB:F1} GB free ({usagePercent:F1}% used)"
                    };
                }
                catch (Exception ex)
                {
                    return new HealthCheckResult
                    {
                        IsHealthy = false,
                        Message = $"Disk space check failed: {ex.Message}",
                        Recommendation = "Unable to monitor disk space"
                    };
                }
            });
        }
        
        /// <summary>
        /// Register a custom health check
        /// </summary>
        public void RegisterHealthCheck(string name, Func<HealthCheckResult> healthCheck)
        {
            _healthChecks[name] = new HealthCheck
            {
                Name = name,
                Check = healthCheck,
                LastRun = DateTime.MinValue,
                LastResult = null
            };
        }
        
        /// <summary>
        /// Start health monitoring
        /// </summary>
        public void StartMonitoring()
        {
            if (_isMonitoring)
                return;
                
            try
            {
                _isMonitoring = true;
                _healthCheckTimer.Start();
                _logger?.LogInfo("Application health monitoring started");
                
                // Run initial health check
                Task.Run(async () => await RunHealthChecks());
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to start health monitoring: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Stop health monitoring
        /// </summary>
        public void StopMonitoring()
        {
            if (!_isMonitoring)
                return;
                
            try
            {
                _isMonitoring = false;
                _healthCheckTimer.Stop();
                _logger?.LogInfo("Application health monitoring stopped");
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to stop health monitoring: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Run all registered health checks
        /// </summary>
        public async Task<ApplicationHealthStatus> RunHealthChecks()
        {
            try
            {
                _logger?.LogDebug("Running health checks...");
                LastHealthCheck = DateTime.Now;
                
                var results = new List<HealthCheckResult>();
                var overallHealthy = true;
                
                foreach (var healthCheck in _healthChecks.Values)
                {
                    try
                    {
                        var result = await Task.Run(() => healthCheck.Check());
                        result.CheckName = healthCheck.Name;
                        result.Timestamp = DateTime.Now;
                        
                        healthCheck.LastRun = DateTime.Now;
                        healthCheck.LastResult = result;
                        
                        results.Add(result);
                        
                        if (!result.IsHealthy)
                        {
                            overallHealthy = false;
                            _logger?.LogWarning($"Health check '{healthCheck.Name}' failed: {result.Message}");
                        }
                        
                        HealthCheckCompleted?.Invoke(this, new HealthCheckEventArgs
                        {
                            CheckName = healthCheck.Name,
                            Result = result
                        });
                    }
                    catch (Exception ex)
                    {
                        overallHealthy = false;
                        var errorResult = new HealthCheckResult
                        {
                            CheckName = healthCheck.Name,
                            IsHealthy = false,
                            Message = $"Health check execution failed: {ex.Message}",
                            Recommendation = "Health check encountered an error",
                            Timestamp = DateTime.Now
                        };
                        
                        results.Add(errorResult);
                        _logger?.LogError($"Health check '{healthCheck.Name}' threw exception: {ex.Message}", ex);
                    }
                }
                
                var previousStatus = CurrentStatus?.IsHealthy ?? true;
                
                CurrentStatus = new ApplicationHealthStatus
                {
                    IsHealthy = overallHealthy,
                    LastCheckTime = DateTime.Now,
                    HealthCheckResults = results,
                    Summary = overallHealthy ? "All systems operational" : "Issues detected - see details"
                };
                
                if (previousStatus != overallHealthy)
                {
                    HealthStatusChanged?.Invoke(this, new HealthStatusChangedEventArgs
                    {
                        PreviousStatus = previousStatus,
                        CurrentStatus = overallHealthy,
                        StatusSummary = CurrentStatus.Summary
                    });
                    
                    if (!overallHealthy)
                    {
                        var errorRecovery = ErrorRecoveryService.Instance;
                        await errorRecovery.ValidateAndRecoverSystemState();
                    }
                }
                
                _logger?.LogDebug($"Health checks completed. Overall status: {(overallHealthy ? "Healthy" : "Unhealthy")}");
                return CurrentStatus;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Health check execution failed: {ex.Message}", ex);
                CurrentStatus = new ApplicationHealthStatus
                {
                    IsHealthy = false,
                    LastCheckTime = DateTime.Now,
                    HealthCheckResults = new List<HealthCheckResult>(),
                    Summary = "Health monitoring system error"
                };
                return CurrentStatus;
            }
        }
        
        /// <summary>
        /// Health check timer tick handler
        /// </summary>
        private async void HealthCheckTimer_Tick(object sender, EventArgs e)
        {
            await RunHealthChecks();
        }
        
        /// <summary>
        /// Get health status for a specific check
        /// </summary>
        public HealthCheckResult GetHealthCheckStatus(string checkName)
        {
            if (_healthChecks.ContainsKey(checkName))
            {
                return _healthChecks[checkName].LastResult;
            }
            return null;
        }
        
        /// <summary>
        /// Get all registered health check names
        /// </summary>
        public List<string> GetHealthCheckNames()
        {
            return new List<string>(_healthChecks.Keys);
        }
    }
    
    /// <summary>
    /// Health check definition
    /// </summary>
    internal class HealthCheck
    {
        public string Name { get; set; }
        public Func<HealthCheckResult> Check { get; set; }
        public DateTime LastRun { get; set; }
        public HealthCheckResult LastResult { get; set; }
    }
    
    /// <summary>
    /// Application health status
    /// </summary>
    public class ApplicationHealthStatus
    {
        public bool IsHealthy { get; set; }
        public DateTime LastCheckTime { get; set; }
        public string Summary { get; set; }
        public List<HealthCheckResult> HealthCheckResults { get; set; } = new List<HealthCheckResult>();
    }
    
    /// <summary>
    /// Individual health check result
    /// </summary>
    public class HealthCheckResult
    {
        public string CheckName { get; set; }
        public bool IsHealthy { get; set; }
        public string Message { get; set; }
        public string Recommendation { get; set; }
        public DateTime Timestamp { get; set; }
    }
    
    /// <summary>
    /// Health status changed event arguments
    /// </summary>
    public class HealthStatusChangedEventArgs : EventArgs
    {
        public bool PreviousStatus { get; set; }
        public bool CurrentStatus { get; set; }
        public string StatusSummary { get; set; }
    }
    
    /// <summary>
    /// Health check completed event arguments
    /// </summary>
    public class HealthCheckEventArgs : EventArgs
    {
        public string CheckName { get; set; }
        public HealthCheckResult Result { get; set; }
    }
}