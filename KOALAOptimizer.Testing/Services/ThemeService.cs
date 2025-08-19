using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for managing application themes
    /// </summary>
    public class ThemeService
    {
        private static readonly Lazy<ThemeService> _instance = new Lazy<ThemeService>(() => new ThemeService());
        public static ThemeService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly List<ThemeInfo> _availableThemes;
        private ThemeInfo _currentTheme;
        
        public event EventHandler<ThemeInfo> ThemeChanged;
        
        private ThemeService()
        {
            try
            {
                LoggingService.EmergencyLog("ThemeService: Initializing...");
                
                _logger = LoggingService.Instance;
                LoggingService.EmergencyLog("ThemeService: LoggingService obtained");
                
                _availableThemes = InitializeThemes();
                LoggingService.EmergencyLog($"ThemeService: {_availableThemes?.Count ?? 0} themes initialized");
                
                // Don't assume a theme is loaded, let the application handle initial theme loading
                _currentTheme = null;
                
                // Try to detect current theme if any
                try
                {
                    DetectCurrentTheme();
                    LoggingService.EmergencyLog($"ThemeService: Current theme detected: {_currentTheme?.DisplayName ?? "None"}");
                }
                catch (Exception detectEx)
                {
                    _logger?.LogWarning($"Failed to detect current theme: {detectEx.Message}");
                    LoggingService.EmergencyLog($"ThemeService: Theme detection failed: {detectEx.Message}");
                }
                
                _logger?.LogInfo("Theme service initialized");
                LoggingService.EmergencyLog("ThemeService: Initialization completed successfully");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"ThemeService: CRITICAL - Initialization failed: {ex.Message}");
                _logger?.LogError($"Critical error initializing ThemeService: {ex.Message}", ex);
                // Initialize with empty theme list to prevent null reference issues
                _availableThemes = new List<ThemeInfo>();
                _currentTheme = null;
            }
        }
        
        /// <summary>
        /// Initialize available themes
        /// </summary>
        private List<ThemeInfo> InitializeThemes()
        {
            return new List<ThemeInfo>
            {
                new ThemeInfo
                {
                    Name = "SciFi",
                    DisplayName = "🚀 Sci-Fi",
                    ResourcePath = "Themes/SciFiTheme.xaml",
                    Description = "Futuristic purple and green theme with glowing effects"
                },
                new ThemeInfo
                {
                    Name = "Gaming",
                    DisplayName = "🎮 Gaming",
                    ResourcePath = "Themes/GamingTheme.xaml",
                    Description = "Bold red and orange gaming theme with RGB-style lighting"
                },
                new ThemeInfo
                {
                    Name = "Classic",
                    DisplayName = "💼 Classic",
                    ResourcePath = "Themes/ClassicTheme.xaml",
                    Description = "Professional blue and white business theme"
                },
                new ThemeInfo
                {
                    Name = "Matrix",
                    DisplayName = "🟢 Matrix",
                    ResourcePath = "Themes/MatrixTheme.xaml",
                    Description = "Green matrix-style terminal theme with monospace fonts"
                },
                new ThemeInfo
                {
                    Name = "KOALA",
                    DisplayName = "🐨 KOALA",
                    ResourcePath = "Themes/KOALATheme.xaml",
                    Description = "Natural eucalyptus and koala-inspired theme with calming earth tones"
                }
            };
        }
        
        /// <summary>
        /// Get all available themes
        /// </summary>
        public IEnumerable<ThemeInfo> GetAvailableThemes()
        {
            return _availableThemes;
        }
        
        /// <summary>
        /// Get current theme
        /// </summary>
        public ThemeInfo GetCurrentTheme()
        {
            // If current theme is null, try to detect from loaded resources
            if (_currentTheme == null)
            {
                DetectCurrentTheme();
            }
            return _currentTheme;
        }
        
        /// <summary>
        /// Detect which theme is currently loaded by examining application resources
        /// </summary>
        private void DetectCurrentTheme()
        {
            try
            {
                var mergedDictionaries = Application.Current.Resources.MergedDictionaries;
                var loadedTheme = mergedDictionaries.FirstOrDefault(d => 
                    d.Source != null && d.Source.ToString().Contains("Themes/"));
                
                if (loadedTheme != null)
                {
                    var sourceString = loadedTheme.Source.ToString();
                    var themeFileName = sourceString.Split('/').LastOrDefault();
                    
                    // Map theme file names to theme info
                    switch (themeFileName)
                    {
                        case "SciFiTheme.xaml":
                            _currentTheme = _availableThemes.FirstOrDefault(t => t.Name == "SciFi");
                            break;
                        case "GamingTheme.xaml":
                            _currentTheme = _availableThemes.FirstOrDefault(t => t.Name == "Gaming");
                            break;
                        case "ClassicTheme.xaml":
                            _currentTheme = _availableThemes.FirstOrDefault(t => t.Name == "Classic");
                            break;
                        case "MatrixTheme.xaml":
                            _currentTheme = _availableThemes.FirstOrDefault(t => t.Name == "Matrix");
                            break;
                        case "KOALATheme.xaml":
                            _currentTheme = _availableThemes.FirstOrDefault(t => t.Name == "KOALA");
                            break;
                    }
                    
                    if (_currentTheme != null)
                    {
                        _logger.LogInfo($"Detected current theme: {_currentTheme.DisplayName}");
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to detect current theme: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Apply theme by name
        /// </summary>
        public bool ApplyTheme(string themeName)
        {
            var theme = _availableThemes.FirstOrDefault(t => t.Name.Equals(themeName, StringComparison.OrdinalIgnoreCase));
            if (theme == null)
            {
                _logger.LogWarning($"Theme '{themeName}' not found");
                return false;
            }
            
            return ApplyTheme(theme);
        }
        
        /// <summary>
        /// Apply specific theme
        /// </summary>
        public bool ApplyTheme(ThemeInfo theme)
        {
            try
            {
                if (theme == null)
                {
                    _logger.LogError("Theme cannot be null");
                    return false;
                }
                
                // Load the theme resource dictionary with validation
                var themeUri = new Uri($"pack://application:,,,/{theme.ResourcePath}", UriKind.Absolute);
                ResourceDictionary themeDict;
                
                try
                {
                    themeDict = new ResourceDictionary { Source = themeUri };
                    
                    // Validate that the theme has essential resources
                    if (!ValidateThemeResources(themeDict))
                    {
                        _logger.LogWarning($"Theme '{theme.DisplayName}' is missing essential resources, attempting fallback");
                        return ApplyFallbackTheme();
                    }
                }
                catch (Exception loadEx)
                {
                    _logger.LogError($"Failed to load theme resource '{theme.ResourcePath}': {loadEx.Message}");
                    return ApplyFallbackTheme();
                }
                
                // Clear existing theme resources and apply new theme
                var mergedDictionaries = Application.Current.Resources.MergedDictionaries;
                
                // Remove existing theme dictionaries
                var existingThemes = mergedDictionaries
                    .Where(d => d.Source != null && d.Source.ToString().Contains("Themes/"))
                    .ToList();
                
                foreach (var existingTheme in existingThemes)
                {
                    mergedDictionaries.Remove(existingTheme);
                }
                
                // Add new theme
                mergedDictionaries.Insert(0, themeDict);
                
                _currentTheme = theme;
                _logger.LogInfo($"Theme applied: {theme.DisplayName}");
                
                // Notify subscribers
                ThemeChanged?.Invoke(this, theme);
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply theme '{theme?.DisplayName}': {ex.Message}", ex);
                return ApplyFallbackTheme();
            }
        }
        
        /// <summary>
        /// Validate that theme has essential resources
        /// </summary>
        private bool ValidateThemeResources(ResourceDictionary themeDict)
        {
            try
            {
                // Check for essential brushes that should be present in every theme
                string[] essentialResources = { 
                    "BackgroundBrush", "TextBrush", "PrimaryBrush", 
                    "AccentBrush", "BorderBrush", "MainWindowStyle" 
                };
                
                foreach (var resourceKey in essentialResources)
                {
                    if (!themeDict.Contains(resourceKey))
                    {
                        _logger.LogWarning($"Theme missing essential resource: {resourceKey}");
                        return false;
                    }
                }
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error validating theme resources: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Apply fallback theme when primary theme fails
        /// </summary>
        private bool ApplyFallbackTheme()
        {
            try
            {
                _logger.LogInfo("Attempting to apply fallback SciFi theme");
                var fallbackTheme = _availableThemes.FirstOrDefault(t => t.Name == "SciFi");
                
                if (fallbackTheme != null && fallbackTheme != _currentTheme)
                {
                    // Try to apply fallback theme (avoid infinite recursion)
                    var themeUri = new Uri($"pack://application:,,,/{fallbackTheme.ResourcePath}", UriKind.Absolute);
                    var themeDict = new ResourceDictionary { Source = themeUri };
                    
                    var mergedDictionaries = Application.Current.Resources.MergedDictionaries;
                    var existingThemes = mergedDictionaries
                        .Where(d => d.Source != null && d.Source.ToString().Contains("Themes/"))
                        .ToList();
                    
                    foreach (var existingTheme in existingThemes)
                    {
                        mergedDictionaries.Remove(existingTheme);
                    }
                    
                    mergedDictionaries.Insert(0, themeDict);
                    _currentTheme = fallbackTheme;
                    _logger.LogInfo("Fallback theme applied successfully");
                    return true;
                }
                else
                {
                    _logger.LogError("No fallback theme available or already using fallback");
                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply fallback theme: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Cycle to next theme
        /// </summary>
        public bool CycleToNextTheme()
        {
            var currentIndex = _availableThemes.IndexOf(_currentTheme);
            var nextIndex = (currentIndex + 1) % _availableThemes.Count;
            var nextTheme = _availableThemes[nextIndex];
            
            return ApplyTheme(nextTheme);
        }
        
        /// <summary>
        /// Cycle to previous theme
        /// </summary>
        public bool CycleToPreviousTheme()
        {
            var currentIndex = _availableThemes.IndexOf(_currentTheme);
            var previousIndex = currentIndex == 0 ? _availableThemes.Count - 1 : currentIndex - 1;
            var previousTheme = _availableThemes[previousIndex];
            
            return ApplyTheme(previousTheme);
        }
        
        /// <summary>
        /// Get theme by name
        /// </summary>
        public ThemeInfo GetTheme(string themeName)
        {
            return _availableThemes.FirstOrDefault(t => t.Name.Equals(themeName, StringComparison.OrdinalIgnoreCase));
        }
        
        /// <summary>
        /// Check if theme exists
        /// </summary>
        public bool ThemeExists(string themeName)
        {
            return _availableThemes.Any(t => t.Name.Equals(themeName, StringComparison.OrdinalIgnoreCase));
        }
    }
}