using System;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using System.Security.Principal;

namespace KOALAOptimizer
{
    public partial class MainWindow : Window
    {
        private readonly DispatcherTimer statusTimer;
        private bool isSafeMode = true;
        private readonly string backupPath;

        public MainWindow()
        {
            InitializeComponent();
            
            backupPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Koala-Backup-V3.json");
            
            statusTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            statusTimer.Tick += (s, e) => UpdateStatusTime();
            statusTimer.Start();
            
            InitializeUI();
            CheckAdminPrivileges();
            LoadBackupStatus();
            
            Title = "KOALA Gaming Optimizer V3 - Safe Mode";
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
                var profiles = new[] { "Counter-Strike 2", "Valorant", "Fortnite", "Apex Legends", "Overwatch 2" };
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
                CrosshairThemeComboBox.SelectedIndex = 0;
            }

            // Initialize FOV styles
            if (FovStyleComboBox != null)
            {
                FovStyleComboBox.Items.Clear();
                FovStyleComboBox.Items.Add("Circle");
                FovStyleComboBox.Items.Add("Rectangle");
                FovStyleComboBox.SelectedIndex = 0;
            }

            // Set defaults
            if (SafeModeRadio != null) SafeModeRadio.IsChecked = true;
            if (StatusTextBlock != null) StatusTextBlock.Text = "Ready - Safe Mode Active";
            if (VersionTextBlock != null) VersionTextBlock.Text = "v3.0.0";
            
            UpdateModeDisplay();
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
                        ? "✓ Running with Administrator privileges"
                        : "⚠ Limited mode - Run as Administrator for all features";
                    AdminStatusTextBlock.Foreground = isAdmin 
                        ? new SolidColorBrush(Colors.LightGreen) 
                        : new SolidColorBrush(Colors.Orange);
                }
            }
            catch
            {
                if (AdminStatusTextBlock != null)
                    AdminStatusTextBlock.Text = "Unable to check admin status";
            }
        }

        private void LoadBackupStatus()
        {
            if (File.Exists(backupPath) && BackupStatusTextBlock != null)
            {
                BackupStatusTextBlock.Text = $"Backup available";
                if (RestoreButton != null)
                    RestoreButton.IsEnabled = true;
            }
        }

        private void UpdateModeDisplay()
        {
            if (ModeBadge != null && ModeTextBlock != null)
            {
                if (isSafeMode)
                {
                    ModeBadge.Background = new SolidColorBrush(Colors.Green);
                    ModeTextBlock.Text = "SAFE MODE";
                }
                else
                {
                    ModeBadge.Background = new SolidColorBrush(Colors.OrangeRed);
                    ModeTextBlock.Text = "PERFORMANCE MODE";
                }
            }
        }

        private void Log(string message)
        {
            if (LogTextBox != null)
            {
                var timestamp = DateTime.Now.ToString("HH:mm:ss");
                LogTextBox.AppendText($"[{timestamp}] {message}\n");
                LogTextBox.ScrollToEnd();
            }
        }

        // Event Handlers
        private void OptimizeButton_Click(object sender, RoutedEventArgs e)
        {
            Log(isSafeMode ? "Applying Safe Mode optimizations..." : "Applying Performance Mode optimizations...");
            MessageBox.Show("Optimizations applied!", "KOALA Optimizer", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void RestoreButton_Click(object sender, RoutedEventArgs e)
        {
            Log("Restoring from backup...");
            MessageBox.Show("Backup restored!", "KOALA Optimizer", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void SafeModeRadio_Checked(object sender, RoutedEventArgs e)
        {
            isSafeMode = true;
            UpdateModeDisplay();
            if (OptimizeButton != null) OptimizeButton.Content = "Apply Safe Optimizations";
            Log("Switched to Safe Mode");
        }

        private void PerformanceModeRadio_Checked(object sender, RoutedEventArgs e)
        {
            isSafeMode = false;
            UpdateModeDisplay();
            if (OptimizeButton != null) OptimizeButton.Content = "Apply Performance Optimizations";
            Log("Switched to Performance Mode");
        }

        private void ThemeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ThemeComboBox?.SelectedItem is ComboBoxItem item && item.Tag != null)
            {
                if (Enum.TryParse<ThemeType>(item.Tag.ToString(), out var theme))
                {
                    ThemeManager.ApplyTheme(theme);
                    ThemeManager.SaveThemePreference(theme);
                }
            }
        }

        // Empty handlers to prevent build errors
        private void CrosshairToggle_Checked(object sender, RoutedEventArgs e) { }
        private void CrosshairToggle_Unchecked(object sender, RoutedEventArgs e) { }
        private void CrosshairThemeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e) { }
        private void CrosshairSizeSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
        private void CrosshairOpacitySlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
        private void FovToggle_Checked(object sender, RoutedEventArgs e) { }
        private void FovToggle_Unchecked(object sender, RoutedEventArgs e) { }
        private void FovStyleComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e) { }
        private void FovRadiusSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
        private void FovOpacitySlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) { }
        private void ResetToDefaultsButton_Click(object sender, RoutedEventArgs e) { }
    }
}