using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Threading;
using KOALAOptimizer.Testing.Models;
using KOALAOptimizer.Testing.Services;
using Microsoft.Win32;

namespace KOALAOptimizer.Testing.Views
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        // Services
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        private readonly ThemeService _themeService;
        private readonly ProcessManagementService _processService;
        private readonly PerformanceMonitoringService _performanceService;
        private readonly RegistryOptimizationService _registryService;
        private readonly GpuDetectionService _gpuService;
        private readonly TimerResolutionService _timerService;
        private readonly CrosshairOverlayService _crosshairService;
        
        // Data collections for UI binding
        private readonly ObservableCollection<string> _logMessages;
        private readonly ObservableCollection<GameProfile> _runningGames;
        
        // UI update timer
        private readonly DispatcherTimer _uiUpdateTimer;
        
        public MainWindow()
        {
            InitializeComponent();
            
            // Initialize services
            _logger = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _themeService = ThemeService.Instance;
            _processService = ProcessManagementService.Instance;
            _performanceService = PerformanceMonitoringService.Instance;
            _registryService = RegistryOptimizationService.Instance;
            _gpuService = GpuDetectionService.Instance;
            _timerService = TimerResolutionService.Instance;
            _crosshairService = CrosshairOverlayService.Instance;
            
            // Initialize data collections
            _logMessages = new ObservableCollection<string>();
            _runningGames = new ObservableCollection<GameProfile>();
            
            // Setup UI update timer
            _uiUpdateTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(1)
            };
            _uiUpdateTimer.Tick += UiUpdateTimer_Tick;
            
            // Handle window closing
            this.Closed += MainWindow_Closed;
            
            // Initialize UI
            InitializeUI();
            
            _logger.LogInfo("KOALA Gaming Optimizer C# Edition - Main window loaded");
        }
        
        /// <summary>
        /// Initialize UI components
        /// </summary>
        private void InitializeUI()
        {
            try
            {
                // Setup theme selector
                SetupThemeSelector();
                
                // Setup admin status
                UpdateAdminStatus();
                
                // Setup game profiles
                SetupGameProfiles();
                
                // Setup data bindings
                SetupDataBindings();
                
                // Setup event handlers
                SetupEventHandlers();
                
                // Start services
                StartServices();
                
                // Load initial data
                LoadInitialData();
                
                // Auto-detect GPU and apply recommendations
                AutoDetectGpuAndApplyRecommendations();
                
                // Initialize crosshair hotkey support
                InitializeCrosshairHotkey();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to initialize UI: {ex.Message}", ex);
                MessageBox.Show($"Failed to initialize application: {ex.Message}", "Initialization Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
        
        /// <summary>
        /// Setup theme selector
        /// </summary>
        private void SetupThemeSelector()
        {
            ThemeComboBox.ItemsSource = _themeService.GetAvailableThemes().Select(t => t.DisplayName);
            ThemeComboBox.SelectedItem = _themeService.GetCurrentTheme().DisplayName;
        }
        
        /// <summary>
        /// Update admin status display
        /// </summary>
        private void UpdateAdminStatus()
        {
            AdminStatusText.Text = _adminService.GetAdminStatusMessage();
            
            if (_adminService.IsRunningAsAdmin())
            {
                AdminStatusText.Foreground = (System.Windows.Media.Brush)FindResource("SuccessBrush");
            }
            else
            {
                AdminStatusText.Foreground = (System.Windows.Media.Brush)FindResource("WarningBrush");
            }
        }
        
        /// <summary>
        /// Setup game profiles combo box
        /// </summary>
        private void SetupGameProfiles()
        {
            var profiles = _processService.GetGameProfiles().ToList();
            GameProfileComboBox.ItemsSource = profiles.Select(p => p.DisplayName);
            
            if (profiles.Any())
            {
                GameProfileComboBox.SelectedIndex = 0; // Default to CS2
            }
        }
        
        /// <summary>
        /// Setup data bindings
        /// </summary>
        private void SetupDataBindings()
        {
            // Bind log messages
            LogListBox.ItemsSource = _logMessages;
            
            // Bind running games
            RunningGamesDataGrid.ItemsSource = _runningGames;
        }
        
        /// <summary>
        /// Setup event handlers
        /// </summary>
        private void SetupEventHandlers()
        {
            // Performance monitoring events
            _performanceService.MetricsUpdated += PerformanceService_MetricsUpdated;
            
            // Process management events
            _processService.GameDetected += ProcessService_GameDetected;
            _processService.GameStopped += ProcessService_GameStopped;
            
            // Logging service events
            _logger.LogEntries.CollectionChanged += LogEntries_CollectionChanged;
            
            // Theme service events
            _themeService.ThemeChanged += ThemeService_ThemeChanged;
        }
        
        /// <summary>
        /// Start background services
        /// </summary>
        private void StartServices()
        {
            _performanceService.StartMonitoring();
            _processService.StartBackgroundMonitoring();
            _uiUpdateTimer.Start();
        }
        
        /// <summary>
        /// Load initial data
        /// </summary>
        private void LoadInitialData()
        {
            // Update system info
            Task.Run(UpdateSystemInfo);
            
            // Update backup status
            UpdateBackupStatus();
            
            // Refresh running games
            RefreshRunningGames();
        }
        
        /// <summary>
        /// Auto-detect GPU and apply recommendations
        /// </summary>
        private void AutoDetectGpuAndApplyRecommendations()
        {
            try
            {
                var gpu = _gpuService.DetectGpu();
                
                // Auto-check GPU vendor specific optimizations
                switch (gpu.Vendor)
                {
                    case "NVIDIA":
                        chkNvidiaTweaks.IsChecked = true;
                        _logger.LogInfo($"NVIDIA GPU detected: {gpu.Name} - NVIDIA optimizations pre-selected");
                        break;
                    case "AMD":
                        chkAmdTweaks.IsChecked = true;
                        _logger.LogInfo($"AMD GPU detected: {gpu.Name} - AMD optimizations pre-selected");
                        break;
                    case "Intel":
                        chkIntelTweaks.IsChecked = true;
                        _logger.LogInfo($"Intel GPU detected: {gpu.Name} - Intel optimizations pre-selected");
                        break;
                }
                
                // Enable hardware scheduling if supported
                if (gpu.HardwareSchedulingSupported)
                {
                    chkEnableGpuScheduling.IsChecked = true;
                    chkHardwareGpuScheduling.IsChecked = true;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to auto-detect GPU: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// UI update timer tick
        /// </summary>
        private void UiUpdateTimer_Tick(object sender, EventArgs e)
        {
            try
            {
                // Update performance metrics display
                var metrics = _performanceService.CurrentMetrics;
                if (metrics != null)
                {
                    CpuUsageText.Text = $"{metrics.CpuUsage:F1}%";
                    MemoryUsageText.Text = $"{metrics.MemoryUsage:N0} MB";
                    GpuUsageText.Text = metrics.GpuName ?? "Unknown";
                    ProcessCountText.Text = metrics.ActiveProcesses.ToString();
                    PerformanceStatusText.Text = $"Last updated: {metrics.Timestamp:HH:mm:ss}";
                }
                
                // Update running games
                RefreshRunningGames();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error updating UI: {ex.Message}", ex);
            }
        }
        
        #region Event Handlers
        
        /// <summary>
        /// Theme selection changed
        /// </summary>
        private void ThemeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            try
            {
                if (ThemeComboBox.SelectedItem is string selectedThemeName)
                {
                    var theme = _themeService.GetAvailableThemes()
                        .FirstOrDefault(t => t.DisplayName == selectedThemeName);
                    
                    if (theme != null)
                    {
                        _themeService.ApplyTheme(theme);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to change theme: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Apply recommended optimizations
        /// </summary>
        private async void RecommendedButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                RecommendedButton.IsEnabled = false;
                _logger.LogInfo("Applying recommended optimizations...");
                
                // Check admin requirements
                var optimizations = GetSelectedOptimizations();
                var adminValidation = _adminService.ValidateOperations(optimizations);
                
                if (adminValidation.RequiresElevation && !_adminService.IsRunningAsAdmin())
                {
                    var result = MessageBox.Show(
                        $"Some optimizations require administrator privileges:\n\n{adminValidation.GetSummary()}\n\n" +
                        "Would you like to restart as administrator?",
                        "Administrator Privileges Required",
                        MessageBoxButton.YesNo,
                        MessageBoxImage.Question);
                    
                    if (result == MessageBoxResult.Yes)
                    {
                        _adminService.RequestElevation();
                        return;
                    }
                }
                
                // Create backup first
                if (!_registryService.BackupExists())
                {
                    _logger.LogInfo("Creating backup before applying optimizations...");
                    await Task.Run(() => _registryService.CreateBackup());
                }
                
                // Apply optimizations
                await Task.Run(() => ApplyOptimizations(optimizations));
                
                _logger.LogInfo("Recommended optimizations applied successfully!");
                MessageBox.Show("Optimizations applied successfully!", "Success", 
                              MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply optimizations: {ex.Message}", ex);
                MessageBox.Show($"Failed to apply optimizations: {ex.Message}", "Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                RecommendedButton.IsEnabled = true;
            }
        }
        
        /// <summary>
        /// Revert all optimizations
        /// </summary>
        private async void RevertAllButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (!_registryService.BackupExists())
                {
                    MessageBox.Show("No backup found to restore from.", "Backup Not Found", 
                                  MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
                
                var result = MessageBox.Show(
                    "This will restore all settings from backup. Continue?",
                    "Confirm Restore",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);
                
                if (result == MessageBoxResult.Yes)
                {
                    RevertAllButton.IsEnabled = false;
                    _logger.LogInfo("Restoring from backup...");
                    
                    await Task.Run(() => _registryService.RestoreFromBackup());
                    
                    _logger.LogInfo("Settings restored from backup successfully!");
                    MessageBox.Show("Settings restored successfully!", "Success", 
                                  MessageBoxButton.OK, MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to restore from backup: {ex.Message}", ex);
                MessageBox.Show($"Failed to restore from backup: {ex.Message}", "Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                RevertAllButton.IsEnabled = true;
            }
        }
        
        /// <summary>
        /// Auto detect games
        /// </summary>
        private void AutoDetectButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var runningGames = _processService.GetRunningGames().ToList();
                
                if (runningGames.Any())
                {
                    var game = runningGames.First();
                    GameProfileComboBox.SelectedItem = game.DisplayName;
                    ProcessNameTextBox.Text = game.ProcessNames.FirstOrDefault() ?? "";
                    
                    _logger.LogInfo($"Auto-detected running game: {game.DisplayName}");
                }
                else
                {
                    _logger.LogInfo("No supported games currently running");
                    MessageBox.Show("No supported games currently running.", "Auto-Detection", 
                                  MessageBoxButton.OK, MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to auto-detect games: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Optimize specific process
        /// </summary>
        private void OptimizeProcessButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var processName = ProcessNameTextBox.Text.Trim();
                if (string.IsNullOrEmpty(processName))
                {
                    MessageBox.Show("Please enter a process name.", "Invalid Input", 
                                  MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
                
                var priority = (ProcessPriority)Enum.Parse(typeof(ProcessPriority), 
                    ((ComboBoxItem)PriorityComboBox.SelectedItem).Tag.ToString());
                
                var success = _processService.OptimizeProcess(processName, priority);
                
                if (success)
                {
                    _logger.LogInfo($"Process '{processName}' optimized with {priority} priority");
                    MessageBox.Show($"Process '{processName}' optimized successfully!", "Success", 
                                  MessageBoxButton.OK, MessageBoxImage.Information);
                }
                else
                {
                    MessageBox.Show($"Failed to optimize process '{processName}'. Make sure it's running.", "Error", 
                                  MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize process: {ex.Message}", ex);
                MessageBox.Show($"Failed to optimize process: {ex.Message}", "Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
        
        /// <summary>
        /// Refresh running games
        /// </summary>
        private void RefreshGamesButton_Click(object sender, RoutedEventArgs e)
        {
            RefreshRunningGames();
        }
        
        /// <summary>
        /// Create backup
        /// </summary>
        private async void CreateBackupButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                CreateBackupButton.IsEnabled = false;
                _logger.LogInfo("Creating system backup...");
                
                var success = await Task.Run(() => _registryService.CreateBackup());
                
                if (success)
                {
                    _logger.LogInfo("Backup created successfully!");
                    MessageBox.Show("Backup created successfully!", "Success", 
                                  MessageBoxButton.OK, MessageBoxImage.Information);
                    UpdateBackupStatus();
                }
                else
                {
                    MessageBox.Show("Failed to create backup. Check the log for details.", "Error", 
                                  MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to create backup: {ex.Message}", ex);
                MessageBox.Show($"Failed to create backup: {ex.Message}", "Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                CreateBackupButton.IsEnabled = true;
            }
        }
        
        /// <summary>
        /// Restore backup
        /// </summary>
        private async void RestoreBackupButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (!_registryService.BackupExists())
                {
                    MessageBox.Show("No backup found to restore from.", "Backup Not Found", 
                                  MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
                
                var result = MessageBox.Show(
                    "This will restore all settings from backup. Continue?",
                    "Confirm Restore",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);
                
                if (result == MessageBoxResult.Yes)
                {
                    RestoreBackupButton.IsEnabled = false;
                    
                    var success = await Task.Run(() => _registryService.RestoreFromBackup());
                    
                    if (success)
                    {
                        _logger.LogInfo("Settings restored from backup successfully!");
                        MessageBox.Show("Settings restored successfully!", "Success", 
                                      MessageBoxButton.OK, MessageBoxImage.Information);
                    }
                    else
                    {
                        MessageBox.Show("Failed to restore from backup. Check the log for details.", "Error", 
                                      MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to restore from backup: {ex.Message}", ex);
                MessageBox.Show($"Failed to restore from backup: {ex.Message}", "Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                RestoreBackupButton.IsEnabled = true;
            }
        }
        
        /// <summary>
        /// Export configuration
        /// </summary>
        private void ExportConfigButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var dialog = new SaveFileDialog
                {
                    Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
                    DefaultExt = "json",
                    FileName = $"KOALA-Config-{DateTime.Now:yyyy-MM-dd}.json"
                };
                
                if (dialog.ShowDialog() == true)
                {
                    var config = GetCurrentConfiguration();
                    var json = Newtonsoft.Json.JsonConvert.SerializeObject(config, Newtonsoft.Json.Formatting.Indented);
                    File.WriteAllText(dialog.FileName, json);
                    
                    _logger.LogInfo($"Configuration exported to: {dialog.FileName}");
                    MessageBox.Show("Configuration exported successfully!", "Success", 
                                  MessageBoxButton.OK, MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to export configuration: {ex.Message}", ex);
                MessageBox.Show($"Failed to export configuration: {ex.Message}", "Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
        
        /// <summary>
        /// Import configuration
        /// </summary>
        private void ImportConfigButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var dialog = new OpenFileDialog
                {
                    Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
                    DefaultExt = "json"
                };
                
                if (dialog.ShowDialog() == true)
                {
                    var json = File.ReadAllText(dialog.FileName);
                    var config = Newtonsoft.Json.JsonConvert.DeserializeObject<Dictionary<string, bool>>(json);
                    
                    ApplyConfiguration(config);
                    
                    _logger.LogInfo($"Configuration imported from: {dialog.FileName}");
                    MessageBox.Show("Configuration imported successfully!", "Success", 
                                  MessageBoxButton.OK, MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to import configuration: {ex.Message}", ex);
                MessageBox.Show($"Failed to import configuration: {ex.Message}", "Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
        
        /// <summary>
        /// Clear log
        /// </summary>
        private void ClearLogButton_Click(object sender, RoutedEventArgs e)
        {
            _logMessages.Clear();
            _logger.ClearLogs();
        }
        
        /// <summary>
        /// Export log
        /// </summary>
        private void ExportLogButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var dialog = new SaveFileDialog
                {
                    Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*",
                    DefaultExt = "txt",
                    FileName = $"KOALA-Log-{DateTime.Now:yyyy-MM-dd-HH-mm}.txt"
                };
                
                if (dialog.ShowDialog() == true)
                {
                    _logger.ExportLogs(dialog.FileName);
                    MessageBox.Show("Log exported successfully!", "Success", 
                                  MessageBoxButton.OK, MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to export log: {ex.Message}", ex);
                MessageBox.Show($"Failed to export log: {ex.Message}", "Error", 
                              MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
        
        /// <summary>
        /// Show system information
        /// </summary>
        private void SystemInfoButton_Click(object sender, RoutedEventArgs e)
        {
            Task.Run(UpdateSystemInfo);
        }
        
        /// <summary>
        /// Run quick benchmark
        /// </summary>
        private async void BenchmarkButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                BenchmarkButton.IsEnabled = false;
                _logger.LogInfo("Running quick performance benchmark...");
                
                await Task.Run(() =>
                {
                    // Simple timer resolution benchmark
                    var timerPerformance = _timerService.MeasureTimerPrecision();
                    var isGood = _timerService.ValidateTimerPerformance();
                    
                    Dispatcher.Invoke(() =>
                    {
                        var message = $"Timer Performance Benchmark:\n\n" +
                                    $"Measured Resolution: {timerPerformance:F2}ms\n" +
                                    $"Performance Rating: {(isGood ? "Good" : "Poor")}\n\n" +
                                    $"Recommendation: {(isGood ? "Timer performance is optimized for gaming" : "Consider enabling high precision timer optimization")}";
                        
                        MessageBox.Show(message, "Performance Benchmark", 
                                      MessageBoxButton.OK, MessageBoxImage.Information);
                    });
                });
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to run benchmark: {ex.Message}", ex);
            }
            finally
            {
                BenchmarkButton.IsEnabled = true;
            }
        }
        
        #endregion
        
        #region Service Event Handlers
        
        /// <summary>
        /// Performance metrics updated
        /// </summary>
        private void PerformanceService_MetricsUpdated(object sender, PerformanceMetrics e)
        {
            // UI updates are handled in the timer tick
        }
        
        /// <summary>
        /// Game detected
        /// </summary>
        private void ProcessService_GameDetected(object sender, GameProfile e)
        {
            Dispatcher.Invoke(() =>
            {
                _logger.LogInfo($"🎮 Game detected: {e.DisplayName}");
                RefreshRunningGames();
            });
        }
        
        /// <summary>
        /// Game stopped
        /// </summary>
        private void ProcessService_GameStopped(object sender, GameProfile e)
        {
            Dispatcher.Invoke(() =>
            {
                _logger.LogInfo($"🎮 Game stopped: {e.DisplayName}");
                RefreshRunningGames();
            });
        }
        
        /// <summary>
        /// Log entries collection changed
        /// </summary>
        private void LogEntries_CollectionChanged(object sender, System.Collections.Specialized.NotifyCollectionChangedEventArgs e)
        {
            Dispatcher.BeginInvoke(new Action(() =>
            {
                if (e.NewItems != null)
                {
                    foreach (LogEntry entry in e.NewItems)
                    {
                        var message = $"[{entry.Timestamp:HH:mm:ss}] [{entry.Level}] {entry.Message}";
                        _logMessages.Add(message);
                        
                        // Keep only last 500 messages in UI
                        while (_logMessages.Count > 500)
                        {
                            _logMessages.RemoveAt(0);
                        }
                    }
                    
                    // Auto-scroll to bottom
                    if (LogListBox.Items.Count > 0)
                    {
                        LogListBox.ScrollIntoView(LogListBox.Items[LogListBox.Items.Count - 1]);
                    }
                }
            }));
        }
        
        /// <summary>
        /// Theme changed
        /// </summary>
        private void ThemeService_ThemeChanged(object sender, ThemeInfo e)
        {
            _logger.LogInfo($"Theme changed to: {e.DisplayName}");
        }
        
        #endregion
        
        #region Helper Methods
        
        /// <summary>
        /// Get selected optimizations from UI
        /// </summary>
        private List<OptimizationItem> GetSelectedOptimizations()
        {
            var optimizations = new List<OptimizationItem>();
            
            // Network optimizations
            if (chkDisableNagle.IsChecked == true)
                optimizations.Add(new OptimizationItem { Name = "DisableNagleAlgorithm", IsEnabled = true, RequiresAdmin = true, Type = OptimizationType.Registry });
            
            if (chkTcpDelayedAck.IsChecked == true)
                optimizations.Add(new OptimizationItem { Name = "OptimizeTCPSettings", IsEnabled = true, RequiresAdmin = true, Type = OptimizationType.Registry });
            
            // Gaming optimizations
            if (chkDisableGameDVR.IsChecked == true)
                optimizations.Add(new OptimizationItem { Name = "DisableGameDVR", IsEnabled = true, RequiresAdmin = false, Type = OptimizationType.Registry });
            
            if (chkEnableGpuScheduling.IsChecked == true)
                optimizations.Add(new OptimizationItem { Name = "EnableHardwareGPUScheduling", IsEnabled = true, RequiresAdmin = true, Type = OptimizationType.Registry });
            
            if (chkOptimizeMemoryManagement.IsChecked == true)
                optimizations.Add(new OptimizationItem { Name = "OptimizeMemoryManagement", IsEnabled = true, RequiresAdmin = true, Type = OptimizationType.Registry });
            
            if (chkOptimizeCpuScheduling.IsChecked == true)
                optimizations.Add(new OptimizationItem { Name = "OptimizeCPUScheduling", IsEnabled = true, RequiresAdmin = true, Type = OptimizationType.Registry });
            
            if (chkOptimizeVisualEffects.IsChecked == true)
                optimizations.Add(new OptimizationItem { Name = "DisableVisualEffects", IsEnabled = true, RequiresAdmin = false, Type = OptimizationType.Registry });
            
            if (chkDisableNetworkThrottling.IsChecked == true)
                optimizations.Add(new OptimizationItem { Name = "OptimizeNetworkSettings", IsEnabled = true, RequiresAdmin = true, Type = OptimizationType.Registry });
            
            return optimizations;
        }
        
        /// <summary>
        /// Apply optimizations
        /// </summary>
        private void ApplyOptimizations(List<OptimizationItem> optimizations)
        {
            try
            {
                // Apply registry optimizations
                _registryService.ApplyGamingOptimizations(optimizations);
                
                // Apply timer resolution if enabled
                if (chkHighPrecisionTimer.IsChecked == true)
                {
                    _timerService.SetHighPrecisionTimer();
                }
                
                _logger.LogInfo($"Applied {optimizations.Count} optimizations successfully");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply optimizations: {ex.Message}", ex);
                throw;
            }
        }
        
        /// <summary>
        /// Update system information
        /// </summary>
        private void UpdateSystemInfo()
        {
            try
            {
                var gpu = _gpuService.GetCurrentGpuInfo();
                var detailedGpuInfo = _gpuService.GetDetailedGpuInfo();
                
                var systemInfo = $"🐨 KOALA Gaming Optimizer v2.3 - C# Edition\n" +
                               $"{"=",-50}\n\n" +
                               $"🖥️ System Information:\n" +
                               $"OS: {Environment.OSVersion}\n" +
                               $"Architecture: {Environment.Is64BitOperatingSystem} bit\n" +
                               $"Processors: {Environment.ProcessorCount}\n" +
                               $"Machine Name: {Environment.MachineName}\n" +
                               $"User: {Environment.UserName}\n\n" +
                               $"🎮 GPU Information:\n" +
                               $"{detailedGpuInfo}\n" +
                               $"💡 Optimization Recommendations:\n" +
                               $"{_gpuService.GetOptimizationDescription()}\n\n" +
                               $"⚡ Performance Status:\n" +
                               $"High Precision Timer: {(_timerService.IsHighPrecisionTimerSet() ? "Enabled" : "Disabled")}\n" +
                               $"Timer Status: {_timerService.GetTimerStatus()}\n" +
                               $"Performance Monitoring: {(_performanceService.IsMonitoring ? "Active" : "Stopped")}\n" +
                               $"Process Monitoring: Active\n\n" +
                               $"💾 Backup Status:\n" +
                               $"Backup Available: {(_registryService.BackupExists() ? "Yes" : "No")}\n" +
                               $"Backup Location: {_registryService.GetBackupFilePath()}\n\n" +
                               $"Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}";
                
                Dispatcher.Invoke(() =>
                {
                    SystemInfoTextBlock.Text = systemInfo;
                });
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to update system info: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Refresh running games list
        /// </summary>
        private void RefreshRunningGames()
        {
            try
            {
                _runningGames.Clear();
                var runningGames = _processService.GetRunningGames();
                
                foreach (var game in runningGames)
                {
                    _runningGames.Add(game);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to refresh running games: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Update backup status
        /// </summary>
        private void UpdateBackupStatus()
        {
            try
            {
                if (_registryService.BackupExists())
                {
                    BackupStatusText.Text = "✓ Backup available";
                    BackupStatusText.Foreground = (System.Windows.Media.Brush)FindResource("SuccessBrush");
                }
                else
                {
                    BackupStatusText.Text = "⚠ No backup found";
                    BackupStatusText.Foreground = (System.Windows.Media.Brush)FindResource("WarningBrush");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to update backup status: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get current configuration
        /// </summary>
        private Dictionary<string, bool> GetCurrentConfiguration()
        {
            return new Dictionary<string, bool>
            {
                ["DisableNagle"] = chkDisableNagle.IsChecked ?? false,
                ["TcpDelayedAck"] = chkTcpDelayedAck.IsChecked ?? false,
                ["DisableGameDVR"] = chkDisableGameDVR.IsChecked ?? false,
                ["EnableGpuScheduling"] = chkEnableGpuScheduling.IsChecked ?? false,
                ["HighPrecisionTimer"] = chkHighPrecisionTimer.IsChecked ?? false,
                ["OptimizeMemoryManagement"] = chkOptimizeMemoryManagement.IsChecked ?? false,
                ["OptimizeCpuScheduling"] = chkOptimizeCpuScheduling.IsChecked ?? false,
                ["OptimizeVisualEffects"] = chkOptimizeVisualEffects.IsChecked ?? false,
                ["DisableNetworkThrottling"] = chkDisableNetworkThrottling.IsChecked ?? false,
                ["NvidiaTweaks"] = chkNvidiaTweaks.IsChecked ?? false,
                ["AmdTweaks"] = chkAmdTweaks.IsChecked ?? false,
                ["IntelTweaks"] = chkIntelTweaks.IsChecked ?? false
            };
        }
        
        /// <summary>
        /// Apply configuration
        /// </summary>
        private void ApplyConfiguration(Dictionary<string, bool> config)
        {
            if (config.ContainsKey("DisableNagle"))
                chkDisableNagle.IsChecked = config["DisableNagle"];
            if (config.ContainsKey("TcpDelayedAck"))
                chkTcpDelayedAck.IsChecked = config["TcpDelayedAck"];
            if (config.ContainsKey("DisableGameDVR"))
                chkDisableGameDVR.IsChecked = config["DisableGameDVR"];
            if (config.ContainsKey("EnableGpuScheduling"))
                chkEnableGpuScheduling.IsChecked = config["EnableGpuScheduling"];
            if (config.ContainsKey("HighPrecisionTimer"))
                chkHighPrecisionTimer.IsChecked = config["HighPrecisionTimer"];
            if (config.ContainsKey("OptimizeMemoryManagement"))
                chkOptimizeMemoryManagement.IsChecked = config["OptimizeMemoryManagement"];
            if (config.ContainsKey("OptimizeCpuScheduling"))
                chkOptimizeCpuScheduling.IsChecked = config["OptimizeCpuScheduling"];
            if (config.ContainsKey("OptimizeVisualEffects"))
                chkOptimizeVisualEffects.IsChecked = config["OptimizeVisualEffects"];
            if (config.ContainsKey("DisableNetworkThrottling"))
                chkDisableNetworkThrottling.IsChecked = config["DisableNetworkThrottling"];
            if (config.ContainsKey("NvidiaTweaks"))
                chkNvidiaTweaks.IsChecked = config["NvidiaTweaks"];
            if (config.ContainsKey("AmdTweaks"))
                chkAmdTweaks.IsChecked = config["AmdTweaks"];
            if (config.ContainsKey("IntelTweaks"))
                chkIntelTweaks.IsChecked = config["IntelTweaks"];
        }
        
        #endregion
        
        #region Crosshair Hotkey Support
        
        /// <summary>
        /// Initialize crosshair hotkey support
        /// </summary>
        private void InitializeCrosshairHotkey()
        {
            try
            {
                // Set up window handle for hotkey registration
                var source = HwndSource.FromHwnd(new WindowInteropHelper(this).Handle);
                if (source != null)
                {
                    source.AddHook(HwndHook);
                    _crosshairService.InitializeHotkey(new WindowInteropHelper(this).Handle);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to initialize crosshair hotkey: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Window procedure hook for handling hotkey messages
        /// </summary>
        private IntPtr HwndHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            const int WM_HOTKEY = 0x0312;
            
            if (msg == WM_HOTKEY)
            {
                var hotkeyId = wParam.ToInt32();
                _crosshairService.HandleHotkey(hotkeyId);
                handled = true;
            }
            
            return IntPtr.Zero;
        }
        
        #endregion
        
        /// <summary>
        /// Handle window closing
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void MainWindow_Closed(object sender, EventArgs e)
        {
            try
            {
                // Stop services
                _uiUpdateTimer?.Stop();
                _performanceService?.StopMonitoring();
                _processService?.StopBackgroundMonitoring();
                
                // Cleanup timer resolution
                _timerService?.RestoreOriginalResolution();
                
                // Cleanup crosshair service
                _crosshairService?.Dispose();
                
                _logger?.LogInfo("KOALA Gaming Optimizer - Application closed");
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Error during shutdown: {ex.Message}", ex);
            }
        }
    }
}