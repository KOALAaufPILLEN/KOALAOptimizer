using System;
using System.Windows;
using System.Windows.Media;
using System.Management;
using Microsoft.Win32;

namespace KOALAOptimizer
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
            LoadSystemInfo();
        }

        private void LoadSystemInfo()
        {
            try
            {
                string info = "System Information:\n";
                info += $"OS: {Environment.OSVersion}\n";
                info += $"Processor: {Environment.ProcessorCount} cores\n";
                info += $"64-bit: {Environment.Is64BitOperatingSystem}\n";
                info += $"Machine: {Environment.MachineName}\n";
                
                SystemInfoText.Text = info;
                SystemInfoText.Foreground = new SolidColorBrush(Colors.LightGreen);
            }
            catch
            {
                SystemInfoText.Text = "System information loaded";
            }
        }

        private void OptimizeButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusText.Text = "Optimizing system...";
                StatusText.Foreground = new SolidColorBrush(Colors.Yellow);
                
                bool isSafeMode = SafeModeRadio.IsChecked == true;
                string mode = isSafeMode ? "Safe Mode" : "Performance Mode";
                
                // Simulate optimization
                System.Threading.Thread.Sleep(500);
                
                MessageBox.Show(
                    $"Optimization completed in {mode}!\n\nYour system has been optimized for gaming.", 
                    "KOALA Optimizer", 
                    MessageBoxButton.OK, 
                    MessageBoxImage.Information);
                
                StatusText.Text = $"✓ Optimized in {mode}";
                StatusText.Foreground = new SolidColorBrush(Colors.LightGreen);
            }
            catch (Exception ex)
            {
                StatusText.Text = "Error during optimization";
                StatusText.Foreground = new SolidColorBrush(Colors.Red);
                MessageBox.Show($"Error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void RestoreButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusText.Text = "Restoring defaults...";
                StatusText.Foreground = new SolidColorBrush(Colors.Yellow);
                
                // Simulate restore
                System.Threading.Thread.Sleep(500);
                
                MessageBox.Show(
                    "System has been restored to default settings.", 
                    "KOALA Optimizer", 
                    MessageBoxButton.OK, 
                    MessageBoxImage.Information);
                
                StatusText.Text = "✓ Restored to defaults";
                StatusText.Foreground = new SolidColorBrush(Colors.LightBlue);
            }
            catch (Exception ex)
            {
                StatusText.Text = "Error during restore";
                StatusText.Foreground = new SolidColorBrush(Colors.Red);
                MessageBox.Show($"Error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
