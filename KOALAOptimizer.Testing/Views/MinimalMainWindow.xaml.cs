using System;
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
        // NUCLEAR APPROACH: No service dependencies - completely self-contained

        public MinimalMainWindow()
        {
            try
            {
                LoggingService.EmergencyLog("MinimalMainWindow: Initializing...");
                InitializeComponent();
                LoggingService.EmergencyLog("MinimalMainWindow: InitializeComponent completed");
                
                LoadSystemInformation();
                
                LoggingService.EmergencyLog("MinimalMainWindow: Initialization complete");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: Initialization error: {ex.Message}");
                // Don't crash - show basic functionality
            }
        }

        private void LoadSystemInformation()
        {
            try
            {
                // NUCLEAR APPROACH: Basic system info without external services
                var systemInfo = $"System: {Environment.OSVersion}\n" +
                               $"CLR Version: {Environment.Version}\n" +
                               $"Machine: {Environment.MachineName}\n" +
                               $"User: {Environment.UserName}\n" +
                               $"64-bit OS: {Environment.Is64BitOperatingSystem}\n" +
                               $"64-bit Process: {Environment.Is64BitProcess}\n" +
                               $"Processor Count: {Environment.ProcessorCount}\n" +
                               $"Working Set: {Environment.WorkingSet / 1024 / 1024} MB\n" +
                               "\n=== NUCLEAR MODE ACTIVE ===\n" +
                               "Full system information requires normal mode.\n" +
                               "This is a safe minimal display.";
                
                SystemInfoTextBlock.Text = systemInfo;
            }
            catch (Exception ex)
            {
                SystemInfoTextBlock.Text = $"Error loading system info: {ex.Message}\n\nNUCLEAR MODE: Basic error display";
                LoggingService.EmergencyLog($"MinimalMainWindow: LoadSystemInformation error: {ex.Message}");
            }
        }

        private void RecommendedButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // NUCLEAR APPROACH: Simple user feedback without external services
                RecommendedButton.Content = "🔄 Processing...";
                RecommendedButton.IsEnabled = false;

                // Show the user what would be optimized
                var selectedOptimizations = GetSelectedOptimizations();
                
                if (selectedOptimizations.Length == 0)
                {
                    MessageBox.Show("Please select at least one optimization to apply.", 
                                  "No Optimizations Selected", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                else
                {
                    var optimizationList = string.Join("\n• ", selectedOptimizations);
                    var result = MessageBox.Show(
                        $"🚨 NUCLEAR MODE: Selected optimizations:\n\n• {optimizationList}\n\n" +
                        "⚠️ Note: Full optimization functionality requires normal mode.\n" +
                        "This is a safe preview of selected optimizations.\n\n" +
                        "Restart with '--normal' flag for full functionality?", 
                        "Nuclear Mode - Optimization Preview", 
                        MessageBoxButton.YesNo, 
                        MessageBoxImage.Information);

                    if (result == MessageBoxResult.Yes)
                    {
                        try
                        {
                            System.Diagnostics.Process.Start(
                                System.Reflection.Assembly.GetExecutingAssembly().Location, 
                                "--normal");
                            Application.Current.Shutdown();
                        }
                        catch (Exception ex)
                        {
                            MessageBox.Show($"Failed to restart in normal mode: {ex.Message}", 
                                          "Restart Failed", MessageBoxButton.OK, MessageBoxImage.Warning);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error in optimization preview: {ex.Message}", 
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

        private void RevertAllButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // NUCLEAR APPROACH: Simple revert functionality without external services
                var result = MessageBox.Show(
                    "🚨 NUCLEAR MODE: Revert Functionality\n\n" +
                    "⚠️ Full revert functionality requires normal mode.\n" +
                    "This mode provides safe basic operation only.\n\n" +
                    "Would you like to restart in normal mode for full revert capabilities?", 
                    "Nuclear Mode - Revert Preview", 
                    MessageBoxButton.YesNo, 
                    MessageBoxImage.Question);
                
                if (result == MessageBoxResult.Yes)
                {
                    try
                    {
                        RevertAllButton.Content = "🔄 Restarting...";
                        RevertAllButton.IsEnabled = false;
                        
                        System.Diagnostics.Process.Start(
                            System.Reflection.Assembly.GetExecutingAssembly().Location, 
                            "--normal");
                        Application.Current.Shutdown();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Failed to restart in normal mode: {ex.Message}", 
                                      "Restart Failed", MessageBoxButton.OK, MessageBoxImage.Warning);
                        RevertAllButton.Content = "🔄 Revert All";
                        RevertAllButton.IsEnabled = true;
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error in revert preview: {ex.Message}", 
                              "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                LoggingService.EmergencyLog($"MinimalMainWindow: RevertAllButton_Click error: {ex.Message}");
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

        private void LoadThemesButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var result = MessageBox.Show(
                    "This will attempt to load themes safely without restarting the application.\n\n" +
                    "If theme loading fails, the application will remain in safe mode.\n\n" +
                    "Do you want to continue?", 
                    "🎨 Load Themes", 
                    MessageBoxButton.YesNo, 
                    MessageBoxImage.Question);
                
                if (result == MessageBoxResult.Yes)
                {
                    LoadThemesButton.Content = "🔄 Loading...";
                    LoadThemesButton.IsEnabled = false;

                    try
                    {
                        LoggingService.EmergencyLog("MinimalMainWindow: User requested safe theme loading");
                        
                        // Try to load SciFi theme using the existing robust infrastructure
                        bool themeLoaded = false;
                        
                        try
                        {
                            LoggingService.EmergencyLog("MinimalMainWindow: Attempting SciFi theme load");
                            themeLoaded = App.LoadThemeSystematically("pack://application:,,,/Themes/SciFiTheme.xaml");
                        }
                        catch (Exception themeEx)
                        {
                            LoggingService.EmergencyLog($"MinimalMainWindow: SciFi theme load failed: {themeEx.Message}");
                        }
                        
                        if (!themeLoaded)
                        {
                            LoggingService.EmergencyLog("MinimalMainWindow: SciFi theme failed, trying fallback");
                            try
                            {
                                themeLoaded = App.LoadMinimalFallbackTheme();
                            }
                            catch (Exception fallbackEx)
                            {
                                LoggingService.EmergencyLog($"MinimalMainWindow: Fallback theme failed: {fallbackEx.Message}");
                            }
                        }
                        
                        if (themeLoaded)
                        {
                            LoggingService.EmergencyLog("MinimalMainWindow: Theme loaded successfully - switching to main window");
                            
                            // Create and show the main window with themes
                            var mainWindow = new MainWindow();
                            mainWindow.Show();
                            
                            // Close the minimal window
                            this.Close();
                        }
                        else
                        {
                            MessageBox.Show("Theme loading failed, but the application remains stable.\n\n" +
                                          "Continuing in safe mode.", 
                                          "Theme Loading Failed", 
                                          MessageBoxButton.OK, MessageBoxImage.Information);
                            LoggingService.EmergencyLog("MinimalMainWindow: Theme loading failed, staying in safe mode");
                        }
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"An error occurred during theme loading: {ex.Message}\n\n" +
                                      "The application remains stable in safe mode.", 
                                      "Theme Loading Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                        LoggingService.EmergencyLog($"MinimalMainWindow: LoadThemesButton error: {ex.Message}");
                    }
                    finally
                    {
                        LoadThemesButton.Content = "🎨 Load Themes";
                        LoadThemesButton.IsEnabled = true;
                    }
                }
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: LoadThemesButton_Click error: {ex.Message}");
            }
        }

        private void EnableCrosshairMinimal_Checked(object sender, RoutedEventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("MinimalMainWindow: Crosshair enabled");
                
                // Use the existing CrosshairOverlayService
                var crosshairService = CrosshairOverlayService.Instance;
                crosshairService?.SetEnabled(true);
                
                LoggingService.EmergencyLog("MinimalMainWindow: Crosshair service enabled");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: EnableCrosshairMinimal_Checked error: {ex.Message}");
                
                // Uncheck the checkbox if enabling failed
                if (sender is CheckBox checkbox)
                {
                    checkbox.IsChecked = false;
                }
            }
        }

        private void EnableCrosshairMinimal_Unchecked(object sender, RoutedEventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("MinimalMainWindow: Crosshair disabled");
                
                // Use the existing CrosshairOverlayService
                var crosshairService = CrosshairOverlayService.Instance;
                crosshairService?.SetEnabled(false);
                
                LoggingService.EmergencyLog("MinimalMainWindow: Crosshair service disabled");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: EnableCrosshairMinimal_Unchecked error: {ex.Message}");
            }
        }

        private void TestCrosshairMinimal_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                LoggingService.EmergencyLog("MinimalMainWindow: Test crosshair clicked");
                
                // Use the existing CrosshairOverlayService
                var crosshairService = CrosshairOverlayService.Instance;
                
                // Toggle crosshair to show/test it
                crosshairService?.ToggleOverlay();
                
                // Show a helpful message
                MessageBox.Show("Crosshair toggled!\n\nIf you don't see the crosshair, check that the overlay is enabled.\nPress F1 to toggle crosshair on/off anytime.", 
                               "Crosshair Test", MessageBoxButton.OK, MessageBoxImage.Information);
                
                LoggingService.EmergencyLog("MinimalMainWindow: Test crosshair toggled");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"MinimalMainWindow: TestCrosshairMinimal_Click error: {ex.Message}");
                MessageBox.Show($"Test crosshair failed: {ex.Message}", "Crosshair Test Error", 
                               MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }
    }
}