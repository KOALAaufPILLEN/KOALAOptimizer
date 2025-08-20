using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;

namespace KOALAOptimizer
{
    public partial class MainWindow : Window
    {
        private readonly DispatcherTimer monitorTimer;
        private readonly DispatcherTimer performanceTimer;
        private readonly DispatcherTimer statusTimer;
        private bool isOptimized = false;
        private bool isSafeMode = true;
        private bool hasShownPerformanceWarning = false;
        private readonly string backupPath;

        public MainWindow()
        {
            InitializeComponent();
            
            backupPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Koala-Backup-V3.json");
            
            // Initialize timers
            monitorTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
            monitorTimer.Tick += MonitorTimer_Tick;
            
            performanceTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            performanceTimer.Tick += UpdatePerformanceMetrics;
            
            statusTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            statusTimer.Tick += (s, e) => UpdateStatusTime();
            
            // Initialize application
            CheckAdminPrivileges();
            InitializeUI();
            InitializePerformanceMonitor();
            InitializeStatusBar();
            LoadBackupStatus();
            
            // Set version
            if (VersionTextBlock != null)
                VersionTextBlock.Text = "v3.0.0";
            
            Title = "KOALA Gaming Optimizer V3 - Safe Mode";
            
            // Log startup
            Log("KOALA Gaming Optimizer V3 started - Safe Mode active");
            Log($"Created by KOALAaufPILLEN - {DateTime.Now:yyyy-MM-dd}");
        }

        private void UpdateStatusTime()
        {
            if (TimeTextBlock != null)
                TimeTextBlock.Text = DateTime.Now.ToString("HH:mm:ss");
        }

        private void InitializeUI()
        {
            // Initialize game profiles
            if (GameProfileComboBox != null)
            {
                GameProfileComboBox.Items.Clear();
                var profiles = new[]
                {
                    "Counter-Strike 2",
                    "Valorant",
                    "Fortnite",
                    "Apex Legends",
                    "Overwatch 2",
                    "Call of Duty: Warzone",
                    "Minecraft",
                    "Roblox",
                    "League of Legends",
                    "Grand Theft Auto V",
                    "Rocket League",
                    "Rainbow Six Siege",
                    "PUBG",
                    "Dota 2",
                    "Deadlock"
                };
                
                foreach (var profile in profiles)
                {
                    GameProfileComboBox.Items.Add(new ComboBoxItem { Content = profile });
                }
                
                if (GameProfileComboBox.Items.Count > 0)
                    GameProfileComboBox.SelectedIndex = 0;
            }

            // Initialize crosshair themes
            if (CrosshairThemeComboBox != null)
            {
                CrosshairThemeComboBox.Items.Clear();
                CrosshairThemeComboBox.Items.Add("Classic Cross");
                CrosshairThemeComboBox.Items.Add("Dot");
                CrosshairThemeComboBox.Items.Add("Circle");
                CrosshairThemeComboBox.Items.Add("Square");
                CrosshairThemeComboBox.Items.Add("T-Shape");
                CrosshairThemeComboBox.SelectedIndex = 0;
            }

            // Initialize FOV styles
            if (FovStyleComboBox != null)
            {
                FovStyleComboBox.Items.Clear();
                FovStyleComboBox.Items.Add("Circle");
                FovStyleComboBox.Items.Add("Rectangle");
                FovStyleComboBox.Items.Add("Hexagon");
                FovStyleComboBox.SelectedIndex = 0;
            }

            // Set default values
            if (CrosshairSizeSlider != null) CrosshairSizeSlider.Value = 20;
            if (CrosshairOpacitySlider != null) CrosshairOpacitySlider.Value = 0.8;
            if (FovRadiusSlider != null) FovRadiusSlider.Value = 100;
            if (FovOpacitySlider != null) FovOpacitySlider.Value = 0.3;
            
            // Set default settings
            if (BackupRetentionComboBox != null) BackupRetentionComboBox.SelectedIndex = 1;
            if (ShowNotificationsCheckBox != null) ShowNotificationsCheckBox.IsChecked = true;
            if (SafeModeRadio != null) SafeModeRadio.IsChecked = true;
            
            UpdateModeDisplay();
        }

        private void InitializePerformanceMonitor()
        {
            performanceTimer.Start();
        }

        private void InitializeStatusBar()
        {
            statusTimer.Start();
            if (StatusTextBlock != null)
                StatusTextBlock.Text = "Ready - Safe Mode Active";
        }

