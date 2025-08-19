using System;
using Microsoft.Win32;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for audio latency optimizations
    /// </summary>
    public class AudioOptimizationService
    {
        private static readonly Lazy<AudioOptimizationService> _instance = new Lazy<AudioOptimizationService>(() => new AudioOptimizationService());
        public static AudioOptimizationService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        private readonly AdminService _adminService;
        
        private AudioOptimizationService()
        {
            _logger = LoggingService.Instance;
            _adminService = AdminService.Instance;
            _logger.LogInfo("Audio optimization service initialized");
        }
        
        /// <summary>
        /// Apply audio latency reduction optimizations
        /// </summary>
        public bool ReduceAudioLatency()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Audio latency optimization requires administrator privileges");
                    return false;
                }
                
                // Disable audio protection and reduce latency
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio", 
                    "DisableProtectedAudioDG", 1, RegistryValueKind.DWord);
                
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio", 
                    "DisableProtectedAudio", 1, RegistryValueKind.DWord);
                
                // Optimize audio service dependencies
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\AudioSrv", 
                    "DependOnService", new string[] { "AudioEndpointBuilder", "RpcSs" }, RegistryValueKind.MultiString);
                
                // Disable audio ducking
                SetRegistryValue(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Multimedia\Audio", 
                    "UserDuckingPreference", 3, RegistryValueKind.DWord);
                
                _logger.LogInfo("Audio latency reduction optimizations applied successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply audio latency optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Optimize audio for gaming performance
        /// </summary>
        public bool OptimizeAudioForGaming()
        {
            try
            {
                if (!_adminService.IsRunningAsAdmin())
                {
                    _logger.LogWarning("Audio gaming optimization requires administrator privileges");
                    return false;
                }
                
                // Set audio quality optimizations for gaming
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}\0000", 
                    "PowerSettings", 0, RegistryValueKind.DWord);
                
                // Disable audio enhancements that can cause latency
                SetRegistryValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render", 
                    "Properties", 0, RegistryValueKind.DWord);
                
                _logger.LogInfo("Audio gaming optimizations applied successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to apply audio gaming optimizations: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Helper method to set registry values safely
        /// </summary>
        private void SetRegistryValue(string keyPath, string valueName, object value, RegistryValueKind valueKind)
        {
            try
            {
                RegistryKey baseKey;
                string normalizedPath;
                
                if (keyPath.StartsWith(@"HKEY_LOCAL_MACHINE\"))
                {
                    baseKey = Registry.LocalMachine;
                    normalizedPath = keyPath.Replace(@"HKEY_LOCAL_MACHINE\", "");
                }
                else if (keyPath.StartsWith(@"HKEY_CURRENT_USER\"))
                {
                    baseKey = Registry.CurrentUser;
                    normalizedPath = keyPath.Replace(@"HKEY_CURRENT_USER\", "");
                }
                else
                {
                    throw new ArgumentException($"Unsupported registry root: {keyPath}");
                }
                
                using (var key = baseKey.CreateSubKey(normalizedPath))
                {
                    if (key != null)
                    {
                        key.SetValue(valueName, value, valueKind);
                        _logger.LogDebug($"Set registry value: {keyPath}\\{valueName} = {value}");
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to set registry value {keyPath}\\{valueName}: {ex.Message}");
                throw;
            }
        }
    }
}