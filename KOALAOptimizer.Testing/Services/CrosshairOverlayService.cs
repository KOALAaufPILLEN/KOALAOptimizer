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
            try
            {
                LoggingService.EmergencyLog("CrosshairOverlayService: Initializing...");
                
                _logger = LoggingService.Instance;
                LoggingService.EmergencyLog("CrosshairOverlayService: LoggingService obtained");
                
                _predefinedThemes = InitializePredefinedThemes();
                LoggingService.EmergencyLog("CrosshairOverlayService: Predefined themes initialized");
                
                try
                {
                    _settingsFilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), 
                                                   "KOALAOptimizer", "crosshair_settings.txt");
                    
                    // Create directory if it doesn't exist
                    Directory.CreateDirectory(Path.GetDirectoryName(_settingsFilePath));
                    LoggingService.EmergencyLog($"CrosshairOverlayService: Settings directory created at {Path.GetDirectoryName(_settingsFilePath)}");
                }
                catch (Exception dirEx)
                {
                    _logger?.LogError($"Failed to create crosshair settings directory: {dirEx.Message}", dirEx);
                    // Fallback to temp directory
                    _settingsFilePath = Path.Combine(Path.GetTempPath(), "crosshair_settings.txt");
                    LoggingService.EmergencyLog($"CrosshairOverlayService: Using fallback settings path: {_settingsFilePath}");
                }
                
                // Load or create default settings
                try
                {
                    LoadSettings();
                    LoggingService.EmergencyLog("CrosshairOverlayService: Settings loaded successfully");
                }
                catch (Exception settingsEx)
                {
                    _logger?.LogError($"Failed to load crosshair settings: {settingsEx.Message}", settingsEx);
                    LoggingService.EmergencyLog($"CrosshairOverlayService: Settings load failed, using defaults");
                    // Create default settings if loading fails
                    _settings = new CrosshairSettings();
                }
                
                _logger?.LogInfo("Crosshair overlay service initialized");
                LoggingService.EmergencyLog("CrosshairOverlayService: Initialization completed successfully");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"CrosshairOverlayService: CRITICAL - Initialization failed: {ex.Message}");
                _logger?.LogError($"Critical error initializing CrosshairOverlayService: {ex.Message}", ex);
                // Don't rethrow - allow app to continue without crosshair functionality
            }
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
        
        /// <summary>
        /// Save current settings as a named profile
        /// </summary>
        public bool SaveProfile(string profileName)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(profileName))
                {
                    _logger.LogWarning("Cannot save profile with empty name");
                    return false;
                }
                
                // Validate profile name
                var adminService = AdminService.Instance;
                var validation = adminService.ValidateInput(profileName, InputType.General);
                if (!validation.IsValid)
                {
                    _logger.LogWarning($"Invalid profile name: {string.Join(", ", validation.Issues)}");
                    return false;
                }
                
                var profileDir = Path.Combine(Path.GetDirectoryName(_settingsFilePath), "Profiles");
                Directory.CreateDirectory(profileDir);
                
                var profilePath = Path.Combine(profileDir, $"{validation.SanitizedInput}.profile");
                var lines = SerializeSettings(_settings);
                
                // Add profile metadata
                var profileData = new List<string>
                {
                    $"ProfileName={validation.SanitizedInput}",
                    $"CreatedDate={DateTime.Now:yyyy-MM-dd HH:mm:ss}",
                    $"Version=2.3.0",
                    "---SETTINGS---"
                };
                profileData.AddRange(lines);
                
                File.WriteAllLines(profilePath, profileData);
                _logger.LogInfo($"Crosshair profile saved: {validation.SanitizedInput}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to save crosshair profile '{profileName}': {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Load a named profile
        /// </summary>
        public bool LoadProfile(string profileName)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(profileName))
                    return false;
                
                var profileDir = Path.Combine(Path.GetDirectoryName(_settingsFilePath), "Profiles");
                var profilePath = Path.Combine(profileDir, $"{profileName}.profile");
                
                if (!File.Exists(profilePath))
                {
                    _logger.LogWarning($"Crosshair profile not found: {profileName}");
                    return false;
                }
                
                var lines = File.ReadAllLines(profilePath);
                var settingsStartIndex = Array.IndexOf(lines, "---SETTINGS---");
                
                if (settingsStartIndex == -1 || settingsStartIndex >= lines.Length - 1)
                {
                    _logger.LogError($"Invalid profile format: {profileName}");
                    return false;
                }
                
                var settingsLines = lines.Skip(settingsStartIndex + 1).ToArray();
                var loadedSettings = DeserializeSettings(settingsLines);
                
                UpdateSettings(loadedSettings);
                _logger.LogInfo($"Crosshair profile loaded: {profileName}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to load crosshair profile '{profileName}': {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Get list of available profiles
        /// </summary>
        public List<CrosshairProfile> GetAvailableProfiles()
        {
            try
            {
                var profiles = new List<CrosshairProfile>();
                var profileDir = Path.Combine(Path.GetDirectoryName(_settingsFilePath), "Profiles");
                
                if (!Directory.Exists(profileDir))
                    return profiles;
                
                var profileFiles = Directory.GetFiles(profileDir, "*.profile");
                
                foreach (var file in profileFiles)
                {
                    try
                    {
                        var lines = File.ReadAllLines(file);
                        var profile = new CrosshairProfile
                        {
                            Name = Path.GetFileNameWithoutExtension(file),
                            FilePath = file,
                            LastModified = File.GetLastWriteTime(file)
                        };
                        
                        // Parse metadata
                        foreach (var line in lines)
                        {
                            if (line == "---SETTINGS---") break;
                            
                            var parts = line.Split('=');
                            if (parts.Length == 2)
                            {
                                switch (parts[0].Trim())
                                {
                                    case "ProfileName":
                                        profile.DisplayName = parts[1].Trim();
                                        break;
                                    case "CreatedDate":
                                        DateTime.TryParse(parts[1].Trim(), out DateTime created);
                                        profile.CreatedDate = created;
                                        break;
                                    case "Version":
                                        profile.Version = parts[1].Trim();
                                        break;
                                }
                            }
                        }
                        
                        if (string.IsNullOrEmpty(profile.DisplayName))
                            profile.DisplayName = profile.Name;
                        
                        profiles.Add(profile);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Failed to read profile {file}: {ex.Message}");
                    }
                }
                
                return profiles.OrderBy(p => p.DisplayName).ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to get available profiles: {ex.Message}", ex);
                return new List<CrosshairProfile>();
            }
        }
        
        /// <summary>
        /// Delete a profile
        /// </summary>
        public bool DeleteProfile(string profileName)
        {
            try
            {
                var profileDir = Path.Combine(Path.GetDirectoryName(_settingsFilePath), "Profiles");
                var profilePath = Path.Combine(profileDir, $"{profileName}.profile");
                
                if (File.Exists(profilePath))
                {
                    File.Delete(profilePath);
                    _logger.LogInfo($"Crosshair profile deleted: {profileName}");
                    return true;
                }
                
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to delete crosshair profile '{profileName}': {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Export profile to file
        /// </summary>
        public bool ExportProfile(string profileName, string exportPath)
        {
            try
            {
                var profileDir = Path.Combine(Path.GetDirectoryName(_settingsFilePath), "Profiles");
                var profilePath = Path.Combine(profileDir, $"{profileName}.profile");
                
                if (!File.Exists(profilePath))
                    return false;
                
                File.Copy(profilePath, exportPath, true);
                _logger.LogInfo($"Crosshair profile exported: {profileName} to {exportPath}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to export profile '{profileName}': {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Import profile from file
        /// </summary>
        public bool ImportProfile(string importPath, string newProfileName = null)
        {
            try
            {
                if (!File.Exists(importPath))
                    return false;
                
                var profileDir = Path.Combine(Path.GetDirectoryName(_settingsFilePath), "Profiles");
                Directory.CreateDirectory(profileDir);
                
                var profileName = newProfileName ?? Path.GetFileNameWithoutExtension(importPath);
                var profilePath = Path.Combine(profileDir, $"{profileName}.profile");
                
                File.Copy(importPath, profilePath, true);
                _logger.LogInfo($"Crosshair profile imported: {profileName} from {importPath}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to import profile from '{importPath}': {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Create quick-switch profiles for popular games
        /// </summary>
        public void CreateGameSpecificProfiles()
        {
            try
            {
                var gameProfiles = new Dictionary<string, CrosshairSettings>
                {
                    ["CS2_Competitive"] = new CrosshairSettings
                    {
                        IsEnabled = false,
                        Style = CrosshairStyle.Plus,
                        Size = 24,
                        Thickness = 1,
                        Red = 0, Green = 255, Blue = 255,
                        Alpha = 255,
                        HexColor = "#00FFFF",
                        Opacity = 0.8,
                        SelectedTheme = "CS2 Cyan",
                        ShowOnlyInGames = true,
                        HotkeyToggle = "F1"
                    },
                    ["Valorant_Precise"] = new CrosshairSettings
                    {
                        IsEnabled = false,
                        Style = CrosshairStyle.Cross,
                        Size = 18,
                        Thickness = 2,
                        Red = 255, Green = 0, Blue = 255,
                        Alpha = 255,
                        HexColor = "#FF00FF",
                        Opacity = 0.9,
                        SelectedTheme = "Valorant Pink",
                        ShowOnlyInGames = true,
                        HotkeyToggle = "F1"
                    },
                    ["Apex_Legends"] = new CrosshairSettings
                    {
                        IsEnabled = false,
                        Style = CrosshairStyle.Dot,
                        Size = 8,
                        Thickness = 3,
                        Red = 255, Green = 255, Blue = 0,
                        Alpha = 255,
                        HexColor = "#FFFF00",
                        Opacity = 1.0,
                        SelectedTheme = "Apex Yellow",
                        ShowOnlyInGames = true,
                        HotkeyToggle = "F1"
                    },
                    ["General_Gaming"] = new CrosshairSettings
                    {
                        IsEnabled = false,
                        Style = CrosshairStyle.Classic,
                        Size = 20,
                        Thickness = 2,
                        Red = 0, Green = 255, Blue = 0,
                        Alpha = 255,
                        HexColor = "#00FF00",
                        Opacity = 1.0,
                        SelectedTheme = "Classic Green",
                        ShowOnlyInGames = false,
                        HotkeyToggle = "F1"
                    }
                };
                
                foreach (var gameProfile in gameProfiles)
                {
                    var tempSettings = _settings;
                    _settings = gameProfile.Value;
                    SaveProfile(gameProfile.Key);
                    _settings = tempSettings;
                }
                
                _logger.LogInfo("Game-specific crosshair profiles created");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to create game-specific profiles: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get crosshair style options with descriptions
        /// </summary>
        public Dictionary<CrosshairStyle, string> GetCrosshairStyleDescriptions()
        {
            return new Dictionary<CrosshairStyle, string>
            {
                [CrosshairStyle.Classic] = "Traditional crosshair with four lines",
                [CrosshairStyle.Dot] = "Simple center dot",
                [CrosshairStyle.Circle] = "Circular crosshair outline",
                [CrosshairStyle.TShape] = "T-shaped crosshair (no bottom line)",
                [CrosshairStyle.Plus] = "Plus sign crosshair",
                [CrosshairStyle.Cross] = "X-shaped diagonal cross",
                [CrosshairStyle.Custom] = "User-defined custom shape"
            };
        }
        
        /// <summary>
        /// Auto-adjust crosshair settings based on display resolution
        /// </summary>
        public void AutoAdjustForResolution()
        {
            try
            {
                var screenWidth = System.Windows.SystemParameters.PrimaryScreenWidth;
                var screenHeight = System.Windows.SystemParameters.PrimaryScreenHeight;
                
                // Scale crosshair size based on resolution
                var scaleFactor = Math.Max(screenWidth / 1920.0, screenHeight / 1080.0);
                
                var adjustedSize = (int)Math.Round(_settings.Size * scaleFactor);
                var adjustedThickness = Math.Max(1, (int)Math.Round(_settings.Thickness * scaleFactor));
                
                _settings.Size = Math.Max(5, Math.Min(100, adjustedSize));
                _settings.Thickness = Math.Max(1, Math.Min(10, adjustedThickness));
                
                UpdateOverlay();
                SaveSettings();
                
                _logger.LogInfo($"Crosshair auto-adjusted for resolution {screenWidth}x{screenHeight}: Size={_settings.Size}, Thickness={_settings.Thickness}");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to auto-adjust crosshair for resolution: {ex.Message}", ex);
            }
        }
    }
}