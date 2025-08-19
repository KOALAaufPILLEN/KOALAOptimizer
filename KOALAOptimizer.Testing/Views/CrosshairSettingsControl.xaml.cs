using System;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using KOALAOptimizer.Testing.Models;
using KOALAOptimizer.Testing.Services;

namespace KOALAOptimizer.Testing.Views
{
    /// <summary>
    /// Interaction logic for CrosshairSettingsControl.xaml
    /// </summary>
    public partial class CrosshairSettingsControl : UserControl
    {
        private readonly CrosshairOverlayService _crosshairService;
        private readonly LoggingService _logger;
        private bool _isUpdating = false;
        
        public CrosshairSettingsControl()
        {
            InitializeComponent();
            
            _crosshairService = CrosshairOverlayService.Instance;
            _logger = LoggingService.Instance;
            
            InitializeControls();
            LoadCurrentSettings();
            
            // Subscribe to settings changes
            _crosshairService.SettingsChanged += CrosshairService_SettingsChanged;
        }
        
        /// <summary>
        /// Initialize UI controls
        /// </summary>
        private void InitializeControls()
        {
            try
            {
                // Initialize crosshair style combo box
                cmbCrosshairStyle.ItemsSource = Enum.GetValues(typeof(CrosshairStyle)).Cast<CrosshairStyle>();
                cmbCrosshairStyle.SelectedItem = CrosshairStyle.Classic;
                
                // Initialize theme buttons
                InitializeThemeButtons();
                
                // Set up preview
                UpdatePreview();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to initialize crosshair controls: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Initialize theme selection buttons
        /// </summary>
        private void InitializeThemeButtons()
        {
            try
            {
                var themes = _crosshairService.GetPredefinedThemes();
                
                foreach (var theme in themes)
                {
                    var button = new Button
                    {
                        Content = theme.DisplayName,
                        Tag = theme,
                        Margin = new Thickness(2),
                        Height = 35,
                        ToolTip = theme.Description,
                        Style = (Style)FindResource("ModernButtonStyle")
                    };
                    
                    // Set button background to theme color
                    try
                    {
                        var color = (System.Windows.Media.Color)ColorConverter.ConvertFromString(theme.HexColor);
                        button.Background = new SolidColorBrush(color);
                        button.Foreground = GetContrastColor(color);
                    }
                    catch
                    {
                        // Use default colors if conversion fails
                        button.Background = new SolidColorBrush(Colors.Gray);
                    }
                    
                    button.Click += ThemeButton_Click;
                    ThemeGrid.Children.Add(button);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to initialize theme buttons: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get contrasting text color for background
        /// </summary>
        private Brush GetContrastColor(System.Windows.Media.Color backgroundColor)
        {
            // Calculate luminance
            var luminance = (0.299 * backgroundColor.R + 0.587 * backgroundColor.G + 0.114 * backgroundColor.B) / 255;
            return luminance > 0.5 ? Brushes.Black : Brushes.White;
        }
        
        /// <summary>
        /// Load current crosshair settings
        /// </summary>
        private void LoadCurrentSettings()
        {
            try
            {
                _isUpdating = true;
                
                var settings = _crosshairService.CurrentSettings;
                if (settings != null)
                {
                    chkEnableCrosshair.IsChecked = settings.IsEnabled;
                    cmbCrosshairStyle.SelectedItem = settings.Style;
                    sliderSize.Value = settings.Size;
                    sliderThickness.Value = settings.Thickness;
                    sliderRed.Value = settings.Red;
                    sliderGreen.Value = settings.Green;
                    sliderBlue.Value = settings.Blue;
                    sliderOpacity.Value = settings.Opacity;
                    txtHexColor.Text = settings.HexColor;
                    
                    UpdateColorPreview();
                    UpdatePreview();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to load crosshair settings: {ex.Message}", ex);
            }
            finally
            {
                _isUpdating = false;
            }
        }
        
        /// <summary>
        /// Handle crosshair service settings changed
        /// </summary>
        private void CrosshairService_SettingsChanged(object sender, CrosshairSettings settings)
        {
            Dispatcher.Invoke(() => LoadCurrentSettings());
        }
        
        /// <summary>
        /// Handle enable crosshair checked
        /// </summary>
        private void EnableCrosshair_Checked(object sender, RoutedEventArgs e)
        {
            if (!_isUpdating)
            {
                _crosshairService.SetEnabled(true);
                _logger.LogInfo("Crosshair overlay enabled via UI");
            }
        }
        
        /// <summary>
        /// Handle enable crosshair unchecked
        /// </summary>
        private void EnableCrosshair_Unchecked(object sender, RoutedEventArgs e)
        {
            if (!_isUpdating)
            {
                _crosshairService.SetEnabled(false);
                _logger.LogInfo("Crosshair overlay disabled via UI");
            }
        }
        
        /// <summary>
        /// Handle theme button click
        /// </summary>
        private void ThemeButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (sender is Button button && button.Tag is CrosshairTheme theme)
                {
                    _crosshairService.ApplyTheme(theme);
                    _logger.LogInfo($"Applied crosshair theme: {theme.DisplayName}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply crosshair theme: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Handle crosshair style selection changed
        /// </summary>
        private void CrosshairStyle_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (!_isUpdating && cmbCrosshairStyle.SelectedItem is CrosshairStyle style)
            {
                UpdateSettingsFromUI();
            }
        }
        
        /// <summary>
        /// Handle size value changed
        /// </summary>
        private void Size_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            if (!_isUpdating)
            {
                UpdateSettingsFromUI();
                UpdatePreview();
            }
        }
        
        /// <summary>
        /// Handle thickness value changed
        /// </summary>
        private void Thickness_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            if (!_isUpdating)
            {
                UpdateSettingsFromUI();
                UpdatePreview();
            }
        }
        
        /// <summary>
        /// Handle color value changed
        /// </summary>
        private void Color_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            if (!_isUpdating)
            {
                UpdateHexFromRGB();
                UpdateColorPreview();
                UpdateSettingsFromUI();
                UpdatePreview();
            }
        }
        
        /// <summary>
        /// Handle opacity value changed
        /// </summary>
        private void Opacity_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            if (!_isUpdating)
            {
                UpdateSettingsFromUI();
                UpdatePreview();
            }
        }
        
        /// <summary>
        /// Handle hex color text changed
        /// </summary>
        private void HexColor_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (!_isUpdating && sender is TextBox textBox)
            {
                UpdateRGBFromHex(textBox.Text);
                UpdateColorPreview();
                UpdateSettingsFromUI();
                UpdatePreview();
            }
        }
        
        /// <summary>
        /// Update RGB sliders from hex color
        /// </summary>
        private void UpdateRGBFromHex(string hexColor)
        {
            try
            {
                if (hexColor.StartsWith("#") && hexColor.Length == 7)
                {
                    _isUpdating = true;
                    
                    var color = (System.Windows.Media.Color)ColorConverter.ConvertFromString(hexColor);
                    sliderRed.Value = color.R;
                    sliderGreen.Value = color.G;
                    sliderBlue.Value = color.B;
                }
            }
            catch
            {
                // Invalid hex color, ignore
            }
            finally
            {
                _isUpdating = false;
            }
        }
        
        /// <summary>
        /// Update hex color from RGB sliders
        /// </summary>
        private void UpdateHexFromRGB()
        {
            try
            {
                _isUpdating = true;
                
                var r = (byte)sliderRed.Value;
                var g = (byte)sliderGreen.Value;
                var b = (byte)sliderBlue.Value;
                
                txtHexColor.Text = $"#{r:X2}{g:X2}{b:X2}";
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to update hex color: {ex.Message}", ex);
            }
            finally
            {
                _isUpdating = false;
            }
        }
        
        /// <summary>
        /// Update color preview button
        /// </summary>
        private void UpdateColorPreview()
        {
            try
            {
                var r = (byte)sliderRed.Value;
                var g = (byte)sliderGreen.Value;
                var b = (byte)sliderBlue.Value;
                
                var color = System.Windows.Media.Color.FromRgb(r, g, b);
                btnColorPreview.Background = new SolidColorBrush(color);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to update color preview: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Update settings from UI controls
        /// </summary>
        private void UpdateSettingsFromUI()
        {
            try
            {
                if (_isUpdating) return;
                
                var settings = new CrosshairSettings
                {
                    IsEnabled = chkEnableCrosshair.IsChecked ?? false,
                    Style = (CrosshairStyle)(cmbCrosshairStyle.SelectedItem ?? CrosshairStyle.Classic),
                    Size = (int)sliderSize.Value,
                    Thickness = (int)sliderThickness.Value,
                    Red = (int)sliderRed.Value,
                    Green = (int)sliderGreen.Value,
                    Blue = (int)sliderBlue.Value,
                    Alpha = 255,
                    HexColor = txtHexColor.Text,
                    Opacity = sliderOpacity.Value,
                    SelectedTheme = "Custom",
                    ShowOnlyInGames = false,
                    HotkeyToggle = "F1"
                };
                
                _crosshairService.UpdateSettings(settings);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to update crosshair settings from UI: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Update live preview
        /// </summary>
        private void UpdatePreview()
        {
            try
            {
                // Clear existing preview
                PreviewCanvas.Children.Clear();
                
                var settings = new CrosshairSettings
                {
                    Style = (CrosshairStyle)(cmbCrosshairStyle.SelectedItem ?? CrosshairStyle.Classic),
                    Size = (int)(sliderSize?.Value ?? 20),
                    Thickness = (int)(sliderThickness?.Value ?? 2),
                    Red = (int)(sliderRed?.Value ?? 0),
                    Green = (int)(sliderGreen?.Value ?? 255),
                    Blue = (int)(sliderBlue?.Value ?? 0),
                    Alpha = 255,
                    Opacity = sliderOpacity?.Value ?? 1.0
                };
                
                DrawPreviewCrosshair(settings);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to update crosshair preview: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Draw crosshair preview
        /// </summary>
        private void DrawPreviewCrosshair(CrosshairSettings settings)
        {
            var color = System.Windows.Media.Color.FromArgb((byte)settings.Alpha, (byte)settings.Red, (byte)settings.Green, (byte)settings.Blue);
            var brush = new SolidColorBrush(color);
            
            var centerX = PreviewCanvas.Width / 2;
            var centerY = PreviewCanvas.Height / 2;
            
            // Scale down for preview
            var previewSize = Math.Min(settings.Size * 0.8, 30);
            var previewThickness = Math.Max(settings.Thickness * 0.5, 1);
            
            switch (settings.Style)
            {
                case CrosshairStyle.Classic:
                    // Horizontal line
                    var hLine = new Rectangle
                    {
                        Width = previewSize * 2,
                        Height = previewThickness,
                        Fill = brush
                    };
                    Canvas.SetLeft(hLine, centerX - hLine.Width / 2);
                    Canvas.SetTop(hLine, centerY - hLine.Height / 2);
                    PreviewCanvas.Children.Add(hLine);
                    
                    // Vertical line
                    var vLine = new Rectangle
                    {
                        Width = previewThickness,
                        Height = previewSize * 2,
                        Fill = brush
                    };
                    Canvas.SetLeft(vLine, centerX - vLine.Width / 2);
                    Canvas.SetTop(vLine, centerY - vLine.Height / 2);
                    PreviewCanvas.Children.Add(vLine);
                    break;
                    
                case CrosshairStyle.Dot:
                    var dot = new Ellipse
                    {
                        Width = previewSize / 3,
                        Height = previewSize / 3,
                        Fill = brush
                    };
                    Canvas.SetLeft(dot, centerX - dot.Width / 2);
                    Canvas.SetTop(dot, centerY - dot.Height / 2);
                    PreviewCanvas.Children.Add(dot);
                    break;
                    
                case CrosshairStyle.Circle:
                    var circle = new Ellipse
                    {
                        Width = previewSize * 1.5,
                        Height = previewSize * 1.5,
                        Stroke = brush,
                        StrokeThickness = previewThickness,
                        Fill = Brushes.Transparent
                    };
                    Canvas.SetLeft(circle, centerX - circle.Width / 2);
                    Canvas.SetTop(circle, centerY - circle.Height / 2);
                    PreviewCanvas.Children.Add(circle);
                    break;
                    
                // Add other styles as needed
            }
        }
        
        /// <summary>
        /// Handle reset to defaults button click
        /// </summary>
        private void ResetToDefaults_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var defaultTheme = _crosshairService.GetPredefinedThemes().FirstOrDefault(t => t.Name == "ClassicGreen");
                if (defaultTheme != null)
                {
                    _crosshairService.ApplyTheme(defaultTheme);
                    _logger.LogInfo("Crosshair settings reset to defaults");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to reset crosshair settings: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Handle test crosshair button click
        /// </summary>
        private void TestCrosshair_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Temporarily enable crosshair for 5 seconds
                var wasEnabled = chkEnableCrosshair.IsChecked ?? false;
                
                _crosshairService.SetEnabled(true);
                _logger.LogInfo("Testing crosshair for 5 seconds...");
                
                // Auto-disable after 5 seconds if it wasn't enabled before
                if (!wasEnabled)
                {
                    var timer = new System.Windows.Threading.DispatcherTimer
                    {
                        Interval = TimeSpan.FromSeconds(5)
                    };
                    timer.Tick += (s, args) =>
                    {
                        timer.Stop();
                        _crosshairService.SetEnabled(false);
                        _logger.LogInfo("Crosshair test completed");
                    };
                    timer.Start();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to test crosshair: {ex.Message}", ex);
            }
        }
    }
}