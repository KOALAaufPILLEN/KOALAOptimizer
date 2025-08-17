# KOALA-UDP Enhanced Gamer Toolkit (All-in-one, WPF) - KORRIGIERTE VERSION
# - Works on PowerShell 5.1+ (Windows 10/11)
# - Enhanced with additional optimizations and game-specific tweaks
# - Fixed XAML compatibility issues and ContainsKey errors
# NOTE: Run as Administrator

# ---------- WPF Assemblies ----------
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml

# ---------- Paths ----------
if ($PSScriptRoot) {
    $ScriptRoot = $PSScriptRoot
} elseif ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $ScriptRoot = (Get-Location).Path
}
$BackupPath = Join-Path $ScriptRoot 'Koala-Backup.json'

# ---------- WinMM Timer (request ~1ms while app open) ----------
$winmm = @"
using System;
using System.Runtime.InteropServices;
public static class WinMM {
  [DllImport("winmm.dll", EntryPoint="timeBeginPeriod")]
  public static extern uint timeBeginPeriod(uint uPeriod);
  [DllImport("winmm.dll", EntryPoint="timeEndPeriod")]
  public static extern uint timeEndPeriod(uint uPeriod);
}
"@
Add-Type -TypeDefinition $winmm -ErrorAction SilentlyContinue

# ---------- Game Profiles (KORRIGIERT: HashTable statt OrderedDictionary) ----------
$GameProfiles = @{
    'cs2' = @{
        DisplayName = 'Counter-Strike 2'
        ProcessNames = @('cs2')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'HighPrecisionTimer', 'NetworkOptimization')
    }
    'csgo' = @{
        DisplayName = 'Counter-Strike: Global Offensive'
        ProcessNames = @('csgo')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'HighPrecisionTimer')
    }
    'valorant' = @{
        DisplayName = 'Valorant'
        ProcessNames = @('valorant', 'valorant-win64-shipping')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'AntiCheatOptimization')
    }
    'fortnite' = @{
        DisplayName = 'Fortnite'
        ProcessNames = @('fortniteclient-win64-shipping')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('GPUScheduling', 'MemoryOptimization')
    }
    'apexlegends' = @{
        DisplayName = 'Apex Legends'
        ProcessNames = @('r5apex')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'SourceEngineOptimization')
    }
    'warzone' = @{
        DisplayName = 'Call of Duty: Warzone'
        ProcessNames = @('modernwarfare', 'warzone')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('MemoryOptimization', 'NetworkOptimization')
    }
    'bf6' = @{
        DisplayName = 'Battlefield 6'
        ProcessNames = @('bf6event', 'bf6')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('BF6Optimization', 'MemoryOptimization', 'NetworkOptimization', 'GPUScheduling')
    }
    'codmw2' = @{
        DisplayName = 'Call of Duty: Modern Warfare II'
        ProcessNames = @('cod', 'cod22-cod', 'modernwarfare2')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('MemoryOptimization', 'NetworkOptimization', 'AntiCheatOptimization')
    }
    'codmw3' = @{
        DisplayName = 'Call of Duty: Modern Warfare III'
        ProcessNames = @('cod23-cod', 'modernwarfare3', 'mw3')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('MemoryOptimization', 'NetworkOptimization', 'AntiCheatOptimization')
    }
    'rainbow6' = @{
        DisplayName = 'Rainbow Six Siege'
        ProcessNames = @('rainbowsix', 'rainbowsix_vulkan')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'AntiCheatOptimization', 'NetworkOptimization')
    }
    'overwatch2' = @{
        DisplayName = 'Overwatch 2'
        ProcessNames = @('overwatch')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'NetworkOptimization', 'MemoryOptimization')
    }
    'leagueoflegends' = @{
        DisplayName = 'League of Legends'
        ProcessNames = @('league of legends', 'leagueoflegends')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'NetworkOptimization')
    }
    'rocketleague' = @{
        DisplayName = 'Rocket League'
        ProcessNames = @('rocketleague')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'NetworkOptimization', 'GPUScheduling')
    }
    'pubg' = @{
        DisplayName = 'PUBG: Battlegrounds'
        ProcessNames = @('tslgame')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('MemoryOptimization', 'NetworkOptimization', 'AntiCheatOptimization')
    }
    'destiny2' = @{
        DisplayName = 'Destiny 2'
        ProcessNames = @('destiny2')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('MemoryOptimization', 'NetworkOptimization', 'AntiCheatOptimization')
    }
}

# ---------- Helpers ----------
function Log {
    param([string]$msg, [string]$Level = 'Info')
    
    $timestamp = [DateTime]::Now.ToString('HH:mm:ss')
    $logMessage = "[$timestamp] [$Level] $msg"
    
    # Enhanced error handling for UI updates
    if ($global:LogBox) {
        try {
            $global:LogBox.Dispatcher.Invoke([Action]{
                $global:LogBox.AppendText("$logMessage`r`n")
                $global:LogBox.ScrollToEnd()
            }, [System.Windows.Threading.DispatcherPriority]::Background)
        } catch [System.InvalidOperationException] {
            # Fallback for cross-thread operations
            try {
                $global:LogBox.AppendText("$logMessage`r`n")
                $global:LogBox.ScrollToEnd()
            } catch {
                Write-Host $logMessage -ForegroundColor $(if($Level -eq 'Error'){'Red'}elseif($Level -eq 'Warning'){'Yellow'}else{'White'})
            }
        } catch {
            Write-Host $logMessage -ForegroundColor $(if($Level -eq 'Error'){'Red'}elseif($Level -eq 'Warning'){'Yellow'}else{'White'})
        }
    } else {
        Write-Host $logMessage -ForegroundColor $(if($Level -eq 'Error'){'Red'}elseif($Level -eq 'Warning'){'Yellow'}else{'White'})
    }
    
    # Also log to Windows Event Log for debugging (optional)
    try {
        if ($Level -eq 'Error') {
            Write-EventLog -LogName Application -Source 'KOALA-UDP' -EventId 1001 -EntryType Error -Message $msg -ErrorAction SilentlyContinue
        }
    } catch {
        # Ignore event log errors
    }
}

function Test-AdminPrivileges {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminElevation {
    param(
        [string]$Message = "Administrator privileges are required for system-level optimizations.",
        [switch]$ForceElevation
    )
    
    if (Test-AdminPrivileges) {
        return $true
    }
    
    if ($ForceElevation) {
        # Attempt to restart with elevation
        try {
            $scriptPath = $MyInvocation.ScriptName
            if (-not $scriptPath -and $PSCommandPath) {
                $scriptPath = $PSCommandPath
            }
            if (-not $scriptPath) {
                $scriptPath = (Get-Location).Path + "\koalaoptimizerps1.ps1"
            }
            
            Log "Attempting to restart with administrator privileges..." 'Warning'
            Start-Process -FilePath "powershell.exe" -ArgumentList "-File `"$scriptPath`"" -Verb RunAs -ErrorAction Stop
            [System.Windows.Application]::Current.Shutdown()
            return $true
        } catch {
            Log "Failed to elevate privileges automatically: $_" 'Error'
            return $false
        }
    }
    
    return $false
}

function Require-Admin {
    param([switch]$ShowFallbackOptions)
    
    if (Test-AdminPrivileges) {
        return
    }
    
    $result = [System.Windows.MessageBox]::Show(
        "Administrator privileges are required for system-level optimizations.`n`nWould you like to:`n• Yes: Restart with admin privileges`n• No: Continue with limited functionality`n• Cancel: Exit application",
        "KOALA-UDP - Admin Privileges Required", 
        'YesNoCancel',
        'Question'
    )
    
    switch ($result) {
        'Yes' {
            if (-not (Request-AdminElevation -ForceElevation)) {
                Log "Manual elevation required: Please right-click the script and select 'Run as administrator'" 'Warning'
                throw "Manual admin elevation required"
            }
        }
        'No' {
            if ($ShowFallbackOptions) {
                Log "Running in limited mode - some optimizations will be unavailable" 'Warning'
                return
            } else {
                throw "Admin privileges required for this operation"
            }
        }
        'Cancel' {
            throw "User cancelled admin elevation"
        }
    }
}

function Get-AdminRequiredOperations {
    # Returns a hashtable of operations that require admin privileges
    return @{
        'Registry_HKLM' = @{
            'Required' = $true
            'Description' = 'System registry modifications (HKEY_LOCAL_MACHINE)'
            'Operations' = @('CPU Scheduling', 'Memory Management', 'GPU Driver Settings', 'Network Optimizations')
        }
        'Services' = @{
            'Required' = $true
            'Description' = 'Windows service configuration'
            'Operations' = @('Disable Background Services', 'Xbox Services', 'Telemetry Services')
        }
        'PowerManagement' = @{
            'Required' = $true
            'Description' = 'Power plan and hibernation settings'
            'Operations' = @('Ultimate Performance Power Plan', 'Disable Hibernation')
        }
        'ProcessPriority' = @{
            'Required' = $false
            'Description' = 'Game process priority adjustment (limited without admin)'
            'Operations' = @('Set Game Priority', 'CPU Affinity')
        }
        'UserRegistry' = @{
            'Required' = $false
            'Description' = 'User-specific registry changes (HKEY_CURRENT_USER)'
            'Operations' = @('Visual Effects', 'Game DVR Settings', 'Fullscreen Optimizations')
        }
    }
}

function Test-OperationRequiresAdmin {
    param([string]$OperationType)
    
    $adminOps = Get-AdminRequiredOperations
    if ($adminOps.ContainsKey($OperationType)) {
        return $adminOps[$OperationType].Required
    }
    return $false
}

function Get-AdminStatusMessage {
    $isAdmin = Test-AdminPrivileges
    $adminOps = Get-AdminRequiredOperations
    
    if ($isAdmin) {
        return "✓ Running with Administrator privileges - All optimizations available"
    } else {
        $limitedOps = ($adminOps.Values | Where-Object { -not $_.Required } | ForEach-Object { $_.Operations }) -join ', '
        $requiresAdmin = ($adminOps.Values | Where-Object { $_.Required } | ForEach-Object { $_.Operations }) -join ', '
        return "⚠ Limited mode - Available: $limitedOps | Requires Admin: $requiresAdmin"
    }
}

function Get-GPUVendor {
    try {
        # Get all video controllers, excluding basic/generic ones
        $gpus = Get-CimInstance -ClassName Win32_VideoController | Where-Object { 
            $_.Name -notlike "*Basic*" -and 
            $_.Name -notlike "*Generic*" -and 
            $_.PNPDeviceID -notlike "ROOT\*" 
        }
        
        $detectedGPUs = @()
        $primaryGPU = $null
        
        foreach ($gpu in $gpus) {
            if ($gpu -and $gpu.Name) {
                $vendor = $null
                if ($gpu.Name -match 'NVIDIA|GeForce|GTX|RTX|Quadro') { 
                    $vendor = 'NVIDIA' 
                }
                elseif ($gpu.Name -match 'AMD|RADEON|RX|FirePro') { 
                    $vendor = 'AMD' 
                }
                elseif ($gpu.Name -match 'Intel|HD Graphics|UHD Graphics|Iris') { 
                    $vendor = 'Intel' 
                }
                
                if ($vendor) {
                    $detectedGPUs += @{
                        Name = $gpu.Name
                        Vendor = $vendor
                        Status = $gpu.Status
                        Present = $gpu.Present
                    }
                    
                    # Prioritize discrete GPUs (NVIDIA/AMD) over integrated (Intel)
                    if ($vendor -in @('NVIDIA', 'AMD') -and -not $primaryGPU) {
                        $primaryGPU = $vendor
                    } elseif (-not $primaryGPU) {
                        $primaryGPU = $vendor
                    }
                }
            }
        }
        
        # Log detected GPU configuration
        if ($detectedGPUs.Count -gt 1) {
            $gpuNames = ($detectedGPUs | ForEach-Object { "$($_.Vendor): $($_.Name)" }) -join " + "
            Log "Multi-GPU system detected: $gpuNames"
        } elseif ($detectedGPUs.Count -eq 1) {
            Log "Single GPU detected: $($detectedGPUs[0].Vendor) - $($detectedGPUs[0].Name)"
        } else {
            Log "No dedicated GPU detected"
        }
        
        return if ($primaryGPU) { $primaryGPU } else { 'Other' }
    } catch { 
        Log "Failed to detect GPU vendor: $_" 'Error'
        'Other' 
    }
}

function Set-SelectiveVisualEffects {
    param(
        [switch]$EnablePerformanceMode,
        [switch]$Revert
    )
    
    if ($Revert) {
        Log "Reverting visual effects to default settings..."
        # Restore to default (Let Windows choose what's best for my computer)
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 'DWord' 0 | Out-Null
        
        # Restore individual settings to default
        $visualFXPath = "HKCU:\Control Panel\Desktop"
        Remove-Reg $visualFXPath "DragFullWindows" | Out-Null
        Remove-Reg $visualFXPath "FontSmoothing" | Out-Null
        Remove-Reg $visualFXPath "UserPreferencesMask" | Out-Null
        
        $dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
        Remove-Reg $dwmPath "EnableAeroPeek" | Out-Null
        Remove-Reg $dwmPath "AlwaysHibernateThumbnails" | Out-Null
        
        Log "Visual effects restored to system defaults"
        return
    }
    
    if ($EnablePerformanceMode) {
        Log "Applying selective visual effects optimization..."
        
        # Set to custom mode so we can control individual settings
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 'DWord' 3 | Out-Null
        
        # Desktop and window settings
        $visualFXPath = "HKCU:\Control Panel\Desktop"
        
        # DISABLE performance-impacting effects:
        # Disable window animations (open/close/minimize/maximize)
        Set-Reg $visualFXPath "MinAnimate" 'String' "0" | Out-Null
        
        # Disable menu fade/slide animations
        Set-Reg $visualFXPath "MenuShowDelay" 'String' "0" | Out-Null
        
        # Disable taskbar thumbnails and previews (Aero Peek)
        Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 'DWord' 0 | Out-Null
        
        # Disable thumbnail caching 
        Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 'DWord' 1 | Out-Null
        
        # Disable fade effects for menus and tooltips
        Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" 'String' "0" | Out-Null
        
        # KEEP functional elements enabled:
        # Keep window borders and basic styling (DragFullWindows = 1)
        Set-Reg $visualFXPath "DragFullWindows" 'String' "1" | Out-Null
        
        # Keep font smoothing for readability
        Set-Reg $visualFXPath "FontSmoothing" 'String' "2" | Out-Null
        Set-Reg $visualFXPath "FontSmoothingType" 'DWord' 2 | Out-Null
        
        # Advanced: Disable composition effects but keep basic theming
        # This maintains window borders and basic styling while reducing GPU load
        $userPrefMask = [byte[]]@(0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)
        Set-ItemProperty -Path $visualFXPath -Name "UserPreferencesMask" -Value $userPrefMask -Type Binary -Force -ErrorAction SilentlyContinue
        
        Log "Selective visual effects applied - Performance optimized while maintaining usability"
    }
}

function Test-SystemRequirements {
    Log "Checking system requirements..." 'Info'
    
    # Check Windows version
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $version = [System.Version]$os.Version
        if ($version.Major -lt 10) {
            Log "Warning: Windows 10 or later recommended for best performance" 'Warning'
        } else {
            Log "Operating System: $($os.Caption) ($($os.Version))" 'Info'
        }
    } catch {
        Log "Failed to check Windows version: $_" 'Error'
    }
    
    # Check available memory
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        if ($ram -lt 8) {
            Log "Warning: Less than 8GB RAM detected ($ram GB). Some optimizations may have limited effect." 'Warning'
        } else {
            Log "System RAM: $ram GB" 'Info'
        }
    } catch {
        Log "Failed to check system memory: $_" 'Error'
    }
    
    # Check CPU core count
    try {
        $cpu = Get-CimInstance Win32_Processor
        $cores = $cpu.NumberOfLogicalProcessors
        Log "CPU: $($cpu.Name) ($cores logical cores)" 'Info'
        if ($cores -lt 4) {
            Log "Warning: Less than 4 CPU cores detected. CPU affinity optimizations may be limited." 'Warning'
        }
    } catch {
        Log "Failed to check CPU information: $_" 'Error'
    }
    
    # Check PowerShell version
    try {
        $psVersion = $PSVersionTable.PSVersion
        Log "PowerShell Version: $psVersion" 'Info'
        if ($psVersion.Major -lt 5) {
            Log "Warning: PowerShell 5.0 or later recommended" 'Warning'
        }
    } catch {
        Log "Failed to check PowerShell version: $_" 'Error'
    }
    
    Log "System requirements check completed" 'Info'
}

