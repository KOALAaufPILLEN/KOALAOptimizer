using System;
using System.Drawing;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Forms;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Views
{
    /// <summary>
    /// Interaction logic for CrosshairWindow.xaml
    /// </summary>
    public partial class CrosshairWindow : Window
    {
        public CrosshairWindow()
        {
            InitializeComponent();
            
            // Position window at center of primary screen
            PositionAtScreenCenter();
            
            // Ensure window is always on top and click-through
            this.Topmost = true;
            this.IsHitTestVisible = false;
        }
        
        /// <summary>
        /// Position the crosshair at the center of the primary screen
        /// </summary>
        private void PositionAtScreenCenter()
        {
            try
            {
                var primaryScreen = Screen.PrimaryScreen;
                var screenBounds = primaryScreen.Bounds;
                
                // Convert screen coordinates to WPF coordinates
                var dpiX = VisualTreeHelper.GetDpi(this).DpiScaleX;
                var dpiY = VisualTreeHelper.GetDpi(this).DpiScaleY;
                
                var screenWidth = screenBounds.Width / dpiX;
                var screenHeight = screenBounds.Height / dpiY;
                
                // Position at center
                this.Left = (screenWidth - this.Width) / 2;
                this.Top = (screenHeight - this.Height) / 2;
            }
            catch (Exception)
            {
                // Fallback to system parameters if screen detection fails
                this.Left = (SystemParameters.PrimaryScreenWidth - this.Width) / 2;
                this.Top = (SystemParameters.PrimaryScreenHeight - this.Height) / 2;
            }
        }
        
        /// <summary>
        /// Update crosshair appearance based on settings
        /// </summary>
        public void UpdateCrosshair(CrosshairSettings settings)
        {
            if (settings == null) return;
            
            try
            {
                // Hide all crosshair shapes first
                HideAllShapes();
                
                // Create brush from settings
                var color = System.Windows.Media.Color.FromArgb((byte)settings.Alpha, (byte)settings.Red, (byte)settings.Green, (byte)settings.Blue);
                var brush = new SolidColorBrush(color);
                
                // Show and configure the appropriate shape
                switch (settings.Style)
                {
                    case CrosshairStyle.Classic:
                        ConfigureClassicCross(brush, settings);
                        break;
                    case CrosshairStyle.Dot:
                        ConfigureDot(brush, settings);
                        break;
                    case CrosshairStyle.Circle:
                        ConfigureCircle(brush, settings);
                        break;
                    case CrosshairStyle.TShape:
                        ConfigureTShape(brush, settings);
                        break;
                    case CrosshairStyle.Plus:
                        ConfigurePlus(brush, settings);
                        break;
                    case CrosshairStyle.Cross:
                        ConfigureCross(brush, settings);
                        break;
                    default:
                        ConfigureClassicCross(brush, settings);
                        break;
                }
                
                // Update window opacity
                this.Opacity = settings.Opacity;
                
                // Reposition at screen center
                PositionAtScreenCenter();
            }
            catch (Exception ex)
            {
                // Log error if logging service is available
                var logger = Services.LoggingService.Instance;
                logger?.LogError($"Failed to update crosshair: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Hide all crosshair shapes
        /// </summary>
        private void HideAllShapes()
        {
            ClassicCross.Visibility = Visibility.Collapsed;
            DotShape.Visibility = Visibility.Collapsed;
            CircleShape.Visibility = Visibility.Collapsed;
            TShape.Visibility = Visibility.Collapsed;
            PlusShape.Visibility = Visibility.Collapsed;
            CrossShape.Visibility = Visibility.Collapsed;
        }
        
        /// <summary>
        /// Configure classic cross shape
        /// </summary>
        private void ConfigureClassicCross(SolidColorBrush brush, CrosshairSettings settings)
        {
            ClassicCross.Visibility = Visibility.Visible;
            
            // Update horizontal line
            HorizontalLine.Fill = brush;
            HorizontalLine.Width = settings.Size * 2;
            HorizontalLine.Height = settings.Thickness;
            
            // Update vertical line
            VerticalLine.Fill = brush;
            VerticalLine.Width = settings.Thickness;
            VerticalLine.Height = settings.Size * 2;
            
            // Update container size
            ClassicCross.Width = settings.Size * 2 + 10;
            ClassicCross.Height = settings.Size * 2 + 10;
        }
        
        /// <summary>
        /// Configure dot shape
        /// </summary>
        private void ConfigureDot(SolidColorBrush brush, CrosshairSettings settings)
        {
            DotShape.Visibility = Visibility.Visible;
            DotShape.Fill = brush;
            DotShape.Width = settings.Size / 3;
            DotShape.Height = settings.Size / 3;
            
            // Center the dot
            var canvasCenter = CrosshairCanvas.Width / 2;
            System.Windows.Controls.Canvas.SetLeft(DotShape, canvasCenter - DotShape.Width / 2);
            System.Windows.Controls.Canvas.SetTop(DotShape, canvasCenter - DotShape.Height / 2);
        }
        
        /// <summary>
        /// Configure circle shape
        /// </summary>
        private void ConfigureCircle(SolidColorBrush brush, CrosshairSettings settings)
        {
            CircleShape.Visibility = Visibility.Visible;
            CircleShape.Stroke = brush;
            CircleShape.StrokeThickness = settings.Thickness;
            CircleShape.Width = settings.Size * 1.5;
            CircleShape.Height = settings.Size * 1.5;
            
            // Center the circle
            var canvasCenter = CrosshairCanvas.Width / 2;
            System.Windows.Controls.Canvas.SetLeft(CircleShape, canvasCenter - CircleShape.Width / 2);
            System.Windows.Controls.Canvas.SetTop(CircleShape, canvasCenter - CircleShape.Height / 2);
        }
        
        /// <summary>
        /// Configure T-shape
        /// </summary>
        private void ConfigureTShape(SolidColorBrush brush, CrosshairSettings settings)
        {
            TShape.Visibility = Visibility.Visible;
            
            // Update horizontal line
            TShapeHorizontal.Fill = brush;
            TShapeHorizontal.Width = settings.Size * 1.5;
            TShapeHorizontal.Height = settings.Thickness;
            
            // Update vertical line
            TShapeVertical.Fill = brush;
            TShapeVertical.Width = settings.Thickness;
            TShapeVertical.Height = settings.Size * 1.5;
            
            // Update container size
            TShape.Width = settings.Size * 2;
            TShape.Height = settings.Size * 2;
        }
        
        /// <summary>
        /// Configure plus shape
        /// </summary>
        private void ConfigurePlus(SolidColorBrush brush, CrosshairSettings settings)
        {
            PlusShape.Visibility = Visibility.Visible;
            
            // Update horizontal line
            PlusHorizontal.Fill = brush;
            PlusHorizontal.Width = settings.Size * 1.25;
            PlusHorizontal.Height = settings.Thickness;
            
            // Update vertical line
            PlusVertical.Fill = brush;
            PlusVertical.Width = settings.Thickness;
            PlusVertical.Height = settings.Size * 1.25;
            
            // Update container size
            PlusShape.Width = settings.Size * 1.5;
            PlusShape.Height = settings.Size * 1.5;
        }
        
        /// <summary>
        /// Configure cross (X) shape
        /// </summary>
        private void ConfigureCross(SolidColorBrush brush, CrosshairSettings settings)
        {
            CrossShape.Visibility = Visibility.Visible;
            
            // Update diagonal lines
            CrossDiagonal1.Fill = brush;
            CrossDiagonal1.Width = settings.Thickness;
            CrossDiagonal1.Height = settings.Size * 1.75;
            
            CrossDiagonal2.Fill = brush;
            CrossDiagonal2.Width = settings.Thickness;
            CrossDiagonal2.Height = settings.Size * 1.75;
            
            // Update container size
            CrossShape.Width = settings.Size * 2;
            CrossShape.Height = settings.Size * 2;
        }
    }
}