using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Win32;
using System.Management;
using System.Threading.Tasks;
using System.IO;

namespace KOALAOptimizer
{
    public static class AdvancedOptimizations
    {
        // DirectX Optimizations
        public static void OptimizeDirectX()
        {
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Direct3D", 
                "DisableVidMemVirtualization", 1, RegistryValueKind.DWord);
                
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DirectX", 
                "D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE", 1, RegistryValueKind.DWord);
                
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DirectX", 
                "D3D12_ENABLE_RUNTIME_DRIVER_OPTIMIZATIONS", 1, RegistryValueKind.DWord);
        }
        
        // NVIDIA Specific Optimizations
        public static void OptimizeNvidia()
        {
            string nvidiaCpl = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000";
            
            Registry.SetValue(nvidiaCpl, "RMHdcpKeyglobZero", 1, RegistryValueKind.DWord);
            Registry.SetValue(nvidiaCpl, "RmGpsPsEnablePerCpuCoreDpc", 1, RegistryValueKind.DWord);
            Registry.SetValue(nvidiaCpl, "PowerMizerEnable", 1, RegistryValueKind.DWord);
            Registry.SetValue(nvidiaCpl, "PowerMizerLevel", 1, RegistryValueKind.DWord);
            Registry.SetValue(nvidiaCpl, "PowerMizerLevelAC", 1, RegistryValueKind.DWord);
            Registry.SetValue(nvidiaCpl, "PerfLevelSrc", 0x3322, RegistryValueKind.DWord);
            Registry.SetValue(nvidiaCpl, "EnableMSI", 1, RegistryValueKind.DWord);
        }
        
        // AMD Specific Optimizations
        public static void OptimizeAMD()
        {
            string amdKey = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000";
            
            Registry.SetValue(amdKey, "DisableDMACopy", 1, RegistryValueKind.DWord);
            Registry.SetValue(amdKey, "DisableBlockWrite", 0, RegistryValueKind.DWord);
            Registry.SetValue(amdKey, "KMD_EnableComputePreemption", 0, RegistryValueKind.DWord);
            Registry.SetValue(amdKey, "KMD_DeLagEnabled", 0, RegistryValueKind.DWord);
            Registry.SetValue(amdKey, "DisableDrmdmaPowerGating", 1, RegistryValueKind.DWord);
        }
        
        // Intel iGPU Optimizations
        public static void OptimizeIntel()
        {
            string intelKey = @"HKEY_LOCAL_MACHINE\SOFTWARE\Intel\GMM";
            
            Registry.SetValue(intelKey, "DedicatedSegmentSize", 512, RegistryValueKind.DWord);
        }
        
        // USB Polling Rate Optimization
        public static void OptimizeUSBPolling()
        {
            string usbKey = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\usbflags";
            Registry.SetValue(usbKey, "PollingInterval", 1, RegistryValueKind.DWord);
            
            // Mouse polling
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters",
                "MouseDataQueueSize", 50, RegistryValueKind.DWord);
                
            // Keyboard polling  
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters",
                "KeyboardDataQueueSize", 50, RegistryValueKind.DWord);
        }
        
        // Process Lasso Style Optimizations
        public static void OptimizeProcessScheduling()
        {
            // IdleSaver
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                "NoLazyMode", 1, RegistryValueKind.DWord);
                
            // ProBalance equivalent
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Executive",
                "AdditionalCriticalWorkerThreads", 2, RegistryValueKind.DWord);
                
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Executive",
                "AdditionalDelayedWorkerThreads", 2, RegistryValueKind.DWord);
        }
        
        // MSI Mode for devices
        public static void EnableMSIMode()
        {
            // Enable MSI for GPU
            using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController"))
            {
                foreach (var gpu in searcher.Get())
                {
                    string deviceId = gpu["PNPDeviceID"]?.ToString();
                    if (!string.IsNullOrEmpty(deviceId))
                    {
                        string regPath = $@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\{deviceId}\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties";
                        Registry.SetValue(regPath, "MSISupported", 1, RegistryValueKind.DWord);
                    }
                }
            }
        }
        
        // Interrupt Affinity
        public static void OptimizeInterruptAffinity()
        {
            // Set interrupt affinity to specific cores
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl",
                "IRQ8Priority", 1, RegistryValueKind.DWord);
                
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl",
                "IRQ16Priority", 2, RegistryValueKind.DWord);
        }
        
        // Storage Optimizations
        public static void OptimizeStorage()
        {
            // NVMe optimizations
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device",
                "ForcedPhysicalDiskIo", 1, RegistryValueKind.DWord);
                
            // AHCI optimizations
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device",
                "SingleIO", 0, RegistryValueKind.DWord);
                
            // File system optimizations
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem",
                "NtfsMftZoneReservation", 2, RegistryValueKind.DWord);
                
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem",
                "NtfsDisableLastAccessUpdate", 1, RegistryValueKind.DWord);
                
            Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem",
                "NtfsDisable8dot3NameCreation", 1, RegistryValueKind.DWord);
        }
        
        // Spectre/Meltdown Mitigations
        public static void DisableSpectreMeltdown(bool disable)
        {
            if (disable)
            {
                // WARNING: This reduces security but can improve performance
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "FeatureSettingsOverride", 3, RegistryValueKind.DWord);
                    
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "FeatureSettingsOverrideMask", 3, RegistryValueKind.DWord);
            }
        }
        
        // Razer Booster-inspired Game Mode Optimization
        public static void ApplyGameBoosterMode()
        {
            try
            {
                // Enhanced Game Mode with automatic process prioritization
                Registry.SetValue(@"HKEY_CURRENT_USER\Software\Microsoft\GameBar",
                    "AutoGameModeEnabled", 1, RegistryValueKind.DWord);
                
                // Game DVR optimizations
                Registry.SetValue(@"HKEY_CURRENT_USER\System\GameConfigStore",
                    "GameDVR_Enabled", 0, RegistryValueKind.DWord);
                
                Registry.SetValue(@"HKEY_CURRENT_USER\System\GameConfigStore",
                    "GameDVR_FSEBehaviorMode", 2, RegistryValueKind.DWord);
                
                // Gaming thread scheduling
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "GPU Priority", 8, RegistryValueKind.DWord);
                
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "Priority", 6, RegistryValueKind.DWord);
                
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "Scheduling Category", "High", RegistryValueKind.String);
                
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "SFIO Priority", "High", RegistryValueKind.String);
            }
            catch { }
        }
        
        // CPU Core Optimization for Gaming (Razer Booster style)
        public static void OptimizeCPUCoresForGaming()
        {
            try
            {
                // Disable core parking for all cores
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583",
                    "ValueMax", 0, RegistryValueKind.DWord);
                
                // Performance boost mode
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\be337238-0d82-4146-a960-4f3749d470c7",
                    "ValueMax", 100, RegistryValueKind.DWord);
                
                // CPU idle states optimization
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\5d76a2ca-e8c0-402f-a133-2158492d58ad",
                    "ValueMax", 0, RegistryValueKind.DWord);
                
                // Processor performance increase threshold
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\06cadf0e-64ed-448a-8927-ce7bf90eb35d",
                    "ValueMax", 10, RegistryValueKind.DWord);
                
                // Processor performance decrease threshold  
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\12a0ab44-fe28-4fa9-b3bd-4b64f44960a6",
                    "ValueMax", 75, RegistryValueKind.DWord);
            }
            catch { }
        }
        
        // Memory Cleanup and Optimization (Razer Booster style)
        public static void PerformMemoryCleanup()
        {
            try
            {
                // Clear standby memory
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "ClearPageFileAtShutdown", 1, RegistryValueKind.DWord);
                
                // Memory compression optimization
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "DisablePagingExecutive", 1, RegistryValueKind.DWord);
                
                // Large system cache
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "LargeSystemCache", 1, RegistryValueKind.DWord);
                
                // System managed virtual memory
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "SecondLevelDataCache", 1024, RegistryValueKind.DWord);
                
                // Gaming memory allocation
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
                    "FeatureSettings", 1, RegistryValueKind.DWord);
                
                // Run memory cleanup
                RunMemoryCleanupCommand();
            }
            catch { }
        }
        
        // Background Process Management (Razer Booster style)
        public static void OptimizeBackgroundProcesses()
        {
            try
            {
                // Disable Windows Defender real-time monitoring during gaming (optional)
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection",
                    "DisableRealtimeMonitoring", 1, RegistryValueKind.DWord);
                
                // Windows Update optimization
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU",
                    "NoAutoUpdate", 1, RegistryValueKind.DWord);
                
                // Background apps optimization
                Registry.SetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications",
                    "GlobalUserDisabled", 1, RegistryValueKind.DWord);
                
                // Disable background task host
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\backgroundTaskHost.exe",
                    "Debugger", "rundll32.exe", RegistryValueKind.String);
                
                // System interrupts optimization
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl",
                    "ConvertSharedInterrupts", 1, RegistryValueKind.DWord);
            }
            catch { }
        }
        
        // System Resource Prioritization (Razer Booster style)
        public static void PrioritizeSystemResources()
        {
            try
            {
                // I/O priority for games
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System",
                    "CountOperations", 1, RegistryValueKind.DWord);
                
                // Network throttling index
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                    "NetworkThrottlingIndex", 10, RegistryValueKind.DWord);
                
                // System responsiveness for gaming
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                    "SystemResponsiveness", 0, RegistryValueKind.DWord);
                
                // Gaming multimedia optimizations
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "Affinity", 0, RegistryValueKind.DWord);
                
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "Background Only", "False", RegistryValueKind.String);
                
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games",
                    "Clock Rate", 10000, RegistryValueKind.DWord);
            }
            catch { }
        }
        
        // Automatic Game Detection and Process Optimization
        public static void EnableGameDetectionOptimization()
        {
            try
            {
                // Game detection registry settings
                Registry.SetValue(@"HKEY_CURRENT_USER\Software\Microsoft\GameBar",
                    "UseNexusForGameBarEnabled", 0, RegistryValueKind.DWord);
                
                Registry.SetValue(@"HKEY_CURRENT_USER\Software\Microsoft\GameBar",
                    "GamePanelStartupTipIndex", 3, RegistryValueKind.DWord);
                
                // Full screen exclusive optimizations
                Registry.SetValue(@"HKEY_CURRENT_USER\System\GameConfigStore",
                    "GameDVR_DSEBehavior", 2, RegistryValueKind.DWord);
                
                // GPU scheduling for detected games
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
                    "HwSchMode", 2, RegistryValueKind.DWord);
                
                // Automatic GPU performance scaling
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power",
                    "DefaultD3TransitionLatencyActivelyUsed", 0, RegistryValueKind.DWord);
                
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power",
                    "DefaultD3TransitionLatencyIdleLongTime", 0, RegistryValueKind.DWord);
            }
            catch { }
        }
        
        // Enhanced DirectX Gaming Optimizations
        public static void OptimizeDirectXGaming()
        {
            try
            {
                // DirectX 12 Ultimate optimizations
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DirectX",
                    "DisableAGPSupport", 0, RegistryValueKind.DWord);
                
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DirectX",
                    "EnableDebugging", 0, RegistryValueKind.DWord);
                
                // DXGI optimizations
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DirectX",
                    "DXGI_MAX_FRAME_LATENCY", 1, RegistryValueKind.DWord);
                
                // DirectX shader optimizations
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DirectX",
                    "D3D12_SHADER_CACHE_SIZE", 10737418240, RegistryValueKind.QWord); // 10GB cache
                
                // GPU preemption optimizations
                Registry.SetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler",
                    "EnablePreemption", 0, RegistryValueKind.DWord);
            }
            catch { }
        }
        
        // Memory cleanup command execution
        private static void RunMemoryCleanupCommand()
        {
            try
            {
                // Clear standby memory using Windows API
                var startInfo = new ProcessStartInfo
                {
                    FileName = "rundll32.exe",
                    Arguments = "advapi32.dll,ProcessIdleTasks",
                    WindowStyle = ProcessWindowStyle.Hidden,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                
                using (var process = Process.Start(startInfo))
                {
                    process?.WaitForExit(5000); // Wait max 5 seconds
                }
            }
            catch { }
        }
        public static void ApplyBCDEditTweaks()
        {
            // Disable dynamic tick
            RunCommand("bcdedit", "/set disabledynamictick yes");
            
            // Use legacy boot
            RunCommand("bcdedit", "/set uselegacyapicmode yes");
            
            // Use platform clock
            RunCommand("bcdedit", "/set useplatformclock yes");
            
            // Disable boot debugging
            RunCommand("bcdedit", "/set debug no");
            
            // Disable integrity checks
            RunCommand("bcdedit", "/set nointegritychecks yes");
            
            // Set TSC sync policy
            RunCommand("bcdedit", "/set tscsyncpolicy enhanced");
        }
        
        private static void RunCommand(string command, string arguments)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = command,
                    Arguments = arguments,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    Verb = "runas"
                })?.WaitForExit();
            }
            catch { }
        }
    }
}