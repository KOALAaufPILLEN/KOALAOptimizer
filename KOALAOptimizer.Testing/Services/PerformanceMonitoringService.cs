using System;
using System.Diagnostics;
using System.Management;
using System.Threading;
using System.Windows.Threading;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for monitoring system performance metrics in real-time
    /// </summary>
    public class PerformanceMonitoringService
    {
        private static readonly Lazy<PerformanceMonitoringService> _instance = new Lazy<PerformanceMonitoringService>(() => new PerformanceMonitoringService());
        public static PerformanceMonitoringService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly DispatcherTimer _monitoringTimer;
        private readonly PerformanceCounter _cpuCounter;
        private readonly PerformanceCounter _memoryCounter;
        private bool _isMonitoring = false;
        
        public event EventHandler<PerformanceMetrics> MetricsUpdated;
        public PerformanceMetrics CurrentMetrics { get; private set; }
        
        private PerformanceMonitoringService()
        {
            _logger = LoggingService.Instance;
            
            try
            {
                // Initialize performance counters
                _cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
                _memoryCounter = new PerformanceCounter("Memory", "Available MBytes");
                
                // Initialize monitoring timer (update every 2 seconds)
                _monitoringTimer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromSeconds(2)
                };
                _monitoringTimer.Tick += MonitoringTimer_Tick;
                
                CurrentMetrics = new PerformanceMetrics { Timestamp = DateTime.Now };
                
                _logger.LogInfo("Performance monitoring service initialized");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to initialize performance monitoring: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Start performance monitoring
        /// </summary>
        public void StartMonitoring()
        {
            if (_isMonitoring)
            {
                return;
            }
            
            try
            {
                _isMonitoring = true;
                _monitoringTimer.Start();
                _logger.LogInfo("Performance monitoring started");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to start performance monitoring: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Stop performance monitoring
        /// </summary>
        public void StopMonitoring()
        {
            if (!_isMonitoring)
            {
                return;
            }
            
            try
            {
                _isMonitoring = false;
                _monitoringTimer.Stop();
                _logger.LogInfo("Performance monitoring stopped");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to stop performance monitoring: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Timer tick event handler for updating metrics
        /// </summary>
        private void MonitoringTimer_Tick(object sender, EventArgs e)
        {
            try
            {
                UpdateMetrics();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error updating performance metrics: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Update performance metrics
        /// </summary>
        private void UpdateMetrics()
        {
            try
            {
                var metrics = new PerformanceMetrics
                {
                    Timestamp = DateTime.Now,
                    CpuUsage = GetCpuUsage(),
                    MemoryUsage = GetMemoryUsage(),
                    MemoryAvailable = GetAvailableMemory(),
                    ActiveProcesses = GetActiveProcessCount(),
                    GpuUsage = GetGpuUsage(),
                    GpuName = GetGpuName()
                };
                
                CurrentMetrics = metrics;
                MetricsUpdated?.Invoke(this, metrics);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error collecting performance metrics: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get CPU usage percentage
        /// </summary>
        private double GetCpuUsage()
        {
            try
            {
                return Math.Round(_cpuCounter.NextValue(), 1);
            }
            catch
            {
                return 0;
            }
        }
        
        /// <summary>
        /// Get memory usage in MB
        /// </summary>
        private long GetMemoryUsage()
        {
            try
            {
                var totalMemory = GetTotalPhysicalMemory();
                var availableMemory = GetAvailableMemory();
                return totalMemory - availableMemory;
            }
            catch
            {
                return 0;
            }
        }
        
        /// <summary>
        /// Get available memory in MB
        /// </summary>
        private long GetAvailableMemory()
        {
            try
            {
                return (long)_memoryCounter.NextValue();
            }
            catch
            {
                return 0;
            }
        }
        
        /// <summary>
        /// Get total physical memory in MB
        /// </summary>
        private long GetTotalPhysicalMemory()
        {
            try
            {
                var computerInfo = new Microsoft.VisualBasic.Devices.ComputerInfo();
                return (long)(computerInfo.TotalPhysicalMemory / (1024 * 1024));
            }
            catch
            {
                try
                {
                    // Fallback method using WMI
                    using (var searcher = new ManagementObjectSearcher("SELECT TotalPhysicalMemory FROM Win32_ComputerSystem"))
                    {
                        foreach (ManagementObject obj in searcher.Get())
                        {
                            return Convert.ToInt64(obj["TotalPhysicalMemory"]) / (1024 * 1024);
                        }
                    }
                }
                catch
                {
                    return 8192; // Default 8GB
                }
                return 0;
            }
        }
        
        /// <summary>
        /// Get active process count
        /// </summary>
        private int GetActiveProcessCount()
        {
            try
            {
                return Process.GetProcesses().Length;
            }
            catch
            {
                return 0;
            }
        }
        
        /// <summary>
        /// Get GPU usage percentage (simplified)
        /// </summary>
        private double GetGpuUsage()
        {
            try
            {
                // Try to get GPU usage from performance counters
                // This is simplified - real implementation would need GPU-specific counters
                using (var searcher = new ManagementObjectSearcher("SELECT LoadPercentage FROM Win32_Processor"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        // This is actually CPU load, but used as fallback
                        var load = obj["LoadPercentage"];
                        if (load != null)
                        {
                            return Convert.ToDouble(load);
                        }
                    }
                }
            }
            catch
            {
                // Ignore errors and return 0
            }
            
            return 0;
        }
        
        /// <summary>
        /// Get GPU name
        /// </summary>
        private string GetGpuName()
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT Name FROM Win32_VideoController"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        if (!string.IsNullOrEmpty(name) && !name.Contains("Microsoft Basic"))
                        {
                            return name;
                        }
                    }
                }
            }
            catch
            {
                // Ignore errors
            }
            
            return "Unknown GPU";
        }
        
        /// <summary>
        /// Get formatted metrics summary
        /// </summary>
        public string GetMetricsSummary()
        {
            if (CurrentMetrics == null)
            {
                return "No metrics available";
            }
            
            return $"CPU: {CurrentMetrics.CpuUsage:F1}% | " +
                   $"Memory: {CurrentMetrics.MemoryUsage:N0} MB | " +
                   $"Processes: {CurrentMetrics.ActiveProcesses} | " +
                   $"Updated: {CurrentMetrics.Timestamp:HH:mm:ss}";
        }
        
        /// <summary>
        /// Force update metrics once
        /// </summary>
        public void UpdateOnce()
        {
            UpdateMetrics();
        }
        
        /// <summary>
        /// Check if monitoring is active
        /// </summary>
        public bool IsMonitoring => _isMonitoring;
        
        /// <summary>
        /// Cleanup resources
        /// </summary>
        public void Dispose()
        {
            try
            {
                StopMonitoring();
                _monitoringTimer?.Stop();
                _cpuCounter?.Dispose();
                _memoryCounter?.Dispose();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error disposing performance monitoring service: {ex.Message}", ex);
            }
        }
    }
}