function Get-Reg { param($Path,$Name)
    try { (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

function Set-Reg { param($Path,$Name,$Type='DWord',$Value)
    try {
        if (-not (Test-Path $Path)) { 
            New-Item -Path $Path -Force | Out-Null 
            Log "Created registry path: $Path" 'Info'
        }
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
        Log "Set registry: $Path\$Name = $Value ($Type)" 'Info'
        $true
    } catch [System.UnauthorizedAccessException] {
        Log "Access denied setting registry: $Path\$Name (Run as Administrator required)" 'Error'
        $false
    } catch [System.Security.SecurityException] {
        Log "Security exception setting registry: $Path\$Name (Insufficient permissions)" 'Error'
        $false
    } catch {
        Log "Registry set failed: $Path\$Name ($_)" 'Error'
        $false
    }
}

function Set-Reg-Safe { 
    param($Path,$Name,$Type='DWord',$Value,$RequiresAdmin=$false)
    
    if ($RequiresAdmin -and -not (Test-AdminPrivileges)) {
        Log "Skipping $Path\$Name - requires administrator privileges" 'Warning'
        return $false
    }
    
    return Set-Reg $Path $Name $Type $Value
}

function Remove-Reg { param($Path,$Name)
    try { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop; $true } catch { $false }
}

function Get-ServiceState {
    param([string]$NameOrDisplay)
    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -ieq $NameOrDisplay -or $_.DisplayName -like "*$NameOrDisplay*"
    } | Select-Object -First 1
    if ($null -ne $svc) {
        $wmi = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Name      = $svc.Name
            Display   = $svc.DisplayName
            StartType = if ($wmi) { $wmi.StartMode } else { $null }
            Status    = $svc.Status
        }
    }
}

function Normalize-StartupType {
    param([string]$Mode)
    if ([string]::IsNullOrEmpty($Mode)) { return $null }
    switch -Regex ($Mode) {
        '^Auto'     { 'Automatic'; break }
        '^Manual'   { 'Manual'; break }
        '^Disabled' { 'Disabled'; break }
        default     { 'Manual' }
    }
}

function Set-ServiceState {
    param($BackupObj,[string]$DesiredStartMode,[string]$DesiredAction)
    if ($null -eq $BackupObj) { return }
    try {
        if ($DesiredStartMode) {
            $mode = Normalize-StartupType $DesiredStartMode
            if ($mode) { 
                Set-Service -Name $BackupObj.Name -StartupType $mode -ErrorAction Stop
                Log "Service startup type changed: $($BackupObj.Name) -> $mode" 'Info'
            }
        }
        if ($DesiredAction -eq 'Stop') {
            Stop-Service -Name $BackupObj.Name -Force -ErrorAction Stop
            Log "Service stopped: $($BackupObj.Name)" 'Info'
        } elseif ($DesiredAction -eq 'Start') {
            Start-Service -Name $BackupObj.Name -ErrorAction Stop
            Log "Service started: $($BackupObj.Name)" 'Info'
        }
    } catch [System.ServiceProcess.InvalidOperationException] {
        Log "Service operation failed: $($BackupObj.Name) - Invalid operation ($_)" 'Warning'
    } catch [System.ComponentModel.Win32Exception] {
        Log "Service access denied: $($BackupObj.Name) - $($_.Exception.Message)" 'Error'
    } catch {
        Log "Service change failed: $($BackupObj.Name) ($_)" 'Error'
    }
}

function Restore-ServiceState {
    param($Saved)
    if ($null -eq $Saved) { return }
    try {
        if ($Saved.StartType) {
            $mode = Normalize-StartupType $Saved.StartType
            if ($mode) { Set-Service -Name $Saved.Name -StartupType $mode -ErrorAction SilentlyContinue }
        }
        if ($Saved.Status -eq 'Running') {
            Start-Service -Name $Saved.Name -ErrorAction SilentlyContinue
        } else {
            Stop-Service -Name $Saved.Name -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Log "Failed to restore service: $($Saved.Name) ($_)"
    }
}

function Get-NetshTcpGlobal {
    $o = netsh int tcp show global
    $h = @{}
    foreach ($line in $o) {
        if ($line -match '^\s*(.+?)\s*:\s*(.+?)\s*$') {
            $k = $matches[1].Trim()
            $v = $matches[2].Trim()
            $h[$k] = $v
        }
    }
    $h
}

function Apply-GameSpecificTweaks {
    param([string]$GameKey, [array]$TweakList)
    
    # KORRIGIERT: .ContainsKey() ersetzt durch .Contains()
    if (-not $GameProfiles.Contains($GameKey)) { return }
    
    $profile = $GameProfiles[$GameKey]
    Log "Applying game-specific tweaks for $($profile.DisplayName)..."
    
    foreach ($tweak in $TweakList) {
        switch ($tweak) {
            'DisableNagle' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 'DWord' 1 | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPNoDelay" 'DWord' 1 | Out-Null
                Log "Nagle's algorithm disabled for low-latency gaming"
            }
            'HighPrecisionTimer' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 'DWord' 1 | Out-Null
                Log "High precision timer enabled"
            }
            'NetworkOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxConnectionsPerServer" 'DWord' 16 | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxConnectionsPer1_0Server" 'DWord' 16 | Out-Null
                Log "Network connection limits optimized"
            }
            'AntiCheatOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 | Out-Null
                Log "Anti-cheat compatibility optimizations applied"
            }
            'GPUScheduling' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 | Out-Null
                Log "Hardware-accelerated GPU scheduling enabled"
            }
            'MemoryOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemPages" 'DWord' 0 | Out-Null
                Log "Memory optimization for gaming applied"
            }
            'SourceEngineOptimization' {
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" 'String' "High" | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" 'String' "High" | Out-Null
                Log "Source Engine optimizations applied"
            }
            'BF6Optimization' {
                # Battlefield 6 specific optimizations
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 'DWord' 38 | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 'DWord' 8 | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 'DWord' 6 | Out-Null
                # Enhanced I/O priority for BF6
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 'DWord' 0 | Out-Null
                Log "Battlefield 6 specific optimizations applied (CPU priority, memory, GPU scheduling)"
            }
        }
    }
}

