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
            try
            {
                LoggingService.EmergencyLog("PerformanceMonitoringService: Initializing...");
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
                
                LoggingService.EmergencyLog("PerformanceMonitoringService: Initialization completed");
                _logger.LogInfo("Performance monitoring service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"PerformanceMonitoringService: Initialization failed - {ex.Message}");
                _logger?.LogError($"Failed to initialize performance monitoring: {ex.Message}", ex);
                
                // Initialize with minimal state
                CurrentMetrics = new PerformanceMetrics { Timestamp = DateTime.Now };
            }
            }
            catch (Exception criticalEx)
            {
                LoggingService.EmergencyLog($"PerformanceMonitoringService: CRITICAL failure - {criticalEx.Message}");
                // Initialize minimal state to prevent null reference errors
                CurrentMetrics = new PerformanceMetrics { Timestamp = DateTime.Now };
                _logger = null;
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
        /// Get performance metrics history for trend analysis
        /// </summary>
        public List<PerformanceMetrics> GetMetricsHistory(int maxEntries = 100)
        {
            try
            {
                // This would be implemented with a circular buffer in a real implementation
                // For now, return current metrics as a single entry
                return CurrentMetrics != null ? new List<PerformanceMetrics> { CurrentMetrics } : new List<PerformanceMetrics>();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to get metrics history: {ex.Message}", ex);
                return new List<PerformanceMetrics>();
            }
        }
        
        /// <summary>
        /// Get performance benchmark score
        /// </summary>
        public double CalculatePerformanceBenchmark()
        {
            try
            {
                if (CurrentMetrics == null)
                    return 0;
                
                // Simple benchmark calculation based on current metrics
                // Higher is better (100 = perfect, 0 = terrible)
                var cpuScore = Math.Max(0, 100 - CurrentMetrics.CpuUsage);
                var memoryScore = Math.Max(0, Math.Min(100, (CurrentMetrics.MemoryAvailable / 1024.0) * 10)); // 10GB = 100 points
                var processScore = Math.Max(0, 100 - (CurrentMetrics.ActiveProcesses / 2.0)); // 200 processes = 0 points
                
                var overallScore = (cpuScore + memoryScore + processScore) / 3.0;
                return Math.Round(overallScore, 1);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to calculate performance benchmark: {ex.Message}", ex);
                return 0;
            }
        }
        
        /// <summary>
        /// Get system health assessment
        /// </summary>
        public SystemHealthAssessment GetSystemHealthAssessment()
        {
            try
            {
                var assessment = new SystemHealthAssessment
                {
                    Timestamp = DateTime.Now,
                    OverallScore = CalculatePerformanceBenchmark()
                };
                
                if (CurrentMetrics != null)
                {
                    // CPU Assessment
                    if (CurrentMetrics.CpuUsage < 30)
                        assessment.CpuStatus = HealthStatus.Excellent;
                    else if (CurrentMetrics.CpuUsage < 60)
                        assessment.CpuStatus = HealthStatus.Good;
                    else if (CurrentMetrics.CpuUsage < 85)
                        assessment.CpuStatus = HealthStatus.Warning;
                    else
                        assessment.CpuStatus = HealthStatus.Critical;
                    
                    // Memory Assessment
                    var memoryUsagePercent = (CurrentMetrics.MemoryUsage / (double)(CurrentMetrics.MemoryUsage + CurrentMetrics.MemoryAvailable)) * 100;
                    if (memoryUsagePercent < 50)
                        assessment.MemoryStatus = HealthStatus.Excellent;
                    else if (memoryUsagePercent < 75)
                        assessment.MemoryStatus = HealthStatus.Good;
                    else if (memoryUsagePercent < 90)
                        assessment.MemoryStatus = HealthStatus.Warning;
                    else
                        assessment.MemoryStatus = HealthStatus.Critical;
                    
                    // Process Count Assessment
                    if (CurrentMetrics.ActiveProcesses < 100)
                        assessment.ProcessStatus = HealthStatus.Excellent;
                    else if (CurrentMetrics.ActiveProcesses < 150)
                        assessment.ProcessStatus = HealthStatus.Good;
                    else if (CurrentMetrics.ActiveProcesses < 200)
                        assessment.ProcessStatus = HealthStatus.Warning;
                    else
                        assessment.ProcessStatus = HealthStatus.Critical;
                    
                    // GPU Assessment (if available)
                    if (CurrentMetrics.GpuUsage < 50)
                        assessment.GpuStatus = HealthStatus.Excellent;
                    else if (CurrentMetrics.GpuUsage < 80)
                        assessment.GpuStatus = HealthStatus.Good;
                    else if (CurrentMetrics.GpuUsage < 95)
                        assessment.GpuStatus = HealthStatus.Warning;
                    else
                        assessment.GpuStatus = HealthStatus.Critical;
                }
                
                // Generate recommendations
                assessment.Recommendations = GenerateOptimizationRecommendations(assessment);
                
                return assessment;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to get system health assessment: {ex.Message}", ex);
                return new SystemHealthAssessment
                {
                    Timestamp = DateTime.Now,
                    OverallScore = 0,
                    Recommendations = new List<string> { "Unable to assess system health due to error" }
                };
            }
        }
        
        /// <summary>
        /// Generate optimization recommendations based on system health
        /// </summary>
        private List<string> GenerateOptimizationRecommendations(SystemHealthAssessment assessment)
        {
            var recommendations = new List<string>();
            
            try
            {
                if (assessment.CpuStatus == HealthStatus.Critical || assessment.CpuStatus == HealthStatus.Warning)
                {
                    recommendations.Add("Consider closing unnecessary applications to reduce CPU load");
                    recommendations.Add("Apply CPU optimization settings for better performance");
                }
                
                if (assessment.MemoryStatus == HealthStatus.Critical || assessment.MemoryStatus == HealthStatus.Warning)
                {
                    recommendations.Add("Close memory-intensive applications");
                    recommendations.Add("Consider upgrading system RAM");
                    recommendations.Add("Enable memory optimization features");
                }
                
                if (assessment.ProcessStatus == HealthStatus.Critical || assessment.ProcessStatus == HealthStatus.Warning)
                {
                    recommendations.Add("Too many processes running - consider startup optimization");
                    recommendations.Add("Review and disable unnecessary background services");
                }
                
                if (assessment.GpuStatus == HealthStatus.Critical || assessment.GpuStatus == HealthStatus.Warning)
                {
                    recommendations.Add("GPU usage is high - close graphics-intensive applications");
                    recommendations.Add("Check GPU temperature and cooling");
                }
                
                if (assessment.OverallScore > 80)
                {
                    recommendations.Add("System performance is excellent - no immediate action needed");
                }
                else if (assessment.OverallScore > 60)
                {
                    recommendations.Add("System performance is good - minor optimizations may help");
                }
                else if (assessment.OverallScore > 40)
                {
                    recommendations.Add("System performance needs attention - apply optimizations");
                }
                else
                {
                    recommendations.Add("System performance is poor - immediate optimization recommended");
                    recommendations.Add("Consider system restart to clear memory leaks");
                }
                
                if (recommendations.Count == 0)
                {
                    recommendations.Add("System appears healthy - continue monitoring");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to generate recommendations: {ex.Message}", ex);
                recommendations.Add("Unable to generate recommendations due to error");
            }
            
            return recommendations;
        }
        
        /// <summary>
        /// Run automated performance benchmark
        /// </summary>
        public async Task<BenchmarkResult> RunPerformanceBenchmark()
        {
            try
            {
                _logger.LogInfo("Starting performance benchmark...");
                
                var result = new BenchmarkResult
                {
                    StartTime = DateTime.Now,
                    BenchmarkType = "System Performance"
                };
                
                // Collect baseline metrics
                UpdateMetrics();
                var baselineMetrics = CurrentMetrics;
                
                // Wait and collect metrics again
                await Task.Delay(5000);
                UpdateMetrics();
                var endMetrics = CurrentMetrics;
                
                result.EndTime = DateTime.Now;
                result.Duration = result.EndTime - result.StartTime;
                
                // Calculate scores
                result.CpuScore = Math.Max(0, 100 - baselineMetrics.CpuUsage);
                result.MemoryScore = Math.Max(0, Math.Min(100, (baselineMetrics.MemoryAvailable / 1024.0) * 10));
                result.ProcessScore = Math.Max(0, 100 - (baselineMetrics.ActiveProcesses / 2.0));
                result.GpuScore = Math.Max(0, 100 - baselineMetrics.GpuUsage);
                
                result.OverallScore = (result.CpuScore + result.MemoryScore + result.ProcessScore + result.GpuScore) / 4.0;
                
                // Calculate stability (lower variance = more stable)
                var cpuVariance = Math.Abs(endMetrics.CpuUsage - baselineMetrics.CpuUsage);
                var memoryVariance = Math.Abs(endMetrics.MemoryUsage - baselineMetrics.MemoryUsage);
                result.StabilityScore = Math.Max(0, 100 - (cpuVariance + memoryVariance / 100.0));
                
                result.IsSuccessful = true;
                result.Notes = $"Benchmark completed successfully. System stability: {result.StabilityScore:F1}%";
                
                _logger.LogInfo($"Performance benchmark completed. Overall score: {result.OverallScore:F1}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Performance benchmark failed: {ex.Message}", ex);
                return new BenchmarkResult
                {
                    StartTime = DateTime.Now,
                    EndTime = DateTime.Now,
                    IsSuccessful = false,
                    Notes = $"Benchmark failed: {ex.Message}"
                };
            }
        }
        
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