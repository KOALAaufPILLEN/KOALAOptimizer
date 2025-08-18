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
            _logger = LoggingService.Instance;
            _availableThemes = InitializeThemes();
            _currentTheme = _availableThemes.First(); // Default to first theme (Sci-Fi)
            
            _logger.LogInfo("Theme service initialized");
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
            return _currentTheme;
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
                
                // Load the theme resource dictionary
                var themeUri = new Uri($"pack://application:,,,/{theme.ResourcePath}", UriKind.Absolute);
                var themeDict = new ResourceDictionary { Source = themeUri };
                
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