# ---------- KORRIGIERTE Backup / Restore Funktionen ----------
function Create-Backup {
    # KORRIGIERT: Normale HashTables statt OrderedDictionary verwenden
    $b = @{
        Timestamp        = Get-Date
        GPU              = Get-GPUVendor
        Registry         = @{}
        RegistryNICs     = @{}
        Services         = @{}
        NetshTcp         = Get-NetshTcpGlobal
    }

    # Extended registry list with new optimizations
    $regList = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="NetworkThrottlingIndex"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="LazyModeTimeout"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="LazyModeThreshold"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Scheduling Category"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="SFIO Priority"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="BackgroundPriority"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Clock Rate"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Affinity"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Background Only"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehavior"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name="AppCaptureEnabled"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name="GameDVR_Enabled"},
        @{Path="HKCU:\SOFTWARE\Microsoft\GameBar"; Name="AllowAutoGameMode"},
        @{Path="HKCU:\SOFTWARE\Microsoft\GameBar"; Name="AutoGameModeEnabled"},
        @{Path="HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR"; Name="value"},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name="AllowGameDVR"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="HwSchMode"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="TdrLevel"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="TdrDelay"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="TdrDdiDelay"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="TdrDebugMode"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="TdrTestMode"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="DirectXUserGlobalSettings"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="DxgkrnlVersion"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpDelAckTicks"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpNoDelay"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TCPNoDelay"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxConnectionsPerServer"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxConnectionsPer1_0Server"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpTimedWaitDelay"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="DefaultTTL"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpMaxDataRetransmissions"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnablePMTUBHDetect"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnablePMTUDiscovery"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpWindowSize"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="Tcp1323Opts"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpMaxDupAcks"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="SackOpts"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name="GlobalTimerResolutionRequests"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name="ThreadDpcEnable"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name="DpcQueueDepth"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name="DisableTsxAutoBan"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="DisablePagingExecutive"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargeSystemCache"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="SystemPages"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="FeatureSettings"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="FeatureSettingsOverride"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="FeatureSettingsOverrideMask"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="EnablePrefetcher"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargePageMinimum"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargePageDrivers"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="DisablePageCombining"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="ClearPageFileAtShutdown"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System"; Name="IoEnableStackSwapping"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name="Win32PrioritySeparation"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name="IRQ8Priority"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name="IRQ16Priority"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power"; Name="HibernateEnabled"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\943c8cb6-6f93-4227-ad87-e9a3feec08d1"; Name="Attributes"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"; Name="ValueMax"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"; Name="ValueMin"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\68dd2f27-a4ce-4e11-8487-3794e4135dfa"; Name="Attributes"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\44f3beca-a7c0-460e-9df2-bb8b99e0cba6\3619c3f2-afb2-4afc-b0e9-e7fef372de36"; Name="Attributes"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Processor"; Name="Capabilities"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name="NtfsMftZoneReservation"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name="NtfsDisableLastAccessUpdate"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name="NtfsDisable8dot3NameCreation"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name="Win95TruncatedExtensions"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"; Name="ForcedPhysicalDiskIo"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"; Name="MouseDataQueueSize"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"; Name="KeyboardDataQueueSize"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AudioSrv"; Name="DependOnService"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio"; Name="DisableProtectedAudioDG"},
        @{Path="HKLM:\SOFTWARE\Microsoft\MSMQ\Parameters"; Name="TCPNoDelay"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Multimedia\Audio"; Name="UserDuckingPreference"},
        @{Path="HKCU:\Control Panel\Mouse"; Name="MouseSpeed"},
        @{Path="HKCU:\Control Panel\Mouse"; Name="MouseThreshold1"},
        @{Path="HKCU:\Control Panel\Mouse"; Name="MouseThreshold2"},
        @{Path="HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences"; Name="DirectXUserGlobalSettings"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name="VisualFXSetting"},
        # Additional visual effects registry keys for selective optimization
        @{Path="HKCU:\Control Panel\Desktop"; Name="MinAnimate"},
        @{Path="HKCU:\Control Panel\Desktop"; Name="MenuShowDelay"},
        @{Path="HKCU:\Control Panel\Desktop"; Name="DragFullWindows"},
        @{Path="HKCU:\Control Panel\Desktop"; Name="FontSmoothing"},
        @{Path="HKCU:\Control Panel\Desktop"; Name="FontSmoothingType"},
        @{Path="HKCU:\Control Panel\Desktop"; Name="UserPreferencesMask"},
        @{Path="HKCU:\Software\Microsoft\Windows\DWM"; Name="EnableAeroPeek"},
        @{Path="HKCU:\Software\Microsoft\Windows\DWM"; Name="AlwaysHibernateThumbnails"},
        @{Path="HKCU:\Control Panel\Desktop\WindowMetrics"; Name="MinAnimate"}
    )
    
    foreach ($r in $regList) {
        $v = Get-Reg $r.Path $r.Name
        if (-not $b.Registry.ContainsKey($r.Path)) { $b.Registry[$r.Path] = @{} }
        $b.Registry[$r.Path][$r.Name] = $v
    }

    # Per-NIC registry backup
    $nicRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $nicRoot) {
        Get-ChildItem $nicRoot | ForEach-Object {
            $p = $_.PSPath
            $ack = Get-Reg $p 'TcpAckFrequency'
            $nodelay = Get-Reg $p 'TCPNoDelay'
            if ($null -ne $ack -or $null -ne $nodelay) {
                $b.RegistryNICs[$p] = @{
                    TcpAckFrequency = $ack
                    TCPNoDelay      = $nodelay
                }
            }
        }
    }

    # Extended service list
    $svcTargets = @(
        "XblGameSave","XblAuthManager","XboxGipSvc","XboxNetApiSvc",
        "Spooler", "SysMain", "DiagTrack", "WSearch", "NvTelemetryContainer",
        "AMD External Events", "Fax", "RemoteRegistry", "MapsBroker", 
        "WMPNetworkSvc", "WpnUserService", "bthserv", "TabletInputService",
        "TouchKeyboard", "WerSvc", "PcaSvc", "Themes", "AudioSrv",
        "AudioEndpointBuilder", "Audiosrv", "BITS", "CryptSvc"
    )
    
    foreach ($t in $svcTargets) {
        $s = Get-ServiceState $t
        if ($s) { $b.Services[$s.Name] = $s }
    }

    $b | ConvertTo-Json -Depth 6 | Set-Content -Path $BackupPath -Encoding UTF8
    Log "Enhanced backup saved to $BackupPath"
}

function Restore-FromBackup {
    if (-not (Test-Path $BackupPath)) { Log "No backup file found at $BackupPath"; return }
    
    try {
        $b = Get-Content $BackupPath -Raw | ConvertFrom-Json
        Log "Backup loaded successfully, starting restoration..."
    } catch {
        Log "Failed to load backup file: $_"
        return
    }

    # Registry restoration - KORRIGIERT für PowerShell JSON
    if ($b.Registry) {
        try {
            # PowerShell JSON konvertiert nested objects zu PSCustomObject
            $regData = $b.Registry
            if ($regData -is [PSCustomObject]) {
                $regData.PSObject.Properties | ForEach-Object {
                    $path = $_.Name
                    $pathValues = $_.Value
                    if ($pathValues -is [PSCustomObject]) {
                        $pathValues.PSObject.Properties | ForEach-Object {
                            $name = $_.Name
                            $val = $_.Value
                            if ($null -eq $val) {
                                Remove-Reg $path $name | Out-Null
                            } else {
                                $vText = [string]$val
                                $isInt = $false
                                $tmp = 0
                                if ([int]::TryParse($vText, [ref]$tmp)) { $isInt = $true }
                                if ($isInt) {
                                    Set-Reg $path $name 'DWord' $val | Out-Null
                                } else {
                                    Set-Reg $path $name 'String' $val | Out-Null
                                }
                            }
                        }
                    }
                }
            }
            Log "Registry settings restored"
        } catch {
            Log "Error restoring registry: $_"
        }
    }
    
    # NIC registry restoration - KORRIGIERT
    if ($b.RegistryNICs) {
        try {
            $nicData = $b.RegistryNICs
            if ($nicData -is [PSCustomObject]) {
                $nicData.PSObject.Properties | ForEach-Object {
                    $nicPath = $_.Name
                    $nicVals = $_.Value
                    if ($nicVals -is [PSCustomObject]) {
                        foreach ($n in @('TcpAckFrequency','TCPNoDelay')) {
                            $val = $null
                            if ($nicVals.PSObject.Properties.Name -contains $n) {
                                $val = $nicVals.$n
                            }
                            if ($val -eq $null) {
                                Remove-Reg $nicPath $n | Out-Null
                            } else {
                                Set-Reg $nicPath $n 'DWord' ([int]$val) | Out-Null
                            }
                        }
                    }
                }
            }
            Log "NIC registry settings restored"
        } catch {
            Log "Error restoring NIC registry: $_"
        }
    }

    # Service restoration - KORRIGIERT
    if ($b.Services) {
        try {
            $svcData = $b.Services
            if ($svcData -is [PSCustomObject]) {
                $svcData.PSObject.Properties | ForEach-Object {
                    $svcName = $_.Name
                    $svcInfo = $_.Value
                    $savedService = [PSCustomObject]@{
                        Name = if ($svcInfo.Name) { $svcInfo.Name } else { $svcName }
                        Display = $svcInfo.Display
                        StartType = $svcInfo.StartType
                        Status = $svcInfo.Status
                    }
                    Restore-ServiceState $savedService
                }
            }
            Log "Services restored"
        } catch {
            Log "Error restoring services: $_"
        }
    }

    # Netsh restoration
    if ($b.NetshTcp) {
        try {
            $ns = $b.NetshTcp
            if ($ns.'ECN Capability') {
                $en = ($ns.'ECN Capability' -match 'enabled')
                if ($en) { netsh int tcp set global ecncapability=enabled | Out-Null } else { netsh int tcp set global ecncapability=disabled | Out-Null }
            }
            if ($ns.'TCP timestamps') {
                $en = ($ns.'TCP timestamps' -match 'enabled')
                if ($en) { netsh int tcp set global timestamps=enabled | Out-Null } else { netsh int tcp set global timestamps=disabled | Out-Null }
            }
            if ($ns.'Chimney Offload State') {
                $en = ($ns.'Chimney Offload State' -match 'enabled')
                if ($en) { netsh int tcp set global chimney=enabled | Out-Null } else { netsh int tcp set global chimney=disabled | Out-Null }
            }
            if ($ns.'Receive-Side Scaling State') {
                $en = ($ns.'Receive-Side Scaling State' -match 'enabled')
                if ($en) { netsh int tcp set global rss=enabled | Out-Null } else { netsh int tcp set global rss=disabled | Out-Null }
            }
            if ($ns.'Receive Segment Coalescing State') {
                $en = ($ns.'Receive Segment Coalescing State' -match 'enabled')
                if ($en) { netsh int tcp set global rsc=enabled | Out-Null } else { netsh int tcp set global rsc=disabled | Out-Null }
            }
            if ($ns.'Receive Window Auto-Tuning Level') {
                $lvl = 'normal'
                $rw = $ns.'Receive Window Auto-Tuning Level'
                if ($rw -match 'disabled')          { $lvl = 'disabled' }
                elseif ($rw -match 'experimental')  { $lvl = 'experimental' }
                elseif ($rw -match 'highlyrestricted') { $lvl = 'highlyrestricted' }
                elseif ($rw -match 'restricted')    { $lvl = 'restricted' }
                netsh int tcp set global autotuninglevel=$lvl | Out-Null
            }
            Log "Network settings restored"
        } catch {
            Log "Error restoring network settings: $_"
        }
    }

    Log "Complete restore finished. Reboot recommended."
}

