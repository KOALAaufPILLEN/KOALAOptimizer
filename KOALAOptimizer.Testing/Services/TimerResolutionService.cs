using System;
using System.Runtime.InteropServices;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for managing Windows timer resolution for gaming performance
    /// </summary>
    public class TimerResolutionService
    {
        private static readonly Lazy<TimerResolutionService> _instance = new Lazy<TimerResolutionService>(() => new TimerResolutionService());
        public static TimerResolutionService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private bool _isHighResolutionSet = false;
        
        // Windows API imports for timer resolution
        [DllImport("winmm.dll", EntryPoint = "timeBeginPeriod")]
        private static extern uint TimeBeginPeriod(uint uPeriod);
        
        [DllImport("winmm.dll", EntryPoint = "timeEndPeriod")]
        private static extern uint TimeEndPeriod(uint uPeriod);
        
        [DllImport("kernel32.dll")]
        private static extern uint GetTickCount();
        
        private TimerResolutionService()
        {
            try
            {
                LoggingService.EmergencyLog("TimerResolutionService: Initializing...");
                _logger = LoggingService.Instance;
                LoggingService.EmergencyLog("TimerResolutionService: Initialization completed");
                _logger?.LogInfo("Timer resolution service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"TimerResolutionService: Initialization failed - {ex.Message}");
                _logger = null;
            }
        }
        
        /// <summary>
        /// Set high precision timer (1ms resolution) for gaming performance
        /// </summary>
        public bool SetHighPrecisionTimer()
        {
            if (_isHighResolutionSet)
            {
                _logger.LogWarning("High precision timer is already set");
                return true;
            }
            
            try
            {
                // Request 1ms timer resolution
                uint result = TimeBeginPeriod(1);
                
                if (result == 0) // TIMERR_NOERROR
                {
                    _isHighResolutionSet = true;
                    _logger.LogInfo("High precision timer (1ms) enabled successfully");
                    return true;
                }
                else
                {
                    _logger.LogError($"Failed to set high precision timer. Error code: {result}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Exception setting high precision timer: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Restore original timer resolution
        /// </summary>
        public bool RestoreOriginalResolution()
        {
            if (!_isHighResolutionSet)
            {
                return true;
            }
            
            try
            {
                // End the 1ms timer period
                uint result = TimeEndPeriod(1);
                
                if (result == 0) // TIMERR_NOERROR
                {
                    _isHighResolutionSet = false;
                    _logger.LogInfo("Timer resolution restored to system default");
                    return true;
                }
                else
                {
                    _logger.LogError($"Failed to restore timer resolution. Error code: {result}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Exception restoring timer resolution: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Check if high precision timer is currently set
        /// </summary>
        public bool IsHighPrecisionTimerSet()
        {
            return _isHighResolutionSet;
        }
        
        /// <summary>
        /// Get current timer resolution status
        /// </summary>
        public string GetTimerStatus()
        {
            if (_isHighResolutionSet)
            {
                return "High Precision (1ms) - Gaming Optimized";
            }
            else
            {
                return "System Default (~15ms)";
            }
        }
        
        /// <summary>
        /// Test timer precision by measuring actual resolution
        /// </summary>
        public double MeasureTimerPrecision()
        {
            const int iterations = 100;
            double totalDifference = 0;
            
            try
            {
                uint previousTick = GetTickCount();
                
                for (int i = 0; i < iterations; i++)
                {
                    System.Threading.Thread.Sleep(1);
                    uint currentTick = GetTickCount();
                    uint difference = currentTick - previousTick;
                    totalDifference += difference;
                    previousTick = currentTick;
                }
                
                double averageResolution = totalDifference / iterations;
                _logger.LogInfo($"Measured timer resolution: {averageResolution:F2}ms average");
                
                return averageResolution;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to measure timer precision: {ex.Message}", ex);
                return -1;
            }
        }
        
        /// <summary>
        /// Validate timer performance
        /// </summary>
        public bool ValidateTimerPerformance()
        {
            try
            {
                var measuredResolution = MeasureTimerPrecision();
                
                if (measuredResolution < 0)
                {
                    return false;
                }
                
                // Consider good if resolution is better than 5ms
                bool isGood = measuredResolution <= 5.0;
                
                if (isGood)
                {
                    _logger.LogInfo($"Timer performance is good: {measuredResolution:F2}ms");
                }
                else
                {
                    _logger.LogWarning($"Timer performance is poor: {measuredResolution:F2}ms");
                }
                
                return isGood;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Timer performance validation failed: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Cleanup timer resolution on shutdown
        /// </summary>
        public void Cleanup()
        {
            if (_isHighResolutionSet)
            {
                RestoreOriginalResolution();
            }
        }
    }
}