using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for performance trending and predictive analytics
    /// </summary>
    public class PerformanceTrendingService
    {
        private static readonly Lazy<PerformanceTrendingService> _instance = new Lazy<PerformanceTrendingService>(() => new PerformanceTrendingService());
        public static PerformanceTrendingService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly PerformanceMonitoringService _performanceMonitor;
        private readonly Timer _analysisTimer;
        private readonly Queue<PerformanceSnapshot> _performanceHistory;
        private readonly Dictionary<string, List<double>> _trendData;
        private readonly int _maxHistorySize = 1000; // Keep last 1000 data points
        private bool _isRunning = false;
        
        public event EventHandler<PerformanceTrendEventArgs> TrendDetected;
        public event EventHandler<BottleneckDetectedEventArgs> BottleneckDetected;
        public event EventHandler<PerformancePredictionEventArgs> PredictionAvailable;
        
        private PerformanceTrendingService()
        {
            try
            {
                LoggingService.EmergencyLog("PerformanceTrendingService: Initializing...");
                _logger = LoggingService.Instance;
                _performanceMonitor = PerformanceMonitoringService.Instance;
                
                _performanceHistory = new Queue<PerformanceSnapshot>();
                _trendData = new Dictionary<string, List<double>>();
                
                // Initialize analysis timer (analyze every 30 seconds)
                _analysisTimer = new Timer(PerformTrendAnalysis, null, Timeout.Infinite, Timeout.Infinite);
                
                LoggingService.EmergencyLog("PerformanceTrendingService: Initialization completed");
                _logger.LogInfo("Performance trending service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"PerformanceTrendingService initialization failed: {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Start performance trending analysis
        /// </summary>
        public void StartTrending()
        {
            if (_isRunning)
                return;
                
            try
            {
                _isRunning = true;
                
                // Subscribe to performance updates
                _performanceMonitor.MetricsUpdated += OnPerformanceMetricsUpdated;
                
                // Start analysis timer
                _analysisTimer.Change(TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30));
                
                _logger.LogInfo("Performance trending started");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to start performance trending: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Stop performance trending analysis
        /// </summary>
        public void StopTrending()
        {
            if (!_isRunning)
                return;
                
            try
            {
                _isRunning = false;
                
                // Unsubscribe from performance updates
                _performanceMonitor.MetricsUpdated -= OnPerformanceMetricsUpdated;
                
                // Stop analysis timer
                _analysisTimer.Change(Timeout.Infinite, Timeout.Infinite);
                
                _logger.LogInfo("Performance trending stopped");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to stop performance trending: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Handle performance metrics updates
        /// </summary>
        private void OnPerformanceMetricsUpdated(object sender, PerformanceMetrics metrics)
        {
            try
            {
                if (!_isRunning)
                    return;
                    
                // Create performance snapshot
                var snapshot = new PerformanceSnapshot
                {
                    Timestamp = metrics.Timestamp,
                    CpuUsage = metrics.CpuUsage,
                    MemoryUsage = metrics.MemoryUsage,
                    MemoryAvailable = metrics.MemoryAvailable,
                    GpuUsage = metrics.GpuUsage,
                    ActiveProcesses = metrics.ActiveProcesses
                };
                
                // Add to history
                AddToHistory(snapshot);
                
                // Update trend data
                UpdateTrendData(snapshot);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to process performance metrics: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Add performance snapshot to history
        /// </summary>
        private void AddToHistory(PerformanceSnapshot snapshot)
        {
            lock (_performanceHistory)
            {
                _performanceHistory.Enqueue(snapshot);
                
                // Remove old data if we exceed max size
                while (_performanceHistory.Count > _maxHistorySize)
                {
                    _performanceHistory.Dequeue();
                }
            }
        }
        
        /// <summary>
        /// Update trend data for analysis
        /// </summary>
        private void UpdateTrendData(PerformanceSnapshot snapshot)
        {
            lock (_trendData)
            {
                AddToTrendData("cpu", snapshot.CpuUsage);
                AddToTrendData("memory", (double)snapshot.MemoryUsage / 1024 / 1024); // Convert to MB
                AddToTrendData("gpu", snapshot.GpuUsage);
                AddToTrendData("processes", snapshot.ActiveProcesses);
            }
        }
        
        /// <summary>
        /// Add data point to trend collection
        /// </summary>
        private void AddToTrendData(string metric, double value)
        {
            if (!_trendData.ContainsKey(metric))
            {
                _trendData[metric] = new List<double>();
            }
            
            _trendData[metric].Add(value);
            
            // Keep only recent data points for trend analysis
            if (_trendData[metric].Count > 100)
            {
                _trendData[metric].RemoveAt(0);
            }
        }
        
        /// <summary>
        /// Perform trend analysis
        /// </summary>
        private void PerformTrendAnalysis(object state)
        {
            try
            {
                if (!_isRunning)
                    return;
                    
                // Analyze trends for each metric
                foreach (var metric in _trendData.Keys.ToList())
                {
                    var trend = AnalyzeTrend(metric, _trendData[metric]);
                    if (trend != null)
                    {
                        TrendDetected?.Invoke(this, new PerformanceTrendEventArgs { Trend = trend });
                    }
                }
                
                // Detect bottlenecks
                var bottlenecks = DetectBottlenecks();
                foreach (var bottleneck in bottlenecks)
                {
                    BottleneckDetected?.Invoke(this, new BottleneckDetectedEventArgs { Bottleneck = bottleneck });
                }
                
                // Generate predictions
                var predictions = GeneratePredictions();
                if (predictions.Any())
                {
                    PredictionAvailable?.Invoke(this, new PerformancePredictionEventArgs { Predictions = predictions });
                }
                
                _logger.LogDebug("Performance trend analysis completed");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Performance trend analysis failed: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Analyze trend for a specific metric
        /// </summary>
        private PerformanceTrend AnalyzeTrend(string metricName, List<double> data)
        {
            try
            {
                if (data.Count < 10) // Need at least 10 data points for trend analysis
                    return null;
                    
                var trend = new PerformanceTrend
                {
                    MetricName = metricName,
                    Timestamp = DateTime.Now,
                    DataPoints = data.Count
                };
                
                // Calculate basic statistics
                trend.CurrentValue = data.Last();
                trend.AverageValue = data.Average();
                trend.MinValue = data.Min();
                trend.MaxValue = data.Max();
                
                // Calculate trend direction using linear regression
                var trendDirection = CalculateTrendDirection(data);
                trend.Direction = trendDirection;
                
                // Calculate trend strength (how consistent the trend is)
                trend.Strength = CalculateTrendStrength(data, trendDirection);
                
                // Determine trend type
                if (Math.Abs(trendDirection) < 0.1)
                {
                    trend.Type = TrendType.Stable;
                }
                else if (trendDirection > 0)
                {
                    trend.Type = TrendType.Increasing;
                }
                else
                {
                    trend.Type = TrendType.Decreasing;
                }
                
                // Set severity based on current value and trend
                trend.Severity = DetermineTrendSeverity(metricName, trend.CurrentValue, trend.Type);
                
                return trend;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to analyze trend for {metricName}: {ex.Message}", ex);
                return null;
            }
        }
        
        /// <summary>
        /// Calculate trend direction using simple linear regression
        /// </summary>
        private double CalculateTrendDirection(List<double> data)
        {
            int n = data.Count;
            double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
            
            for (int i = 0; i < n; i++)
            {
                sumX += i;
                sumY += data[i];
                sumXY += i * data[i];
                sumXX += i * i;
            }
            
            // Calculate slope (trend direction)
            double slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
            return slope;
        }
        
        /// <summary>
        /// Calculate trend strength (correlation coefficient)
        /// </summary>
        private double CalculateTrendStrength(List<double> data, double slope)
        {
            try
            {
                int n = data.Count;
                double meanY = data.Average();
                double meanX = (n - 1) / 2.0;
                
                double ssTotal = 0, ssRes = 0;
                
                for (int i = 0; i < n; i++)
                {
                    double predicted = slope * i + (meanY - slope * meanX);
                    ssRes += Math.Pow(data[i] - predicted, 2);
                    ssTotal += Math.Pow(data[i] - meanY, 2);
                }
                
                if (ssTotal == 0) return 0;
                
                double rSquared = 1 - (ssRes / ssTotal);
                return Math.Max(0, rSquared);
            }
            catch
            {
                return 0;
            }
        }
        
        /// <summary>
        /// Determine trend severity
        /// </summary>
        private TrendSeverity DetermineTrendSeverity(string metricName, double currentValue, TrendType trendType)
        {
            switch (metricName.ToLower())
            {
                case "cpu":
                    if (currentValue > 90 && trendType == TrendType.Increasing) return TrendSeverity.Critical;
                    if (currentValue > 70 && trendType == TrendType.Increasing) return TrendSeverity.Warning;
                    break;
                    
                case "memory":
                    if (currentValue > 8000 && trendType == TrendType.Increasing) return TrendSeverity.Critical; // 8GB+
                    if (currentValue > 6000 && trendType == TrendType.Increasing) return TrendSeverity.Warning; // 6GB+
                    break;
                    
                case "gpu":
                    if (currentValue > 95 && trendType == TrendType.Increasing) return TrendSeverity.Critical;
                    if (currentValue > 80 && trendType == TrendType.Increasing) return TrendSeverity.Warning;
                    break;
            }
            
            return TrendSeverity.Info;
        }
        
        /// <summary>
        /// Detect performance bottlenecks
        /// </summary>
        private List<PerformanceBottleneck> DetectBottlenecks()
        {
            var bottlenecks = new List<PerformanceBottleneck>();
            
            try
            {
                lock (_performanceHistory)
                {
                    if (_performanceHistory.Count < 5)
                        return bottlenecks;
                        
                    var recent = _performanceHistory.Skip(Math.Max(0, _performanceHistory.Count - 5)).ToList();
                    var avgCpu = recent.Average(r => r.CpuUsage);
                    var avgMemory = recent.Average(r => (double)r.MemoryUsage / 1024 / 1024);
                    var avgGpu = recent.Average(r => r.GpuUsage);
                    
                    // CPU bottleneck
                    if (avgCpu > 85)
                    {
                        bottlenecks.Add(new PerformanceBottleneck
                        {
                            Type = BottleneckType.CPU,
                            Severity = avgCpu > 95 ? BottleneckSeverity.Critical : BottleneckSeverity.High,
                            CurrentValue = avgCpu,
                            Description = $"CPU usage is consistently high at {avgCpu:F1}%",
                            Recommendations = new List<string>
                            {
                                "Close unnecessary applications",
                                "Check for background processes consuming CPU",
                                "Consider upgrading CPU for demanding workloads"
                            }
                        });
                    }
                    
                    // Memory bottleneck
                    if (avgMemory > 6000) // 6GB+
                    {
                        bottlenecks.Add(new PerformanceBottleneck
                        {
                            Type = BottleneckType.Memory,
                            Severity = avgMemory > 8000 ? BottleneckSeverity.Critical : BottleneckSeverity.High,
                            CurrentValue = avgMemory,
                            Description = $"Memory usage is high at {avgMemory:F0} MB",
                            Recommendations = new List<string>
                            {
                                "Close memory-intensive applications",
                                "Run memory defragmentation",
                                "Consider adding more RAM"
                            }
                        });
                    }
                    
                    // GPU bottleneck
                    if (avgGpu > 90)
                    {
                        bottlenecks.Add(new PerformanceBottleneck
                        {
                            Type = BottleneckType.GPU,
                            Severity = avgGpu > 98 ? BottleneckSeverity.Critical : BottleneckSeverity.High,
                            CurrentValue = avgGpu,
                            Description = $"GPU usage is maxed out at {avgGpu:F1}%",
                            Recommendations = new List<string>
                            {
                                "Lower graphics settings in games",
                                "Close GPU-intensive applications",
                                "Check GPU temperature and cooling"
                            }
                        });
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Bottleneck detection failed: {ex.Message}", ex);
            }
            
            return bottlenecks;
        }
        
        /// <summary>
        /// Generate performance predictions
        /// </summary>
        private List<PerformancePrediction> GeneratePredictions()
        {
            var predictions = new List<PerformancePrediction>();
            
            try
            {
                foreach (var metric in _trendData.Keys)
                {
                    if (_trendData[metric].Count >= 20) // Need enough data for prediction
                    {
                        var prediction = PredictMetric(metric, _trendData[metric]);
                        if (prediction != null)
                        {
                            predictions.Add(prediction);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Performance prediction failed: {ex.Message}", ex);
            }
            
            return predictions;
        }
        
        /// <summary>
        /// Predict future value for a metric
        /// </summary>
        private PerformancePrediction PredictMetric(string metricName, List<double> data)
        {
            try
            {
                var slope = CalculateTrendDirection(data);
                var currentValue = data.Last();
                
                // Predict values for next 5, 10, 30 minutes
                var prediction = new PerformancePrediction
                {
                    MetricName = metricName,
                    CurrentValue = currentValue,
                    Prediction5Min = currentValue + (slope * 10), // Assuming data points are 30s apart
                    Prediction10Min = currentValue + (slope * 20),
                    Prediction30Min = currentValue + (slope * 60),
                    Confidence = CalculateTrendStrength(data, slope),
                    Timestamp = DateTime.Now
                };
                
                // Only return predictions with reasonable confidence
                if (prediction.Confidence > 0.3)
                {
                    return prediction;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to predict metric {metricName}: {ex.Message}", ex);
            }
            
            return null;
        }
        
        /// <summary>
        /// Get performance history
        /// </summary>
        public List<PerformanceSnapshot> GetPerformanceHistory(TimeSpan timeRange)
        {
            lock (_performanceHistory)
            {
                var cutoff = DateTime.Now - timeRange;
                return _performanceHistory.Where(s => s.Timestamp >= cutoff).ToList();
            }
        }
        
        /// <summary>
        /// Get current trends
        /// </summary>
        public List<PerformanceTrend> GetCurrentTrends()
        {
            var trends = new List<PerformanceTrend>();
            
            foreach (var metric in _trendData.Keys)
            {
                var trend = AnalyzeTrend(metric, _trendData[metric]);
                if (trend != null)
                {
                    trends.Add(trend);
                }
            }
            
            return trends;
        }
        
        /// <summary>
        /// Get trending status
        /// </summary>
        public PerformanceTrendingStatus GetTrendingStatus()
        {
            return new PerformanceTrendingStatus
            {
                IsRunning = _isRunning,
                DataPointsCollected = _performanceHistory.Count,
                MetricsTracked = _trendData.Count,
                LastAnalysis = DateTime.Now
            };
        }
        
        /// <summary>
        /// Dispose resources
        /// </summary>
        public void Dispose()
        {
            try
            {
                StopTrending();
                _analysisTimer?.Dispose();
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Error disposing PerformanceTrendingService: {ex.Message}", ex);
            }
        }
    }
}