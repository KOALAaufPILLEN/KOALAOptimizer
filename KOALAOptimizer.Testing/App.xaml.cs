using System;
using System.Windows;
using System.Windows.Media;
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
            // Initialize core services FIRST before anything else
            _loggingService = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _crosshairService = CrosshairOverlayService.Instance;
            
            // Set up global exception handling EARLY
            this.DispatcherUnhandledException += App_DispatcherUnhandledException;
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;
            
            _loggingService.LogInfo("KOALA Gaming Optimizer v2.3 C# Edition - Starting...");
            
            // Load theme with robust error handling BEFORE base.OnStartup()
            try
            {
                LoadInitialTheme();
            }
            catch (Exception themeEx)
            {
                _loggingService.LogError($"Critical theme loading error: {themeEx.Message}", themeEx);
                
                // Try to load a minimal fallback theme
                try
                {
                    LoadMinimalFallbackTheme();
                }
                catch (Exception fallbackEx)
                {
                    _loggingService.LogError($"Failed to load even fallback theme: {fallbackEx.Message}", fallbackEx);
                    // Continue with default system theme
                }
            }
            
            base.OnStartup(e);
            
            // Initialize theme service after basic startup
            try
            {
                var themeService = ThemeService.Instance;
                _loggingService.LogInfo("Theme service initialized");
                
                // Validate that the default theme is properly loaded
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
            bool isStyleError = false;
            
            if (e.Exception.Message.Contains("FrameworkElement.Style") || 
                e.Exception.Message.Contains("resource") ||
                e.Exception.Message.Contains("StaticResource") ||
                e.Exception.Message.Contains("DynamicResource") ||
                e.Exception.Message.Contains("ResourceDictionary") ||
                e.Exception.Message.Contains("pack://application"))
            {
                isStyleError = true;
                errorMessage = "A theme or style error occurred. The application will attempt to continue with default styling.\n\n" +
                              "This usually happens when theme files are corrupted or missing essential styles.\n\n" +
                              "Technical details: " + e.Exception.Message;
                errorTitle = "KOALA Gaming Optimizer - Theme Error";
                
                // Try to apply fallback theme
                try
                {
                    _loggingService?.LogInfo("Attempting to recover from style error...");
                    
                    // First try to load minimal fallback theme
                    LoadMinimalFallbackTheme();
                    
                    // Then try to initialize theme service with fallback
                    var themeService = ThemeService.Instance;
                    themeService?.ApplyTheme("SciFi");
                    
                    _loggingService?.LogInfo("Applied fallback theme after style error");
                    
                    // If we successfully recovered, just log and continue
                    e.Handled = true;
                    return;
                }
                catch (Exception themeEx)
                {
                    _loggingService?.LogError($"Failed to apply fallback theme: {themeEx.Message}", themeEx);
                    errorMessage += "\n\nAdditional error: Failed to load fallback theme. " +
                                   "Please reinstall the application or contact support.";
                }
            }
            
            MessageBox.Show(errorMessage, errorTitle, MessageBoxButton.OK, 
                           isStyleError ? MessageBoxImage.Warning : MessageBoxImage.Error);
            
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
        
        /// <summary>
        /// Load initial theme with robust error handling
        /// </summary>
        private void LoadInitialTheme()
        {
            try
            {
                _loggingService?.LogInfo("Loading initial SciFi theme...");
                var themeUri = new Uri("pack://application:,,,/Themes/SciFiTheme.xaml", UriKind.Absolute);
                var themeDict = new ResourceDictionary { Source = themeUri };
                
                // Validate essential resources exist
                if (ValidateEssentialResources(themeDict))
                {
                    Application.Current.Resources.MergedDictionaries.Insert(0, themeDict);
                    _loggingService?.LogInfo("Initial theme loaded successfully");
                }
                else
                {
                    throw new InvalidOperationException("SciFi theme is missing essential resources");
                }
            }
            catch (Exception ex)
            {
                _loggingService?.LogError($"Failed to load SciFi theme: {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Load minimal fallback theme when primary theme fails
        /// </summary>
        private void LoadMinimalFallbackTheme()
        {
            _loggingService?.LogInfo("Loading minimal fallback theme...");
            
            // Create a minimal theme with essential resources
            var fallbackDict = new ResourceDictionary();
            
            // Add essential brushes
            fallbackDict.Add("BackgroundBrush", new SolidColorBrush(Colors.DarkSlateGray));
            fallbackDict.Add("TextBrush", new SolidColorBrush(Colors.White));
            fallbackDict.Add("PrimaryBrush", new SolidColorBrush(Colors.CornflowerBlue));
            fallbackDict.Add("AccentBrush", new SolidColorBrush(Colors.Orange));
            fallbackDict.Add("BorderBrush", new SolidColorBrush(Colors.Gray));
            fallbackDict.Add("GroupBackgroundBrush", new SolidColorBrush(Colors.DimGray));
            fallbackDict.Add("HoverBrush", new SolidColorBrush(Colors.LightBlue));
            fallbackDict.Add("DarkBackgroundBrush", new SolidColorBrush(Colors.Black));
            fallbackDict.Add("DangerBrush", new SolidColorBrush(Colors.Red));
            fallbackDict.Add("SuccessBrush", new SolidColorBrush(Colors.Green));
            fallbackDict.Add("WarningBrush", new SolidColorBrush(Colors.Yellow));
            fallbackDict.Add("SecondaryBrush", new SolidColorBrush(Colors.LightGray));
            
            // Add minimal window style
            var windowStyle = new Style(typeof(Window));
            windowStyle.Setters.Add(new Setter(Window.BackgroundProperty, fallbackDict["BackgroundBrush"]));
            windowStyle.Setters.Add(new Setter(Window.ForegroundProperty, fallbackDict["TextBrush"]));
            fallbackDict.Add("MainWindowStyle", windowStyle);
            
            Application.Current.Resources.MergedDictionaries.Insert(0, fallbackDict);
            _loggingService?.LogInfo("Minimal fallback theme loaded");
        }
        
        /// <summary>
        /// Validate that essential resources exist in a theme dictionary
        /// </summary>
        private bool ValidateEssentialResources(ResourceDictionary themeDict)
        {
            string[] essentialResources = { 
                "BackgroundBrush", "TextBrush", "PrimaryBrush", 
                "AccentBrush", "BorderBrush", "MainWindowStyle" 
            };
            
            foreach (var resourceKey in essentialResources)
            {
                if (!themeDict.Contains(resourceKey))
                {
                    _loggingService?.LogWarning($"Theme missing essential resource: {resourceKey}");
                    return false;
                }
            }
            return true;
        }
    }
}