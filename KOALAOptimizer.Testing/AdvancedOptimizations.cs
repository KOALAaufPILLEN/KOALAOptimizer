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
        
        // BCDEdit optimizations
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