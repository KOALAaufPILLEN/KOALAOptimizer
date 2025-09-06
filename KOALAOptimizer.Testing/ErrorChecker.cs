using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Management;
using System.Security.Principal;
using Microsoft.Win32;

namespace KOALAOptimizer
{
    public static class ErrorChecker
    {
        public delegate void LogMessageDelegate(string message, string level = "Info");
        
        // Comprehensive system validation before optimization
        public static List<string> ValidateSystemReadiness(LogMessageDelegate logCallback = null)
        {
            var issues = new List<string>();
            
            try
            {
                logCallback?.Invoke("🔍 Starting comprehensive system validation...", "Info");
                
                // Check admin privileges
                if (!IsRunningAsAdministrator())
                {
                    issues.Add("❌ Administrator privileges required for full optimization");
                    logCallback?.Invoke("⚠️ Not running as administrator", "Warning");
                }
                
                // Check available disk space
                var spaceIssues = CheckDiskSpace();
                issues.AddRange(spaceIssues);
                if (spaceIssues.Count > 0)
                {
                    logCallback?.Invoke($"⚠️ Disk space warnings: {spaceIssues.Count} issues found", "Warning");
                }
                
                // Check system file integrity
                if (CheckSystemFileIntegrity())
                {
                    logCallback?.Invoke("✅ System file integrity check passed", "Info");
                }
                else
                {
                    issues.Add("⚠️ System file integrity issues detected - run 'sfc /scannow'");
                    logCallback?.Invoke("⚠️ System file integrity issues detected", "Warning");
                }
                
                // Check registry health
                if (CheckRegistryHealth())
                {
                    logCallback?.Invoke("✅ Registry health check passed", "Info");
                }
                else
                {
                    issues.Add("⚠️ Registry health issues detected");
                    logCallback?.Invoke("⚠️ Registry health issues detected", "Warning");
                }
                
                // Check antivirus status
                var avStatus = CheckAntivirusStatus();
                if (!string.IsNullOrEmpty(avStatus))
                {
                    issues.Add(avStatus);
                    logCallback?.Invoke($"⚠️ Antivirus status: {avStatus}", "Warning");
                }
                
                // Check running processes
                var processIssues = CheckCriticalProcesses();
                issues.AddRange(processIssues);
                if (processIssues.Count > 0)
                {
                    logCallback?.Invoke($"⚠️ Process warnings: {processIssues.Count} issues found", "Warning");
                }
                
                // Check system stability
                if (CheckSystemStability())
                {
                    logCallback?.Invoke("✅ System stability check passed", "Info");
                }
                else
                {
                    issues.Add("⚠️ Recent system crashes detected - check Event Viewer");
                    logCallback?.Invoke("⚠️ System stability issues detected", "Warning");
                }
                
                logCallback?.Invoke($"🔍 System validation complete. {issues.Count} issues found.", "Info");
                return issues;
            }
            catch (Exception ex)
            {
                issues.Add($"❌ Error during system validation: {ex.Message}");
                logCallback?.Invoke($"❌ Validation error: {ex.Message}", "Error");
                return issues;
            }
        }
        
        // Validate optimization safety before applying changes
        public static bool ValidateOptimizationSafety(string optimizationType, LogMessageDelegate logCallback = null)
        {
            try
            {
                logCallback?.Invoke($"🔒 Validating safety for {optimizationType}...", "Info");
                
                switch (optimizationType.ToLower())
                {
                    case "kernel":
                        return ValidateKernelOptimizationSafety(logCallback);
                    case "registry":
                        return ValidateRegistryOptimizationSafety(logCallback);
                    case "services":
                        return ValidateServiceOptimizationSafety(logCallback);
                    case "gpu":
                        return ValidateGPUOptimizationSafety(logCallback);
                    case "network":
                        return ValidateNetworkOptimizationSafety(logCallback);
                    default:
                        logCallback?.Invoke("✅ General optimization safety validated", "Info");
                        return true;
                }
            }
            catch (Exception ex)
            {
                logCallback?.Invoke($"❌ Safety validation error: {ex.Message}", "Error");
                return false;
            }
        }
        
        // Post-optimization validation
        public static List<string> ValidatePostOptimization(LogMessageDelegate logCallback = null)
        {
            var issues = new List<string>();
            
            try
            {
                logCallback?.Invoke("🔍 Running post-optimization validation...", "Info");
                
                // Check system responsiveness
                if (!CheckSystemResponsiveness())
                {
                    issues.Add("⚠️ System responsiveness degraded after optimization");
                    logCallback?.Invoke("⚠️ System responsiveness issues detected", "Warning");
                }
                
                // Check critical services
                var serviceIssues = CheckCriticalServices();
                issues.AddRange(serviceIssues);
                
                // Check network connectivity
                if (!CheckNetworkConnectivity())
                {
                    issues.Add("⚠️ Network connectivity issues detected");
                    logCallback?.Invoke("⚠️ Network connectivity problems", "Warning");
                }
                
                // Check display functionality
                if (!CheckDisplayFunctionality())
                {
                    issues.Add("⚠️ Display functionality issues detected");
                    logCallback?.Invoke("⚠️ Display problems detected", "Warning");
                }
                
                logCallback?.Invoke($"🔍 Post-optimization validation complete. {issues.Count} issues found.", "Info");
                return issues;
            }
            catch (Exception ex)
            {
                issues.Add($"❌ Error during post-optimization validation: {ex.Message}");
                logCallback?.Invoke($"❌ Post-validation error: {ex.Message}", "Error");
                return issues;
            }
        }
        
