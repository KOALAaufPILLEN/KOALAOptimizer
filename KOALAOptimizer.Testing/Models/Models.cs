using System;
using System.Collections.Generic;

namespace KOALAOptimizer.Testing.Models
{
    /// <summary>
    /// Game profile configuration
    /// </summary>
    public class GameProfile
    {
        public string GameKey { get; set; }
        public string DisplayName { get; set; }
        public List<string> ProcessNames { get; set; } = new List<string>();
        public ProcessPriority Priority { get; set; } = ProcessPriority.High;
        public string Affinity { get; set; } = "Auto";
        public List<string> SpecificTweaks { get; set; } = new List<string>();
        public bool IsRunning { get; set; }
        public DateTime? LastDetected { get; set; }
    }

    /// <summary>
    /// Process priority levels
    /// </summary>
    public enum ProcessPriority
    {
        Idle,
        Normal,
        High,
        RealTime
    }

    /// <summary>
    /// Registry backup entry
    /// </summary>
    public class RegistryBackupEntry
    {
        public string Path { get; set; }
        public string Name { get; set; }
        public object Value { get; set; }
        public string Type { get; set; }
        public DateTime BackupTime { get; set; }
    }

    /// <summary>
    /// Service backup entry
    /// </summary>
    public class ServiceBackupEntry
    {
        public string ServiceName { get; set; }
        public string StartType { get; set; }
        public string Status { get; set; }
        public DateTime BackupTime { get; set; }
    }

    /// <summary>
    /// Windows service information
    /// </summary>
    public class ServiceInfo
    {
        public string ServiceName { get; set; }
        public string DisplayName { get; set; }
        public string Status { get; set; }
        public string StartType { get; set; }
    }

    /// <summary>
    /// Service backup information for restoration
    /// </summary>
    public class ServiceBackupInfo
    {
        public string ServiceName { get; set; }
        public string DisplayName { get; set; }
        public string OriginalStatus { get; set; }
        public string OriginalStartType { get; set; }
        public DateTime BackupTime { get; set; }
    }

    /// <summary>
    /// System performance metrics
    /// </summary>
    public class PerformanceMetrics
    {
        public double CpuUsage { get; set; }
        public long MemoryUsage { get; set; }
        public long MemoryAvailable { get; set; }
        public int ActiveProcesses { get; set; }
        public double GpuUsage { get; set; }
        public string GpuName { get; set; }
        public DateTime Timestamp { get; set; }
    }

    /// <summary>
    /// Optimization category
    /// </summary>
    public class OptimizationCategory
    {
        public string Name { get; set; }
        public string Description { get; set; }
        public List<OptimizationItem> Items { get; set; } = new List<OptimizationItem>();
        public bool IsExpanded { get; set; } = true;
    }

    /// <summary>
    /// Individual optimization item
    /// </summary>
    public class OptimizationItem
    {
        public string Name { get; set; }
        public string Description { get; set; }
        public bool IsEnabled { get; set; }
        public bool RequiresAdmin { get; set; }
        public string Category { get; set; }
        public OptimizationType Type { get; set; }
        public Dictionary<string, object> Parameters { get; set; } = new Dictionary<string, object>();
    }

    /// <summary>
    /// Optimization types
    /// </summary>
    public enum OptimizationType
    {
        Registry,
        Service,
        Process,
        Network,
        GPU,
        Power,
        Memory,
        Storage
    }

    /// <summary>
    /// Backup configuration
    /// </summary>
    public class BackupConfiguration
    {
        public DateTime CreatedDate { get; set; }
        public string Version { get; set; }
        public Dictionary<string, Dictionary<string, object>> Registry { get; set; } = new Dictionary<string, Dictionary<string, object>>();
        public Dictionary<string, Dictionary<string, object>> RegistryNICs { get; set; } = new Dictionary<string, Dictionary<string, object>>();
        public Dictionary<string, string> Services { get; set; } = new Dictionary<string, string>();
        public List<string> AppliedOptimizations { get; set; } = new List<string>();
        
        // Additional properties for backward compatibility with RegistryOptimizationService
        public List<RegistryBackupEntry> RegistryEntries { get; set; } = new List<RegistryBackupEntry>();
        public List<ServiceBackupEntry> ServiceSettings { get; set; } = new List<ServiceBackupEntry>();
    }

    /// <summary>
    /// GPU vendor information
    /// </summary>
    public class GpuInfo
    {
        public string Vendor { get; set; }
        public string Name { get; set; }
        public string DriverVersion { get; set; }
        public bool HardwareSchedulingSupported { get; set; }
    }

    /// <summary>
    /// Log entry
    /// </summary>
    public class LogEntry
    {
        public DateTime Timestamp { get; set; }
        public LogLevel Level { get; set; }
        public string Message { get; set; }
        public Exception Exception { get; set; }
    }

    /// <summary>
    /// Log levels
    /// </summary>
    public enum LogLevel
    {
        Info,
        Warning,
        Error,
        Debug
    }

    /// <summary>
    /// Theme information
    /// </summary>
    public class ThemeInfo
    {
        public string Name { get; set; }
        public string DisplayName { get; set; }
        public string ResourcePath { get; set; }
        public string Description { get; set; }
    }

    /// <summary>
    /// Network optimization settings
    /// </summary>
    public class NetworkOptimization
    {
        public bool DisableNagleAlgorithm { get; set; }
        public bool OptimizeTcpSettings { get; set; }
        public bool DisableNetworkThrottling { get; set; }
        public int TcpAckFrequency { get; set; }
        public bool EnableRSS { get; set; }
        public bool EnableECN { get; set; }
    }

    /// <summary>
    /// Crosshair overlay styles
    /// </summary>
    public enum CrosshairStyle
    {
        Classic,
        Dot,
        Circle,
        TShape,
        Plus,
        Cross,
        Custom
    }

    /// <summary>
    /// Crosshair overlay settings
    /// </summary>
    public class CrosshairSettings
    {
        public bool IsEnabled { get; set; } = false;
        public CrosshairStyle Style { get; set; } = CrosshairStyle.Classic;
        public int Size { get; set; } = 20;
        public int Thickness { get; set; } = 2;
        public int Red { get; set; } = 0;
        public int Green { get; set; } = 255;
        public int Blue { get; set; } = 0;
        public int Alpha { get; set; } = 255;
        public string HexColor { get; set; } = "#00FF00";
        public double Opacity { get; set; } = 1.0;
        public string SelectedTheme { get; set; } = "Classic Green";
        public bool ShowOnlyInGames { get; set; } = false;
        public string HotkeyToggle { get; set; } = "F1";
    }

    /// <summary>
    /// Predefined crosshair theme
    /// </summary>
    public class CrosshairTheme
    {
        public string Name { get; set; }
        public string DisplayName { get; set; }
        public string HexColor { get; set; }
        public int Red { get; set; }
        public int Green { get; set; }
        public int Blue { get; set; }
        public int Alpha { get; set; } = 255;
        public CrosshairStyle Style { get; set; } = CrosshairStyle.Classic;
        public int Size { get; set; } = 20;
        public int Thickness { get; set; } = 2;
        public string Description { get; set; }
    }
}