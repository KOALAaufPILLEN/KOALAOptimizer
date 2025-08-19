using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Runtime.InteropServices;
using KOALAOptimizer.Testing.Models;
using KOALAOptimizer.Testing.Views;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for managing crosshair overlay functionality
    /// </summary>
    public class CrosshairOverlayService
    {
        private static readonly Lazy<CrosshairOverlayService> _instance = new Lazy<CrosshairOverlayService>(() => new CrosshairOverlayService());
        public static CrosshairOverlayService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly List<CrosshairTheme> _predefinedThemes;
        private CrosshairWindow _overlayWindow;
        private CrosshairSettings _settings;
        private string _settingsFilePath;
        
        // Win32 API for global hotkeys
        [DllImport("user32.dll")]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
        
        [DllImport("user32.dll")]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
        
        private const int HOTKEY_ID = 9000;
        private const uint VK_F1 = 0x70;
        private IntPtr _windowHandle = IntPtr.Zero;
        
        public event EventHandler<CrosshairSettings> SettingsChanged;
        
        private CrosshairOverlayService()
        {
            _logger = LoggingService.Instance;
            _predefinedThemes = InitializePredefinedThemes();
            _settingsFilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), 
                                           "KOALAOptimizer", "crosshair_settings.txt");
            
            // Create directory if it doesn't exist
            Directory.CreateDirectory(Path.GetDirectoryName(_settingsFilePath));
            
            // Load or create default settings
            LoadSettings();
            
            _logger.LogInfo("Crosshair overlay service initialized");
        }
        
        /// <summary>
        /// Initialize predefined crosshair themes
        /// </summary>
        private List<CrosshairTheme> InitializePredefinedThemes()
        {
            return new List<CrosshairTheme>
            {
                new CrosshairTheme
                {
                    Name = "ClassicGreen",
                    DisplayName = "Classic Green",
                    HexColor = "#00FF00",
                    Red = 0, Green = 255, Blue = 0,
                    Style = CrosshairStyle.Classic,
                    Size = 20,
                    Thickness = 2,
                    Description = "Traditional FPS crosshair"
                },
                new CrosshairTheme
                {
                    Name = "NeonPink",
                    DisplayName = "Neon Pink",
                    HexColor = "#FF1493",
                    Red = 255, Green = 20, Blue = 147,
                    Style = CrosshairStyle.Classic,
                    Size = 20,
                    Thickness = 2,
                    Description = "Bright gaming theme"
                },
                new CrosshairTheme
                {
                    Name = "ElectricBlue",
                    DisplayName = "Electric Blue",
                    HexColor = "#00BFFF",
                    Red = 0, Green = 191, Blue = 255,
                    Style = CrosshairStyle.Classic,
                    Size = 20,
                    Thickness = 2,
                    Description = "Cool gaming aesthetic"
                },
                new CrosshairTheme
                {
                    Name = "FireOrange",
                    DisplayName = "Fire Orange",
                    HexColor = "#FF4500",
                    Red = 255, Green = 69, Blue = 0,
                    Style = CrosshairStyle.Classic,
                    Size = 20,
                    Thickness = 2,
                    Description = "Warm gaming theme"
                },
                new CrosshairTheme
                {
                    Name = "PurpleGaming",
                    DisplayName = "Purple Gaming",
                    HexColor = "#8A2BE2",
                    Red = 138, Green = 43, Blue = 226,
                    Style = CrosshairStyle.Classic,
                    Size = 20,
                    Thickness = 2,
                    Description = "RGB gaming style"
                },
                new CrosshairTheme
                {
                    Name = "MatrixGreen",
                    DisplayName = "Matrix Green",
                    HexColor = "#00FF41",
                    Red = 0, Green = 255, Blue = 65,
                    Style = CrosshairStyle.Dot,
                    Size = 15,
                    Thickness = 3,
                    Description = "Matrix/hacker theme"
                },
                new CrosshairTheme
                {
                    Name = "BloodRed",
                    DisplayName = "Blood Red",
                    HexColor = "#DC143C",
                    Red = 220, Green = 20, Blue = 60,
                    Style = CrosshairStyle.Cross,
                    Size = 25,
                    Thickness = 3,
                    Description = "Aggressive gaming"
                },
                new CrosshairTheme
                {
                    Name = "GoldPro",
                    DisplayName = "Gold Pro",
                    HexColor = "#FFD700",
                    Red = 255, Green = 215, Blue = 0,
                    Style = CrosshairStyle.Plus,
                    Size = 18,
                    Thickness = 2,
                    Description = "Professional esports"
                },
                new CrosshairTheme
                {
                    Name = "IceBlue",
                    DisplayName = "Ice Blue",
                    HexColor = "#B0E0E6",
                    Red = 176, Green = 224, Blue = 230,
                    Style = CrosshairStyle.Circle,
                    Size = 16,
                    Thickness = 2,
                    Description = "Cool professional"
                },
                new CrosshairTheme
                {
                    Name = "ShadowGray",
                    DisplayName = "Shadow Gray",
                    HexColor = "#696969",
                    Red = 105, Green = 105, Blue = 105,
                    Style = CrosshairStyle.TShape,
                    Size = 22,
                    Thickness = 2,
                    Description = "Subtle/stealth"
                }
            };
        }
        
        /// <summary>
        /// Get available predefined themes
        /// </summary>
        public List<CrosshairTheme> GetPredefinedThemes()
        {
            return _predefinedThemes.ToList();
        }
        
        /// <summary>
        /// Get current crosshair settings
        /// </summary>
        public CrosshairSettings CurrentSettings => _settings;
        
        /// <summary>
        /// Apply crosshair theme
        /// </summary>
        public void ApplyTheme(CrosshairTheme theme)
        {
            if (theme == null) return;
            
            _settings.Red = theme.Red;
            _settings.Green = theme.Green;
            _settings.Blue = theme.Blue;
            _settings.Alpha = theme.Alpha;
            _settings.HexColor = theme.HexColor;
            _settings.Style = theme.Style;
            _settings.Size = theme.Size;
            _settings.Thickness = theme.Thickness;
            _settings.SelectedTheme = theme.DisplayName;
            
            UpdateOverlay();
            SaveSettings();
            SettingsChanged?.Invoke(this, _settings);
            
            _logger.LogInfo($"Applied crosshair theme: {theme.DisplayName}");
        }
        
        /// <summary>
        /// Update crosshair settings
        /// </summary>
        public void UpdateSettings(CrosshairSettings newSettings)
        {
            if (newSettings == null) return;
            
            _settings = newSettings;
            UpdateOverlay();
            SaveSettings();
            SettingsChanged?.Invoke(this, _settings);
        }
        
        /// <summary>
        /// Enable/disable crosshair overlay
        /// </summary>
        public void SetEnabled(bool enabled)
        {
            _settings.IsEnabled = enabled;
            
            if (enabled)
            {
                ShowOverlay();
            }
            else
            {
                HideOverlay();
            }
            
            SaveSettings();
            SettingsChanged?.Invoke(this, _settings);
            
            _logger.LogInfo($"Crosshair overlay {(enabled ? "enabled" : "disabled")}");
        }
        
        /// <summary>
        /// Toggle crosshair overlay
        /// </summary>
        public void ToggleOverlay()
        {
            SetEnabled(!_settings.IsEnabled);
        }
        
        /// <summary>
        /// Show crosshair overlay
        /// </summary>
        private void ShowOverlay()
        {
            try
            {
                if (_overlayWindow == null)
                {
                    _overlayWindow = new CrosshairWindow();
                    _overlayWindow.UpdateCrosshair(_settings);
                }
                
                if (!_overlayWindow.IsVisible)
                {
                    _overlayWindow.Show();
                }
                
                _overlayWindow.UpdateCrosshair(_settings);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to show crosshair overlay: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Hide crosshair overlay
        /// </summary>
        private void HideOverlay()
        {
            try
            {
                if (_overlayWindow != null && _overlayWindow.IsVisible)
                {
                    _overlayWindow.Hide();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to hide crosshair overlay: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Update overlay with current settings
        /// </summary>
        private void UpdateOverlay()
        {
            if (_settings.IsEnabled && _overlayWindow != null)
            {
                _overlayWindow.UpdateCrosshair(_settings);
            }
        }
        
        /// <summary>
        /// Initialize hotkey support
        /// </summary>
        public void InitializeHotkey(IntPtr windowHandle)
        {
            _windowHandle = windowHandle;
            RegisterGlobalHotkey();
        }
        
        /// <summary>
        /// Register global hotkey
        /// </summary>
        private void RegisterGlobalHotkey()
        {
            try
            {
                if (_windowHandle != IntPtr.Zero)
                {
                    RegisterHotKey(_windowHandle, HOTKEY_ID, 0, VK_F1);
                    _logger.LogInfo("Crosshair hotkey (F1) registered");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to register crosshair hotkey: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Handle hotkey message
        /// </summary>
        public void HandleHotkey(int hotkeyId)
        {
            if (hotkeyId == HOTKEY_ID)
            {
                ToggleOverlay();
            }
        }
        
        /// <summary>
        /// Load crosshair settings from file
        /// </summary>
        private void LoadSettings()
        {
            try
            {
                if (File.Exists(_settingsFilePath))
                {
                    var lines = File.ReadAllLines(_settingsFilePath);
                    _settings = DeserializeSettings(lines);
                    _logger.LogInfo("Crosshair settings loaded from file");
                }
                else
                {
                    _settings = CreateDefaultSettings();
                    SaveSettings();
                    _logger.LogInfo("Default crosshair settings created");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to load crosshair settings: {ex.Message}", ex);
                _settings = CreateDefaultSettings();
            }
        }
        
        /// <summary>
        /// Save crosshair settings to file
        /// </summary>
        private void SaveSettings()
        {
            try
            {
                var lines = SerializeSettings(_settings);
                File.WriteAllLines(_settingsFilePath, lines);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to save crosshair settings: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Create default crosshair settings
        /// </summary>
        private CrosshairSettings CreateDefaultSettings()
        {
            return new CrosshairSettings
            {
                IsEnabled = false,
                Style = CrosshairStyle.Classic,
                Size = 20,
                Thickness = 2,
                Red = 0,
                Green = 255,
                Blue = 0,
                Alpha = 255,
                HexColor = "#00FF00",
                Opacity = 1.0,
                SelectedTheme = "Classic Green",
                ShowOnlyInGames = false,
                HotkeyToggle = "F1"
            };
        }
        
        /// <summary>
        /// Serialize settings to text format
        /// </summary>
        private string[] SerializeSettings(CrosshairSettings settings)
        {
            return new string[]
            {
                $"IsEnabled={settings.IsEnabled}",
                $"Style={settings.Style}",
                $"Size={settings.Size}",
                $"Thickness={settings.Thickness}",
                $"Red={settings.Red}",
                $"Green={settings.Green}",
                $"Blue={settings.Blue}",
                $"Alpha={settings.Alpha}",
                $"HexColor={settings.HexColor}",
                $"Opacity={settings.Opacity}",
                $"SelectedTheme={settings.SelectedTheme}",
                $"ShowOnlyInGames={settings.ShowOnlyInGames}",
                $"HotkeyToggle={settings.HotkeyToggle}"
            };
        }
        
        /// <summary>
        /// Deserialize settings from text format
        /// </summary>
        private CrosshairSettings DeserializeSettings(string[] lines)
        {
            var settings = CreateDefaultSettings();
            
            foreach (var line in lines)
            {
                var parts = line.Split('=');
                if (parts.Length != 2) continue;
                
                var key = parts[0].Trim();
                var value = parts[1].Trim();
                
                switch (key)
                {
                    case "IsEnabled":
                        bool.TryParse(value, out bool isEnabled);
                        settings.IsEnabled = isEnabled;
                        break;
                    case "Style":
                        Enum.TryParse(value, out CrosshairStyle style);
                        settings.Style = style;
                        break;
                    case "Size":
                        int.TryParse(value, out int size);
                        settings.Size = size;
                        break;
                    case "Thickness":
                        int.TryParse(value, out int thickness);
                        settings.Thickness = thickness;
                        break;
                    case "Red":
                        int.TryParse(value, out int red);
                        settings.Red = red;
                        break;
                    case "Green":
                        int.TryParse(value, out int green);
                        settings.Green = green;
                        break;
                    case "Blue":
                        int.TryParse(value, out int blue);
                        settings.Blue = blue;
                        break;
                    case "Alpha":
                        int.TryParse(value, out int alpha);
                        settings.Alpha = alpha;
                        break;
                    case "HexColor":
                        settings.HexColor = value;
                        break;
                    case "Opacity":
                        double.TryParse(value, out double opacity);
                        settings.Opacity = opacity;
                        break;
                    case "SelectedTheme":
                        settings.SelectedTheme = value;
                        break;
                    case "ShowOnlyInGames":
                        bool.TryParse(value, out bool showOnlyInGames);
                        settings.ShowOnlyInGames = showOnlyInGames;
                        break;
                    case "HotkeyToggle":
                        settings.HotkeyToggle = value;
                        break;
                }
            }
            
            return settings;
        }
        
        /// <summary>
        /// Cleanup resources
        /// </summary>
        public void Dispose()
        {
            try
            {
                // Unregister hotkey
                if (_windowHandle != IntPtr.Zero)
                {
                    UnregisterHotKey(_windowHandle, HOTKEY_ID);
                }
                
                // Close overlay window
                if (_overlayWindow != null)
                {
                    _overlayWindow.Close();
                    _overlayWindow = null;
                }
                
                _logger.LogInfo("Crosshair overlay service disposed");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error disposing crosshair overlay service: {ex.Message}", ex);
            }
        }
    }
}