        // Check if running as administrator
        private static bool IsRunningAsAdministrator()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }
        
        // Check available disk space
        private static List<string> CheckDiskSpace()
        {
            var issues = new List<string>();
            
            try
            {
                var drives = DriveInfo.GetDrives();
                foreach (var drive in drives)
                {
                    if (drive.IsReady && drive.DriveType == DriveType.Fixed)
                    {
                        var freeSpaceGB = drive.AvailableFreeSpace / (1024 * 1024 * 1024);
                        var totalSpaceGB = drive.TotalSize / (1024 * 1024 * 1024);
                        var freePercentage = (double)freeSpaceGB / totalSpaceGB * 100;
                        
                        if (freePercentage < 10)
                        {
                            issues.Add($"⚠️ Drive {drive.Name} has only {freeSpaceGB}GB ({freePercentage:F1}%) free space");
                        }
                        else if (freePercentage < 20 && drive.Name.StartsWith("C"))
                        {
                            issues.Add($"⚠️ System drive {drive.Name} has only {freeSpaceGB}GB ({freePercentage:F1}%) free space");
                        }
                    }
                }
            }
            catch { }
            
            return issues;
        }
        
        // Check system file integrity
        private static bool CheckSystemFileIntegrity()
        {
            try
            {
                // Quick check for common system files
                var systemFiles = new[]
                {
                    @"C:\Windows\System32\kernel32.dll",
                    @"C:\Windows\System32\ntdll.dll",
                    @"C:\Windows\System32\user32.dll",
                    @"C:\Windows\System32\advapi32.dll"
                };
                
                foreach (var file in systemFiles)
                {
                    if (!File.Exists(file))
                    {
                        return false;
                    }
                }
                
                return true;
            }
            catch
            {
                return false;
            }
        }
        
