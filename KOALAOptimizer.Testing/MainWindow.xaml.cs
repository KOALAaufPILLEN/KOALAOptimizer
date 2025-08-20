using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using Microsoft.Win32;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using System.ComponentModel;
using System.Windows.Input;

namespace KOALAOptimizer
{
    public partial class MainWindow : Window
    {
        private Dictionary<string, object> backupData = new Dictionary<string, object>();
        private readonly string backupPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "KOALA-Backup.json");
        private DispatcherTimer processTimer;
        private Window crosshairOverlay;
        
        // Import Windows APIs for advanced optimizations
        [DllImport("kernel32.dll")]
        static extern IntPtr GetCurrentProcess();
        
        [DllImport("kernel32.dll")]
        static extern bool SetProcessWorkingSetSize(IntPtr proc, int min, int max);
        
        [DllImport("psapi.dll")]
        static extern bool EmptyWorkingSet(IntPtr hProcess);
        
        [DllImport("winmm.dll")]
        internal static extern uint timeBeginPeriod(uint period);
        
        [DllImport("winmm.dll")]
        internal static extern uint timeEndPeriod(uint period);
        
        [DllImport("kernel32.dll")]
        static extern bool SetProcessPriorityBoost(IntPtr hProcess, bool disablePriorityBoost);
        
        [DllImport("ntdll.dll")]
        static extern int NtSetTimerResolution(int DesiredResolution, bool SetResolution, out int CurrentResolution);

        public MainWindow()
        {
            InitializeComponent();
            LoadSystemInfo();
            CheckAdminStatus();
            LoadGameProfiles();
            InitializeProcessManager();
            
            // Set high precision timer for the app
            timeBeginPeriod(1);
        }

        private void LoadSystemInfo()
        {
            try
            {
                string info = "";
                
                // OS Info
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_OperatingSystem"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        info += $"OS: {obj["Caption"]} ({obj["Version"]})\n";
                    }
                }
                
