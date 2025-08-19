using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using KOALAOptimizer.Testing.Services;

namespace KOALAOptimizer.Testing.Views
{
    /// <summary>
    /// Minimal safe window with zero theme dependencies
    /// NUCLEAR APPROACH: Hardcoded styling to prevent FrameworkElement.Style errors
    /// </summary>
    public partial class MinimalMainWindow : Window
    {
        private ILoggingService _loggingService;
        private OptimizationService _optimizationService;
        private SystemService _systemService;

        public MinimalMainWindow()
        {
            try
            {
                LoggingService.EmergencyLog("MinimalMainWindow: Initializing...");
                InitializeComponent();
                LoggingService.EmergencyLog("MinimalMainWindow: InitializeComponent completed");
                
                InitializeServices();
                LoadSystemInformation();
                
                LoggingService.EmergencyLog("MinimalMainWindow: Initialization complete");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: Initialization error: {ex.Message}");
                // Don't crash - show basic functionality
            }
        }

        private void InitializeServices()
        {
            try
            {
                _loggingService = LoggingService.Instance;
                _optimizationService = OptimizationService.Instance;
                _systemService = SystemService.Instance;
                
                LoggingService.EmergencyLog("MinimalMainWindow: Services initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: Service initialization error: {ex.Message}");
                // Continue without services if needed
            }
        }

        private async void LoadSystemInformation()
        {
            try
            {
                if (_systemService != null)
                {
                    var systemInfo = await _systemService.GetSystemInfoAsync();
                    SystemInfoTextBlock.Text = systemInfo;
                }
                else
                {
                    SystemInfoTextBlock.Text = "System service unavailable - running in minimal mode";
                }
            }
            catch (Exception ex)
            {
                SystemInfoTextBlock.Text = $"Error loading system info: {ex.Message}";
                LoggingService.EmergencyLog($"MinimalMainWindow: LoadSystemInformation error: {ex.Message}");
            }
        }

        private async void RecommendedButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (_optimizationService == null)
                {
                    MessageBox.Show("Optimization service not available", "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }

                RecommendedButton.Content = "🔄 Applying...";
                RecommendedButton.IsEnabled = false;

                // Apply the checked optimizations
                var selectedOptimizations = GetSelectedOptimizations();
                bool success = await _optimizationService.ApplyOptimizationsAsync(selectedOptimizations);

                if (success)
                {
                    MessageBox.Show("Recommended optimizations applied successfully!", 
                                  "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                    _loggingService?.LogInfo("Recommended optimizations applied successfully from minimal window");
                }
                else
                {
                    MessageBox.Show("Some optimizations failed. Check the log for details.", 
                                  "Warning", MessageBoxButton.OK, MessageBoxImage.Warning);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error applying optimizations: {ex.Message}", 
                              "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                LoggingService.EmergencyLog($"MinimalMainWindow: RecommendedButton_Click error: {ex.Message}");
            }
            finally
            {
                RecommendedButton.Content = "🚀 Apply Recommended";
                RecommendedButton.IsEnabled = true;
            }
        }

        private string[] GetSelectedOptimizations()
        {
            var optimizations = new System.Collections.Generic.List<string>();

            if (chkDisableNagle.IsChecked == true) optimizations.Add("DisableNagle");
            if (chkSystemResponsiveness.IsChecked == true) optimizations.Add("SystemResponsiveness");
            if (chkDisableGameDVR.IsChecked == true) optimizations.Add("DisableGameDVR");
            if (chkEnableGpuScheduling.IsChecked == true) optimizations.Add("EnableGpuScheduling");
            if (chkHighPrecisionTimer.IsChecked == true) optimizations.Add("HighPrecisionTimer");
            if (chkCpuCorePark.IsChecked == true) optimizations.Add("CpuCorePark");
            if (chkMMCSS.IsChecked == true) optimizations.Add("MMCSS");
            if (chkGamesTaskHighPriority.IsChecked == true) optimizations.Add("GamesTaskHighPriority");
            if (chkNetworkLatency.IsChecked == true) optimizations.Add("NetworkLatency");
            if (chkGameMode.IsChecked == true) optimizations.Add("GameMode");
            if (chkProcessOptimization.IsChecked == true) optimizations.Add("ProcessOptimization");
            if (chkDisableNetworkThrottling.IsChecked == true) optimizations.Add("DisableNetworkThrottling");

            return optimizations.ToArray();
        }

        private async void RevertAllButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var result = MessageBox.Show("Are you sure you want to revert all optimizations?", 
                                           "Confirm Revert", MessageBoxButton.YesNo, MessageBoxImage.Question);
                
                if (result == MessageBoxResult.Yes)
                {
                    if (_optimizationService != null)
                    {
                        RevertAllButton.Content = "🔄 Reverting...";
                        RevertAllButton.IsEnabled = false;

                        bool success = await _optimizationService.RevertAllOptimizationsAsync();
                        
                        if (success)
                        {
                            MessageBox.Show("All optimizations reverted successfully!", 
                                          "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                        }
                        else
                        {
                            MessageBox.Show("Some optimizations could not be reverted. Check the log for details.", 
                                          "Warning", MessageBoxButton.OK, MessageBoxImage.Warning);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error reverting optimizations: {ex.Message}", 
                              "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                LoggingService.EmergencyLog($"MinimalMainWindow: RevertAllButton_Click error: {ex.Message}");
            }
            finally
            {
                RevertAllButton.Content = "🔄 Revert All";
                RevertAllButton.IsEnabled = true;
            }
        }

        private void SystemInfoButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Switch to System Info tab
                var tabControl = FindName("MinimalTabControl") as TabControl;
                if (tabControl != null && tabControl.Items.Count > 1)
                {
                    tabControl.SelectedIndex = 1;
                }
                
                // Refresh system information
                LoadSystemInformation();
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: SystemInfoButton_Click error: {ex.Message}");
            }
        }

        private async void LoadThemesButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var result = MessageBox.Show(
                    "This will attempt to load themes which may cause FrameworkElement.Style errors.\n\n" +
                    "Only proceed if you're sure your system can handle theme loading.\n\n" +
                    "Do you want to continue?", 
                    "⚠️ Warning - Theme Loading", 
                    MessageBoxButton.YesNo, 
                    MessageBoxImage.Warning);
                
                if (result == MessageBoxResult.Yes)
                {
                    LoadThemesButton.Content = "🔄 Loading...";
                    LoadThemesButton.IsEnabled = false;

                    try
                    {
                        // Attempt to restart with theme loading
                        LoggingService.EmergencyLog("MinimalMainWindow: User requested theme loading - restarting with --normal flag");
                        
                        System.Diagnostics.Process.Start(
                            System.Reflection.Assembly.GetExecutingAssembly().Location, 
                            "--normal");
                        
                        Application.Current.Shutdown();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Failed to restart with theme loading: {ex.Message}", 
                                      "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                        LoggingService.EmergencyLog($"MinimalMainWindow: LoadThemesButton restart error: {ex.Message}");
                    }
                    finally
                    {
                        LoadThemesButton.Content = "🎨 Load Themes (Advanced)";
                        LoadThemesButton.IsEnabled = true;
                    }
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: LoadThemesButton_Click error: {ex.Message}");
            }
        }
    }
}