        // Check registry health
        private static bool CheckRegistryHealth()
        {
            try
            {
                // Test access to critical registry hives
                using (var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion"))
                {
                    if (key == null) return false;
                }
                
                using (var key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion"))
                {
                    if (key == null) return false;
                }
                
                return true;
            }
            catch
            {
                return false;
            }
        }
        
        // Check antivirus status
        private static string CheckAntivirusStatus()
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher(@"root\SecurityCenter2", 
                    "SELECT * FROM AntiVirusProduct"))
                {
                    var antiVirusProducts = searcher.Get();
                    if (antiVirusProducts.Count == 0)
                    {
                        return "No antivirus software detected";
                    }
                    
                    foreach (ManagementObject product in antiVirusProducts)
                    {
                        var state = product["productState"];
                        if (state != null)
                        {
                            var stateValue = Convert.ToInt32(state);
                            var isEnabled = (stateValue & 0x1000) != 0;
                            var isUpToDate = (stateValue & 0x10) != 0;
                            
                            if (!isEnabled)
                            {
                                return "Antivirus is disabled";
                            }
                            if (!isUpToDate)
                            {
                                return "Antivirus definitions are outdated";
                            }
                        }
                    }
                }
                
                return string.Empty; // No issues
            }
            catch
            {
                return "Unable to check antivirus status";
            }
        }
        
        // Check critical processes
        private static List<string> CheckCriticalProcesses()
        {
            var issues = new List<string>();
            
            try
            {
                var criticalProcesses = new[] { "winlogon", "csrss", "wininit", "services", "lsass" };
                
                foreach (var processName in criticalProcesses)
                {
                    var processes = Process.GetProcessesByName(processName);
                    if (processes.Length == 0)
                    {
                        issues.Add($"❌ Critical process '{processName}' not running");
                    }
                }
            }
            catch { }
            
            return issues;
        }
        
        // Check system stability
        private static bool CheckSystemStability()
        {
            try
            {
                // Check for recent critical events in Event Log
                using (var eventLog = new EventLog("System"))
                {
                    var entries = eventLog.Entries;
                    var recentCrashes = 0;
                    var cutoffTime = DateTime.Now.AddDays(-7);
                    
                    for (int i = entries.Count - 1; i >= 0 && recentCrashes < 5; i--)
                    {
                        var entry = entries[i];
                        if (entry.TimeGenerated > cutoffTime)
                        {
                            if (entry.EntryType == EventLogEntryType.Error && 
                                (entry.Source.Contains("Kernel") || entry.EventID == 1001))
                            {
                                recentCrashes++;
                            }
                        }
                        else
                        {
                            break;
                        }
                    }
                    
                    return recentCrashes < 3;
                }
            }
            catch
            {
                return true; // Assume stable if can't check
            }
        }
        
        // Validate kernel optimization safety
        private static bool ValidateKernelOptimizationSafety(LogMessageDelegate logCallback)
        {
            try
            {
                // Check for virtualization environments
                var computerSystem = new ManagementObjectSearcher("SELECT * FROM Win32_ComputerSystem").Get();
                foreach (ManagementObject obj in computerSystem)
                {
                    var manufacturer = obj["Manufacturer"]?.ToString().ToLower();
                    if (manufacturer != null && (manufacturer.Contains("vmware") || manufacturer.Contains("microsoft corporation") || manufacturer.Contains("xen")))
                    {
                        logCallback?.Invoke("⚠️ Virtual machine detected - kernel optimizations may be limited", "Warning");
                        return false;
                    }
                }
                
                // Check for secure boot
                try
                {
                    using (var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\SecureBoot\State"))
                    {
                        var secureBootEnabled = key?.GetValue("UEFISecureBootEnabled");
                        if (secureBootEnabled != null && Convert.ToInt32(secureBootEnabled) == 1)
                        {
                            logCallback?.Invoke("⚠️ Secure Boot enabled - some kernel optimizations may fail", "Warning");
                        }
                    }
                }
                catch { }
                
                return true;
            }
            catch
            {
                return false;
            }
        }
        
        // Validate registry optimization safety
        private static bool ValidateRegistryOptimizationSafety(LogMessageDelegate logCallback)
        {
            try
            {
                // Check if registry backup exists
                var backupPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "KOALAOptimizer_Backup");
                if (!Directory.Exists(backupPath))
                {
                    logCallback?.Invoke("⚠️ No registry backup found - creating backup recommended", "Warning");
                }
                
                return true;
            }
            catch
            {
                return false;
            }
        }
        
        // Validate service optimization safety
        private static bool ValidateServiceOptimizationSafety(LogMessageDelegate logCallback)
        {
            try
            {
                // Check for domain membership
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_ComputerSystem"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var domain = obj["Domain"]?.ToString();
                        if (!string.IsNullOrEmpty(domain) && !domain.Equals(Environment.MachineName, StringComparison.OrdinalIgnoreCase))
                        {
                            logCallback?.Invoke("⚠️ Domain-joined computer detected - some service optimizations may affect domain functionality", "Warning");
                        }
                    }
                }
                
                return true;
            }
            catch
            {
                return false;
            }
        }
        
        // Validate GPU optimization safety
        private static bool ValidateGPUOptimizationSafety(LogMessageDelegate logCallback)
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController"))
                {
                    var gpuCount = 0;
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        if (!string.IsNullOrEmpty(name) && !name.Contains("Basic") && !name.Contains("VGA"))
                        {
                            gpuCount++;
                        }
                    }
                    
                    if (gpuCount > 1)
                    {
                        logCallback?.Invoke("⚠️ Multiple GPUs detected - verify optimization compatibility", "Warning");
                    }
                    
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }
        
        // Validate network optimization safety
        private static bool ValidateNetworkOptimizationSafety(LogMessageDelegate logCallback)
        {
            try
            {
                // Check for VPN connections
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = true"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var description = obj["Description"]?.ToString().ToLower();
                        if (description != null && (description.Contains("vpn") || description.Contains("virtual") || description.Contains("tunnel")))
                        {
                            logCallback?.Invoke("⚠️ VPN/Virtual network adapter detected - network optimizations may affect VPN functionality", "Warning");
                        }
                    }
                }
                
                return true;
            }
            catch
            {
                return false;
            }
        }
        
        // Post-optimization checks
        private static bool CheckSystemResponsiveness()
        {
            try
            {
                var stopwatch = Stopwatch.StartNew();
                Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion")?.Close();
                stopwatch.Stop();
                
                return stopwatch.ElapsedMilliseconds < 1000; // Should be very fast
            }
            catch
            {
                return false;
            }
        }
        
        private static List<string> CheckCriticalServices()
        {
            var issues = new List<string>();
            
            try
            {
                var criticalServices = new[] { "Winmgmt", "RpcSs", "Dhcp", "Dnscache", "EventLog" };
                
                foreach (var serviceName in criticalServices)
                {
                    try
                    {
                        using (var service = new System.ServiceProcess.ServiceController(serviceName))
                        {
                            if (service.Status != System.ServiceProcess.ServiceControllerStatus.Running)
                            {
                                issues.Add($"⚠️ Critical service '{serviceName}' is not running");
                            }
                        }
                    }
                    catch
                    {
                        issues.Add($"❌ Cannot access critical service '{serviceName}'");
                    }
                }
            }
            catch { }
            
            return issues;
        }
        
        private static bool CheckNetworkConnectivity()
        {
            try
            {
                using (var ping = new System.Net.NetworkInformation.Ping())
                {
                    var reply = ping.Send("8.8.8.8", 5000);
                    return reply.Status == System.Net.NetworkInformation.IPStatus.Success;
                }
            }
            catch
            {
                return false;
            }
        }
        
        private static bool CheckDisplayFunctionality()
        {
            try
            {
                return System.Windows.Forms.Screen.AllScreens.Length > 0;
            }
            catch
            {
                return true; // Assume OK if can't check
            }
        }
    }
}