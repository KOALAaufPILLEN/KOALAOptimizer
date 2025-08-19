using System;
using System.Diagnostics;
using System.Linq;
using System.Security.Principal;
using System.Windows;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Service for handling administrator privileges and elevation
    /// </summary>
    public class AdminService
    {
        private static readonly Lazy<AdminService> _instance = new Lazy<AdminService>(() => new AdminService());
        public static AdminService Instance => _instance.Value;
        
        private readonly LoggingService _logger;
        
        private AdminService()
        {
            try
            {
                LoggingService.EmergencyLog("AdminService: Initializing...");
                _logger = LoggingService.Instance;
                LoggingService.EmergencyLog("AdminService: LoggingService obtained successfully");
                _logger?.LogInfo("AdminService initialized");
            }
            catch (Exception ex)
            {
                LoggingService.EmergencyLog($"AdminService: Initialization failed - {ex.Message}");
                // Don't rethrow - allow service to continue with limited functionality
                _logger = null;
            }
        }
        
        /// <summary>
        /// Check if the application is running with administrator privileges
        /// </summary>
        public bool IsRunningAsAdmin()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to check admin privileges: {ex.Message}", ex);
                return false;
            }
        }
        
        /// <summary>
        /// Request elevation to administrator privileges
        /// </summary>
        public bool RequestElevation(bool showDialog = true)
        {
            if (IsRunningAsAdmin())
            {
                return true;
            }
            
            if (showDialog)
            {
                var result = MessageBox.Show(
                    "Administrator privileges are required for full optimization functionality.\n\n" +
                    "Would you like to restart the application as administrator?",
                    "Administrator Privileges Required",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);
                
                if (result != MessageBoxResult.Yes)
                {
                    return false;
                }
            }
            
            try
            {
                var processInfo = new ProcessStartInfo
                {
                    FileName = Process.GetCurrentProcess().MainModule.FileName,
                    UseShellExecute = true,
                    Verb = "runas",
                    WorkingDirectory = Environment.CurrentDirectory
                };
                
                Process.Start(processInfo);
                Application.Current.Shutdown();
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to restart with elevation: {ex.Message}", ex);
                
                if (showDialog)
                {
                    MessageBox.Show(
                        $"Failed to restart with administrator privileges:\n{ex.Message}",
                        "Elevation Failed",
                        MessageBoxButton.OK,
                        MessageBoxImage.Error);
                }
                
                return false;
            }
        }
        
        /// <summary>
        /// Check if a specific operation requires admin privileges
        /// </summary>
        public bool OperationRequiresAdmin(OptimizationType operationType)
        {
            switch (operationType)
            {
                case OptimizationType.Registry:
                case OptimizationType.Service:
                case OptimizationType.Power:
                case OptimizationType.Network:
                    return true;
                
                case OptimizationType.Process:
                case OptimizationType.GPU:
                case OptimizationType.Memory:
                case OptimizationType.Storage:
                    return false;
                
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// Get admin status message for UI display
        /// </summary>
        public string GetAdminStatusMessage()
        {
            if (IsRunningAsAdmin())
            {
                return "✓ Running with Administrator privileges - All optimizations available";
            }
            else
            {
                return "⚠ Limited privileges - Some optimizations require Administrator access";
            }
        }
        
        /// <summary>
        /// Check if current user can perform operation
        /// </summary>
        public bool CanPerformOperation(OptimizationItem operation, bool showWarning = true)
        {
            if (!operation.RequiresAdmin)
            {
                return true;
            }
            
            if (IsRunningAsAdmin())
            {
                return true;
            }
            
            if (showWarning)
            {
                _logger.LogWarning($"Operation '{operation.Name}' requires administrator privileges and will be skipped");
            }
            
            return false;
        }
        
        /// <summary>
        /// Validate admin requirements for a list of operations
        /// </summary>
        public AdminValidationResult ValidateOperations(System.Collections.Generic.List<OptimizationItem> operations)
        {
            var result = new AdminValidationResult
            {
                CanProceed = true,
                RequiresElevation = false
            };
            
            var isAdmin = IsRunningAsAdmin();
            
            foreach (var operation in operations)
            {
                if (operation.IsEnabled && operation.RequiresAdmin && !isAdmin)
                {
                    result.RequiresElevation = true;
                    result.RestrictedOperations.Add(operation);
                }
            }
            
            return result;
        }
        
        /// <summary>
        /// Validate process integrity and permissions before system modifications
        /// </summary>
        public ProcessIntegrityResult ValidateProcessIntegrity()
        {
            try
            {
                var result = new ProcessIntegrityResult
                {
                    IsValid = true,
                    SecurityStatus = SecurityStatusLevel.Secure
                };
                
                // Check process integrity
                var currentProcess = Process.GetCurrentProcess();
                
                // Validate process is running from expected location
                var processPath = currentProcess.MainModule?.FileName;
                if (string.IsNullOrEmpty(processPath))
                {
                    result.IsValid = false;
                    result.SecurityStatus = SecurityStatusLevel.Warning;
                    result.Issues.Add("Unable to determine process location");
                }
                else
                {
                    // Check if running from system directories (potential security concern)
                    var systemPaths = new[] { 
                        Environment.GetFolderPath(Environment.SpecialFolder.System),
                        Environment.GetFolderPath(Environment.SpecialFolder.Windows)
                    };
                    
                    if (systemPaths.Any(path => processPath.StartsWith(path, StringComparison.OrdinalIgnoreCase)))
                    {
                        result.SecurityStatus = SecurityStatusLevel.Warning;
                        result.Issues.Add("Process running from system directory - verify authenticity");
                    }
                }
                
                // Check for debugger attachment (security concern)
                if (Debugger.IsAttached)
                {
                    result.SecurityStatus = SecurityStatusLevel.Warning;
                    result.Issues.Add("Debugger attached - development environment detected");
                }
                
                // Validate current user identity
                try
                {
                    var identity = WindowsIdentity.GetCurrent();
                    if (identity == null || string.IsNullOrEmpty(identity.Name))
                    {
                        result.IsValid = false;
                        result.SecurityStatus = SecurityStatusLevel.Critical;
                        result.Issues.Add("Unable to verify user identity");
                    }
                    else
                    {
                        result.UserIdentity = identity.Name;
                        result.IsAuthenticated = identity.IsAuthenticated;
                        
                        if (!identity.IsAuthenticated)
                        {
                            result.SecurityStatus = SecurityStatusLevel.Warning;
                            result.Issues.Add("User identity not authenticated");
                        }
                    }
                }
                catch (Exception ex)
                {
                    result.IsValid = false;
                    result.SecurityStatus = SecurityStatusLevel.Critical;
                    result.Issues.Add($"Identity validation failed: {ex.Message}");
                }
                
                // Check system state before modifications
                if (result.IsValid)
                {
                    result.CanModifySystem = IsRunningAsAdmin();
                    if (!result.CanModifySystem)
                    {
                        result.SecurityStatus = SecurityStatusLevel.Warning;
                        result.Issues.Add("Insufficient privileges for system modifications");
                    }
                }
                
                _logger?.LogInfo($"Process integrity validation completed. Status: {result.SecurityStatus}, Valid: {result.IsValid}");
                
                if (result.Issues.Count > 0)
                {
                    _logger?.LogWarning($"Process integrity issues: {string.Join("; ", result.Issues)}");
                }
                
                return result;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Process integrity validation failed: {ex.Message}", ex);
                return new ProcessIntegrityResult
                {
                    IsValid = false,
                    SecurityStatus = SecurityStatusLevel.Critical,
                    Issues = new System.Collections.Generic.List<string> { $"Validation error: {ex.Message}" }
                };
            }
        }
        
        /// <summary>
        /// Validate secure registry access patterns before registry operations
        /// </summary>
        public RegistrySecurityResult ValidateRegistryAccess(string registryPath)
        {
            try
            {
                var result = new RegistrySecurityResult
                {
                    CanAccess = false,
                    SecurityLevel = RegistrySecurityLevel.Unknown
                };
                
                if (string.IsNullOrEmpty(registryPath))
                {
                    result.SecurityLevel = RegistrySecurityLevel.Denied;
                    result.Issues.Add("Registry path is null or empty");
                    return result;
                }
                
                // Check if path is in allowed locations
                var allowedPaths = new[]
                {
                    @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Games",
                    @"HKEY_CURRENT_USER\Control Panel",
                    @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services",
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control"
                };
                
                bool isAllowedPath = allowedPaths.Any(allowed => 
                    registryPath.StartsWith(allowed, StringComparison.OrdinalIgnoreCase));
                
                if (!isAllowedPath)
                {
                    result.SecurityLevel = RegistrySecurityLevel.Restricted;
                    result.Issues.Add("Registry path not in approved optimization locations");
                    _logger?.LogWarning($"Registry access attempt to non-approved path: {registryPath}");
                    return result;
                }
                
                // Check for dangerous registry locations
                var dangerousPaths = new[]
                {
                    @"HKEY_LOCAL_MACHINE\SAM",
                    @"HKEY_LOCAL_MACHINE\SECURITY",
                    @"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WinDefend",
                    @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
                };
                
                bool isDangerousPath = dangerousPaths.Any(dangerous => 
                    registryPath.StartsWith(dangerous, StringComparison.OrdinalIgnoreCase));
                
                if (isDangerousPath)
                {
                    result.SecurityLevel = RegistrySecurityLevel.Denied;
                    result.Issues.Add("Access to critical system registry locations is prohibited");
                    _logger?.LogError($"Attempted access to dangerous registry path: {registryPath}");
                    return result;
                }
                
                // Validate admin privileges for HKLM access
                if (registryPath.StartsWith("HKEY_LOCAL_MACHINE", StringComparison.OrdinalIgnoreCase))
                {
                    if (!IsRunningAsAdmin())
                    {
                        result.SecurityLevel = RegistrySecurityLevel.Restricted;
                        result.Issues.Add("Administrator privileges required for HKEY_LOCAL_MACHINE access");
                        return result;
                    }
                }
                
                result.CanAccess = true;
                result.SecurityLevel = RegistrySecurityLevel.Approved;
                result.ValidatedPath = registryPath;
                
                _logger?.LogDebug($"Registry access validated for path: {registryPath}");
                return result;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Registry access validation failed: {ex.Message}", ex);
                return new RegistrySecurityResult
                {
                    CanAccess = false,
                    SecurityLevel = RegistrySecurityLevel.Denied,
                    Issues = new System.Collections.Generic.List<string> { $"Validation error: {ex.Message}" }
                };
            }
        }
        
        /// <summary>
        /// Validate input for security threats before processing
        /// </summary>
        public InputValidationResult ValidateInput(string input, InputType inputType)
        {
            try
            {
                var result = new InputValidationResult
                {
                    IsValid = false,
                    SanitizedInput = string.Empty
                };
                
                if (string.IsNullOrEmpty(input))
                {
                    result.Issues.Add("Input is null or empty");
                    return result;
                }
                
                // Check input length
                if (input.Length > 1000)
                {
                    result.Issues.Add("Input exceeds maximum allowed length (1000 characters)");
                    return result;
                }
                
                // Check for potential injection attempts
                var suspiciousPatterns = new[]
                {
                    @"<script", @"javascript:", @"vbscript:", @"onload=", @"onerror=",
                    @"cmd.exe", @"powershell", @"wscript", @"cscript",
                    @"../", @"..\\", @"../../", @"..\..\",
                    @"DROP TABLE", @"DELETE FROM", @"UPDATE.*SET", @"INSERT INTO"
                };
                
                foreach (var pattern in suspiciousPatterns)
                {
                    if (System.Text.RegularExpressions.Regex.IsMatch(input, pattern, 
                        System.Text.RegularExpressions.RegexOptions.IgnoreCase))
                    {
                        result.Issues.Add($"Potentially malicious pattern detected: {pattern}");
                        _logger?.LogWarning($"Suspicious input pattern detected: {pattern} in input: {input.Substring(0, Math.Min(50, input.Length))}...");
                        return result;
                    }
                }
                
                // Type-specific validation
                switch (inputType)
                {
                    case InputType.RegistryPath:
                        if (!System.Text.RegularExpressions.Regex.IsMatch(input, @"^HKEY_[A-Z_]+\\[a-zA-Z0-9\\._\s-]+$"))
                        {
                            result.Issues.Add("Invalid registry path format");
                            return result;
                        }
                        break;
                        
                    case InputType.ProcessName:
                        if (!System.Text.RegularExpressions.Regex.IsMatch(input, @"^[a-zA-Z0-9._-]+$"))
                        {
                            result.Issues.Add("Invalid process name format");
                            return result;
                        }
                        break;
                        
                    case InputType.FilePath:
                        if (System.Text.RegularExpressions.Regex.IsMatch(input, @"[<>:""|?*]"))
                        {
                            result.Issues.Add("Invalid characters in file path");
                            return result;
                        }
                        break;
                        
                    case InputType.HexColor:
                        if (!System.Text.RegularExpressions.Regex.IsMatch(input, @"^#[0-9A-Fa-f]{6}$"))
                        {
                            result.Issues.Add("Invalid hex color format");
                            return result;
                        }
                        break;
                }
                
                result.IsValid = true;
                result.SanitizedInput = input.Trim();
                return result;
            }
            catch (Exception ex)
            {
                _logger?.LogError($"Input validation failed: {ex.Message}", ex);
                return new InputValidationResult
                {
                    IsValid = false,
                    Issues = new System.Collections.Generic.List<string> { $"Validation error: {ex.Message}" }
                };
            }
        }
    }
    
    /// <summary>
    /// Process integrity validation result
    /// </summary>
    public class ProcessIntegrityResult
    {
        public bool IsValid { get; set; }
        public SecurityStatusLevel SecurityStatus { get; set; }
        public bool CanModifySystem { get; set; }
        public string UserIdentity { get; set; }
        public bool IsAuthenticated { get; set; }
        public System.Collections.Generic.List<string> Issues { get; set; } = new System.Collections.Generic.List<string>();
    }
    
    /// <summary>
    /// Registry security validation result
    /// </summary>
    public class RegistrySecurityResult
    {
        public bool CanAccess { get; set; }
        public RegistrySecurityLevel SecurityLevel { get; set; }
        public string ValidatedPath { get; set; }
        public System.Collections.Generic.List<string> Issues { get; set; } = new System.Collections.Generic.List<string>();
    }
    
    /// <summary>
    /// Input validation result
    /// </summary>
    public class InputValidationResult
    {
        public bool IsValid { get; set; }
        public string SanitizedInput { get; set; }
        public System.Collections.Generic.List<string> Issues { get; set; } = new System.Collections.Generic.List<string>();
    }
    
    /// <summary>
    /// Security status levels
    /// </summary>
    public enum SecurityStatusLevel
    {
        Secure,
        Warning,
        Critical
    }
    
    /// <summary>
    /// Registry security levels
    /// </summary>
    public enum RegistrySecurityLevel
    {
        Unknown,
        Denied,
        Restricted,
        Approved
    }
    
    /// <summary>
    /// Input validation types
    /// </summary>
    public enum InputType
    {
        General,
        RegistryPath,
        ProcessName,
        FilePath,
        HexColor
    }
    
    /// <summary>
    /// Result of admin validation
    /// </summary>
    public class AdminValidationResult
    {
        public bool CanProceed { get; set; }
        public bool RequiresElevation { get; set; }
        public System.Collections.Generic.List<OptimizationItem> RestrictedOperations { get; set; } = new System.Collections.Generic.List<OptimizationItem>();
        
        public string GetSummary()
        {
            if (!RequiresElevation)
            {
                return "All selected optimizations can be applied.";
            }
            
            return $"{RestrictedOperations.Count} optimization(s) require administrator privileges and will be skipped.";
        }
    }
}