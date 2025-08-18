using System;
using System.Diagnostics;
using System.Security.Principal;
using System.Windows;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for handling administrator privileges and elevation
    /// </summary>
    public class AdminService
    {
        private static readonly Lazy<AdminService> _instance = new Lazy<AdminService>(() => new AdminService());
        public static AdminService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        
        private AdminService()
        {
            _logger = LoggingService.Instance;
        }
        
        /// <summary>
        /// Check if the application is running with administrator privileges
        /// </summary>
        public bool IsRunningAsAdmin()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to check admin privileges: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Request elevation to administrator privileges
        /// </summary>
        public bool RequestElevation(bool showDialog = true)
        {
            if (IsRunningAsAdmin())
            {
                return true;
            }
            
            if (showDialog)
            {
                var result = MessageBox.Show(
                    "Administrator privileges are required for full optimization functionality.\n\n" +
                    "Would you like to restart the application as administrator?",
                    "Administrator Privileges Required",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);
                
                if (result != MessageBoxResult.Yes)
                {
                    return false;
                }
            }
            
            try
            {
                var processInfo = new ProcessStartInfo
                {
                    FileName = Process.GetCurrentProcess().MainModule.FileName,
                    UseShellExecute = true,
                    Verb = "runas",
                    WorkingDirectory = Environment.CurrentDirectory
                };
                
                Process.Start(processInfo);
                Application.Current.Shutdown();
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to restart with elevation: {ex.Message}", ex);
                
                if (showDialog)
                {
                    MessageBox.Show(
                        $"Failed to restart with administrator privileges:\n{ex.Message}",
                        "Elevation Failed",
                        MessageBoxButton.OK,
                        MessageBoxImage.Error);
                }
                
                return false;
            }
        }
        
        /// <summary>
        /// Check if a specific operation requires admin privileges
        /// </summary>
        public bool OperationRequiresAdmin(OptimizationType operationType)
        {
            switch (operationType)
            {
                case OptimizationType.Registry:
                case OptimizationType.Service:
                case OptimizationType.Power:
                case OptimizationType.Network:
                    return true;
                
                case OptimizationType.Process:
                case OptimizationType.GPU:
                case OptimizationType.Memory:
                case OptimizationType.Storage:
                    return false;
                
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// Get admin status message for UI display
        /// </summary>
        public string GetAdminStatusMessage()
        {
            if (IsRunningAsAdmin())
            {
                return "✓ Running with Administrator privileges - All optimizations available";
            }
            else
            {
                return "⚠ Limited privileges - Some optimizations require Administrator access";
            }
        }
        
        /// <summary>
        /// Check if current user can perform operation
        /// </summary>
        public bool CanPerformOperation(OptimizationItem operation, bool showWarning = true)
        {
            if (!operation.RequiresAdmin)
            {
                return true;
            }
            
            if (IsRunningAsAdmin())
            {
                return true;
            }
            
            if (showWarning)
            {
                _logger.LogWarning($"Operation '{operation.Name}' requires administrator privileges and will be skipped");
            }
            
            return false;
        }
        
        /// <summary>
        /// Validate admin requirements for a list of operations
        /// </summary>
        public AdminValidationResult ValidateOperations(System.Collections.Generic.List<OptimizationItem> operations)
        {
            var result = new AdminValidationResult
            {
                CanProceed = true,
                RequiresElevation = false
            };
            
            var isAdmin = IsRunningAsAdmin();
            
            foreach (var operation in operations)
            {
                if (operation.IsEnabled && operation.RequiresAdmin && !isAdmin)
                {
                    result.RequiresElevation = true;
                    result.RestrictedOperations.Add(operation);
                }
            }
            
            return result;
        }
    }
    
    /// <summary>
    /// Result of admin validation
    /// </summary>
    public class AdminValidationResult
    {
        public bool CanProceed { get; set; }
        public bool RequiresElevation { get; set; }
        public System.Collections.Generic.List<OptimizationItem> RestrictedOperations { get; set; } = new System.Collections.Generic.List<OptimizationItem>();
        
        public string GetSummary()
        {
            if (!RequiresElevation)
            {
                return "All selected optimizations can be applied.";
            }
            
            return $"{RestrictedOperations.Count} optimization(s) require administrator privileges and will be skipped.";
        }
    }
}