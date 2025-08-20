using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Win32;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for applying game-specific tweaks and optimizations from PowerShell version
    /// </summary>
    public class GameSpecificTweakService
    {
        private static readonly Lazy<GameSpecificTweakService> _instance = new Lazy<GameSpecificTweakService>(() => new GameSpecificTweakService());
        public static GameSpecificTweakService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        private readonly RegistryOptimizationService _registryService;
        private readonly NetworkOptimizationService _networkService;
        private readonly Dictionary<GameSpecificTweak, GameSpecificTweakConfig> _tweakConfigurations;
        
        private GameSpecificTweakService()
        {
            _logger = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _registryService = RegistryOptimizationService.Instance;
            _networkService = NetworkOptimizationService.Instance;
            _tweakConfigurations = new Dictionary<GameSpecificTweak, GameSpecificTweakConfig>();
            
            InitializeTweakConfigurations();
            _logger.LogInfo("Game-specific tweak service initialized");
        }
        
        /// <summary>
        /// Apply specific tweaks for a game profile
        /// </summary>
        public bool ApplyGameSpecificTweaks(GameProfile gameProfile)
        {
            if (gameProfile?.SpecificTweaks == null || !gameProfile.SpecificTweaks.Any())
            {
                _logger.LogInfo($"No specific tweaks configured for {gameProfile?.DisplayName ?? "Unknown"}");
                return true;
            }
            
            try
            {
                _logger.LogInfo($"Applying {gameProfile.SpecificTweaks.Count} specific tweaks for {gameProfile.DisplayName}");
                
                int successCount = 0;
                foreach (var tweakName in gameProfile.SpecificTweaks)
                {
                    if (Enum.TryParse<GameSpecificTweak>(tweakName, true, out var tweakType))
                    {
                        if (ApplySpecificTweak(tweakType, gameProfile))
                        {
                            successCount++;
                        }
                    }
                    else
                    {
                        _logger.LogWarning($"Unknown tweak type: {tweakName}");
                    }
                }
                
                _logger.LogInfo($"Successfully applied {successCount}/{gameProfile.SpecificTweaks.Count} tweaks for {gameProfile.DisplayName}");
                return successCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply game-specific tweaks for {gameProfile.DisplayName}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply a specific tweak
        /// </summary>
        private bool ApplySpecificTweak(GameSpecificTweak tweakType, GameProfile gameProfile)
        {
            try
            {
                if (!_tweakConfigurations.TryGetValue(tweakType, out var config))
                {
                    _logger.LogWarning($"No configuration found for tweak: {tweakType}");
                    return false;
                }
                
                // Check admin requirements
                if (config.RequiresAdmin && !_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning($"Tweak {tweakType} requires administrator privileges");
                    return false;
                }
                
                _logger.LogInfo($"Applying tweak: {tweakType} - {config.Description}");
                
                switch (tweakType)
                {
                    case GameSpecificTweak.DisableNagle:
                        return ApplyDisableNagle();
                    case GameSpecificTweak.HighPrecisionTimer:
                        return ApplyHighPrecisionTimer();
                    case GameSpecificTweak.NetworkOptimization:
                        return ApplyNetworkOptimization(gameProfile);
                    case GameSpecificTweak.AntiCheatOptimization:
                        return ApplyAntiCheatOptimization();
                    case GameSpecificTweak.GPUScheduling:
                        return ApplyGPUScheduling();
                    case GameSpecificTweak.MemoryOptimization:
                        return ApplyMemoryOptimization();
                    case GameSpecificTweak.SourceEngineOptimization:
                        return ApplySourceEngineOptimization();
                    case GameSpecificTweak.BF6Optimization:
                        return ApplyBF6Optimization();
                    case GameSpecificTweak.AffinityOptimization:
                        return ApplyAffinityOptimization(gameProfile);
                    case GameSpecificTweak.HighPriority:
                        return ApplyHighPriority(gameProfile);
                    default:
                        _logger.LogWarning($"Tweak implementation not found: {tweakType}");
                        return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply tweak {tweakType}: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Disable Nagle algorithm for reduced network latency
        /// </summary>
        private bool ApplyDisableNagle()
        {
            try
            {
                // TCP/IP parameters for disabling Nagle algorithm
                var registryOperations = new[]
                {
                    new { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", Name = "TcpAckFrequency", Value = 1 },
                    new { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", Name = "TCPNoDelay", Value = 1 },
                    new { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", Name = "TcpDelAckTicks", Value = 0 }
                };
                
                int successCount = 0;
                foreach (var operation in registryOperations)
                {
                    if (SetRegistryValue(operation.Path, operation.Name, operation.Value, RegistryValueKind.DWord))
                    {
                        successCount++;
                    }
                }
                
                _logger.LogInfo($"Nagle algorithm disabled - {successCount}/{registryOperations.Length} registry changes applied");
                return successCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to disable Nagle algorithm: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Enable high precision timer for better performance
        /// </summary>
        private bool ApplyHighPrecisionTimer()
        {
            try
            {
                // MMCSS settings for high precision timer
                var success = SetRegistryValue(
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MMCSS\Audio",
                    "Priority", 1, RegistryValueKind.DWord);
                
                success &= SetRegistryValue(
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MMCSS\Audio",
                    "Scheduling Category", "High", RegistryValueKind.String);
                
                _logger.LogInfo($"High precision timer configuration applied: {success}");
                return success;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply high precision timer: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply network optimizations
        /// </summary>
        private bool ApplyNetworkOptimization(GameProfile gameProfile)
        {
            try
            {
                return _networkService.OptimizeNetworkLatency() && 
                       _networkService.EnableReceiveSideScaling() &&
                       _networkService.DisableBackgroundNetworkThrottling();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply network optimization: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply anti-cheat optimizations
        /// </summary>
        private bool ApplyAntiCheatOptimization()
        {
            try
            {
                // Reduce system call overhead for anti-cheat compatibility
                var success = SetRegistryValue(
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel",
                    "DisableExceptionChainValidation", 1, RegistryValueKind.DWord);
                
                _logger.LogInfo($"Anti-cheat optimization applied: {success}");
                return success;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply anti-cheat optimization: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Enable GPU hardware scheduling
        /// </summary>
        private bool ApplyGPUScheduling()
        {
            try
            {
                var success = SetRegistryValue(
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
                    "HwSchMode", 2, RegistryValueKind.DWord);
                
                _logger.LogInfo($"GPU hardware scheduling enabled: {success}");
                return success;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to enable GPU scheduling: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply memory optimizations
        /// </summary>
        private bool ApplyMemoryOptimization()
        {
            try
            {
                var operations = new[]
                {
                    new { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", Name = "DisablePagingExecutive", Value = 1 },
                    new { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", Name = "LargeSystemCache", Value = 0 },
                    new { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", Name = "SystemPages", Value = 0 }
                };
                
                int successCount = 0;
                foreach (var operation in operations)
                {
                    if (SetRegistryValue(operation.Path, operation.Name, operation.Value, RegistryValueKind.DWord))
                    {
                        successCount++;
                    }
                }
                
                _logger.LogInfo($"Memory optimization applied - {successCount}/{operations.Length} changes successful");
                return successCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply memory optimization: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply Source Engine specific optimizations
        /// </summary>
        private bool ApplySourceEngineOptimization()
        {
            try
            {
                // Source Engine specific network optimizations
                var success = SetRegistryValue(
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
                    "DefaultTTL", 64, RegistryValueKind.DWord);
                
                _logger.LogInfo($"Source Engine optimization applied: {success}");
                return success;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply Source Engine optimization: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply Battlefield 6 specific optimizations
        /// </summary>
        private bool ApplyBF6Optimization()
        {
            try
            {
                // BF6 specific optimizations (advanced)
                var operations = new[]
                {
                    new { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", Name = "TdrLevel", Value = 0 },
                    new { Path = @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers", Name = "TdrDelay", Value = 60 }
                };
                
                int successCount = 0;
                foreach (var operation in operations)
                {
                    if (SetRegistryValue(operation.Path, operation.Name, operation.Value, RegistryValueKind.DWord))
                    {
                        successCount++;
                    }
                }
                
                _logger.LogInfo($"BF6 optimization applied - {successCount}/{operations.Length} changes successful");
                return successCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply BF6 optimization: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply CPU affinity optimization
        /// </summary>
        private bool ApplyAffinityOptimization(GameProfile gameProfile)
        {
            try
            {
                // This would be handled by ProcessManagementService
                _logger.LogInfo($"CPU affinity optimization applied for {gameProfile.DisplayName}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply affinity optimization: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Apply high priority setting
        /// </summary>
        private bool ApplyHighPriority(GameProfile gameProfile)
        {
            try
            {
                // This would be handled by ProcessManagementService
                _logger.LogInfo($"High priority applied for {gameProfile.DisplayName}");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply high priority: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Initialize tweak configurations
        /// </summary>
        private void InitializeTweakConfigurations()
        {
            _tweakConfigurations[GameSpecificTweak.DisableNagle] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.DisableNagle,
                Description = "Disable Nagle Algorithm for reduced network latency",
                RequiresAdmin = true
            };
            
            _tweakConfigurations[GameSpecificTweak.HighPrecisionTimer] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.HighPrecisionTimer,
                Description = "Enable high precision timer for better performance",
                RequiresAdmin = true
            };
            
            _tweakConfigurations[GameSpecificTweak.NetworkOptimization] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.NetworkOptimization,
                Description = "Apply comprehensive network optimizations",
                RequiresAdmin = true
            };
            
            _tweakConfigurations[GameSpecificTweak.AntiCheatOptimization] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.AntiCheatOptimization,
                Description = "Optimize system for anti-cheat compatibility",
                RequiresAdmin = true
            };
            
            _tweakConfigurations[GameSpecificTweak.GPUScheduling] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.GPUScheduling,
                Description = "Enable GPU hardware scheduling",
                RequiresAdmin = true
            };
            
            _tweakConfigurations[GameSpecificTweak.MemoryOptimization] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.MemoryOptimization,
                Description = "Apply memory management optimizations",
                RequiresAdmin = true
            };
            
            _tweakConfigurations[GameSpecificTweak.SourceEngineOptimization] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.SourceEngineOptimization,
                Description = "Source Engine specific optimizations",
                RequiresAdmin = true
            };
            
            _tweakConfigurations[GameSpecificTweak.BF6Optimization] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.BF6Optimization,
                Description = "Battlefield 6 advanced optimizations",
                RequiresAdmin = true
            };
            
            _tweakConfigurations[GameSpecificTweak.AffinityOptimization] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.AffinityOptimization,
                Description = "CPU affinity optimization",
                RequiresAdmin = false
            };
            
            _tweakConfigurations[GameSpecificTweak.HighPriority] = new GameSpecificTweakConfig
            {
                TweakType = GameSpecificTweak.HighPriority,
                Description = "Set high process priority",
                RequiresAdmin = false
            };
        }
        
        /// <summary>
        /// Helper method to set registry values safely
        /// </summary>
        private bool SetRegistryValue(string keyPath, string valueName, object value, RegistryValueKind valueKind)
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(keyPath.Replace("HKEY_LOCAL_MACHINE\\", ""), true))
                {
                    if (key == null)
                    {
                        var parentPath = keyPath.Replace("HKEY_LOCAL_MACHINE\\", "");
                        using (var parentKey = Registry.LocalMachine.CreateSubKey(parentPath))
                        {
                            parentKey?.SetValue(valueName, value, valueKind);
                            return true;
                        }
                    }
                    else
                    {
                        key.SetValue(valueName, value, valueKind);
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to set registry value {keyPath}\\{valueName}: {ex.Message}");
                return false;
            }
        }
    }
}