using System;
using System.Diagnostics;
using System.Reflection;
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
        
        /// <summary>
        /// Application constructor with early error detection
        /// </summary>
        public App()
        {
            try
            {
                // Emergency logging at the very start
                LoggingService.EmergencyLog("App constructor: Application starting...");
                LoggingService.EmergencyLog($"App constructor: Assembly version {Assembly.GetExecutingAssembly().GetName().Version}");
                LoggingService.EmergencyLog($"App constructor: Runtime version {Environment.Version}");
                LoggingService.EmergencyLog($"App constructor: Working directory {Environment.CurrentDirectory}");
                
                // Initialize component
                InitializeComponent();
                LoggingService.EmergencyLog("App constructor: InitializeComponent completed successfully");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"App constructor: CRITICAL ERROR - {ex.Message}");
                LoggingService.EmergencyLog($"App constructor: Exception details - {ex}");
                
                // Try to show error message and exit gracefully
                try
                {
                    MessageBox.Show($"Critical startup error in App constructor:\n\n{ex.Message}\n\nThe application cannot continue. Please check the emergency log in your temp folder.", 
                                   "KOALA Gaming Optimizer - Critical Startup Error", 
                                   MessageBoxButton.OK, MessageBoxImage.Error);
                }
                catch
                {
                    // If even MessageBox fails, force exit
                    Environment.Exit(1);
                }
                throw;
            }
        }
        
        protected override void OnStartup(StartupEventArgs e)
        {
            LoggingService.EmergencyLog("OnStartup: Method entry");
            
            try
            {
                // Initialize core services FIRST before anything else
                LoggingService.EmergencyLog("OnStartup: Initializing core services...");
                
                try
                {
                    _loggingService = LoggingService.Instance;
                    _loggingService.LogStartupMilestone("LoggingService initialized");
                }
                catch (Exception ex)
                {
                    LoggingService.EmergencyLog($"OnStartup: CRITICAL - LoggingService initialization failed: {ex.Message}");
                    throw new InvalidOperationException("Failed to initialize logging service", ex);
                }
                
                try
                {
                    _adminService = AdminService.Instance;
                    _loggingService.LogStartupMilestone("AdminService initialized");
                }
                catch (Exception ex)
                {
                    _loggingService.LogError($"AdminService initialization failed: {ex.Message}", ex);
                    _loggingService.LogWarning("Continuing without AdminService - some features may be limited");
                    _adminService = null;
                }
                
                try
                {
                    _crosshairService = CrosshairOverlayService.Instance;
                    _loggingService.LogStartupMilestone("CrosshairOverlayService initialized");
                }
                catch (Exception ex)
                {
                    _loggingService.LogError($"CrosshairOverlayService initialization failed: {ex.Message}", ex);
                    _loggingService.LogWarning("Continuing without CrosshairOverlayService - crosshair features will be disabled");
                    _crosshairService = null;
                }
                
                // Set up global exception handling EARLY
                _loggingService.LogStartupMilestone("Setting up global exception handlers");
                this.DispatcherUnhandledException += App_DispatcherUnhandledException;
                AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;
                
                // Log system information
                LogSystemInformation();
                
                _loggingService.LogInfo("KOALA Gaming Optimizer v2.3 C# Edition - Starting...");
                _loggingService.LogStartupMilestone("Core initialization complete");
                
                // Load theme with robust error handling BEFORE base.OnStartup()
                _loggingService.LogStartupMilestone("Loading initial theme");
                try
                {
                    LoadInitialTheme();
                    _loggingService.LogStartupMilestone("Initial theme loaded successfully");
                }
                catch (Exception themeEx)
                {
                    _loggingService.LogError($"Critical theme loading error: {themeEx.Message}", themeEx);
                    
                    // Try to load a minimal fallback theme
                    try
                    {
                        _loggingService.LogStartupMilestone("Attempting fallback theme load");
                        LoadMinimalFallbackTheme();
                        _loggingService.LogStartupMilestone("Fallback theme loaded successfully");
                    }
                    catch (Exception fallbackEx)
                    {
                        _loggingService.LogError($"Failed to load even fallback theme: {fallbackEx.Message}", fallbackEx);
                        _loggingService.LogWarning("Continuing with system default theme");
                    }
                }
                
                _loggingService.LogStartupMilestone("Calling base.OnStartup");
                base.OnStartup(e);
                _loggingService.LogStartupMilestone("base.OnStartup completed");
                
                // Initialize theme service after basic startup
                try
                {
                    _loggingService.LogStartupMilestone("Initializing ThemeService");
                    var themeService = ThemeService.Instance;
                    _loggingService.LogInfo("Theme service initialized");
                    
                    // Validate that the default theme is properly loaded
                    var currentTheme = themeService.GetCurrentTheme();
                    if (currentTheme == null)
                    {
                        _loggingService.LogWarning("No default theme loaded, applying SciFi theme");
                        if (themeService.ApplyTheme("SciFi"))
                        {
                            _loggingService.LogStartupMilestone("SciFi theme applied successfully");
                        }
                        else
                        {
                            _loggingService.LogWarning("Failed to apply SciFi theme, continuing with current state");
                        }
                    }
                    else
                    {
                        _loggingService.LogStartupMilestone($"Current theme: {currentTheme.DisplayName}");
                    }
                }
                catch (Exception themeEx)
                {
                    _loggingService.LogError($"Failed to initialize theme service: {themeEx.Message}", themeEx);
                    _loggingService.LogWarning("Continuing without theme service - theme switching will be disabled");
                }
                
                // Check admin privileges
                if (_adminService != null)
                {
                    try
                    {
                        if (!_adminService.IsRunningAsAdmin())
                        {
                            _loggingService.LogWarning("Not running as administrator. Some optimizations may be limited.");
                        }
                        else
                        {
                            _loggingService.LogInfo("Running with administrator privileges - All optimizations available");
                        }
                    }
                    catch (Exception ex)
                    {
                        _loggingService.LogError($"Failed to check admin privileges: {ex.Message}", ex);
                    }
                }
                
                if (_crosshairService != null)
                {
                    _loggingService.LogInfo("Crosshair overlay service initialized");
                }
                
                _loggingService.LogStartupMilestone("Application startup completed successfully");
                _loggingService.LogInfo("KOALA Gaming Optimizer is ready for use");
            }
            catch (Exception ex)
            {
                // Final catch-all for any startup errors
                var errorMessage = $"Critical startup error: {ex.Message}";
                LoggingService.EmergencyLog($"OnStartup: FATAL ERROR - {errorMessage}");
                LoggingService.EmergencyLog($"OnStartup: Exception details - {ex}");
                
                try
                {
                    _loggingService?.LogError($"FATAL STARTUP ERROR: {ex.Message}", ex);
                }
                catch { /* Ignore if logging fails */ }
                
                // Show error to user and exit gracefully
                try
                {
                    MessageBox.Show($"{errorMessage}\n\nException Details:\n{ex}\n\nPlease check the log files for more information.", 
                                   "KOALA Gaming Optimizer - Fatal Startup Error", 
                                   MessageBoxButton.OK, MessageBoxImage.Error);
                }
                catch
                {
                    // If MessageBox fails, just log and exit
                    LoggingService.EmergencyLog("OnStartup: CRITICAL - Even MessageBox failed, forcing exit");
                }
                
                // Exit the application
                Environment.Exit(1);
            }
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
            var errorMessage = "Unknown unhandled exception";
            Exception exception = null;
            
            if (e.ExceptionObject is Exception ex)
            {
                exception = ex;
                errorMessage = ex.Message;
                _loggingService?.LogError($"Unhandled domain exception: {ex.Message}", ex);
                LoggingService.EmergencyLog($"CurrentDomain_UnhandledException: {ex.Message}");
                LoggingService.EmergencyLog($"CurrentDomain_UnhandledException: Exception details - {ex}");
            }
            else
            {
                errorMessage = e.ExceptionObject?.ToString() ?? "Unknown exception object";
                _loggingService?.LogError($"Unhandled domain exception (non-Exception): {errorMessage}");
                LoggingService.EmergencyLog($"CurrentDomain_UnhandledException: Non-Exception object - {errorMessage}");
            }
            
            _loggingService?.LogError($"IsTerminating: {e.IsTerminating}");
            LoggingService.EmergencyLog($"CurrentDomain_UnhandledException: IsTerminating = {e.IsTerminating}");
            
            // If this is a terminating exception, try to show error message
            if (e.IsTerminating)
            {
                try
                {
                    var message = $"A fatal unhandled exception occurred:\n\n{errorMessage}\n\n" +
                                 "The application will now terminate. Please check the log files for more details.";
                    
                    MessageBox.Show(message, "KOALA Gaming Optimizer - Fatal Error", 
                                   MessageBoxButton.OK, MessageBoxImage.Error);
                }
                catch
                {
                    // If even MessageBox fails, just log
                    LoggingService.EmergencyLog("CurrentDomain_UnhandledException: CRITICAL - MessageBox failed");
                }
            }
        }
        
        protected override void OnExit(ExitEventArgs e)
        {
            LoggingService.EmergencyLog($"OnExit: Application exiting with code {e.ApplicationExitCode}");
            _loggingService?.LogInfo($"KOALA Gaming Optimizer - Shutting down (exit code: {e.ApplicationExitCode})...");
            
            // Cleanup services
            try
            {
                _loggingService?.LogInfo("Cleaning up services...");
                
                try
                {
                    TimerResolutionService.Instance?.RestoreOriginalResolution();
                    _loggingService?.LogInfo("TimerResolutionService cleaned up");
                }
                catch (Exception ex)
                {
                    _loggingService?.LogError($"Error cleaning up TimerResolutionService: {ex.Message}", ex);
                }
                
                try
                {
                    ProcessManagementService.Instance?.StopBackgroundMonitoring();
                    _loggingService?.LogInfo("ProcessManagementService cleaned up");
                }
                catch (Exception ex)
                {
                    _loggingService?.LogError($"Error cleaning up ProcessManagementService: {ex.Message}", ex);
                }
                
                try
                {
                    PerformanceMonitoringService.Instance?.StopMonitoring();
                    _loggingService?.LogInfo("PerformanceMonitoringService cleaned up");
                }
                catch (Exception ex)
                {
                    _loggingService?.LogError($"Error cleaning up PerformanceMonitoringService: {ex.Message}", ex);
                }
                
                try
                {
                    _crosshairService?.Dispose();
                    _loggingService?.LogInfo("CrosshairOverlayService cleaned up");
                }
                catch (Exception ex)
                {
                    _loggingService?.LogError($"Error cleaning up CrosshairOverlayService: {ex.Message}", ex);
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"OnExit: Error during service cleanup: {ex.Message}");
                _loggingService?.LogError($"Error during service cleanup: {ex.Message}", ex);
            }
            
            _loggingService?.LogInfo("KOALA Gaming Optimizer shutdown complete");
            LoggingService.EmergencyLog("OnExit: Shutdown complete, calling base.OnExit");
            
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
        
        /// <summary>
        /// Log comprehensive system information for debugging
        /// </summary>
        private void LogSystemInformation()
        {
            try
            {
                _loggingService.LogInfo("=== SYSTEM INFORMATION ===");
                _loggingService.LogInfo($"OS Version: {Environment.OSVersion}");
                _loggingService.LogInfo($"CLR Version: {Environment.Version}");
                _loggingService.LogInfo($"Machine Name: {Environment.MachineName}");
                _loggingService.LogInfo($"User Name: {Environment.UserName}");
                _loggingService.LogInfo($"Working Directory: {Environment.CurrentDirectory}");
                _loggingService.LogInfo($"Assembly Location: {Assembly.GetExecutingAssembly().Location}");
                _loggingService.LogInfo($"Assembly Version: {Assembly.GetExecutingAssembly().GetName().Version}");
                _loggingService.LogInfo($"Command Line: {Environment.CommandLine}");
                _loggingService.LogInfo($"Process ID: {Process.GetCurrentProcess().Id}");
                _loggingService.LogInfo($"Thread ID: {System.Threading.Thread.CurrentThread.ManagedThreadId}");
                _loggingService.LogInfo($"Is 64-bit OS: {Environment.Is64BitOperatingSystem}");
                _loggingService.LogInfo($"Is 64-bit Process: {Environment.Is64BitProcess}");
                _loggingService.LogInfo($"Processor Count: {Environment.ProcessorCount}");
                _loggingService.LogInfo($"Available Memory: {GC.GetTotalMemory(false):N0} bytes");
                _loggingService.LogInfo("=========================");
            }
            catch (Exception ex)
            {
                _loggingService?.LogError($"Failed to log system information: {ex.Message}", ex);
            }
        }
    }
}