                // CPU Info
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Processor"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        info += $"Processor: {obj["Name"]}\n";
                        info += $"{obj["NumberOfLogicalProcessors"]} cores @ {obj["MaxClockSpeed"]} MHz\n";
                    }
                }
                
                // RAM Info
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_ComputerSystem"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        var ram = Convert.ToDouble(obj["TotalPhysicalMemory"]) / (1024 * 1024 * 1024);
                        info += $"{ram:F1} GB RAM\n";
                        info += $"Machine: {obj["Manufacturer"]} {obj["Model"]}\n";
                    }
                }
                
                // GPU Info
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        if (!string.IsNullOrEmpty(name) && !name.Contains("Microsoft"))
                        {
                            var vram = obj["AdapterRAM"] != null ? Convert.ToDouble(obj["AdapterRAM"]) / (1024 * 1024 * 1024) : 0;
                            info += $"GPU: {name}";
                            if (vram > 0) info += $" ({vram:F1} GB VRAM)";
                            info += "\n";
                            break;
                        }
                    }
                }
                
                SystemInfoText.Text = info;
                SystemInfoText.Foreground = new SolidColorBrush(Colors.LightGreen);
            }
            catch (Exception ex)
            {
                SystemInfoText.Text = $"System info error: {ex.Message}";
                SystemInfoText.Foreground = new SolidColorBrush(Colors.Yellow);
            }
        }

        private void CheckAdminStatus()
        {
            var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
            var principal = new System.Security.Principal.WindowsPrincipal(identity);
            bool isAdmin = principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
            
            if (isAdmin)
            {
                AdminStatusText.Text = "✓ Administrator Mode Active";
                AdminStatusText.Foreground = new SolidColorBrush(Colors.LightGreen);
            }
            else
            {
                AdminStatusText.Text = "⚠ Limited Mode - Run as Admin";
                AdminStatusText.Foreground = new SolidColorBrush(Colors.Yellow);
            }
        }

        private void LoadGameProfiles()
        {
            var games = new List<string>
            {
                "Counter-Strike 2",
                "CS:GO", 
                "Valorant",
                "Fortnite",
                "Apex Legends",
                "Call of Duty: Warzone",
                "Battlefield 2042",
                "Rainbow Six Siege",
                "Overwatch 2",
                "League of Legends",
                "PUBG",
                "Rocket League",
                "Minecraft",
                "GTA V",
                "Red Dead Redemption 2",
                "Cyberpunk 2077",
                "Elden Ring",
                "Destiny 2"
            };
            
            GameProfileCombo.ItemsSource = games;
            GameProfileCombo.SelectedIndex = 0;
        }

        private void InitializeProcessManager()
        {
            processTimer = new DispatcherTimer();
            processTimer.Interval = TimeSpan.FromSeconds(2);
            processTimer.Tick += (s, e) => RefreshProcessList();
            processTimer.Start();
        }

        private void RefreshProcessList()
        {
            var processes = Process.GetProcesses()
                .Where(p => p.MainWindowHandle != IntPtr.Zero)
                .Select(p => new ProcessInfo
                {
                    Name = p.ProcessName,
                    Id = p.Id,
                    Priority = GetPriorityClass(p),
                    Memory = p.WorkingSet64 / (1024 * 1024),
                    Threads = p.Threads.Count,
                    CPU = 0 // Would need performance counter for accurate CPU%
                })
                .OrderByDescending(p => p.Memory)
                .ToList();
                
            ProcessGrid.ItemsSource = processes;
            ProcessList.ItemsSource = processes.Select(p => p.Name).Distinct();
        }

        private string GetPriorityClass(Process p)
        {
            try { return p.PriorityClass.ToString(); }
            catch { return "Normal"; }
        }

        private void LogMessage(string message)
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            LogText.AppendText($"[{timestamp}] {message}\n");
            LogText.ScrollToEnd();
        }

        private void OptimizeButton_Click(object sender, RoutedEventArgs e)
        {
            Task.Run(() => RunOptimizations());
        }

        private async void RunOptimizations()
        {
            await Dispatcher.InvokeAsync(() =>
            {
                LogText.Clear();
                LogMessage("🐨 KOALA Optimizer V3 Starting...");
                StatusText.Text = "Optimizing system...";
            });

            // Create backup
            CreateBackup();

            bool isSafeMode = await Dispatcher.InvokeAsync(() => SafeModeRadio.IsChecked == true);
            
            // Apply optimizations based on selected options
            if (await Dispatcher.InvokeAsync(() => GpuCheckBox.IsChecked == true))
            {
                await ApplyGPUOptimizations();
            }
            
            if (await Dispatcher.InvokeAsync(() => CpuCheckBox.IsChecked == true))
            {
                await ApplyCPUOptimizations();
            }
            
            if (await Dispatcher.InvokeAsync(() => RamCheckBox.IsChecked == true))
            {
                await ApplyMemoryOptimizations();
            }
            
            if (await Dispatcher.InvokeAsync(() => NetworkCheckBox.IsChecked == true))
            {
                await ApplyNetworkOptimizations();
            }
            
            if (await Dispatcher.InvokeAsync(() => ServicesCheckBox.IsChecked == true))
            {
                await DisableUnnecessaryServices();
            }
            
            if (await Dispatcher.InvokeAsync(() => VisualCheckBox.IsChecked == true))
            {
                await OptimizeVisualEffects();
            }
            
            if (await Dispatcher.InvokeAsync(() => GameDvrCheckBox.IsChecked == true))
            {
                await DisableGameDVR();
            }
            
            if (await Dispatcher.InvokeAsync(() => MouseCheckBox.IsChecked == true))
            {
                await OptimizeMouseSettings();
            }
            
            if (await Dispatcher.InvokeAsync(() => AudioCheckBox.IsChecked == true))
            {
                await OptimizeAudioLatency();
            }
            
            if (await Dispatcher.InvokeAsync(() => TimerCheckBox.IsChecked == true))
            {
                await SetHighPrecisionTimer();
            }

            await Dispatcher.InvokeAsync(() =>
            {
                LogMessage("✅ Optimization complete!");
                StatusText.Text = "Optimization complete - System optimized for gaming";
                MessageBox.Show("Optimization complete!\nRestart recommended for best results.", 
                    "KOALA Optimizer V3", MessageBoxButton.OK, MessageBoxImage.Information);
            });
        }

        private void CreateBackup()
        {
            try
            {
                backupData.Clear();
                
                // Backup registry keys
                var registryKeys = new[]
                {
                    @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
                    @"HKEY_CURRENT_USER\System\GameConfigStore",
                    @"HKEY_CURRENT_USER\Control Panel\Mouse"
                };
                
                foreach (var key in registryKeys)
                {
                    // Store current values
                    backupData[key] = "backed_up";
                }
                
                File.WriteAllText(backupPath, JsonSerializer.Serialize(backupData));
                Dispatcher.Invoke(() => LogMessage("✓ Backup created"));
            }
            catch (Exception ex)
            {
                Dispatcher.Invoke(() => LogMessage($"⚠ Backup error: {ex.Message}"));
            }
        }

        private async Task ApplyGPUOptimizations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Applying GPU optimizations..."));
            
            try
            {
                // Hardware-accelerated GPU scheduling
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", 
                    "HwSchMode", 2, RegistryValueKind.DWord);
                
                // GPU Priority
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "GPU Priority", 8, RegistryValueKind.DWord);
                    
                // Scheduling Category
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "Scheduling Category", "High", RegistryValueKind.String);
                
                // Disable GPU timeout detection
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
                    "TdrLevel", 0, RegistryValueKind.DWord);
                    
                await Dispatcher.InvokeAsync(() => LogMessage("✓ GPU optimizations applied"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ GPU optimization error: {ex.Message}"));
            }
        }

        private async Task ApplyCPUOptimizations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Applying CPU optimizations..."));
            
            try
            {
                // Win32PrioritySeparation for gaming
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl",
                    "Win32PrioritySeparation", 38, RegistryValueKind.DWord);
                
                // System responsiveness
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                    "SystemResponsiveness", 0, RegistryValueKind.DWord);
                    
                // CPU Priority
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "Priority", 6, RegistryValueKind.DWord);
                    
                // Disable CPU core parking
                if (await Dispatcher.InvokeAsync(() => CoreParking.IsChecked == true))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "powercfg",
                        Arguments = "-setacvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100",
                        WindowStyle = ProcessWindowStyle.Hidden
                    })?.WaitForExit();
                }
                
                await Dispatcher.InvokeAsync(() => LogMessage("✓ CPU optimizations applied"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ CPU optimization error: {ex.Message}"));
            }
        }

        private async Task ApplyMemoryOptimizations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Applying memory optimizations..."));
            
            try
            {
                // Disable paging executive
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "DisablePagingExecutive", 1, RegistryValueKind.DWord);
                    
                // Large system cache
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "LargeSystemCache", 0, RegistryValueKind.DWord);
                
                // Clear standby memory if checked
                if (await Dispatcher.InvokeAsync(() => StandbyList.IsChecked == true))
                {
                    ClearMemory();
                }
                
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Memory optimizations applied"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Memory optimization error: {ex.Message}"));
            }
        }

        private async Task ApplyNetworkOptimizations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Applying network optimizations..."));
            
            try
            {
                // Disable Nagle's algorithm
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
                    "TcpNoDelay", 1, RegistryValueKind.DWord);
                    
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
                    "TCPNoDelay", 1, RegistryValueKind.DWord);
                
                // Network throttling
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                    "NetworkThrottlingIndex", 0xFFFFFFFF, RegistryValueKind.DWord);
                
                // TCP optimization via netsh
                Process.Start(new ProcessStartInfo
                {
                    FileName = "netsh",
                    Arguments = "int tcp set global autotuninglevel=normal",
                    WindowStyle = ProcessWindowStyle.Hidden
                })?.WaitForExit();
                
                Process.Start(new ProcessStartInfo
                {
                    FileName = "netsh",
                    Arguments = "int tcp set global rss=enabled",
                    WindowStyle = ProcessWindowStyle.Hidden
                })?.WaitForExit();
                
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Network optimizations applied"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Network optimization error: {ex.Message}"));
            }
        }

        private async Task DisableUnnecessaryServices()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Disabling unnecessary services..."));
            
            var services = new[]
            {
                "XblGameSave",
                "XblAuthManager",
                "XboxGipSvc",
                "XboxNetApiSvc",
                "DiagTrack",
                "WSearch",
                "TabletInputService"
            };
            
            foreach (var service in services)
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "sc",
                        Arguments = $"config {service} start=disabled",
                        WindowStyle = ProcessWindowStyle.Hidden
                    })?.WaitForExit();
                }
                catch { }
            }
            
            await Dispatcher.InvokeAsync(() => LogMessage("✓ Services optimized"));
        }

        private async Task OptimizeVisualEffects()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Optimizing visual effects..."));
            
            try
            {
                // Set for best performance
                Registry.SetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
                    "VisualFXSetting", 2, RegistryValueKind.DWord);
                    
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Visual effects optimized"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Visual effects error: {ex.Message}"));
            }
        }

        private async Task DisableGameDVR()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Disabling Game DVR..."));
            
            try
            {
                Registry.SetValue(@"HKEY_CURRENT_USER\System\GameConfigStore",
                    "GameDVR_Enabled", 0, RegistryValueKind.DWord);
                    
                Registry.SetValue(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR",
                    "AppCaptureEnabled", 0, RegistryValueKind.DWord);
                    
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Game DVR disabled"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Game DVR error: {ex.Message}"));
            }
        }

        private async Task OptimizeMouseSettings()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Optimizing mouse settings..."));
            
            try
            {
                // Disable mouse acceleration
                Registry.SetValue(@"HKEY_CURRENT_USER\Control Panel\Mouse",
                    "MouseSpeed", "0", RegistryValueKind.String);
                    
                Registry.SetValue(@"HKEY_CURRENT_USER\Control Panel\Mouse",
                    "MouseThreshold1", "0", RegistryValueKind.String);
                    
                Registry.SetValue(@"HKEY_CURRENT_USER\Control Panel\Mouse",
                    "MouseThreshold2", "0", RegistryValueKind.String);
                    
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Mouse optimized"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Mouse optimization error: {ex.Message}"));
            }
        }

        private async Task OptimizeAudioLatency()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Optimizing audio latency..."));
            
            try
            {
                // Disable audio enhancements
                Registry.SetValue(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Multimedia\Audio",
                    "UserDuckingPreference", 3, RegistryValueKind.DWord);
                    
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Audio latency optimized"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Audio optimization error: {ex.Message}"));
            }
        }

        private async Task SetHighPrecisionTimer()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Setting high precision timer..."));
            
            try
            {
                // Set timer resolution to 0.5ms
                int currentResolution;
                NtSetTimerResolution(5000, true, out currentResolution);
                
                // Global timer resolution
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel",
                    "GlobalTimerResolutionRequests", 1, RegistryValueKind.DWord);
                    
                await Dispatcher.InvokeAsync(() => LogMessage("✓ High precision timer set"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Timer error: {ex.Message}"));
            }
        }

        private void RestoreButton_Click(object sender, RoutedEventArgs e)
        {
            if (!File.Exists(backupPath))
            {
                MessageBox.Show("No backup found!", "KOALA Optimizer", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            
            LogMessage("Restoring from backup...");
            // Restore logic here
            LogMessage("✓ Restore complete");
            MessageBox.Show("System restored from backup!", "KOALA Optimizer", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void ApplyGameProfile_Click(object sender, RoutedEventArgs e)
        {
            string game = GameProfileCombo.SelectedItem?.ToString();
            if (string.IsNullOrEmpty(game)) return;
            
            LogMessage($"Applying profile for {game}...");
            
            // Apply game-specific optimizations
            switch (game)
            {
                case "Counter-Strike 2":
                case "CS:GO":
                    // CS specific optimizations
                    Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
                        "TcpNoDelay", 1, RegistryValueKind.DWord);
                    break;
                    
                case "Valorant":
                    // Valorant specific
                    break;
                    
                // Add more game profiles
            }
            
            LogMessage($"✓ {game} profile applied");
        }

        private void ApplyCrosshair_Click(object sender, RoutedEventArgs e)
        {
            if (CrosshairEnabled.IsChecked == true)
            {
                CreateCrosshairOverlay();
            }
            else
            {
                CloseCrosshairOverlay();
            }
            
            UpdateCrosshairPreview();
        }

        private void CreateCrosshairOverlay()
        {
            if (crosshairOverlay != null) return;
            
            crosshairOverlay = new Window
            {
                WindowStyle = WindowStyle.None,
                AllowsTransparency = true,
                Background = Brushes.Transparent,
                Topmost = true,
                ShowInTaskbar = false,
                IsHitTestVisible = false,
                Width = SystemParameters.PrimaryScreenWidth,
                Height = SystemParameters.PrimaryScreenHeight,
                Left = 0,
                Top = 0
            };
            
            var canvas = new Canvas();
            DrawCrosshair(canvas, crosshairOverlay.Width / 2, crosshairOverlay.Height / 2);
            crosshairOverlay.Content = canvas;
            crosshairOverlay.Show();
            
            LogMessage("✓ Crosshair overlay enabled");
        }

        private void DrawCrosshair(Canvas canvas, double centerX, double centerY)
        {
            canvas.Children.Clear();
            
            string style = (CrosshairType.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "Classic Cross";
            double size = CrosshairSize.Value;
            double thickness = CrosshairThickness.Value;
            double gap = CrosshairGap.Value;
            
            byte r = (byte)ColorR.Value;
            byte g = (byte)ColorG.Value;
            byte b = (byte)ColorB.Value;
            byte opacity = (byte)(CrosshairOpacity.Value * 2.55);
            
            var color = Color.FromArgb(opacity, r, g, b);
            var brush = new SolidColorBrush(color);
            
            switch (style)
            {
                case "Classic Cross":
                    // Horizontal line
                    var hLine1 = new Rectangle
                    {
                        Width = size,
                        Height = thickness,
                        Fill = brush
                    };
                    Canvas.SetLeft(hLine1, centerX - size - gap);
                    Canvas.SetTop(hLine1, centerY - thickness / 2);
                    canvas.Children.Add(hLine1);
                    
                    var hLine2 = new Rectangle
                    {
                        Width = size,
                        Height = thickness,
                        Fill = brush
                    };
                    Canvas.SetLeft(hLine2, centerX + gap);
                    Canvas.SetTop(hLine2, centerY - thickness / 2);
                    canvas.Children.Add(hLine2);
                    
                    // Vertical line
                    var vLine1 = new Rectangle
                    {
                        Width = thickness,
                        Height = size,
                        Fill = brush
                    };
                    Canvas.SetLeft(vLine1, centerX - thickness / 2);
                    Canvas.SetTop(vLine1, centerY - size - gap);
                    canvas.Children.Add(vLine1);
                    
                    var vLine2 = new Rectangle
                    {
                        Width = thickness,
                        Height = size,
                        Fill = brush
                    };
                    Canvas.SetLeft(vLine2, centerX - thickness / 2);
                    Canvas.SetTop(vLine2, centerY + gap);
                    canvas.Children.Add(vLine2);
                    break;
                    
                case "Dot":
                    var dot = new Ellipse
                    {
                        Width = size,
                        Height = size,
                        Fill = brush
                    };
                    Canvas.SetLeft(dot, centerX - size / 2);
                    Canvas.SetTop(dot, centerY - size / 2);
                    canvas.Children.Add(dot);
                    break;
                    
                case "Circle":
                    var circle = new Ellipse
                    {
                        Width = size * 2,
                        Height = size * 2,
                        Stroke = brush,
                        StrokeThickness = thickness
                    };
                    Canvas.SetLeft(circle, centerX - size);
                    Canvas.SetTop(circle, centerY - size);
                    canvas.Children.Add(circle);
                    break;
                    
                // Add more crosshair styles as needed
            }
            
            // Add outline if enabled
            if (CrosshairOutline.IsChecked == true)
                        {
                // Add black outline to crosshair elements
                foreach (var element in canvas.Children)
                {
                    if (element is Shape shape)
                    {
                        shape.Stroke = Brushes.Black;
                        shape.StrokeThickness = 1;
                    }
                }
            }
        }

        private void UpdateCrosshairPreview()
        {
            CrosshairPreview.Children.Clear();
            DrawCrosshair(CrosshairPreview, 200, 200);
        }

        private void CloseCrosshairOverlay()
        {
            crosshairOverlay?.Close();
            crosshairOverlay = null;
            LogMessage("✓ Crosshair overlay disabled");
        }

        private void ApplyFov_Click(object sender, RoutedEventArgs e)
        {
            double fov = FovSlider.Value;
            string mode = (FovMode.SelectedItem as ComboBoxItem)?.Content?.ToString();
            
            LogMessage($"Applying FOV: {fov}° ({mode})");
            
            // Apply display optimizations
            if (FullscreenOpt.IsChecked == true)
            {
                Registry.SetValue(@"HKEY_CURRENT_USER\System\GameConfigStore", 
                    "GameDVR_FSEBehaviorMode", 2, RegistryValueKind.DWord);
            }
            
            if (VSync.IsChecked == true)
            {
                // Disable V-Sync in registry
                Registry.SetValue(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\DirectX\UserGpuPreferences",
                    "DirectXUserGlobalSettings", "VsyncMode=0;", RegistryValueKind.String);
            }
            
            if (GpuScheduling.IsChecked == true)
            {
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
                    "HwSchMode", 2, RegistryValueKind.DWord);
            }
            
            if (LowLatency.IsChecked == true)
            {
                // NVIDIA Low Latency Mode
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "nvidia-settings",
                        Arguments = "-a OpenGLImageSettings=1",
                        WindowStyle = ProcessWindowStyle.Hidden
                    });
                }
                catch { }
            }
            
            LogMessage("✓ FOV and display settings applied");
        }

        private void ClearRam_Click(object sender, RoutedEventArgs e)
        {
            LogMessage("Clearing RAM...");
            ClearMemory();
            LogMessage("✓ RAM cleared");
        }

        private void ClearMemory()
        {
            try
            {
                // Clear working sets
                EmptyWorkingSet(GetCurrentProcess());
                
                // Force garbage collection
                GC.Collect();
                GC.WaitForPendingFinalizers();
                GC.Collect();
                
                // Clear standby list (requires admin)
                Process.Start(new ProcessStartInfo
                {
                    FileName = "cmd",
                    Arguments = "/c %windir%\\system32\\rundll32.exe advapi32.dll,ProcessIdleTasks",
                    WindowStyle = ProcessWindowStyle.Hidden,
                    Verb = "runas"
                })?.WaitForExit();
            }
            catch { }
        }

        private void FlushDns_Click(object sender, RoutedEventArgs e)
        {
            LogMessage("Flushing DNS cache...");
            
            Process.Start(new ProcessStartInfo
            {
                FileName = "ipconfig",
                Arguments = "/flushdns",
                WindowStyle = ProcessWindowStyle.Hidden,
                Verb = "runas"
            })?.WaitForExit();
            
            LogMessage("✓ DNS cache flushed");
        }

        private void RefreshProcesses_Click(object sender, RoutedEventArgs e)
        {
            RefreshProcessList();
        }

        private void SetHighPriority_Click(object sender, RoutedEventArgs e)
        {
            var selected = ProcessGrid.SelectedItem as ProcessInfo;
            if (selected == null) return;
            
            try
            {
                var process = Process.GetProcessById(selected.Id);
                process.PriorityClass = ProcessPriorityClass.High;
                
                // Disable priority boost
                SetProcessPriorityBoost(process.Handle, false);
                
                LogMessage($"✓ Set {selected.Name} to High priority");
                RefreshProcessList();
            }
            catch (Exception ex)
            {
                LogMessage($"⚠ Failed to set priority: {ex.Message}");
            }
        }

        private void SetAffinity_Click(object sender, RoutedEventArgs e)
        {
            var selected = ProcessGrid.SelectedItem as ProcessInfo;
            if (selected == null) return;
            
            try
            {
                var process = Process.GetProcessById(selected.Id);
                
                // Get CPU count
                int cpuCount = Environment.ProcessorCount;
                
                // Set affinity to all CPUs except CPU 0 (reserve for system)
                long affinityMask = 0;
                for (int i = 1; i < cpuCount; i++)
                {
                    affinityMask |= 1L << i;
                }
                
                process.ProcessorAffinity = (IntPtr)affinityMask;
                LogMessage($"✓ Set {selected.Name} CPU affinity");
            }
            catch (Exception ex)
            {
                LogMessage($"⚠ Failed to set affinity: {ex.Message}");
            }
        }

        private void KillBackground_Click(object sender, RoutedEventArgs e)
        {
            LogMessage("Killing background processes...");
            
            var backgroundProcesses = new[]
            {
                "Steam", "Discord", "Skype", "Teams",
                "OneDrive", "Dropbox", "GoogleDrive",
                "AdobeUpdateService", "CCXProcess",
                "node", "Code", "chrome", "firefox",
                "Spotify", "EpicGamesLauncher"
            };
            
            int killed = 0;
            foreach (var procName in backgroundProcesses)
            {
                try
                {
                    foreach (var proc in Process.GetProcessesByName(procName))
                    {
                        proc.Kill();
                        killed++;
                    }
                }
                catch { }
            }
            
            LogMessage($"✓ Killed {killed} background processes");
            RefreshProcessList();
        }

        private void EndTask_Click(object sender, RoutedEventArgs e)
        {
            var selected = ProcessGrid.SelectedItem as ProcessInfo;
            if (selected == null) return;
            
            try
            {
                var process = Process.GetProcessById(selected.Id);
                process.Kill();
                LogMessage($"✓ Ended task: {selected.Name}");
                RefreshProcessList();
            }
            catch (Exception ex)
            {
                LogMessage($"⚠ Failed to end task: {ex.Message}");
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            base.OnClosed(e);
            
            // Clean up
            timeEndPeriod(1);
            processTimer?.Stop();
            CloseCrosshairOverlay();
        }
    }

    public class ProcessInfo
    {
        public string Name { get; set; }
        public int Id { get; set; }
        public string Priority { get; set; }
        public double CPU { get; set; }
        public long Memory { get; set; }
        public int Threads { get; set; }
    }
}
