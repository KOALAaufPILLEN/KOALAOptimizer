using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for managing and optimizing game processes
    /// </summary>
    public class ProcessManagementService
    {
        private static readonly Lazy<ProcessManagementService> _instance = new Lazy<ProcessManagementService>(() => new ProcessManagementService());
        public static ProcessManagementService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly Dictionary<string, GameProfile> _gameProfiles;
        private readonly Timer _monitoringTimer;
        private readonly object _lockObject = new object();
        private bool _isMonitoring = false;
        
        public event EventHandler<GameProfile> GameDetected;
        public event EventHandler<GameProfile> GameStopped;
        
        private ProcessManagementService()
        {
            _logger = LoggingService.Instance;
            _gameProfiles = InitializeGameProfiles();
            
            // Start monitoring timer (every 5 seconds)
            _monitoringTimer = new Timer(MonitorGameProcesses, null, TimeSpan.Zero, TimeSpan.FromSeconds(5));
        }
        
        /// <summary>
        /// Initialize game profiles based on the original PowerShell version
        /// </summary>
        private Dictionary<string, GameProfile> InitializeGameProfiles()
        {
            return new Dictionary<string, GameProfile>
            {
                ["cs2"] = new GameProfile
                {
                    GameKey = "cs2",
                    DisplayName = "Counter-Strike 2",
                    ProcessNames = new List<string> { "cs2" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "DisableNagle", "HighPrecisionTimer", "NetworkOptimization" }
                },
                ["csgo"] = new GameProfile
                {
                    GameKey = "csgo",
                    DisplayName = "Counter-Strike: Global Offensive",
                    ProcessNames = new List<string> { "csgo" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "DisableNagle", "HighPrecisionTimer" }
                },
                ["valorant"] = new GameProfile
                {
                    GameKey = "valorant",
                    DisplayName = "Valorant",
                    ProcessNames = new List<string> { "valorant", "valorant-win64-shipping" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "DisableNagle", "AntiCheatOptimization" }
                },
                ["fortnite"] = new GameProfile
                {
                    GameKey = "fortnite",
                    DisplayName = "Fortnite",
                    ProcessNames = new List<string> { "fortniteclient-win64-shipping" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "GPUScheduling", "MemoryOptimization" }
                },
                ["apexlegends"] = new GameProfile
                {
                    GameKey = "apexlegends",
                    DisplayName = "Apex Legends",
                    ProcessNames = new List<string> { "r5apex" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "DisableNagle", "SourceEngineOptimization" }
                },
                ["warzone"] = new GameProfile
                {
                    GameKey = "warzone",
                    DisplayName = "Call of Duty: Warzone",
                    ProcessNames = new List<string> { "modernwarfare", "warzone" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "MemoryOptimization", "NetworkOptimization" }
                },
                ["bf6"] = new GameProfile
                {
                    GameKey = "bf6",
                    DisplayName = "Battlefield 6",
                    ProcessNames = new List<string> { "bf6event", "bf6" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "BF6Optimization", "MemoryOptimization", "NetworkOptimization", "GPUScheduling" }
                },
                ["codmw2"] = new GameProfile
                {
                    GameKey = "codmw2",
                    DisplayName = "Call of Duty: Modern Warfare II",
                    ProcessNames = new List<string> { "cod", "cod22-cod", "modernwarfare2" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "MemoryOptimization", "NetworkOptimization", "AntiCheatOptimization" }
                },
                ["rainbow6"] = new GameProfile
                {
                    GameKey = "rainbow6",
                    DisplayName = "Rainbow Six Siege",
                    ProcessNames = new List<string> { "rainbowsix", "rainbowsix_vulkan" },
                    Priority = ProcessPriority.High,
                    Affinity = "Auto",
                    SpecificTweaks = new List<string> { "UbisoftOptimization", "NetworkOptimization" }
                }
            };
        }
        
        /// <summary>
        /// Get all available game profiles
        /// </summary>
        public IEnumerable<GameProfile> GetGameProfiles()
        {
            return _gameProfiles.Values;
        }
        
        /// <summary>
        /// Get game profile by key
        /// </summary>
        public GameProfile GetGameProfile(string gameKey)
        {
            return _gameProfiles.TryGetValue(gameKey, out var profile) ? profile : null;
        }
        
        /// <summary>
        /// Monitor for game processes
        /// </summary>
        private void MonitorGameProcesses(object state)
        {
            if (!_isMonitoring)
            {
                return;
            }
            
            try
            {
                lock (_lockObject)
                {
                    var runningProcesses = Process.GetProcesses().Select(p => p.ProcessName.ToLower()).ToHashSet();
                    
                    foreach (var profile in _gameProfiles.Values)
                    {
                        bool wasRunning = profile.IsRunning;
                        bool isNowRunning = profile.ProcessNames.Any(processName => 
                            runningProcesses.Contains(processName.ToLower()));
                        
                        if (isNowRunning && !wasRunning)
                        {
                            // Game started
                            profile.IsRunning = true;
                            profile.LastDetected = DateTime.Now;
                            _logger.LogInfo($"Game detected: {profile.DisplayName}");
                            GameDetected?.Invoke(this, profile);
                            
                            // Apply optimizations
                            Task.Run(() => ApplyGameOptimizations(profile));
                        }
                        else if (!isNowRunning && wasRunning)
                        {
                            // Game stopped
                            profile.IsRunning = false;
                            _logger.LogInfo($"Game stopped: {profile.DisplayName}");
                            GameStopped?.Invoke(this, profile);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error monitoring game processes: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Apply optimizations for a specific game
        /// </summary>
        private void ApplyGameOptimizations(GameProfile profile)
        {
            try
            {
                foreach (var processName in profile.ProcessNames)
                {
                    var processes = Process.GetProcessesByName(processName);
                    foreach (var process in processes)
                    {
                        try
                        {
                            // Set process priority
                            SetProcessPriority(process, profile.Priority);
                            
                            // Set CPU affinity if specified
                            if (profile.Affinity != "Auto")
                            {
                                SetProcessAffinity(process, profile.Affinity);
                            }
                            
                            _logger.LogInfo($"Optimizations applied to {processName} (PID: {process.Id})");
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning($"Failed to optimize process {processName}: {ex.Message}");
                        }
                        finally
                        {
                            process.Dispose();
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error applying game optimizations for {profile.DisplayName}: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Set process priority
        /// </summary>
        public bool SetProcessPriority(Process process, ProcessPriority priority)
        {
            try
            {
                var systemPriority = ConvertToSystemPriority(priority);
                process.PriorityClass = systemPriority;
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to set process priority: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Set process CPU affinity
        /// </summary>
        public bool SetProcessAffinity(Process process, string affinity)
        {
            try
            {
                if (affinity == "Auto")
                {
                    return true; // Let system handle automatically
                }
                
                // Parse affinity (e.g., "0,1,2,3" or "All")
                if (affinity == "All")
                {
                    process.ProcessorAffinity = (IntPtr)((1 << Environment.ProcessorCount) - 1);
                }
                else
                {
                    var cores = affinity.Split(',').Select(int.Parse).ToArray();
                    var affinityMask = cores.Aggregate(0, (mask, core) => mask | (1 << core));
                    process.ProcessorAffinity = (IntPtr)affinityMask;
                }
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to set process affinity: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Convert custom priority to system priority
        /// </summary>
        private ProcessPriorityClass ConvertToSystemPriority(ProcessPriority priority)
        {
            switch (priority)
            {
                case ProcessPriority.Idle:
                    return ProcessPriorityClass.Idle;
                case ProcessPriority.Normal:
                    return ProcessPriorityClass.Normal;
                case ProcessPriority.High:
                    return ProcessPriorityClass.High;
                case ProcessPriority.RealTime:
                    return ProcessPriorityClass.RealTime;
                default:
                    return ProcessPriorityClass.Normal;
            }
        }
        
        /// <summary>
        /// Start background monitoring
        /// </summary>
        public void StartBackgroundMonitoring()
        {
            _isMonitoring = true;
            _logger.LogInfo("Background process monitoring started");
        }
        
        /// <summary>
        /// Stop background monitoring
        /// </summary>
        public void StopBackgroundMonitoring()
        {
            _isMonitoring = false;
            _logger.LogInfo("Background process monitoring stopped");
        }
        
        /// <summary>
        /// Get currently running games
        /// </summary>
        public IEnumerable<GameProfile> GetRunningGames()
        {
            return _gameProfiles.Values.Where(p => p.IsRunning);
        }
        
        /// <summary>
        /// Manually detect and optimize a specific process
        /// </summary>
        public bool OptimizeProcess(string processName, ProcessPriority priority, string affinity = "Auto")
        {
            try
            {
                var processes = Process.GetProcessesByName(processName);
                
                if (!processes.Any())
                {
                    _logger.LogWarning($"Process '{processName}' not found");
                    return false;
                }
                
                foreach (var process in processes)
                {
                    try
                    {
                        SetProcessPriority(process, priority);
                        if (affinity != "Auto")
                        {
                            SetProcessAffinity(process, affinity);
                        }
                        
                        _logger.LogInfo($"Manual optimization applied to {processName} (PID: {process.Id})");
                    }
                    finally
                    {
                        process.Dispose();
                    }
                }
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to optimize process {processName}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Cleanup resources
        /// </summary>
        public void Dispose()
        {
            StopBackgroundMonitoring();
            _monitoringTimer?.Dispose();
        }
    }
}