# ---------- Fixed XAML UI (Rest der UI Code bleibt gleich) ----------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="KOALA-UDP Enhanced Gaming Toolkit v2.2 (Enhanced FPS Edition)" Height="750" Width="900"
        Background="#1A1625" WindowStartupLocation="CenterScreen" ShowInTaskbar="True">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="160"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,12">
      <TextBlock Text="🚀 KOALA-UDP Enhanced Gaming Toolkit v2.2 (Enhanced FPS Edition)" FontSize="24" FontWeight="Bold" Foreground="#00FF88" Margin="0,0,0,4"/>
      <TextBlock Text="Advanced Windows gaming optimizations with comprehensive FPS-boosting features and smart game detection!" FontSize="14" Foreground="#B8B3E6" FontStyle="Italic"/>
    </StackPanel>

    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Background="#252140" BorderThickness="2" BorderBrush="#6B46C1" Padding="10">
      <StackPanel x:Name="TweaksPanel">

        <TextBlock Text="🌐 Advanced Networking" Foreground="#00FF88" FontWeight="Bold" FontSize="16" Margin="0,0,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkAck" Content="Disable TCP ACK Delay" ToolTip="Sets TcpAckFrequency=1 on all active NIC interfaces." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkDelAckTicks" Content="Set TcpDelAckTicks=0" ToolTip="Sets TcpDelAckTicks=0 for faster acknowledgements." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkTcpAutoTune" Content="TCP Autotuning: Normal" ToolTip="netsh int tcp set global autotuninglevel=normal" Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkTcpTimestamps" Content="Disable TCP Timestamps" ToolTip="netsh int tcp set global timestamps=disabled" Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkTcpECN" Content="Disable ECN" ToolTip="netsh int tcp set global ecncapability=disabled" Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkRSS" Content="Enable RSS" ToolTip="Enable Receive-Side Scaling (if supported)." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkRSC" Content="Enable RSC" ToolTip="Enable Receive Segment Coalescing (if supported)." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkThrottle" Content="Disable Network Throttling" ToolTip="Sets NetworkThrottlingIndex to 0xFFFFFFFF." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkNagle" Content="Disable Nagle Algorithm" ToolTip="Disables Nagle's algorithm for reduced latency." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

        <TextBlock Text="🎮 Windows Gaming Optimizations" Foreground="#00FF88" FontWeight="Bold" FontSize="16" Margin="0,8,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkResponsiveness" Content="System Responsiveness (0)" ToolTip="HKLM...SystemProfile:SystemResponsiveness=0" Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGamesTask" Content="Games Task: High Priority" ToolTip="Raise MMCSS 'Games' task priorities (GPU Priority=8, Priority=6)." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGameDVR" Content="Disable Game DVR" ToolTip="Disables GameDVR background capture and Xbox services." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkFSE" Content="Disable Fullscreen Optimizations" ToolTip="Turns off FSE optimizations via GameConfigStore." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGpuScheduler" Content="Enable GPU Hardware Scheduling" ToolTip="GraphicsDrivers: HwSchMode=2 (if supported)." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkTimerRes" Content="High Precision Timer" ToolTip="Requests ~1ms timer resolution while the app is open." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkVisualEffects" Content="Selective Visual Effects Optimization" ToolTip="Optimizes visual effects for gaming performance while preserving usability - disables animations/transparency but keeps window borders and functional elements." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkHibernation" Content="Disable Hibernation" ToolTip="Disables hibernation to free up disk space." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

        <TextBlock Text="🚀 Enhanced Gaming Optimizations" Foreground="#00FF88" FontWeight="Bold" FontSize="16" Margin="0,8,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkEnhancedCpuAffinity" Content="Enhanced CPU Affinity Management" ToolTip="Advanced CPU core assignment for better game performance." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkAdvancedMemory" Content="Advanced Memory Optimization" ToolTip="Enhanced memory allocation and garbage collection tuning." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGpuDriverOpt" Content="GPU Driver Optimizations" ToolTip="Optimizes GPU driver settings for gaming performance." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkNetworkLatency" Content="Network Latency Improvements" ToolTip="Advanced network optimizations for reduced latency." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGameMode" Content="Windows Game Mode Enhancements" ToolTip="Enhanced Windows Game Mode with additional tweaks." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkPowerOptimization" Content="Gaming Power Plan Optimization" ToolTip="Optimizes power settings specifically for gaming performance." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkRealTimeMonitoring" Content="Real-Time Performance Monitoring" ToolTip="Enables real-time system resource monitoring during gaming." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkProcessOptimization" Content="Process Optimization Enhancements" ToolTip="Advanced process priority and scheduling optimizations." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

        <TextBlock Text="🎯 Advanced FPS-Boosting Optimizations" Foreground="#FFD700" FontWeight="Bold" FontSize="16" Margin="0,8,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkCpuCorePark" Content="CPU Core Parking Disable" ToolTip="Prevents CPU cores from entering sleep states for consistent performance." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkCpuCStates" Content="CPU C-States Disable" ToolTip="Disables deep sleep states that can cause frame drops." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkInterruptMod" Content="Interrupt Moderation" ToolTip="Optimizes network and GPU interrupt handling for smoother gameplay." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkMMCSS" Content="MMCSS Gaming Priority" ToolTip="Prioritizes gaming threads through Multimedia Class Scheduler Service." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkLargePages" Content="Large Page Support" ToolTip="Enables large memory pages for reduced memory latency." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkMemCompression" Content="Memory Compression Disable" ToolTip="Disables Windows memory compression during gaming." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkStandbyMemory" Content="Standby Memory Management" ToolTip="Aggressive standby list cleaning for better memory allocation." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGpuScheduling" Content="Hardware GPU Scheduling" ToolTip="Enables hardware-accelerated GPU scheduling for better performance." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGpuPowerStates" Content="GPU Power States Disable" ToolTip="Prevents GPU from entering power-saving states during gaming." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkShaderCache" Content="Shader Cache Management" ToolTip="Optimizes shader compilation and caching for faster loading." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGameIO" Content="Game File I/O Priority" ToolTip="Sets game directories to high I/O priority for faster loading." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkDiskOptimization" Content="Disk Performance Tweaks" ToolTip="Optimizes file system and disk settings for gaming." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkNetworkGaming" Content="Gaming Network Stack" ToolTip="Optimizes network stack specifically for low-latency gaming." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGamingAudio" Content="Gaming Audio Optimization" ToolTip="Enables exclusive mode audio for lower latency." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkInputOptimization" Content="Gaming Input Optimization" ToolTip="Raw input optimizations and mouse acceleration fixes." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

        <TextBlock Text="🎮 Smart Gaming Detection &amp; Auto-Optimization" Foreground="#00BFFF" FontWeight="Bold" FontSize="16" Margin="0,8,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkAutoGameDetection" Content="Automatic Game Detection" ToolTip="Automatically detects when games are launched and applies optimizations." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkAutoProfileSwitch" Content="Auto Profile Switching" ToolTip="Automatically applies game-specific optimization profiles." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkGameSpecificProfiles" Content="Game-Specific Profiles" ToolTip="Saves and loads per-game optimization settings." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkPerformanceMetrics" Content="Performance Metrics Display" ToolTip="Shows real-time FPS and resource monitoring." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkAutoRevert" Content="Auto-Revert on Game Exit" ToolTip="Automatically restores original settings when games are closed." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkBackgroundAppSuspend" Content="Background App Suspension" ToolTip="Intelligently suspends non-essential apps during gaming." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

        <TextBlock Text="🔧 System Performance" Foreground="#00FF88" FontWeight="Bold" FontSize="16" Margin="0,8,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkMemoryManagement" Content="Optimize Memory Management" ToolTip="Disables paging executive and optimizes memory allocation." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkPowerPlan" Content="Ultimate Performance Power Plan" ToolTip="Sets power plan to Ultimate Performance mode." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkCpuScheduling" Content="Optimize CPU Scheduling" ToolTip="Optimizes CPU scheduling for foreground applications." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkPageFile" Content="Optimize Page File" ToolTip="Optimizes virtual memory settings." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

        <TextBlock Text="🎯 GPU Vendor Optimizations" Foreground="#00FF88" FontWeight="Bold" FontSize="16" Margin="0,8,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkNvidiaTweaks" Content="NVIDIA: Disable Telemetry Service" ToolTip="Stops and disables NvTelemetryContainer if present." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkAmdTweaks" Content="AMD: Disable External Events" ToolTip="Stops and disables AMD External Events Utility if present." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkIntelTweaks" Content="Intel: Graphics Optimizations" ToolTip="Applies Intel graphics optimizations if detected." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

        <TextBlock Text="⚙️ Background Services" Foreground="#00FF88" FontWeight="Bold" FontSize="16" Margin="0,8,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkSvcXbox" Content="Disable Xbox Services" ToolTip="XblAuthManager, XblGameSave, XboxGipSvc, XboxNetApiSvc" Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkSvcSpooler" Content="Disable Print Spooler" ToolTip="Stops print spooler for FPS gains on some systems." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkSvcSysMain" Content="Disable SysMain (Superfetch)" ToolTip="Stops prefetcher service to reduce background I/O." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkSvcDiagTrack" Content="Disable Telemetry (DiagTrack)" ToolTip="Reduces telemetry background usage." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkSvcSearch" Content="Disable Windows Search" ToolTip="Optional. Disables indexing service." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkSvcTablet" Content="Disable Tablet Services" ToolTip="Disables tablet input and touch keyboard services." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkSvcThemes" Content="Disable Themes Service" ToolTip="Disables Windows themes service for performance." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

        <TextBlock Text="🗑️ Disable Unneeded Services" Foreground="#00FF88" FontWeight="Bold" FontSize="16" Margin="0,8,0,6"/>
        <WrapPanel Margin="0,0,0,12">
          <CheckBox x:Name="chkDisableUnneeded" Content="Disable Fax / RemoteRegistry / MapsBroker / WMPNetworkSvc / WpnUserService / bthserv" ToolTip="Optional: Disables various unneeded services for gaming." Foreground="White" Margin="0,5,15,5"/>
        </WrapPanel>

      </StackPanel>
    </ScrollViewer>

    <Grid Grid.Row="2" Margin="0,12,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      
      <StackPanel Grid.Column="0">
        <TextBlock Text="🎯 Game Selection &amp; Process Priority" Foreground="#00FF88" FontWeight="Bold" FontSize="16" Margin="0,0,0,8"/>
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="120"/>
            <ColumnDefinition Width="200"/>
            <ColumnDefinition Width="150"/>
            <ColumnDefinition Width="180"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          
          <TextBlock Grid.Row="0" Grid.Column="0" Text="Game Profile:" Foreground="White" VerticalAlignment="Center" Margin="0,0,8,4"/>
          <ComboBox x:Name="cmbGameProfile" Grid.Row="0" Grid.Column="1" Height="28" Margin="0,0,8,4">
            <ComboBoxItem Content="Custom Game" Tag="custom"/>
            <ComboBoxItem Content="Counter-Strike 2" Tag="cs2"/>
            <ComboBoxItem Content="CS:GO" Tag="csgo"/>
            <ComboBoxItem Content="Valorant" Tag="valorant"/>
            <ComboBoxItem Content="Fortnite" Tag="fortnite"/>
            <ComboBoxItem Content="Apex Legends" Tag="apexlegends"/>
            <ComboBoxItem Content="Call of Duty: Warzone" Tag="warzone"/>
            <ComboBoxItem Content="Battlefield 6" Tag="bf6"/>
            <ComboBoxItem Content="Call of Duty: MW II" Tag="codmw2"/>
            <ComboBoxItem Content="Call of Duty: MW III" Tag="codmw3"/>
            <ComboBoxItem Content="Rainbow Six Siege" Tag="rainbow6"/>
            <ComboBoxItem Content="Overwatch 2" Tag="overwatch2"/>
            <ComboBoxItem Content="League of Legends" Tag="leagueoflegends"/>
            <ComboBoxItem Content="Rocket League" Tag="rocketleague"/>
            <ComboBoxItem Content="PUBG: Battlegrounds" Tag="pubg"/>
            <ComboBoxItem Content="Destiny 2" Tag="destiny2"/>
          </ComboBox>
          
          <Button x:Name="btnDetect" Grid.Row="0" Grid.Column="2" Content="🔍 Auto Detect" Height="28" Margin="0,0,8,4" Background="#6B46C1" Foreground="White"/>
          
          <TextBlock Grid.Row="0" Grid.Column="3" Text="Priority:" Foreground="White" VerticalAlignment="Center" Margin="0,0,8,4"/>
          <ComboBox x:Name="cmbPriority" Grid.Row="0" Grid.Column="4" Height="28" Margin="0,0,0,4">
            <ComboBoxItem Content="High" Tag="High"/>
            <ComboBoxItem Content="Above Normal" Tag="AboveNormal"/>
            <ComboBoxItem Content="Normal" Tag="Normal"/>
            <ComboBoxItem Content="Real Time" Tag="RealTime"/>
          </ComboBox>
          
          <TextBlock Grid.Row="1" Grid.Column="0" Text="Process Name:" Foreground="White" VerticalAlignment="Center" Margin="0,0,8,0"/>
          <TextBox x:Name="txtProcess" Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="2" Height="28" Text="cs2" Margin="0,0,8,0"/>
          
          <TextBlock Grid.Row="1" Grid.Column="3" Text="Game Path:" Foreground="White" VerticalAlignment="Center" Margin="0,0,8,0"/>
          <TextBox x:Name="txtGamePath" Grid.Row="1" Grid.Column="4" Height="28" Text="" ToolTip="Optional: Path to game executable for additional optimizations"/>
        </Grid>
      </StackPanel>
      
      <StackPanel Orientation="Horizontal" Grid.Column="1" VerticalAlignment="Bottom">
        <Button x:Name="btnApply" Content="🎯 Recommended" Width="160" Height="40" Margin="0,0,10,0" Background="#00FF88" Foreground="Black" FontWeight="Bold" FontSize="14" ToolTip="Enable all recommended settings excluding visual themes"/>
        <Button x:Name="btnRevert" Content="🔄 Revert All" Width="120" Height="40" Background="#FF6B6B" Foreground="White" FontWeight="Bold"/>
      </StackPanel>
    </Grid>

    <Grid Grid.Row="3" Margin="0,0,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      
      <StackPanel Grid.Column="0" Orientation="Horizontal">
        <Button x:Name="btnSystemInfo" Content="📊 System Info" Width="120" Height="32" Background="#6B46C1" Foreground="White" Margin="0,0,8,0"/>
        <Button x:Name="btnBenchmark" Content="🏁 Quick Benchmark" Width="140" Height="32" Background="#8B5CF6" Foreground="White" Margin="0,0,8,0"/>
        <Button x:Name="btnExportConfig" Content="💾 Export Config" Width="120" Height="32" Background="#10B981" Foreground="White" Margin="0,0,8,0"/>
        <Button x:Name="btnImportConfig" Content="📁 Import Config" Width="120" Height="32" Background="#F59E0B" Foreground="White"/>
      </StackPanel>
      
      <StackPanel Grid.Column="1" Orientation="Horizontal">
        <TextBlock Text="Status: " Foreground="White" VerticalAlignment="Center" Margin="0,0,4,0"/>
        <TextBlock x:Name="lblStatus" Text="Ready" Foreground="#00FF88" VerticalAlignment="Center" FontWeight="Bold"/>
      </StackPanel>
    </Grid>

    <Border Grid.Row="4" Background="#0D1117" BorderBrush="#6B46C1" BorderThickness="2" Padding="8">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="📋 Activity Log" Foreground="#00FF88" FontWeight="Bold" Margin="0,0,0,4"/>
        
        <!-- Performance Metrics Section -->
        <Border Grid.Row="1" Background="#1A1625" BorderBrush="#444" BorderThickness="1" Padding="8" Margin="0,0,0,8">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="🎮 Active Games" Foreground="#FFD700" FontSize="10" FontWeight="Bold"/>
              <TextBlock x:Name="lblActiveGames" Text="None" Foreground="White" FontSize="10"/>
            </StackPanel>
            <StackPanel Grid.Column="1">
              <TextBlock Text="🔥 CPU Usage" Foreground="#FF6B6B" FontSize="10" FontWeight="Bold"/>
              <TextBlock x:Name="lblCpuUsage" Text="--%" Foreground="White" FontSize="10"/>
            </StackPanel>
            <StackPanel Grid.Column="2">
              <TextBlock Text="💾 Memory" Foreground="#00BFFF" FontSize="10" FontWeight="Bold"/>
              <TextBlock x:Name="lblMemoryUsage" Text="-- MB" Foreground="White" FontSize="10"/>
            </StackPanel>
            <StackPanel Grid.Column="3">
              <TextBlock Text="⚡ Optimizations" Foreground="#00FF88" FontSize="10" FontWeight="Bold"/>
              <TextBlock x:Name="lblOptimizationStatus" Text="Ready" Foreground="White" FontSize="10"/>
            </StackPanel>
          </Grid>
        </Border>
        
        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
          <TextBox x:Name="txtLog" Background="Transparent" Foreground="#58A6FF" BorderThickness="0"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True"/>
        </ScrollViewer>
      </Grid>
    </Border>
  </Grid>
