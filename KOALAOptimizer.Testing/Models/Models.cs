using System;
using System.Collections.Generic;
using System.Diagnostics;

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
    
    /// <summary>
    /// Crosshair profile for save/load functionality
    /// </summary>
    public class CrosshairProfile
    {
        public string Name { get; set; }
        public string DisplayName { get; set; }
        public string FilePath { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime LastModified { get; set; }
        public string Version { get; set; }
        public string Description { get; set; }
    }
    
    /// <summary>
    /// Game launcher information
    /// </summary>
    public class LauncherInfo
    {
        public string Name { get; set; }
        public string ProcessName { get; set; }
        public string[] CommonGames { get; set; }
        public string InstallPath { get; set; }
        public bool IsRunning { get; set; }
    }
    
    /// <summary>
    /// Process allocation profile for smart resource management
    /// </summary>
    public class ProcessAllocationProfile
    {
        public string Name { get; set; }
        public string[] ProcessPatterns { get; set; }
        public CpuAffinityStrategy CpuAffinityStrategy { get; set; }
        public ProcessPriorityClass Priority { get; set; }
        public MemoryPriority MemoryPriority { get; set; }
        public bool IoBoost { get; set; }
    }
    
    /// <summary>
    /// CPU affinity assignment strategies
    /// </summary>
    public enum CpuAffinityStrategy
    {
        AllCores,
        HighPerformanceCores,
        EfficiencyCores,
        DedicatedCores
    }
    
    /// <summary>
    /// Memory priority levels
    /// </summary>
    public enum MemoryPriority
    {
        Low,
        Normal,
        High,
        Critical
    }
    
    /// <summary>
    /// Individual process allocation result
    /// </summary>
    public class ProcessAllocation
    {
        public int ProcessId { get; set; }
        public string ProcessName { get; set; }
        public string Profile { get; set; }
        public IntPtr CpuAffinity { get; set; }
        public ProcessPriorityClass Priority { get; set; }
        public MemoryPriority MemoryPriority { get; set; }
        public bool IoBoost { get; set; }
        public DateTime AllocatedAt { get; set; } = DateTime.Now;
    }
    
    /// <summary>
    /// Resource allocation status
    /// </summary>
    public class ResourceAllocationStatus
    {
        public bool IsRunning { get; set; }
        public int TotalCores { get; set; }
        public List<ProcessAllocation> AllocatedProcesses { get; set; } = new List<ProcessAllocation>();
        public DateTime LastUpdate { get; set; } = DateTime.Now;
    }
    
    /// <summary>
    /// Resource allocation event arguments
    /// </summary>
    public class ResourceAllocationEventArgs : EventArgs
    {
        public List<ProcessAllocation> Allocations { get; set; } = new List<ProcessAllocation>();
    }
    
    /// <summary>
    /// Memory information details
    /// </summary>
    public class MemoryInfo
    {
        public double TotalMemoryMB { get; set; }
        public double AvailableMemoryMB { get; set; }
        public double UsedMemoryMB { get; set; }
        public double UsagePercentage { get; set; }
        public DateTime Timestamp { get; set; }
    }
    
    /// <summary>
    /// Memory optimization result
    /// </summary>
    public class MemoryOptimizationResult
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public MemoryInfo BeforeOptimization { get; set; }
        public MemoryInfo AfterOptimization { get; set; }
        public double MemoryFreed { get; set; }
        public int ProcessesTrimmed { get; set; }
        public bool SystemCacheCleared { get; set; }
        public bool GarbageCollectionPerformed { get; set; }
        public bool StandbyMemoryCleared { get; set; }
        public DateTime CompletedAt { get; set; } = DateTime.Now;
    }
    
    /// <summary>
    /// Memory optimization status
    /// </summary>
    public class MemoryOptimizationStatus
    {
        public bool IsRunning { get; set; }
        public bool IsDefragmenting { get; set; }
        public MemoryInfo CurrentMemoryInfo { get; set; }
        public double FragmentationPercentage { get; set; }
        public DateTime LastOptimization { get; set; }
    }
    
    /// <summary>
    /// Memory optimization event arguments
    /// </summary>
    public class MemoryOptimizationEventArgs : EventArgs
    {
        public MemoryOptimizationResult Result { get; set; }
    }
    
    /// <summary>
    /// Memory status event arguments
    /// </summary>
    public class MemoryStatusEventArgs : EventArgs
    {
        public MemoryInfo MemoryInfo { get; set; }
    }
    
    /// <summary>
    /// Disk drive type
    /// </summary>
    public enum DriveType
    {
        Unknown,
        SSD,
        HDD,
        Hybrid
    }
    
    /// <summary>
    /// Disk health status
    /// </summary>
    public enum DiskHealth
    {
        Unknown,
        Good,
        Warning,
        Critical
    }
    
    /// <summary>
    /// Disk alert types
    /// </summary>
    public enum DiskAlertType
    {
        LowSpace,
        HealthIssue,
        PerformanceIssue
    }
    
    /// <summary>
    /// Disk information details
    /// </summary>
    public class DiskInfo
    {
        public string DriveLetter { get; set; }
        public string Label { get; set; }
        public DriveType DriveType { get; set; }
        public double TotalSizeGB { get; set; }
        public double FreeSpaceGB { get; set; }
        public double UsagePercentage { get; set; }
        public string FileSystem { get; set; }
        public DiskHealth Health { get; set; }
        public DateTime LastChecked { get; set; } = DateTime.Now;
    }
    
    /// <summary>
    /// Disk optimization result
    /// </summary>
    public class DiskOptimizationResult
    {
        public string DiskLetter { get; set; }
        public DriveType DiskType { get; set; }
        public bool Success { get; set; }
        public string Message { get; set; }
        public List<string> OptimizationsApplied { get; set; } = new List<string>();
        public DateTime CompletedAt { get; set; } = DateTime.Now;
    }
    
    /// <summary>
    /// Disk optimization status
    /// </summary>
    public class DiskOptimizationStatus
    {
        public bool IsMonitoring { get; set; }
        public int TotalDisks { get; set; }
        public int SSDCount { get; set; }
        public int HDDCount { get; set; }
        public DateTime LastScan { get; set; }
    }
    
    /// <summary>
    /// Disk optimization event arguments
    /// </summary>
    public class DiskOptimizationEventArgs : EventArgs
    {
        public DiskOptimizationResult Result { get; set; }
    }
    
    /// <summary>
    /// Disk health event arguments
    /// </summary>
    public class DiskHealthEventArgs : EventArgs
    {
        public DiskInfo DiskInfo { get; set; }
        public DiskAlertType AlertType { get; set; }
    }
    
    /// <summary>
    /// Performance snapshot for historical tracking
    /// </summary>
    public class PerformanceSnapshot
    {
        public DateTime Timestamp { get; set; }
        public double CpuUsage { get; set; }
        public long MemoryUsage { get; set; }
        public long MemoryAvailable { get; set; }
        public double GpuUsage { get; set; }
        public int ActiveProcesses { get; set; }
    }
    
    /// <summary>
    /// Performance trend types
    /// </summary>
    public enum TrendType
    {
        Stable,
        Increasing,
        Decreasing,
        Volatile
    }
    
    /// <summary>
    /// Trend severity levels
    /// </summary>
    public enum TrendSeverity
    {
        Info,
        Warning,
        Critical
    }
    
    /// <summary>
    /// Bottleneck types
    /// </summary>
    public enum BottleneckType
    {
        CPU,
        Memory,
        GPU,
        Disk,
        Network
    }
    
    /// <summary>
    /// Bottleneck severity levels
    /// </summary>
    public enum BottleneckSeverity
    {
        Low,
        Medium,
        High,
        Critical
    }
    
    /// <summary>
    /// Performance trend analysis result
    /// </summary>
    public class PerformanceTrend
    {
        public string MetricName { get; set; }
        public TrendType Type { get; set; }
        public TrendSeverity Severity { get; set; }
        public double Direction { get; set; }
        public double Strength { get; set; }
        public double CurrentValue { get; set; }
        public double AverageValue { get; set; }
        public double MinValue { get; set; }
        public double MaxValue { get; set; }
        public int DataPoints { get; set; }
        public DateTime Timestamp { get; set; }
    }
    
    /// <summary>
    /// Performance bottleneck detection result
    /// </summary>
    public class PerformanceBottleneck
    {
        public BottleneckType Type { get; set; }
        public BottleneckSeverity Severity { get; set; }
        public double CurrentValue { get; set; }
        public string Description { get; set; }
        public List<string> Recommendations { get; set; } = new List<string>();
        public DateTime DetectedAt { get; set; } = DateTime.Now;
    }
    
    /// <summary>
    /// Performance prediction result
    /// </summary>
    public class PerformancePrediction
    {
        public string MetricName { get; set; }
        public double CurrentValue { get; set; }
        public double Prediction5Min { get; set; }
        public double Prediction10Min { get; set; }
        public double Prediction30Min { get; set; }
        public double Confidence { get; set; }
        public DateTime Timestamp { get; set; }
    }
    
    /// <summary>
    /// Performance trending status
    /// </summary>
    public class PerformanceTrendingStatus
    {
        public bool IsRunning { get; set; }
        public int DataPointsCollected { get; set; }
        public int MetricsTracked { get; set; }
        public DateTime LastAnalysis { get; set; }
    }
    
    /// <summary>
    /// Performance trend event arguments
    /// </summary>
    public class PerformanceTrendEventArgs : EventArgs
    {
        public PerformanceTrend Trend { get; set; }
    }
    
    /// <summary>
    /// Bottleneck detected event arguments
    /// </summary>
    public class BottleneckDetectedEventArgs : EventArgs
    {
        public PerformanceBottleneck Bottleneck { get; set; }
    }
    
    /// <summary>
    /// Performance prediction event arguments
    /// </summary>
    public class PerformancePredictionEventArgs : EventArgs
    {
        public List<PerformancePrediction> Predictions { get; set; } = new List<PerformancePrediction>();
    }
    
    /// <summary>
    /// FPS optimization severity levels
    /// </summary>
    public enum FpsOptimizationSeverity
    {
        Low,
        Medium,
        High,
        Critical
    }
    
    /// <summary>
    /// FPS reading data
    /// </summary>
    public class FpsReading
    {
        public DateTime Timestamp { get; set; }
        public double Fps { get; set; }
        public string ProcessName { get; set; }
        public string GameName { get; set; }
    }
    
    /// <summary>
    /// FPS optimization result
    /// </summary>
    public class FpsOptimization
    {
        public string GameName { get; set; }
        public double CurrentFps { get; set; }
        public double AverageFps { get; set; }
        public double MinFps { get; set; }
        public FpsOptimizationSeverity Severity { get; set; }
        public bool Success { get; set; }
        public List<string> OptimizationsApplied { get; set; } = new List<string>();
        public DateTime Timestamp { get; set; }
    }
    
    /// <summary>
    /// FPS statistics over a time period
    /// </summary>
    public class FpsStatistics
    {
        public string GameName { get; set; }
        public double AverageFps { get; set; }
        public double MinFps { get; set; }
        public double MaxFps { get; set; }
        public double FpsStability { get; set; }
        public int ReadingCount { get; set; }
        public TimeSpan TimeRange { get; set; }
    }
    
    /// <summary>
    /// FPS monitoring status
    /// </summary>
    public class FpsMonitoringStatus
    {
        public bool IsMonitoring { get; set; }
        public string CurrentGame { get; set; }
        public int ReadingsCollected { get; set; }
        public double CurrentFps { get; set; }
        public DateTime LastReading { get; set; }
    }
    
    /// <summary>
    /// FPS changed event arguments
    /// </summary>
    public class FpsChangedEventArgs : EventArgs
    {
        public FpsReading FpsReading { get; set; }
    }
    
    /// <summary>
    /// FPS optimization event arguments
    /// </summary>
    public class FpsOptimizationEventArgs : EventArgs
    {
        public FpsOptimization Optimization { get; set; }
    }
    
    /// <summary>
    /// System health assessment
    /// </summary>
    public class SystemHealthAssessment
    {
        public DateTime Timestamp { get; set; }
        public double OverallScore { get; set; }
        public HealthStatus CpuStatus { get; set; }
        public HealthStatus MemoryStatus { get; set; }
        public HealthStatus ProcessStatus { get; set; }
        public HealthStatus GpuStatus { get; set; }
        public List<string> Recommendations { get; set; } = new List<string>();
    }
    
    /// <summary>
    /// Health status levels
    /// </summary>
    public enum HealthStatus
    {
        Excellent,
        Good,
        Warning,
        Critical
    }
    
    /// <summary>
    /// Performance benchmark result
    /// </summary>
    public class BenchmarkResult
    {
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public string BenchmarkType { get; set; }
        public double OverallScore { get; set; }
        public double CpuScore { get; set; }
        public double MemoryScore { get; set; }
        public double ProcessScore { get; set; }
        public double GpuScore { get; set; }
        public double StabilityScore { get; set; }
        public bool IsSuccessful { get; set; }
        public string Notes { get; set; }
    }
    
    /// <summary>
    /// System health report
    /// </summary>
    public class SystemHealthReport
    {
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public string CheckVersion { get; set; }
        public HealthStatus OverallHealth { get; set; }
        public SystemInformation SystemInfo { get; set; }
        public HardwareInformation HardwareInfo { get; set; }
        public StorageInformation StorageInfo { get; set; }
        public NetworkInformation NetworkInfo { get; set; }
        public ProcessInformation ProcessInfo { get; set; }
        public ServiceInformation ServiceInfo { get; set; }
        public SecurityInformation SecurityInfo { get; set; }
        public PerformanceInformation PerformanceInfo { get; set; }
        public List<string> Recommendations { get; set; } = new List<string>();
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// System information
    /// </summary>
    public class SystemInformation
    {
        public string OperatingSystem { get; set; }
        public bool Is64Bit { get; set; }
        public int ProcessorCount { get; set; }
        public string UserName { get; set; }
        public string MachineName { get; set; }
        public string FrameworkVersion { get; set; }
        public long TotalPhysicalMemory { get; set; }
        public long AvailablePhysicalMemory { get; set; }
        public TimeSpan SystemUptime { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Hardware information
    /// </summary>
    public class HardwareInformation
    {
        public string CpuName { get; set; }
        public int CpuCores { get; set; }
        public int CpuLogicalProcessors { get; set; }
        public int CpuMaxClockSpeed { get; set; }
        public List<string> GpuDevices { get; set; } = new List<string>();
        public string MotherboardManufacturer { get; set; }
        public string MotherboardProduct { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Storage information
    /// </summary>
    public class StorageInformation
    {
        public List<DriveInformation> Drives { get; set; } = new List<DriveInformation>();
        public long TotalStorageSpace { get; set; }
        public long TotalFreeSpace { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Drive information
    /// </summary>
    public class DriveInformation
    {
        public string Name { get; set; }
        public string DriveType { get; set; }
        public string FileSystem { get; set; }
        public long TotalSize { get; set; }
        public long FreeSpace { get; set; }
        public long UsedSpace { get; set; }
        public double UsagePercentage { get; set; }
    }
    
    /// <summary>
    /// Network information
    /// </summary>
    public class NetworkInformation
    {
        public List<NetworkAdapterInfo> Adapters { get; set; } = new List<NetworkAdapterInfo>();
        public int ActiveAdapters { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Network adapter information
    /// </summary>
    public class NetworkAdapterInfo
    {
        public string Name { get; set; }
        public string AdapterType { get; set; }
        public string MACAddress { get; set; }
        public string Speed { get; set; }
        public bool IsConnected { get; set; }
    }
    
    /// <summary>
    /// Process information
    /// </summary>
    public class ProcessInformation
    {
        public int TotalProcesses { get; set; }
        public int SystemProcesses { get; set; }
        public List<ProcessInfo> TopMemoryConsumers { get; set; } = new List<ProcessInfo>();
        public long TotalMemoryUsage { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Process info
    /// </summary>
    public class ProcessInfo
    {
        public string Name { get; set; }
        public long MemoryUsage { get; set; }
        public TimeSpan CpuTime { get; set; }
    }
    
    /// <summary>
    /// Service information
    /// </summary>
    public class ServiceInformation
    {
        public int TotalServices { get; set; }
        public int RunningServices { get; set; }
        public int StoppedServices { get; set; }
        public List<ServiceInfo> CriticalServices { get; set; } = new List<ServiceInfo>();
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Service info
    /// </summary>
    public class ServiceInfo
    {
        public string Name { get; set; }
        public string DisplayName { get; set; }
        public string Status { get; set; }
    }
    
    /// <summary>
    /// Security information
    /// </summary>
    public class SecurityInformation
    {
        public bool IsRunningAsAdmin { get; set; }
        public bool UACEnabled { get; set; }
        public bool AntivirusRunning { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Performance information
    /// </summary>
    public class PerformanceInformation
    {
        public double CurrentCpuUsage { get; set; }
        public long CurrentMemoryUsage { get; set; }
        public int CurrentProcessCount { get; set; }
        public double CurrentGpuUsage { get; set; }
        public double PerformanceScore { get; set; }
        public HealthStatus CpuStatus { get; set; }
        public HealthStatus MemoryStatus { get; set; }
        public HealthStatus ProcessStatus { get; set; }
        public HealthStatus GpuStatus { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Compatibility report
    /// </summary>
    public class CompatibilityReport
    {
        public DateTime CheckDate { get; set; }
        public string ApplicationVersion { get; set; }
        public bool WindowsVersionSupported { get; set; }
        public bool DotNetVersionSupported { get; set; }
        public bool SufficientMemory { get; set; }
        public bool AdminPrivilegesAvailable { get; set; }
        public bool PerformanceCountersAvailable { get; set; }
        public bool WmiAccessAvailable { get; set; }
        public double CompatibilityScore { get; set; }
        public bool IsFullyCompatible { get; set; }
        public string ErrorMessage { get; set; }
    }
    
    /// <summary>
    /// Diagnostics event arguments
    /// </summary>
    public class DiagnosticsEventArgs : EventArgs
    {
        public SystemHealthReport Report { get; set; }
    }
    
    /// <summary>
    /// Game detected event arguments
    /// </summary>
    public class GameDetectedEventArgs : EventArgs
    {
        public GameProfile GameProfile { get; set; }
        public DateTime DetectionTime { get; set; }
        public int ProcessId { get; set; }
    }
    
    /// <summary>
    /// Game closed event arguments
    /// </summary>
    public class GameClosedEventArgs : EventArgs
    {
        public GameProfile GameProfile { get; set; }
        public DateTime ClosedTime { get; set; }
        public TimeSpan SessionDuration { get; set; }
    }
}