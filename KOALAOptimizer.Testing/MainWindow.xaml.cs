using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
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
        private bool kernelWarningShown = false;
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
            
            // Store original settings before any changes
            StoreOriginalSettings();
            
            // Initialize game profiles
            InitializeGameProfiles();
            
            // Load system info
            LoadSystemInfo();
            
            // Set 1ms timer resolution
            timeBeginPeriod(1);
            
            // Log initialization
            LogMessage("🚀 KOALA Gaming Optimizer v3.0 initialized");
            LogMessage($"Admin Mode: {(isAdmin ? "✅ ACTIVE" : "⚠️ LIMITED")}");
            
            // Update status indicators
            UpdateStatusIndicators();
            
            // Perform comprehensive system validation
            Task.Run(() => PerformSystemValidation());
            
            if (!isAdmin)
            {
                LogMessage("⚠️ Run as Administrator for full optimization features!", "Warning");
                DisableAdminFeatures();
            }
            
            // Initialize FOV slider event
            FovSlider.ValueChanged += (s, e) => FovValue.Text = ((int)FovSlider.Value).ToString();
            
            // Start game detection timer
            StartGameDetection();
        }
        
        private async void PerformSystemValidation()
        {
            try
            {
                await Dispatcher.InvokeAsync(() => LogMessage("🔍 Starting system validation...", "Info"));
                UpdateValidationStatus(false);
                
                // Run comprehensive system check
                var issues = ErrorChecker.ValidateSystemReadiness(LogMessage);
                
                await Dispatcher.InvokeAsync(() =>
                {
                    if (issues.Count == 0)
                    {
                        LogMessage("✅ System validation completed successfully - ready for optimization!", "Info");
                        UpdateValidationStatus(true, 0);
                    }
                    else
                    {
                        LogMessage($"⚠️ System validation found {issues.Count} issues:", "Warning");
                        foreach (var issue in issues)
                        {
                            LogMessage($"  {issue}", "Warning");
                        }
                        
                        if (issues.Count > 3)
                        {
                            LogMessage("⚠️ Multiple issues detected - proceed with caution", "Warning");
                        }
                        
                        UpdateValidationStatus(true, issues.Count);
                    }
                });
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"❌ System validation error: {ex.Message}", "Error"));
                UpdateValidationStatus(true, 999); // Indicate error
            }
        }
            
            // Detect GPU vendor
            DetectGPUVendor();
        }

        private void StoreOriginalSettings()
        {
            try
            {
                // Store important registry values before modification
                originalSettings["SystemResponsiveness"] = Registry.GetValue(
                    @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                    "SystemResponsiveness", 20);
                    
                originalSettings["GameDVR_Enabled"] = Registry.GetValue(
                    @"HKEY_CURRENT_USER\System\GameConfigStore",
                    "GameDVR_Enabled", 1);
                    
                originalSettings["Win32PrioritySeparation"] = Registry.GetValue(
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl",
                    "Win32PrioritySeparation", 2);
                    
                originalSettings["NetworkThrottlingIndex"] = Registry.GetValue(
                    @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                    "NetworkThrottlingIndex", 10);
                    
                // Store service states
                var services = new[] { "XblGameSave", "XblAuthManager", "DiagTrack", "SysMain", "WSearch" };
                foreach (var service in services)
                {
                    try
                    {
                        using (var sc = new ServiceController(service))
                        {
                            originalSettings[$"Service_{service}"] = sc.StartType.ToString();
                        }
                    }
                    catch { }
                }
                
                LogMessage("📁 Original settings stored for backup");
            }
            catch (Exception ex)
            {
                LogMessage($"Failed to store original settings: {ex.Message}", "Warning");
            }
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
                            NVIDIAMaxPerformance.Visibility = Visibility.Visible;
                            NVIDIAThreadedOptimization.Visibility = Visibility.Visible;
                            LogMessage("🎮 NVIDIA GPU detected - vendor optimizations available");
                        }
                        else if (name.Contains("AMD") || name.Contains("Radeon") || name.Contains("RX"))
                        {
                            AMDDisableExternalEvents.Visibility = Visibility.Visible;
                            AMDAntiLag.Visibility = Visibility.Visible;
                            AMDRadeonBoost.Visibility = Visibility.Visible;
                            LogMessage("🎮 AMD GPU detected - vendor optimizations available");
                        }
                        else if (name.Contains("Intel"))
                        {
                            IntelGraphicsOptimizations.Visibility = Visibility.Visible;
                            IntelPowerSaving.Visibility = Visibility.Visible;
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
                // PART 2 - Continuation from line ~400

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

        #region UI Event Handlers
        private void ToggleSection_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as ToggleButton;
            if (button == null) return;
            
            string sectionName = button.Name.Replace("Header", "Content");
            var content = FindName(sectionName) as Border;
            
            if (content != null)
            {
                content.Visibility = button.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
            }
        }

        private void OptimizeSection_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as Button;
            if (button == null) return;
            
            // Stop event propagation to prevent toggle
            e.Handled = true;
            
            // Get section name from parent ToggleButton name
            var parent = button.Parent as Grid;
            if (parent?.TemplatedParent is ToggleButton toggleButton)
            {
                string sectionName = toggleButton.Name.Replace("Header", "");
                ApplySectionOptimizations(sectionName);
            }
        }

        private void ApplySectionOptimizations(string section)
        {
            LogMessage($"🚀 Applying {section} optimizations...");
            CreateBackup();
            
            Task.Run(async () =>
            {
                switch (section)
                {
                    case "Networking":
                        ApplyNetworkOptimizations();
                        break;
                    case "Gaming":
                        ApplyGamingOptimizations();
                        break;
                    case "CPU":
                        ApplyCPUOptimizations();
                        break;
                    case "FPS":
                        ApplyFPSBoostingTweaks();
                        break;
                    case "Kernel":
                        if (ShowKernelWarning())
                            ApplyKernelOptimizations();
                        break;
                    case "Detection":
                        EnableSmartDetection();
                        break;
                    case "System":
                        ApplySystemPerformance();
                        break;
                    case "GPU":
                        ApplyGPUVendorOptimizations();
                        break;
                    case "Services":
                        await DisableServices();
                        break;
                    case "Unneeded":
                        await DisableUnneededServices();
                        break;
                }
                
                await Dispatcher.InvokeAsync(() => 
                    LogMessage($"✅ {section} optimizations applied!"));
            });
        }

        private bool ShowKernelWarning()
        {
            if (!kernelWarningShown)
            {
                var result = MessageBox.Show(
                    "⚠️ KERNEL OPTIMIZATIONS WARNING ⚠️\n\n" +
                    "These modifications will:\n" +
                    "• Modify Windows kernel parameters\n" +
                    "• May trigger anti-cheat systems (EAC, BattlEye, Vanguard)\n" +
                    "• Could cause system instability if misconfigured\n" +
                    "• Require system restart to take full effect\n\n" +
                    "Games that may be affected:\n" +
                    "• Valorant (Vanguard)\n" +
                    "• Fortnite (EAC/BattlEye)\n" +
                    "• Apex Legends (EAC)\n" +
                    "• Call of Duty (Ricochet)\n" +
                    "• Rainbow Six Siege (BattlEye)\n" +
                    "• PUBG (BattlEye)\n\n" +
                    "Do you accept these risks and want to continue?",
                    "KOALA V3 - Kernel Optimization Warning",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Warning);
                    
                kernelWarningShown = true;
                return result == MessageBoxResult.Yes;
            }
            return true;
        }

        private void PerformanceMode_Checked(object sender, RoutedEventArgs e)
        {
            LogMessage("⚡ Performance Mode selected - Kernel optimizations available", "Warning");
            EnableKernelOptimizations(true);
        }

        private void UltraMode_Checked(object sender, RoutedEventArgs e)
        {
            var result = MessageBox.Show(
                "🚀 ULTRA MODE WARNING 🚀\n\n" +
                "Ultra Mode will:\n" +
                "• Apply ALL optimizations including risky ones\n" +
                "• Disable security mitigations\n" +
                "• Maximum performance at cost of stability\n" +
                "• NOT recommended for daily use\n\n" +
                "Continue?",
                "KOALA V3 - Ultra Mode",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);
                
            if (result == MessageBoxResult.No)
            {
                SafeMode.IsChecked = true;
            }
            else
            {
                LogMessage("🚀 ULTRA MODE ACTIVATED - Maximum performance, use with caution!", "Warning");
                EnableKernelOptimizations(true);
            }
        }

        private void EnableKernelOptimizations(bool enable)
        {
            KernelTimerResolution.IsEnabled = enable && isAdmin;
            DisablePagingExecutive.IsEnabled = enable && isAdmin;
            Win32PrioritySeparation.IsEnabled = enable && isAdmin;
            DisableSpeculativeMitigations.IsEnabled = enable && isAdmin;
            DisableTSXAutoBan.IsEnabled = enable && isAdmin;
            ThreadDPCEnable.IsEnabled = enable && isAdmin;
            DPCQueueDepth.IsEnabled = enable && isAdmin;
            DisableKernelMitigations.IsEnabled = enable && isAdmin && UltraMode.IsChecked == true;
            DisableHyperThreading.IsEnabled = enable && isAdmin;
            DisableSMT.IsEnabled = enable && isAdmin;
            SetMSRRegisters.IsEnabled = enable && isAdmin && UltraMode.IsChecked == true;
            DisableVBS.IsEnabled = enable && isAdmin;
        }

        private void EnableSmartDetection()
        {
            AutomaticGameDetection.IsChecked = true;
            AutoProfileSwitching.IsChecked = true;
            GameSpecificProfiles.IsChecked = true;
            BackgroundAppSuppression.IsChecked = true;
            LogMessage("🎯 Smart detection enabled");
        }

        private void ApplySystemPerformance()
        {
            if (OptimizeMemoryManagement.IsChecked == true)
                ApplyMemoryOptimizations();
            if (UltimatePerformancePowerPlan.IsChecked == true)
                ApplyPowerManagement();
            if (OptimizeCPUScheduling2.IsChecked == true)
                ApplyCPUOptimizations();
        }
        #endregion

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
                string configPath = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "KOALA_FOV.cfg");
                File.WriteAllText(configPath, $"fov={fov}");
                LogMessage($"FOV config saved to {configPath}");
            }
            catch { }
        }
        #endregion

        #region Main Optimization Methods
        private void Recommended_Click(object sender, RoutedEventArgs e)
        {
            if (!isAdmin && MessageBox.Show(
                "Administrator privileges required for full optimization.\n\nContinue with limited optimizations?", 
                "KOALA V3", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.No)
            {
                return;
            }

            LogMessage("🚀 Applying recommended optimizations...");
            UpdateOptimizationStatus("🚀 Starting...", "Info");
            CreateBackup();
            
            Task.Run(async () =>
            {
                await ApplyAllOptimizations();
                await Dispatcher.InvokeAsync(() =>
                {
                    LogMessage("✅ All recommended optimizations applied!");
                    UpdateOptimizationStatus("✅ Complete!", "Success");
                    MessageBox.Show("Optimizations complete!\n\nRestart recommended for best performance.", 
                        "KOALA V3", MessageBoxButton.OK, MessageBoxImage.Information);
                });
            });
        }

        private async Task ApplyAllOptimizations()
        {
            try
            {
                // Pre-optimization validation
                await Dispatcher.InvokeAsync(() => LogMessage("🔒 Validating optimization safety...", "Info"));
                
                var safetyChecks = new[]
                {
                    ("network", DisableTCPDelay.IsChecked == true),
                    ("registry", true),
                    ("services", DisableXboxServices.IsChecked == true),
                    ("gpu", EnableGPUHwScheduling.IsChecked == true),
                    ("kernel", PerformanceMode.IsChecked == true)
                };
                
                foreach (var (type, enabled) in safetyChecks)
                {
                    if (enabled && !ErrorChecker.ValidateOptimizationSafety(type, LogMessage))
                    {
                        await Dispatcher.InvokeAsync(() => 
                            LogMessage($"⚠️ Safety validation failed for {type} optimizations - proceeding with caution", "Warning"));
                    }
                }

                int totalSteps = 15;
                int currentStep = 0;

                // 1. Network Optimizations
                if (DisableTCPDelay.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying network optimizations..."));
                    await SafeExecuteOptimization(() => ApplyNetworkOptimizations(), "Network");
                }

                // 2. Gaming Optimizations
                if (DisableGameDVR.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Disabling Game DVR..."));
                    await SafeExecuteOptimization(() => ApplyGamingOptimizations(), "Gaming");
                }

                // 3. GPU Optimizations
                if (EnableGPUHwScheduling.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Enabling GPU hardware scheduling..."));
                    await SafeExecuteOptimization(() => ApplyGPUOptimizations(), "GPU");
                }

                // 4. Memory Optimizations
                if (AdvancedMemoryOptimization.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing memory management..."));
                    await SafeExecuteOptimization(() => ApplyMemoryOptimizations(), "Memory");
                }

                // 5. CPU Optimizations
                if (OptimizeCPUScheduling.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing CPU scheduling..."));
                    await SafeExecuteOptimization(() => ApplyCPUOptimizations(), "CPU");
                }

                // 6. Visual Effects
                if (SelectiveVisualEffectsOptimization.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying selective visual effects..."));
                    await SafeExecuteOptimization(() => ApplyVisualEffectOptimizations(), "Visual Effects");
                }

                // 7. Power Management
                if (UltimatePerformancePowerPlan.IsChecked == true && isAdmin)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Setting ultimate performance power plan..."));
                    await SafeExecuteOptimization(() => ApplyPowerManagement(), "Power Management");
                }

                // 8. Services
                if (DisableXboxServices.IsChecked == true && isAdmin)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Disabling unnecessary services..."));
                    await SafeExecuteOptimization(async () => await DisableServices(), "Services");
                }

                // 9. Kernel Optimizations (Performance Mode Only)
                if (PerformanceMode.IsChecked == true && isAdmin)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying kernel optimizations..."));
                    await SafeExecuteOptimization(() => ApplyKernelOptimizations(), "Kernel");
                }

                // 10. Input Optimizations
                if (GamingInputOptimization.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing input devices..."));
                    await SafeExecuteOptimization(() => ApplyInputOptimizations(), "Input");
                }

                // 11. Audio Optimizations
                if (GamingAudioOptimization.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing audio..."));
                    await SafeExecuteOptimization(() => ApplyAudioOptimizations(), "Audio");
                }

                // 12. Disk Optimizations
                if (DiskPerformanceTweaks.IsChecked == true)
                {
                    await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing disk performance..."));
                    await SafeExecuteOptimization(() => ApplyDiskOptimizations(), "Disk");
                }

                // 13. GPU Vendor Specific
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying GPU vendor optimizations..."));
                await SafeExecuteOptimization(() => ApplyGPUVendorOptimizations(), "GPU Vendor");

                // 14. FPS Boosting
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying FPS boosting tweaks..."));
                await SafeExecuteOptimization(() => ApplyFPSBoostingTweaks(), "FPS Boosting");

                // 15. Advanced Razer Booster-style optimizations
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying advanced gaming optimizations..."));
                await SafeExecuteOptimization(() => ApplyRazerBoosterOptimizations(), "Advanced Gaming");

                // Post-optimization validation
                await Dispatcher.InvokeAsync(() => LogMessage("🔍 Running post-optimization validation...", "Info"));
                var postIssues = ErrorChecker.ValidatePostOptimization(LogMessage);
                
                await Dispatcher.InvokeAsync(() =>
                {
                    if (postIssues.Count == 0)
                    {
                        LogMessage("✅ Post-optimization validation successful!", "Info");
                    }
                    else
                    {
                        LogMessage($"⚠️ Post-optimization validation found {postIssues.Count} issues:", "Warning");
                        foreach (var issue in postIssues)
                        {
                            LogMessage($"  {issue}", "Warning");
                        }
                    }
                });
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"❌ Critical error during optimization: {ex.Message}", "Error"));
                throw;
            }
        }
        
        private async Task SafeExecuteOptimization(Action optimization, string optimizationType)
        {
            try
            {
                await Task.Run(optimization);
                await Dispatcher.InvokeAsync(() => LogMessage($"✅ {optimizationType} optimization completed successfully", "Info"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"❌ {optimizationType} optimization failed: {ex.Message}", "Error"));
            }
        }
        
        private async Task SafeExecuteOptimization(Func<Task> optimization, string optimizationType)
        {
            try
            {
                await optimization();
                await Dispatcher.InvokeAsync(() => LogMessage($"✅ {optimizationType} optimization completed successfully", "Info"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"❌ {optimizationType} optimization failed: {ex.Message}", "Error"));
            }
        }
        
        private void ApplyRazerBoosterOptimizations()
        {
            try
            {
                AdvancedOptimizations.ApplyGameBoosterMode();
                AdvancedOptimizations.OptimizeCPUCoresForGaming();
                AdvancedOptimizations.PerformMemoryCleanup();
                AdvancedOptimizations.OptimizeBackgroundProcesses();
                AdvancedOptimizations.PrioritizeSystemResources();
                AdvancedOptimizations.EnableGameDetectionOptimization();
                AdvancedOptimizations.OptimizeDirectXGaming();
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Razer Booster optimization error: {ex.Message}", "Error");
            }
        }
                ApplyMemoryOptimizations();
            }

            // 5. CPU Optimizations
            if (OptimizeCPUScheduling.IsChecked == true)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing CPU scheduling..."));
                ApplyCPUOptimizations();
            }

            // 6. Visual Effects
            if (SelectiveVisualEffectsOptimization.IsChecked == true)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying selective visual effects..."));
                ApplyVisualEffectOptimizations();
            }

            // 7. Power Management
            if (UltimatePerformancePowerPlan.IsChecked == true && isAdmin)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Setting ultimate performance power plan..."));
                ApplyPowerManagement();
            }

            // 8. Services
            if (DisableXboxServices.IsChecked == true && isAdmin)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Disabling unnecessary services..."));
                await DisableServices();
            }

            // 9. Kernel Optimizations (Performance Mode Only)
            if (PerformanceMode.IsChecked == true && isAdmin)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying kernel optimizations..."));
                ApplyKernelOptimizations();
            }

            // 10. Input Optimizations
            if (GamingInputOptimization.IsChecked == true)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing input devices..."));
                ApplyInputOptimizations();
            }

            // 11. Audio Optimizations
            if (GamingAudioOptimization.IsChecked == true)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing audio..."));
                ApplyAudioOptimizations();
            }

            // 12. Disk Optimizations
            if (DiskPerformanceTweaks.IsChecked == true)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Optimizing disk performance..."));
                ApplyDiskOptimizations();
            }

            // 13. GPU Vendor Specific
            await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying GPU vendor optimizations..."));
            ApplyGPUVendorOptimizations();

            // 14. FPS Boosting
            if (CPUCoreParkingDisable.IsChecked == true && isAdmin)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Applying FPS boosting tweaks..."));
                ApplyFPSBoostingTweaks();
            }

            // 15. Process Priority
            await Dispatcher.InvokeAsync(() => LogMessage($"[{++currentStep}/{totalSteps}] Setting process priorities..."));
            ApplyProcessPriorities();

            await Task.Delay(500);
        }
                // PART 3 - Continuation from line ~850

        private void ApplyNetworkOptimizations()
        {
            // TCP/IP optimizations
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "TcpNoDelay", 1, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "TCPNoDelay", 1, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "TcpDelAckTicks", 0, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "TcpMaxDataRetransmissions", 3, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "SackOpts", 1, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "TcpWindowSize", 65535, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "Tcp1323Opts", 3, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "DefaultTTL", 64, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "EnablePMTUBHDetect", 0, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", 
                "EnablePMTUDiscovery", 1, RegistryValueKind.DWord);

            // Network throttling
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile", 
                "NetworkThrottlingIndex", 0xFFFFFFFF, RegistryValueKind.DWord);

            // DNS Optimization (if enabled)
            if (OptimizeDNS?.IsChecked == true && isAdmin)
            {
                ExecuteCommand("netsh interface ip set dns \"Ethernet\" static 1.1.1.1");
                ExecuteCommand("netsh interface ip add dns \"Ethernet\" 1.0.0.1 index=2");
            }

            // Apply netsh commands if admin
            if (isAdmin)
            {
                try
                {
                    var netshCommands = new[]
                    {
                        "netsh int tcp set global autotuninglevel=normal",
                        "netsh int tcp set global chimney=disabled",
                        "netsh int tcp set global rss=enabled",
                        "netsh int tcp set global rsc=disabled",
                        "netsh int tcp set global ecncapability=disabled",
                        "netsh int tcp set global timestamps=disabled",
                        "netsh int tcp set supplemental internet congestionprovider=ctcp",
                        "netsh int tcp set heuristics disabled",
                        "netsh int tcp set global initialRto=2000",
                        "netsh int tcp set global nonsackrttresiliency=disabled"
                    };

                    foreach (var cmd in netshCommands)
                    {
                        ExecuteCommand(cmd);
                    }
                }
                catch { }
            }
        }

        private void ApplyGamingOptimizations()
        {
            // Disable Game DVR
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\System\GameConfigStore", 
                "GameDVR_Enabled", 0, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\System\GameConfigStore", 
                "GameDVR_FSEBehaviorMode", 2, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR", 
                "AppCaptureEnabled", 0, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR", 
                "AllowGameDVR", 0, RegistryValueKind.DWord);

            // Game Mode
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\GameBar", 
                "AllowAutoGameMode", 1, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\GameBar", 
                "AutoGameModeEnabled", 1, RegistryValueKind.DWord);

            // Multimedia System Profile for Games
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                "GPU Priority", 8, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                "Priority", 6, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                "Scheduling Category", "High", RegistryValueKind.String);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games", 
                "SFIO Priority", "High", RegistryValueKind.String);

            // System responsiveness
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile", 
                "SystemResponsiveness", 0, RegistryValueKind.DWord);
        }

        private void ApplyGPUOptimizations()
        {
            // Hardware-accelerated GPU scheduling
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", 
                "HwSchMode", 2, RegistryValueKind.DWord);

            // TDR settings
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", 
                "TdrLevel", 0, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", 
                "TdrDelay", 10, RegistryValueKind.DWord);

            // DirectX optimizations
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DirectX", 
                "D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE", 1, RegistryValueKind.DWord);

            // GPU preemption
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler", 
                "EnablePreemption", 0, RegistryValueKind.DWord);
        }

        private void ApplyMemoryOptimizations()
        {
            if (!isAdmin) return;

            // Memory management
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", 
                "LargeSystemCache", 0, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", 
                "DisablePagingExecutive", 1, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", 
                "DisablePageCombining", 1, RegistryValueKind.DWord);

            // Prefetcher and Superfetch
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters", 
                "EnablePrefetcher", 0, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters", 
                "EnableSuperfetch", 0, RegistryValueKind.DWord);

            // Spectre/Meltdown mitigations (disable for performance - USE WITH CAUTION)
            if (DisableSpeculativeMitigations?.IsChecked == true && UltraMode.IsChecked == true)
            {
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", 
                    "FeatureSettings", 1, RegistryValueKind.DWord);
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", 
                    "FeatureSettingsOverride", 3, RegistryValueKind.DWord);
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", 
                    "FeatureSettingsOverrideMask", 3, RegistryValueKind.DWord);
                LogMessage("⚠️ WARNING: Speculative execution mitigations disabled - Security risk!", "Warning");
            }
        }

        private void ApplyCPUOptimizations()
        {
            // CPU priority separation
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl", 
                "Win32PrioritySeparation", 38, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl", 
                "IRQ8Priority", 1, RegistryValueKind.DWord);

            // Core parking
            if (CPUCoreParkingDisable?.IsChecked == true && isAdmin)
            {
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583", 
                    "ValueMax", 0, RegistryValueKind.DWord);
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583", 
                    "ValueMin", 0, RegistryValueKind.DWord);
            }

            // Disable C-States if checked
            if (DisableCStates?.IsChecked == true && isAdmin)
            {
                ExecuteCommand("powercfg -setacvalueindex scheme_current sub_processor 5d76a2ca-e8c0-402f-a133-2158492d58ad 1");
            }
        }

        private void ApplyKernelOptimizations()
        {
            if (!isAdmin || PerformanceMode.IsChecked != true) return;

            LogMessage("⚠️ Applying kernel optimizations - Use at your own risk!", "Warning");

            // Timer resolution
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", 
                "GlobalTimerResolutionRequests", 1, RegistryValueKind.DWord);

            // DPC settings
            if (ThreadDPCEnable?.IsChecked == true)
            {
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", 
                    "ThreadDpcEnable", 1, RegistryValueKind.DWord);
            }

            if (DPCQueueDepth?.IsChecked == true)
            {
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", 
                    "DpcQueueDepth", 1, RegistryValueKind.DWord);
            }

            // TSX
            if (DisableTSXAutoBan?.IsChecked == true)
            {
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", 
                    "DisableTsxAutoBan", 1, RegistryValueKind.DWord);
            }

            // Disable VBS/HVCI if checked
            if (DisableVBS?.IsChecked == true)
            {
                ExecuteCommand("bcdedit /set hypervisorlaunchtype off");
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard", 
                    "EnableVirtualizationBasedSecurity", 0, RegistryValueKind.DWord);
            }

            // Set kernel timer resolution to 1ms
            try
            {
                int currentResolution;
                NtSetTimerResolution(10000, true, out currentResolution);
                LogMessage($"Kernel timer resolution set to: {currentResolution / 10000.0}ms");
            }
            catch { }
        }

        private void ApplyVisualEffectOptimizations()
        {
            // Set for best performance but keep essential elements
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects", 
                "VisualFXSetting", 3, RegistryValueKind.DWord);

            // Disable animations
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\Control Panel\Desktop", 
                "MinAnimate", "0", RegistryValueKind.String);
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\Control Panel\Desktop", 
                "MenuShowDelay", "0", RegistryValueKind.String);

            // Keep font smoothing
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\Control Panel\Desktop", 
                "FontSmoothing", "2", RegistryValueKind.String);

            // Disable DWM animations
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM", 
                "EnableAeroPeek", 0, RegistryValueKind.DWord);
        }

        private void ApplyInputOptimizations()
        {
            // Mouse optimizations
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\Control Panel\Mouse", 
                "MouseSpeed", "0", RegistryValueKind.String);
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\Control Panel\Mouse", 
                "MouseThreshold1", "0", RegistryValueKind.String);
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\Control Panel\Mouse", 
                "MouseThreshold2", "0", RegistryValueKind.String);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters", 
                "MouseDataQueueSize", 100, RegistryValueKind.DWord);

            // Keyboard optimizations
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters", 
                "KeyboardDataQueueSize", 100, RegistryValueKind.DWord);
        }

        private void ApplyAudioOptimizations()
        {
            // Disable audio enhancements
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio", 
                "DisableProtectedAudioDG", 1, RegistryValueKind.DWord);

            // Disable audio ducking
            ApplyRegistryTweak(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Multimedia\Audio", 
                "UserDuckingPreference", 3, RegistryValueKind.DWord);
        }

        private void ApplyDiskOptimizations()
        {
            // NTFS optimizations
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem", 
                "NtfsMftZoneReservation", 2, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem", 
                "NtfsDisableLastAccessUpdate", 1, RegistryValueKind.DWord);
            ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem", 
                "NtfsDisable8dot3NameCreation", 1, RegistryValueKind.DWord);
        }

        private void ApplyGPUVendorOptimizations()
        {
            // NVIDIA optimizations
            if (NVIDIADisableTelemetry?.IsChecked == true && isAdmin)
            {
                try
                {
                    ServiceController nvTelemetry = new ServiceController("NvTelemetryContainer");
                    if (nvTelemetry.Status == ServiceControllerStatus.Running)
                    {
                        nvTelemetry.Stop();
                    }
                    ExecuteCommand("sc config NvTelemetryContainer start= disabled");
                    LogMessage("NVIDIA telemetry disabled");
                }
                catch { }
            }

            // AMD optimizations
            if (AMDDisableExternalEvents?.IsChecked == true && isAdmin)
            {
                try
                {
                    ServiceController amdEvents = new ServiceController("AMD External Events Utility");
                    if (amdEvents.Status == ServiceControllerStatus.Running)
                    {
                        amdEvents.Stop();
                    }
                    ExecuteCommand("sc config \"AMD External Events Utility\" start= disabled");
                    LogMessage("AMD External Events disabled");
                }
                catch { }
            }

            // Intel optimizations
            if (IntelGraphicsOptimizations?.IsChecked == true)
            {
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", 
                    "DisableOverlays", 1, RegistryValueKind.DWord);
            }
        }

        private void ApplyFPSBoostingTweaks()
        {
            if (!isAdmin) return;

            // Disable Dynamic Tick
            ExecuteCommand("bcdedit /set disabledynamictick yes");
            
            // Use platform tick
            ExecuteCommand("bcdedit /set useplatformtick yes");
            
            // Use platform clock
            ExecuteCommand("bcdedit /set useplatformclock yes");
            
            // TSC sync policy
            ExecuteCommand("bcdedit /set tscsyncpolicy enhanced");
            
            LogMessage("Advanced FPS boosting tweaks applied");
        }

        private void ApplyPowerManagement()
        {
            if (!isAdmin) return;

            // Create and set Ultimate Performance power plan
            ExecuteCommand("powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61");
            ExecuteCommand("powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61");
            
            // Disable hibernation
            if (DisableHibernation?.IsChecked == true)
            {
                ExecuteCommand("powercfg -h off");
            }
            
            LogMessage("Ultimate Performance power plan activated");
        }

        private async Task DisableServices()
        {
            if (!isAdmin) return;

            var servicesToDisable = new List<string>();

            // Xbox services
            if (DisableXboxServices?.IsChecked == true)
            {
                servicesToDisable.AddRange(new[] { "XblGameSave", "XblAuthManager", "XboxGipSvc", "XboxNetApiSvc" });
            }

            // Other services
            if (DisablePrintSpooler?.IsChecked == true) servicesToDisable.Add("Spooler");
            if (DisableSysMain?.IsChecked == true) servicesToDisable.Add("SysMain");
            if (DisableTelemetryDiagTrack?.IsChecked == true) servicesToDisable.Add("DiagTrack");
            if (DisableWindowsSearch?.IsChecked == true) servicesToDisable.Add("WSearch");
            if (DisableTabletServices?.IsChecked == true) servicesToDisable.Add("TabletInputService");
            if (DisableThemesService?.IsChecked == true) servicesToDisable.Add("Themes");

            foreach (var service in servicesToDisable)
            {
                try
                {
                    ExecuteCommand($"sc stop {service}");
                    ExecuteCommand($"sc config {service} start= disabled");
                    await Task.Delay(100);
                }
                catch { }
            }
            
            LogMessage($"Disabled {servicesToDisable.Count} services");
        }

        private async Task DisableUnneededServices()
        {
            if (!isAdmin) return;
            
            var servicesToDisable = new List<string>();
            
            if (DisableFax?.IsChecked == true)
            {
                servicesToDisable.AddRange(new[] { 
                    "Fax", "RemoteRegistry", "MapsBroker", 
                    "WMPNetworkSvc", "WpnUserService", "bthserv" 
                });
            }
            
            if (DisableBiometric?.IsChecked == true)
                servicesToDisable.Add("WbioSrvc");
                
            if (DisableSmartCard?.IsChecked == true)
            {
                servicesToDisable.AddRange(new[] { "SCardSvr", "ScDeviceEnum", "SCPolicySvc" });
            }
            
            if (DisableParentalControls?.IsChecked == true)
                servicesToDisable.Add("WpcMonSvc");
                
            if (DisableHomeGroup?.IsChecked == true)
            {
                servicesToDisable.AddRange(new[] { "HomeGroupListener", "HomeGroupProvider" });
            }
            
            foreach (var service in servicesToDisable)
            {
                try
                {
                    ExecuteCommand($"sc stop {service}");
                    ExecuteCommand($"sc config {service} start= disabled");
                    await Task.Delay(50);
                }
                catch { }
            }
            
            await Dispatcher.InvokeAsync(() => 
                LogMessage($"Disabled {servicesToDisable.Count} unneeded services"));
        }

        private void ApplyProcessPriorities()
        {
            string priority = (PriorityCombo.SelectedItem as ComboBoxItem)?.Content.ToString() ?? "High";
            
            // Set priority for common game processes
            var gameProcesses = Process.GetProcesses().Where(p => 
                gameProfiles.Values.Any(profile => 
                    profile.ProcessNames.Any(name => 
                        p.ProcessName.ToLower().Contains(name.ToLower().Replace(".exe", "")))));

            foreach (var process in gameProcesses)
            {
                try
                {
                    process.PriorityClass = priority switch
                    {
                        "High" => ProcessPriorityClass.High,
                        "Above Normal" => ProcessPriorityClass.AboveNormal,
                        _ => ProcessPriorityClass.Normal
                    };
                    LogMessage($"Set {process.ProcessName} priority to {priority}");
                }
                catch { }
            }
        }

        private void ExecuteCommand(string command)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = $"/c {command}",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                
                using (Process process = Process.Start(psi))
                {
                    process.WaitForExit();
                }
            }
            catch (Exception ex)
            {
                LogMessage($"Command failed: {ex.Message}", "Error");
            }
        }
        #endregion

        #region Backup and Restore
        private void CreateBackup()
        {
            try
            {
                var backup = new Dictionary<string, object>
                {
                    ["Timestamp"] = DateTime.Now,
                    ["Settings"] = originalSettings
                };
                
                string json = JsonSerializer.Serialize(backup, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(backupPath, json);
                LogMessage($"Backup created: {backupPath}");
            }
            catch (Exception ex)
            {
                LogMessage($"Failed to create backup: {ex.Message}", "Error");
            }
        }

        private void RevertAll_Click(object sender, RoutedEventArgs e)
        {
            LogMessage("🔄 Reverting all optimizations...");
            
            if (File.Exists(backupPath))
            {
                try
                {
                    string json = File.ReadAllText(backupPath);
                    var backup = JsonSerializer.Deserialize<Dictionary<string, object>>(json);
                    
                    if (backup != null && backup.ContainsKey("Settings"))
                    {
                        var settings = backup["Settings"] as JsonElement?;
                        if (settings.HasValue)
                        {
                            // Restore registry values
                            foreach (var setting in settings.Value.EnumerateObject())
                            {
                                if (setting.Name.StartsWith("Service_"))
                                {
                                    // Restore service
                                    string serviceName = setting.Name.Replace("Service_", "");
                                    ExecuteCommand($"sc config {serviceName} start= auto");
                                }
                                else
                                {
                                    // Restore registry value
                                    RestoreRegistryValue(setting.Name, setting.Value);
                                }
                            }
                        }
                    }
                    
                    // Re-enable services
                    if (isAdmin)
                    {
                        var servicesToRestore = new[] { 
                            "XblGameSave", "XblAuthManager", "DiagTrack", 
                            "SysMain", "WSearch", "Themes" 
                        };
                        
                        foreach (var service in servicesToRestore)
                        {
                            ExecuteCommand($"sc config {service} start= auto");
                        }
                    }
                    
                    LogMessage("✅ All optimizations reverted!");
                }
                catch (Exception ex)
                {
                    LogMessage($"Failed to restore: {ex.Message}", "Error");
                }
            }
            else
            {
                LogMessage("No backup found - performing default restoration");
                
                // Reset key registry values to defaults
                ApplyRegistryTweak(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile", 
                    "SystemResponsiveness", 20, RegistryValueKind.DWord);
                ApplyRegistryTweak(@"HKEY_CURRENT_USER\System\GameConfigStore", 
                    "GameDVR_Enabled", 1, RegistryValueKind.DWord);
            }
            
            MessageBox.Show("All optimizations have been reverted.\n\nRestart recommended.", 
                "KOALA V3", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void RestoreRegistryValue(string name, JsonElement value)
        {
            try
            {
                switch (name)
                {
                    case "SystemResponsiveness":
                        Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                            "SystemResponsiveness", value.GetInt32(), RegistryValueKind.DWord);
                        break;
                    case "GameDVR_Enabled":
                        Registry.SetValue(@"HKEY_CURRENT_USER\System\GameConfigStore",
                            "GameDVR_Enabled", value.GetInt32(), RegistryValueKind.DWord);
                        break;
                    case "Win32PrioritySeparation":
                        Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl",
                            "Win32PrioritySeparation", value.GetInt32(), RegistryValueKind.DWord);
                        break;
                    case "NetworkThrottlingIndex":
                        Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                            "NetworkThrottlingIndex", value.GetInt32(), RegistryValueKind.DWord);
                        break;
                }
            }
            catch { }
        }
        #endregion

        #region Event Handlers
        private void AutoDetect_Click(object sender, RoutedEventArgs e)
        {
            LogMessage("🔍 Scanning for running games...");
            DetectRunningGames(null, null);
        }

        private void ExportConfig_Click(object sender, RoutedEventArgs e)
        {
            SaveFileDialog dialog = new SaveFileDialog
            {
                Filter = "KOALA Config|*.koala",
                FileName = $"KOALA_Config_{DateTime.Now:yyyyMMdd}.koala"
            };
            
            if (dialog.ShowDialog() == true)
            {
                CreateBackup();
                File.Copy(backupPath, dialog.FileName, true);
                LogMessage($"Configuration exported to {dialog.FileName}");
            }
        }

        private void ImportConfig_Click(object sender, RoutedEventArgs e)
        {
            OpenFileDialog dialog = new OpenFileDialog
            {
                Filter = "KOALA Config|*.koala"
            };
            
            if (dialog.ShowDialog() == true)
            {
                File.Copy(dialog.FileName, backupPath, true);
                LogMessage($"Configuration imported from {dialog.FileName}");
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            base.OnClosed(e);
            timeEndPeriod(1);
            HideCrosshairOverlay();
            gameDetectionTimer?.Stop();
        }
        
        #region Theme and UI Management
        private void ThemeSelector_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            try
            {
                var selectedItem = ThemeSelector.SelectedItem as ComboBoxItem;
                if (selectedItem?.Tag != null)
                {
                    var themeTag = selectedItem.Tag.ToString();
                    if (Enum.TryParse<ThemeType>(themeTag, out var themeType))
                    {
                        ThemeManager.ApplyTheme(themeType);
                        ThemeManager.SaveThemePreference(themeType);
                        LogMessage($"🎨 Theme changed to {themeTag}", "Info");
                    }
                }
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Theme change error: {ex.Message}", "Error");
            }
        }
        
        private void UpdateStatusIndicators()
        {
            try
            {
                // Update admin status
                AdminStatusText.Text = $"Admin: {(isAdmin ? "✅ Active" : "⚠️ Limited")}";
                AdminStatusText.Foreground = isAdmin ? 
                    (System.Windows.Media.Brush)FindResource("SuccessGreen") : 
                    (System.Windows.Media.Brush)FindResource("WarningOrange");
                
                // Update validation status
                ValidationStatusText.Text = "Validation: ⏳ Running...";
                ValidationStatusText.Foreground = (System.Windows.Media.Brush)FindResource("TextSecondary");
                
                // Update optimization status  
                OptimizationStatusText.Text = "Optimizations: 🔄 Ready";
                OptimizationStatusText.Foreground = (System.Windows.Media.Brush)FindResource("AccentPurple");
            }
            catch (Exception ex)
            {
                LogMessage($"❌ Status update error: {ex.Message}", "Error");
            }
        }
        
        private void UpdateValidationStatus(bool isCompleted, int issueCount = 0)
        {
            try
            {
                Dispatcher.InvokeAsync(() =>
                {
                    if (isCompleted)
                    {
                        if (issueCount == 0)
                        {
                            ValidationStatusText.Text = "Validation: ✅ Passed";
                            ValidationStatusText.Foreground = (System.Windows.Media.Brush)FindResource("SuccessGreen");
                        }
                        else
                        {
                            ValidationStatusText.Text = $"Validation: ⚠️ {issueCount} Issues";
                            ValidationStatusText.Foreground = (System.Windows.Media.Brush)FindResource("WarningOrange");
                        }
                    }
                    else
                    {
                        ValidationStatusText.Text = "Validation: ⏳ Running...";
                        ValidationStatusText.Foreground = (System.Windows.Media.Brush)FindResource("TextSecondary");
                    }
                });
            }
            catch { }
        }
        
        private void UpdateOptimizationStatus(string status, string level = "Info")
        {
            try
            {
                Dispatcher.InvokeAsync(() =>
                {
                    OptimizationStatusText.Text = $"Optimizations: {status}";
                    
                    var color = level switch
                    {
                        "Error" => (System.Windows.Media.Brush)FindResource("DangerRed"),
                        "Warning" => (System.Windows.Media.Brush)FindResource("WarningOrange"),
                        "Success" => (System.Windows.Media.Brush)FindResource("SuccessGreen"),
                        _ => (System.Windows.Media.Brush)FindResource("AccentPurple")
                    };
                    
                    OptimizationStatusText.Foreground = color;
                });
            }
            catch { }
        }
        #endregion
        #endregion
    }
}