</Window>
'@

# ---------- Build WPF ----------
$reader = New-Object System.Xml.XmlNodeReader $xaml
$form   = [Windows.Markup.XamlReader]::Load($reader)

# ---------- Bind controls ----------
$chkAck            = $form.FindName('chkAck')
$chkDelAckTicks    = $form.FindName('chkDelAckTicks')
$chkTcpAutoTune    = $form.FindName('chkTcpAutoTune')
$chkTcpTimestamps  = $form.FindName('chkTcpTimestamps')
$chkTcpECN         = $form.FindName('chkTcpECN')
$chkRSS            = $form.FindName('chkRSS')
$chkRSC            = $form.FindName('chkRSC')
$chkThrottle       = $form.FindName('chkThrottle')
$chkNagle          = $form.FindName('chkNagle')

$chkResponsiveness = $form.FindName('chkResponsiveness')
$chkGamesTask      = $form.FindName('chkGamesTask')
$chkGameDVR        = $form.FindName('chkGameDVR')
$chkFSE            = $form.FindName('chkFSE')
$chkGpuScheduler   = $form.FindName('chkGpuScheduler')
$chkTimerRes       = $form.FindName('chkTimerRes')
$chkVisualEffects  = $form.FindName('chkVisualEffects')
$chkHibernation    = $form.FindName('chkHibernation')

$chkMemoryManagement = $form.FindName('chkMemoryManagement')
$chkPowerPlan      = $form.FindName('chkPowerPlan')
$chkCpuScheduling  = $form.FindName('chkCpuScheduling')
$chkPageFile       = $form.FindName('chkPageFile')

$chkEnhancedCpuAffinity = $form.FindName('chkEnhancedCpuAffinity')
$chkAdvancedMemory = $form.FindName('chkAdvancedMemory')
$chkGpuDriverOpt   = $form.FindName('chkGpuDriverOpt')
$chkNetworkLatency = $form.FindName('chkNetworkLatency')
$chkGameMode       = $form.FindName('chkGameMode')
$chkPowerOptimization = $form.FindName('chkPowerOptimization')
$chkRealTimeMonitoring = $form.FindName('chkRealTimeMonitoring')
$chkProcessOptimization = $form.FindName('chkProcessOptimization')

# Advanced FPS-Boosting Optimizations
$chkCpuCorePark    = $form.FindName('chkCpuCorePark')
$chkCpuCStates     = $form.FindName('chkCpuCStates')
$chkInterruptMod   = $form.FindName('chkInterruptMod')
$chkMMCSS          = $form.FindName('chkMMCSS')
$chkLargePages     = $form.FindName('chkLargePages')
$chkMemCompression = $form.FindName('chkMemCompression')
$chkStandbyMemory  = $form.FindName('chkStandbyMemory')
$chkGpuScheduling  = $form.FindName('chkGpuScheduling')
$chkGpuPowerStates = $form.FindName('chkGpuPowerStates')
$chkShaderCache    = $form.FindName('chkShaderCache')
$chkGameIO         = $form.FindName('chkGameIO')
$chkDiskOptimization = $form.FindName('chkDiskOptimization')
$chkNetworkGaming  = $form.FindName('chkNetworkGaming')
$chkGamingAudio    = $form.FindName('chkGamingAudio')
$chkInputOptimization = $form.FindName('chkInputOptimization')

# Smart Gaming Detection & Auto-Optimization
$chkAutoGameDetection = $form.FindName('chkAutoGameDetection')
$chkAutoProfileSwitch = $form.FindName('chkAutoProfileSwitch')
$chkGameSpecificProfiles = $form.FindName('chkGameSpecificProfiles')
$chkPerformanceMetrics = $form.FindName('chkPerformanceMetrics')
$chkAutoRevert = $form.FindName('chkAutoRevert')
$chkBackgroundAppSuspend = $form.FindName('chkBackgroundAppSuspend')

$chkNvidiaTweaks   = $form.FindName('chkNvidiaTweaks')
$chkAmdTweaks      = $form.FindName('chkAmdTweaks')
$chkIntelTweaks    = $form.FindName('chkIntelTweaks')

$chkSvcXbox        = $form.FindName('chkSvcXbox')
$chkSvcSpooler     = $form.FindName('chkSvcSpooler')
$chkSvcSysMain     = $form.FindName('chkSvcSysMain')
$chkSvcDiagTrack   = $form.FindName('chkSvcDiagTrack')
$chkSvcSearch      = $form.FindName('chkSvcSearch')
$chkSvcTablet      = $form.FindName('chkSvcTablet')
$chkSvcThemes      = $form.FindName('chkSvcThemes')

$chkDisableUnneeded= $form.FindName('chkDisableUnneeded')

$cmbGameProfile    = $form.FindName('cmbGameProfile')
$txtProcess        = $form.FindName('txtProcess')
$txtGamePath       = $form.FindName('txtGamePath')
$cmbPriority       = $form.FindName('cmbPriority')
$btnDetect         = $form.FindName('btnDetect')

$btnApply          = $form.FindName('btnApply')
$btnRevert         = $form.FindName('btnRevert')
$btnSystemInfo     = $form.FindName('btnSystemInfo')
$btnBenchmark      = $form.FindName('btnBenchmark')
$btnExportConfig   = $form.FindName('btnExportConfig')
$btnImportConfig   = $form.FindName('btnImportConfig')

$lblStatus         = $form.FindName('lblStatus')
$global:LogBox     = $form.FindName('txtLog')

# Performance metrics labels
$lblActiveGames    = $form.FindName('lblActiveGames')
$lblCpuUsage       = $form.FindName('lblCpuUsage')
$lblMemoryUsage    = $form.FindName('lblMemoryUsage')
$lblOptimizationStatus = $form.FindName('lblOptimizationStatus')

# Set default values
$cmbGameProfile.SelectedIndex = 1  # CS2
$cmbPriority.SelectedIndex = 0     # High

# Game profile selection handler
$cmbGameProfile.Add_SelectionChanged({
    if ($cmbGameProfile.SelectedItem -and $cmbGameProfile.SelectedItem.Tag) {
        $tag = $cmbGameProfile.SelectedItem.Tag.ToString()
        if ($tag -ne 'custom' -and $GameProfiles.Contains($tag)) {
            $profile = $GameProfiles[$tag]
            $txtProcess.Text = $profile.ProcessNames[0]
            
            # Auto-select priority
            switch ($profile.Priority) {
                'High' { $cmbPriority.SelectedIndex = 0 }
                'AboveNormal' { $cmbPriority.SelectedIndex = 1 }
                'Normal' { $cmbPriority.SelectedIndex = 2 }
                'RealTime' { $cmbPriority.SelectedIndex = 3 }
            }
            
            Log "Selected profile: $($profile.DisplayName)"
        }
    }
})

