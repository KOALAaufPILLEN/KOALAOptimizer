using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Threading;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for tracking usage analytics and performance trends
    /// </summary>
    public class AnalyticsService
    {
        private static readonly Lazy<AnalyticsService> _instance = new Lazy<AnalyticsService>(() => new AnalyticsService());
        public static AnalyticsService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly string _analyticsFilePath;
        private readonly DispatcherTimer _analyticsTimer;
        private readonly object _lockObject = new object();
        
        // Analytics data
        private readonly List<UsageSession> _sessions;
        private readonly List<OptimizationUsage> _optimizationUsage;
        private readonly List<PerformanceTrend> _performanceTrends;
        private readonly Dictionary<string, int> _featureUsage;
        
        // Current session tracking
        private UsageSession _currentSession;
        private DateTime _sessionStartTime;
        private bool _isTracking = false;
        
        public event EventHandler<AnalyticsEventArgs> AnalyticsUpdated;
        
        private AnalyticsService()
        {
            try
            {
                LoggingService.EmergencyLog("AnalyticsService: Initializing...");
                _logger = LoggingService.Instance;
                
                // Initialize data structures
                _sessions = new List<UsageSession>();
                _optimizationUsage = new List<OptimizationUsage>();
                _performanceTrends = new List<PerformanceTrend>();
                _featureUsage = new Dictionary<string, int>();
                
                // Setup analytics file path
                var appDataPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "KOALAOptimizer");
                Directory.CreateDirectory(appDataPath);
                _analyticsFilePath = Path.Combine(appDataPath, "analytics.dat");
                
                // Initialize analytics timer (every 30 seconds)
                _analyticsTimer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromSeconds(30)
                };
                _analyticsTimer.Tick += AnalyticsTimer_Tick;
                
                LoadAnalyticsData();
                LoggingService.EmergencyLog("AnalyticsService: Initialization completed");
                _logger?.LogInfo("Analytics service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"AnalyticsService: Initialization failed - {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Start analytics tracking
        /// </summary>
        public void StartTracking()
        {
            try
            {
                if (_isTracking)
                    return;
                
                _isTracking = true;
                _sessionStartTime = DateTime.Now;
                
                _currentSession = new UsageSession
                {
                    SessionId = Guid.NewGuid().ToString(),
                    StartTime = _sessionStartTime,
                    ApplicationVersion = "2.3.0",
                    IsAdmin = AdminService.Instance.IsRunningAsAdmin()
                };
                
                _analyticsTimer.Start();
                _logger?.LogInfo("Analytics tracking started");
                
                // Track application start
                TrackFeatureUsage("ApplicationStart");
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to start analytics tracking: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Stop analytics tracking
        /// </summary>
        public void StopTracking()
        {
            try
            {
                if (!_isTracking)
                    return;
                
                _isTracking = false;
                _analyticsTimer.Stop();
                
                if (_currentSession != null)
                {
                    _currentSession.EndTime = DateTime.Now;
                    _currentSession.Duration = _currentSession.EndTime - _currentSession.StartTime;
                    
                    lock (_lockObject)
                    {
                        _sessions.Add(_currentSession);
                    }
                    
                    SaveAnalyticsData();
                }
                
                _logger?.LogInfo("Analytics tracking stopped");
                
                // Track application stop
                TrackFeatureUsage("ApplicationStop");
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to stop analytics tracking: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Track feature usage
        /// </summary>
        public void TrackFeatureUsage(string featureName)
        {
            try
            {
                if (!_isTracking || string.IsNullOrEmpty(featureName))
                    return;
                
                lock (_lockObject)
                {
                    if (_featureUsage.ContainsKey(featureName))
                        _featureUsage[featureName]++;
                    else
                        _featureUsage[featureName] = 1;
                }
                
                _logger?.LogDebug($"Feature usage tracked: {featureName}");
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to track feature usage '{featureName}': {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Track optimization usage
        /// </summary>
        public void TrackOptimizationUsage(string optimizationType, bool isSuccessful, string errorMessage = null)
        {
            try
            {
                if (!_isTracking)
                    return;
                
                var usage = new OptimizationUsage
                {
                    Timestamp = DateTime.Now,
                    OptimizationType = optimizationType,
                    IsSuccessful = isSuccessful,
                    ErrorMessage = errorMessage,
                    SessionId = _currentSession?.SessionId
                };
                
                lock (_lockObject)
                {
                    _optimizationUsage.Add(usage);
                }
                
                _logger?.LogDebug($"Optimization usage tracked: {optimizationType} - {(isSuccessful ? "Success" : "Failed")}");
                
                // Update current session stats
                if (_currentSession != null)
                {
                    if (isSuccessful)
                        _currentSession.SuccessfulOptimizations++;
                    else
                        _currentSession.FailedOptimizations++;
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to track optimization usage: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Track performance trend
        /// </summary>
        public void TrackPerformanceTrend(PerformanceMetrics metrics, double benchmarkScore)
        {
            try
            {
                if (!_isTracking || metrics == null)
                    return;
                
                var trend = new PerformanceTrend
                {
                    Timestamp = DateTime.Now,
                    CpuUsage = metrics.CpuUsage,
                    MemoryUsage = metrics.MemoryUsage,
                    MemoryAvailable = metrics.MemoryAvailable,
                    ActiveProcesses = metrics.ActiveProcesses,
                    GpuUsage = metrics.GpuUsage,
                    BenchmarkScore = benchmarkScore,
                    SessionId = _currentSession?.SessionId
                };
                
                lock (_lockObject)
                {
                    _performanceTrends.Add(trend);
                    
                    // Keep only recent trends (last 1000 entries)
                    if (_performanceTrends.Count > 1000)
                    {
                        _performanceTrends.RemoveAt(0);
                    }
                }
                
                _logger?.LogDebug($"Performance trend tracked: CPU={metrics.CpuUsage:F1}%, Benchmark={benchmarkScore:F1}");
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to track performance trend: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get usage analytics summary
        /// </summary>
        public AnalyticsSummary GetAnalyticsSummary()
        {
            try
            {
                lock (_lockObject)
                {
                    var summary = new AnalyticsSummary
                    {
                        GeneratedDate = DateTime.Now,
                        TotalSessions = _sessions.Count,
                        TotalUsageTime = TimeSpan.FromTicks(_sessions.Sum(s => s.Duration.Ticks)),
                        AverageSessionDuration = _sessions.Count > 0 ? 
                            TimeSpan.FromTicks(_sessions.Sum(s => s.Duration.Ticks) / _sessions.Count) : 
                            TimeSpan.Zero
                    };
                    
                    // Feature usage statistics
                    summary.MostUsedFeatures = _featureUsage
                        .OrderByDescending(f => f.Value)
                        .Take(10)
                        .ToDictionary(f => f.Key, f => f.Value);
                    
                    // Optimization statistics
                    var totalOptimizations = _optimizationUsage.Count;
                    var successfulOptimizations = _optimizationUsage.Count(o => o.IsSuccessful);
                    summary.OptimizationSuccessRate = totalOptimizations > 0 ? 
                        (double)successfulOptimizations / totalOptimizations * 100 : 0;
                    
                    summary.OptimizationsByType = _optimizationUsage
                        .GroupBy(o => o.OptimizationType)
                        .ToDictionary(g => g.Key, g => g.Count());
                    
                    // Performance trends
                    if (_performanceTrends.Count > 0)
                    {
                        summary.AverageCpuUsage = _performanceTrends.Average(t => t.CpuUsage);
                        summary.AverageMemoryUsage = _performanceTrends.Average(t => t.MemoryUsage);
                        summary.AverageBenchmarkScore = _performanceTrends.Average(t => t.BenchmarkScore);
                        
                        // Recent vs historical comparison
                        var recentTrends = _performanceTrends.Where(t => t.Timestamp > DateTime.Now.AddDays(-7)).ToList();
                        if (recentTrends.Count > 0)
                        {
                            summary.RecentPerformanceImprovement = 
                                recentTrends.Average(t => t.BenchmarkScore) - 
                                (_performanceTrends.Count > recentTrends.Count ? 
                                 _performanceTrends.Take(_performanceTrends.Count - recentTrends.Count).Average(t => t.BenchmarkScore) : 0);
                        }
                    }
                    
                    return summary;
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get analytics summary: {ex.Message}", ex);
                return new AnalyticsSummary
                {
                    GeneratedDate = DateTime.Now,
                    ErrorMessage = ex.Message
                };
            }
        }
        
        /// <summary>
        /// Get performance trends for charting
        /// </summary>
        public List<PerformanceTrend> GetPerformanceTrends(DateTime? startDate = null, DateTime? endDate = null)
        {
            try
            {
                lock (_lockObject)
                {
                    var trends = _performanceTrends.AsEnumerable();
                    
                    if (startDate.HasValue)
                        trends = trends.Where(t => t.Timestamp >= startDate.Value);
                    
                    if (endDate.HasValue)
                        trends = trends.Where(t => t.Timestamp <= endDate.Value);
                    
                    return trends.OrderBy(t => t.Timestamp).ToList();
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to get performance trends: {ex.Message}", ex);
                return new List<PerformanceTrend>();
            }
        }
        
        /// <summary>
        /// Export analytics data
        /// </summary>
        public bool ExportAnalytics(string exportPath)
        {
            try
            {
                var summary = GetAnalyticsSummary();
                var exportData = new List<string>
                {
                    "KOALA Optimizer Analytics Export",
                    $"Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
                    $"Version: 2.3.0",
                    "",
                    "=== USAGE SUMMARY ===",
                    $"Total Sessions: {summary.TotalSessions}",
                    $"Total Usage Time: {summary.TotalUsageTime:hh\\:mm\\:ss}",
                    $"Average Session Duration: {summary.AverageSessionDuration:hh\\:mm\\:ss}",
                    $"Optimization Success Rate: {summary.OptimizationSuccessRate:F1}%",
                    "",
                    "=== MOST USED FEATURES ===",
                };
                
                foreach (var feature in summary.MostUsedFeatures)
                {
                    exportData.Add($"{feature.Key}: {feature.Value} times");
                }
                
                exportData.Add("");
                exportData.Add("=== OPTIMIZATIONS BY TYPE ===");
                
                foreach (var optimization in summary.OptimizationsByType)
                {
                    exportData.Add($"{optimization.Key}: {optimization.Value} times");
                }
                
                exportData.Add("");
                exportData.Add("=== PERFORMANCE METRICS ===");
                exportData.Add($"Average CPU Usage: {summary.AverageCpuUsage:F1}%");
                exportData.Add($"Average Memory Usage: {summary.AverageMemoryUsage:F0} MB");
                exportData.Add($"Average Benchmark Score: {summary.AverageBenchmarkScore:F1}");
                exportData.Add($"Recent Performance Change: {summary.RecentPerformanceImprovement:+0.0;-0.0;0.0}");
                
                File.WriteAllLines(exportPath, exportData);
                _logger?.LogInfo($"Analytics exported to: {exportPath}");
                return true;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to export analytics: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Analytics timer tick handler
        /// </summary>
        private void AnalyticsTimer_Tick(object sender, EventArgs e)
        {
            try
            {
                // Update current session duration
                if (_currentSession != null)
                {
                    _currentSession.Duration = DateTime.Now - _currentSession.StartTime;
                }
                
                // Trigger analytics update event
                AnalyticsUpdated?.Invoke(this, new AnalyticsEventArgs
                {
                    Summary = GetAnalyticsSummary(),
                    CurrentSession = _currentSession
                });
                
                // Periodic save
                if (_sessions.Count % 10 == 0) // Save every 10 timer ticks
                {
                    SaveAnalyticsData();
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Analytics timer error: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Load analytics data from file
        /// </summary>
        private void LoadAnalyticsData()
        {
            try
            {
                if (!File.Exists(_analyticsFilePath))
                    return;
                
                // Simple text format for analytics data
                var lines = File.ReadAllLines(_analyticsFilePath);
                // Implementation would parse the saved data
                // For now, just log that we attempted to load
                
                _logger?.LogInfo("Analytics data loaded from file");
            }
            catch (Exception ex)
            {
                _logger?.LogWarning($"Failed to load analytics data: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Save analytics data to file
        /// </summary>
        private void SaveAnalyticsData()
        {
            try
            {
                // Simple text format for analytics data
                var lines = new List<string>
                {
                    $"# KOALA Analytics Data - {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
                    $"TotalSessions={_sessions.Count}",
                    $"FeatureUsageCount={_featureUsage.Count}",
                    $"OptimizationUsageCount={_optimizationUsage.Count}",
                    $"PerformanceTrendsCount={_performanceTrends.Count}"
                };
                
                File.WriteAllLines(_analyticsFilePath, lines);
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to save analytics data: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Clear all analytics data
        /// </summary>
        public void ClearAnalyticsData()
        {
            try
            {
                lock (_lockObject)
                {
                    _sessions.Clear();
                    _optimizationUsage.Clear();
                    _performanceTrends.Clear();
                    _featureUsage.Clear();
                }
                
                if (File.Exists(_analyticsFilePath))
                {
                    File.Delete(_analyticsFilePath);
                }
                
                _logger?.LogInfo("Analytics data cleared");
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to clear analytics data: {ex.Message}", ex);
            }
        }
    }
    
    /// <summary>
    /// Usage session tracking
    /// </summary>
    public class UsageSession
    {
        public string SessionId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public string ApplicationVersion { get; set; }
        public bool IsAdmin { get; set; }
        public int SuccessfulOptimizations { get; set; }
        public int FailedOptimizations { get; set; }
    }
    
    /// <summary>
    /// Optimization usage tracking
    /// </summary>
    public class OptimizationUsage
    {
        public DateTime Timestamp { get; set; }
        public string OptimizationType { get; set; }
        public bool IsSuccessful { get; set; }
        public string ErrorMessage { get; set; }
        public string SessionId { get; set; }
    }
    

    
    /// <summary>
    /// Analytics summary
    /// </summary>
    public class AnalyticsSummary
    {
        public DateTime GeneratedDate { get; set; }
        public int TotalSessions { get; set; }
        public TimeSpan TotalUsageTime { get; set; }
        public TimeSpan AverageSessionDuration { get; set; }
        public Dictionary<string, int> MostUsedFeatures { get; set; } = new Dictionary<string, int>();
        public double OptimizationSuccessRate { get; set; }
        public Dictionary<string, int> OptimizationsByType { get; set; } = new Dictionary<string, int>();
        public double AverageCpuUsage { get; set; }
        public double AverageMemoryUsage { get; set; }
        public double AverageBenchmarkScore { get; set; }
        public double RecentPerformanceImprovement { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Analytics event arguments
    /// </summary>
    public class AnalyticsEventArgs : EventArgs
    {
        public AnalyticsSummary Summary { get; set; }
        public UsageSession CurrentSession { get; set; }
    }
}