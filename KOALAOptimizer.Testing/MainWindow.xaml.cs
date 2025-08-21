using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using Microsoft.Win32;
using System.IO;
using System.Text.Json;
using System.ServiceProcess;
using System.Security.Principal;

namespace KOALAOptimizer
{
    public partial class MainWindow : Window
    {
        #region Win32 API Imports
        [DllImport("winmm.dll")]
        static extern uint timeBeginPeriod(uint period);
        
        [DllImport("winmm.dll")]
        static extern uint timeEndPeriod(uint period);

        [DllImport("ntdll.dll", SetLastError = true)]
        static extern int NtSetTimerResolution(int DesiredResolution, bool SetResolution, out int CurrentResolution);

        [DllImport("kernel32.dll")]
        static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll")]
        static extern bool SetProcessWorkingSetSize(IntPtr hProcess, int dwMinimumWorkingSetSize, int dwMaximumWorkingSetSize);

        [DllImport("kernel32.dll")]
        static extern bool SetProcessAffinityMask(IntPtr hProcess, IntPtr dwProcessAffinityMask);

        [DllImport("kernel32.dll")]
        static extern bool GetProcessAffinityMask(IntPtr hProcess, out IntPtr lpProcessAffinityMask, out IntPtr lpSystemAffinityMask);
        #endregion

        #region Fields
        private string backupPath;
        private Dictionary<string, object> originalSettings = new Dictionary<string, object>();
        private Window crosshairOverlay;
        private Dictionary<string, GameProfile> gameProfiles;
        private System.Windows.Threading.DispatcherTimer gameDetectionTimer;
        private string currentDetectedGame = null;
        private bool isAdmin = false;
        #endregion

        #region Game Profile Class
        public class GameProfile
        {
            public string DisplayName { get; set; }
            public List<string> ProcessNames { get; set; }
            public string Priority { get; set; }
            public string Affinity { get; set; }
            public List<string> SpecificTweaks { get; set; }
        }
        #endregion

        public MainWindow()
        {
            InitializeComponent();
            InitializeOptimizer();
        }

        private void InitializeOptimizer()
        {
            // Check admin privileges
            isAdmin = IsRunAsAdmin();
            
            // Set backup path
            string appPath = AppDomain.CurrentDomain.BaseDirectory;
            backupPath = System.IO.Path.Combine(appPath, "KoalaBackup.json");
            
            // Initialize game profiles
            InitializeGameProfiles();
            
            // Load system info
            LoadSystemInfo();
            
            // Set 1ms timer resolution
            timeBeginPeriod(1);
            
            // Log initialization
            LogMessage("🚀 KOALA Gaming Optimizer v3.0 initialized");
            LogMessage($"Admin Mode: {(isAdmin ? "✅ ACTIVE" : "⚠️ LIMITED")}");
            
            if (!isAdmin)
            {
                LogMessage("⚠️ Run as Administrator for full optimization features!", "Warning");
                DisableAdminFeatures();
            }
            
            // Initialize FOV slider event
            FovSlider.ValueChanged += (s, e) => FovValue.Text = ((int)FovSlider.Value).ToString();
            
            // Start game detection timer
            StartGameDetection();
            
            // Detect GPU vendor
            DetectGPUVendor();
        }

