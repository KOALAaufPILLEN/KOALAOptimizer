using System;
using System.Windows;
using KOALAOptimizer.Testing.Services;

namespace KOALAOptimizer.Testing
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        private LoggingService _loggingService;
        private AdminService _adminService;
        
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            
            // Initialize core services
            _loggingService = LoggingService.Instance;
            _adminService = AdminService.Instance;
            
            // Set up global exception handling
            this.DispatcherUnhandledException += App_DispatcherUnhandledException;
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;
            
            _loggingService.LogInfo("KOALA Gaming Optimizer v2.3 C# Edition - Starting...");
            
            // Check admin privileges
            if (!_adminService.IsRunningAsAdmin())
            {
                _loggingService.LogWarning("Not running as administrator. Some optimizations may be limited.");
            }
            else
            {
                _loggingService.LogInfo("Running with administrator privileges - All optimizations available");
            }
        }
        
        private void App_DispatcherUnhandledException(object sender, System.Windows.Threading.DispatcherUnhandledExceptionEventArgs e)
        {
            _loggingService?.LogError($"Unhandled UI exception: {e.Exception.Message}", e.Exception);
            
            MessageBox.Show($"An unexpected error occurred:\n{e.Exception.Message}", 
                          "KOALA Gaming Optimizer - Error", 
                          MessageBoxButton.OK, 
                          MessageBoxImage.Error);
            
            e.Handled = true;
        }
        
        private void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            if (e.ExceptionObject is Exception ex)
            {
                _loggingService?.LogError($"Unhandled domain exception: {ex.Message}", ex);
            }
        }
        
        protected override void OnExit(ExitEventArgs e)
        {
            _loggingService?.LogInfo("KOALA Gaming Optimizer - Shutting down...");
            
            // Cleanup services
            try
            {
                TimerResolutionService.Instance?.RestoreOriginalResolution();
                ProcessManagementService.Instance?.StopBackgroundMonitoring();
                PerformanceMonitoringService.Instance?.StopMonitoring();
            }
            catch (Exception ex)
            {
                _loggingService?.LogError($"Error during shutdown: {ex.Message}", ex);
            }
            
            base.OnExit(e);
        }
    }
}