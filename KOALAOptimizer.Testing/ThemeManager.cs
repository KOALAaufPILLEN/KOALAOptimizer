using System;
using System.IO;
using System.Windows;

namespace KOALAOptimizer
{
    public enum ThemeType
    {
        Dark,
        Light,
        Matrix
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
            var app = Application.Current;
            if (app?.Resources == null) return;

            string prefix = theme.ToString();
            
            app.Resources["BackgroundBrush"] = app.Resources[$"{prefix}BackgroundBrush"];
            app.Resources["ForegroundBrush"] = app.Resources[$"{prefix}ForegroundBrush"];
            app.Resources["AccentBrush"] = app.Resources[$"{prefix}AccentBrush"];
            app.Resources["SecondaryBackgroundBrush"] = app.Resources[$"{prefix}SecondaryBackgroundBrush"];
            app.Resources["DangerBrush"] = app.Resources[$"{prefix}DangerBrush"];
        }

        public static void SaveThemePreference(ThemeType theme)
        {
            try
            {
                var directory = Path.GetDirectoryName(ThemePreferencePath);
                if (!string.IsNullOrEmpty(directory))
                {
                    Directory.CreateDirectory(directory);
                }
                File.WriteAllText(ThemePreferencePath, theme.ToString());
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
