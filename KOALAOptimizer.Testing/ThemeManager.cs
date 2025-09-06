using System;
using System.IO;
using System.Windows;

namespace KOALAOptimizer
{
    public enum ThemeType
    {
        Dark,
        Light,
        Matrix,
        KOALA,
        Gaming,
        SciFi,
        Classic
    }

    public static class ThemeManager
    {
        private static readonly string ThemePreferencePath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "KOALAOptimizer",
            "theme.preference"
        );

        public static void ApplyTheme(ThemeType theme)
        {
            try
            {
                var app = Application.Current;
                if (app?.Resources == null) return;

                // Clear existing theme resources
                app.Resources.MergedDictionaries.Clear();

                // Load the appropriate theme dictionary
                string themeUri = theme switch
                {
                    ThemeType.Matrix => "Themes/MatrixTheme.xaml",
                    ThemeType.KOALA => "Themes/KOALATheme.xaml",
                    ThemeType.Gaming => "Themes/GamingTheme.xaml",
                    ThemeType.SciFi => "Themes/SciFiTheme.xaml",
                    ThemeType.Classic => "Themes/ClassicTheme.xaml",
                    ThemeType.Light => "Themes/ClassicTheme.xaml", // Default to classic for light
                    _ => "Themes/KOALATheme.xaml" // Default theme
                };

                var themeDict = new ResourceDictionary
                {
                    Source = new Uri($"pack://application:,,,/{themeUri}")
                };

                app.Resources.MergedDictionaries.Add(themeDict);

                // Apply dynamic color updates for existing windows
                foreach (Window window in app.Windows)
                {
                    if (window != null)
                    {
                        window.Resources.MergedDictionaries.Clear();
                        window.Resources.MergedDictionaries.Add(themeDict);
                        
                        // Force refresh of the window
                        window.InvalidateVisual();
                    }
                }
            }
            catch (Exception ex)
            {
                // Log error but don't crash - fallback to default theme
                System.Diagnostics.Debug.WriteLine($"Theme application error: {ex.Message}");
            }
        }

        public static void SaveThemePreference(ThemeType theme)
        {
            try
            {
                var directory = Path.GetDirectoryName(ThemePreferencePath);
                if (!string.IsNullOrEmpty(directory))
                {
                    Directory.CreateDirectory(directory);
                    File.WriteAllText(ThemePreferencePath, theme.ToString());
                }
            }
            catch { }
        }

        public static ThemeType LoadThemePreference()
        {
            try
            {
                if (File.Exists(ThemePreferencePath))
                {
                    var themeName = File.ReadAllText(ThemePreferencePath);
                    if (Enum.TryParse<ThemeType>(themeName, out var theme))
                    {
                        return theme;
                    }
                }
            }
            catch { }
            
            return ThemeType.Dark;
        }
    }
}