        private void InitializeGameProfiles()
        {
            gameProfiles = new Dictionary<string, GameProfile>
            {
                ["cs2"] = new GameProfile
                {
                    DisplayName = "Counter-Strike 2",
                    ProcessNames = new List<string> { "cs2", "cs2.exe" },
                    Priority = "High",
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "DisableNagle", "HighPrecisionTimer", "NetworkOptimization" }
                },
                ["valorant"] = new GameProfile
                {
                    DisplayName = "Valorant",
                    ProcessNames = new List<string> { "valorant", "valorant-win64-shipping" },
                    Priority = "High",
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "DisableNagle", "AntiCheatOptimization" }
                },
                ["fortnite"] = new GameProfile
                {
                    DisplayName = "Fortnite",
                    ProcessNames = new List<string> { "fortniteclient-win64-shipping" },
                    Priority = "High",
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "GPUScheduling", "MemoryOptimization" }
                },
                ["apex"] = new GameProfile
                {
                    DisplayName = "Apex Legends",
                    ProcessNames = new List<string> { "r5apex", "r5apex.exe" },
                    Priority = "High",
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "DisableNagle", "SourceEngineOptimization" }
                },
                ["warzone"] = new GameProfile
                {
                    DisplayName = "Call of Duty: Warzone",
                    ProcessNames = new List<string> { "modernwarfare", "warzone", "cod" },
                    Priority = "High",
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "MemoryOptimization", "NetworkOptimization" }
                },
                ["bf6"] = new GameProfile
                {
                    DisplayName = "Battlefield 6",
                    ProcessNames = new List<string> { "bf6event", "bf6", "battlefield" },
                    Priority = "High",
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "BF6Optimization", "MemoryOptimization", "NetworkOptimization", "GPUScheduling" }
                }
            };
        }

        private bool IsRunAsAdmin()
        {
            WindowsIdentity identity = WindowsIdentity.GetCurrent();
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }

        private void DisableAdminFeatures()
        {
            // Disable kernel optimizations
            KernelTimerResolution.IsEnabled = false;
            DisablePagingExecutive.IsEnabled = false;
            Win32PrioritySeparation.IsEnabled = false;
            DisableSpeculativeMitigations.IsEnabled = false;
            DisableTSXAutoBan.IsEnabled = false;
            ThreadDPCEnable.IsEnabled = false;
            DPCQueueDepth.IsEnabled = false;
            
            // Disable service controls
            DisableXboxServices.IsEnabled = false;
            DisablePrintSpooler.IsEnabled = false;
            DisableSysMain.IsEnabled = false;
            DisableTelemetryDiagTrack.IsEnabled = false;
            DisableWindowsSearch.IsEnabled = false;
            DisableTabletServices.IsEnabled = false;
            DisableThemesService.IsEnabled = false;
            DisableFax.IsEnabled = false;
            
            // Disable power management
            UltimatePerformancePowerPlan.IsEnabled = false;
            DisableHibernation.IsEnabled = false;
        }

        private void LoadSystemInfo()
        {
            try
            {
                string cpuInfo = "Unknown CPU";
                string gpuInfo = "Unknown GPU";
                string ramInfo = "0 GB";
                
                // Get CPU info
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Processor"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        cpuInfo = obj["Name"].ToString();
                        break;
                    }
                }
                
                // Get GPU info
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        if (obj["Name"] != null && !obj["Name"].ToString().Contains("Microsoft"))
                        {
                            gpuInfo = obj["Name"].ToString();
                            break;
                        }
                    }
                }
                
                // Get RAM info
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_ComputerSystem"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        double ram = Convert.ToDouble(obj["TotalPhysicalMemory"]) / (1024 * 1024 * 1024);
                        ramInfo = $"{Math.Round(ram, 1)} GB";
                        break;
                    }
                }
                
                LogMessage($"📊 System: CPU: {cpuInfo} | GPU: {gpuInfo} | RAM: {ramInfo}");
            }
            catch (Exception ex)
            {
                LogMessage($"Failed to load system info: {ex.Message}", "Error");
            }
        }

        private void DetectGPUVendor()
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        string name = obj["Name"]?.ToString() ?? "";
                        
                        if (name.Contains("NVIDIA") || name.Contains("GeForce") || name.Contains("RTX") || name.Contains("GTX"))
                        {
                            NVIDIADisableTelemetry.Visibility = Visibility.Visible;
                            LogMessage("🎮 NVIDIA GPU detected - vendor optimizations available");
                        }
                        else if (name.Contains("AMD") || name.Contains("Radeon") || name.Contains("RX"))
                        {
                            AMDDisableExternalEvents.Visibility = Visibility.Visible;
                            LogMessage("🎮 AMD GPU detected - vendor optimizations available");
                        }
                        else if (name.Contains("Intel"))
                        {
                            IntelGraphicsOptimizations.Visibility = Visibility.Visible;
                            LogMessage("🎮 Intel GPU detected - vendor optimizations available");
                        }
                    }
                }
            }
            catch { }
        }

        private void StartGameDetection()
        {
            gameDetectionTimer = new System.Windows.Threading.DispatcherTimer();
            gameDetectionTimer.Interval = TimeSpan.FromSeconds(5);
            gameDetectionTimer.Tick += DetectRunningGames;
            gameDetectionTimer.Start();
        }

        private void DetectRunningGames(object sender, EventArgs e)
        {
            if (AutomaticGameDetection.IsChecked != true) return;
            
            var processes = Process.GetProcesses();
            foreach (var profile in gameProfiles.Values)
            {
                foreach (var processName in profile.ProcessNames)
                {
                    if (processes.Any(p => p.ProcessName.ToLower().Contains(processName.ToLower().Replace(".exe", ""))))
                    {
                        if (currentDetectedGame != profile.DisplayName)
                        {
                            currentDetectedGame = profile.DisplayName;
                            LogMessage($"🎮 Game detected: {profile.DisplayName}");
                            
                            // Auto-select in combo
                            for (int i = 0; i < GameProfileCombo.Items.Count; i++)
                            {
                                var item = GameProfileCombo.Items[i] as ComboBoxItem;
                                if (item?.Content.ToString() == profile.DisplayName)
                                {
                                    GameProfileCombo.SelectedIndex = i;
                                    break;
                                }
                            }
                            
                            // Apply game-specific tweaks if auto-profile switching is enabled
                            if (AutoProfileSwitching.IsChecked == true)
                            {
                                ApplyGameProfile(profile);
                            }
                        }
                        return;
                    }
                }
            }
            
            if (currentDetectedGame != null)
            {
                LogMessage("🎮 No game detected");
                currentDetectedGame = null;
            }
        }

        private void ApplyGameProfile(GameProfile profile)
        {
            LogMessage($"Applying profile for {profile.DisplayName}...");
            
            foreach (var tweak in profile.SpecificTweaks)
            {
                switch (tweak)
                {
                    case "DisableNagle":
                        ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                            "TcpNoDelay", 1, RegistryValueKind.DWord);
                        break;
                    case "HighPrecisionTimer":
                        ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", 
                            "GlobalTimerResolutionRequests", 1, RegistryValueKind.DWord);
                        break;
                    case "NetworkOptimization":
                        ApplyNetworkOptimizations();
                        break;
                    case "MemoryOptimization":
                        ApplyMemoryOptimizations();
                        break;
                    case "GPUScheduling":
                        ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", 
                            "HwSchMode", 2, RegistryValueKind.DWord);
                        break;
                    case "BF6Optimization":
                        ApplyBF6Optimizations();
                        break;
                }
            }
        }

        private void ApplyBF6Optimizations()
        {
            LogMessage("Applying Battlefield 6 specific optimizations...");
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", 
                "DisablePagingExecutive", 1, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl", 
                "Win32PrioritySeparation", 38, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile", 
                "SystemResponsiveness", 0, RegistryValueKind.DWord);
        }

        private void LogMessage(string message, string level = "Info")
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string logEntry = $"[{timestamp}] [{level}] {message}\n";
            
            LogBox.AppendText(logEntry);
            LogBox.ScrollToEnd();
            
            // Update status
            StatusText.Text = message.Length > 50 ? message.Substring(0, 50) + "..." : message;
        }

        private void ApplyRegistryTweak(string keyPath, string valueName, object value, RegistryValueKind valueKind)
        {
            if (!isAdmin && keyPath.StartsWith(@"HKEY_LOCAL_MACHINE"))
            {
                LogMessage($"Skipping {valueName} - requires admin", "Warning");
                return;
            }
            
            try
            {
                Registry.SetValue(keyPath, valueName, value, valueKind);
                LogMessage($"✅ Applied: {valueName}");
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Failed to apply {valueName}: {ex.Message}", "Error");
            }
        }

        // Continue in Part 3...

        #region Crosshair Implementation
        private void ApplyCrosshair_Click(object sender, RoutedEventArgs e)
        {
            if (EnableCrosshair.IsChecked == true)
            {
                ShowCrosshairOverlay();
            }
            else
            {
                HideCrosshairOverlay();
            }
        }

        private void ShowCrosshairOverlay()
        {
            if (crosshairOverlay != null)
            {
                crosshairOverlay.Close();
            }

            crosshairOverlay = new Window
            {
                Width = 100,
                Height = 100,
                WindowStyle = WindowStyle.None,
                AllowsTransparency = true,
                Background = Brushes.Transparent,
                Topmost = true,
                ShowInTaskbar = false,
                IsHitTestVisible = false,
                WindowStartupLocation = WindowStartupLocation.CenterScreen
            };

            var canvas = new Canvas();
            
            // Get crosshair settings
            string style = (CrosshairStyle.SelectedItem as ComboBoxItem)?.Content.ToString() ?? "Cross";
            double size = CrosshairSize.Value;
            string colorStr = (CrosshairColor.SelectedItem as ComboBoxItem)?.Content.ToString() ?? "Green";
            
            Brush color = colorStr switch
            {
                "Red" => Brushes.Red,
                "Cyan" => Brushes.Cyan,
                _ => Brushes.Lime
            };

            switch (style)
            {
                case "Cross":
                    var hLine = new Line
                    {
                        X1 = 50 - size,
                        Y1 = 50,
                        X2 = 50 + size,
                        Y2 = 50,
                        Stroke = color,
                        StrokeThickness = 2
                    };
                    var vLine = new Line
                    {
                        X1 = 50,
                        Y1 = 50 - size,
                        X2 = 50,
                        Y2 = 50 + size,
                        Stroke = color,
                        StrokeThickness = 2
                    };
                    canvas.Children.Add(hLine);
                    canvas.Children.Add(vLine);
                    break;
                    
                case "Dot":
                    var dot = new Ellipse
                    {
                        Width = size,
                        Height = size,
                        Fill = color
                    };
                    Canvas.SetLeft(dot, 50 - size / 2);
                    Canvas.SetTop(dot, 50 - size / 2);
                    canvas.Children.Add(dot);
                    break;
                    
                case "Circle":
                    var circle = new Ellipse
                    {
                        Width = size * 2,
                        Height = size * 2,
                        Stroke = color,
                        StrokeThickness = 2
                    };
                    Canvas.SetLeft(circle, 50 - size);
                    Canvas.SetTop(circle, 50 - size);
                    canvas.Children.Add(circle);
                    break;
            }

            crosshairOverlay.Content = canvas;
            crosshairOverlay.Show();
            
            LogMessage($"✅ Crosshair enabled: {style}, Size: {size}, Color: {colorStr}");
        }

        private void HideCrosshairOverlay()
        {
            crosshairOverlay?.Close();
            crosshairOverlay = null;
            LogMessage("Crosshair disabled");
        }
        #endregion

        #region FOV Implementation
        private void ApplyFov_Click(object sender, RoutedEventArgs e)
        {
            int fov = (int)FovSlider.Value;
            LogMessage($"FOV set to {fov} (Note: Game must support FOV changes)");
            
            // Store FOV value for game configs
            try
            {
                string configPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "KOALA_FOV.cfg");
                File.WriteAllText(configPath, $"fov={fov}");
                LogMessage($"FOV config saved to {configPath}");
            }
            catch { }
        }
        #endregion
    }
}
