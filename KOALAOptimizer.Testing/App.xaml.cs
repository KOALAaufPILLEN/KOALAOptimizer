using System;
using System.Collections.Generic;
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
        /// Static constructor for early initialization
        /// </summary>
        static App()
        {
            try
            {
                LoggingService.EmergencyLog("App static constructor: Starting early initialization");
                
                // Log basic system information early
                LoggingService.EmergencyLog($"App static constructor: OS Version = {Environment.OSVersion}");
                LoggingService.EmergencyLog($"App static constructor: CLR Version = {Environment.Version}");
                LoggingService.EmergencyLog($"App static constructor: Is64BitOS = {Environment.Is64BitOperatingSystem}");
                LoggingService.EmergencyLog($"App static constructor: Is64BitProcess = {Environment.Is64BitProcess}");
                LoggingService.EmergencyLog($"App static constructor: ProcessorCount = {Environment.ProcessorCount}");
                
                LoggingService.EmergencyLog("App static constructor: Early initialization complete");
            }
            catch (Exception ex)
            {
                // Even emergency logging failed - this is very bad
                try
                {
                    System.Diagnostics.Debug.WriteLine($"CRITICAL: App static constructor failed: {ex}");
                    Console.WriteLine($"CRITICAL: App static constructor failed: {ex}");
                }
                catch
                {
                    // Can't do anything more
                }
            }
        }
        
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
                // EMERGENCY BYPASS MODE - If startup fails, try ultra-minimal mode
                bool emergencyMode = false;
                if (e.Args != null && e.Args.Contains("--emergency"))
                {
                    emergencyMode = true;
                    LoggingService.EmergencyLog("OnStartup: EMERGENCY MODE ACTIVATED");
                }
                
                if (emergencyMode)
                {
                    CreateEmergencyWindow();
                    return;
                }
                
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
                    // Try emergency mode if service initialization fails
                    LoggingService.EmergencyLog("OnStartup: Attempting emergency mode due to service failure");
                    CreateEmergencyWindow();
                    return;
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
                
                // Create and show main window with error handling
                _loggingService.LogStartupMilestone("Creating main window");
                try
                {
                    var mainWindow = new Views.MainWindow();
                    LoggingService.EmergencyLog("OnStartup: MainWindow instance created");
                    
                    mainWindow.Show();
                    LoggingService.EmergencyLog("OnStartup: MainWindow.Show() called successfully");
                    _loggingService.LogStartupMilestone("Main window displayed successfully");
                }
                catch (Exception windowEx)
                {
                    LoggingService.EmergencyLog($"OnStartup: CRITICAL - MainWindow creation/show failed: {windowEx.Message}");
                    _loggingService.LogError($"Failed to create or show main window: {windowEx.Message}", windowEx);
                    
                    // Show error and exit
                    try
                    {
                        MessageBox.Show($"Failed to create the main window:\n\n{windowEx.Message}\n\nThe application cannot continue.", 
                                       "KOALA Gaming Optimizer - Window Creation Error", 
                                       MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                    catch
                    {
                        LoggingService.EmergencyLog("OnStartup: CRITICAL - Even error MessageBox failed");
                    }
                    
                    Environment.Exit(1);
                }
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
            LoggingService.EmergencyLog($"App_DispatcherUnhandledException: {e.Exception.Message}");
            LoggingService.EmergencyLog($"App_DispatcherUnhandledException: Exception details - {e.Exception}");
            
            // Special handling for style/resource related exceptions
            string errorMessage = e.Exception.Message;
            string errorTitle = "KOALA Gaming Optimizer - Error";
            bool isStyleError = false;
            bool shouldTriggerEmergencyMode = false;
            
            if (e.Exception.Message.Contains("FrameworkElement.Style") || 
                e.Exception.Message.Contains("resource") ||
                e.Exception.Message.Contains("StaticResource") ||
                e.Exception.Message.Contains("DynamicResource") ||
                e.Exception.Message.Contains("ResourceDictionary") ||
                e.Exception.Message.Contains("pack://application") ||
                e.Exception.Message.Contains("Beim Festlegen der Eigenschaft") ||
                e.Exception.Message.Contains("System.Windows.FrameworkElement.Style"))
            {
                isStyleError = true;
                LoggingService.EmergencyLog("App_DispatcherUnhandledException: Style error detected");
                
                // If this is a FrameworkElement.Style error during startup, trigger emergency mode
                if (e.Exception.Message.Contains("FrameworkElement.Style") ||
                    e.Exception.Message.Contains("Beim Festlegen der Eigenschaft"))
                {
                    shouldTriggerEmergencyMode = true;
                    LoggingService.EmergencyLog("App_DispatcherUnhandledException: FrameworkElement.Style error - triggering emergency mode");
                }
                
                // Detect language for better error messages
                bool isGerman = e.Exception.Message.Contains("Beim Festlegen der Eigenschaft") ||
                               System.Globalization.CultureInfo.CurrentCulture.Name.StartsWith("de");
                
                if (shouldTriggerEmergencyMode)
                {
                    LoggingService.EmergencyLog("App_DispatcherUnhandledException: Attempting emergency mode activation");
                    
                    try
                    {
                        // Close all existing windows first
                        foreach (Window window in Application.Current.Windows)
                        {
                            if (window != null && window.IsLoaded)
                            {
                                window.Close();
                            }
                        }
                        
                        // Create emergency window
                        CreateEmergencyWindow();
                        e.Handled = true;
                        return;
                    }
                    catch (Exception emergencyEx)
                    {
                        LoggingService.EmergencyLog($"App_DispatcherUnhandledException: Emergency mode failed: {emergencyEx.Message}");
                        // Continue with normal error handling if emergency mode fails
                    }
                }
                
                if (isGerman)
                {
                    errorMessage = "Ein Design- oder Stilfehler ist aufgetreten. Die Anwendung wird versuchen, mit der Standardgestaltung fortzufahren.\n\n" +
                                  "Dies passiert normalerweise, wenn Designdateien beschädigt oder wichtige Stile fehlen.\n\n" +
                                  "Technische Details: " + e.Exception.Message;
                    errorTitle = "KOALA Gaming Optimizer - Design-Fehler";
                }
                else
                {
                    errorMessage = "A theme or style error occurred. The application will attempt to continue with default styling.\n\n" +
                                  "This usually happens when theme files are corrupted or missing essential styles.\n\n" +
                                  "Technical details: " + e.Exception.Message;
                    errorTitle = "KOALA Gaming Optimizer - Theme Error";
                }
                
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
                    
                    isGerman = e.Exception.Message.Contains("Beim Festlegen der Eigenschaft") ||
                              System.Globalization.CultureInfo.CurrentCulture.Name.StartsWith("de");
                    
                    if (isGerman)
                    {
                        errorMessage += "\n\nZusätzlicher Fehler: Fallback-Design konnte nicht geladen werden. " +
                                       "Bitte installieren Sie die Anwendung neu oder wenden Sie sich an den Support.";
                    }
                    else
                    {
                        errorMessage += "\n\nAdditional error: Failed to load fallback theme. " +
                                       "Please reinstall the application or contact support.";
                    }
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
                LoggingService.EmergencyLog("LoadInitialTheme: Starting theme load");
                
                // ENHANCED DIAGNOSTICS - Capture comprehensive state before theme loading
                CaptureDiagnosticSnapshot("PRE_THEME_LOAD");
                
                // NEW: Implement systematic phased loading
                if (LoadThemeSystematically("pack://application:,,,/Themes/SciFiTheme.xaml"))
                {
                    LoggingService.EmergencyLog("LoadInitialTheme: Systematic theme loading succeeded");
                    _loggingService?.LogInfo("SciFi theme loaded systematically and validated successfully");
                    
                    // Post-application diagnostics
                    CaptureDiagnosticSnapshot("POST_THEME_LOAD");
                }
                else
                {
                    LoggingService.EmergencyLog("LoadInitialTheme: Systematic theme loading failed, trying fallback");
                    throw new InvalidOperationException("Systematic theme loading failed");
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"LoadInitialTheme: FAILED - {ex.Message}");
                LoggingService.EmergencyLog($"LoadInitialTheme: Exception details - {ex}");
                _loggingService?.LogError($"Failed to load SciFi theme: {ex.Message}", ex);
                
                // Capture diagnostic snapshot at failure point
                CaptureDiagnosticSnapshot("THEME_LOAD_FAILURE");
                
                throw;
            }
        }
        
        /// <summary>
        /// Load theme systematically with progressive enhancement and rollback capability
        /// </summary>
        private bool LoadThemeSystematically(string themeUri)
        {
            var rollbackPoint = new ResourceDictionary();
            bool success = false;
            
            try
            {
                LoggingService.EmergencyLog("LoadThemeSystematically: Starting systematic theme loading");
                
                // Phase 1: Create rollback snapshot
                CaptureResourceSnapshot(rollbackPoint);
                LoggingService.EmergencyLog("LoadThemeSystematically: Rollback point captured");
                
                // Phase 2: Load theme into isolated dictionary
                var themeDict = new ResourceDictionary();
                try
                {
                    themeDict.Source = new Uri(themeUri, UriKind.Absolute);
                    LoggingService.EmergencyLog("LoadThemeSystematically: Theme dictionary loaded");
                }
                catch (Exception loadEx)
                {
                    LoggingService.EmergencyLog($"LoadThemeSystematically: Failed to load theme: {loadEx.Message}");
                    return false;
                }
                
                // Phase 3: Validate essential resources in isolation
                if (!ValidateResourcesInIsolation(themeDict))
                {
                    LoggingService.EmergencyLog("LoadThemeSystematically: Resource validation failed");
                    return false;
                }
                
                // Phase 4: Apply resources progressively with validation at each step
                success = ApplyResourcesProgressively(themeDict);
                
                if (!success)
                {
                    LoggingService.EmergencyLog("LoadThemeSystematically: Progressive application failed, rolling back");
                    RollbackToSnapshot(rollbackPoint);
                    return false;
                }
                
                LoggingService.EmergencyLog("LoadThemeSystematically: Theme applied successfully");
                return true;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"LoadThemeSystematically: Exception occurred: {ex.Message}");
                
                try
                {
                    RollbackToSnapshot(rollbackPoint);
                    LoggingService.EmergencyLog("LoadThemeSystematically: Rollback completed");
                }
                catch (Exception rollbackEx)
                {
                    LoggingService.EmergencyLog($"LoadThemeSystematically: CRITICAL - Rollback failed: {rollbackEx.Message}");
                }
                
                return false;
            }
        }
        
        /// <summary>
        /// Capture current resource state for rollback
        /// </summary>
        private void CaptureResourceSnapshot(ResourceDictionary snapshot)
        {
            try
            {
                LoggingService.EmergencyLog("CaptureResourceSnapshot: Capturing current resources");
                
                // Copy current merged dictionaries
                foreach (var dict in Application.Current.Resources.MergedDictionaries)
                {
                    var copyDict = new ResourceDictionary();
                    if (dict.Source != null)
                    {
                        copyDict.Source = dict.Source;
                    }
                    else
                    {
                        // Copy individual resources
                        foreach (var key in dict.Keys)
                        {
                            copyDict[key] = dict[key];
                        }
                    }
                    snapshot.MergedDictionaries.Add(copyDict);
                }
                
                // Copy direct resources
                foreach (var key in Application.Current.Resources.Keys)
                {
                    snapshot[key] = Application.Current.Resources[key];
                }
                
                LoggingService.EmergencyLog($"CaptureResourceSnapshot: Captured {snapshot.MergedDictionaries.Count} merged dictionaries and {snapshot.Count} direct resources");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"CaptureResourceSnapshot: Failed: {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Validate resources in isolation before applying them
        /// </summary>
        private bool ValidateResourcesInIsolation(ResourceDictionary themeDict)
        {
            try
            {
                LoggingService.EmergencyLog("ValidateResourcesInIsolation: Starting isolated validation");
                
                // Check essential resources
                if (!ValidateEssentialResources(themeDict))
                {
                    LoggingService.EmergencyLog("ValidateResourcesInIsolation: Essential resources validation failed");
                    return false;
                }
                
                // Validate style integrity
                if (!ValidateStyleIntegrity(themeDict))
                {
                    LoggingService.EmergencyLog("ValidateResourcesInIsolation: Style integrity validation failed");
                    return false;
                }
                
                // Test individual resource access
                if (!TestResourceAccess(themeDict))
                {
                    LoggingService.EmergencyLog("ValidateResourcesInIsolation: Resource access test failed");
                    return false;
                }
                
                LoggingService.EmergencyLog("ValidateResourcesInIsolation: All validations passed");
                return true;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ValidateResourcesInIsolation: Exception: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Test individual resource access without applying to application
        /// </summary>
        private bool TestResourceAccess(ResourceDictionary themeDict)
        {
            try
            {
                LoggingService.EmergencyLog("TestResourceAccess: Testing resource accessibility");
                
                string[] criticalKeys = { "BackgroundBrush", "TextBrush", "PrimaryBrush", "MainWindowStyle" };
                
                foreach (var key in criticalKeys)
                {
                    try
                    {
                        if (themeDict.Contains(key))
                        {
                            var resource = themeDict[key];
                            LoggingService.EmergencyLog($"TestResourceAccess: Resource '{key}' accessible, type: {resource?.GetType().Name ?? "NULL"}");
                        }
                        else
                        {
                            LoggingService.EmergencyLog($"TestResourceAccess: Resource '{key}' not found in theme");
                        }
                    }
                    catch (Exception resourceEx)
                    {
                        LoggingService.EmergencyLog($"TestResourceAccess: Failed to access resource '{key}': {resourceEx.Message}");
                        return false;
                    }
                }
                
                return true;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"TestResourceAccess: Exception: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Apply resources progressively with validation at each step
        /// </summary>
        private bool ApplyResourcesProgressively(ResourceDictionary themeDict)
        {
            try
            {
                LoggingService.EmergencyLog("ApplyResourcesProgressively: Starting progressive application");
                
                // Step 1: Apply basic brushes first
                if (!ApplyBasicBrushes(themeDict))
                {
                    LoggingService.EmergencyLog("ApplyResourcesProgressively: Basic brushes application failed");
                    return false;
                }
                
                // Step 2: Apply styles
                if (!ApplyStyles(themeDict))
                {
                    LoggingService.EmergencyLog("ApplyResourcesProgressively: Styles application failed");
                    return false;
                }
                
                // Step 3: Apply complete theme
                if (!ApplyCompleteTheme(themeDict))
                {
                    LoggingService.EmergencyLog("ApplyResourcesProgressively: Complete theme application failed");
                    return false;
                }
                
                LoggingService.EmergencyLog("ApplyResourcesProgressively: Progressive application successful");
                return true;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ApplyResourcesProgressively: Exception: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Apply basic brushes first for safety
        /// </summary>
        private bool ApplyBasicBrushes(ResourceDictionary themeDict)
        {
            try
            {
                LoggingService.EmergencyLog("ApplyBasicBrushes: Applying basic brushes");
                
                string[] brushKeys = { "BackgroundBrush", "TextBrush", "PrimaryBrush", "AccentBrush", "BorderBrush" };
                
                foreach (var key in brushKeys)
                {
                    if (themeDict.Contains(key))
                    {
                        try
                        {
                            Application.Current.Resources[key] = themeDict[key];
                            LoggingService.EmergencyLog($"ApplyBasicBrushes: Applied brush '{key}'");
                        }
                        catch (Exception brushEx)
                        {
                            LoggingService.EmergencyLog($"ApplyBasicBrushes: Failed to apply brush '{key}': {brushEx.Message}");
                            return false;
                        }
                    }
                }
                
                return true;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ApplyBasicBrushes: Exception: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Apply styles with individual validation
        /// </summary>
        private bool ApplyStyles(ResourceDictionary themeDict)
        {
            try
            {
                LoggingService.EmergencyLog("ApplyStyles: Applying individual styles");
                
                string[] styleKeys = { "MainWindowStyle", "GroupBoxStyle", "ModernButtonStyle" };
                
                foreach (var key in styleKeys)
                {
                    if (themeDict.Contains(key))
                    {
                        try
                        {
                            var style = themeDict[key];
                            if (ValidateIndividualStyle(style))
                            {
                                Application.Current.Resources[key] = style;
                                LoggingService.EmergencyLog($"ApplyStyles: Applied style '{key}'");
                            }
                            else
                            {
                                LoggingService.EmergencyLog($"ApplyStyles: Style '{key}' validation failed, skipping");
                            }
                        }
                        catch (Exception styleEx)
                        {
                            LoggingService.EmergencyLog($"ApplyStyles: Failed to apply style '{key}': {styleEx.Message}");
                            // Continue with other styles instead of failing completely
                        }
                    }
                }
                
                return true;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ApplyStyles: Exception: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Apply complete theme as final step
        /// </summary>
        private bool ApplyCompleteTheme(ResourceDictionary themeDict)
        {
            try
            {
                LoggingService.EmergencyLog("ApplyCompleteTheme: Applying complete theme");
                
                // Insert the complete theme dictionary
                Application.Current.Resources.MergedDictionaries.Insert(0, themeDict);
                
                LoggingService.EmergencyLog("ApplyCompleteTheme: Complete theme applied");
                return true;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ApplyCompleteTheme: Exception: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Rollback to captured resource snapshot
        /// </summary>
        private void RollbackToSnapshot(ResourceDictionary snapshot)
        {
            try
            {
                LoggingService.EmergencyLog("RollbackToSnapshot: Rolling back to previous state");
                
                // Clear current resources
                Application.Current.Resources.MergedDictionaries.Clear();
                Application.Current.Resources.Clear();
                
                // Restore merged dictionaries
                foreach (var dict in snapshot.MergedDictionaries)
                {
                    Application.Current.Resources.MergedDictionaries.Add(dict);
                }
                
                // Restore direct resources
                foreach (var key in snapshot.Keys)
                {
                    Application.Current.Resources[key] = snapshot[key];
                }
                
                LoggingService.EmergencyLog("RollbackToSnapshot: Rollback completed");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"RollbackToSnapshot: Rollback failed: {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Load minimal fallback theme when primary theme fails
        /// </summary>
        private void LoadMinimalFallbackTheme()
        {
            try
            {
                _loggingService?.LogInfo("Loading minimal fallback theme...");
                LoggingService.EmergencyLog("LoadMinimalFallbackTheme: Starting fallback theme creation");
                
                // Create a minimal theme with essential resources
                var fallbackDict = new ResourceDictionary();
                LoggingService.EmergencyLog("LoadMinimalFallbackTheme: ResourceDictionary created");
                
                // Add essential brushes with validation
                try
                {
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
                    LoggingService.EmergencyLog("LoadMinimalFallbackTheme: Brushes added successfully");
                }
                catch (Exception brushEx)
                {
                    LoggingService.EmergencyLog($"LoadMinimalFallbackTheme: Failed to add brushes: {brushEx.Message}");
                    throw new InvalidOperationException("Failed to create fallback theme brushes", brushEx);
                }
                
                // Add minimal window style
                try
                {
                    var windowStyle = new Style(typeof(Window));
                    windowStyle.Setters.Add(new Setter(Window.BackgroundProperty, fallbackDict["BackgroundBrush"]));
                    windowStyle.Setters.Add(new Setter(Window.ForegroundProperty, fallbackDict["TextBrush"]));
                    fallbackDict.Add("MainWindowStyle", windowStyle);
                    LoggingService.EmergencyLog("LoadMinimalFallbackTheme: Window style added successfully");
                }
                catch (Exception styleEx)
                {
                    LoggingService.EmergencyLog($"LoadMinimalFallbackTheme: Failed to add window style: {styleEx.Message}");
                    // Continue without window style if it fails
                }
                
                Application.Current.Resources.MergedDictionaries.Insert(0, fallbackDict);
                LoggingService.EmergencyLog("LoadMinimalFallbackTheme: Fallback theme applied to application");
                _loggingService?.LogInfo("Minimal fallback theme loaded");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"LoadMinimalFallbackTheme: CRITICAL FAILURE - {ex.Message}");
                _loggingService?.LogError($"Failed to load minimal fallback theme: {ex.Message}", ex);
                throw;
            }
        }
        
        /// <summary>
        /// Validate that essential resources exist in a theme dictionary
        /// </summary>
        private bool ValidateEssentialResources(ResourceDictionary themeDict)
        {
            if (themeDict == null)
            {
                LoggingService.EmergencyLog("ValidateEssentialResources: Theme dictionary is null");
                _loggingService?.LogWarning("Theme dictionary is null during validation");
                return false;
            }

            string[] essentialResources = { 
                "BackgroundBrush", "TextBrush", "PrimaryBrush", 
                "AccentBrush", "BorderBrush", "MainWindowStyle" 
            };
            
            LoggingService.EmergencyLog($"ValidateEssentialResources: Checking {essentialResources.Length} essential resources");
            
            bool allValid = true;
            foreach (var resourceKey in essentialResources)
            {
                try
                {
                    if (!themeDict.Contains(resourceKey))
                    {
                        LoggingService.EmergencyLog($"ValidateEssentialResources: Missing resource: {resourceKey}");
                        _loggingService?.LogWarning($"Theme missing essential resource: {resourceKey}");
                        allValid = false;
                    }
                    else
                    {
                        LoggingService.EmergencyLog($"ValidateEssentialResources: Found resource: {resourceKey}");
                    }
                }
                catch (Exception ex)
                {
                    LoggingService.EmergencyLog($"ValidateEssentialResources: Error checking resource {resourceKey}: {ex.Message}");
                    _loggingService?.LogError($"Error validating resource {resourceKey}: {ex.Message}", ex);
                    allValid = false;
                }
            }
            
            LoggingService.EmergencyLog($"ValidateEssentialResources: Validation result: {allValid}");
            return allValid;
        }
        
        /// <summary>
        /// Enhanced validation to check for all styles referenced by Views
        /// </summary>
        private bool ValidateAllReferencedStyles(ResourceDictionary themeDict)
        {
            if (themeDict == null)
            {
                LoggingService.EmergencyLog("ValidateAllReferencedStyles: Theme dictionary is null");
                _loggingService?.LogWarning("Theme dictionary is null during style validation");
                return false;
            }

            // All styles that are referenced with DynamicResource in Views
            string[] referencedStyles = { 
                "MainWindowStyle", "GroupBoxStyle", "FeatureTextStyle", "SciFiCheckBoxStyle",
                "DescriptionTextStyle", "ModernScrollViewerStyle", "ModernComboBoxStyle", 
                "ModernSliderStyle", "ValueTextStyle", "ModernTextBoxStyle", "ModernButtonStyle",
                "AccentButtonStyle", "ModernDataGridStyle", "OptimizationButtonStyle", 
                "PrimaryButtonStyle", "DangerButtonStyle"
            };
            
            LoggingService.EmergencyLog($"ValidateAllReferencedStyles: Checking {referencedStyles.Length} referenced styles");
            
            bool allValid = true;
            var missingStyles = new List<string>();
            
            foreach (var styleKey in referencedStyles)
            {
                try
                {
                    if (!themeDict.Contains(styleKey))
                    {
                        // Check in merged dictionaries and application resources
                        bool foundInMerged = false;
                        foreach (var mergedDict in Application.Current.Resources.MergedDictionaries)
                        {
                            if (mergedDict.Contains(styleKey))
                            {
                                foundInMerged = true;
                                LoggingService.EmergencyLog($"ValidateAllReferencedStyles: Style {styleKey} found in merged dictionary");
                                break;
                            }
                        }
                        
                        if (!foundInMerged && !Application.Current.Resources.Contains(styleKey))
                        {
                            LoggingService.EmergencyLog($"ValidateAllReferencedStyles: MISSING STYLE: {styleKey}");
                            _loggingService?.LogWarning($"Theme missing referenced style: {styleKey}");
                            missingStyles.Add(styleKey);
                            allValid = false;
                        }
                    }
                    else
                    {
                        LoggingService.EmergencyLog($"ValidateAllReferencedStyles: Found style: {styleKey}");
                    }
                }
                catch (Exception ex)
                {
                    LoggingService.EmergencyLog($"ValidateAllReferencedStyles: Error checking style {styleKey}: {ex.Message}");
                    _loggingService?.LogError($"Error validating style {styleKey}: {ex.Message}", ex);
                    allValid = false;
                }
            }
            
            if (missingStyles.Count > 0)
            {
                LoggingService.EmergencyLog($"ValidateAllReferencedStyles: CRITICAL - Missing {missingStyles.Count} styles: {string.Join(", ", missingStyles)}");
                _loggingService?.LogError($"Theme validation failed - Missing styles: {string.Join(", ", missingStyles)}");
            }
            
            LoggingService.EmergencyLog($"ValidateAllReferencedStyles: Validation completed - All valid: {allValid}");
            return allValid;
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
        
        /// <summary>
        /// Test error handling mechanisms - can be called for validation
        /// </summary>
        public static void TestErrorHandling()
        {
            LoggingService.EmergencyLog("TestErrorHandling: Starting error handling tests");
            
            try
            {
                // Test 1: Emergency logging
                LoggingService.EmergencyLog("TestErrorHandling: Test 1 - Emergency logging works");
                
                // Test 2: Service instance creation
                try
                {
                    var testLogging = LoggingService.Instance;
                    testLogging?.LogInfo("TestErrorHandling: Test 2 - LoggingService instance creation works");
                }
                catch (Exception ex)
                {
                    LoggingService.EmergencyLog($"TestErrorHandling: Test 2 FAILED - LoggingService: {ex.Message}");
                }
                
                // Test 3: Other service instances
                try
                {
                    var testAdmin = AdminService.Instance;
                    LoggingService.EmergencyLog("TestErrorHandling: Test 3 - AdminService instance creation works");
                }
                catch (Exception ex)
                {
                    LoggingService.EmergencyLog($"TestErrorHandling: Test 3 FAILED - AdminService: {ex.Message}");
                }
                
                LoggingService.EmergencyLog("TestErrorHandling: All tests completed");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"TestErrorHandling: CRITICAL - Test framework failed: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Create an ultra-minimal emergency window with zero styling dependencies
        /// </summary>
        private void CreateEmergencyWindow()
        {
            try
            {
                LoggingService.EmergencyLog("CreateEmergencyWindow: Starting emergency window creation");
                
                // Create the specialized emergency main window
                var emergencyWindow = new Views.EmergencyMainWindow();
                
                LoggingService.EmergencyLog("CreateEmergencyWindow: Emergency window created successfully");
                
                // Show the window
                emergencyWindow.Show();
                
                LoggingService.EmergencyLog("CreateEmergencyWindow: Emergency window displayed");
                
                // Make this the main window
                this.MainWindow = emergencyWindow;
                
                LoggingService.EmergencyLog("CreateEmergencyWindow: Emergency mode initialization complete");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"CreateEmergencyWindow: CRITICAL FAILURE - {ex.Message}");
                LoggingService.EmergencyLog($"CreateEmergencyWindow: Exception details - {ex}");
                
                // If even the specialized emergency window fails, fall back to ultra-basic window
                try
                {
                    LoggingService.EmergencyLog("CreateEmergencyWindow: Attempting ultra-basic fallback window");
                    
                    var fallbackWindow = new Window
                    {
                        Title = "KOALA Gaming Optimizer - Critical Emergency Mode",
                        Width = 600,
                        Height = 400,
                        WindowStartupLocation = WindowStartupLocation.CenterScreen,
                        Background = System.Windows.Media.Brushes.DarkRed,
                        Foreground = System.Windows.Media.Brushes.White,
                        Content = new StackPanel
                        {
                            Margin = new Thickness(20),
                            Children =
                            {
                                new TextBlock
                                {
                                    Text = "🐨 KOALA Gaming Optimizer - Critical Emergency Mode",
                                    FontSize = 16,
                                    FontWeight = FontWeights.Bold,
                                    Margin = new Thickness(0, 0, 0, 20),
                                    TextWrapping = TextWrapping.Wrap
                                },
                                new TextBlock
                                {
                                    Text = $"Critical startup failure. Even emergency mode failed.\n\nError: {ex.Message}\n\nThe application cannot start properly.",
                                    Margin = new Thickness(0, 0, 0, 20),
                                    TextWrapping = TextWrapping.Wrap
                                },
                                new Button
                                {
                                    Content = "Exit Application",
                                    Width = 150,
                                    Height = 30,
                                    Background = System.Windows.Media.Brushes.Black,
                                    Foreground = System.Windows.Media.Brushes.White
                                }
                            }
                        }
                    };
                    
                    // Add close handler
                    if (fallbackWindow.Content is StackPanel panel && 
                        panel.Children[panel.Children.Count - 1] is Button exitButton)
                    {
                        exitButton.Click += (s, e) => Application.Current.Shutdown();
                    }
                    
                    fallbackWindow.Show();
                    this.MainWindow = fallbackWindow;
                    
                    LoggingService.EmergencyLog("CreateEmergencyWindow: Ultra-basic fallback window created");
                }
                catch (Exception fallbackEx)
                {
                    LoggingService.EmergencyLog($"CreateEmergencyWindow: Even ultra-basic fallback failed: {fallbackEx.Message}");
                    
                    // If even the fallback window fails, show a basic message box and exit
                    try
                    {
                        MessageBox.Show(
                            $"Critical startup failure. All emergency modes failed.\n\n" +
                            $"Primary Error: {ex.Message}\n" +
                            $"Fallback Error: {fallbackEx.Message}\n\n" +
                            $"The application cannot start. Please check the emergency log in your temp folder.",
                            "KOALA Gaming Optimizer - Critical Failure",
                            MessageBoxButton.OK,
                            MessageBoxImage.Error);
                    }
                    catch
                    {
                        // If even MessageBox fails, just exit
                        LoggingService.EmergencyLog("CreateEmergencyWindow: MessageBox also failed - force exit");
                    }
                    
                    Environment.Exit(1);
                }
            }
        }
        
        /// <summary>
        /// Capture comprehensive diagnostic snapshot for debugging
        /// </summary>
        private void CaptureDiagnosticSnapshot(string phase)
        {
            try
            {
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Starting diagnostic capture");
                
                // Application state
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Application.Current = {(Application.Current != null ? "Available" : "NULL")}");
                
                if (Application.Current != null)
                {
                    LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Application.Current.Resources = {(Application.Current.Resources != null ? "Available" : "NULL")}");
                    
                    if (Application.Current.Resources != null)
                    {
                        LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: MergedDictionaries.Count = {Application.Current.Resources.MergedDictionaries.Count}");
                        LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Direct Resources.Count = {Application.Current.Resources.Count}");
                        
                        // Log current merged dictionaries
                        for (int i = 0; i < Application.Current.Resources.MergedDictionaries.Count; i++)
                        {
                            var dict = Application.Current.Resources.MergedDictionaries[i];
                            var source = dict.Source?.ToString() ?? "No Source";
                            LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: MergedDict[{i}] = {source} (Count: {dict.Count})");
                        }
                        
                        // Check for critical resources
                        string[] criticalResources = { "BackgroundBrush", "TextBrush", "PrimaryBrush", "MainWindowStyle" };
                        foreach (var resource in criticalResources)
                        {
                            bool exists = Application.Current.Resources.Contains(resource);
                            LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Resource '{resource}' = {(exists ? "FOUND" : "MISSING")}");
                            
                            if (exists)
                            {
                                var resourceValue = Application.Current.Resources[resource];
                                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Resource '{resource}' type = {resourceValue?.GetType().Name ?? "NULL"}");
                            }
                        }
                    }
                    
                    LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: MainWindow = {(Application.Current.MainWindow != null ? "Available" : "NULL")}");
                    LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Windows.Count = {Application.Current.Windows.Count}");
                }
                
                // System state
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Current Thread = {System.Threading.Thread.CurrentThread.ManagedThreadId}");
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Is UI Thread = {Application.Current?.Dispatcher.CheckAccess() ?? false}");
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Culture = {System.Globalization.CultureInfo.CurrentCulture.Name}");
                
                // Assembly state
                var assembly = Assembly.GetExecutingAssembly();
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Assembly Location = {assembly.Location}");
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Assembly Version = {assembly.GetName().Version}");
                
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: Diagnostic capture complete");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"DIAGNOSTIC_SNAPSHOT[{phase}]: FAILED - {ex.Message}");
            }
        }
        
        /// <summary>
        /// Validate style integrity to ensure styles don't have circular dependencies or invalid references
        /// </summary>
        private bool ValidateStyleIntegrity(ResourceDictionary themeDict)
        {
            try
            {
                LoggingService.EmergencyLog("ValidateStyleIntegrity: Starting style integrity validation");
                
                foreach (var key in themeDict.Keys)
                {
                    var resource = themeDict[key];
                    
                    if (resource is Style style)
                    {
                        try
                        {
                            // Test style properties
                            var targetType = style.TargetType;
                            var setters = style.Setters;
                            
                            LoggingService.EmergencyLog($"ValidateStyleIntegrity: Style '{key}' - TargetType: {targetType?.Name}, Setters: {setters?.Count}");
                            
                            // Check for null or invalid setters
                            if (setters != null)
                            {
                                foreach (var setter in setters)
                                {
                                    if (setter is Setter styleSetter)
                                    {
                                        // Validate setter properties
                                        var property = styleSetter.Property;
                                        var value = styleSetter.Value;
                                        
                                        if (property == null)
                                        {
                                            LoggingService.EmergencyLog($"ValidateStyleIntegrity: Style '{key}' has setter with null property");
                                            return false;
                                        }
                                        
                                        // Check for resource references
                                        if (value is DynamicResourceExtension dynamicRef)
                                        {
                                            LoggingService.EmergencyLog($"ValidateStyleIntegrity: Style '{key}' references dynamic resource: {dynamicRef.ResourceKey}");
                                        }
                                        else if (value is StaticResourceExtension staticRef)
                                        {
                                            LoggingService.EmergencyLog($"ValidateStyleIntegrity: Style '{key}' references static resource: {staticRef.ResourceKey}");
                                        }
                                    }
                                }
                            }
                        }
                        catch (Exception styleEx)
                        {
                            LoggingService.EmergencyLog($"ValidateStyleIntegrity: Error validating style '{key}': {styleEx.Message}");
                            // Continue validation but note the error
                        }
                    }
                }
                
                LoggingService.EmergencyLog("ValidateStyleIntegrity: Style integrity validation completed");
                return true;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ValidateStyleIntegrity: Exception: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Validate individual style before application
        /// </summary>
        private bool ValidateIndividualStyle(object style)
        {
            try
            {
                if (style is Style wpfStyle)
                {
                    // Basic validation - ensure style has target type and isn't corrupted
                    var targetType = wpfStyle.TargetType;
                    if (targetType == null)
                    {
                        LoggingService.EmergencyLog("ValidateIndividualStyle: Style has null TargetType");
                        return false;
                    }
                    
                    LoggingService.EmergencyLog($"ValidateIndividualStyle: Style validated for type {targetType.Name}");
                    return true;
                }
                else if (style != null)
                {
                    LoggingService.EmergencyLog($"ValidateIndividualStyle: Resource is not a Style, type: {style.GetType().Name}");
                    return true; // Non-style resources are OK
                }
                else
                {
                    LoggingService.EmergencyLog("ValidateIndividualStyle: Style is null");
                    return false;
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ValidateIndividualStyle: Exception: {ex.Message}");
                return false;
            }
        }
    }
}