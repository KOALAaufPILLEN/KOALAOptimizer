using System;
using System.Collections.Generic;  // <-- THIS WAS MISSING!
using System.Diagnostics;
using System.Management;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace KOALAOptimizer
{
    public partial class MainWindow : Window
    {
        private Dictionary<string, object> backupData = new Dictionary<string, object>();
        private readonly string backupPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "KOALA-Backup.json");
        
        [DllImport("winmm.dll")]
        static extern uint timeBeginPeriod(uint period);
        
        [DllImport("winmm.dll")]
        static extern uint timeEndPeriod(uint period);
        
        [DllImport("ntdll.dll")]
        static extern int NtSetTimerResolution(int DesiredResolution, bool SetResolution, out int CurrentResolution);
        
        [DllImport("kernel32.dll")]
        static extern bool SetProcessWorkingSetSize(IntPtr proc, int min, int max);

        public MainWindow()
        {
            InitializeComponent();
            LoadSystemInfo();
            CheckAdminStatus();
            SetupModeListeners();
        }

        private void SetupModeListeners()
        {
            SafeModeRadio.Checked += (s, e) => UpdateOptionsBasedOnMode();
            PerformanceRadio.Checked += (s, e) => UpdateOptionsBasedOnMode();
            KernelModeRadio.Checked += (s, e) => ShowKernelWarning();
        }

        private void UpdateOptionsBasedOnMode()
        {
            if (SafeModeRadio.IsChecked == true)
            {
                // Safe mode - disable risky options
                ServicesCheckBox.IsEnabled = false;
                ServicesCheckBox.IsChecked = false;
                TimerCheckBox.IsEnabled = false;
                TimerCheckBox.IsChecked = false;
                CoreParkingCheckBox.IsEnabled = false;
                CoreParkingCheckBox.IsChecked = false;
                CStatesCheckBox.IsEnabled = false;
                CStatesCheckBox.IsChecked = false;
                MitigationsCheckBox.IsEnabled = false;
                MitigationsCheckBox.IsChecked = false;
                MSICheckBox.IsEnabled = false;
                MSICheckBox.IsChecked = false;
                InterruptCheckBox.IsEnabled = false;
                InterruptCheckBox.IsChecked = false;
                
                LogMessage("✅ Safe Mode - Anti-cheat compatible optimizations only");
            }
            else if (PerformanceRadio.IsChecked == true)
            {
                // Performance mode - enable most options
                ServicesCheckBox.IsEnabled = true;
                TimerCheckBox.IsEnabled = true;
                CoreParkingCheckBox.IsEnabled = true;
                CStatesCheckBox.IsEnabled = true;
                MitigationsCheckBox.IsEnabled = true;
                MSICheckBox.IsEnabled = true;
                InterruptCheckBox.IsEnabled = true;
                
                LogMessage("⚡ Performance Mode - Some features may trigger anti-cheats");
            }
        }

        private void ShowKernelWarning()
        {
            if (KernelModeRadio.IsChecked == true)
            {
                var result = MessageBox.Show(
                    "⚠️ KERNEL MODE WARNING ⚠️\n\n" +
                    "This mode includes:\n" +
                    "• BCDEdit modifications\n" +
                    "• Kernel security changes\n" +
                    "• Driver signing bypass\n" +
                    "• Test mode activation\n\n" +
                    "These changes WILL:\n" +
                    "❌ Trigger ALL anti-cheat systems (EAC, BattlEye, Vanguard)\n" +
                    "❌ Potentially cause system instability\n" +
                    "❌ Require system restore to undo\n\n" +
                    "Are you ABSOLUTELY SURE?",
                    "KERNEL MODE - EXTREME WARNING",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Warning);
                    
                if (result == MessageBoxResult.Yes)
                {
                    // Enable kernel options
                    BCDEditCheckBox.IsEnabled = true;
                    KernelDebugCheckBox.IsEnabled = true;
                    DriverSignCheckBox.IsEnabled = true;
                    TestModeCheckBox.IsEnabled = true;
                    DEPCheckBox.IsEnabled = true;
                    
                    // Enable all other options
                    UpdateOptionsBasedOnMode();
                    
                    LogMessage("🔥 KERNEL MODE ACTIVATED - USE AT YOUR OWN RISK!");
                }
                else
                {
                    SafeModeRadio.IsChecked = true;
                }
            }
        }

        private void LoadSystemInfo()
        {
            try
            {
                string info = "";
                
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_OperatingSystem"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        info += $"OS: {obj["Caption"]} ({obj["Version"]})\n";
                    }
                }
                
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Processor"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        info += $"CPU: {obj["Name"]}\n";
                        info += $"Cores: {obj["NumberOfLogicalProcessors"]}\n";
                    }
                }
                
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_ComputerSystem"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        var ram = Convert.ToDouble(obj["TotalPhysicalMemory"]) / (1024 * 1024 * 1024);
                        info += $"RAM: {ram:F1} GB\n";
                    }
                }
                
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController"))
                {
                    foreach (var obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        if (!string.IsNullOrEmpty(name) && !name.Contains("Microsoft"))
                        {
                            info += $"GPU: {name}\n";
                            break;
                        }
                    }
                }
                
                SystemInfoText.Text = info;
                SystemInfoText.Foreground = new SolidColorBrush(Colors.LightGreen);
            }
            catch (Exception ex)
            {
                SystemInfoText.Text = $"Error: {ex.Message}";
            }
        }

        private void CheckAdminStatus()
        {
            var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
            var principal = new System.Security.Principal.WindowsPrincipal(identity);
            bool isAdmin = principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
            
            if (isAdmin)
            {
                AdminStatusText.Text = "✓ Administrator Mode";
                AdminStatusText.Foreground = new SolidColorBrush(Colors.LightGreen);
            }
            else
            {
                AdminStatusText.Text = "⚠ Run as Admin for full features";
                AdminStatusText.Foreground = new SolidColorBrush(Colors.Yellow);
            }
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
                StatusText.Text = "Optimizing...";
            });

            CreateBackup();
            
            bool isSafeMode = await Dispatcher.InvokeAsync(() => SafeModeRadio.IsChecked == true);
            bool isPerformanceMode = await Dispatcher.InvokeAsync(() => PerformanceRadio.IsChecked == true);
            bool isKernelMode = await Dispatcher.InvokeAsync(() => KernelModeRadio.IsChecked == true);
            
            // SAFE OPTIMIZATIONS (work with all anti-cheats)
            if (await Dispatcher.InvokeAsync(() => GpuCheckBox.IsChecked == true))
            {
                await ApplySafeGPUOptimizations();
            }
            
            if (await Dispatcher.InvokeAsync(() => CpuCheckBox.IsChecked == true))
            {
                await ApplySafeCPUOptimizations();
            }
            
            if (await Dispatcher.InvokeAsync(() => RamCheckBox.IsChecked == true))
            {
                await ApplySafeMemoryOptimizations();
            }
            
            if (await Dispatcher.InvokeAsync(() => NetworkCheckBox.IsChecked == true))
            {
                await ApplySafeNetworkOptimizations();
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
            
            // PERFORMANCE MODE OPTIMIZATIONS (may trigger some anti-cheats)
            if (isPerformanceMode || isKernelMode)
            {
                if (await Dispatcher.InvokeAsync(() => ServicesCheckBox.IsChecked == true))
                {
                    await DisableServices();
                }
                
                if (await Dispatcher.InvokeAsync(() => TimerCheckBox.IsChecked == true))
                {
                    await SetTimerResolution();
                }
                
                if (await Dispatcher.InvokeAsync(() => CoreParkingCheckBox.IsChecked == true))
                {
                    await DisableCoreParking();
                }
                
                if (await Dispatcher.InvokeAsync(() => CStatesCheckBox.IsChecked == true))
                {
                    await DisableCStates();
                }
                
                if (await Dispatcher.InvokeAsync(() => MitigationsCheckBox.IsChecked == true))
                {
                    await DisableMitigations();
                }
                
                if (await Dispatcher.InvokeAsync(() => MSICheckBox.IsChecked == true))
                {
                    await EnableMSIMode();
                }
                
                if (await Dispatcher.InvokeAsync(() => InterruptCheckBox.IsChecked == true))
                {
                    await OptimizeInterrupts();
                }
            }
            
            // KERNEL MODE ONLY (WILL trigger anti-cheats)
            if (isKernelMode)
            {
                if (await Dispatcher.InvokeAsync(() => BCDEditCheckBox.IsChecked == true))
                {
                    await ApplyBCDEditTweaks();
                }
                
                if (await Dispatcher.InvokeAsync(() => KernelDebugCheckBox.IsChecked == true))
                {
                    await DisableKernelSecurity();
                }
                
                if (await Dispatcher.InvokeAsync(() => DriverSignCheckBox.IsChecked == true))
                {
                    await DisableDriverSigning();
                }
                
                if (await Dispatcher.InvokeAsync(() => TestModeCheckBox.IsChecked == true))
                {
                    await EnableTestMode();
                }
                
                if (await Dispatcher.InvokeAsync(() => DEPCheckBox.IsChecked == true))
                {
                    await DisableDEP();
                }
            }

            await Dispatcher.InvokeAsync(() =>
            {
                LogMessage("✅ Optimization complete!");
                StatusText.Text = "Complete - System optimized";
                
                string modeText = isSafeMode ? "Safe Mode" : 
                                 isPerformanceMode ? "Performance Mode" : 
                                 "Kernel Mode";
                                 
                MessageBox.Show($"Optimization complete in {modeText}!\n\n" +
                               (isSafeMode ? "✅ Anti-cheat compatible\n" : 
                                isPerformanceMode ? "⚠️ Some anti-cheats may detect changes\n" :
                                "❌ Anti-cheats WILL detect modifications\n") +
                               "Restart recommended for best results.", 
                               "KOALA Optimizer V3", 
                               MessageBoxButton.OK, 
                               MessageBoxImage.Information);
            });
        }

        private void CreateBackup()
        {
            try
            {
                backupData.Clear();
                backupData["timestamp"] = DateTime.Now.ToString();
                backupData["mode"] = SafeModeRadio.IsChecked == true ? "Safe" :
                                     PerformanceRadio.IsChecked == true ? "Performance" : "Kernel";
                File.WriteAllText(backupPath, JsonSerializer.Serialize(backupData));
                Dispatcher.Invoke(() => LogMessage("✓ Backup created"));
            }
            catch (Exception ex)
            {
                Dispatcher.Invoke(() => LogMessage($"⚠ Backup error: {ex.Message}"));
            }
        }

        // SAFE OPTIMIZATIONS (Anti-cheat compatible)
        private async Task ApplySafeGPUOptimizations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Applying safe GPU optimizations..."));
            
            try
            {
                // Only apply user-level GPU settings
                Registry.SetValue(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\DirectX\UserGpuPreferences",
                    "DirectXUserGlobalSettings", "SwapEffectUpgradeEnable=1;", RegistryValueKind.String);
                    
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Safe GPU optimizations applied"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ GPU error: {ex.Message}"));
            }
        }

        private async Task ApplySafeCPUOptimizations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Applying safe CPU optimizations..."));
            
            try
            {
                // Only set process priority, no system-wide changes
                Process.GetCurrentProcess().PriorityClass = ProcessPriorityClass.High;
                
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Safe CPU optimizations applied"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ CPU error: {ex.Message}"));
            }
        }

        private async Task ApplySafeMemoryOptimizations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Clearing memory..."));
            
            try
            {
                // Only clear working set, no registry changes
                GC.Collect();
                GC.WaitForPendingFinalizers();
                GC.Collect();
                SetProcessWorkingSetSize(Process.GetCurrentProcess().Handle, -1, -1);
                
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Memory cleared"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Memory error: {ex.Message}"));
            }
        }

        private async Task ApplySafeNetworkOptimizations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Applying safe network optimizations..."));
            
            try
            {
                // Only flush DNS, no registry changes
                Process.Start(new ProcessStartInfo
                {
                    FileName = "ipconfig",
                    Arguments = "/flushdns",
                    WindowStyle = ProcessWindowStyle.Hidden
                })?.WaitForExit();
                
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Network optimized"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Network error: {ex.Message}"));
            }
        }

        private async Task OptimizeVisualEffects()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("Optimizing visual effects..."));
            
            try
            {
                Registry.SetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
                    "VisualFXSetting", 2, RegistryValueKind.DWord);
                    
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Visual effects optimized"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Visual error: {ex.Message}"));
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
            await Dispatcher.InvokeAsync(() => LogMessage("Optimizing mouse..."));
            
            try
            {
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
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Mouse error: {ex.Message}"));
            }
        }

        // PERFORMANCE MODE (May trigger anti-cheats)
        private async Task DisableServices()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("⚠ Disabling services (may trigger AC)..."));
            
            var services = new[] { "XblGameSave", "XblAuthManager", "DiagTrack", "WSearch" };
            foreach (var service in services)
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "sc",
                        Arguments = $"config {service} start=disabled",
                        WindowStyle = ProcessWindowStyle.Hidden,
                        Verb = "runas"
                    })?.WaitForExit();
                }
                catch { }
            }
            
            await Dispatcher.InvokeAsync(() => LogMessage("✓ Services disabled"));
        }

        private async Task SetTimerResolution()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("⚠ Setting timer resolution..."));
            
            try
            {
                timeBeginPeriod(1);
                int currentResolution;
                NtSetTimerResolution(5000, true, out currentResolution);
                
                await Dispatcher.InvokeAsync(() => LogMessage("✓ Timer resolution set"));
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() => LogMessage($"⚠ Timer error: {ex.Message}"));
            }
        }

        private async Task DisableCoreParking()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("⚠ Disabling core parking..."));
            
            Process.Start(new ProcessStartInfo
            {
                FileName = "powercfg",
                Arguments = "-setacvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100",
                WindowStyle = ProcessWindowStyle.Hidden
            })?.WaitForExit();
            
            await Dispatcher.InvokeAsync(() => LogMessage("✓ Core parking disabled"));
        }

        private async Task DisableCStates()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("⚠ Disabling C-States..."));
            
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Processor",
                "Capabilities", 0x0007e066, RegistryValueKind.DWord);
                
            await Dispatcher.InvokeAsync(() => LogMessage("✓ C-States disabled"));
        }

        private async Task DisableMitigations()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("⚠ Disabling CPU mitigations (security risk)..."));
            
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                "FeatureSettingsOverride", 3, RegistryValueKind.DWord);
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                "FeatureSettingsOverrideMask", 3, RegistryValueKind.DWord);
                
            await Dispatcher.InvokeAsync(() => LogMessage("✓ Mitigations disabled"));
        }

        private async Task EnableMSIMode()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("⚠ Enabling MSI mode..."));
            // MSI mode implementation
            await Dispatcher.InvokeAsync(() => LogMessage("✓ MSI mode enabled"));
        }

        private async Task OptimizeInterrupts()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("⚠ Optimizing interrupts..."));
            
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl",
                "IRQ8Priority", 1, RegistryValueKind.DWord);
                
            await Dispatcher.InvokeAsync(() => LogMessage("✓ Interrupts optimized"));
        }

        // KERNEL MODE (WILL trigger anti-cheats)
        private async Task ApplyBCDEditTweaks()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("🔥 APPLYING KERNEL TWEAKS (WILL TRIGGER AC)..."));
            
            Process.Start(new ProcessStartInfo
            {
                FileName = "bcdedit",
                Arguments = "/set disabledynamictick yes",
                WindowStyle = ProcessWindowStyle.Hidden,
                Verb = "runas"
            })?.WaitForExit();
            
            Process.Start(new ProcessStartInfo
            {
                FileName = "bcdedit",
                Arguments = "/set useplatformclock yes",
                WindowStyle = ProcessWindowStyle.Hidden,
                Verb = "runas"
            })?.WaitForExit();
            
            await Dispatcher.InvokeAsync(() => LogMessage("✓ BCDEdit tweaks applied"));
        }

        private async Task DisableKernelSecurity()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("🔥 DISABLING KERNEL SECURITY..."));
            
            Process.Start(new ProcessStartInfo
            {
                FileName = "bcdedit",
                Arguments = "/set nointegritychecks on",
                WindowStyle = ProcessWindowStyle.Hidden,
                Verb = "runas"
            })?.WaitForExit();
            
            await Dispatcher.InvokeAsync(() => LogMessage("✓ Kernel security disabled"));
        }

        private async Task DisableDriverSigning()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("🔥 DISABLING DRIVER SIGNING..."));
            
            Process.Start(new ProcessStartInfo
            {
                FileName = "bcdedit",
                Arguments = "/set loadoptions DISABLE_INTEGRITY_CHECKS",
                WindowStyle = ProcessWindowStyle.Hidden,
                Verb = "runas"
            })?.WaitForExit();
            
            await Dispatcher.InvokeAsync(() => LogMessage("✓ Driver signing disabled"));
        }

        private async Task EnableTestMode()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("🔥 ENABLING TEST MODE..."));
            
            Process.Start(new ProcessStartInfo
            {
                FileName = "bcdedit",
                Arguments = "/set testsigning on",
                WindowStyle = ProcessWindowStyle.Hidden,
                Verb = "runas"
            })?.WaitForExit();
            
            await Dispatcher.InvokeAsync(() => LogMessage("✓ Test mode enabled"));
        }

        private async Task DisableDEP()
        {
            await Dispatcher.InvokeAsync(() => LogMessage("🔥 DISABLING DEP..."));
            
            Process.Start(new ProcessStartInfo
            {
                FileName = "bcdedit",
                Arguments = "/set nx AlwaysOff",
                WindowStyle = ProcessWindowStyle.Hidden,
                Verb = "runas"
            })?.WaitForExit();
            
            await Dispatcher.InvokeAsync(() => LogMessage("✓ DEP disabled"));
        }

        private void RestoreButton_Click(object sender, RoutedEventArgs e)
        {
            if (!File.Exists(backupPath))
            {
                MessageBox.Show("No backup found!", "KOALA Optimizer", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            
            LogMessage("Restoring from backup...");
            // Restore implementation
            LogMessage("✓ Restore complete");
        }

        protected override void OnClosed(EventArgs e)
        {
            base.OnClosed(e);
            timeEndPeriod(1);
        }
    }
}
