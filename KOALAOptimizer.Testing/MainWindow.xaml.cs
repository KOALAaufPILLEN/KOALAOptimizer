using System;
using System.Windows;
using System.Windows.Media;

namespace KOALAOptimizer
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
        }

        private void OptimizeButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusText.Text = "Optimizing...";
                StatusText.Foreground = new SolidColorBrush(Colors.Yellow);
                
                // Simulate optimization
                bool isSafeMode = SafeModeRadio.IsChecked == true;
                string mode = isSafeMode ? "Safe Mode" : "Performance Mode";
                
                MessageBox.Show($"Optimization in {mode} completed successfully!", 
                               "KOALA Optimizer", 
                               MessageBoxButton.OK, 
                               MessageBoxImage.Information);
                
                StatusText.Text = $"Optimized in {mode}";
                StatusText.Foreground = new SolidColorBrush(Colors.LightGreen);
            }
            catch (Exception ex)
            {
                StatusText.Text = "Error during optimization";
                StatusText.Foreground = new SolidColorBrush(Colors.Red);
                MessageBox.Show($"Error: {ex.Message}", "Error", 
                               MessageBoxButton.OK, 
                               MessageBoxImage.Error);
            }
        }

        private void RestoreButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusText.Text = "Restoring...";
                StatusText.Foreground = new SolidColorBrush(Colors.Yellow);
                
                MessageBox.Show("System restored to defaults!", 
                               "KOALA Optimizer", 
                               MessageBoxButton.OK, 
                               MessageBoxImage.Information);
                
                StatusText.Text = "Restored to defaults";
                StatusText.Foreground = new SolidColorBrush(Colors.LightBlue);
            }
            catch (Exception ex)
            {
                StatusText.Text = "Error during restore";
                StatusText.Foreground = new SolidColorBrush(Colors.Red);
                MessageBox.Show($"Error: {ex.Message}", "Error", 
                               MessageBoxButton.OK, 
                               MessageBoxImage.Error);
            }
        }
    }
}