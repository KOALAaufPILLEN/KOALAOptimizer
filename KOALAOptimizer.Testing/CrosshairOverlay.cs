using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using System.Runtime.InteropServices;
using System.Windows.Interop;

namespace KOALAOptimizer
{
    public class CrosshairOverlay : Window
    {
        private Canvas canvas;
        private DispatcherTimer animationTimer;
        private CrosshairSettings settings;
        
        [DllImport("user32.dll")]
        static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        
        [DllImport("user32.dll")]
        static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
        
        const int GWL_EXSTYLE = -20;
        const int WS_EX_TRANSPARENT = 0x00000020;
        const int WS_EX_LAYERED = 0x00080000;
        
        public CrosshairOverlay(CrosshairSettings settings)
        {
            this.settings = settings;
            InitializeWindow();
            MakeClickThrough();
            
            if (settings.IsDynamic)
            {
                StartAnimation();
            }
        }
        
        private void InitializeWindow()
        {
            WindowStyle = WindowStyle.None;
            AllowsTransparency = true;
            Background = Brushes.Transparent;
            Topmost = true;
            ShowInTaskbar = false;
            Width = SystemParameters.PrimaryScreenWidth;
            Height = SystemParameters.PrimaryScreenHeight;
            Left = 0;
            Top = 0;
            
            canvas = new Canvas();
            Content = canvas;
            
            DrawCrosshair();
        }
        
        private void MakeClickThrough()
        {
            var hwnd = new WindowInteropHelper(this).Handle;
            int extendedStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
            SetWindowLong(hwnd, GWL_EXSTYLE, extendedStyle | WS_EX_TRANSPARENT | WS_EX_LAYERED);
        }
        
        private void DrawCrosshair()
        {
            canvas.Children.Clear();
            
            double centerX = Width / 2;
            double centerY = Height / 2;
            
            switch (settings.Style)
            {
                case CrosshairStyle.ClassicCross:
                    DrawClassicCross(centerX, centerY);
                    break;
                case CrosshairStyle.Dot:
                    DrawDot(centerX, centerY);
                    break;
                case CrosshairStyle.Circle:
                    DrawCircle(centerX, centerY);
                    break;
                case CrosshairStyle.Square:
                    DrawSquare(centerX, centerY);
                    break;
                case CrosshairStyle.TShape:
                    DrawTShape(centerX, centerY);
                    break;
                case CrosshairStyle.Dynamic:
                    DrawDynamicCrosshair(centerX, centerY);
                    break;
                case CrosshairStyle.CSGOStyle:
                    DrawCSGOStyle(centerX, centerY);
                    break;
                case CrosshairStyle.ValorantStyle:
                    DrawValorantStyle(centerX, centerY);
                    break;
                case CrosshairStyle.Custom:
                    DrawCustomCrosshair(centerX, centerY);
                    break;
            }
        }
        
        private void DrawClassicCross(double x, double y)
        {
            var brush = new SolidColorBrush(settings.Color);
            
            // Horizontal lines
            AddLine(x - settings.Size - settings.Gap, y, x - settings.Gap, y, brush);
            AddLine(x + settings.Gap, y, x + settings.Size + settings.Gap, y, brush);
            
            // Vertical lines
            AddLine(x, y - settings.Size - settings.Gap, x, y - settings.Gap, brush);
            AddLine(x, y + settings.Gap, x, y + settings.Size + settings.Gap, brush);
            
            // Center dot if enabled
            if (settings.CenterDot)
            {
                var dot = new Ellipse
                {
                    Width = 2,
                    Height = 2,
                    Fill = brush
                };
                Canvas.SetLeft(dot, x - 1);
                Canvas.SetTop(dot, y - 1);
                canvas.Children.Add(dot);
            }
        }
        
        private void DrawDot(double x, double y)
        {
            var dot = new Ellipse
            {
                Width = settings.Size,
                Height = settings.Size,
                Fill = new SolidColorBrush(settings.Color)
            };
            
            if (settings.HasOutline)
            {
                dot.Stroke = new SolidColorBrush(settings.OutlineColor);
                dot.StrokeThickness = settings.OutlineThickness;
            }
            
            Canvas.SetLeft(dot, x - settings.Size / 2);
            Canvas.SetTop(dot, y - settings.Size / 2);
            canvas.Children.Add(dot);
        }
        
        private void DrawCircle(double x, double y)
        {
            var circle = new Ellipse
            {
                Width = settings.Size * 2,
                Height = settings.Size * 2,
                Stroke = new SolidColorBrush(settings.Color),
                StrokeThickness = settings.Thickness,
                Fill = Brushes.Transparent
            };
            
            Canvas.SetLeft(circle, x - settings.Size);
            Canvas.SetTop(circle, y - settings.Size);
            canvas.Children.Add(circle);
        }
        
        private void DrawSquare(double x, double y)
        {
            var square = new Rectangle
            {
                Width = settings.Size * 2,
                Height = settings.Size * 2,
                Stroke = new SolidColorBrush(settings.Color),
                StrokeThickness = settings.Thickness,
                Fill = Brushes.Transparent
            };
            
            Canvas.SetLeft(square, x - settings.Size);
            Canvas.SetTop(square, y - settings.Size);
            canvas.Children.Add(square);
        }
        
