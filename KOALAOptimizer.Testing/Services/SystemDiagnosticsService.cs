using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Threading.Tasks;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for comprehensive system diagnostics and compatibility validation
    /// </summary>
    public class SystemDiagnosticsService
    {
        private static readonly Lazy<SystemDiagnosticsService> _instance = new Lazy<SystemDiagnosticsService>(() => new SystemDiagnosticsService());
        public static SystemDiagnosticsService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        
        public event EventHandler<DiagnosticsEventArgs> DiagnosticsCompleted;
        
        private SystemDiagnosticsService()
        {
            try
            {
                LoggingService.EmergencyLog("SystemDiagnosticsService: Initializing...");
                _logger = LoggingService.Instance;
                LoggingService.EmergencyLog("SystemDiagnosticsService: Initialization completed");
                _logger?.LogInfo("System diagnostics service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"SystemDiagnosticsService: Initialization failed - {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Run comprehensive system health check
        /// </summary>
        public async Task<SystemHealthReport> RunSystemHealthCheck()
        {
            try
            {
                _logger?.LogInfo("Starting comprehensive system health check...");
                
                var report = new SystemHealthReport
                {
                    StartTime = DateTime.Now,
                    CheckVersion = "2.3.0"
                };
                
                // Run all diagnostic checks
                await Task.Run(() =>
                {
                    report.SystemInfo = GetSystemInformation();
                    report.HardwareInfo = GetHardwareInformation();
                    report.StorageInfo = GetStorageInformation();
                    report.NetworkInfo = GetNetworkInformation();
                    report.ProcessInfo = GetProcessInformation();
                    report.ServiceInfo = GetServiceInformation();
                    report.SecurityInfo = GetSecurityInformation();
                    report.PerformanceInfo = GetPerformanceInformation();
                });
                
                report.EndTime = DateTime.Now;
                report.Duration = report.EndTime - report.StartTime;
                report.OverallHealth = CalculateOverallHealth(report);
                report.Recommendations = GenerateRecommendations(report);
                
                DiagnosticsCompleted?.Invoke(this, new DiagnosticsEventArgs { Report = report });
                
                _logger?.LogInfo($"System health check completed in {report.Duration.TotalSeconds:F1} seconds. Overall health: {report.OverallHealth}");
                return report;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"System health check failed: {ex.Message}", ex);
                return new SystemHealthReport
                {
                    StartTime = DateTime.Now,
                    EndTime = DateTime.Now,
                    OverallHealth = HealthStatus.Critical,
                    ErrorMessage = ex.Message
                };
            }
        }
        
        /// <summary>
        /// Get system information
        /// </summary>
        private SystemInformation GetSystemInformation()
        {
            try
            {
                var info = new SystemInformation();
                
                // Operating System
                var os = Environment.OSVersion;
                info.OperatingSystem = $"{os.Platform} {os.Version}";
                info.Is64Bit = Environment.Is64BitOperatingSystem;
                info.ProcessorCount = Environment.ProcessorCount;
                info.UserName = Environment.UserName;
                info.MachineName = Environment.MachineName;
                info.FrameworkVersion = Environment.Version.ToString();
                
                // Additional system info via WMI
                try
                {
                    using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_OperatingSystem"))
                    {
                        foreach (ManagementObject obj in searcher.Get())
                        {
                            info.TotalPhysicalMemory = Convert.ToInt64(obj["TotalVisibleMemorySize"]) * 1024;
                            info.AvailablePhysicalMemory = Convert.ToInt64(obj["FreePhysicalMemory"]) * 1024;
                            info.SystemUptime = DateTime.Now - DateTime.ParseExact(obj["LastBootUpTime"].ToString().Split('.')[0], "yyyyMMddHHmmss", null);
                            break;
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning($"Failed to get extended system info: {ex.Message}");
                }
                
                return info;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get system information: {ex.Message}", ex);
                return new SystemInformation { ErrorMessage = ex.Message };
            }
        }
        
        /// <summary>
        /// Get hardware information
        /// </summary>
        private HardwareInformation GetHardwareInformation()
        {
            try
            {
                var info = new HardwareInformation();
                
                // CPU Information
                try
                {
                    using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Processor"))
                    {
                        foreach (ManagementObject obj in searcher.Get())
                        {
                            info.CpuName = obj["Name"]?.ToString();
                            info.CpuCores = Convert.ToInt32(obj["NumberOfCores"]);
                            info.CpuLogicalProcessors = Convert.ToInt32(obj["NumberOfLogicalProcessors"]);
                            info.CpuMaxClockSpeed = Convert.ToInt32(obj["MaxClockSpeed"]);
                            break;
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning($"Failed to get CPU info: {ex.Message}");
                }
                
                // GPU Information
                try
                {
                    var gpus = new List<string>();
                    using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController"))
                    {
                        foreach (ManagementObject obj in searcher.Get())
                        {
                            var name = obj["Name"]?.ToString();
                            if (!string.IsNullOrEmpty(name) && !name.Contains("Microsoft Basic"))
                            {
                                gpus.Add(name);
                            }
                        }
                    }
                    info.GpuDevices = gpus;
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning($"Failed to get GPU info: {ex.Message}");
                }
                
                // Motherboard Information
                try
                {
                    using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_BaseBoard"))
                    {
                        foreach (ManagementObject obj in searcher.Get())
                        {
                            info.MotherboardManufacturer = obj["Manufacturer"]?.ToString();
                            info.MotherboardProduct = obj["Product"]?.ToString();
                            break;
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning($"Failed to get motherboard info: {ex.Message}");
                }
                
                return info;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get hardware information: {ex.Message}", ex);
                return new HardwareInformation { ErrorMessage = ex.Message };
            }
        }
        
        /// <summary>
        /// Get storage information
        /// </summary>
        private StorageInformation GetStorageInformation()
        {
            try
            {
                var info = new StorageInformation();
                var drives = new List<DriveInformation>();
                
                foreach (var drive in DriveInfo.GetDrives())
                {
                    try
                    {
                        if (drive.IsReady)
                        {
                            var driveInfo = new DriveInformation
                            {
                                Name = drive.Name,
                                DriveType = ((System.IO.DriveType)drive.DriveType).ToString(),
                                FileSystem = drive.DriveFormat,
                                TotalSize = drive.TotalSize,
                                FreeSpace = drive.AvailableFreeSpace,
                                UsedSpace = drive.TotalSize - drive.AvailableFreeSpace
                            };
                            
                            driveInfo.UsagePercentage = (double)driveInfo.UsedSpace / driveInfo.TotalSize * 100;
                            drives.Add(driveInfo);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger?.LogWarning($"Failed to get info for drive {drive.Name}: {ex.Message}");
                    }
                }
                
                info.Drives = drives;
                info.TotalStorageSpace = drives.Sum(d => d.TotalSize);
                info.TotalFreeSpace = drives.Sum(d => d.FreeSpace);
                
                return info;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get storage information: {ex.Message}", ex);
                return new StorageInformation { ErrorMessage = ex.Message };
            }
        }
        
        /// <summary>
        /// Get network information
        /// </summary>
        private NetworkInformation GetNetworkInformation()
        {
            try
            {
                var info = new NetworkInformation();
                var adapters = new List<NetworkAdapterInfo>();
                
                try
                {
                    using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_NetworkAdapter WHERE NetEnabled=true"))
                    {
                        foreach (ManagementObject obj in searcher.Get())
                        {
                            var adapter = new NetworkAdapterInfo
                            {
                                Name = obj["Name"]?.ToString(),
                                AdapterType = obj["AdapterType"]?.ToString(),
                                MACAddress = obj["MACAddress"]?.ToString(),
                                Speed = obj["Speed"]?.ToString(),
                                IsConnected = Convert.ToBoolean(obj["NetEnabled"])
                            };
                            
                            adapters.Add(adapter);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning($"Failed to get network adapter info: {ex.Message}");
                }
                
                info.Adapters = adapters;
                info.ActiveAdapters = adapters.Count(a => a.IsConnected);
                
                return info;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get network information: {ex.Message}", ex);
                return new NetworkInformation { ErrorMessage = ex.Message };
            }
        }
        
        /// <summary>
        /// Get process information
        /// </summary>
        private ProcessInformation GetProcessInformation()
        {
            try
            {
                var info = new ProcessInformation();
                var processes = Process.GetProcesses();
                
                info.TotalProcesses = processes.Length;
                info.SystemProcesses = processes.Count(p => 
                {
                    try { return p.SessionId == 0; }
                    catch { return false; }
                });
                
                // Top memory consumers
                var topMemoryProcesses = processes
                    .Where(p => { try { return p.WorkingSet64 > 0; } catch { return false; } })
                    .OrderByDescending(p => { try { return p.WorkingSet64; } catch { return 0; } })
                    .Take(10)
                    .Select(p => new ProcessInfo 
                    { 
                        Name = p.ProcessName, 
                        MemoryUsage = p.WorkingSet64,
                        CpuTime = p.TotalProcessorTime
                    })
                    .ToList();
                
                info.TopMemoryConsumers = topMemoryProcesses;
                info.TotalMemoryUsage = topMemoryProcesses.Sum(p => p.MemoryUsage);
                
                return info;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get process information: {ex.Message}", ex);
                return new ProcessInformation { ErrorMessage = ex.Message };
            }
        }
        
        /// <summary>
        /// Get service information
        /// </summary>
        private ServiceInformation GetServiceInformation()
        {
            try
            {
                var info = new ServiceInformation();
                var services = System.ServiceProcess.ServiceController.GetServices();
                
                info.TotalServices = services.Length;
                info.RunningServices = services.Count(s => s.Status == System.ServiceProcess.ServiceControllerStatus.Running);
                info.StoppedServices = services.Count(s => s.Status == System.ServiceProcess.ServiceControllerStatus.Stopped);
                
                // Critical services
                var criticalServiceNames = new[] { "Winmgmt", "RpcSs", "Dhcp", "Dnscache", "EventLog", "PlugPlay" };
                var criticalServices = new List<ServiceInfo>();
                
                foreach (var serviceName in criticalServiceNames)
                {
                    var service = services.FirstOrDefault(s => s.ServiceName.Equals(serviceName, StringComparison.OrdinalIgnoreCase));
                    if (service != null)
                    {
                        criticalServices.Add(new ServiceInfo 
                        { 
                            Name = service.ServiceName,
                            DisplayName = service.DisplayName,
                            Status = service.Status.ToString()
                        });
                    }
                }
                
                info.CriticalServices = criticalServices;
                
                return info;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get service information: {ex.Message}", ex);
                return new ServiceInformation { ErrorMessage = ex.Message };
            }
        }
        
        /// <summary>
        /// Get security information
        /// </summary>
        private SecurityInformation GetSecurityInformation()
        {
            try
            {
                var info = new SecurityInformation();
                
                // Admin privileges
                info.IsRunningAsAdmin = AdminService.Instance.IsRunningAsAdmin();
                
                // UAC status
                try
                {
                    using (var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"))
                    {
                        var uacValue = key?.GetValue("EnableLUA");
                        info.UACEnabled = uacValue != null && Convert.ToBoolean(uacValue);
                    }
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning($"Failed to check UAC status: {ex.Message}");
                }
                
                // Windows Defender status (simplified check)
                try
                {
                    var defenderProcess = Process.GetProcessesByName("MsMpEng");
                    info.AntivirusRunning = defenderProcess.Length > 0;
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning($"Failed to check antivirus status: {ex.Message}");
                }
                
                return info;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get security information: {ex.Message}", ex);
                return new SecurityInformation { ErrorMessage = ex.Message };
            }
        }
        
        /// <summary>
        /// Get performance information
        /// </summary>
        private PerformanceInformation GetPerformanceInformation()
        {
            try
            {
                var info = new PerformanceInformation();
                var perfService = PerformanceMonitoringService.Instance;
                
                // Current performance metrics
                perfService.UpdateOnce();
                var metrics = perfService.CurrentMetrics;
                
                if (metrics != null)
                {
                    info.CurrentCpuUsage = metrics.CpuUsage;
                    info.CurrentMemoryUsage = metrics.MemoryUsage;
                    info.CurrentProcessCount = metrics.ActiveProcesses;
                    info.CurrentGpuUsage = metrics.GpuUsage;
                }
                
                // Performance assessment
                var assessment = perfService.GetSystemHealthAssessment();
                info.PerformanceScore = assessment.OverallScore;
                info.CpuStatus = assessment.CpuStatus;
                info.MemoryStatus = assessment.MemoryStatus;
                info.ProcessStatus = assessment.ProcessStatus;
                info.GpuStatus = assessment.GpuStatus;
                
                return info;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get performance information: {ex.Message}", ex);
                return new PerformanceInformation { ErrorMessage = ex.Message };
            }
        }
        
        /// <summary>
        /// Calculate overall system health
        /// </summary>
        private HealthStatus CalculateOverallHealth(SystemHealthReport report)
        {
            try
            {
                var healthScores = new List<HealthStatus>();
                
                // Performance health
                if (report.PerformanceInfo != null)
                {
                    healthScores.Add(report.PerformanceInfo.CpuStatus);
                    healthScores.Add(report.PerformanceInfo.MemoryStatus);
                    healthScores.Add(report.PerformanceInfo.ProcessStatus);
                }
                
                // Storage health
                if (report.StorageInfo?.Drives != null)
                {
                    foreach (var drive in report.StorageInfo.Drives)
                    {
                        if (drive.UsagePercentage > 95)
                            healthScores.Add(HealthStatus.Critical);
                        else if (drive.UsagePercentage > 85)
                            healthScores.Add(HealthStatus.Warning);
                        else if (drive.UsagePercentage > 70)
                            healthScores.Add(HealthStatus.Good);
                        else
                            healthScores.Add(HealthStatus.Excellent);
                    }
                }
                
                // Security health
                if (report.SecurityInfo != null)
                {
                    if (!report.SecurityInfo.UACEnabled)
                        healthScores.Add(HealthStatus.Warning);
                    if (!report.SecurityInfo.AntivirusRunning)
                        healthScores.Add(HealthStatus.Warning);
                }
                
                // Calculate overall status
                if (healthScores.Any(h => h == HealthStatus.Critical))
                    return HealthStatus.Critical;
                if (healthScores.Count(h => h == HealthStatus.Warning) > healthScores.Count / 2)
                    return HealthStatus.Warning;
                if (healthScores.Count(h => h == HealthStatus.Good || h == HealthStatus.Excellent) > healthScores.Count / 2)
                    return HealthStatus.Good;
                
                return HealthStatus.Excellent;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to calculate overall health: {ex.Message}", ex);
                return HealthStatus.Critical;
            }
        }
        
        /// <summary>
        /// Generate recommendations based on diagnostics
        /// </summary>
        private List<string> GenerateRecommendations(SystemHealthReport report)
        {
            var recommendations = new List<string>();
            
            try
            {
                // Performance recommendations
                if (report.PerformanceInfo != null)
                {
                    if (report.PerformanceInfo.CpuStatus == HealthStatus.Critical)
                        recommendations.Add("CPU usage is critically high - close unnecessary applications");
                    if (report.PerformanceInfo.MemoryStatus == HealthStatus.Critical)
                        recommendations.Add("Memory usage is critically high - consider adding more RAM");
                    if (report.PerformanceInfo.ProcessStatus == HealthStatus.Warning)
                        recommendations.Add("Too many processes running - optimize startup programs");
                }
                
                // Storage recommendations
                if (report.StorageInfo?.Drives != null)
                {
                    foreach (var drive in report.StorageInfo.Drives)
                    {
                        if (drive.UsagePercentage > 90)
                            recommendations.Add($"Drive {drive.Name} is nearly full ({drive.UsagePercentage:F1}%) - free up space");
                    }
                }
                
                // Security recommendations
                if (report.SecurityInfo != null)
                {
                    if (!report.SecurityInfo.UACEnabled)
                        recommendations.Add("User Account Control (UAC) is disabled - enable for better security");
                    if (!report.SecurityInfo.AntivirusRunning)
                        recommendations.Add("No antivirus detected - ensure Windows Defender or other antivirus is running");
                }
                
                // System recommendations
                if (report.SystemInfo != null && report.SystemInfo.SystemUptime.TotalDays > 7)
                    recommendations.Add($"System has been running for {report.SystemInfo.SystemUptime.Days} days - consider restarting");
                
                if (recommendations.Count == 0)
                    recommendations.Add("System appears to be running optimally - no immediate issues detected");
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to generate recommendations: {ex.Message}", ex);
                recommendations.Add("Unable to generate recommendations due to error");
            }
            
            return recommendations;
        }
        
        /// <summary>
        /// Run compatibility check for gaming optimization
        /// </summary>
        public async Task<CompatibilityReport> RunCompatibilityCheck()
        {
            try
            {
                _logger?.LogInfo("Running compatibility check...");
                
                var report = new CompatibilityReport
                {
                    CheckDate = DateTime.Now,
                    ApplicationVersion = "2.3.0"
                };
                
                await Task.Run(() =>
                {
                    // Windows version compatibility
                    var os = Environment.OSVersion;
                    report.WindowsVersionSupported = os.Version.Major >= 10; // Windows 10+
                    
                    // .NET Framework compatibility
                    report.DotNetVersionSupported = Environment.Version.Major >= 4;
                    
                    // Memory requirements
                    var totalMemory = GC.GetTotalMemory(false) / (1024 * 1024); // MB
                    report.SufficientMemory = totalMemory >= 512; // 512MB minimum
                    
                    // Admin privileges
                    report.AdminPrivilegesAvailable = AdminService.Instance.IsRunningAsAdmin();
                    
                    // Performance counter access
                    try
                    {
                        using (var counter = new PerformanceCounter("Processor", "% Processor Time", "_Total"))
                        {
                            counter.NextValue();
                            report.PerformanceCountersAvailable = true;
                        }
                    }
                    catch
                    {
                        report.PerformanceCountersAvailable = false;
                    }
                    
                    // WMI access
                    try
                    {
                        using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_OperatingSystem"))
                        {
                            searcher.Get();
                            report.WmiAccessAvailable = true;
                        }
                    }
                    catch
                    {
                        report.WmiAccessAvailable = false;
                    }
                });
                
                // Calculate overall compatibility
                var compatibilityChecks = new[]
                {
                    report.WindowsVersionSupported,
                    report.DotNetVersionSupported,
                    report.SufficientMemory,
                    report.PerformanceCountersAvailable,
                    report.WmiAccessAvailable
                };
                
                report.CompatibilityScore = (double)compatibilityChecks.Count(c => c) / compatibilityChecks.Length * 100;
                report.IsFullyCompatible = compatibilityChecks.All(c => c);
                
                _logger?.LogInfo($"Compatibility check completed. Score: {report.CompatibilityScore:F1}%");
                return report;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Compatibility check failed: {ex.Message}", ex);
                return new CompatibilityReport
                {
                    CheckDate = DateTime.Now,
                    ApplicationVersion = "2.3.0",
                    CompatibilityScore = 0,
                    IsFullyCompatible = false,
                    ErrorMessage = ex.Message
                };
            }
        }
    }
}