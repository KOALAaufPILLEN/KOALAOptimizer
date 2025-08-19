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
        private CrosshairOverlayService _crosshairService;
        
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            
            // Initialize core services
            _loggingService = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _crosshairService = CrosshairOverlayService.Instance;
            
            // Set up global exception handling
            this.DispatcherUnhandledException += App_DispatcherUnhandledException;
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;
            
            _loggingService.LogInfo("KOALA Gaming Optimizer v2.3 C# Edition - Starting...");
            
            // Initialize theme service and validate default theme
            try
            {
                var themeService = ThemeService.Instance;
                _loggingService.LogInfo("Theme service initialized");
                
                // Validate that the default theme (SciFi) is properly loaded
                var currentTheme = themeService.GetCurrentTheme();
                if (currentTheme == null)
                {
                    _loggingService.LogWarning("No default theme loaded, applying SciFi theme");
                    themeService.ApplyTheme("SciFi");
                }
            }
            catch (Exception themeEx)
            {
                _loggingService.LogError($"Failed to initialize theme service: {themeEx.Message}", themeEx);
            }
            
            // Check admin privileges
            if (!_adminService.IsRunningAsAdmin())
            {
                _loggingService.LogWarning("Not running as administrator. Some optimizations may be limited.");
            }
            else
            {
                _loggingService.LogInfo("Running with administrator privileges - All optimizations available");
            }
            
            _loggingService.LogInfo("Crosshair overlay service initialized");
        }
        
        private void App_DispatcherUnhandledException(object sender, System.Windows.Threading.DispatcherUnhandledExceptionEventArgs e)
        {
            _loggingService?.LogError($"Unhandled UI exception: {e.Exception.Message}", e.Exception);
            
            // Special handling for style/resource related exceptions
            string errorMessage = e.Exception.Message;
            string errorTitle = "KOALA Gaming Optimizer - Error";
            
            if (e.Exception.Message.Contains("FrameworkElement.Style") || 
                e.Exception.Message.Contains("resource") ||
                e.Exception.Message.Contains("StaticResource") ||
                e.Exception.Message.Contains("DynamicResource"))
            {
                errorMessage = "A theme or style error occurred. The application will attempt to continue with default styling.\n\n" +
                              "Technical details: " + e.Exception.Message;
                errorTitle = "KOALA Gaming Optimizer - Theme Error";
                
                // Try to apply fallback theme
                try
                {
                    var themeService = ThemeService.Instance;
                    themeService?.ApplyTheme("SciFi");
                    _loggingService?.LogInfo("Applied fallback theme after style error");
                }
                catch (Exception themeEx)
                {
                    _loggingService?.LogError($"Failed to apply fallback theme: {themeEx.Message}", themeEx);
                }
            }
            
            MessageBox.Show(errorMessage, errorTitle, MessageBoxButton.OK, MessageBoxImage.Error);
            
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
                _crosshairService?.Dispose();
            }
            catch (Exception ex)
            {
                _loggingService?.LogError($"Error during shutdown: {ex.Message}", ex);
            }
            
            base.OnExit(e);
        }
    }
}