        private void DrawTShape(double x, double y)
        {
            var brush = new SolidColorBrush(settings.Color);
            
            // Top horizontal line
            AddLine(x - settings.Size, y - settings.Size, x + settings.Size, y - settings.Size, brush);
            
            // Vertical line
            AddLine(x, y - settings.Size, x, y + settings.Size, brush);
        }
        
        private void DrawDynamicCrosshair(double x, double y)
        {
            // Dynamic crosshair that expands when moving/shooting
            double dynamicSize = settings.Size + (settings.DynamicExpansion * Math.Sin(DateTime.Now.Millisecond / 1000.0 * Math.PI));
            
            var brush = new SolidColorBrush(settings.Color);
            
            // Animated lines
            AddLine(x - dynamicSize - settings.Gap, y, x - settings.Gap, y, brush);
            AddLine(x + settings.Gap, y, x + dynamicSize + settings.Gap, y, brush);
            AddLine(x, y - dynamicSize - settings.Gap, x, y - settings.Gap, brush);
            AddLine(x, y + settings.Gap, x, y + dynamicSize + settings.Gap, brush);
        }
        
        private void DrawCSGOStyle(double x, double y)
        {
            var brush = new SolidColorBrush(settings.Color);
            
            // CS:GO style with gap and outline
            double lineLength = settings.Size;
            double gap = settings.Gap;
            double thickness = settings.Thickness;
            
            // Draw with outline first
            if (settings.HasOutline)
            {
                var outlineBrush = new SolidColorBrush(Colors.Black);
                AddLine(x - lineLength - gap, y, x - gap, y, outlineBrush, thickness + 2);
                AddLine(x + gap, y, x + lineLength + gap, y, outlineBrush, thickness + 2);
                AddLine(x, y - lineLength - gap, x, y - gap, outlineBrush, thickness + 2);
                AddLine(x, y + gap, x, y + lineLength + gap, outlineBrush, thickness + 2);
            }
            
            // Main crosshair
            AddLine(x - lineLength - gap, y, x - gap, y, brush, thickness);
            AddLine(x + gap, y, x + lineLength + gap, y, brush, thickness);
            AddLine(x, y - lineLength - gap, x, y - gap, brush, thickness);
            AddLine(x, y + gap, x, y + lineLength + gap, brush, thickness);
        }
        
        private void DrawValorantStyle(double x, double y)
        {
            var brush = new SolidColorBrush(settings.Color);
            
            // Valorant style - smaller with center lines
            double innerSize = settings.Size * 0.6;
            double outerSize = settings.Size;
            
            // Inner cross
            AddLine(x - innerSize, y, x - settings.Gap, y, brush);
            AddLine(x + settings.Gap, y, x + innerSize, y, brush);
            AddLine(x, y - innerSize, x, y - settings.Gap, brush);
            AddLine(x, y + settings.Gap, x, y + innerSize, brush);
            
            // Outer markers
            AddLine(x - outerSize - 5, y, x - outerSize, y, brush);
            AddLine(x + outerSize, y, x + outerSize + 5, y, brush);
            AddLine(x, y - outerSize - 5, x, y - outerSize, brush);
            AddLine(x, y + outerSize, x, y + outerSize + 5, brush);
        }
        
        private void DrawCustomCrosshair(double x, double y)
        {
            // Allow for completely custom crosshair patterns
            if (settings.CustomPattern != null)
            {
                foreach (var element in settings.CustomPattern)
                {
                    canvas.Children.Add(element);
                }
            }
        }
        
        private void AddLine(double x1, double y1, double x2, double y2, Brush brush, double thickness = -1)
        {
            var line = new Line
            {
                X1 = x1,
                Y1 = y1,
                X2 = x2,
                Y2 = y2,
                Stroke = brush,
                StrokeThickness = thickness > 0 ? thickness : settings.Thickness,
                StrokeEndLineCap = PenLineCap.Square,
                StrokeStartLineCap = PenLineCap.Square
            };
            
            canvas.Children.Add(line);
        }
        
        private void StartAnimation()
        {
            animationTimer = new DispatcherTimer();
            animationTimer.Interval = TimeSpan.FromMilliseconds(16); // 60 FPS
            animationTimer.Tick += (s, e) => DrawCrosshair();
            animationTimer.Start();
        }
        
        protected override void OnClosed(EventArgs e)
        {
            base.OnClosed(e);
            animationTimer?.Stop();
        }
    }
    
    public class CrosshairSettings
    {
        public CrosshairStyle Style { get; set; }
        public double Size { get; set; }
        public double Thickness { get; set; }
        public double Gap { get; set; }
        public Color Color { get; set; }
        public bool HasOutline { get; set; }
        public Color OutlineColor { get; set; }
        public double OutlineThickness { get; set; }
        public bool CenterDot { get; set; }
        public bool IsDynamic { get; set; }
        public double DynamicExpansion { get; set; }
        public UIElement[] CustomPattern { get; set; }
    }
    
    public enum CrosshairStyle
    {
        ClassicCross,
        Dot,
        Circle,
        Square,
        TShape,
        Dynamic,
        CSGOStyle,
        ValorantStyle,
        Custom
    }
}