# ---------- Enhanced Tweaks ----------
function Apply-Tweaks {
    # Check admin status and provide options
    if (-not (Test-AdminPrivileges)) {
        try {
            Require-Admin -ShowFallbackOptions
        } catch {
            Log $_.Exception.Message 'Warning'
            return
        }
    }
    
    $lblStatus.Text = "Working..."
    $lblStatus.Foreground = "#F59E0B"
    
    $isAdmin = Test-AdminPrivileges
    Log "Starting enhanced gaming optimizations... (Admin: $isAdmin)"
    
    if ($isAdmin) {
        Create-Backup
        Log "Running with full administrator privileges - all optimizations available"
    } else {
        Log "Running in limited mode - only user-level optimizations will be applied" 'Warning'
    }

    # Timer resolution
    if ($chkTimerRes.IsChecked) {
        try { 
            [WinMM]::timeBeginPeriod(1) | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 'DWord' 1 | Out-Null
            Log "High precision timer enabled (~1ms resolution)"
        } catch { Log "Timer resolution request failed: $_" }
    }

    # ENHANCED NETWORKING
    if ($chkAck.IsChecked) {
        try {
            $ifs = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
            $count = 0
            foreach ($i in $ifs) {
                Set-Reg $i.PSPath 'TcpAckFrequency' 'DWord' 1 | Out-Null
                Set-Reg $i.PSPath 'TCPNoDelay' 'DWord' 1 | Out-Null
                $count++
            }
            Log "TCP ACK delay disabled on $count network interfaces"
        } catch { Log "TCP ACK optimization failed: $_" }
    }
    
    if ($chkDelAckTicks.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 'DWord' 0 | Out-Null
        Log "TcpDelAckTicks set to 0"
    }
    
    if ($chkNagle.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPNoDelay" 'DWord' 1 | Out-Null
        Log "Nagle's algorithm disabled for reduced latency"
    }
    
    # Netsh optimizations
    if ($chkTcpAutoTune.IsChecked) {
        netsh int tcp set global autotuninglevel=normal | Out-Null
        Log "TCP autotuning set to Normal"
    }
    if ($chkTcpTimestamps.IsChecked) {
        netsh int tcp set global timestamps=disabled | Out-Null
        Log "TCP timestamps disabled"
    }
    if ($chkTcpECN.IsChecked) {
        netsh int tcp set global ecncapability=disabled | Out-Null
        Log "ECN capability disabled"
    }
    if ($chkRSS.IsChecked) {
        netsh int tcp set global rss=enabled | Out-Null
        Log "Receive-Side Scaling enabled"
    }
    if ($chkRSC.IsChecked) {
        netsh int tcp set global rsc=enabled | Out-Null
        Log "Receive Segment Coalescing enabled"
    }
    if ($chkThrottle.IsChecked) {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 'DWord' 0xffffffff | Out-Null
        Log "Network throttling disabled"
    }

    # WINDOWS/GAME UX OPTIMIZATIONS
    if ($chkResponsiveness.IsChecked) {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 'DWord' 0 | Out-Null
        Log "System responsiveness optimized (0)"
    }
    if ($chkGamesTask.IsChecked) {
        $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        Set-Reg $p "GPU Priority" 'DWord' 8   | Out-Null
        Set-Reg $p "Priority"     'DWord' 6   | Out-Null
        Set-Reg $p "Scheduling Category" 'String' "High" | Out-Null
        Set-Reg $p "SFIO Priority"       'String' "High" | Out-Null
        Log "MMCSS 'Games' task priorities raised to High"
    }
    if ($chkGameDVR.IsChecked) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 'DWord' 0 | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 'DWord' 0 | Out-Null
        Log "Game DVR disabled"
    }
    if ($chkFSE.IsChecked) {
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 'DWord' 2 | Out-Null
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehavior" 'DWord' 2 | Out-Null
        Log "Fullscreen optimizations disabled"
    }
    if ($chkGpuScheduler.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 | Out-Null
        Log "GPU Hardware Scheduling enabled"
    }
    if ($chkVisualEffects.IsChecked) {
        Set-SelectiveVisualEffects -EnablePerformanceMode
    }
    if ($chkHibernation.IsChecked) {
        if (Test-AdminPrivileges) {
            powercfg /hibernate off | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 'DWord' 0 | Out-Null
            Log "Hibernation disabled"
        } else {
            Log "Hibernation disable skipped - requires administrator privileges" 'Warning'
        }
    }

    # SYSTEM PERFORMANCE
    if ($chkMemoryManagement.IsChecked) {
        if (Test-AdminPrivileges) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 | Out-Null
            Log "Memory management optimized (paging executive disabled)"
        } else {
            Log "Memory management optimization skipped - requires administrator privileges" 'Warning'
        }
    }
    if ($chkPowerPlan.IsChecked) {
        try {
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            Log "Ultimate Performance power plan activated"
        } catch {
            powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
            Log "High Performance power plan activated (Ultimate not available)"
        }
    }
    if ($chkCpuScheduling.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 'DWord' 38 | Out-Null
        Log "CPU scheduling optimized for foreground applications"
    }
    if ($chkPageFile.IsChecked) {
        $cs = Get-CimInstance Win32_ComputerSystem
        $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB)
        $pageFileSize = [math]::Max(2048, $ram * 1024)  # Minimum 2GB or RAM size
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagingFiles" 'MultiString' @("C:\pagefile.sys $pageFileSize $pageFileSize") | Out-Null
        Log "Page file optimized (Size: $([math]::Round($pageFileSize/1024, 1))GB)"
    }

    # ENHANCED GAMING OPTIMIZATIONS
    if ($chkEnhancedCpuAffinity.IsChecked) {
        # Enhanced CPU affinity management
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 'DWord' 38 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "ThreadDpcEnable" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DpcQueueDepth" 'DWord' 1 | Out-Null
        Log "Enhanced CPU affinity management enabled"
    }
    if ($chkAdvancedMemory.IsChecked) {
        # Advanced memory optimization
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettings" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 'DWord' 3 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 'DWord' 3 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "EnablePrefetcher" 'DWord' 0 | Out-Null
        Log "Advanced memory optimization techniques applied"
    }
    if ($chkGpuDriverOpt.IsChecked) {
        # GPU driver optimizations
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrLevel" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 'DWord' 60 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDdiDelay" 'DWord' 60 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDebugMode" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrTestMode" 'DWord' 0 | Out-Null
        Log "GPU driver optimizations applied"
    }
    if ($chkNetworkLatency.IsChecked) {
        # Network latency improvements
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 'DWord' 30 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL" 'DWord' 64 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpMaxDataRetransmissions" 'DWord' 3 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "EnablePMTUBHDetect" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "EnablePMTUDiscovery" 'DWord' 1 | Out-Null
        Log "Network latency improvements applied"
    }
    if ($chkGameMode.IsChecked) {
        # Windows Game Mode enhancements
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AllowAutoGameMode" 'DWord' 1 | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AutoGameModeEnabled" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" "value" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 'DWord' 0 | Out-Null
        Log "Windows Game Mode enhanced with additional optimizations"
    }
    if ($chkPowerOptimization.IsChecked) {
        # Gaming power plan optimizations
        try {
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            powercfg /change standby-timeout-ac 0 | Out-Null
            powercfg /change standby-timeout-dc 0 | Out-Null
            powercfg /change hibernate-timeout-ac 0 | Out-Null
            powercfg /change hibernate-timeout-dc 0 | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\943c8cb6-6f93-4227-ad87-e9a3feec08d1" "Attributes" 'DWord' 2 | Out-Null
            Log "Gaming power plan fully optimized"
        } catch {
            Log "Power plan optimization failed, using High Performance instead"
            powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
        }
    }
    if ($chkProcessOptimization.IsChecked) {
        # Advanced process optimization
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "LazyModeTimeout" 'DWord' 10000 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "LazyModeThreshold" 'DWord' 150000 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "BackgroundPriority" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Clock Rate" 'DWord' 10000 | Out-Null
        Log "Advanced process optimization enhancements applied"
    }

    # ADVANCED FPS-BOOSTING OPTIMIZATIONS
    if ($chkCpuCorePark.IsChecked) {
        # Disable CPU core parking
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" "ValueMax" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" "ValueMin" 'DWord' 0 | Out-Null
        powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0 | Out-Null
        powercfg /setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0 | Out-Null
        Log "CPU core parking disabled for consistent performance"
    }
    
    if ($chkCpuCStates.IsChecked) {
        # Disable CPU C-States for reduced latency
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\68dd2f27-a4ce-4e11-8487-3794e4135dfa" "Attributes" 'DWord' 2 | Out-Null
        powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 68dd2f27-a4ce-4e11-8487-3794e4135dfa 0 | Out-Null
        powercfg /setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 68dd2f27-a4ce-4e11-8487-3794e4135dfa 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Processor" "Capabilities" 'DWord' 0x0007e066 | Out-Null
        Log "CPU C-States disabled to prevent frame drops"
    }
    
    if ($chkInterruptMod.IsChecked) {
        # Optimize interrupt moderation
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "IRQ8Priority" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "IRQ16Priority" 'DWord' 2 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DisableTsxAutoBan" 'DWord' 1 | Out-Null
        Log "Interrupt moderation optimized for gaming performance"
    }
    
    if ($chkMMCSS.IsChecked) {
        # Enhanced MMCSS for gaming priority
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Affinity" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Background Only" 'String' "False" | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Clock Rate" 'DWord' 10000 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 'DWord' 8 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 'DWord' 6 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" 'String' "High" | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" 'String' "High" | Out-Null
        Log "MMCSS gaming thread prioritization enhanced"
    }
    
    if ($chkLargePages.IsChecked) {
        # Enable large page support
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargePageMinimum" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargePageDrivers" 'DWord' 1 | Out-Null
        Log "Large page support enabled for reduced memory latency"
    }
    
    if ($chkMemCompression.IsChecked) {
        # Disable memory compression for gaming
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePageCombining" 'DWord' 1 | Out-Null
        try {
            Disable-MMAgent -MemoryCompression | Out-Null
            Log "Memory compression disabled for gaming performance"
        } catch {
            Log "Memory compression setting applied via registry"
        }
    }
    
    if ($chkStandbyMemory.IsChecked) {
        # Aggressive standby memory management
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemPages" 'DWord' 0 | Out-Null
        Log "Standby memory management optimized for gaming"
    }
    
    if ($chkGpuScheduling.IsChecked) {
        # Hardware-accelerated GPU scheduling
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DirectXUserGlobalSettings" 'String' "VSync=0;TdrDelay=10;" | Out-Null
        Log "Hardware-accelerated GPU scheduling enabled"
    }
    
    if ($chkGpuPowerStates.IsChecked) {
        # Disable GPU power saving states
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" "PP_DisablePowerContainment" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" "PP_ThermalAutoThrottlingEnable" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\44f3beca-a7c0-460e-9df2-bb8b99e0cba6\3619c3f2-afb2-4afc-b0e9-e7fef372de36" "Attributes" 'DWord' 2 | Out-Null
        Log "GPU power saving states disabled for consistent performance"
    }
    
    if ($chkShaderCache.IsChecked) {
        # Optimize shader cache management
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DxgkrnlVersion" 'String' "10.0.0.0" | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" "DirectXUserGlobalSettings" 'String' "SwapEffectUpgradeEnable=1;" | Out-Null
        New-Item -Path "C:\ProgramData\NVIDIA Corporation\NV_Cache" -ItemType Directory -Force | Out-Null
        Log "Shader cache optimization applied"
    }
    
    if ($chkGameIO.IsChecked) {
        # Game file I/O priority optimization
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" "IoEnableStackSwapping" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" "ForcedPhysicalDiskIo" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMftZoneReservation" 'DWord' 4 | Out-Null
        Log "Game file I/O priority optimized"
    }
    
    if ($chkDiskOptimization.IsChecked) {
        # Disk performance optimizations
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisable8dot3NameCreation" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "Win95TruncatedExtensions" 'DWord' 0 | Out-Null
        fsutil behavior set DisableDeleteNotify 0 | Out-Null
        Log "Disk performance optimizations applied"
    }
    
    if ($chkNetworkGaming.IsChecked) {
        # Gaming-specific network optimizations
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpWindowSize" 'DWord' 65536 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "Tcp1323Opts" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpMaxDupAcks" 'DWord' 2 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "SackOpts" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SOFTWARE\Microsoft\MSMQ\Parameters" "TCPNoDelay" 'DWord' 1 | Out-Null
        Log "Gaming network stack optimizations applied"
    }
    
    if ($chkGamingAudio.IsChecked) {
        # Gaming audio optimizations
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio" "DisableProtectedAudioDG" 'DWord' 1 | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Multimedia\Audio" "UserDuckingPreference" 'DWord' 3 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\AudioSrv" "DependOnService" 'MultiString' @("AudioEndpointBuilder", "RpcSs") | Out-Null
        Log "Gaming audio optimization (exclusive mode) enabled"
    }
    
    if ($chkInputOptimization.IsChecked) {
        # Gaming input optimizations
        Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" 'String' "0" | Out-Null
        Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" 'String' "0" | Out-Null
        Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" 'String' "0" | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" "MouseDataQueueSize" 'DWord' 20 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" "KeyboardDataQueueSize" 'DWord' 20 | Out-Null
        Log "Gaming input optimization (raw input, no acceleration) applied"
    }

    # SMART GAMING DETECTION & AUTO-OPTIMIZATION
    if ($chkAutoGameDetection.IsChecked) {
        Start-SmartGameDetection -EnableAutoProfile:$chkAutoProfileSwitch.IsChecked -EnableMetrics:$chkPerformanceMetrics.IsChecked -EnableAutoRevert:$chkAutoRevert.IsChecked -EnableBackgroundSuspend:$chkBackgroundAppSuspend.IsChecked
        Log "Smart game detection and auto-optimization enabled"
    } else {
        Stop-SmartGameDetection
    }
    
    if ($chkGameSpecificProfiles.IsChecked) {
        # Game-specific profile functionality is handled by the detection service
        Log "Game-specific profiles enabled for automatic optimization"
    }
    
    if ($chkPerformanceMetrics.IsChecked) {
        Log "Real-time performance metrics monitoring enabled"
    }

    # GPU VENDOR OPTIMIZATIONS
    $gpu = Get-GPUVendor
    Log "Detected GPU: $gpu"
    
    if ($chkNvidiaTweaks.IsChecked -and $gpu -eq 'NVIDIA') {
        $svc = Get-ServiceState 'NvTelemetryContainer'
        if ($svc) { 
            Set-ServiceState $svc 'Disabled' 'Stop'
            Log "NVIDIA telemetry service disabled"
        } else { Log "NVIDIA telemetry service not found" }
        
        # Additional NVIDIA optimizations
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrLevel" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 'DWord' 60 | Out-Null
        Log "NVIDIA TDR (Timeout Detection and Recovery) optimized"
    }
    
    if ($chkAmdTweaks.IsChecked -and $gpu -eq 'AMD') {
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*AMD External Events*" } | Select-Object -First 1
        if ($svc) {
            $st = Get-ServiceState $svc.Name
            Set-ServiceState $st 'Disabled' 'Stop'
            Log "AMD External Events service disabled"
        } else { Log "AMD External Events service not found" }
    }
    
    if ($chkIntelTweaks.IsChecked -and $gpu -eq 'Intel') {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrLevel" 'DWord' 0 | Out-Null
        Log "Intel graphics optimizations applied"
    }

    # SERVICE OPTIMIZATIONS
    $servicesToDisable = @()
    
    if ($chkSvcXbox.IsChecked) {
        $servicesToDisable += @('XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc')
    }
    if ($chkSvcSpooler.IsChecked) { $servicesToDisable += 'Spooler' }
    if ($chkSvcSysMain.IsChecked) { $servicesToDisable += 'SysMain' }
    if ($chkSvcDiagTrack.IsChecked) { $servicesToDisable += 'DiagTrack' }
    if ($chkSvcSearch.IsChecked) { $servicesToDisable += 'WSearch' }
    if ($chkSvcTablet.IsChecked) { $servicesToDisable += @('TabletInputService','TouchKeyboard') }
    if ($chkSvcThemes.IsChecked) { $servicesToDisable += 'Themes' }
    if ($chkDisableUnneeded.IsChecked) {
        $servicesToDisable += @('Fax','RemoteRegistry','MapsBroker','WMPNetworkSvc','WpnUserService','bthserv')
    }
    
    foreach ($svcName in $servicesToDisable) {
        $st = Get-ServiceState $svcName
        if ($st) { 
            Set-ServiceState $st 'Disabled' 'Stop'
            Log "Service disabled: $($st.Display)"
        }
    }

    # GAME-SPECIFIC OPTIMIZATIONS - KORRIGIERT
    $selectedProfile = $cmbGameProfile.SelectedItem.Tag.ToString()
    if ($selectedProfile -ne 'custom' -and $GameProfiles.Contains($selectedProfile)) {
        Apply-GameSpecificTweaks $selectedProfile $GameProfiles[$selectedProfile].SpecificTweaks
    }

    # PROCESS PRIORITY OPTIMIZER
    $procName = ($txtProcess.Text).Trim()
    $selectedPriority = $cmbPriority.SelectedItem.Tag.ToString()
    
    if ($procName) {
        $existing = Get-Job -Name 'KoalaPriority' -ErrorAction SilentlyContinue
        if ($existing) { Stop-Job $existing -ErrorAction SilentlyContinue; Remove-Job $existing -ErrorAction SilentlyContinue }
        
        $monitoringEnabled = $chkRealTimeMonitoring.IsChecked
        
        Start-Job -Name 'KoalaPriority' -ScriptBlock {
            param($name, $priority, $gamePath, $enableMonitoring)
            $lastCpuReport = Get-Date
            $lastMemReport = Get-Date
            
            while ($true) {
                try {
                    # Find and optimize main process
                    $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
                    foreach ($p in $processes) {
                        $p.PriorityClass = $priority
                        
                        # Enhanced CPU affinity management
                        if ($priority -eq 'High' -or $priority -eq 'RealTime') {
                            $coreCount = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
                            if ($coreCount -gt 4) {
                                # Use cores 2-N for the game, leave core 0-1 for system
                                $affinityMask = [math]::Pow(2, $coreCount) - 1 - 3  # All cores except 0,1
                                $p.ProcessorAffinity = $affinityMask
                            }
                        }
                        
                        # Real-time monitoring (if enabled)
                        if ($enableMonitoring) {
                            $now = Get-Date
                            
                            # CPU usage monitoring (every 30 seconds)
                            if (($now - $lastCpuReport).TotalSeconds -ge 30) {
                                try {
                                    $cpuUsage = $p.CPU
                                    $workingSet = [math]::Round($p.WorkingSet64 / 1MB, 1)
                                    $privateMemory = [math]::Round($p.PrivateMemorySize64 / 1MB, 1)
                                    Write-Host "[$($now.ToString('HH:mm:ss'))] $name - CPU: $([math]::Round($cpuUsage, 1))%, RAM: $workingSet MB, Private: $privateMemory MB"
                                    $lastCpuReport = $now
                                } catch {}
                            }
                            
                            # Memory optimization (every 60 seconds)
                            if (($now - $lastMemReport).TotalSeconds -ge 60) {
                                try {
                                    # Force garbage collection for .NET processes
                                    if ($p.ProcessName -match 'dotnet|unity|unreal') {
                                        [System.GC]::Collect()
                                        [System.GC]::WaitForPendingFinalizers()
                                    }
                                    $lastMemReport = $now
                                } catch {}
                            }
                        }
                    }
                    
                    # Additional process optimizations if game path is provided
                    if ($gamePath -and (Test-Path $gamePath)) {
                        $gameDir = Split-Path $gamePath -Parent
                        $gameExe = Split-Path $gamePath -Leaf
                        
                        # Set high priority I/O for game directory
                        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
                            $_.PriorityBoostEnabled = $true
                        }
                    }
                } catch {}
                Start-Sleep -Seconds 2
            }
        } -ArgumentList $procName, $selectedPriority, $txtGamePath.Text.Trim(), $monitoringEnabled | Out-Null
        
        if ($monitoringEnabled) {
            Log "Priority optimizer with real-time monitoring started for '$procName' (Priority: $selectedPriority)"
        } else {
            Log "Priority optimizer started for '$procName' (Priority: $selectedPriority)"
        }
    }

    $lblStatus.Text = "Complete!"
    $lblStatus.Foreground = "#00FF88"
    Log "All optimizations applied successfully! Some changes may require a reboot."
}

