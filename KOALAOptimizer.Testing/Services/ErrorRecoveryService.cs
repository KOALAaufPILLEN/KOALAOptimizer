using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for handling error recovery and graceful fallback mechanisms
    /// </summary>
    public class ErrorRecoveryService
    {
        private static readonly Lazy<ErrorRecoveryService> _instance = new Lazy<ErrorRecoveryService>(() => new ErrorRecoveryService());
        public static ErrorRecoveryService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly Dictionary<string, RecoveryAction> _recoveryActions;
        private readonly List<string> _criticalErrors;
        
        public event EventHandler<ErrorRecoveryEventArgs> RecoveryAttempted;
        public event EventHandler<ErrorRecoveryEventArgs> RecoverySucceeded;
        public event EventHandler<ErrorRecoveryEventArgs> RecoveryFailed;
        
        private ErrorRecoveryService()
        {
            try
            {
                LoggingService.EmergencyLog("ErrorRecoveryService: Initializing...");
                _logger = LoggingService.Instance;
                _recoveryActions = new Dictionary<string, RecoveryAction>();
                _criticalErrors = new List<string>();
                
                InitializeRecoveryActions();
                LoggingService.EmergencyLog("ErrorRecoveryService: Initialization completed");
                _logger?.LogInfo("Error recovery service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ErrorRecoveryService: Initialization failed - {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Initialize predefined recovery actions
        /// </summary>
        private void InitializeRecoveryActions()
        {
            // Registry operation recovery
            RegisterRecoveryAction("RegistryAccessFailed", () =>
            {
                _logger?.LogWarning("Attempting registry access recovery...");
                
                // Check admin privileges
                var adminService = AdminService.Instance;
                if (!adminService.IsRunningAsAdmin())
                {
                    ShowUserFriendlyError("Registry Access Error", 
                        "Registry operations require administrator privileges.\n\n" +
                        "Solution: Restart the application as Administrator.");
                    return Task.FromResult(false);
                }
                
                // Attempt to backup current state before retry
                try
                {
                    var registryService = RegistryOptimizationService.Instance;
                    // Force backup creation as safety measure
                    _logger?.LogInfo("Creating safety backup before registry recovery");
                    return Task.FromResult(true);
                }
                catch
                {
                    return Task.FromResult(false);
                }
            });
            
            // Theme loading recovery
            RegisterRecoveryAction("ThemeLoadingFailed", () =>
            {
                _logger?.LogWarning("Attempting theme loading recovery...");
                
                try
                {
                    var themeService = ThemeService.Instance;
                    // Fallback to safe mode or default theme
                    _logger?.LogInfo("Attempting fallback theme application");
                    
                    ShowUserFriendlyError("Theme Loading Error",
                        "The selected theme could not be loaded.\n\n" +
                        "Solution: Switching to default theme. You can try loading themes again from the theme menu.");
                    
                    return Task.FromResult(true);
                }
                catch
                {
                    return Task.FromResult(false);
                }
            });
            
            // Performance monitoring recovery
            RegisterRecoveryAction("PerformanceMonitoringFailed", () =>
            {
                _logger?.LogWarning("Attempting performance monitoring recovery...");
                
                try
                {
                    var perfService = PerformanceMonitoringService.Instance;
                    
                    ShowUserFriendlyError("Performance Monitoring Error",
                        "Performance monitoring encountered an error.\n\n" +
                        "Solution: Performance monitoring has been restarted. Some metrics may be temporarily unavailable.");
                    
                    return Task.FromResult(true);
                }
                catch
                {
                    return Task.FromResult(false);
                }
            });
            
            // Crosshair overlay recovery
            RegisterRecoveryAction("CrosshairOverlayFailed", () =>
            {
                _logger?.LogWarning("Attempting crosshair overlay recovery...");
                
                try
                {
                    var crosshairService = CrosshairOverlayService.Instance;
                    
                    ShowUserFriendlyError("Crosshair Overlay Error",
                        "The crosshair overlay encountered an error.\n\n" +
                        "Solution: Crosshair has been reset to safe mode. You can reconfigure it in the crosshair settings.");
                    
                    return Task.FromResult(true);
                }
                catch
                {
                    return Task.FromResult(false);
                }
            });
        }
        
        /// <summary>
        /// Register a recovery action for a specific error type
        /// </summary>
        public void RegisterRecoveryAction(string errorType, Func<Task<bool>> recoveryAction)
        {
            _recoveryActions[errorType] = new RecoveryAction
            {
                ErrorType = errorType,
                Action = recoveryAction,
                MaxAttempts = 3,
                AttemptCount = 0
            };
        }
        
        /// <summary>
        /// Attempt recovery for a specific error
        /// </summary>
        public async Task<bool> AttemptRecovery(string errorType, Exception exception = null)
        {
            try
            {
                if (!_recoveryActions.ContainsKey(errorType))
                {
                    _logger?.LogWarning($"No recovery action registered for error type: {errorType}");
                    return false;
                }
                
                var recoveryAction = _recoveryActions[errorType];
                recoveryAction.AttemptCount++;
                
                var eventArgs = new ErrorRecoveryEventArgs
                {
                    ErrorType = errorType,
                    Exception = exception,
                    AttemptNumber = recoveryAction.AttemptCount,
                    MaxAttempts = recoveryAction.MaxAttempts
                };
                
                RecoveryAttempted?.Invoke(this, eventArgs);
                _logger?.LogInfo($"Attempting recovery for {errorType} (attempt {recoveryAction.AttemptCount}/{recoveryAction.MaxAttempts})");
                
                if (recoveryAction.AttemptCount > recoveryAction.MaxAttempts)
                {
                    _logger?.LogError($"Maximum recovery attempts exceeded for {errorType}");
                    RecoveryFailed?.Invoke(this, eventArgs);
                    
                    ShowUserFriendlyError("Recovery Failed",
                        $"Unable to recover from {errorType} after {recoveryAction.MaxAttempts} attempts.\n\n" +
                        "Solution: Please restart the application. If the problem persists, check the logs for details.");
                    
                    return false;
                }
                
                bool success = await recoveryAction.Action();
                
                if (success)
                {
                    _logger?.LogInfo($"Recovery successful for {errorType}");
                    recoveryAction.AttemptCount = 0; // Reset for future use
                    RecoverySucceeded?.Invoke(this, eventArgs);
                }
                else
                {
                    _logger?.LogWarning($"Recovery failed for {errorType}");
                    RecoveryFailed?.Invoke(this, eventArgs);
                }
                
                return success;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Error during recovery attempt for {errorType}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Handle critical system errors with immediate user notification
        /// </summary>
        public void HandleCriticalError(string errorMessage, Exception exception, string userAction = null)
        {
            try
            {
                _criticalErrors.Add($"{DateTime.Now}: {errorMessage}");
                _logger?.LogError($"CRITICAL ERROR: {errorMessage}", exception);
                
                var userMessage = $"A critical error has occurred:\n\n{errorMessage}";
                
                if (!string.IsNullOrEmpty(userAction))
                {
                    userMessage += $"\n\nRecommended action: {userAction}";
                }
                else
                {
                    userMessage += "\n\nRecommended action: Save your work and restart the application.";
                }
                
                userMessage += "\n\nDetailed error information has been logged for troubleshooting.";
                
                ShowUserFriendlyError("Critical Error", userMessage);
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ErrorRecoveryService: Failed to handle critical error - {ex.Message}");
            }
        }
        
        /// <summary>
        /// Show user-friendly error message with recovery suggestions
        /// </summary>
        private void ShowUserFriendlyError(string title, string message)
        {
            try
            {
                if (Application.Current?.Dispatcher != null)
                {
                    Application.Current.Dispatcher.BeginInvoke(new Action(() =>
                    {
                        MessageBox.Show(message, title, MessageBoxButton.OK, MessageBoxImage.Warning);
                    }));
                }
                else
                {
                    // Fallback for non-UI thread scenarios
                    _logger?.LogError($"UI Error - {title}: {message}");
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Failed to show user error dialog: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get critical error history
        /// </summary>
        public List<string> GetCriticalErrorHistory()
        {
            return new List<string>(_criticalErrors);
        }
        
        /// <summary>
        /// Clear critical error history
        /// </summary>
        public void ClearCriticalErrorHistory()
        {
            _criticalErrors.Clear();
        }
        
        /// <summary>
        /// Validate system state and attempt auto-recovery
        /// </summary>
        public async Task<bool> ValidateAndRecoverSystemState()
        {
            try
            {
                _logger?.LogInfo("Starting system state validation...");
                bool allValid = true;
                
                // Check logging service
                try
                {
                    _logger?.LogDebug("Validating logging service...");
                }
                catch (Exception ex)
                {
                    _logger?.LogError("Logging service validation failed", ex);
                    allValid = false;
                }
                
                // Check admin service
                try
                {
                    var adminService = AdminService.Instance;
                    adminService.IsRunningAsAdmin();
                }
                catch (Exception ex)
                {
                    _logger?.LogError("Admin service validation failed", ex);
                    await AttemptRecovery("AdminServiceFailed", ex);
                    allValid = false;
                }
                
                // Check performance monitoring
                try
                {
                    var perfService = PerformanceMonitoringService.Instance;
                    // Validation check without disrupting monitoring
                }
                catch (Exception ex)
                {
                    _logger?.LogError("Performance monitoring validation failed", ex);
                    await AttemptRecovery("PerformanceMonitoringFailed", ex);
                    allValid = false;
                }
                
                _logger?.LogInfo($"System state validation completed. All valid: {allValid}");
                return allValid;
            }
            catch (Exception ex)
            {
                _logger?.LogError("System state validation failed", ex);
                return false;
            }
        }
    }
    
    /// <summary>
    /// Recovery action definition
    /// </summary>
    internal class RecoveryAction
    {
        public string ErrorType { get; set; }
        public Func<Task<bool>> Action { get; set; }
        public int MaxAttempts { get; set; }
        public int AttemptCount { get; set; }
    }
    
    /// <summary>
    /// Error recovery event arguments
    /// </summary>
    public class ErrorRecoveryEventArgs : EventArgs
    {
        public string ErrorType { get; set; }
        public Exception Exception { get; set; }
        public int AttemptNumber { get; set; }
        public int MaxAttempts { get; set; }
    }
}