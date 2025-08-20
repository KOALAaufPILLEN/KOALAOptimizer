using System.Windows;

namespace KOALAOptimizer
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            // Remove ThemeManager call since it's causing issues
            // Theme will be applied from MainWindow
        }
    }
}