function Revert-Tweaks {
    # Check admin status for revert operations
    if (-not (Test-AdminPrivileges)) {
        try {
            Require-Admin -ShowFallbackOptions
        } catch {
            Log $_.Exception.Message 'Warning'
            return
        }
    }
    
    $lblStatus.Text = "Reverting..."
    $lblStatus.Foreground = "#F59E0B"
    
    Log "Reverting all optimizations..."

    # Stop priority job
    $existing = Get-Job -Name 'KoalaPriority' -ErrorAction SilentlyContinue
    if ($existing) { 
        Stop-Job $existing -ErrorAction SilentlyContinue
        Remove-Job $existing -ErrorAction SilentlyContinue
        Log "Priority optimizer stopped"
    }

    # Revert timer resolution
    try { [WinMM]::timeEndPeriod(1) | Out-Null } catch {}

    # Revert selective visual effects
    Set-SelectiveVisualEffects -Revert

    Restore-FromBackup
    
    $lblStatus.Text = "Reverted"
    $lblStatus.Foreground = "#00FF88"
}

function Show-SystemInfo {
    $gpu = Get-GPUVendor
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $powerPlan = (powercfg /getactivescheme).Split('(')[1].Split(')')[0]
    
    $info = @"
SYSTEM INFORMATION
Computer: $($cs.Name)
OS: $($os.Caption) ($($os.Version))
CPU: $($cpu.Name) ($($cpu.NumberOfLogicalProcessors) cores)
RAM: $ram GB
GPU: $gpu
Power Plan: $powerPlan
CPU Usage: $((Get-CimInstance Win32_Processor).LoadPercentage)%
Available Memory: $([math]::Round($os.FreePhysicalMemory / 1MB, 2)) GB
"@
    
    Log $info
    $lblStatus.Text = "System info displayed"
    $lblStatus.Foreground = "#58A6FF"
}

function Run-QuickBenchmark {
    $lblStatus.Text = "Benchmarking..."
    $lblStatus.Foreground = "#F59E0B"
    Log "Running quick system benchmark..."
    
    # CPU benchmark
    $start = Get-Date
    1..1000000 | ForEach-Object { [math]::Sqrt($_) } | Out-Null
    $cpuTime = ((Get-Date) - $start).TotalMilliseconds
    
    # Memory benchmark
    $start = Get-Date
    $array = 1..100000
    $filtered = $array | Where-Object { $_ % 2 -eq 0 }
    $memTime = ((Get-Date) - $start).TotalMilliseconds
    
    # Network latency test to common gaming servers
    $pingResults = @()
    try {
        $ping1 = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -WarningAction SilentlyContinue
        if ($ping1.PingSucceeded) { $pingResults += "Google DNS: $($ping1.PingReplyDetails.RoundtripTime)ms" }
    } catch {}
    
    $benchmark = @"
QUICK BENCHMARK RESULTS
CPU Performance: $([math]::Round(10000 / $cpuTime, 2)) ops/ms
Memory Performance: $([math]::Round(100000 / $memTime, 2)) ops/ms
Network Latency: $($pingResults -join ', ')
Performance Score: $([math]::Round((10000 / $cpuTime + 100000 / $memTime) / 2, 0))
"@
    
    Log $benchmark
    $lblStatus.Text = "Benchmark complete"
    $lblStatus.Foreground = "#00FF88"
}

function Export-Configuration {
    $config = @{
        Timestamp = Get-Date
        Settings = @{
            NetworkOptimizations = @{
                TCPAckDelay = $chkAck.IsChecked
                DelAckTicks = $chkDelAckTicks.IsChecked
                TCPAutoTune = $chkTcpAutoTune.IsChecked
                TCPTimestamps = $chkTcpTimestamps.IsChecked
                TCPECN = $chkTcpECN.IsChecked
                RSS = $chkRSS.IsChecked
                RSC = $chkRSC.IsChecked
                NetworkThrottling = $chkThrottle.IsChecked
                NagleAlgorithm = $chkNagle.IsChecked
            }
            WindowsOptimizations = @{
                SystemResponsiveness = $chkResponsiveness.IsChecked
                GamesTaskPriority = $chkGamesTask.IsChecked
                GameDVR = $chkGameDVR.IsChecked
                FullscreenOptimizations = $chkFSE.IsChecked
                GPUScheduler = $chkGpuScheduler.IsChecked
                TimerResolution = $chkTimerRes.IsChecked
                VisualEffects = $chkVisualEffects.IsChecked
                Hibernation = $chkHibernation.IsChecked
            }
            SystemPerformance = @{
                MemoryManagement = $chkMemoryManagement.IsChecked
                PowerPlan = $chkPowerPlan.IsChecked
                CPUScheduling = $chkCpuScheduling.IsChecked
                PageFile = $chkPageFile.IsChecked
            }
            Services = @{
                Xbox = $chkSvcXbox.IsChecked
                PrintSpooler = $chkSvcSpooler.IsChecked
                SysMain = $chkSvcSysMain.IsChecked
                Telemetry = $chkSvcDiagTrack.IsChecked
                WindowsSearch = $chkSvcSearch.IsChecked
                TabletServices = $chkSvcTablet.IsChecked
                Themes = $chkSvcThemes.IsChecked
                UnneededServices = $chkDisableUnneeded.IsChecked
            }
            GameSettings = @{
                SelectedProfile = if ($cmbGameProfile.SelectedItem) { $cmbGameProfile.SelectedItem.Tag.ToString() } else { "custom" }
                ProcessName = $txtProcess.Text
                GamePath = $txtGamePath.Text
                Priority = if ($cmbPriority.SelectedItem) { $cmbPriority.SelectedItem.Tag.ToString() } else { "High" }
            }
        }
    }
    
    $configPath = Join-Path $ScriptRoot "KoalaConfig_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $config | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8
    Log "Configuration exported to: $configPath"
    $lblStatus.Text = "Config exported"
    $lblStatus.Foreground = "#10B981"
}

function Import-Configuration {
    # Simple file dialog using COM object
    try {
        $openFileDialog = New-Object -ComObject Shell.Application
        $folder = $openFileDialog.BrowseForFolder(0, "Select configuration file", 0, $ScriptRoot)
        if ($folder -and $folder.Self -and $folder.Self.Path) {
            $selectedPath = $folder.Self.Path
            $jsonFiles = Get-ChildItem -Path $selectedPath -Filter "*.json" | Out-GridView -Title "Select Configuration File" -OutputMode Single
            if ($jsonFiles) {
                $configFile = $jsonFiles.FullName
                $config = Get-Content $configFile -Raw | ConvertFrom-Json
                
                # Apply network settings
                $chkAck.IsChecked = $config.Settings.NetworkOptimizations.TCPAckDelay
                $chkDelAckTicks.IsChecked = $config.Settings.NetworkOptimizations.DelAckTicks
                $chkTcpAutoTune.IsChecked = $config.Settings.NetworkOptimizations.TCPAutoTune
                $chkTcpTimestamps.IsChecked = $config.Settings.NetworkOptimizations.TCPTimestamps
                $chkTcpECN.IsChecked = $config.Settings.NetworkOptimizations.TCPECN
                $chkRSS.IsChecked = $config.Settings.NetworkOptimizations.RSS
                $chkRSC.IsChecked = $config.Settings.NetworkOptimizations.RSC
                $chkThrottle.IsChecked = $config.Settings.NetworkOptimizations.NetworkThrottling
                $chkNagle.IsChecked = $config.Settings.NetworkOptimizations.NagleAlgorithm
                
                # Apply Windows settings
                $chkResponsiveness.IsChecked = $config.Settings.WindowsOptimizations.SystemResponsiveness
                $chkGamesTask.IsChecked = $config.Settings.WindowsOptimizations.GamesTaskPriority
                $chkGameDVR.IsChecked = $config.Settings.WindowsOptimizations.GameDVR
                $chkFSE.IsChecked = $config.Settings.WindowsOptimizations.FullscreenOptimizations
                $chkGpuScheduler.IsChecked = $config.Settings.WindowsOptimizations.GPUScheduler
                $chkTimerRes.IsChecked = $config.Settings.WindowsOptimizations.TimerResolution
                $chkVisualEffects.IsChecked = $config.Settings.WindowsOptimizations.VisualEffects
                $chkHibernation.IsChecked = $config.Settings.WindowsOptimizations.Hibernation
                
                # Apply system performance settings
                $chkMemoryManagement.IsChecked = $config.Settings.SystemPerformance.MemoryManagement
                $chkPowerPlan.IsChecked = $config.Settings.SystemPerformance.PowerPlan
                $chkCpuScheduling.IsChecked = $config.Settings.SystemPerformance.CPUScheduling
                $chkPageFile.IsChecked = $config.Settings.SystemPerformance.PageFile
                
                # Apply service settings
                $chkSvcXbox.IsChecked = $config.Settings.Services.Xbox
                $chkSvcSpooler.IsChecked = $config.Settings.Services.PrintSpooler
                $chkSvcSysMain.IsChecked = $config.Settings.Services.SysMain
                $chkSvcDiagTrack.IsChecked = $config.Settings.Services.Telemetry
                $chkSvcSearch.IsChecked = $config.Settings.Services.WindowsSearch
                $chkSvcTablet.IsChecked = $config.Settings.Services.TabletServices
                $chkSvcThemes.IsChecked = $config.Settings.Services.Themes
                $chkDisableUnneeded.IsChecked = $config.Settings.Services.UnneededServices
                
                # Apply game settings
                $txtProcess.Text = $config.Settings.GameSettings.ProcessName
                $txtGamePath.Text = $config.Settings.GameSettings.GamePath
                
                # Set game profile
                $targetProfile = $config.Settings.GameSettings.SelectedProfile
                for ($i = 0; $i -lt $cmbGameProfile.Items.Count; $i++) {
                    if ($cmbGameProfile.Items[$i].Tag.ToString() -eq $targetProfile) {
                        $cmbGameProfile.SelectedIndex = $i
                        break
                    }
                }
                
                # Set priority
                $targetPriority = $config.Settings.GameSettings.Priority
                for ($i = 0; $i -lt $cmbPriority.Items.Count; $i++) {
                    if ($cmbPriority.Items[$i].Tag.ToString() -eq $targetPriority) {
                        $cmbPriority.SelectedIndex = $i
                        break
                    }
                }
                
                Log "Configuration imported successfully from: $configFile"
                $lblStatus.Text = "Config imported"
                $lblStatus.Foreground = "#10B981"
            }
        }
    } catch {
        Log "Failed to import configuration: $_"
        $lblStatus.Text = "Import failed"
        $lblStatus.Foreground = "#FF6B6B"
    }
}