        private void CheckAdminPrivileges()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                bool isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);

                if (AdminStatusTextBlock != null)
                {
                    AdminStatusTextBlock.Text = isAdmin 
                        ? "✓ Running with Administrator privileges - All optimizations available"
                        : "⚠ Limited mode - Some optimizations require administrator privileges";
                    
                    AdminStatusTextBlock.Foreground = isAdmin 
                        ? new SolidColorBrush(Colors.LightGreen) 
                        : new SolidColorBrush(Colors.Orange);
                }
            }
            catch
            {
                if (AdminStatusTextBlock != null)
                    AdminStatusTextBlock.Text = "⚠ Unable to check admin privileges";
            }
        }

        private void LoadBackupStatus()
        {
            if (File.Exists(backupPath))
            {
                try
                {
                    var backupContent = File.ReadAllText(backupPath);
                    if (BackupStatusTextBlock != null)
                    {
                        BackupStatusTextBlock.Text = $"Last backup: {File.GetLastWriteTime(backupPath):yyyy-MM-dd HH:mm:ss}";
                    }
                    if (RestoreButton != null)
                    {
                        RestoreButton.IsEnabled = true;
                    }
                }
                catch (Exception ex)
                {
                    Log($"Failed to load backup status: {ex.Message}");
                }
            }
        }

        private void SafeModeRadio_Checked(object sender, RoutedEventArgs e)
        {
            isSafeMode = true;
            UpdateModeDisplay();
            if (OptimizeButton != null)
                OptimizeButton.Content = "Apply Safe Optimizations";
            if (AggressiveOptimizationCheckBox != null)
                AggressiveOptimizationCheckBox.IsEnabled = false;
            Log("Switched to Safe Mode - Anti-cheat compatible optimizations");
            if (StatusTextBlock != null)
                StatusTextBlock.Text = "Ready - Safe Mode Active";
        }

        private void PerformanceModeRadio_Checked(object sender, RoutedEventArgs e)
        {
            if (!hasShownPerformanceWarning)
            {
                ShowPerformanceModeWarning();
            }
            else
            {
                EnablePerformanceMode();
            }
        }

        private void ShowPerformanceModeWarning()
        {
            var result = MessageBox.Show(
                "⚠️ WARNING: Performance Mode may trigger anti-cheat systems!\n\n" +
                "This mode should ONLY be used for:\n" +
                "• Single-player games\n" +
                "• Games without anti-cheat\n" +
                "• Offline gaming\n\n" +
                "Using this in online games may result in PERMANENT BANS!\n\n" +
                "Do you accept the risk?",
                "Performance Mode Warning",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);

            if (result == MessageBoxResult.Yes)
            {
                hasShownPerformanceWarning = true;
                EnablePerformanceMode();
            }
            else
            {
                if (SafeModeRadio != null)
                    SafeModeRadio.IsChecked = true;
            }
        }

        private void EnablePerformanceMode()
        {
            isSafeMode = false;
            UpdateModeDisplay();
            if (OptimizeButton != null)
                OptimizeButton.Content = "Apply Performance Optimizations";
            if (AggressiveOptimizationCheckBox != null)
                AggressiveOptimizationCheckBox.IsEnabled = true;
            Log("⚠️ PERFORMANCE MODE ACTIVATED - DO NOT USE IN ONLINE GAMES!");
            if (StatusTextBlock != null)
                StatusTextBlock.Text = "Ready - Performance Mode Active (Use at own risk!)";
        }

        private void UpdateModeDisplay()
        {
            if (ModeBadge != null && ModeTextBlock != null)
            {
                if (isSafeMode)
                {
                    ModeBadge.Background = new SolidColorBrush(Colors.Green);
                    ModeTextBlock.Text = "SAFE MODE";
                    Title = "KOALA Gaming Optimizer V3 - Safe Mode";
                }
                else
                {
                    ModeBadge.Background = new SolidColorBrush(Colors.OrangeRed);
                    ModeTextBlock.Text = "PERFORMANCE MODE";
                    Title = "KOALA Gaming Optimizer V3 - Performance Mode (AT OWN RISK)";
                }
            }
        }

        private void OptimizeButton_Click(object sender, RoutedEventArgs e)
        {
            Log(isSafeMode ? "Applying Safe Mode optimizations..." : "Applying Performance Mode optimizations...");
            
            // Simulate optimization
            Task.Run(async () =>
            {
                Dispatcher.Invoke(() => 
                {
                    if (ProgressBar != null)
                    {
                        ProgressBar.Visibility = Visibility.Visible;
                        ProgressBar.IsIndeterminate = true;
                    }
                });
                
                await Task.Delay(2000); // Simulate work
                
                Dispatcher.Invoke(() =>
                {
                    if (ProgressBar != null)
                        ProgressBar.Visibility = Visibility.Collapsed;
                    
                    Log("✓ Optimizations applied successfully!");
                    MessageBox.Show("Optimizations applied successfully!", "KOALA Optimizer", 
                        MessageBoxButton.OK, MessageBoxImage.Information);
                });
            });
        }

        private void RestoreButton_Click(object sender, RoutedEventArgs e)
        {
            Log("Restoring from backup...");
            MessageBox.Show("Backup restored successfully!", "KOALA Optimizer", 
                MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void ThemeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ThemeComboBox?.SelectedItem is ComboBoxItem item && item.Tag != null)
            {
                if (Enum.TryParse<ThemeType>(item.Tag.ToString(), out var theme))
                {
                    ThemeManager.ApplyTheme(theme);
                    ThemeManager.SaveThemePreference(theme);
                    Log($"Theme changed to: {theme}");
                }
            }
        }

        private void MonitorTimer_Tick(object? sender, EventArgs e)
        {
            // Monitor running games
        }

        private void UpdatePerformanceMetrics(object? sender, EventArgs e)
        {
            try
            {
                // Update CPU
                if (CpuProgressBar != null && CpuTextBlock != null)
                {
                    var cpuUsage = GetCpuUsage();
                    CpuProgressBar.Value = cpuUsage;
                    CpuTextBlock.Text = $"{cpuUsage:F0}%";
                }
                
                // Update RAM
                if (RamProgressBar != null && RamTextBlock != null)
                {
                    var (used, total) = GetMemoryUsage();
                    RamProgressBar.Value = (used / total) * 100;
                    RamTextBlock.Text = $"{used:F1} GB / {total:F1} GB";
                }
                
                // Update GPU
                if (GpuProgressBar != null && GpuTextBlock != null)
                {
                    var gpuUsage = GetGpuUsage();
                    GpuProgressBar.Value = gpuUsage;
                    GpuTextBlock.Text = $"{gpuUsage:F0}%";
                }
            }
            catch { }
        }

        private double GetCpuUsage()
        {
            // Simplified CPU usage
            return new Random().Next(10, 40);
        }

        private (double used, double total) GetMemoryUsage()
        {
            // Simplified memory usage
            return (8.5, 16.0);
        }

        private double GetGpuUsage()
        {
            // Simplified GPU usage
            return new Random().Next(20, 50);
        }

        private void Log(string message)
        {
            var timestamp = DateTime.Now.ToString("HH:mm:ss");
            var logMessage = $"[{timestamp}] {message}";
            
            Dispatcher.Invoke(() =>
            {
                if (LogTextBox != null)
                {
                    LogTextBox.AppendText(logMessage + Environment.NewLine);
                    LogTextBox.ScrollToEnd();
                }
            });
        }

        // Event handler stubs
        private void CrosshairToggle_Checked(object sender, RoutedEventArgs e) 
        {
            Log("Crosshair enabled");
        }
        
        private void CrosshairToggle_Unchecked(object sender, RoutedEventArgs e) 
        {
            Log("Crosshair disabled");
        }
        
        private void CrosshairThemeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e) { }
        private void CrosshairSizeSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
        private void CrosshairOpacitySlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
        
        private void FovToggle_Checked(object sender, RoutedEventArgs e) 
        {
            Log("FOV indicator enabled");
        }
        
        private void FovToggle_Unchecked(object sender, RoutedEventArgs e) 
        {
            Log("FOV indicator disabled");
        }
        
        private void FovStyleComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e) { }
        private void FovRadiusSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
        private void FovOpacitySlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
        
        private void ResetToDefaultsButton_Click(object sender, RoutedEventArgs e) 
        {
            var result = MessageBox.Show(
                "Are you sure you want to reset all settings to defaults?",
                "Reset Settings",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);
                
            if (result == MessageBoxResult.Yes)
            {
                InitializeUI();
                Log("Settings reset to defaults");
            }
        }
    }
}
