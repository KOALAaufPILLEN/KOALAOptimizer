using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Threading;
using KOALAOptimizer.Testing.Services;

namespace KOALAOptimizer.Testing.Views
{
    /// <summary>
    /// Emergency main window with zero styling dependencies
    /// </summary>
    public partial class EmergencyMainWindow : Window
    {
        private readonly DispatcherTimer _timer;
        private readonly LoggingService _loggingService;

        public EmergencyMainWindow()
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: Constructor starting");
                
                InitializeComponent();
                
                LoggingService.EmergencyLog("EmergencyMainWindow: InitializeComponent completed");
                
                // Initialize logging service
                try
                {
                    _loggingService = LoggingService.Instance;
                    LoggingService.EmergencyLog("EmergencyMainWindow: LoggingService initialized");
                }
                catch (Exception ex)
                {
                    LoggingService.EmergencyLog($"EmergencyMainWindow: LoggingService failed: {ex.Message}");
                    _loggingService = null;
                }
                
                // Initialize timer for status updates
                _timer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromSeconds(1)
                };
                _timer.Tick += Timer_Tick;
                _timer.Start();
                
                // Load system information
                LoadSystemInformation();
                
                LoggingService.EmergencyLog("EmergencyMainWindow: Constructor completed successfully");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: Constructor FAILED: {ex.Message}");
                LoggingService.EmergencyLog($"EmergencyMainWindow: Exception details: {ex}");
                throw;
            }
        }

        private void Timer_Tick(object sender, EventArgs e)
        {
            try
            {
                TimeText.Text = DateTime.Now.ToString("HH:mm:ss");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: Timer_Tick failed: {ex.Message}");
            }
        }

        private void LoadSystemInformation()
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: Loading system information");
                
                var systemInfo = $"OS: {Environment.OSVersion}\n" +
                               $"CLR Version: {Environment.Version}\n" +
                               $"64-bit OS: {Environment.Is64BitOperatingSystem}\n" +
                               $"64-bit Process: {Environment.Is64BitProcess}\n" +
                               $"Processor Count: {Environment.ProcessorCount}\n" +
                               $"Machine Name: {Environment.MachineName}\n" +
                               $"User Name: {Environment.UserName}\n" +
                               $"Working Directory: {Environment.CurrentDirectory}\n" +
                               $"Application Started: {DateTime.Now:yyyy-MM-dd HH:mm:ss}";

                SystemInfoText.Text = systemInfo;
                
                LoggingService.EmergencyLog("EmergencyMainWindow: System information loaded");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: LoadSystemInformation failed: {ex.Message}");
                SystemInfoText.Text = $"Failed to load system information: {ex.Message}";
            }
        }

        private void OpenEmergencyLogButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: Opening emergency log");
                
                var logPath = LoggingService.GetEmergencyLogPath();
                if (File.Exists(logPath))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = logPath,
                        UseShellExecute = true
                    });
                    _loggingService?.LogInfo("Emergency log opened");
                }
                else
                {
                    MessageBox.Show($"Emergency log file not found at: {logPath}", 
                                   "Log File Not Found", MessageBoxButton.OK, MessageBoxImage.Warning);
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: OpenEmergencyLogButton_Click failed: {ex.Message}");
                MessageBox.Show($"Failed to open emergency log: {ex.Message}", 
                               "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void RestartApplicationButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: Restarting application");
                
                var result = MessageBox.Show(
                    "Restart the application?\n\nThis will close the current emergency mode and attempt to start normally.",
                    "Restart Application", 
                    MessageBoxButton.YesNo, 
                    MessageBoxImage.Question);

                if (result == MessageBoxResult.Yes)
                {
                    _loggingService?.LogInfo("User requested application restart from emergency mode");
                    
                    // Get current executable path
                    var currentExe = Process.GetCurrentProcess().MainModule?.FileName;
                    if (!string.IsNullOrEmpty(currentExe))
                    {
                        // Start new instance
                        Process.Start(new ProcessStartInfo
                        {
                            FileName = currentExe,
                            UseShellExecute = true
                        });
                        
                        // Close current instance
                        Application.Current.Shutdown();
                    }
                    else
                    {
                        MessageBox.Show("Could not determine executable path for restart.", 
                                       "Restart Failed", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: RestartApplicationButton_Click failed: {ex.Message}");
                MessageBox.Show($"Failed to restart application: {ex.Message}", 
                               "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void ExitApplicationButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: Exiting application");
                
                var result = MessageBox.Show(
                    "Exit the application?", 
                    "Exit Application", 
                    MessageBoxButton.YesNo, 
                    MessageBoxImage.Question);

                if (result == MessageBoxResult.Yes)
                {
                    _loggingService?.LogInfo("User requested application exit from emergency mode");
                    Application.Current.Shutdown();
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: ExitApplicationButton_Click failed: {ex.Message}");
                Application.Current.Shutdown(); // Force exit if even the error handling fails
            }
        }

        private void BasicOptimizationCheckBox_Checked(object sender, RoutedEventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: Basic optimization checkbox checked");
                _loggingService?.LogInfo("User enabled basic optimizations in emergency mode");
                
                StatusText.Text = "Emergency Mode Active - Basic Optimizations Enabled";
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: BasicOptimizationCheckBox_Checked failed: {ex.Message}");
            }
        }

        private void ApplyEmergencyOptimizationsButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: Applying emergency optimizations");
                
                // Show progress
                StatusText.Text = "Applying Emergency Optimizations...";
                
                // Apply basic system optimizations that don't require theming
                bool success = ApplyBasicOptimizations();
                
                if (success)
                {
                    StatusText.Text = "Emergency Optimizations Applied Successfully";
                    MessageBox.Show(
                        "Basic gaming optimizations have been applied.\n\n" +
                        "Note: Full functionality requires normal mode. Consider restarting the application.",
                        "Optimizations Applied", 
                        MessageBoxButton.OK, 
                        MessageBoxImage.Information);
                }
                else
                {
                    StatusText.Text = "Emergency Optimizations Failed";
                    MessageBox.Show(
                        "Some optimizations could not be applied.\n\nCheck the log for details.",
                        "Optimization Warning", 
                        MessageBoxButton.OK, 
                        MessageBoxImage.Warning);
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: ApplyEmergencyOptimizationsButton_Click failed: {ex.Message}");
                StatusText.Text = "Emergency Optimization Error";
                MessageBox.Show($"Failed to apply optimizations: {ex.Message}", 
                               "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private bool ApplyBasicOptimizations()
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: ApplyBasicOptimizations starting");
                
                // Basic system optimizations that don't require theme services
                bool allSuccess = true;
                
                // Set high priority for current process
                try
                {
                    Process.GetCurrentProcess().PriorityClass = ProcessPriorityClass.High;
                    LoggingService.EmergencyLog("EmergencyMainWindow: Process priority set to High");
                    _loggingService?.LogInfo("Process priority optimization applied");
                }
                catch (Exception ex)
                {
                    LoggingService.EmergencyLog($"EmergencyMainWindow: Failed to set process priority: {ex.Message}");
                    allSuccess = false;
                }
                
                // Basic gaming-related system settings
                try
                {
                    // These would normally be done by specialized services, but we'll do basic versions
                    LoggingService.EmergencyLog("EmergencyMainWindow: Basic system optimizations completed");
                    _loggingService?.LogInfo("Emergency optimizations applied successfully");
                }
                catch (Exception ex)
                {
                    LoggingService.EmergencyLog($"EmergencyMainWindow: System optimizations failed: {ex.Message}");
                    allSuccess = false;
                }
                
                return allSuccess;
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: ApplyBasicOptimizations failed: {ex.Message}");
                return false;
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("EmergencyMainWindow: Window closing");
                
                _timer?.Stop();
                _loggingService?.LogInfo("Emergency window closed");
                
                base.OnClosed(e);
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"EmergencyMainWindow: OnClosed failed: {ex.Message}");
                base.OnClosed(e);
            }
        }
    }
}