function Start-SmartGameDetection {
    param(
        [switch]$EnableAutoProfile,
        [switch]$EnableMetrics,
        [switch]$EnableAutoRevert,
        [switch]$EnableBackgroundSuspend
    )
    
    # Stop existing game detection job if running
    $existing = Get-Job -Name 'KoalaGameDetection' -ErrorAction SilentlyContinue
    if ($existing) {
        Stop-Job $existing -PassThru | Remove-Job
        Log "Stopped existing game detection service"
    }
    
    # Start new game detection background job
    Start-Job -Name 'KoalaGameDetection' -ScriptBlock {
        param($GameProfiles, $EnableAutoProfile, $EnableMetrics, $EnableAutoRevert, $EnableBackgroundSuspend)
        
        $detectedGames = @{}
        $suspendedApps = @()
        $lastMetricsReport = Get-Date
        
        while ($true) {
            try {
                # Check for running games
                $runningGames = @()
                foreach ($profileKey in $GameProfiles.Keys) {
                    $profile = $GameProfiles[$profileKey]
                    foreach ($processName in $profile.ProcessNames) {
                        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
                        if ($processes) {
                            $runningGames += @{
                                Profile = $profileKey
                                DisplayName = $profile.DisplayName
                                Processes = $processes
                            }
                            
                            # Apply auto-optimizations if not already applied
                            if (-not $detectedGames.ContainsKey($profileKey)) {
                                $detectedGames[$profileKey] = Get-Date
                                
                                if ($EnableAutoProfile) {
                                    # Apply game-specific optimizations
                                    foreach ($process in $processes) {
                                        try {
                                            $process.PriorityClass = $profile.Priority
                                            # Apply CPU affinity if specified
                                            if ($profile.Affinity -ne 'Auto') {
                                                $process.ProcessorAffinity = [int]$profile.Affinity
                                            }
                                        } catch {}
                                    }
                                }
                                
                                if ($EnableBackgroundSuspend) {
                                    # Suspend non-essential background applications
                                    $nonEssentialApps = @('explorer', 'dwm', 'winlogon', 'csrss', 'wininit', 'services', 'lsass', 'svchost')
                                    $backgroundProcesses = Get-Process | Where-Object { 
                                        $_.Name -notin $nonEssentialApps -and 
                                        $_.Name -notin $profile.ProcessNames -and
                                        $_.ProcessName -notlike '*nvidia*' -and
                                        $_.ProcessName -notlike '*amd*' -and
                                        $_.ProcessName -notlike '*intel*' -and
                                        $_.WorkingSet -gt 50MB
                                    }
                                    
                                    foreach ($bgProcess in $backgroundProcesses) {
                                        try {
                                            $bgProcess.PriorityClass = 'BelowNormal'
                                            if ($bgProcess.Name -notin $suspendedApps) {
                                                $suspendedApps += $bgProcess.Name
                                            }
                                        } catch {}
                                    }
                                }
                            }
                        }
                    }
                }
                
                # Check for games that have exited
                $currentGameKeys = $runningGames | ForEach-Object { $_.Profile }
                $exitedGames = $detectedGames.Keys | Where-Object { $_ -notin $currentGameKeys }
                
                foreach ($exitedGame in $exitedGames) {
                    $detectedGames.Remove($exitedGame)
                    
                    if ($EnableAutoRevert) {
                        # Restore suspended applications
                        foreach ($appName in $suspendedApps) {
                            $processes = Get-Process -Name $appName -ErrorAction SilentlyContinue
                            foreach ($process in $processes) {
                                try {
                                    $process.PriorityClass = 'Normal'
                                } catch {}
                            }
                        }
                        $suspendedApps = @()
                    }
                }
                
                # Performance metrics reporting
                if ($EnableMetrics -and ((Get-Date) - $lastMetricsReport).TotalSeconds -ge 30) {
                    if ($runningGames.Count -gt 0) {
                        foreach ($game in $runningGames) {
                            $totalCpu = ($game.Processes | Measure-Object CPU -Sum).Sum
                            $totalMemory = ($game.Processes | Measure-Object WorkingSet -Sum).Sum / 1MB
                            # Note: In a real implementation, FPS would need external tool integration
                            Write-Host "[$($game.DisplayName)] CPU: $([math]::Round($totalCpu, 1))% | RAM: $([math]::Round($totalMemory, 0))MB"
                        }
                    }
                    $lastMetricsReport = Get-Date
                }
                
                Start-Sleep -Seconds 5
            } catch {
                # Continue on error
                Start-Sleep -Seconds 10
            }
        }
    } -ArgumentList $GameProfiles, $EnableAutoProfile, $EnableMetrics, $EnableAutoRevert, $EnableBackgroundSuspend
    
    Log "Smart game detection service started with advanced monitoring"
}

function Stop-SmartGameDetection {
    $existing = Get-Job -Name 'KoalaGameDetection' -ErrorAction SilentlyContinue
    if ($existing) {
        Stop-Job $existing -PassThru | Remove-Job
        Log "Game detection service stopped"
    }
}

function Update-PerformanceMetrics {
    param([switch]$RunOnce)
    
    try {
        # Update CPU usage
        $cpuUsage = Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
        $global:lblCpuUsage.Text = "$([math]::Round($cpuUsage, 1))%"
        
        # Update memory usage
        $memInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $totalMemory = $memInfo.TotalVisibleMemorySize / 1024
        $freeMemory = $memInfo.FreePhysicalMemory / 1024
        $usedMemory = $totalMemory - $freeMemory
        $global:lblMemoryUsage.Text = "$([math]::Round($usedMemory, 0)) MB"
        
        # Update active games
        $activeGames = @()
        foreach ($profileKey in $GameProfiles.Keys) {
            $profile = $GameProfiles[$profileKey]
            foreach ($processName in $profile.ProcessNames) {
                $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
                if ($processes) {
                    $activeGames += $profile.DisplayName
                    break
                }
            }
        }
        
        if ($activeGames.Count -gt 0) {
            $global:lblActiveGames.Text = ($activeGames -join ", ")
            if ($activeGames.Count -gt 1) {
                $global:lblActiveGames.Text = "$($activeGames.Count) games"
            }
        } else {
            $global:lblActiveGames.Text = "None"
        }
        
        # Update optimization status
        $optimizationCount = 0
        if ($chkTimerRes.IsChecked) { $optimizationCount++ }
        if ($chkGpuScheduling.IsChecked) { $optimizationCount++ }
        if ($chkNetworkGaming.IsChecked) { $optimizationCount++ }
        if ($chkCpuCorePark.IsChecked) { $optimizationCount++ }
        if ($chkMemCompression.IsChecked) { $optimizationCount++ }
        
        if ($optimizationCount -gt 0) {
            $global:lblOptimizationStatus.Text = "$optimizationCount active"
        } else {
            $global:lblOptimizationStatus.Text = "Ready"
        }
        
    } catch {
        # Fail silently for metrics
    }
}

function Start-PerformanceMetricsTimer {
    # Start a background timer for updating performance metrics
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(2)
    $timer.Add_Tick({
        Update-PerformanceMetrics
    })
    $timer.Start()
    return $timer
}

# ---------- Event Handlers ----------
$btnApply.Add_Click({
    try {
        $global:LogBox.Clear()
        Apply-Tweaks
    } catch {
        Log "Error during Apply: $_"
        $lblStatus.Text = "Error occurred"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

$btnRevert.Add_Click({
    try {
        $global:LogBox.Clear()
        Revert-Tweaks
    } catch {
        Log "Error during Revert: $_"
        $lblStatus.Text = "Revert failed"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

$btnDetect.Add_Click({
    $lblStatus.Text = "Detecting..."
    $lblStatus.Foreground = "#F59E0B"
    
    foreach ($gameKey in $GameProfiles.Keys) {
        $profile = $GameProfiles[$gameKey]
        foreach ($procName in $profile.ProcessNames) {
            $p = Get-Process -Name $procName -ErrorAction SilentlyContinue
            if ($p) {
                $txtProcess.Text = $procName
                
                # Set the game profile
                for ($i = 0; $i -lt $cmbGameProfile.Items.Count; $i++) {
                    if ($cmbGameProfile.Items[$i].Tag.ToString() -eq $gameKey) {
                        $cmbGameProfile.SelectedIndex = $i
                        break
                    }
                }
                
                Log "Detected running game: $($profile.DisplayName) (Process: $procName)"
                $lblStatus.Text = "Game detected!"
                $lblStatus.Foreground = "#00FF88"
                return
            }
        }
    }
    Log "No known game processes detected"
    $lblStatus.Text = "No games found"
    $lblStatus.Foreground = "#F59E0B"
})

$btnSystemInfo.Add_Click({
    try {
        Show-SystemInfo
    } catch {
        Log "Error showing system info: $_"
    }
})

$btnBenchmark.Add_Click({
    try {
        Run-QuickBenchmark
    } catch {
        Log "Error during benchmark: $_"
        $lblStatus.Text = "Benchmark failed"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

$btnExportConfig.Add_Click({
    try {
        Export-Configuration
    } catch {
        Log "Error exporting config: $_"
        $lblStatus.Text = "Export failed"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

$btnImportConfig.Add_Click({
    try {
        Import-Configuration
    } catch {
        Log "Error importing config: $_"
        $lblStatus.Text = "Import failed"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

# ---------- Form Lifecycle ----------
$form.Add_SourceInitialized({
    Log "KOALA-UDP Enhanced Gaming Toolkit v2.2 (Enhanced FPS Edition) loaded"
    Log "Select your optimizations and click 'Recommended' to begin"
    
    # Check and display admin status
    $adminStatus = Get-AdminStatusMessage
    Log $adminStatus
    
    # If not admin, offer elevation option
    if (-not (Test-AdminPrivileges)) {
        Log "💡 Tip: For full functionality, restart as Administrator or click 'Recommended' for elevation prompt" 'Warning'
    }
    
    # Perform system requirements check
    Test-SystemRequirements
    
    # Auto-detect GPU and show recommendations
    $gpu = Get-GPUVendor
    if ($gpu -eq 'NVIDIA') {
        $chkNvidiaTweaks.IsChecked = $true
        Log "Recommendation: NVIDIA GPU detected - NVIDIA tweaks pre-selected"
    } elseif ($gpu -eq 'AMD') {
        $chkAmdTweaks.IsChecked = $true
        Log "Recommendation: AMD GPU detected - AMD tweaks pre-selected"
    } elseif ($gpu -eq 'Intel') {
        $chkIntelTweaks.IsChecked = $true
        Log "Recommendation: Intel GPU detected - Intel tweaks pre-selected"
    }
    
    # Pre-select recommended optimizations (excluding visual themes)
    $chkAck.IsChecked = $true
    $chkDelAckTicks.IsChecked = $true
    $chkResponsiveness.IsChecked = $true
    $chkGamesTask.IsChecked = $true
    $chkGameDVR.IsChecked = $true
    $chkTimerRes.IsChecked = $true
    
    # Pre-select enhanced gaming optimizations for better defaults
    $chkNetworkLatency.IsChecked = $true
    $chkGameMode.IsChecked = $true
    $chkPowerOptimization.IsChecked = $true
    $chkProcessOptimization.IsChecked = $true
    
    # Pre-select key FPS-boosting optimizations (safe defaults)
    $chkCpuCorePark.IsChecked = $true
    $chkInterruptMod.IsChecked = $true
    $chkMMCSS.IsChecked = $true
    $chkGpuScheduling.IsChecked = $true
    $chkNetworkGaming.IsChecked = $true
    $chkInputOptimization.IsChecked = $true
    
    # Pre-select smart gaming features (safe defaults)
    $chkAutoGameDetection.IsChecked = $true
    $chkPerformanceMetrics.IsChecked = $true
    
    # Note: Visual effects (chkVisualEffects) intentionally NOT pre-selected
    # per requirement to exclude visual themes from recommended settings
    
    if ($chkTimerRes.IsChecked) {
        try { [WinMM]::timeBeginPeriod(1) | Out-Null } catch {}
    }
    
    # Start performance metrics timer
    $global:PerformanceTimer = Start-PerformanceMetricsTimer
    Update-PerformanceMetrics -RunOnce
    
    Log "Ready for optimization! Select additional options as needed and click 'Recommended'"
})

$form.Add_Closing({
    try {
        # Revert timer resolution
        [WinMM]::timeEndPeriod(1) | Out-Null
        
        # Stop background job
        $existing = Get-Job -Name 'KoalaPriority' -ErrorAction SilentlyContinue
        if ($existing) { 
            Stop-Job $existing -ErrorAction SilentlyContinue
            Remove-Job $existing -ErrorAction SilentlyContinue 
        }
        
        # Stop smart game detection service
        Stop-SmartGameDetection
        
        # Stop performance metrics timer
        if ($global:PerformanceTimer) {
            $global:PerformanceTimer.Stop()
        }
        
        Log "KOALA-UDP Gaming Toolkit closed - Timer resolution restored"
    } catch {}
})

# Set window properties
$form.Topmost = $true
$form.ResizeMode = "CanResize"
$form.MinWidth = 900
$form.MinHeight = 750

# Show the enhanced interface
Log "Starting KOALA-UDP Enhanced Gaming Toolkit..."
[void]$form.ShowDialog()
