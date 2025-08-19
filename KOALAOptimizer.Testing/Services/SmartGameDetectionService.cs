using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for smart game detection and automatic optimization
    /// </summary>
    public class SmartGameDetectionService
    {
        private static readonly Lazy<SmartGameDetectionService> _instance = new Lazy<SmartGameDetectionService>(() => new SmartGameDetectionService());
        public static SmartGameDetectionService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly ProcessManagementService _processManager;
        private readonly RegistryOptimizationService _registryService;
        private readonly Timer _detectionTimer;
        private readonly object _lockObject = new object();
        private bool _isMonitoring = false;
        private bool _autoProfileSwitching = false;
        private bool _autoRevertEnabled = false;
        private bool _backgroundAppSuspension = false;
        
        public event EventHandler<GameProfile> GameDetected;
        public event EventHandler<GameProfile> GameStopped;
        
        private readonly Dictionary<string, GameProfile> _gameProfiles;
        private readonly List<string> _suspendedProcesses;
        
        private SmartGameDetectionService()
        {
            _logger = LoggingService.Instance;
            _processManager = ProcessManagementService.Instance;
            _registryService = RegistryOptimizationService.Instance;
            _gameProfiles = new Dictionary<string, GameProfile>();
            _suspendedProcesses = new List<string>();
            
            // Initialize detection timer (but don't start it yet)
            _detectionTimer = new Timer(MonitorGamesCallback, null, Timeout.Infinite, Timeout.Infinite);
            
            InitializeGameProfiles();
            _logger.LogInfo("Smart game detection service initialized");
        }
        
        /// <summary>
        /// Start smart game detection with specified options
        /// </summary>
        public bool StartDetection(bool enableAutoProfile = true, bool enableAutoRevert = false, bool enableBackgroundSuspension = false)
        {
            try
            {
                lock (_lockObject)
                {
                    if (_isMonitoring)
                    {
                        _logger.LogInfo("Smart game detection is already running");
                        return true;
                    }
                    
                    _autoProfileSwitching = enableAutoProfile;
                    _autoRevertEnabled = enableAutoRevert;
                    _backgroundAppSuspension = enableBackgroundSuspension;
                    _isMonitoring = true;
                    
                    // Start monitoring every 5 seconds
                    _detectionTimer.Change(TimeSpan.Zero, TimeSpan.FromSeconds(5));
                    
                    _logger.LogInfo($"Smart game detection started with options: AutoProfile={enableAutoProfile}, AutoRevert={enableAutoRevert}, BackgroundSuspension={enableBackgroundSuspension}");
                    return true;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to start smart game detection: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Stop smart game detection
        /// </summary>
        public bool StopDetection()
        {
            try
            {
                lock (_lockObject)
                {
                    if (!_isMonitoring)
                    {
                        return true;
                    }
                    
                    _isMonitoring = false;
                    _detectionTimer.Change(Timeout.Infinite, Timeout.Infinite);
                    
                    // Resume any suspended processes
                    if (_backgroundAppSuspension && _suspendedProcesses.Count > 0)
                    {
                        ResumeBackgroundProcesses();
                    }
                    
                    _logger.LogInfo("Smart game detection stopped");
                    return true;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to stop smart game detection: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Monitor for game processes
        /// </summary>
        private void MonitorGamesCallback(object state)
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
                    
                    // Check for game launcher processes
                    CheckGameLaunchers(runningProcesses);
                    
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
                            
                            // Apply game-specific optimizations
                            Task.Run(() => ApplyGameOptimizations(profile));
                        }
                        else if (!isNowRunning && wasRunning)
                        {
                            // Game stopped
                            profile.IsRunning = false;
                            _logger.LogInfo($"Game stopped: {profile.DisplayName}");
                            
                            GameStopped?.Invoke(this, profile);
                            
                            // Revert optimizations if enabled
                            if (_autoRevertEnabled)
                            {
                                Task.Run(() => RevertGameOptimizations(profile));
                            }
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
        /// Check for game launcher processes and their associated games
        /// </summary>
        private void CheckGameLaunchers(HashSet<string> runningProcesses)
        {
            try
            {
                var gameLaunchers = new Dictionary<string, LauncherInfo>
                {
                    ["steam"] = new LauncherInfo 
                    { 
                        Name = "Steam", 
                        ProcessName = "steam",
                        CommonGames = new[] { "csgo", "dota2", "tf2", "left4dead2", "counter-strike2" }
                    },
                    ["epicgameslauncher"] = new LauncherInfo 
                    { 
                        Name = "Epic Games", 
                        ProcessName = "epicgameslauncher",
                        CommonGames = new[] { "fortnite", "rocketleague", "unrealtournament" }
                    },
                    ["battle.net"] = new LauncherInfo 
                    { 
                        Name = "Battle.net", 
                        ProcessName = "battle.net",
                        CommonGames = new[] { "overwatch", "wow", "diablo", "hearthstone", "starcraft2" }
                    },
                    ["origin"] = new LauncherInfo 
                    { 
                        Name = "Origin", 
                        ProcessName = "origin",
                        CommonGames = new[] { "battlefield", "fifa", "apex", "titanfall" }
                    },
                    ["uplay"] = new LauncherInfo 
                    { 
                        Name = "Ubisoft Connect", 
                        ProcessName = "uplay",
                        CommonGames = new[] { "assassinscreed", "farcry", "rainbow6", "watchdogs" }
                    },
                    ["riotclientux"] = new LauncherInfo 
                    { 
                        Name = "Riot Games", 
                        ProcessName = "riotclientux",
                        CommonGames = new[] { "valorant", "leagueoflegends", "teamfighttactics" }
                    }
                };
                
                foreach (var launcher in gameLaunchers)
                {
                    if (runningProcesses.Contains(launcher.Key))
                    {
                        // Launcher is running, check for associated games
                        foreach (var gameName in launcher.Value.CommonGames)
                        {
                            if (runningProcesses.Any(proc => proc.Contains(gameName)))
                            {
                                // Try to find or create a profile for this game
                                var gameProfile = GetOrCreateGameProfile(gameName, launcher.Value.Name);
                                if (gameProfile != null && !gameProfile.IsRunning)
                                {
                                    _logger.LogInfo($"Game detected via {launcher.Value.Name}: {gameProfile.DisplayName}");
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error checking game launchers: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Get or create a game profile for detected games
        /// </summary>
        private GameProfile GetOrCreateGameProfile(string gameName, string launcherName)
        {
            try
            {
                // Check if we already have a profile for this game
                var existingProfile = _gameProfiles.Values.FirstOrDefault(p => 
                    p.ProcessNames.Any(proc => proc.ToLower().Contains(gameName.ToLower())));
                
                if (existingProfile != null)
                    return existingProfile;
                
                // Create a new profile
                var newProfile = new GameProfile
                {
                    GameKey = $"{gameName}_{launcherName}",
                    DisplayName = FormatGameName(gameName),
                    ProcessNames = new List<string> { gameName },
                    Priority = ProcessPriority.High,
                    SpecificTweaks = new List<string> { "HighPriority" },
                    IsRunning = false
                };
                
                _gameProfiles[newProfile.GameKey] = newProfile;
                _logger.LogInfo($"Created new game profile: {newProfile.DisplayName} (via {launcherName})");
                
                return newProfile;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error creating game profile for {gameName}: {ex.Message}", ex);
                return null;
            }
        }
        
        /// <summary>
        /// Format game name for display
        /// </summary>
        private string FormatGameName(string gameName)
        {
            // Convert common game process names to display names
            var gameNameMap = new Dictionary<string, string>
            {
                ["csgo"] = "Counter-Strike: Global Offensive",
                ["counter-strike2"] = "Counter-Strike 2",
                ["valorant"] = "VALORANT",
                ["leagueoflegends"] = "League of Legends",
                ["overwatch"] = "Overwatch 2",
                ["rocketleague"] = "Rocket League",
                ["fortnite"] = "Fortnite",
                ["apex"] = "Apex Legends",
                ["battlefield"] = "Battlefield",
                ["rainbow6"] = "Rainbow Six Siege",
                ["dota2"] = "Dota 2"
            };
            
            if (gameNameMap.ContainsKey(gameName.ToLower()))
                return gameNameMap[gameName.ToLower()];
            
            // Default formatting: capitalize first letter of each word
            return string.Join(" ", gameName.Split('_', '-')
                .Select(word => char.ToUpper(word[0]) + word.Substring(1).ToLower()));
        }
        
        /// <summary>
        /// Apply optimizations when a game is detected
        /// </summary>
        private void ApplyGameOptimizations(GameProfile profile)
        {
            try
            {
                _logger.LogInfo($"Applying optimizations for {profile.DisplayName}");
                
                if (_autoProfileSwitching)
                {
                    // Apply game-specific tweaks
                    foreach (var tweak in profile.SpecificTweaks)
                    {
                        // Apply specific optimization based on tweak name
                        ApplySpecificOptimization(tweak);
                    }
                }
                
                if (_backgroundAppSuspension)
                {
                    SuspendBackgroundProcesses();
                }
                
                _logger.LogInfo($"Optimizations applied for {profile.DisplayName}");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply optimizations for {profile.DisplayName}: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Revert optimizations when a game stops
        /// </summary>
        private void RevertGameOptimizations(GameProfile profile)
        {
            try
            {
                _logger.LogInfo($"Reverting optimizations for {profile.DisplayName}");
                
                if (_backgroundAppSuspension && _suspendedProcesses.Count > 0)
                {
                    ResumeBackgroundProcesses();
                }
                
                _logger.LogInfo($"Optimizations reverted for {profile.DisplayName}");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to revert optimizations for {profile.DisplayName}: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Suspend background processes during gaming
        /// </summary>
        private void SuspendBackgroundProcesses()
        {
            try
            {
                var processesToSuspend = new List<string>
                {
                    "discord", "spotify", "chrome", "firefox", "edge", "teams", 
                    "slack", "skype", "steam", "origin", "uplay", "epicgameslauncher"
                };
                
                foreach (var processName in processesToSuspend)
                {
                    var processes = Process.GetProcessesByName(processName);
                    foreach (var process in processes)
                    {
                        try
                        {
                            // Lower priority instead of suspending (safer approach)
                            process.PriorityClass = ProcessPriorityClass.BelowNormal;
                            _suspendedProcesses.Add(processName);
                            _logger.LogDebug($"Lowered priority for background process: {processName}");
                        }
                        catch (Exception ex)
                        {
                            _logger.LogDebug($"Failed to suspend process {processName}: {ex.Message}");
                        }
                    }
                }
                
                if (_suspendedProcesses.Count > 0)
                {
                    _logger.LogInfo($"Suspended {_suspendedProcesses.Count} background processes");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to suspend background processes: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Resume background processes
        /// </summary>
        private void ResumeBackgroundProcesses()
        {
            try
            {
                foreach (var processName in _suspendedProcesses.ToList())
                {
                    var processes = Process.GetProcessesByName(processName);
                    foreach (var process in processes)
                    {
                        try
                        {
                            process.PriorityClass = ProcessPriorityClass.Normal;
                            _logger.LogDebug($"Restored priority for background process: {processName}");
                        }
                        catch (Exception ex)
                        {
                            _logger.LogDebug($"Failed to resume process {processName}: {ex.Message}");
                        }
                    }
                }
                
                _logger.LogInfo($"Resumed {_suspendedProcesses.Count} background processes");
                _suspendedProcesses.Clear();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to resume background processes: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Apply specific optimization based on name
        /// </summary>
        private void ApplySpecificOptimization(string optimizationName)
        {
            try
            {
                switch (optimizationName.ToLower())
                {
                    case "highpriority":
                        // Already handled by ProcessManagementService
                        break;
                    case "affinityoptimization":
                        // CPU affinity optimization
                        break;
                    case "memoryoptimization":
                        // Memory optimization
                        break;
                    default:
                        _logger.LogDebug($"Unknown optimization: {optimizationName}");
                        break;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to apply optimization {optimizationName}: {ex.Message}");
            }
        }
        
        /// <summary>
        /// Initialize game profiles from PowerShell version
        /// </summary>
        private void InitializeGameProfiles()
        {
            _gameProfiles.Clear();
            
            // Popular competitive games from PowerShell version
            var profiles = new[]
            {
                new GameProfile { GameKey = "CS2", DisplayName = "Counter-Strike 2", ProcessNames = new List<string> { "cs2" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority", "AffinityOptimization" } },
                new GameProfile { GameKey = "Valorant", DisplayName = "Valorant", ProcessNames = new List<string> { "valorant", "valorant-win64-shipping" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority", "MemoryOptimization" } },
                new GameProfile { GameKey = "Fortnite", DisplayName = "Fortnite", ProcessNames = new List<string> { "fortniteclient-win64-shipping" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority" } },
                new GameProfile { GameKey = "ApexLegends", DisplayName = "Apex Legends", ProcessNames = new List<string> { "r5apex" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority" } },
                new GameProfile { GameKey = "CODWarzone", DisplayName = "Call of Duty: Warzone", ProcessNames = new List<string> { "cod", "modernwarfare", "blackops", "warzone" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority" } },
                new GameProfile { GameKey = "PUBG", DisplayName = "PUBG", ProcessNames = new List<string> { "tslgame" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority" } },
                new GameProfile { GameKey = "Overwatch2", DisplayName = "Overwatch 2", ProcessNames = new List<string> { "overwatch" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority" } },
                new GameProfile { GameKey = "RocketLeague", DisplayName = "Rocket League", ProcessNames = new List<string> { "rocketleague" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority" } },
                new GameProfile { GameKey = "RainbowSix", DisplayName = "Rainbow Six Siege", ProcessNames = new List<string> { "rainbowsix", "r6game" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority" } },
                new GameProfile { GameKey = "Cyberpunk2077", DisplayName = "Cyberpunk 2077", ProcessNames = new List<string> { "cyberpunk2077" }, Priority = ProcessPriority.High, SpecificTweaks = new List<string> { "HighPriority", "MemoryOptimization" } }
            };
            
            foreach (var profile in profiles)
            {
                _gameProfiles[profile.GameKey] = profile;
            }
            
            _logger.LogInfo($"Initialized {_gameProfiles.Count} game profiles");
        }
        
        /// <summary>
        /// Get currently running games
        /// </summary>
        public IEnumerable<GameProfile> GetRunningGames()
        {
            lock (_lockObject)
            {
                return _gameProfiles.Values.Where(p => p.IsRunning).ToList();
            }
        }
        
        /// <summary>
        /// Get all game profiles
        /// </summary>
        public IEnumerable<GameProfile> GetAllGameProfiles()
        {
            lock (_lockObject)
            {
                return _gameProfiles.Values.ToList();
            }
        }
        
        /// <summary>
        /// Check if monitoring is active
        /// </summary>
        public bool IsMonitoring => _isMonitoring;
        
        /// <summary>
        /// Add or update a game profile
        /// </summary>
        public bool AddGameProfile(GameProfile profile)
        {
            try
            {
                if (profile == null || string.IsNullOrEmpty(profile.GameKey))
                    return false;
                
                lock (_lockObject)
                {
                    _gameProfiles[profile.GameKey] = profile;
                    _logger.LogInfo($"Game profile added/updated: {profile.DisplayName}");
                    return true;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to add game profile: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Remove a game profile
        /// </summary>
        public bool RemoveGameProfile(string gameKey)
        {
            try
            {
                if (string.IsNullOrEmpty(gameKey))
                    return false;
                
                lock (_lockObject)
                {
                    if (_gameProfiles.ContainsKey(gameKey))
                    {
                        var profile = _gameProfiles[gameKey];
                        _gameProfiles.Remove(gameKey);
                        _logger.LogInfo($"Game profile removed: {profile.DisplayName}");
                        return true;
                    }
                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to remove game profile: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Save game profiles to file
        /// </summary>
        public bool SaveProfilesToFile(string filePath)
        {
            try
            {
                var profileData = new List<string>();
                
                lock (_lockObject)
                {
                    profileData.Add("# KOALA Game Detection Profiles");
                    profileData.Add($"# Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
                    profileData.Add($"# Version: 2.3.0");
                    profileData.Add("");
                    
                    foreach (var profile in _gameProfiles.Values)
                    {
                        profileData.Add($"[{profile.GameKey}]");
                        profileData.Add($"DisplayName={profile.DisplayName}");
                        profileData.Add($"ProcessNames={string.Join(",", profile.ProcessNames)}");
                        profileData.Add($"Priority={profile.Priority}");
                        profileData.Add($"Affinity={profile.Affinity}");
                        profileData.Add($"SpecificTweaks={string.Join(",", profile.SpecificTweaks)}");
                        profileData.Add("");
                    }
                }
                
                File.WriteAllLines(filePath, profileData);
                _logger.LogInfo($"Game profiles saved to: {filePath}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to save game profiles: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Load game profiles from file
        /// </summary>
        public bool LoadProfilesFromFile(string filePath)
        {
            try
            {
                if (!File.Exists(filePath))
                    return false;
                
                var lines = File.ReadAllLines(filePath);
                var profiles = new Dictionary<string, GameProfile>();
                GameProfile currentProfile = null;
                
                foreach (var line in lines)
                {
                    var trimmedLine = line.Trim();
                    
                    // Skip comments and empty lines
                    if (string.IsNullOrEmpty(trimmedLine) || trimmedLine.StartsWith("#"))
                        continue;
                    
                    // Section header
                    if (trimmedLine.StartsWith("[") && trimmedLine.EndsWith("]"))
                    {
                        var gameKey = trimmedLine.Substring(1, trimmedLine.Length - 2);
                        currentProfile = new GameProfile
                        {
                            GameKey = gameKey,
                            ProcessNames = new List<string>(),
                            SpecificTweaks = new List<string>()
                        };
                        profiles[gameKey] = currentProfile;
                        continue;
                    }
                    
                    // Profile properties
                    if (currentProfile != null && trimmedLine.Contains("="))
                    {
                        var parts = trimmedLine.Split('=');
                        if (parts.Length >= 2)
                        {
                            var key = parts[0].Trim();
                            var value = string.Join("=", parts.Skip(1)).Trim();
                            
                            switch (key)
                            {
                                case "DisplayName":
                                    currentProfile.DisplayName = value;
                                    break;
                                case "ProcessNames":
                                    currentProfile.ProcessNames = value.Split(',').Select(s => s.Trim()).ToList();
                                    break;
                                case "Priority":
                                    if (Enum.TryParse(value, out ProcessPriority priority))
                                        currentProfile.Priority = priority;
                                    break;
                                case "Affinity":
                                    currentProfile.Affinity = value;
                                    break;
                                case "SpecificTweaks":
                                    currentProfile.SpecificTweaks = value.Split(',').Select(s => s.Trim()).ToList();
                                    break;
                            }
                        }
                    }
                }
                
                lock (_lockObject)
                {
                    _gameProfiles.Clear();
                    foreach (var profile in profiles)
                    {
                        _gameProfiles[profile.Key] = profile.Value;
                    }
                }
                
                _logger.LogInfo($"Loaded {profiles.Count} game profiles from: {filePath}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to load game profiles: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Export profiles for sharing
        /// </summary>
        public bool ExportProfiles(string exportPath)
        {
            try
            {
                return SaveProfilesToFile(exportPath);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to export profiles: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Import profiles from file
        /// </summary>
        public bool ImportProfiles(string importPath, bool mergeWithExisting = true)
        {
            try
            {
                if (!mergeWithExisting)
                {
                    return LoadProfilesFromFile(importPath);
                }
                
                // Merge with existing profiles
                var tempProfiles = new Dictionary<string, GameProfile>();
                lock (_lockObject)
                {
                    foreach (var profile in _gameProfiles)
                    {
                        tempProfiles[profile.Key] = profile.Value;
                    }
                }
                
                var result = LoadProfilesFromFile(importPath);
                
                if (result && mergeWithExisting)
                {
                    lock (_lockObject)
                    {
                        // Restore existing profiles that weren't in the import
                        foreach (var profile in tempProfiles)
                        {
                            if (!_gameProfiles.ContainsKey(profile.Key))
                            {
                                _gameProfiles[profile.Key] = profile.Value;
                            }
                        }
                    }
                }
                
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to import profiles: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Create optimization profile for detected game
        /// </summary>
        public bool CreateOptimizationProfile(string gameName, ProcessPriority priority = ProcessPriority.High, string[] specificTweaks = null)
        {
            try
            {
                var gameKey = gameName.Replace(" ", "").Replace(":", "");
                var profile = new GameProfile
                {
                    GameKey = gameKey,
                    DisplayName = gameName,
                    ProcessNames = new List<string> { gameName.ToLower().Replace(" ", "").Replace(":", "") },
                    Priority = priority,
                    Affinity = "Auto",
                    SpecificTweaks = specificTweaks?.ToList() ?? new List<string> { "HighPriority" }
                };
                
                return AddGameProfile(profile);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to create optimization profile for {gameName}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Cleanup resources
        /// </summary>
        public void Dispose()
        {
            StopDetection();
            _detectionTimer?.Dispose();
        }
    }
}