using System;
using System.Linq;
using System.Management;
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
        /// Detect GPU information
        /// </summary>
        public GpuInfo DetectGpu()
        {
            try
            {
                _logger.LogInfo("Detecting GPU information...");
                
                using (var searcher = new ManagementObjectSearcher("SELECT Name, DriverVersion FROM Win32_VideoController"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        var driverVersion = obj["DriverVersion"]?.ToString();
                        
                        // Skip basic display adapters
                        if (string.IsNullOrEmpty(name) || name.Contains("Microsoft Basic") || name.Contains("Remote Desktop"))
                        {
                            continue;
                        }
                        
                        var vendor = DetectVendor(name);
                        if (vendor != "Unknown")
                        {
                            _detectedGpu = new GpuInfo
                            {
                                Name = name,
                                Vendor = vendor,
                                DriverVersion = driverVersion ?? "Unknown",
                                HardwareSchedulingSupported = CheckHardwareSchedulingSupport(vendor)
                            };
                            
                            _logger.LogInfo($"GPU detected: {vendor} - {name}");
                            return _detectedGpu;
                        }
                    }
                }
                
                // Fallback GPU info if none detected
                _detectedGpu = new GpuInfo
                {
                    Name = "Unknown GPU",
                    Vendor = "Unknown",
                    DriverVersion = "Unknown",
                    HardwareSchedulingSupported = false
                };
                
                _logger.LogWarning("No dedicated GPU detected, using fallback info");
                return _detectedGpu;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to detect GPU: {ex.Message}", ex);
                
                return new GpuInfo
                {
                    Name = "Detection Failed",
                    Vendor = "Unknown",
                    DriverVersion = "Unknown",
                    HardwareSchedulingSupported = false
                };
            }
        }
        
        /// <summary>
        /// Detect GPU vendor from device name
        /// </summary>
        private string DetectVendor(string deviceName)
        {
            if (string.IsNullOrEmpty(deviceName))
                return "Unknown";
            
            var name = deviceName.ToUpperInvariant();
            
            if (name.Contains("NVIDIA") || name.Contains("GEFORCE") || name.Contains("GTX") || name.Contains("RTX") || name.Contains("QUADRO"))
            {
                return "NVIDIA";
            }
            
            if (name.Contains("AMD") || name.Contains("RADEON") || name.Contains("RX ") || name.Contains("VEGA") || name.Contains("NAVI"))
            {
                return "AMD";
            }
            
            if (name.Contains("INTEL") || name.Contains("HD GRAPHICS") || name.Contains("UHD GRAPHICS") || name.Contains("IRIS"))
            {
                return "Intel";
            }
            
            return "Unknown";
        }
        
        /// <summary>
        /// Check if hardware GPU scheduling is supported
        /// </summary>
        private bool CheckHardwareSchedulingSupport(string vendor)
        {
            // Hardware GPU scheduling is supported on Windows 10 2004+ with modern GPUs
            switch (vendor)
            {
                case "NVIDIA":
                    // NVIDIA GTX 1000 series and newer support hardware scheduling
                    return true;
                
                case "AMD":
                    // AMD RX 5000 series and newer support hardware scheduling
                    return true;
                
                case "Intel":
                    // Intel Xe graphics and newer support hardware scheduling
                    return true;
                
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// Get current GPU info (cached)
        /// </summary>
        public GpuInfo GetCurrentGpuInfo()
        {
            return _detectedGpu ?? DetectGpu();
        }
        
        /// <summary>
        /// Get GPU vendor
        /// </summary>
        public string GetGpuVendor()
        {
            var gpu = GetCurrentGpuInfo();
            return gpu?.Vendor ?? "Unknown";
        }
        
        /// <summary>
        /// Get GPU name
        /// </summary>
        public string GetGpuName()
        {
            var gpu = GetCurrentGpuInfo();
            return gpu?.Name ?? "Unknown GPU";
        }
        
        /// <summary>
        /// Check if current GPU supports hardware scheduling
        /// </summary>
        public bool SupportsHardwareScheduling()
        {
            var gpu = GetCurrentGpuInfo();
            return gpu?.HardwareSchedulingSupported ?? false;
        }
        
        /// <summary>
        /// Get recommended optimizations for detected GPU
        /// </summary>
        public string[] GetRecommendedOptimizations()
        {
            var vendor = GetGpuVendor();
            
            switch (vendor)
            {
                case "NVIDIA":
                    return new[]
                    {
                        "EnableHardwareGPUScheduling",
                        "DisableNvidiaTelemetry",
                        "OptimizeNvidiaControlPanel",
                        "DisableGPUPowerStates"
                    };
                
                case "AMD":
                    return new[]
                    {
                        "EnableHardwareGPUScheduling",
                        "DisableAMDExternalEvents",
                        "OptimizeAMDRadeonSettings",
                        "DisableGPUPowerStates"
                    };
                
                case "Intel":
                    return new[]
                    {
                        "EnableHardwareGPUScheduling",
                        "OptimizeIntelGraphics",
                        "DisableIntelTelemetry"
                    };
                
                default:
                    return new[]
                    {
                        "EnableHardwareGPUScheduling",
                        "OptimizeGenericGPU"
                    };
            }
        }
        
        /// <summary>
        /// Get GPU optimization description
        /// </summary>
        public string GetOptimizationDescription()
        {
            var vendor = GetGpuVendor();
            var name = GetGpuName();
            
            switch (vendor)
            {
                case "NVIDIA":
                    return $"NVIDIA GPU detected ({name}). Recommended optimizations include hardware scheduling, " +
                           "disabling telemetry services, and optimizing power states for maximum gaming performance.";
                
                case "AMD":
                    return $"AMD GPU detected ({name}). Recommended optimizations include hardware scheduling, " +
                           "disabling external events service, and optimizing Radeon settings for gaming.";
                
                case "Intel":
                    return $"Intel GPU detected ({name}). Recommended optimizations include hardware scheduling " +
                           "and Intel graphics-specific tweaks for better integrated graphics performance.";
                
                default:
                    return $"GPU detected ({name}). Basic optimizations available including hardware scheduling " +
                           "and generic performance improvements.";
            }
        }
        
        /// <summary>
        /// Refresh GPU detection
        /// </summary>
        public GpuInfo RefreshDetection()
        {
            _detectedGpu = null;
            return DetectGpu();
        }
        
        /// <summary>
        /// Get detailed GPU specifications
        /// </summary>
        public string GetDetailedGpuInfo()
        {
            try
            {
                var info = new System.Text.StringBuilder();
                
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        if (string.IsNullOrEmpty(name) || name.Contains("Microsoft Basic"))
                            continue;
                        
                        info.AppendLine($"GPU: {name}");
                        info.AppendLine($"Driver Version: {obj["DriverVersion"] ?? "Unknown"}");
                        info.AppendLine($"Driver Date: {obj["DriverDate"] ?? "Unknown"}");
                        info.AppendLine($"Video Memory: {FormatVideoMemory(obj["AdapterRAM"])}");
                        info.AppendLine($"Video Processor: {obj["VideoProcessor"] ?? "Unknown"}");
                        info.AppendLine($"Status: {obj["Status"] ?? "Unknown"}");
                        info.AppendLine();
                    }
                }
                
                return info.ToString();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to get detailed GPU info: {ex.Message}", ex);
                return "Failed to retrieve detailed GPU information.";
            }
        }
        
        /// <summary>
        /// Format video memory size
        /// </summary>
        private string FormatVideoMemory(object adapterRam)
        {
            try
            {
                if (adapterRam != null && uint.TryParse(adapterRam.ToString(), out uint ram))
                {
                    if (ram > 0)
                    {
                        var gb = ram / (1024.0 * 1024.0 * 1024.0);
                        if (gb >= 1)
                        {
                            return $"{gb:F1} GB";
                        }
                        else
                        {
                            var mb = ram / (1024.0 * 1024.0);
                            return $"{mb:F0} MB";
                        }
                    }
                }
            }
            catch
            {
                // Ignore errors
            }
            
            return "Unknown";
        }
    }
}