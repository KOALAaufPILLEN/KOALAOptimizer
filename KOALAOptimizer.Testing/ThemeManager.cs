using System;
using System.IO;
using System.Windows;

namespace KOALAOptimizer
{
    public enum ThemeType
    {
        Dark,
        Light,
        Blue,
        Red,
        Purple,
        Green,
        Orange,
        Pink,
        Cyan,
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
            
            try
            {
                // Apply theme resources if they exist
                UpdateResource(app, "BackgroundBrush", $"{prefix}BackgroundBrush");
                UpdateResource(app, "ForegroundBrush", $"{prefix}ForegroundBrush");
                UpdateResource(app, "AccentBrush", $"{prefix}AccentBrush");
                UpdateResource(app, "SecondaryBackgroundBrush", $"{prefix}SecondaryBackgroundBrush");
                UpdateResource(app, "DangerBrush", $"{prefix}DangerBrush");
            }
            catch { }
        }

        private static void UpdateResource(Application app, string targetKey, string sourceKey)
        {
            if (app.Resources.Contains(sourceKey))
            {
                app.Resources[targetKey] = app.Resources[sourceKey];
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
