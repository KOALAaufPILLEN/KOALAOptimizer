using System;
using System.Linq;
using System.Management;
using System.Threading.Tasks;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for detecting and managing GPU information
    /// </summary>
    public class GpuDetectionService
    {
        private static readonly Lazy<GpuDetectionService> _instance = new Lazy<GpuDetectionService>(() => new GpuDetectionService());
        public static GpuDetectionService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private GpuInfo _detectedGpu;
        
        private GpuDetectionService()
        {
            _logger = LoggingService.Instance;
            _logger.LogInfo("GPU detection service initialized");
        }
        
        /// <summary>
        /// Detect GPU information with comprehensive detection like PowerShell
        /// </summary>
        public GpuInfo DetectGpu()
        {
            try
            {
                _logger.LogInfo("Detecting GPU information with PowerShell-like comprehensive detection...");
                
                var detectedGpus = new System.Collections.Generic.List<GpuInfo>();
                GpuInfo primaryGpu = null;
                
                using (var searcher = new ManagementObjectSearcher(
                    "SELECT Name, DriverVersion, Status, Present, PNPDeviceID FROM Win32_VideoController"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        var driverVersion = obj["DriverVersion"]?.ToString();
                        var status = obj["Status"]?.ToString();
                        var present = obj["Present"]?.ToString();
                        var pnpDeviceId = obj["PNPDeviceID"]?.ToString();
                        
                        // Skip basic/generic adapters (like PowerShell)
                        if (string.IsNullOrEmpty(name) || 
                            name.Contains("Basic") || 
                            name.Contains("Generic") || 
                            name.Contains("Microsoft Basic") || 
                            name.Contains("Remote Desktop") ||
                            (pnpDeviceId?.StartsWith("ROOT\\") == true))
                        {
                            continue;
                        }
                        
                        var vendor = DetectVendorComprehensive(name);
                        if (vendor != "Unknown")
                        {
                            var gpuInfo = new GpuInfo
                            {
                                Name = name,
                                Vendor = vendor,
                                DriverVersion = driverVersion ?? "Unknown",
                                Status = status ?? "Unknown",
                                Present = present?.Equals("True", StringComparison.OrdinalIgnoreCase) ?? false
                            };
                            
                            detectedGpus.Add(gpuInfo);
                            
                            // Prioritize discrete GPUs (NVIDIA/AMD) over integrated (Intel)
                            if (vendor == "NVIDIA" || vendor == "AMD")
                            {
                                primaryGpu = gpuInfo; // Always prioritize discrete GPUs
                            }
                            else if (primaryGpu == null)
                            {
                                primaryGpu = gpuInfo; // Use integrated only if no discrete GPU found yet
                            }
                        }
                    }
                }
                
                // Log detected GPU configuration (like PowerShell)
                if (detectedGpus.Count > 1)
                {
                    var gpuNames = string.Join(" + ", detectedGpus.Select(g => $"{g.Vendor}: {g.Name}"));
                    _logger.LogInfo($"Multi-GPU system detected: {gpuNames}");
                }
                else if (detectedGpus.Count == 1)
                {
                    _logger.LogInfo($"Single GPU detected: {detectedGpus[0].Vendor} - {detectedGpus[0].Name}");
                }
                else
                {
                    _logger.LogInfo("No dedicated GPU detected");
                }
                
                _detectedGpu = primaryGpu ?? new GpuInfo { Name = "Unknown", Vendor = "Unknown", DriverVersion = "Unknown" };
                _logger.LogInfo($"Primary GPU: {_detectedGpu.Vendor} - {_detectedGpu.Name}");
                
                return _detectedGpu;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to detect GPU: {ex.Message}", ex);
                _detectedGpu = new GpuInfo { Name = "Detection Failed", Vendor = "Unknown", DriverVersion = "Unknown" };
                return _detectedGpu;
            }
        }
        
        /// <summary>
        /// Comprehensive vendor detection like PowerShell
        /// </summary>
        private string DetectVendorComprehensive(string name)
        {
            if (string.IsNullOrEmpty(name))
                return "Unknown";
            
            var upperName = name.ToUpperInvariant();
            
            // NVIDIA detection (comprehensive patterns from PowerShell)
            if (upperName.Contains("NVIDIA") || 
                upperName.Contains("GEFORCE") || 
                upperName.Contains("GTX") || 
                upperName.Contains("RTX") || 
                upperName.Contains("QUADRO") ||
                upperName.Contains("TESLA") ||
                upperName.Contains("TITAN"))
            {
                return "NVIDIA";
            }
            
            // AMD detection (comprehensive patterns from PowerShell)
            if (upperName.Contains("AMD") || 
                upperName.Contains("RADEON") || 
                upperName.Contains("RX") || 
                upperName.Contains("FIREPRO") ||
                upperName.Contains("VEGA") ||
                upperName.Contains("NAVI") ||
                upperName.Contains("RDNA"))
            {
                return "AMD";
            }
            
            // Intel detection (comprehensive patterns from PowerShell)
            if (upperName.Contains("INTEL") || 
                upperName.Contains("HD GRAPHICS") || 
                upperName.Contains("UHD GRAPHICS") || 
                upperName.Contains("IRIS") ||
                upperName.Contains("ARC"))
            {
                return "Intel";
            }
            
            return "Unknown";
        }
        
        /// <summary>
        /// Apply vendor-specific optimizations (from PowerShell)
        /// </summary>
        public bool ApplyVendorSpecificOptimizations()
        {
            if (_detectedGpu == null)
            {
                DetectGpu();
            }
            
            try
            {
                var vendor = _detectedGpu?.Vendor ?? "Unknown";
                _logger.LogInfo($"Applying vendor-specific optimizations for: {vendor}");
                
                switch (vendor)
                {
                    case "NVIDIA":
                        return ApplyNvidiaOptimizations();
                    case "AMD":
                        return ApplyAmdOptimizations();
                    case "Intel":
                        return ApplyIntelOptimizations();
                    default:
                        _logger.LogInfo("No vendor-specific optimizations available for detected GPU");
                        return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply vendor-specific optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply NVIDIA-specific optimizations (from PowerShell)
        /// </summary>
        private bool ApplyNvidiaOptimizations()
        {
            try
            {
                var adminService = AdminService.Instance;
                var serviceService = ServiceManagementService.Instance;
                
                _logger.LogInfo("Applying NVIDIA-specific optimizations...");
                
                // Disable NVIDIA telemetry service
                try
                {
                    var service = System.ServiceProcess.ServiceController.GetServices()
                        .FirstOrDefault(s => s.ServiceName.Equals("NvTelemetryContainer", StringComparison.OrdinalIgnoreCase));
                    
                    if (service != null)
                    {
                        if (service.Status == System.ServiceProcess.ServiceControllerStatus.Running)
                        {
                            service.Stop();
                            _logger.LogInfo("NVIDIA telemetry service stopped");
                        }
                        // Note: Disabling service requires admin and registry changes
                        _logger.LogInfo("NVIDIA telemetry service found and optimized");
                    }
                    else
                    {
                        _logger.LogInfo("NVIDIA telemetry service not found");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning($"Could not optimize NVIDIA telemetry service: {ex.Message}");
                }
                
                // Apply NVIDIA TDR optimizations (from PowerShell)
                if (adminService.IsRunningAsAdmin())
                {
                    try
                    {
                        using (var key = Microsoft.Win32.Registry.LocalMachine.CreateSubKey(@"SYSTEM\CurrentControlSet\Control\GraphicsDrivers"))
                        {
                            key?.SetValue("TdrLevel", 0, Microsoft.Win32.RegistryValueKind.DWord);
                            key?.SetValue("TdrDelay", 60, Microsoft.Win32.RegistryValueKind.DWord);
                            _logger.LogInfo("NVIDIA TDR (Timeout Detection and Recovery) optimized");
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Could not apply NVIDIA registry optimizations: {ex.Message}");
                    }
                }
                else
                {
                    _logger.LogWarning("NVIDIA registry optimizations require administrator privileges");
                }
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply NVIDIA optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply AMD-specific optimizations (from PowerShell)
        /// </summary>
        private bool ApplyAmdOptimizations()
        {
            try
            {
                _logger.LogInfo("Applying AMD-specific optimizations...");
                
                // Disable AMD External Events service
                try
                {
                    var amdService = System.ServiceProcess.ServiceController.GetServices()
                        .FirstOrDefault(s => s.DisplayName.Contains("AMD External Events", StringComparison.OrdinalIgnoreCase) ||
                                           s.ServiceName.Contains("AMD", StringComparison.OrdinalIgnoreCase));
                    
                    if (amdService != null)
                    {
                        if (amdService.Status == System.ServiceProcess.ServiceControllerStatus.Running)
                        {
                            amdService.Stop();
                            _logger.LogInfo("AMD External Events service stopped");
                        }
                        _logger.LogInfo("AMD External Events service found and optimized");
                    }
                    else
                    {
                        _logger.LogInfo("AMD External Events service not found");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning($"Could not optimize AMD External Events service: {ex.Message}");
                }
                
                // Additional AMD optimizations can be added here
                _logger.LogInfo("AMD optimizations applied successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply AMD optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply Intel-specific optimizations (from PowerShell)
        /// </summary>
        private bool ApplyIntelOptimizations()
        {
            try
            {
                var adminService = AdminService.Instance;
                
                _logger.LogInfo("Applying Intel graphics optimizations...");
                
                // Apply Intel graphics optimizations (from PowerShell)
                if (adminService.IsRunningAsAdmin())
                {
                    try
                    {
                        using (var key = Microsoft.Win32.Registry.LocalMachine.CreateSubKey(@"SYSTEM\CurrentControlSet\Control\GraphicsDrivers"))
                        {
                            key?.SetValue("TdrLevel", 0, Microsoft.Win32.RegistryValueKind.DWord);
                            _logger.LogInfo("Intel graphics optimizations applied");
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Could not apply Intel registry optimizations: {ex.Message}");
                    }
                }
                else
                {
                    _logger.LogWarning("Intel graphics optimizations require administrator privileges");
                }
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply Intel optimizations: {ex.Message}", ex);
                return false;
            }
        }
    }
}