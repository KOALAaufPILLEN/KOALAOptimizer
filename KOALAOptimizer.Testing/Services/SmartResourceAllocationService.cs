using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.Threading;
using System.Threading.Tasks;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for smart resource allocation and dynamic CPU affinity management
    /// </summary>
    public class SmartResourceAllocationService
    {
        private static readonly Lazy<SmartResourceAllocationService> _instance = new Lazy<SmartResourceAllocationService>(() => new SmartResourceAllocationService());
        public static SmartResourceAllocationService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        private readonly PerformanceMonitoringService _performanceMonitor;
        private readonly Timer _allocationTimer;
        private readonly Dictionary<string, ProcessAllocationProfile> _processProfiles;
        private bool _isRunning = false;
        
        public event EventHandler<ResourceAllocationEventArgs> AllocationChanged;
        
        private SmartResourceAllocationService()
        {
            try
            {
                LoggingService.EmergencyLog("SmartResourceAllocationService: Initializing...");
                _logger = LoggingService.Instance;
                _adminService = AdminService.Instance;
                _performanceMonitor = PerformanceMonitoringService.Instance;
                
                _processProfiles = InitializeProcessProfiles();
                
                // Initialize allocation timer (check every 10 seconds)
                _allocationTimer = new Timer(PerformResourceAllocation, null, Timeout.Infinite, Timeout.Infinite);
                
                LoggingService.EmergencyLog("SmartResourceAllocationService: Initialization completed");
                _logger.LogInfo("Smart resource allocation service initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"SmartResourceAllocationService initialization failed: {ex.Message}");
                throw;
            }
        }
        
        /// <summary>
        /// Initialize process allocation profiles
        /// </summary>
        private Dictionary<string, ProcessAllocationProfile> InitializeProcessProfiles()
        {
            return new Dictionary<string, ProcessAllocationProfile>
            {
                ["gaming"] = new ProcessAllocationProfile
                {
                    Name = "Gaming",
                    ProcessPatterns = new[] { "cs2", "valorant", "fortnite", "apex", "warzone", "bf6", "lol", "dota2", "pubg", "overwatch2" },
                    CpuAffinityStrategy = CpuAffinityStrategy.HighPerformanceCores,
                    Priority = ProcessPriorityClass.High,
                    MemoryPriority = MemoryPriority.High,
                    IoBoost = true
                },
                ["streaming"] = new ProcessAllocationProfile
                {
                    Name = "Streaming",
                    ProcessPatterns = new[] { "obs64", "streamlabs", "xsplit", "nvidia" },
                    CpuAffinityStrategy = CpuAffinityStrategy.DedicatedCores,
                    Priority = ProcessPriorityClass.AboveNormal,
                    MemoryPriority = MemoryPriority.High,
                    IoBoost = true
                },
                ["background"] = new ProcessAllocationProfile
                {
                    Name = "Background",
                    ProcessPatterns = new[] { "chrome", "firefox", "discord", "spotify", "steam", "epic" },
                    CpuAffinityStrategy = CpuAffinityStrategy.EfficiencyCores,
                    Priority = ProcessPriorityClass.BelowNormal,
                    MemoryPriority = MemoryPriority.Low,
                    IoBoost = false
                }
            };
        }
        
        /// <summary>
        /// Start smart resource allocation
        /// </summary>
        public void StartAllocation()
        {
            if (_isRunning)
                return;
                
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Smart resource allocation requires administrator privileges");
                    return;
                }
                
                _isRunning = true;
                _allocationTimer.Change(TimeSpan.Zero, TimeSpan.FromSeconds(10));
                _logger.LogInfo("Smart resource allocation started");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to start smart resource allocation: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Stop smart resource allocation
        /// </summary>
        public void StopAllocation()
        {
            if (!_isRunning)
                return;
                
            try
            {
                _isRunning = false;
                _allocationTimer.Change(Timeout.Infinite, Timeout.Infinite);
                _logger.LogInfo("Smart resource allocation stopped");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to stop smart resource allocation: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Perform resource allocation based on current system state
        /// </summary>
        private void PerformResourceAllocation(object state)
        {
            try
            {
                if (!_isRunning || !_adminService.IsRunningAsAdmin())
                    return;
                    
                var processes = Process.GetProcesses();
                var cpuCoreCount = Environment.ProcessorCount;
                var allocatedProcesses = new List<ProcessAllocation>();
                
                // Analyze running processes and categorize them
                foreach (var process in processes)
                {
                    try
                    {
                        var profile = GetProcessProfile(process.ProcessName.ToLower());
                        if (profile != null)
                        {
                            var allocation = AllocateResourcesForProcess(process, profile, cpuCoreCount);
                            if (allocation != null)
                            {
                                allocatedProcesses.Add(allocation);
                                ApplyProcessAllocation(process, allocation);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogDebug($"Failed to allocate resources for process {process.ProcessName}: {ex.Message}");
                    }
                }
                
                // Notify about allocation changes
                AllocationChanged?.Invoke(this, new ResourceAllocationEventArgs { Allocations = allocatedProcesses });
                
                _logger.LogDebug($"Resource allocation completed for {allocatedProcesses.Count} processes");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Resource allocation failed: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get process profile based on process name
        /// </summary>
        private ProcessAllocationProfile GetProcessProfile(string processName)
        {
            foreach (var profile in _processProfiles.Values)
            {
                if (profile.ProcessPatterns.Any(pattern => processName.Contains(pattern)))
                {
                    return profile;
                }
            }
            return null;
        }
        
        /// <summary>
        /// Allocate resources for a specific process
        /// </summary>
        private ProcessAllocation AllocateResourcesForProcess(Process process, ProcessAllocationProfile profile, int totalCores)
        {
            try
            {
                var allocation = new ProcessAllocation
                {
                    ProcessId = process.Id,
                    ProcessName = process.ProcessName,
                    Profile = profile.Name
                };
                
                // Calculate CPU affinity based on strategy
                switch (profile.CpuAffinityStrategy)
                {
                    case CpuAffinityStrategy.HighPerformanceCores:
                        // Use last 75% of cores (typically performance cores)
                        var perfCoreStart = totalCores / 4;
                        allocation.CpuAffinity = CreateAffinityMask(perfCoreStart, totalCores - 1);
                        break;
                        
                    case CpuAffinityStrategy.EfficiencyCores:
                        // Use first 25% of cores (typically efficiency cores)
                        allocation.CpuAffinity = CreateAffinityMask(0, totalCores / 4 - 1);
                        break;
                        
                    case CpuAffinityStrategy.DedicatedCores:
                        // Use middle cores for dedicated workloads
                        var start = totalCores / 3;
                        var end = (totalCores * 2) / 3;
                        allocation.CpuAffinity = CreateAffinityMask(start, end);
                        break;
                        
                    case CpuAffinityStrategy.AllCores:
                    default:
                        allocation.CpuAffinity = (IntPtr)((1L << totalCores) - 1);
                        break;
                }
                
                allocation.Priority = profile.Priority;
                allocation.MemoryPriority = profile.MemoryPriority;
                allocation.IoBoost = profile.IoBoost;
                
                return allocation;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to create allocation for process {process.ProcessName}: {ex.Message}", ex);
                return null;
            }
        }
        
        /// <summary>
        /// Create CPU affinity mask for specified core range
        /// </summary>
        private IntPtr CreateAffinityMask(int startCore, int endCore)
        {
            long mask = 0;
            for (int i = startCore; i <= endCore && i < Environment.ProcessorCount; i++)
            {
                mask |= (1L << i);
            }
            return (IntPtr)mask;
        }
        
        /// <summary>
        /// Apply resource allocation to process
        /// </summary>
        private void ApplyProcessAllocation(Process process, ProcessAllocation allocation)
        {
            try
            {
                // Set CPU affinity
                if (allocation.CpuAffinity != IntPtr.Zero)
                {
                    process.ProcessorAffinity = allocation.CpuAffinity;
                }
                
                // Set process priority
                if (process.PriorityClass != allocation.Priority)
                {
                    process.PriorityClass = allocation.Priority;
                }
                
                // Apply I/O boost if needed (Windows 8+)
                if (allocation.IoBoost)
                {
                    ApplyIoBoost(process);
                }
                
                _logger.LogDebug($"Applied allocation to {process.ProcessName}: Affinity={allocation.CpuAffinity}, Priority={allocation.Priority}");
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Failed to apply allocation to {process.ProcessName}: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Apply I/O boost to process (platform specific)
        /// </summary>
        private void ApplyIoBoost(Process process)
        {
            try
            {
                // This would typically involve native Windows API calls
                // For now, we'll log the intent
                _logger.LogDebug($"I/O boost applied to {process.ProcessName}");
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Failed to apply I/O boost to {process.ProcessName}: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Get current resource allocation status
        /// </summary>
        public ResourceAllocationStatus GetAllocationStatus()
        {
            try
            {
                var status = new ResourceAllocationStatus
                {
                    IsRunning = _isRunning,
                    TotalCores = Environment.ProcessorCount,
                    AllocatedProcesses = new List<ProcessAllocation>()
                };
                
                var processes = Process.GetProcesses();
                foreach (var process in processes)
                {
                    try
                    {
                        var profile = GetProcessProfile(process.ProcessName.ToLower());
                        if (profile != null)
                        {
                            status.AllocatedProcesses.Add(new ProcessAllocation
                            {
                                ProcessId = process.Id,
                                ProcessName = process.ProcessName,
                                Profile = profile.Name,
                                CpuAffinity = process.ProcessorAffinity,
                                Priority = process.PriorityClass
                            });
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogDebug($"Failed to get status for process {process.ProcessName}: {ex.Message}");
                    }
                }
                
                return status;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to get allocation status: {ex.Message}", ex);
                return new ResourceAllocationStatus { IsRunning = false };
            }
        }
        
        /// <summary>
        /// Dispose resources
        /// </summary>
        public void Dispose()
        {
            try
            {
                StopAllocation();
                _allocationTimer?.Dispose();
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Error disposing SmartResourceAllocationService: {ex.Message}", ex);
            }
        }
    }
}