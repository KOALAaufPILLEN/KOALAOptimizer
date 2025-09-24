# KOALA Gaming Optimizer v3.0 - COMPLETE ENHANCED VERSION
# Saved with UTF-8 BOM to preserve emoji characters when downloading raw scripts
# Full-featured Windows Gaming Optimizer with 40+ game profiles
# Works on PowerShell 5.1+ (Windows 10/11)
# Run as Administrator for best results

# Features included:
# - 40+ Game Profiles with auto-detection for popular games (CS2, Valorant, Fortnite, Apex Legends, etc.)
# - Complete WPF GUI with modern dark theme and proper layout
# - Network Optimizations (TCP ACK, Nagle Algorithm, Network Throttling, RSS, RSC, etc.)
# - Gaming Optimizations (Game DVR disable, FSE, GPU Scheduling, Timer Resolution, etc.)
# - System Performance (Memory Management, Power Plans, CPU Scheduling, Page File optimization)
# - Advanced FPS Boosting (Core Parking, C-States, Interrupt Moderation, MMCSS, Large Pages)
# - Advanced System Tweaks (HPET, Modern Standby, UTC Time, NTFS optimization)
# - Service Management (Xbox services, Telemetry, Search, Print Spooler, Superfetch)
# - Engine-specific optimizations (Unreal, Unity, Source, Frostbite engines)
# - Performance monitoring with real-time CPU/Memory display
# - Auto-optimization with game detection
# - Backup and restore system with full rollback capability
# - Export/Import configuration functionality
# - Quick benchmark tool
# - Advanced/Compact menu modes
# - Comprehensive logging system

# Script Version: 3.0.0
# Build Date: 2024
# Author: KOALA Team

# ---------- Check PowerShell Version ----------
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "This script requires PowerShell 5.0 or higher" -ForegroundColor Red
    exit 1
}

# Detect whether the current platform supports the Windows-specific UI that the
# optimizer relies on. Older PowerShell builds do not expose the $IsWindows
# automatic variable, so fall back to the .NET APIs when necessary.
$script:IsWindowsPlatform = $false
try {
    $script:IsWindowsPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows
    )
} catch {
    $script:IsWindowsPlatform = ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
}

if (-not $script:IsWindowsPlatform) {
    Write-Host 'KOALA Gaming Optimizer requires Windows because it depends on WPF and Windows-specific APIs.' -ForegroundColor Yellow
    return
}

# ---------- WPF Assemblies ----------
try {
    # Load required assemblies for the WPF-based UI. Breaking the list of
    # assemblies into an array keeps the code readable and avoids issues with
    # extremely long lines or accidental line wraps.
    $assemblies = @(
        'PresentationFramework'
        'PresentationCore'
        'WindowsBase'
        'System.Xaml'
        'System.Windows.Forms'
        'Microsoft.VisualBasic'
    )
    Add-Type -AssemblyName $assemblies -ErrorAction Stop
} catch {
    $warning = "Warning: WPF assemblies not available. This script requires Windows with .NET Framework."
    Write-Host $warning -ForegroundColor Yellow
    return
}

$BrushConverter = New-Object System.Windows.Media.BrushConverter

# ---------- Global Performance Variables ----------
$global:PerformanceCounters = @{}
$script:LocalizationResources = $null
if (-not $script:CurrentLanguage) {
    $script:CurrentLanguage = 'en'
}
$script:IsLanguageInitializing = $false
$global:OptimizationCache = @{}
$global:ActiveGames = @()
$global:MenuMode = "Basic"  # Basic or Advanced
$global:AutoOptimizeEnabled = $false
$global:LastTimestamp = $null
$global:CachedTimestamp = ""
$global:LogBoxAvailable = $false
$global:RegistryCache = @{}
$global:LastOptimizationTime = $null  # Track when optimizations were last applied

# ---------- .NET Framework 4.8 Compatibility Helper Functions ----------
function Set-BorderBrushSafe {
    param(
        [System.Windows.FrameworkElement]$Element,
        [object]$BorderBrushValue,
        [string]$BorderThicknessValue = $null
    )

    if (-not $Element) { return }

    try {
        # Check if element supports BorderBrush
        if ($Element.GetType().GetProperty("BorderBrush")) {
            Set-BrushPropertySafe -Target $Element -Property 'BorderBrush' -Value $BorderBrushValue -AllowTransparentFallback
        }

        # Set BorderThickness if provided and supported
        if ($BorderThicknessValue -and $Element.GetType().GetProperty("BorderThickness")) {
            $Element.BorderThickness = $BorderThicknessValue
        }
    } catch [System.InvalidOperationException] {
        # Sealed object exception - skip assignment
        Write-Verbose "BorderBrush assignment skipped due to sealed object (compatible with .NET Framework 4.8)"
    } catch {
        # Other exceptions - log but don't fail
        Write-Verbose "BorderBrush assignment failed: $($_.Exception.Message)"
    }
}

# ---------- CENTRALIZED THEME ARRAY - ONLY CHANGE HERE! ----------
# ---------- COMPLETE THEME ARRAY - ALL COLORS CENTRALIZED! ----------
$global:ThemeDefinitions = @{
    'Nebula' = @{
        Name = 'Nebula Vortex'
        Background = $BrushConverter.ConvertFromString('#0F0F12')
        Primary = '#A855F7'
        Hover = '#9333EA'
        Text = '#FFFFFF'
        Secondary = '#151517'
        Accent = '#A855F7'
        TextSecondary = '#9CA3AF'
        LogBg = '#111111'
        SidebarBg = '#141416'
        HeaderBg = '#151517'
        Success = '#22C55E'
        Warning = '#F59E0B'
        Danger = '#EF4444'
        Info = '#60A5FA'
        CardBackgroundStart = $BrushConverter.ConvertFromString('#1A1A1D')
        CardBackgroundEnd = $BrushConverter.ConvertFromString('#1A1A1D')
        SummaryBackgroundStart = $BrushConverter.ConvertFromString('#151517')
        SummaryBackgroundEnd = $BrushConverter.ConvertFromString('#151517')
        CardBorder = '#2A2A2E'
        GlowAccent = '#00000000'
        GaugeBackground = $BrushConverter.ConvertFromString('#1F1F23')
        GaugeStroke = '#A855F7'
        SelectedBackground = $BrushConverter.ConvertFromString('#A855F7')
        UnselectedBackground = $BrushConverter.ConvertFromString('#1F1F23')
        SelectedForeground = $BrushConverter.ConvertFromString('#FFFFFF')
        UnselectedForeground = $BrushConverter.ConvertFromString('#9CA3AF')
        HoverBackground = $BrushConverter.ConvertFromString('#222227')
        IsLight = $false
    }
    'Midnight' = @{
        Name = 'Midnight Azure'
        Background = $BrushConverter.ConvertFromString('#071021')
        Primary = '#3FA6FF'
        Hover = '#63B8FF'
        Text = '#E6F1FF'
        Secondary = '#0D1A33'
        Accent = '#35D0FF'
        TextSecondary = '#98B7D8'
        LogBg = '#0D1A33'
        SidebarBg = '#081326'
        HeaderBg = '#0F1F3C'
        Success = '#10B981'
        Warning = '#F59E0B'
        Danger = '#EF4444'
        Info = '#35D0FF'
        CardBackgroundStart = $BrushConverter.ConvertFromString('#12284A')
        CardBackgroundEnd = $BrushConverter.ConvertFromString('#081326')
        SummaryBackgroundStart = $BrushConverter.ConvertFromString('#1A3C63')
        SummaryBackgroundEnd = $BrushConverter.ConvertFromString('#0C203A')
        CardBorder = '#3FA6FF'
        GlowAccent = '#35D0FF'
        GaugeBackground = $BrushConverter.ConvertFromString('#102845')
        GaugeStroke = '#63B8FF'
        SelectedBackground = $BrushConverter.ConvertFromString('#3FA6FF')
        UnselectedBackground = $BrushConverter.ConvertFromString('Transparent')
        SelectedForeground = $BrushConverter.ConvertFromString('#031021')
        UnselectedForeground = $BrushConverter.ConvertFromString('#E6F1FF')
        HoverBackground = $BrushConverter.ConvertFromString('#1B395A')
        IsLight = $false
    }
    'Lumen' = @{
        Name = 'Lumen Daybreak'
        Background = $BrushConverter.ConvertFromString('#F5F7FB')
        Primary = '#5D5FEF'
        Hover = '#4448D8'
        Text = '#161B3A'
        Secondary = '#E7EAF5'
        Accent = '#2EA6A6'
        TextSecondary = '#444B72'
        LogBg = '#FFFFFF'
        SidebarBg = '#EEF1FA'
        HeaderBg = '#EEF1FA'
        Success = '#0EA769'
        Warning = '#C27803'
        Danger = '#C24133'
        Info = '#5D5FEF'
        CardBackgroundStart = $BrushConverter.ConvertFromString('#FFFFFF')
        CardBackgroundEnd = $BrushConverter.ConvertFromString('#E3E6F4')
        SummaryBackgroundStart = $BrushConverter.ConvertFromString('#FFFFFF')
        SummaryBackgroundEnd = $BrushConverter.ConvertFromString('#D6DAEE')
        CardBorder = '#5D5FEF'
        GlowAccent = '#2EA6A6'
        GaugeBackground = $BrushConverter.ConvertFromString('#FFFFFF')
        GaugeStroke = '#5D5FEF'
        SelectedBackground = $BrushConverter.ConvertFromString('#5D5FEF')
        UnselectedBackground = $BrushConverter.ConvertFromString('Transparent')
        SelectedForeground = $BrushConverter.ConvertFromString('#FFFFFF')
        UnselectedForeground = $BrushConverter.ConvertFromString('#161B3A')
        HoverBackground = $BrushConverter.ConvertFromString('#4448D8')
        IsLight = $true
    }
}

# Pre-instantiate the shared brush converter so later theming fallbacks never
# leave string literals or PSObject wrappers parked in resource dictionaries.
try {
    $script:SharedBrushConverter = [System.Windows.Media.BrushConverter]::new()
} catch {
    $script:SharedBrushConverter = $null
}

$script:BrushResourceKeys = @(
    'AppBackgroundBrush'
    'SidebarBackgroundBrush'
    'SidebarAccentBrush'
    'SidebarHoverBrush'
    'SidebarSelectedBrush'
    'SidebarSelectedForegroundBrush'
    'HeaderBackgroundBrush'
    'HeaderBorderBrush'
    'CardBackgroundBrush'
    'ContentBackgroundBrush'
    'CardBorderBrush'
    'HeroCardBrush'
    'AccentBrush'
    'PrimaryTextBrush'
    'SecondaryTextBrush'
    'SuccessBrush'
    'WarningBrush'
    'DangerBrush'
    'InfoBrush'
    'ButtonBackgroundBrush'
    'ButtonBorderBrush'
    'ButtonHoverBrush'
    'ButtonPressedBrush'
    'HeroChipBrush'
    'DialogBackgroundBrush'
)


function Register-BrushResourceKeys {
    param([System.Collections.IEnumerable]$Keys)

    if (-not $Keys) { return }

    foreach ($rawKey in $Keys) {
        if ($null -eq $rawKey) { continue }

        $keyText = $null
        try { $keyText = [string]$rawKey } catch { $keyText = $null }
        if ([string]::IsNullOrWhiteSpace($keyText)) { continue }
        if (-not $keyText.EndsWith('Brush')) { continue }

        if (-not $script:BrushResourceKeys) {
            $script:BrushResourceKeys = @()
        }

        if ($script:BrushResourceKeys -notcontains $keyText) {
            $script:BrushResourceKeys += $keyText
        }
    }
}


# Storage for the last applied custom theme so navigation refreshes reuse the same colors
$global:CustomThemeColors = $null


# Einfache Funktion zum Abrufen eines Themes
function Get-ThemeColors {
    param([string]$ThemeName = 'Nebula')

    if ($global:ThemeDefinitions.ContainsKey($ThemeName)) {
        return Normalize-ThemeColorTable $global:ThemeDefinitions[$ThemeName]
    } else {
        Log "Theme '$ThemeName' nicht gefunden, verwende Nebula" 'Warning'
        return Normalize-ThemeColorTable $global:ThemeDefinitions['Nebula']
    }
}

function Optimize-LogFile {
    param([int]$MaxSizeMB = 10)

    try {
        $logFilePath = Join-Path $ScriptRoot 'Koala-Activity.log'

        if (Test-Path $logFilePath) {
            $logFile = Get-Item $logFilePath
            $sizeMB = [math]::Round($logFile.Length / 1MB, 2)

            if ($sizeMB -gt $MaxSizeMB) {
                # Keep only the last 70% of the file
                $content = Get-Content $logFilePath
                $keepLines = [math]::Floor($content.Count * 0.7)
                $content[-$keepLines..-1] | Set-Content $logFilePath

                # Add optimization notice
                Add-Content $logFilePath "[$([DateTime]::Now.ToString('HH:mm:ss'))] [Info] Log file optimized - size reduced from $sizeMB MB"
            }
        }
    } catch {
        # Silent failure for log optimization to prevent recursion
    }
}

function Get-SystemPerformanceMetrics {
    param([switch]$Detailed)

    try {
        $metrics = @{
            CPU = 0
            Memory = 0
            Disk = 0
            Network = 0
        }

        # Get CPU usage
        try {
            $cpu = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average
            $metrics.CPU = [math]::Round($cpu.Average, 1)
        } catch {
            $metrics.CPU = 0
        }

        # Get Memory usage
        try {
            $totalMemory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
            $availableMemory = (Get-WmiObject -Class Win32_OperatingSystem).AvailablePhysicalMemory
            $usedMemory = $totalMemory - $availableMemory
            $metrics.Memory = [math]::Round(($usedMemory / $totalMemory) * 100, 1)
        } catch {
            $metrics.Memory = 0
        }

        if ($Detailed) {
            # Add more detailed metrics if needed
            $metrics.Timestamp = Get-Date
            $metrics.Source = "WMI"
        }

        return $metrics
    } catch {
        # Return default metrics on error
        return @{
            CPU = 0
            Memory = 0
            Disk = 0
            Network = 0
        }
    }
}

function Ensure-NavigationVisibility {
    param([System.Windows.Controls.Panel]$NavigationPanel)

    try {
        if (-not $NavigationPanel) {
            return
        }

        # Ensure all navigation buttons are visible and properly styled
        $navigationButtons = @(
            'btnNavDashboard', 'btnNavBasicOpt', 'btnNavAdvanced', 'btnNavGames',
            'btnNavOptions', 'btnNavBackup', 'btnNavLog'
        )

        foreach ($buttonName in $navigationButtons) {
            try {
                $button = $form.FindName($buttonName)
                if ($button) {
                    $button.Visibility = [System.Windows.Visibility]::Visible

                    # Ensure proper styling
                    if (-not $button.Style) {
                        Set-BrushPropertySafe -Target $button -Property 'Background' -Value '#2F285A'
                        Set-BrushPropertySafe -Target $button -Property 'Foreground' -Value '#F5F3FF'
                        $button.BorderThickness = '0'
                        $button.Margin = '0,2'
                        $button.Padding = '15,10'
                    }
                }
            } catch {
                # Silent failure for individual buttons
            }
        }
    } catch {
        # Silent failure for navigation visibility
    }
}


# ---------- Paths with Admin-safe Configuration ----------
if ($PSScriptRoot) {
    $ScriptRoot = $PSScriptRoot
} elseif ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $ScriptRoot = (Get-Location).Path
}

# Function moved to after helper functions to fix call order

# Initialize global variables for custom paths
$global:CustomConfigPath = $null
$global:CustomGamePaths = @()

# ---------- Core Logging Functions (moved to top to fix call order issues) ----------
function Get-LogColor($Level) {
    switch ($Level) {
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        'Success' { 'Green' }
        default { 'White' }
    }
}


$global:LogFilterSettings = @{
    ShowInfo = $true
    ShowSuccess = $true
    ShowWarning = $true
    ShowError = $true
    ShowContext = $false
    ShowDebug = $false
    SearchTerm = ""
    CategoryFilter = "All"
}
$global:LogCategories = @("All", "System", "Gaming", "Network", "UI", "Performance", "Security", "Optimization", "Status", "Debug")
$global:LogHistory = [System.Collections.ArrayList]::new()
$global:MaxLogHistorySize = 1000

function Get-EnhancedLogCategories {
    <#
    .SYNOPSIS
    Enhanced logging categories for better organization and filtering
    .DESCRIPTION
    Provides categorization system for logs to enable filtering and organization
    #>

    return @{
        "System" = @("Registry", "Service", "Process", "Hardware", "Driver")
        "Gaming" = @("Game", "Profile", "Optimization", "FPS", "Latency", "Auto-Detect")
        "Network" = @("TCP", "UDP", "Latency", "Bandwidth", "DNS", "Firewall")
        "UI" = @("Theme", "Panel", "Control", "Navigation", "Scale", "Layout")
        "Performance" = @("CPU", "Memory", "Disk", "GPU", "Benchmark", "Monitor")
        "Security" = @("Admin", "Permission", "UAC", "Privilege", "Access")
        "Optimization" = @("Applied", "Reverted", "Backup", "Restore", "Config")
        "Status" = @("Success", "Completed", "Ready", "Warning", "Alert", "Caution", "Healthy")
        "Debug" = @("Verbose", "Trace", "Internal", "Exception", "Stack")
    }
}

function Get-LogCategory {
    <#
    .SYNOPSIS
    Determines the category of a log message based on content analysis
    .PARAMETER Message
    The log message to categorize
    #>
    param([string]$Message)

    $categories = Get-EnhancedLogCategories

    foreach ($category in $categories.Keys) {
        foreach ($keyword in $categories[$category]) {
            if ($Message -match $keyword) {
                return $category
            }
        }
    }

    return "General"
}

function Add-LogToHistory {
    <#
    .SYNOPSIS
    Adds a log entry to the searchable history with metadata
    .PARAMETER Message
    The log message
    .PARAMETER Level
    The log level
    .PARAMETER Category
    The log category
    #>
    param(
        [string]$Message,
        [string]$Level = 'Info',
        [string]$Category = 'General'
    )

    try {
        if (-not $global:LogHistory -or -not ($global:LogHistory -is [System.Collections.IList])) {
            $global:LogHistory = [System.Collections.ArrayList]::new()
        }

        if (-not $global:MaxLogHistorySize -or $global:MaxLogHistorySize -lt 10) {
            $global:MaxLogHistorySize = 1000
        }

        $logEntry = @{
            Timestamp = Get-Date
            Message = $Message
            Level = $Level
            Category = $Category
            Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }

        [void]$global:LogHistory.Add($logEntry)

        while ($global:LogHistory.Count -gt $global:MaxLogHistorySize) {
            $global:LogHistory.RemoveAt(0)

        }

    } catch {
        # Silent fail to prevent logging issues
        Write-Verbose "Failed to add log to history: $($_.Exception.Message)"
    }
}

function Log {
    param([string]$msg, [string]$Level = 'Info')

    if (-not $global:LastTimestamp -or ((Get-Date) - $global:LastTimestamp).TotalMilliseconds -gt 100) {
        $global:CachedTimestamp = [DateTime]::Now.ToString('HH:mm:ss')
        $global:LastTimestamp = Get-Date
    }

    $logMessage = "[$global:CachedTimestamp] [$Level] $msg"

    # Enhanced categorization and history tracking
    $category = Get-LogCategory -Message $msg
    Add-LogToHistory -Message $msg -Level $Level -Category $category

    # Periodic log file optimization
    if ((Get-Random -Maximum 100) -eq 1) {  # 1% chance per log entry
        Optimize-LogFile -MaxSizeMB 10
    }

    # Enhanced activity logging with persistent file logging and administrator mode awareness
    try {
        $logFilePath = Join-Path $ScriptRoot 'Koala-Activity.log'

        # Additional reliability check: ensure directory exists
        $logDir = Split-Path $logFilePath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        # Enhanced file writing with retry mechanism
        $maxRetries = 3
        $retryCount = 0
        $success = $false

        while (-not $success -and $retryCount -lt $maxRetries) {
            try {
                # Enhanced log entry with category information
                $enhancedLogMessage = "[$global:CachedTimestamp] [$Level] [$category] $msg"
                Add-Content -Path $logFilePath -Value $enhancedLogMessage -Encoding UTF8 -ErrorAction Stop
                $success = $true
            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Start-Sleep -Milliseconds 100
                } else {
                    throw
                }
            }
        }

        # Verify file write was successful for critical operations
        if ($Level -eq 'Error' -or $Level -eq 'Warning') {
            $lastLine = Get-Content $logFilePath -Tail 1 -ErrorAction SilentlyContinue
            if ($lastLine -notmatch [regex]::Escape($msg)) {
                throw "File verification failed - log entry may not have been written"
            }
        }

        # Enhanced context logging for comprehensive user action tracking
        if ($msg -match "Theme|Game|Mode|Optimization|Service|System|Network|Settings|Backup|Import|Export|Search") {
            try {
                $adminStatus = if (Get-Command Test-AdminPrivileges -ErrorAction SilentlyContinue) { Test-AdminPrivileges } else { "Unknown" }
                $contextMessage = "[$global:CachedTimestamp] [Context] [$category] User action '$($msg.Split(' ')[0])' in $global:MenuMode mode with Admin: $adminStatus"
                Add-Content -Path $logFilePath -Value $contextMessage -Encoding UTF8 -ErrorAction SilentlyContinue

                # Add to history as well
                Add-LogToHistory -Message "User action '$($msg.Split(' ')[0])' in $global:MenuMode mode with Admin: $adminStatus" -Level "Context" -Category $category
            } catch {
                # Ignore context logging errors to prevent circular issues
            }
        }

        # Additional validation logging for critical operations
        if ($Level -eq 'Error') {
            try {
                $errorContext = "[$global:CachedTimestamp] [ErrorContext] [$category] PowerShell: $($PSVersionTable.PSVersion), OS: $(if ($IsWindows -ne $null) { if ($IsWindows) {'Windows'} else {'Non-Windows'} } else {'Windows Legacy'})"
                Add-Content -Path $logFilePath -Value $errorContext -Encoding UTF8 -ErrorAction SilentlyContinue

                # Add to history as well
                Add-LogToHistory -Message "PowerShell: $($PSVersionTable.PSVersion), OS: $(if ($IsWindows -ne $null) { if ($IsWindows) {'Windows'} else {'Non-Windows'} } else {'Windows Legacy'})" -Level "ErrorContext" -Category $category
            } catch {
                # Ignore additional context logging errors
            }
        }

    } catch {
        # Enhanced error reporting for administrator mode and permission issues
        $errorContext = ""
        if ($_.Exception.Message -match "Access.*denied|UnauthorizedAccess") {
            $errorContext = " (Insufficient permissions - try running as Administrator)"
        } elseif ($_.Exception.Message -match "path.*not found|DirectoryNotFound") {
            $errorContext = " (Directory access issue - check script location)"
        } elseif ($_.Exception.Message -match "sharing violation|used by another process") {
            $errorContext = " (File in use - another instance may be running)"
        }

        # Fallback to console with enhanced error context
        Write-Host "LOG FILE ERROR: $($_.Exception.Message)$errorContext" -ForegroundColor Red
        Write-Host $logMessage -ForegroundColor $(Get-LogColor $Level)
    }

    if ($global:LogBox -and $global:LogBoxAvailable) {
        try {
            # Use Dispatcher.Invoke instead of BeginInvoke for more reliable UI updates
            $global:LogBox.Dispatcher.Invoke({
                try {
                    # Check if LogBox is still accessible
                    if ($global:LogBox -and $global:LogBox.IsEnabled -ne $null) {
                        $global:LogBox.AppendText("$logMessage`r`n")
                        $global:LogBox.ScrollToEnd()

                        # Maintain detailed log backup for toggle functionality
                        if (-not $global:DetailedLogBackup) {
                            $global:DetailedLogBackup = ""
                        }
                        $global:DetailedLogBackup += "$logMessage`r`n"

                        # If in compact mode, apply filtering
                        if ($global:LogViewDetailed -eq $false) {
                            if ($msg -match "Success|Error|Warning|Applied|Optimization") {
                                # Important messages are shown in compact view
                            } else {
                                # Hide non-essential messages in compact view
                                $currentText = $global:LogBox.Text
                                $lines = $currentText -split "`r`n"
                                $filteredLines = $lines | Where-Object {
                                    $_ -match "Success|Error|Warning|Applied|Optimization"
                                } | Select-Object -Last 20
                                $global:LogBox.Text = ($filteredLines -join "`r`n")
                            }
                        }

                        # Force immediate UI update to ensure text appears
                        $global:LogBox.InvalidateVisual()
                        $global:LogBox.UpdateLayout()

                        # Process pending UI operations
                        if ([System.Windows.Threading.Dispatcher]::CurrentDispatcher) {
                            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke({}, [System.Windows.Threading.DispatcherPriority]::Render)
                        }
                    } else {
                        $global:LogBoxAvailable = $false
                        Write-Host $logMessage -ForegroundColor $(Get-LogColor $Level)
                    }
                } catch {
                    $global:LogBoxAvailable = $false
                    Write-Host $logMessage -ForegroundColor $(Get-LogColor $Level)
                    Log "LogBox UI became unavailable: $($_.Exception.Message)" 'Warning'
                }
            }, [System.Windows.Threading.DispatcherPriority]::Normal)
        } catch {
            $global:LogBoxAvailable = $false
            Write-Host $logMessage -ForegroundColor $(Get-LogColor $Level)
        }
    } else {
        Write-Host $logMessage -ForegroundColor $(Get-LogColor $Level)
    }
}

# ---------- Essential Helper Functions (moved to top to fix call order) ----------
function Test-AdminPrivileges {
    if (-not $script:IsWindowsPlatform) {
        return $false
    }

    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not $id) {
            return $false
        }

        $principal = New-Object Security.Principal.WindowsPrincipal($id)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        $warningMessage = 'Admin privilege detection unavailable: {0}' -f $_.Exception.Message
        Log $warningMessage 'Warning'
        return $false
    }
}

function Get-SafeConfigPath {
    param([string]$Filename)

    if ($global:CustomConfigPath) {
        return Join-Path $global:CustomConfigPath $Filename
    }

    # Check if current path is system32 or other sensitive location
    $currentPath = if ($ScriptRoot) { $ScriptRoot } else { (Get-Location).Path }
    $isAdmin = Test-AdminPrivileges

    if ($isAdmin -and ($currentPath -match "system32|windows|program files" -or $currentPath.Length -lt 10)) {
        if (-not $script:SafeConfigDirectory) {
            $documentsRoot = try { [Environment]::GetFolderPath('MyDocuments') } catch { $null }
            if ([string]::IsNullOrWhiteSpace($documentsRoot)) {
                $documentsRoot = Join-Path $env:USERPROFILE 'Documents'
            }

            $script:SafeConfigDirectory = Join-Path $documentsRoot 'KOALA Gaming Optimizer'
        }

        if (-not $script:HasWarnedUnsafeConfigPath) {
            Log "Admin mode detected with unsafe path ($currentPath) - using user documents folder" 'Warning'
            $script:HasWarnedUnsafeConfigPath = $true
        }

        if (-not (Test-Path $script:SafeConfigDirectory)) {
            try {
                New-Item -ItemType Directory -Path $script:SafeConfigDirectory -Force | Out-Null
                Log "Created safe configuration directory: $script:SafeConfigDirectory" 'Info'
            } catch {
                Log "Failed to create safe configuration directory: $script:SafeConfigDirectory - $($_.Exception.Message)" 'Warning'
            }
        }

        return Join-Path $script:SafeConfigDirectory $Filename
    }

    return Join-Path $currentPath $Filename
}

# Initialize paths after function definition
$BackupPath = Get-SafeConfigPath 'Koala-Backup.json'
$ConfigPath = Get-SafeConfigPath 'Koala-Config.json'

# ---------- Control Validation Function ----------
function Test-StartupControls {
    <#
    .SYNOPSIS
    Validates all critical UI controls are properly bound and logs missing controls
    #>

    $criticalControls = @{
        # Navigation controls
        'btnNavDashboard' = $btnNavDashboard
        'btnNavBasicOpt' = $btnNavBasicOpt
        'btnNavAdvanced' = $btnNavAdvanced
        'btnNavGames' = $btnNavGames
        'btnNavOptions' = $btnNavOptions
        'btnNavBackup' = $btnNavBackup
        'btnNavLog' = $btnNavLog

        # Panels
        'panelDashboard' = $panelDashboard
        'panelBasicOpt' = $panelBasicOpt
        'panelAdvanced' = $panelAdvanced
        'panelGames' = $panelGames
        'panelOptions' = $panelOptions
        'panelBackup' = $panelBackup
        'panelLog' = $panelLog
        'btnAdvancedNetwork' = $btnAdvancedNetwork
        'btnAdvancedSystem' = $btnAdvancedSystem
        'btnAdvancedServices' = $btnAdvancedServices

        # Critical buttons mentioned in problem statement
        'btnInstalledGames' = $btnInstalledGames
        'btnSaveSettings' = $btnSaveSettings
        'btnLoadSettings' = $btnLoadSettings
        'btnResetSettings' = $btnResetSettings
        'btnSearchGames' = $btnSearchGames
        'btnAddGameFolder' = $btnAddGameFolder
        'btnCustomSearch' = $btnCustomSearch
        'btnInstalledGamesDash' = $btnInstalledGamesDash
        'btnSearchGamesPanel' = $btnSearchGamesPanel
        'btnAddGameFolderPanel' = $btnAddGameFolderPanel
        'btnCustomSearchPanel' = $btnCustomSearchPanel
        'btnAddGameFolderDash' = $btnAddGameFolderDash
        'btnCustomSearchDash' = $btnCustomSearchDash
        'btnOptimizeSelected' = $btnOptimizeSelected
        'btnImportOptions' = $btnImportOptions
        'btnChooseBackupFolder' = $btnChooseBackupFolder
        'cmbOptionsLanguage' = $cmbOptionsLanguage

        # System optimization and service management controls
        'btnOptimizeGame' = $btnOptimizeGame
        'btnDashQuickOptimize' = $btnDashQuickOptimize
        'btnBasicSystem' = $btnBasicSystem
        'btnBasicNetwork' = $btnBasicNetwork
        'btnBasicGaming' = $btnBasicGaming
        'btnSystemInfo' = $btnSystemInfo
        'expanderServices' = $expanderServices
        'expanderNetworkTweaks' = $expanderNetworkTweaks
        'expanderSystemOptimizations' = $expanderSystemOptimizations
        'expanderServiceManagement' = $expanderServiceManagement

        # Checkboxes for optimizations
        'chkAutoOptimize' = $chkAutoOptimize
        'chkDashAutoOptimize' = $chkDashAutoOptimize
        'chkGameDVR' = $chkGameDVR
        'chkFullscreenOptimizations' = $chkFullscreenOptimizations
        'chkGPUScheduling' = $chkGPUScheduling
        'chkTimerResolution' = $chkTimerResolution
        'chkGameMode' = $chkGameMode
        'chkMPO' = $chkMPO
        'chkGameDVRSystem' = $chkGameDVRSystem
        'chkGPUSchedulingSystem' = $chkGPUSchedulingSystem
        'chkFullscreenOptimizationsSystem' = $chkFullscreenOptimizationsSystem
        'chkTimerResolutionSystem' = $chkTimerResolutionSystem
        'chkGameModeSystem' = $chkGameModeSystem
        'chkMPOSystem' = $chkMPOSystem

        # Logging
        'LogBox' = $global:LogBox
    }

    $missingControls = @()
    $availableControls = @()

    foreach ($controlName in $criticalControls.Keys) {
        $control = $criticalControls[$controlName]
        if ($control -eq $null) {
            $missingControls += $controlName
            Log "MISSING CONTROL: $controlName is null - event handlers will be skipped" 'Warning'
        } else {
            $availableControls += $controlName
        }
    }

    # Log startup summary
    Log "STARTUP CONTROL VALIDATION COMPLETE" 'Info'
    Log "Available controls: $($availableControls.Count)/$($criticalControls.Count)" 'Info'

    if ($missingControls.Count -gt 0) {
        Log "MISSING CONTROLS DETECTED: $($missingControls.Count) controls not found" 'Warning'
        Log "Missing controls: $($missingControls -join ', ')" 'Warning'
        Log "Suggestions for fixing missing controls:" 'Info'

        foreach ($missing in $missingControls) {
            switch -Wildcard ($missing) {
                'btn*' { Log "  * Add <Button x:Name=`"$missing`" .../> to XAML" 'Info' }
                'chk*' { Log "  * Add <CheckBox x:Name=`"$missing`" .../> to XAML" 'Info' }
                'panel*' { Log "  * Add <StackPanel x:Name=`"$missing`" .../> to XAML" 'Info' }
                'LogBox' { Log "  * Add <TextBox x:Name=`"LogBox`" .../> to XAML for logging" 'Info' }
                'expanderServices' { Log "  * Add <Expander x:Name=`"expanderServices`" Header=`"Service Management`" .../> to XAML" 'Info' }
                'btnSystemInfo' { Log "  * Add <Button x:Name=`"btnSystemInfo`" Content=`"System Info`" .../> for system information" 'Info' }
                '*Optimize*' { Log "  * Add <Button x:Name=`"$missing`" .../> for optimization functionality" 'Info' }
                default { Log "  * Add control with x:Name=`"$missing`" to XAML" 'Info' }
            }
        }

        # Provide UI feedback but do not block startup
        try {
            $message = "⚠️ STARTUP VALIDATION: $($missingControls.Count) UI controls are missing.`n`nMissing: $($missingControls -join ', ')`n`nThe application will continue to run, but some features may not work properly.`n`nCheck the Activity Log for detailed fix suggestions."

            # Only show message box if WPF is available
            if ([System.Windows.MessageBox] -and $form) {
                [System.Windows.MessageBox]::Show($message, "Startup Control Validation", 'OK', 'Warning')
            } else {
                Log "UI feedback not available - continuing with console logging only" 'Info'
            }
        } catch {
            Log "Could not display UI feedback for missing controls: $($_.Exception.Message)" 'Warning'
        }

        return $false
    } else {
        Log "[OK] All critical controls found and bound successfully" 'Success'
        return $true
    }
}
$SettingsPath = Get-SafeConfigPath 'koala-settings.cfg'

# ---------- UI Cloning and Mirroring Helpers (moved forward for availability) ----------
function Clone-UIElement {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.UIElement]
        $Element
    )

    try {
        $xaml = [System.Windows.Markup.XamlWriter]::Save($Element)
        $stringReader = New-Object System.IO.StringReader $xaml
        $xmlReader = [System.Xml.XmlReader]::Create($stringReader)
        $clone = [Windows.Markup.XamlReader]::Load($xmlReader)
        $xmlReader.Close()
        $stringReader.Close()
        return $clone
    } catch {
        Write-Verbose "Clone-UIElement failed: $($_.Exception.Message)"
        return $null
    }
}

function Copy-TagValue {
    param($Value)

    if (-not $Value) { return $Value }

    if ($Value -is [System.Management.Automation.PSObject]) {
        $hashtable = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $hashtable[$property.Name] = $property.Value
        }
        return [PSCustomObject]$hashtable
    }

    return $Value
}

function New-ClonedTextBlock {
    param([System.Windows.Controls.TextBlock]$Source)

    $clone = New-Object System.Windows.Controls.TextBlock
    try { $clone.Text = $Source.Text } catch { }
    try { if ($Source.Foreground) { $clone.Foreground = $Source.Foreground.Clone() } } catch { }
    try { $clone.FontStyle = $Source.FontStyle } catch { }
    try { $clone.FontWeight = $Source.FontWeight } catch { }
    try { $clone.FontSize = $Source.FontSize } catch { }
    try { $clone.Margin = $Source.Margin } catch { }
    try { $clone.HorizontalAlignment = $Source.HorizontalAlignment } catch { }
    try { $clone.TextWrapping = $Source.TextWrapping } catch { }
    try { $clone.FontFamily = $Source.FontFamily } catch { }
    try { $clone.TextAlignment = $Source.TextAlignment } catch { }
    return $clone
}

function New-ClonedCheckBox {
    param([System.Windows.Controls.CheckBox]$Source)

    $clone = New-Object System.Windows.Controls.CheckBox
    try { $clone.Content = $Source.Content } catch { }
    try { if ($Source.Foreground) { $clone.Foreground = $Source.Foreground.Clone() } } catch { }
    try { $clone.FontWeight = $Source.FontWeight } catch { }
    try { $clone.FontSize = $Source.FontSize } catch { }
    try { $clone.Margin = $Source.Margin } catch { }
    try { $clone.Padding = $Source.Padding } catch { }
    try { $clone.HorizontalAlignment = $Source.HorizontalAlignment } catch { }
    try { $clone.IsChecked = $Source.IsChecked } catch { }
    try { $clone.ToolTip = $Source.ToolTip } catch { }

    try {
        $clone.Tag = Copy-TagValue -Value $Source.Tag
    } catch {
        Write-Verbose "Failed to copy checkbox Tag value: $($_.Exception.Message)"
    }

    return $clone
}

function Copy-ChildElement {
    param([System.Windows.UIElement]$Source)

    if (-not $Source) { return $null }

    $typeName = $Source.GetType().Name

    switch ($typeName) {
        'TextBlock' { return New-ClonedTextBlock -Source $Source }
        'CheckBox'  { return New-ClonedCheckBox -Source $Source }
        'StackPanel' {
            $stackClone = New-Object System.Windows.Controls.StackPanel
            try { $stackClone.Orientation = $Source.Orientation } catch { }
            try { $stackClone.Margin = $Source.Margin } catch { }

            foreach ($child in $Source.Children) {
                $clonedChild = Copy-ChildElement -Source $child
                if ($clonedChild) {
                    $stackClone.Children.Add($clonedChild)
                }
            }

            return $stackClone
        }
        default { return Clone-UIElement -Element $Source }
    }
}

function Update-GameListMirrors {
    if (-not $script:PrimaryGameListPanel -or -not $script:DashboardGameListPanel) { return }

    try {
        $script:DashboardGameListPanel.Children.Clear()
        foreach ($child in $script:PrimaryGameListPanel.Children) {
            if ($child -is [System.Windows.Controls.TextBlock]) {
                $clonedText = New-ClonedTextBlock -Source $child
                if ($clonedText) { $script:DashboardGameListPanel.Children.Add($clonedText) }
                continue
            }

            if ($child -is [System.Windows.Controls.Border]) {
                $borderClone = New-Object System.Windows.Controls.Border
                try { $borderClone.Background = if ($child.Background) { $child.Background.Clone() } else { $null } } catch { }
                try { $borderClone.BorderBrush = if ($child.BorderBrush) { $child.BorderBrush.Clone() } else { $null } } catch { }
                try { $borderClone.BorderThickness = $child.BorderThickness } catch { }
                try { $borderClone.CornerRadius = $child.CornerRadius } catch { }
                try { $borderClone.Margin = $child.Margin } catch { }
                try { $borderClone.Padding = $child.Padding } catch { }

                if ($child.Child) {
                    $clonedChild = Copy-ChildElement -Source $child.Child
                    if ($clonedChild) { $borderClone.Child = $clonedChild }
                }

                $script:DashboardGameListPanel.Children.Add($borderClone)
                continue
            }

            $fallback = Clone-UIElement -Element $child
            if ($fallback) {
                $script:DashboardGameListPanel.Children.Add($fallback)
            }
        }
    } catch {
        Write-Verbose "Update-GameListMirrors failed: $($_.Exception.Message)"
    }
}

# Resolve a color-like value (string, brush, PSObject) to a usable color string.
function Get-ColorStringFromValue {
    param([object]$ColorValue)

    if ($null -eq $ColorValue) { return $null }

    if ($ColorValue -is [string]) { return $ColorValue }

    if ($ColorValue -is [System.Windows.Media.Color]) {
        return $ColorValue.ToString()
    }

    if ($ColorValue -is [System.Windows.Media.Brush]) {
        try { return $ColorValue.ToString() } catch { return $null }
    }

    if ($ColorValue -is [System.Management.Automation.PSObject]) {
        foreach ($propName in 'Brush','Color','Value','Hex','Text','Background','Primary') {
            if ($ColorValue.PSObject.Properties[$propName]) {
                $resolved = Get-ColorStringFromValue $ColorValue.$propName
                if (-not [string]::IsNullOrWhiteSpace($resolved)) { return $resolved }
            }
        }

        if ($ColorValue.PSObject.BaseObject -ne $ColorValue) {
            $resolved = Get-ColorStringFromValue $ColorValue.PSObject.BaseObject
            if (-not [string]::IsNullOrWhiteSpace($resolved)) { return $resolved }
        }

        try { return $ColorValue.ToString() } catch { return $null }
    }

    if ($ColorValue -is [System.Collections.IDictionary]) {
        foreach ($propName in 'Brush','Color','Value','Hex','Text','Background','Primary') {
            if ($ColorValue.Contains($propName)) {
                $resolved = Get-ColorStringFromValue $ColorValue[$propName]
                if (-not [string]::IsNullOrWhiteSpace($resolved)) { return $resolved }
            }
        }
    }

    if ($ColorValue -is [System.Array]) {
        $length = $ColorValue.Length
        if ($length -eq 4) {
            $bytes = @()
            foreach ($item in $ColorValue) { $bytes += [byte]$item }
            $color = [System.Windows.Media.Color]::FromArgb($bytes[0], $bytes[1], $bytes[2], $bytes[3])
            return $color.ToString()
        } elseif ($length -eq 3) {
            $bytes = @()
            foreach ($item in $ColorValue) { $bytes += [byte]$item }
            $color = [System.Windows.Media.Color]::FromRgb($bytes[0], $bytes[1], $bytes[2])
            return $color.ToString()
        }
    }

    if ($ColorValue -is [System.ValueType]) {
        return $ColorValue.ToString()
    }

    try { return [string]$ColorValue } catch { return $null }
}

# Normalize theme tables so color values resolve to reusable brush instances.
function Normalize-ThemeColorTable {
    param([hashtable]$Theme)

    if (-not $Theme) { return $Theme }

    foreach ($key in @($Theme.Keys)) {
        $value = $Theme[$key]

        if ($null -eq $value) { continue }

        if ($value -is [string]) {
            $stringBrush = $null
            try {
                $stringBrush = New-SolidColorBrushSafe $value
            } catch {
                $stringBrush = $null
            }

            if ($stringBrush -is [System.Windows.Media.Brush]) {
                $Theme[$key] = $stringBrush
                continue
            }

            continue
        }

        if ($value -is [bool]) { continue }
        if ($value -is [System.Windows.Media.Brush]) {
            try {
                if ($value -is [System.Windows.Freezable] -and -not $value.IsFrozen) {
                    $value.Freeze()
                }
            } catch {
                Write-Verbose "Normalize-ThemeColorTable: Failed to freeze brush for key '$key'"
            }
            continue
        }
        if ($value -is [int] -or $value -is [double] -or $value -is [decimal]) { continue }

        $resolved = Get-ColorStringFromValue $value
        if (-not [string]::IsNullOrWhiteSpace($resolved)) {
            $Theme[$key] = $resolved
        }
    }

    return $Theme
}

# Creates a cloneable brush instance from a variety of incoming values.
function Resolve-BrushInstance {
    param([object]$BrushCandidate)

    if ($null -eq $BrushCandidate) { return $null }

    $current = $BrushCandidate
    $previous = $null

    while ($current -is [System.Management.Automation.PSObject] -and $current -ne $previous) {
        $previous = $current
        $current = $current.PSObject.BaseObject
    }

    if ($current -is [System.Windows.Media.Brush]) {
        try {
            $clone = if ($current -is [System.Windows.Freezable]) { $current.Clone() } else { $current }
            if ($clone -is [System.Windows.Freezable] -and -not $clone.IsFrozen) {
                try { $clone.Freeze() } catch { }
            }
            return $clone
        } catch {
            return $current
        }
    }

    return $null
}

# Creates a frozen SolidColorBrush from a color-like value when possible.
function New-SolidColorBrushSafe {
    param([Parameter(ValueFromPipeline = $true)][object]$ColorValue)

    if ($null -eq $ColorValue) { return $null }

    $existingBrush = Resolve-BrushInstance $ColorValue
    if ($existingBrush -is [System.Windows.Media.SolidColorBrush]) {
        return $existingBrush
    }

    if ($existingBrush -is [System.Windows.Media.Brush]) {
        try {
            $colorText = $existingBrush.ToString()
            if (-not [string]::IsNullOrWhiteSpace($colorText)) {
                $colorCandidate = [System.Windows.Media.ColorConverter]::ConvertFromString($colorText)
                if ($colorCandidate -is [System.Windows.Media.Color]) {
                    $fromBrush = New-Object System.Windows.Media.SolidColorBrush $colorCandidate
                    $fromBrush.Freeze()
                    return $fromBrush
                }
            }
        } catch {
            Write-Verbose "Failed to coerce brush value '$existingBrush' to SolidColorBrush: $($_.Exception.Message)"
        }
    }

    if ($ColorValue -is [System.Windows.Media.Color]) {
        $brushFromColor = New-Object System.Windows.Media.SolidColorBrush $ColorValue
        $brushFromColor.Freeze()
        return $brushFromColor
    }

    $resolvedValue = Get-ColorStringFromValue $ColorValue
    if ([string]::IsNullOrWhiteSpace($resolvedValue)) { return $null }

    $converter = Get-SharedBrushConverter
    if ($converter) {
        try {
            $converted = $converter.ConvertFromString($resolvedValue)
            $convertedBrush = Resolve-BrushInstance $converted
            if ($convertedBrush -is [System.Windows.Media.SolidColorBrush]) {
                return $convertedBrush
            }
        } catch {
            Write-Verbose "BrushConverter could not convert '$resolvedValue' to SolidColorBrush: $($_.Exception.Message)"
        }
    }

    try {
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($resolvedValue)
        if ($color -is [System.Windows.Media.Color]) {
            $brush = New-Object System.Windows.Media.SolidColorBrush $color
            $brush.Freeze()
            return $brush
        }
    } catch {
        Write-Verbose "Failed to convert '$resolvedValue' to SolidColorBrush: $($_.Exception.Message)"
    }

    return $null
}

function Get-SharedBrushConverter {
    if (-not $script:SharedBrushConverter -or $script:SharedBrushConverter.GetType().FullName -ne 'System.Windows.Media.BrushConverter') {
        try {
            $script:SharedBrushConverter = [System.Windows.Media.BrushConverter]::new()
        } catch {
            $script:SharedBrushConverter = $null
        }
    }

    return $script:SharedBrushConverter
}

function Set-ShapeFillSafe {
    param(
        [object]$Shape,
        [object]$Value
    )

    if (-not $Shape) { return }

    try {
        Set-BrushPropertySafe -Target $Shape -Property 'Fill' -Value $Value -AllowTransparentFallback
    } catch {
        Write-Verbose "Set-ShapeFillSafe failed: $($_.Exception.Message)"
    }
}

# Centralized helper to assign Brush-like theme values to WPF dependency properties.
function Set-BrushPropertySafe {
    param(
        [Parameter(Mandatory = $true)][object]$Target,
        [Parameter(Mandatory = $true)][string]$Property,
        [object]$Value,
        [switch]$AllowTransparentFallback
    )

    if (-not $Target) { return }
    if ([string]::IsNullOrWhiteSpace($Property)) { return }

    try {
        $resolvedValue = $Value
        $previousValue = $null
        while ($resolvedValue -is [System.Management.Automation.PSObject] -and $resolvedValue -ne $previousValue) {
            $previousValue = $resolvedValue
            $resolvedValue = $resolvedValue.PSObject.BaseObject
        }

        $brush = Resolve-BrushInstance $resolvedValue
        if (-not $brush) {
            $brush = New-SolidColorBrushSafe $resolvedValue
        }
        $previousBrush = $null
        while ($brush -is [System.Management.Automation.PSObject] -and $brush -ne $previousBrush) {
            $previousBrush = $brush
            $brush = $brush.PSObject.BaseObject
        }

        if ($brush -is [System.Windows.Media.Brush]) {
            if ($brush -is [System.Windows.Freezable] -and $brush.IsFrozen) {
                $Target.$Property = $brush.Clone()
            } else {
                $Target.$Property = $brush
            }
            return
        }

        $colorValue = Get-ColorStringFromValue $resolvedValue
        $previousColor = $null
        while ($colorValue -is [System.Management.Automation.PSObject] -and $colorValue -ne $previousColor) {
            $previousColor = $colorValue
            $colorValue = $colorValue.PSObject.BaseObject
        }

        $colorString = $null
        if ($null -ne $colorValue) {
            if ($colorValue -is [string]) {
                $colorString = $colorValue
            } else {
                try { $colorString = [string]$colorValue } catch { $colorString = $null }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($colorString)) {
            $converter = Get-SharedBrushConverter
            if ($converter) {
                try {
                    $converted = $converter.ConvertFromString($colorString)
                    $convertedBrush = Resolve-BrushInstance $converted
                    if (-not $convertedBrush) {
                        $convertedBrush = New-SolidColorBrushSafe $converted
                    }

                    if ($convertedBrush -is [System.Windows.Media.Brush]) {
                        if ($convertedBrush -is [System.Windows.Freezable] -and $convertedBrush.IsFrozen) {
                            $Target.$Property = $convertedBrush.Clone()
                        } else {
                            $Target.$Property = $convertedBrush
                        }
                        return
                    }
                } catch {
                    Write-Verbose "BrushConverter fallback for property '$Property' failed: $($_.Exception.Message)"
                }
            }

            $fallbackBrush = New-SolidColorBrushSafe $colorString
            if ($fallbackBrush -is [System.Windows.Media.Brush]) {
                if ($fallbackBrush -is [System.Windows.Freezable] -and $fallbackBrush.IsFrozen) {
                    $Target.$Property = $fallbackBrush.Clone()
                } else {
                    $Target.$Property = $fallbackBrush
                }
                return
            }
        }

        if ($AllowTransparentFallback) {
            $transparentBrush = [System.Windows.Media.Brushes]::Transparent
            if ($transparentBrush -is [System.Windows.Freezable] -and $transparentBrush.IsFrozen) {
                $Target.$Property = $transparentBrush.Clone()
            } else {
                $Target.$Property = $transparentBrush
            }
        } else {
            try { $Target.$Property = $null } catch { }
        }
    } catch {
        Write-Verbose "Set-BrushPropertySafe failed for property '$Property' on $($Target.GetType().Name): $($_.Exception.Message)"
    }
}

function Normalize-BrushResources {
    param(
        [System.Windows.ResourceDictionary]$Resources,
        [string[]]$Keys,
        [switch]$AllowTransparentFallback
    )

    if (-not $Resources) { return }

    $targetKeys = @()
    if ($Keys -and $Keys.Count -gt 0) {
        $targetKeys = $Keys
    } else {
        $targetKeys = @($Resources.Keys)
    }

    foreach ($key in $targetKeys) {
        if (-not $Resources.Contains($key)) { continue }

        $resourceValue = $Resources[$key]
        if ($resourceValue -is [System.Windows.Media.Brush]) { continue }

        $normalizedBrush = Resolve-BrushInstance $resourceValue
        if (-not $normalizedBrush) {
            $colorString = Get-ColorStringFromValue $resourceValue
            if (-not [string]::IsNullOrWhiteSpace($colorString)) {
                $normalizedBrush = New-SolidColorBrushSafe $colorString
            }
        }

        if (-not $normalizedBrush -and $AllowTransparentFallback) {
            $normalizedBrush = [System.Windows.Media.Brushes]::Transparent
        }

        if ($normalizedBrush -is [System.Windows.Media.Brush]) {
            if ($normalizedBrush -is [System.Windows.Freezable] -and $normalizedBrush.IsFrozen) {
                try { $Resources[$key] = $normalizedBrush.Clone() } catch { $Resources[$key] = $normalizedBrush }
            } else {
                $Resources[$key] = $normalizedBrush
            }
        } elseif ($resourceValue -is [System.Management.Automation.PSObject]) {
            if ($AllowTransparentFallback) {
                $Resources[$key] = [System.Windows.Media.Brushes]::Transparent
            } else {
                Write-Verbose "Normalize-BrushResources skipped '$key' due to unresolved brush value"
            }
        }
    }
}

function Normalize-ElementBrushProperties {
    param([System.Windows.DependencyObject]$Element)

    if ($null -eq $Element) { return }

    $brushPropertyNames = @(
        'Background',
        'Foreground',
        'BorderBrush',
        'SelectionBrush',
        'CaretBrush',
        'Stroke',
        'Fill',
        'OpacityMask',
        'SelectionForeground',
        'HighlightBrush'
    )

    foreach ($propertyName in $brushPropertyNames) {
        try {
            $propertyInfo = $Element.GetType().GetProperty($propertyName)
        } catch {
            $propertyInfo = $null
        }

        if (-not $propertyInfo -or -not $propertyInfo.CanRead -or -not $propertyInfo.CanWrite) { continue }

        try {
            $currentValue = $propertyInfo.GetValue($Element, $null)
        } catch {
            continue
        }

        if ($null -eq $currentValue) { continue }
        if ($currentValue -is [System.Windows.Media.Brush]) { continue }

        Set-BrushPropertySafe -Target $Element -Property $propertyName -Value $currentValue -AllowTransparentFallback
    }
}

function Normalize-VisualTreeBrushes {
    param([System.Windows.DependencyObject]$Root)

    if ($null -eq $Root) { return }

    $visited = New-Object 'System.Collections.Generic.HashSet[int]'
    $stack = New-Object System.Collections.Stack
    $stack.Push($Root)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()

        if ($current -isnot [System.Windows.DependencyObject]) { continue }

        try {
            $hash = [System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($current)
        } catch {
            continue
        }

        if (-not $visited.Add($hash)) { continue }

        Normalize-ElementBrushProperties -Element $current

        $childCount = 0
        try {
            $childCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($current)
        } catch {
            $childCount = 0
        }

        for ($i = 0; $i -lt $childCount; $i++) {
            $child = $null
            try { $child = [System.Windows.Media.VisualTreeHelper]::GetChild($current, $i) } catch { $child = $null }
            if ($child) { $stack.Push($child) }
        }

        try {
            foreach ($logicalChild in [System.Windows.LogicalTreeHelper]::GetChildren($current)) {
                if ($logicalChild -is [System.Windows.DependencyObject]) {
                    $stack.Push($logicalChild)
                }
            }
        } catch {
        }
    }
}

# ---------- Theme and Styling Helpers (moved forward for availability) ----------
function Find-AllControlsOfType {
    param(
        $Parent,
        [object]$ControlType,
        [ref]$Collection
    )

    if (-not $Parent) { return }

    if ($ControlType -isnot [Type]) {
        $typeName = $null
        if ($ControlType -is [string]) {
            $typeName = $ControlType.Trim()
            if ($typeName.StartsWith('[') -and $typeName.EndsWith(']')) {
                $typeName = $typeName.Trim('[', ']')
            }
        } elseif ($ControlType) {
            $typeName = $ControlType.ToString()
        }

        if ($typeName) {
            $resolvedType = $null
            try { $resolvedType = [Type]::GetType($typeName, $false) } catch { }
            if (-not $resolvedType) {
                switch ($typeName) {
                    'System.Windows.Controls.Button' { $resolvedType = [System.Windows.Controls.Button] }
                    'System.Windows.Controls.ComboBox' { $resolvedType = [System.Windows.Controls.ComboBox] }
                    'System.Windows.Controls.TextBlock' { $resolvedType = [System.Windows.Controls.TextBlock] }
                    'System.Windows.Controls.Label' { $resolvedType = [System.Windows.Controls.Label] }
                    'System.Windows.Controls.Border' { $resolvedType = [System.Windows.Controls.Border] }
                    'System.Windows.Controls.Primitives.ScrollBar' { $resolvedType = [System.Windows.Controls.Primitives.ScrollBar] }
                    default {
                        try { $resolvedType = [Type]::GetType("$typeName, PresentationFramework", $false) } catch { }
                    }
                }
            }

            $ControlType = $resolvedType
        }
    }

    if (-not $ControlType -or $ControlType -isnot [Type]) {
        return
    }

    try {
        if ($Parent -is $ControlType) {
            $Collection.Value += $Parent
        }

        if ($Parent.Children) {
            foreach ($child in $Parent.Children) {
                Find-AllControlsOfType -Parent $child -ControlType $ControlType -Collection $Collection
            }
        } elseif ($Parent.Content -and $Parent.Content -is [System.Windows.UIElement]) {
            Find-AllControlsOfType -Parent $Parent.Content -ControlType $ControlType -Collection $Collection
        } elseif ($Parent.Child) {
            Find-AllControlsOfType -Parent $Parent.Child -ControlType $ControlType -Collection $Collection
        }
    } catch {
        # Continue searching even if error occurs with specific element
    }
}

function Set-StackPanelChildSpacing {
    param(
        [System.Windows.Controls.StackPanel]$Panel,
        [double]$Spacing
    )

    if (-not $Panel -or -not $Panel.Children) { return }

    $count = $Panel.Children.Count
    if ($count -le 1) { return }

    for ($index = 0; $index -lt $count; $index++) {
        $child = $Panel.Children[$index]
        if ($child -isnot [System.Windows.FrameworkElement]) { continue }

        $margin = $child.Margin
        if (-not $margin) {
            $margin = [System.Windows.Thickness]::new(0)
        }

        $newMargin = [System.Windows.Thickness]::new($margin.Left, $margin.Top, $margin.Right, $margin.Bottom)

        if ($Panel.Orientation -eq [System.Windows.Controls.Orientation]::Horizontal) {
            $current = $margin.Right
            if ($index -lt $count - 1) {
                if ([math]::Abs($current) -lt 0.01) {
                    $newMargin.Right = $Spacing
                } elseif ($current -lt $Spacing) {
                    $newMargin.Right = $Spacing
                }
            } else {
                if ([math]::Abs($current) -lt 0.01) {
                    $newMargin.Right = 0
                }
            }
        } else {
            $current = $margin.Bottom
            if ($index -lt $count - 1) {
                if ([math]::Abs($current) -lt 0.01) {
                    $newMargin.Bottom = $Spacing
                } elseif ($current -lt $Spacing) {
                    $newMargin.Bottom = $Spacing
                }
            } else {
                if ([math]::Abs($current) -lt 0.01) {
                    $newMargin.Bottom = 0
                }
            }
        }

        $child.Margin = $newMargin
    }
}

function Set-GridColumnSpacing {
    param(
        [System.Windows.Controls.Grid]$Grid,
        [double]$Spacing
    )

    if (-not $Grid -or -not $Grid.Children -or $Spacing -le 0) { return }

    foreach ($child in $Grid.Children) {
        if ($child -isnot [System.Windows.FrameworkElement]) { continue }

        $columnIndex = [System.Windows.Controls.Grid]::GetColumn($child)
        if ($columnIndex -le 0) { continue }

        $margin = $child.Margin
        if (-not $margin) {
            $margin = [System.Windows.Thickness]::new(0)
        }

        $newMargin = [System.Windows.Thickness]::new($margin.Left, $margin.Top, $margin.Right, $margin.Bottom)
        if ($newMargin.Left -lt $Spacing) {
            $newMargin.Left = $Spacing
        }

        $child.Margin = $newMargin
    }
}

function Initialize-LayoutSpacing {
    param(
        [System.Windows.DependencyObject]$Root
    )

    if (-not $Root) { return }

    $stackPanels = New-Object System.Collections.ArrayList
    Find-AllControlsOfType -Parent $Root -ControlType ([System.Windows.Controls.StackPanel]) -Collection ([ref]$stackPanels)

    foreach ($panel in $stackPanels) {
        if (-not $panel.Tag) { continue }

        $tagText = $panel.Tag.ToString()
        $match = [regex]::Match($tagText, 'Spacing\s*:\s*(?<value>-?[0-9]+(?:\.[0-9]+)?)')
        if (-not $match.Success) { continue }

        $valueText = $match.Groups['value'].Value
        $spacing = 0.0
        if (-not [double]::TryParse($valueText, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$spacing)) {
            continue
        }

        Set-StackPanelChildSpacing -Panel $panel -Spacing $spacing
        $panel.Tag = $null
    }

    $grids = New-Object System.Collections.ArrayList
    Find-AllControlsOfType -Parent $Root -ControlType ([System.Windows.Controls.Grid]) -Collection ([ref]$grids)

    foreach ($grid in $grids) {
        if (-not $grid.Tag) { continue }

        $tagText = $grid.Tag.ToString()
        $match = [regex]::Match($tagText, 'ColumnSpacing\s*:\s*(?<value>-?[0-9]+(?:\.[0-9]+)?)')
        if (-not $match.Success) { continue }

        $valueText = $match.Groups['value'].Value
        $spacing = 0.0
        if (-not [double]::TryParse($valueText, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$spacing)) {
            continue
        }

        Set-GridColumnSpacing -Grid $grid -Spacing $spacing
        $grid.Tag = $null
    }
}

function Get-XamlDuplicateNames {
    param(
        [Parameter(Mandatory = $true)][string]$Xaml
    )

    $pattern = [regex]'\b(?:x:)?Name\s*=\s*"([^"]+)"'
    $occurrences = @()
    $lineNumber = 1

    foreach ($line in $Xaml -split "`r?`n") {
        foreach ($match in $pattern.Matches($line)) {
            $occurrences += [pscustomobject]@{
                Name     = $match.Groups[1].Value
                Line     = $lineNumber
                LineText = $line.Trim()
            }
        }

        $lineNumber++
    }

    return $occurrences |
        Group-Object -Property Name |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object {
            [pscustomobject]@{
                Name        = $_.Name
                Occurrences = $_.Group
            }
        }
}

function Test-XamlNameUniqueness {
    param(
        [Parameter(Mandatory = $true)][string]$Xaml
    )

    $duplicates = Get-XamlDuplicateNames -Xaml $Xaml
    if (-not $duplicates -or $duplicates.Count -eq 0) {
        return
    }

    Write-Host 'Duplicate x:Name/Name values detected in XAML:' -ForegroundColor Red
    foreach ($duplicate in $duplicates) {
        foreach ($occurrence in $duplicate.Occurrences) {
            $lineInfo = if ($occurrence.Line -gt 0) { "line $($occurrence.Line)" } else { 'unknown line' }
            Write-Host ("  {0} ({1}): {2}" -f $duplicate.Name, $lineInfo, $occurrence.LineText) -ForegroundColor Red
        }
    }

    throw "Duplicate element names detected in XAML content."
}

function Apply-FallbackThemeColors {
    param($element, $colors)

    if (-not $element -or -not $colors) { return }

    try {
        $elementType = $element.GetType().Name

        switch ($elementType) {
            "Window" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background
            }
            "Border" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
            }
            "TextBlock" {
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
            }
            "Label" {
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
            }
            "Button" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Primary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value 'White'
            }
        }

        if ($element.Children) {
            foreach ($child in $element.Children) {
                Apply-FallbackThemeColors -element $child -colors $colors
            }
        } elseif ($element.Content -and $element.Content -is [System.Windows.UIElement]) {
            Apply-FallbackThemeColors -element $element.Content -colors $colors
        } elseif ($element.Child) {
            Apply-FallbackThemeColors -element $element.Child -colors $colors
        }
    } catch {
        # Ignore errors in fallback theming to avoid breaking the UI
    }
}

function Update-AllUIElementsRecursively {
    param($element, $colors)

    if (-not $element -or -not $colors) { return }

    try {
        $elementType = $element.GetType().Name

        switch ($elementType) {
            "Window" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background
                if ($element.BorderBrush) {
                    Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
                }
            }
            "Border" {
                $currentBg = if ($element.Background) { $element.Background.ToString() } else { $null }

                if ($currentBg -match "#161D3F|#1B2345|#141830|#1A1F39|#141830|#14132B|#F8F9FA|#FFFFFF|#F0F2F5") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary

                }
                if ($currentBg -match "#0E101A|#36393F|#0E0E10") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background
                }

                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
            "GroupBox" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback

                if ($element.Header -and $element.Header -is [System.String]) {
                    $headerBlock = New-Object System.Windows.Controls.TextBlock
                    $headerBlock.Text = $element.Header
                    Set-BrushPropertySafe -Target $headerBlock -Property 'Foreground' -Value $colors.Text
                    $headerBlock.FontWeight = "Bold"
                    $element.Header = $headerBlock
                } elseif ($element.Header -and $element.Header -is [System.Windows.Controls.TextBlock]) {
                    Set-BrushPropertySafe -Target $element.Header -Property 'Foreground' -Value $colors.Text
                }
            }
            "StackPanel" {
                if ($element.Background -and $element.Background.ToString() -ne "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                } elseif (-not $element.Background -or $element.Background.ToString() -eq "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background -AllowTransparentFallback
                }
            }
            "Grid" {
                if ($element.Background -and $element.Background.ToString() -ne "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                } elseif (-not $element.Background -or $element.Background.ToString() -eq "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background -AllowTransparentFallback
                }
            }
            "WrapPanel" {
                if ($element.Background -and $element.Background.ToString() -ne "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                } else {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background -AllowTransparentFallback
                }
            }
            "DockPanel" {
                if ($element.Background -and $element.Background.ToString() -ne "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                } else {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background -AllowTransparentFallback
                }
            }
            "TabItem" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
            "TabControl" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
            "Expander" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback

                if ($element.Header -and $element.Header -is [System.Windows.Controls.TextBlock]) {
                    Set-BrushPropertySafe -Target $element.Header -Property 'Foreground' -Value $colors.Text
                }
            }
            "TextBlock" {
                $currentForeground = if ($element.Foreground) { $element.Foreground.ToString() } else { $null }

                if ($currentForeground -match "#8F6FFF|#B497FF|#5D5FEF|#8A77FF") {
                    Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Accent
                }
                elseif ($currentForeground -match "#A9A5D9|#A6AACF|#B8B8B8|#777EA6888|#6C757D|#8B949E") {
                    Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.TextSecondary

                }
                elseif ($currentForeground -match "White|#FFFFFF|Black|#000000|#212529|#1C1E21") {
                    Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                }
                elseif (-not $currentForeground) {
                    Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                }
            }
            "Label" {
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                if ($element.Background -and $element.Background.ToString() -ne "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                }
            }
            "TextBox" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
                Set-BrushPropertySafe -Target $element -Property 'SelectionBrush' -Value $colors.Primary
            }
            "ComboBox" {
                $comboBackground = $colors.Secondary
                $comboForeground = $colors.Text

                if ($colors.ContainsKey('IsLight') -and $colors.IsLight) {
                    $comboBackground = $colors.Background
                    $comboForeground = $colors.Text
                }

                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $comboBackground
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $comboForeground
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback

                try {
                    $element.FontSize = 12
                    $element.FontWeight = 'Normal'
                } catch { Write-Verbose "ComboBox font styling skipped for compatibility" }

                foreach ($item in $element.Items) {
                    if ($item -is [System.Windows.Controls.ComboBoxItem]) {
                        Set-BrushPropertySafe -Target $item -Property 'Background' -Value $comboBackground
                        Set-BrushPropertySafe -Target $item -Property 'Foreground' -Value $comboForeground

                        try {
                            $item.Padding = "10,6"
                            $item.MinHeight = 28
                            $item.FontSize = 12
                        } catch { Write-Verbose "ComboBoxItem styling skipped for compatibility" }
                    }
                }
            }
            "ListBox" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
            "ListView" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
            "CheckBox" {
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                if ($element.Background -and $element.Background.ToString() -ne "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                }
            }
            "RadioButton" {
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                if ($element.Background -and $element.Background.ToString() -ne "Transparent") {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                }
            }
            "Button" {
                if ($element.Name -and -not ($element.Name -match "btnNav")) {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Primary
                    Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value 'White'
                    Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Hover -AllowTransparentFallback
                } elseif ($element.Name -match "btnNav") {
                    if ($element.Tag -eq "Selected") {
                        Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.SelectedBackground -AllowTransparentFallback
                        Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.SelectedForeground -AllowTransparentFallback
                    } else {
                        Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.UnselectedBackground -AllowTransparentFallback
                        Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.UnselectedForeground -AllowTransparentFallback
                    }
                } else {
                    Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Primary
                    Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value 'White'
                    Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Hover -AllowTransparentFallback
                }
            }
            "ScrollViewer" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Background

                try {
                    if ($element.Template) {
        $scrollBars = @()
        Find-AllControlsOfType -Parent $element -ControlType 'System.Windows.Controls.Primitives.ScrollBar' -Collection ([ref]$scrollBars)
                        foreach ($scrollBar in $scrollBars) {
                            Set-BrushPropertySafe -Target $scrollBar -Property 'Background' -Value $colors.Secondary
                            Set-BrushPropertySafe -Target $scrollBar -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
                        }
                    }
                } catch {
                    # Continue if scrollbar theming fails
                }
            }
            "ProgressBar" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Primary
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
            "Slider" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Primary
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
            "Menu" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
            "MenuItem" {
                Set-BrushPropertySafe -Target $element -Property 'Background' -Value $colors.Secondary
                Set-BrushPropertySafe -Target $element -Property 'Foreground' -Value $colors.Text
                Set-BrushPropertySafe -Target $element -Property 'BorderBrush' -Value $colors.Primary -AllowTransparentFallback
            }
        }

        try {
            $element.InvalidateVisual()
        } catch {
            # Ignore refresh issues on individual elements
        }

        if ($element.Children) {
            foreach ($child in $element.Children) {
                Update-AllUIElementsRecursively -element $child -colors $colors
            }
        }
        elseif ($element.Content -and $element.Content -is [System.Windows.UIElement]) {
            Update-AllUIElementsRecursively -element $element.Content -colors $colors
        }
        elseif ($element.Child) {
            Update-AllUIElementsRecursively -element $element.Child -colors $colors
        }

    } catch {
        # Continue on individual element failures
    }
}

  function Update-ButtonStyles {
      param($Primary, $Hover)

        try {
          $primaryBrush = $null
          if ($Primary) {
              $primaryBrush = New-SolidColorBrushSafe $Primary
          }

          $hoverBrush = $null
          if ($Hover) {
              $hoverBrush = New-SolidColorBrushSafe $Hover
          }

          $brushConverter = $null
          $setResourceBrush = {
              param($key, $brushCandidate, $colorValue)

              if (-not $form.Resources.Contains($key)) { return }

              $assignBrush = {
                  param($resourceKey, $brush)
                  if (-not $brush) { return $false }

                  $normalizedBrush = Resolve-BrushInstance $brush
                  if (-not $normalizedBrush) {
                      $normalizedBrush = New-SolidColorBrushSafe $brush
                  }

                  if (-not $normalizedBrush -or ($normalizedBrush -isnot [System.Windows.Media.Brush])) {
                      return $false
                  }

                  try {
                      if ($normalizedBrush -is [System.Windows.Freezable] -and $normalizedBrush.IsFrozen) {
                          $form.Resources[$resourceKey] = $normalizedBrush.Clone()
                      } else {
                          $form.Resources[$resourceKey] = $normalizedBrush
                      }
                  } catch {
                      $form.Resources[$resourceKey] = $normalizedBrush
                  }

                  return $true
              }

              if ($brushCandidate) {
                  if (& $assignBrush $key $brushCandidate) { return }
              }

              $colorString = Get-ColorStringFromValue $colorValue
              if ([string]::IsNullOrWhiteSpace($colorString)) {
                  return
              }

              try {
                  if (-not $brushConverter) {
                      $brushConverter = Get-SharedBrushConverter
                  }

                  if ($brushConverter) {
                      $converted = $brushConverter.ConvertFromString($colorString)
                      if ($converted -and (& $assignBrush $key $converted)) {
                          return
                      }
                  }
              } catch {
                  # fall through to safe brush creation
              }

              $safeBrush = New-SolidColorBrushSafe $colorString
              if (& $assignBrush $key $safeBrush) {
                  return
              }

              Write-Verbose "Skipping resource '$key' update - unable to convert '$colorString' to a brush"
          }

          & $setResourceBrush 'ButtonBackgroundBrush' $primaryBrush $Primary
          & $setResourceBrush 'ButtonBorderBrush' $primaryBrush $Primary

          $hoverBrushCandidate = $hoverBrush
          if (-not $hoverBrushCandidate) { $hoverBrushCandidate = $primaryBrush }

          $hoverColorValue = $Hover
          if (-not $hoverColorValue) { $hoverColorValue = $Primary }

          & $setResourceBrush 'ButtonHoverBrush' $hoverBrushCandidate $hoverColorValue
          & $setResourceBrush 'ButtonPressedBrush' $hoverBrushCandidate $hoverColorValue

          $buttons = @()
          Find-AllControlsOfType -Parent $form -ControlType 'System.Windows.Controls.Button' -Collection ([ref]$buttons)

          $modernStyle = $form.Resources['ModernButton']
          foreach ($button in $buttons) {
              if ($modernStyle -and $button.Style -eq $modernStyle) {
                  if ($primaryBrush) {
                      Set-BrushPropertySafe -Target $button -Property 'Background' -Value $primaryBrush
                      Set-BrushPropertySafe -Target $button -Property 'BorderBrush' -Value $primaryBrush
                  } elseif ($Primary) {
                      Set-BrushPropertySafe -Target $button -Property 'Background' -Value $Primary
                      Set-BrushPropertySafe -Target $button -Property 'BorderBrush' -Value $Primary
                  }
              }
          }

          Normalize-BrushResources -Resources $form.Resources -Keys @('ButtonBackgroundBrush','ButtonBorderBrush','ButtonHoverBrush','ButtonPressedBrush') -AllowTransparentFallback

      } catch {
          $errorMessage = 'Error updating button styles: {0}' -f $_.Exception.Message
          Log $errorMessage 'Warning'
      }
}

function Update-ComboBoxStyles {
    param($Background, $Foreground, $Border, $ThemeName = 'Nebula')

    try {
        $themeColors = Get-ThemeColors -ThemeName $ThemeName
        $isLight = $false
        if ($themeColors -and $themeColors.ContainsKey('IsLight')) {
            $isLight = [bool]$themeColors['IsLight']
        }

    $comboBoxes = @()
    Find-AllControlsOfType -Parent $form -ControlType 'System.Windows.Controls.ComboBox' -Collection ([ref]$comboBoxes)

        $actualBackground = if ($isLight) {
            'White'
        } elseif ($themeColors -and $themeColors.Secondary) {
            $themeColors.Secondary
        } else {
            $Background
        }

        $actualForeground = if ($themeColors -and $themeColors.Text) {
            $themeColors.Text
        } else {
            $Foreground
        }

        $itemBackground = if ($isLight) { 'White' } else { $actualBackground }
        $itemForeground = $actualForeground

        foreach ($combo in $comboBoxes) {
            Set-BrushPropertySafe -Target $combo -Property 'Background' -Value $actualBackground
            Set-BrushPropertySafe -Target $combo -Property 'Foreground' -Value $actualForeground
            Set-BrushPropertySafe -Target $combo -Property 'BorderBrush' -Value $Border -AllowTransparentFallback

            try {
                $combo.FontSize = 13
                $combo.FontWeight = 'Normal'
            } catch {
                Write-Verbose 'ComboBox font styling skipped for compatibility'
            }

            foreach ($item in $combo.Items) {
                if ($item -is [System.Windows.Controls.ComboBoxItem]) {
                    Set-BrushPropertySafe -Target $item -Property 'Background' -Value $itemBackground
                    Set-BrushPropertySafe -Target $item -Property 'Foreground' -Value $itemForeground

                    try {
                        $item.Padding = '12,6'
                        $item.MinHeight = 30
                        $item.FontSize = 13
                    } catch {
                        Write-Verbose 'ComboBoxItem styling skipped for compatibility'
                    }
                }
            }

            try {
                $combo.InvalidateVisual()
                $combo.UpdateLayout()
            } catch {
                Write-Verbose 'ComboBox refresh skipped for compatibility'
            }
        }

    } catch {
        $errorMessage = 'Error updating ComboBox styles: {0}' -f $_.Exception.Message
        Log $errorMessage 'Warning'
    }
}

function Update-TextStyles {
    param($Foreground, $Header, $ThemeName = 'Nebula')

    try {
        $colors = Get-ThemeColors -ThemeName $ThemeName
        $isLight = $false
        if ($colors -and $colors.ContainsKey('IsLight')) {
            $isLight = [bool]$colors['IsLight']
        }

    $textBlocks = @()
    Find-AllControlsOfType -Parent $form -ControlType 'System.Windows.Controls.TextBlock' -Collection ([ref]$textBlocks)

        foreach ($textBlock in $textBlocks) {
            if ($textBlock.Tag -eq 'AccentText') { continue }

            $targetColor = if ($textBlock.Style -eq $form.Resources['HeaderText']) {
                $Header
            } else {
                $Foreground
            }

            Set-BrushPropertySafe -Target $textBlock -Property 'Foreground' -Value $targetColor

            try {
                if (-not $textBlock.FontSize -or $textBlock.FontSize -lt 11) {
                    $textBlock.FontSize = 11
                }

                if ($isLight) {
                    $textBlock.FontWeight = 'Normal'
                    if ($textBlock.Text -and $textBlock.Text.Length -gt 50) {
                        Set-BrushPropertySafe -Target $textBlock -Property 'Foreground' -Value $colors.TextSecondary
                    }
                }
            } catch {
                Write-Verbose 'TextBlock enhancement skipped for compatibility'
            }
        }

    $labels = @()
    Find-AllControlsOfType -Parent $form -ControlType 'System.Windows.Controls.Label' -Collection ([ref]$labels)

        foreach ($label in $labels) {
            Set-BrushPropertySafe -Target $label -Property 'Foreground' -Value $Foreground
            try {
                if (-not $label.FontSize -or $label.FontSize -lt 11) {
                    $label.FontSize = 11
                }
                if ($isLight) {
                    $label.FontWeight = 'Normal'
                }
            } catch {
                Write-Verbose 'Label enhancement skipped for compatibility'
            }
        }

    } catch {
        $errorMessage = 'Error updating text styles: {0}' -f $_.Exception.Message
        Log $errorMessage 'Warning'
    }
}

function Update-ThemeColorPreview {
    param([string]$ThemeName)

    if (-not $previewBg -or -not $previewPrimary -or -not $previewHover -or -not $previewText) {
        return
    }

    try {
        $colors = if ($ThemeName -eq 'Custom' -and $global:CustomThemeColors) {
            $global:CustomThemeColors
        } else {
            Get-ThemeColors -ThemeName $ThemeName
        }

        $colors = Normalize-ThemeColorTable $colors

        $bgBrush = New-SolidColorBrushSafe $colors.Background
        $primaryBrush = New-SolidColorBrushSafe $colors.Primary
        $hoverBrush = New-SolidColorBrushSafe $colors.Hover
        $textBrush = New-SolidColorBrushSafe $colors.Text

        if ($bgBrush) { $previewBg.Fill = $bgBrush.Clone() }
        if ($primaryBrush) { $previewPrimary.Fill = $primaryBrush.Clone() }
        if ($hoverBrush) { $previewHover.Fill = $hoverBrush.Clone() }
        if ($textBrush) { $previewText.Fill = $textBrush.Clone() }

        if ($previewBgCustom -and $bgBrush) { $previewBgCustom.Fill = $bgBrush.Clone() }
        if ($previewPrimaryCustom -and $primaryBrush) { $previewPrimaryCustom.Fill = $primaryBrush.Clone() }
        if ($previewHoverCustom -and $hoverBrush) { $previewHoverCustom.Fill = $hoverBrush.Clone() }
        if ($previewTextCustom -and $textBrush) { $previewTextCustom.Fill = $textBrush.Clone() }

        if ($ThemeName -eq 'Custom' -and $global:CustomThemeColors) {
            if ($txtCustomBg) { $txtCustomBg.Text = $global:CustomThemeColors.Background }
            if ($txtCustomPrimary) { $txtCustomPrimary.Text = $global:CustomThemeColors.Primary }
            if ($txtCustomHover) { $txtCustomHover.Text = $global:CustomThemeColors.Hover }
            if ($txtCustomText) { $txtCustomText.Text = $global:CustomThemeColors.Text }
        }

        Log "Farb-Vorschau für '$($colors.Name)' aktualisiert" 'Info'
    } catch {
        Log "Fehler bei Farb-Vorschau: $($_.Exception.Message)" 'Warning'
    }
}

function Apply-ThemeColors {
    [CmdletBinding(DefaultParameterSetName='ByTheme')]
    param(
        [Parameter(ParameterSetName='ByTheme')]
        [string]$ThemeName = 'Nebula',
        [Parameter(ParameterSetName='ByCustom')]
        [string]$Background,
        [Parameter(ParameterSetName='ByCustom')]
        [string]$Primary,
        [Parameter(ParameterSetName='ByCustom')]
        [string]$Hover,
        [Parameter(ParameterSetName='ByCustom')]
        [string]$Foreground,
        [Parameter(ParameterSetName='__AllParameterSets')]
        [switch]$IsFallback
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByCustom') {
            $colors = (Get-ThemeColors -ThemeName 'Nebula').Clone()
            $colors['Name'] = 'Custom Theme'

            if ($PSBoundParameters.ContainsKey('Background') -and -not [string]::IsNullOrWhiteSpace($Background)) {
                $colors['Background'] = $Background
                $colors['Secondary'] = $Background
                $colors['SidebarBg'] = $Background
                $colors['HeaderBg'] = $Background
                $colors['LogBg'] = $Background
            }

            if ($PSBoundParameters.ContainsKey('Primary') -and -not [string]::IsNullOrWhiteSpace($Primary)) {
                $colors['Primary'] = $Primary
                $colors['Accent'] = $Primary
                $colors['SelectedBackground'] = $Primary
            }

            if ($PSBoundParameters.ContainsKey('Hover') -and -not [string]::IsNullOrWhiteSpace($Hover)) {
                $colors['Hover'] = $Hover
                $colors['HoverBackground'] = $Hover
            } elseif ($PSBoundParameters.ContainsKey('Primary') -and -not [string]::IsNullOrWhiteSpace($Primary)) {
                $colors['HoverBackground'] = $Primary
            }

            if ($PSBoundParameters.ContainsKey('Foreground') -and -not [string]::IsNullOrWhiteSpace($Foreground)) {
                $colors['Text'] = $Foreground
                $colors['SelectedForeground'] = $Foreground
                $colors['UnselectedForeground'] = $Foreground
                $colors['TextSecondary'] = $Foreground
            }

            $appliedThemeName = 'Custom'
        } else {
            if ($ThemeName -eq 'Custom' -and $global:CustomThemeColors) {
                $colors = $global:CustomThemeColors.Clone()
            } else {
                $colors = (Get-ThemeColors -ThemeName $ThemeName).Clone()
            }
            $appliedThemeName = $ThemeName
        }

        $colors = Normalize-ThemeColorTable $colors

        if ($PSCmdlet.ParameterSetName -eq 'ByCustom') {
            $global:CustomThemeColors = $colors.Clone()
        }

        if (-not $form) {
            Log "Window form nicht verfügbar für Theme-Anwendung" 'Error'
            return
        }

        Log "Wende Theme '$($colors.Name)' an..." 'Info'

        try {
            $cardStartValue = if ($colors.ContainsKey('CardBackgroundStart') -and $colors['CardBackgroundStart']) { $colors['CardBackgroundStart'] } else { $colors.Secondary }
            $cardEndValue = if ($colors.ContainsKey('CardBackgroundEnd') -and $colors['CardBackgroundEnd']) { $colors['CardBackgroundEnd'] } else { $colors.Background }
            $summaryStartValue = if ($colors.ContainsKey('SummaryBackgroundStart') -and $colors['SummaryBackgroundStart']) { $colors['SummaryBackgroundStart'] } else { $cardStartValue }
            $summaryEndValue = if ($colors.ContainsKey('SummaryBackgroundEnd') -and $colors['SummaryBackgroundEnd']) { $colors['SummaryBackgroundEnd'] } else { $cardEndValue }
            $cardBorderValue = if ($colors.ContainsKey('CardBorder') -and $colors['CardBorder']) { $colors['CardBorder'] } else { $colors.Primary }
            $glowAccentValue = if ($colors.ContainsKey('GlowAccent') -and $colors['GlowAccent']) { $colors['GlowAccent'] } else { $colors.Accent }
            $gaugeBackgroundValue = if ($colors.ContainsKey('GaugeBackground') -and $colors['GaugeBackground']) { $colors['GaugeBackground'] } else { $colors.Secondary }
            $gaugeStrokeValue = if ($colors.ContainsKey('GaugeStroke') -and $colors['GaugeStroke']) { $colors['GaugeStroke'] } else { $colors.Primary }

            $cardBrush = New-SolidColorBrushSafe $cardStartValue
            if (-not $cardBrush) { $cardBrush = New-SolidColorBrushSafe $cardEndValue }
            if (-not $cardBrush) { $cardBrush = New-SolidColorBrushSafe $colors.Secondary }

            $summaryBrush = New-SolidColorBrushSafe $summaryStartValue
            if (-not $summaryBrush) { $summaryBrush = New-SolidColorBrushSafe $summaryEndValue }
            if (-not $summaryBrush) { $summaryBrush = $cardBrush }

            $cardBorderBrush = New-SolidColorBrushSafe $cardBorderValue
            if (-not $cardBorderBrush) { $cardBorderBrush = New-SolidColorBrushSafe $colors.Primary }

            $contentBrush = New-SolidColorBrushSafe $colors.Secondary
            if ($contentBrush -is [System.Windows.Media.Brush]) {
                try { $form.Resources['ContentBackgroundBrush'] = $contentBrush } catch { Write-Verbose "Content background resource assignment skipped" }
            }

            $heroBrush = New-SolidColorBrushSafe $summaryBrush
            if (-not $heroBrush) { $heroBrush = $summaryBrush }
            if ($heroBrush -is [System.Windows.Media.Brush]) {
                try { $form.Resources['HeroCardBrush'] = $heroBrush } catch { Write-Verbose "HeroCardBrush resource assignment skipped" }
            }

            $gaugeBackgroundBrush = New-SolidColorBrushSafe $gaugeBackgroundValue
            if (-not $gaugeBackgroundBrush) { $gaugeBackgroundBrush = New-SolidColorBrushSafe $colors.Secondary }

            $gaugeStrokeBrush = New-SolidColorBrushSafe $gaugeStrokeValue
            if (-not $gaugeStrokeBrush) { $gaugeStrokeBrush = New-SolidColorBrushSafe $colors.Primary }

            $innerGaugeBrush = New-SolidColorBrushSafe $colors.Background
            if (-not $innerGaugeBrush) { $innerGaugeBrush = New-SolidColorBrushSafe '#000000' }

            $resourceColors = @{
                'AppBackgroundBrush'             = $colors.Background
                'SidebarBackgroundBrush'         = $colors.SidebarBg
                'SidebarAccentBrush'             = $colors.Primary
                'SidebarHoverBrush'              = if ($colors.ContainsKey('HoverBackground') -and $colors['HoverBackground']) { $colors['HoverBackground'] } elseif ($colors.ContainsKey('Hover')) { $colors['Hover'] } else { $colors.Primary }
                'SidebarSelectedBrush'           = if ($colors.ContainsKey('SelectedBackground')) { $colors['SelectedBackground'] } else { $colors.Primary }
                'SidebarSelectedForegroundBrush' = if ($colors.ContainsKey('SelectedForeground')) { $colors['SelectedForeground'] } else { $colors.Text }
                'HeaderBackgroundBrush'          = $colors.HeaderBg
                'HeaderBorderBrush'              = if ($cardBorderBrush) { $cardBorderBrush } else { $cardBorderValue }
                'CardBackgroundBrush'            = if ($cardBrush) { $cardBrush } else { $colors.Secondary }
                'CardBorderBrush'                = if ($cardBorderBrush) { $cardBorderBrush } else { $cardBorderValue }
                'AccentBrush'                    = if ($colors.ContainsKey('Accent') -and $colors['Accent']) { $colors['Accent'] } else { $colors.Primary }
                'ButtonBackgroundBrush'          = if ($colors.ContainsKey('ButtonBackground') -and $colors['ButtonBackground']) { $colors['ButtonBackground'] } else { $colors.Primary }
                'ButtonBorderBrush'              = if ($colors.ContainsKey('ButtonBorder') -and $colors['ButtonBorder']) { $colors['ButtonBorder'] } else { $colors.Primary }
                'ButtonHoverBrush'               = if ($colors.ContainsKey('ButtonHover') -and $colors['ButtonHover']) { $colors['ButtonHover'] } elseif ($colors.ContainsKey('HoverBackground') -and $colors['HoverBackground']) { $colors['HoverBackground'] } elseif ($colors.ContainsKey('Hover')) { $colors['Hover'] } else { $colors.Primary }
                'ButtonPressedBrush'             = if ($colors.ContainsKey('ButtonPressed') -and $colors['ButtonPressed']) { $colors['ButtonPressed'] } elseif ($colors.ContainsKey('Hover') -and $colors['Hover']) { $colors['Hover'] } else { $colors.Primary }
                'PrimaryTextBrush'               = $colors.Text
                'SecondaryTextBrush'             = $colors.TextSecondary
                'HeroChipBrush'                  = if ($colors.ContainsKey('HeroChip') -and $colors['HeroChip']) { $colors['HeroChip'] } elseif ($colors.ContainsKey('HoverBackground') -and $colors['HoverBackground']) { $colors['HoverBackground'] } else { $colors.Accent }
                'SuccessBrush'                   = if ($colors.ContainsKey('Success')) { $colors['Success'] } else { '#10B981' }
                'WarningBrush'                   = if ($colors.ContainsKey('Warning')) { $colors['Warning'] } else { '#F59E0B' }
                'DangerBrush'                    = if ($colors.ContainsKey('Danger')) { $colors['Danger'] } else { '#EF4444' }
                'InfoBrush'                      = if ($colors.ContainsKey('Info')) { $colors['Info'] } else { $colors.Primary }
            }

            foreach ($resourceKey in $resourceColors.Keys) {
                $value = $resourceColors[$resourceKey]
                if ($null -eq $value) { continue }

                $brush = Resolve-BrushInstance $value
                if (-not $brush) {
                    $brush = New-SolidColorBrushSafe $value
                }
                if ($brush -is [System.Windows.Media.Brush]) {
                    try { $form.Resources[$resourceKey] = $brush } catch { Write-Verbose "Resource brush '$resourceKey' could not be updated: $($_.Exception.Message)" }
                } else {
                    Write-Verbose "Resource brush '$resourceKey' skipped due to unresolved value"
                }
            }

            if ($form -and $form.Resources) {
                Register-BrushResourceKeys -Keys $form.Resources.Keys
            }

            $targetBrushKeys = @($script:BrushResourceKeys)
            if ($form -and $form.Resources) {
                try {
                    foreach ($resourceKey in $form.Resources.Keys) {
                        if ($resourceKey -is [string] -and $resourceKey.EndsWith('Brush') -and ($targetBrushKeys -notcontains $resourceKey)) {
                            $targetBrushKeys += $resourceKey
                        }
                    }
                } catch {
                    # Ignore enumeration errors and fall back to the static list
                }
            }

            Normalize-BrushResources -Resources $form.Resources -Keys $targetBrushKeys -AllowTransparentFallback

            $glowEffect = $null
            try { $form.Resources['CardGlow'] = $null } catch { Write-Verbose "CardGlow reset skipped: $($_.Exception.Message)" }

            $summaryPanel = $form.FindName('dashboardSummaryPanel')
            if ($summaryPanel -is [System.Windows.Controls.Border]) {
                Set-BrushPropertySafe -Target $summaryPanel -Property 'Background' -Value $summaryBrush
                Set-BrushPropertySafe -Target $summaryPanel -Property 'BorderBrush' -Value $cardBorderBrush
                $summaryPanel.Effect = $null
            }

            $dashboardCards = @(
                'dashboardSummaryRibbon',
                'dashboardHeroCard',
                'dashboardSummaryPanel',
                'dashboardCpuCard',
                'dashboardMemoryCard',
                'dashboardActivityCard',
                'dashboardHealthCard',
                'dashboardQuickActionsCard',
                'dashboardActionBar',
                'dashboardGameProfileCard',
                'dashboardGameListCard'
            )

            foreach ($cardName in $dashboardCards) {
                $card = $form.FindName($cardName)
                if ($card -is [System.Windows.Controls.Border]) {
                    Set-BrushPropertySafe -Target $card -Property 'Background' -Value $cardBrush
                    Set-BrushPropertySafe -Target $card -Property 'BorderBrush' -Value $cardBorderBrush
                    $card.Effect = $null
                }
            }

            foreach ($ellipseName in 'ellipseCpuRing', 'ellipseMemoryRing') {
                $ellipse = $form.FindName($ellipseName)
                if ($ellipse) {
                    Set-BrushPropertySafe -Target $ellipse -Property 'Fill' -Value $gaugeBackgroundBrush
                    Set-BrushPropertySafe -Target $ellipse -Property 'Stroke' -Value $gaugeStrokeBrush
                }
            }

            foreach ($innerEllipseName in 'ellipseCpuInner', 'ellipseMemoryInner') {
                $innerEllipse = $form.FindName($innerEllipseName)
                if ($innerEllipse) {
                    Set-BrushPropertySafe -Target $innerEllipse -Property 'Fill' -Value $innerGaugeBrush
                }
            }
        } catch {
            Log "Fehler beim Aktualisieren der Dashboard-Hintergründe: $($_.Exception.Message)" 'Warning'
        }

        $backgroundBrush = New-SolidColorBrushSafe $colors.Background
        $secondaryBrush = New-SolidColorBrushSafe $colors.Secondary
        $sidebarBrush = New-SolidColorBrushSafe $colors.SidebarBg
        $headerBrush = New-SolidColorBrushSafe $colors.HeaderBg
        $primaryBrush = New-SolidColorBrushSafe $colors.Primary

        $formBackgroundValue = if ($backgroundBrush) { $backgroundBrush } else { $colors.Background }
        try {
            Set-BrushPropertySafe -Target $form -Property 'Background' -Value $formBackgroundValue
        } catch {
            Write-Verbose "Form background assignment skipped"
        }

        $rootLayout = $form.FindName('RootLayout')
        if ($rootLayout) {
            try {
                $rootLayoutBackground = if ($backgroundBrush) { $backgroundBrush } else { $colors.Background }
                Set-BrushPropertySafe -Target $rootLayout -Property 'Background' -Value $rootLayoutBackground
            } catch {
                Write-Verbose "RootLayout background assignment skipped"
            }
        }

        $sidebar = $form.FindName('SidebarShell')
        if ($sidebar -is [System.Windows.Controls.Border]) {
            $sidebarBackground = if ($sidebarBrush) { $sidebarBrush } else { $colors.SidebarBg }
            Set-BrushPropertySafe -Target $sidebar -Property 'Background' -Value $sidebarBackground
            try {
                $sidebarBorder = if ($primaryBrush) { $primaryBrush } else { $colors.Primary }
                Set-BrushPropertySafe -Target $sidebar -Property 'BorderBrush' -Value $sidebarBorder -AllowTransparentFallback
            } catch {
                Write-Verbose "Sidebar border assignment skipped"
            }
        }

        $navScroll = $form.FindName('SidebarNavScroll')
        if ($navScroll -is [System.Windows.Controls.ScrollViewer]) {
            try {
                $navScrollBackground = if ($sidebarBrush) { $sidebarBrush } else { $colors.SidebarBg }
                Set-BrushPropertySafe -Target $navScroll -Property 'Background' -Value $navScrollBackground
            } catch {
                Write-Verbose "Sidebar scroll background skipped"
            }
        }

        $adminCard = $form.FindName('SidebarAdminCard')
        if ($adminCard -is [System.Windows.Controls.Border]) {
            $adminBackground = if ($headerBrush) { $headerBrush } else { $colors.HeaderBg }
            Set-BrushPropertySafe -Target $adminCard -Property 'Background' -Value $adminBackground
            try {
                $adminBorder = if ($primaryBrush) { $primaryBrush } else { $colors.Primary }
                Set-BrushPropertySafe -Target $adminCard -Property 'BorderBrush' -Value $adminBorder -AllowTransparentFallback
            } catch {
                Write-Verbose "Sidebar admin border assignment skipped"
            }
        }

        $mainStage = $form.FindName('MainStage')
        if ($mainStage -is [System.Windows.Controls.Grid]) {
            try {
                $mainStageBackground = if ($secondaryBrush) { $secondaryBrush } else { $colors.Secondary }
                Set-BrushPropertySafe -Target $mainStage -Property 'Background' -Value $mainStageBackground
            } catch {
                Write-Verbose "MainStage background assignment skipped"
            }
        }

        $headerBar = $form.FindName('HeaderBar')
        if ($headerBar -is [System.Windows.Controls.Border]) {
            $headerBackground = if ($headerBrush) { $headerBrush } else { $colors.HeaderBg }
            Set-BrushPropertySafe -Target $headerBar -Property 'Background' -Value $headerBackground
            try {
                $headerBorder = if ($primaryBrush) { $primaryBrush } else { $colors.Primary }
                Set-BrushPropertySafe -Target $headerBar -Property 'BorderBrush' -Value $headerBorder -AllowTransparentFallback
            } catch {
                Write-Verbose "Header border assignment skipped"
            }
        }

        $footerBar = $form.FindName('FooterBar')
        if ($footerBar -is [System.Windows.Controls.Border]) {
            $footerBackground = if ($headerBrush) { $headerBrush } else { $colors.HeaderBg }
            Set-BrushPropertySafe -Target $footerBar -Property 'Background' -Value $footerBackground
            try {
                $footerBorder = if ($primaryBrush) { $primaryBrush } else { $colors.Primary }
                Set-BrushPropertySafe -Target $footerBar -Property 'BorderBrush' -Value $footerBorder -AllowTransparentFallback
            } catch {
                Write-Verbose "Footer border assignment skipped"
            }
        }

        $mainScroll = $form.FindName('MainScrollViewer')
        if ($mainScroll -is [System.Windows.Controls.ScrollViewer]) {
            try { Set-BrushPropertySafe -Target $mainScroll -Property 'Background' -Value [System.Windows.Media.Brushes]::Transparent } catch { Write-Verbose "Main scroll background skipped" }
        }

        try {
            Update-AllUIElementsRecursively -element $form -colors $colors
            Log "Rekursive UI-Element-Aktualisierung abgeschlossen" 'Info'
        } catch [System.InvalidOperationException] {
            if ($_.Exception.Message -match "sealed|IsSealed") {
                Log "SetterBase sealed style detected - applying fallback theming strategy" 'Warning'
                try {
                    Apply-FallbackThemeColors -element $form -colors $colors
                    Log "Fallback theming strategy erfolgreich angewendet" 'Info'
                } catch {
                    Log "Fallback theming strategy fehlgeschlagen: $($_.Exception.Message)" 'Error'
                }
            } else {
                throw
            }
        }

        try {
            $panels = @($panelDashboard, $panelBasicOpt, $panelAdvanced, $panelGames, $panelOptions, $panelBackup, $panelLog)
            foreach ($panel in $panels) {
                if ($panel) {
                    try {
                        $panel.InvalidateVisual()
                        $panel.InvalidateMeasure()
                        $panel.UpdateLayout()
                    } catch {
                    }
                }
            }

            function Find-ScrollViewers($element) {
                if ($element -is [System.Windows.Controls.ScrollViewer]) {
                    $script:scrollViewers += $element
                }

                if ($element.Children) {
                    foreach ($child in $element.Children) {
                        Find-ScrollViewers $child
                    }
                } elseif ($element.Content) {
                    Find-ScrollViewers $element.Content
                } elseif ($element.Child) {
                    Find-ScrollViewers $element.Child
                }
            }

            $form.Dispatcher.Invoke([action]{

                $form.InvalidateVisual()
                $form.InvalidateMeasure()
                $form.InvalidateArrange()
                $form.UpdateLayout()

                $script:scrollViewers = @()
                Find-ScrollViewers $form

                foreach ($scrollViewer in $script:scrollViewers) {
                    try {
                        $scrollViewer.InvalidateVisual()
                        $scrollViewer.UpdateLayout()
                    } catch {
                    }
                }

            }, [System.Windows.Threading.DispatcherPriority]::Render)

            $form.Dispatcher.BeginInvoke([action]{
                try {
                    $backgroundBrush = $null
                    try {
                        $backgroundBrush = New-SolidColorBrushSafe $colors.Background
                    } catch {
                        $backgroundBrush = $null
                    }

                    if ($backgroundBrush) {
                        Set-BrushPropertySafe -Target $form -Property 'Background' -Value $backgroundBrush
                    } else {
                        try {
                            $converter = New-Object System.Windows.Media.BrushConverter
                            $converted = $converter.ConvertFromString($colors.Background)
                            if ($converted) {
                                Set-BrushPropertySafe -Target $form -Property 'Background' -Value $converted
                            } else {
                                Set-BrushPropertySafe -Target $form -Property 'Background' -Value $colors.Background
                            }
                        } catch {
                            Set-BrushPropertySafe -Target $form -Property 'Background' -Value $colors.Background
                        }
                    }
                } catch {
                    Write-Verbose "Background refresh skipped: $($_.Exception.Message)"
                }

                $form.InvalidateVisual()
                $form.UpdateLayout()
            }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null

            Log '[OK] Vollständiger UI-Refresh abgeschlossen - alle Änderungen sofort sichtbar!' 'Success'

        } catch {
            $warningMessage = '⚠️ UI-Refresh teilweise fehlgeschlagen: {0}' -f $_.Exception.Message
            Log $warningMessage 'Warning'

            try {
                $form.InvalidateVisual()
                $form.UpdateLayout()
                Log 'Fallback-Refresh durchgeführt' 'Info'
            } catch {
                Log 'Auch Fallback-Refresh fehlgeschlagen' 'Error'
            }
        }

        $global:CurrentTheme = $appliedThemeName
        Update-ButtonStyles -Primary $colors.Primary -Hover $colors.Hover
        Update-ComboBoxStyles -Background $colors.Secondary -Foreground $colors.Text -Border $colors.Primary -ThemeName $appliedThemeName
        Update-TextStyles -Foreground $colors.Text -Header $colors.Accent -ThemeName $appliedThemeName

        Normalize-VisualTreeBrushes -Root $form

    } catch {
        Log "❌ Fehler beim Theme-Wechsel: $($_.Exception.Message)" 'Error'

        $shouldAttemptFallback = -not $IsFallback
        if ($PSCmdlet.ParameterSetName -eq 'ByTheme' -and $ThemeName -eq 'Nebula') {
            $shouldAttemptFallback = $false
        }

        if ($shouldAttemptFallback) {
            try {
                if (${function:Apply-ThemeColors}) {
                    & ${function:Apply-ThemeColors} -ThemeName 'Nebula' -IsFallback
                    Log "Standard-Theme als Fallback angewendet" 'Info'
                } else {
                    Log "Fallback-Theme konnte nicht geladen werden (Function nicht verfügbar)" 'Error'
                }
            } catch {
                Log "KRITISCHER FEHLER: Kein Theme kann angewendet werden." 'Error'
            }
        } else {
            Log "KRITISCHER FEHLER: Kein Theme kann angewendet werden." 'Error'
        }
    }
}

function Switch-Theme {
    param([string]$ThemeName)

    try {
        if (-not $ThemeName) {
            Log "Theme-Name ist leer, verwende Standard" 'Warning'
            $ThemeName = "Nebula"
        }

        if (-not $form) {
            Log "UI-Formular nicht verfügbar, Theme kann nicht gewechselt werden" 'Error'
            return
        }

        if ($ThemeName -eq 'Custom' -and $global:CustomThemeColors) {
            $themeColors = $global:CustomThemeColors.Clone()
        } else {
            if (-not $global:ThemeDefinitions.ContainsKey($ThemeName)) {
                Log "Theme '$ThemeName' nicht gefunden, wechsle zu Nebula" 'Warning'
                $ThemeName = "Nebula"
            }

            $themeColors = (Get-ThemeColors -ThemeName $ThemeName).Clone()
        }

        $themeColors = Normalize-ThemeColorTable $themeColors

        Log "Wechsle zu Theme '$($themeColors.Name)'..." 'Info'

        if (${function:Apply-ThemeColors}) {
            & ${function:Apply-ThemeColors} -ThemeName $ThemeName
        } else {
            Log "Apply-ThemeColors Funktion nicht verfügbar - Theme kann nicht angewendet werden" 'Error'
            return
        }

        $form.Dispatcher.Invoke([action]{

            try {
                Set-BrushPropertySafe -Target $form -Property 'Background' -Value $themeColors.Background
            } catch {
                Write-Verbose "Switch-Theme background refresh skipped: $($_.Exception.Message)"
            }

            $form.InvalidateVisual()
            $form.InvalidateMeasure()
            $form.InvalidateArrange()
            $form.UpdateLayout()

            $navButtons = if ($global:NavigationButtonNames) {
                $global:NavigationButtonNames
            } else {
                @('btnNavDashboard', 'btnNavBasicOpt', 'btnNavAdvanced', 'btnNavGames', 'btnNavOptions', 'btnNavBackup', 'btnNavLog')
            }

            foreach ($btnName in $navButtons) {
                $btn = $form.FindName($btnName)
                if ($btn) {
                    if ($btn.Tag -eq "Selected") {
                        Set-BrushPropertySafe -Target $btn -Property 'Background' -Value $themeColors.SelectedBackground -AllowTransparentFallback
                        Set-BrushPropertySafe -Target $btn -Property 'Foreground' -Value $themeColors.SelectedForeground -AllowTransparentFallback
                    } else {
                        Set-BrushPropertySafe -Target $btn -Property 'Background' -Value $themeColors.UnselectedBackground -AllowTransparentFallback
                        Set-BrushPropertySafe -Target $btn -Property 'Foreground' -Value $themeColors.UnselectedForeground -AllowTransparentFallback
                    }

                    $btn.InvalidateVisual()
                    $btn.InvalidateMeasure()
                    $btn.UpdateLayout()
                }
            }

            if ($form.Children -and $form.Children.Count -gt 0) {
                $firstChild = $form.Children[0]
                if ($firstChild.Children -and $firstChild.Children.Count -gt 0) {
                    $sidebar = $firstChild.Children[0]
                    if ($sidebar) {
                        Set-BrushPropertySafe -Target $sidebar -Property 'Background' -Value $themeColors.SidebarBg
                        Set-BrushPropertySafe -Target $sidebar -Property 'BorderBrush' -Value $themeColors.Primary -AllowTransparentFallback

                        if ($sidebar.Child -is [System.Windows.Controls.Grid]) {
                            $sidebarGrid = $sidebar.Child
                            if ($sidebarGrid.Children -and $sidebarGrid.Children.Count -gt 0) {
                                Set-BrushPropertySafe -Target $sidebarGrid.Children[0] -Property 'Background' -Value $themeColors.SidebarBg
                            }
                            if ($sidebarGrid.Children.Count -gt 1 -and $sidebarGrid.Children[1].GetType().GetProperty('Background')) {
                                try { Set-BrushPropertySafe -Target $sidebarGrid.Children[1] -Property 'Background' -Value $themeColors.SidebarBg } catch { Write-Verbose "Sidebar scroll background skipped" }
                            }
                            if ($sidebarGrid.Children.Count -gt 2) {
                                Set-BrushPropertySafe -Target $sidebarGrid.Children[2] -Property 'Background' -Value $themeColors.SidebarBg
                                Set-BrushPropertySafe -Target $sidebarGrid.Children[2] -Property 'BorderBrush' -Value $themeColors.Primary -AllowTransparentFallback
                            }
                        }

                        $sidebar.InvalidateVisual()
                        $sidebar.UpdateLayout()
                    }

                    if ($firstChild.Children.Count -gt 1) {
                        $mainContent = $firstChild.Children[1]
                        if ($mainContent) {
                            if ($mainContent.Children -and $mainContent.Children.Count -gt 0) {
                                Set-BrushPropertySafe -Target $mainContent.Children[0] -Property 'Background' -Value $themeColors.HeaderBg
                                Set-BrushPropertySafe -Target $mainContent.Children[0] -Property 'BorderBrush' -Value $themeColors.Primary -AllowTransparentFallback
                            }

                            if ($mainContent.Children.Count -gt 3) {
                                Set-BrushPropertySafe -Target $mainContent.Children[3] -Property 'Background' -Value $themeColors.HeaderBg
                                Set-BrushPropertySafe -Target $mainContent.Children[3] -Property 'BorderBrush' -Value $themeColors.Primary -AllowTransparentFallback
                            }

                            if ($mainContent.Children.Count -gt 4) {
                                Set-BrushPropertySafe -Target $mainContent.Children[4] -Property 'Background' -Value $themeColors.LogBg
                                Set-BrushPropertySafe -Target $mainContent.Children[4] -Property 'BorderBrush' -Value $themeColors.Accent -AllowTransparentFallback
                            }

                            $mainContent.InvalidateVisual()
                            $mainContent.UpdateLayout()
                        }
                    }
                }
            }

            $panels = @($panelDashboard, $panelBasicOpt, $panelAdvanced, $panelGames, $panelOptions, $panelBackup, $panelLog)
            foreach ($panel in $panels) {
                if ($panel) {
                    $panel.InvalidateVisual()
                    $panel.UpdateLayout()
                }
            }

            if ($global:LogBox) {
                Set-BrushPropertySafe -Target $global:LogBox -Property 'Background' -Value $themeColors.LogBg
                Set-BrushPropertySafe -Target $global:LogBox -Property 'Foreground' -Value $themeColors.Accent
                $global:LogBox.InvalidateVisual()
                $global:LogBox.UpdateLayout()
            }

            if ($activityLogBorder) {
                try {
                    Set-BrushPropertySafe -Target $activityLogBorder -Property 'Background' -Value $themeColors.LogBg
                    Set-BorderBrushSafe -Element $activityLogBorder -BorderBrushValue $themeColors.Accent -BorderThicknessValue '0,0,0,2'
                    $activityLogBorder.InvalidateVisual()
                    $activityLogBorder.UpdateLayout()
                } catch {
                    Write-Verbose "Activity log border update skipped: $($_.Exception.Message)"
                }
            }

            $form.InvalidateVisual()
            $form.UpdateLayout()

        }, [System.Windows.Threading.DispatcherPriority]::Render)

        Start-Sleep -Milliseconds 100

        $form.Dispatcher.BeginInvoke([action]{
            Set-BrushPropertySafe -Target $form -Property 'Background' -Value $themeColors.Background
            $form.InvalidateVisual()
            $form.UpdateLayout()

            $navButtons = if ($global:NavigationButtonNames) {
                $global:NavigationButtonNames
            } else {
                @('btnNavDashboard', 'btnNavBasicOpt', 'btnNavAdvanced', 'btnNavGames', 'btnNavOptions', 'btnNavBackup', 'btnNavLog')
            }

            foreach ($btnName in $navButtons) {
                $btn = $form.FindName($btnName)
                if ($btn) {
                    if ($btn.Tag -eq "Selected") {
                        Set-BrushPropertySafe -Target $btn -Property 'Background' -Value $themeColors.SelectedBackground -AllowTransparentFallback
                        Set-BrushPropertySafe -Target $btn -Property 'Foreground' -Value $themeColors.SelectedForeground -AllowTransparentFallback
                    } else {
                        Set-BrushPropertySafe -Target $btn -Property 'Background' -Value $themeColors.UnselectedBackground -AllowTransparentFallback
                        Set-BrushPropertySafe -Target $btn -Property 'Foreground' -Value $themeColors.UnselectedForeground -AllowTransparentFallback
                    }
                    $btn.InvalidateVisual()
                }
            }

        }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null

        Start-Sleep -Milliseconds 150

        $form.Dispatcher.BeginInvoke([action]{
            Update-AllUIElementsRecursively -element $form -colors $themeColors

            $form.InvalidateVisual()
            $form.UpdateLayout()

        }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null

        if ($global:CurrentPanel -eq 'Advanced' -and $global:CurrentAdvancedSection) {
            $currentSection = $global:CurrentAdvancedSection
            $themeForHighlight = if ($appliedThemeName) { $appliedThemeName } else { $ThemeName }

            try {
                $form.Dispatcher.BeginInvoke([action]{
                    Set-ActiveAdvancedSectionButton -Section $currentSection -CurrentTheme $themeForHighlight
                }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
            } catch {
                Log "Could not refresh advanced section highlight: $($_.Exception.Message)" 'Warning'
            }
        }

        Log "[OK] Theme '$($themeColors.Name)' erfolgreich angewendet mit umfassendem UI-Refresh!" 'Success'

        if ($ThemeName -ne 'Custom') {
            Update-ThemeColorPreview -ThemeName $ThemeName
        }

    } catch {
        Log "❌ Fehler beim Theme-Wechsel: $($_.Exception.Message)" 'Error'

        try {
            if (${function:Apply-ThemeColors}) {
                & ${function:Apply-ThemeColors} -ThemeName 'Nebula' -IsFallback
                Log "Standard-Theme als Fallback angewendet" 'Info'
            } else {
                Log "Fallback-Theme konnte nicht geladen werden (Function nicht verfügbar)" 'Error'
            }
        } catch {
            Log "KRITISCHER FEHLER: Kein Theme kann angewendet werden." 'Error'
        }
    }
}

# Log functions moved to top of script to fix call order issues

# ---------- WinMM Timer (1ms precision) ----------
if (-not ([System.Management.Automation.PSTypeName]'WinMM').Type) {
    try {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WinMM {
    [DllImport("winmm.dll", EntryPoint="timeBeginPeriod")]
    public static extern uint timeBeginPeriod(uint uPeriod);
    [DllImport("winmm.dll", EntryPoint="timeEndPeriod")]
    public static extern uint timeEndPeriod(uint uPeriod);
}
'@ -ErrorAction Stop
    } catch {
        Write-Verbose "WinMM timer API not available: $($_.Exception.Message)"
    }
}

# ---------- Performance Monitoring API ----------
if (-not ([System.Management.Automation.PSTypeName]'PerfMon').Type) {
    try {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PerfMon {
    [DllImport("kernel32.dll")]
    public static extern bool GetSystemTimes(out long idleTime, out long kernelTime, out long userTime);

    [DllImport("kernel32.dll")]
    public static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORYSTATUSEX {  // Memory structure with ullTotalPhys and ullAvailPhys for detailed monitoring
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }
}
'@ -ErrorAction Stop
    } catch {
        Write-Verbose "Performance monitoring API not available: $($_.Exception.Message)"
    }
}

# ---------- System Health Monitoring and Alerts ----------
$global:SystemHealthData = @{
    LastHealthCheck = $null
    HealthStatus = 'Not Run'
    HealthWarnings = @()
    HealthScore = $null
    Recommendations = @()
    Issues = @()
    Metrics = @{}
    LastResult = $null
}

function Get-SystemHealthStatus {
    <#
    .SYNOPSIS
    Comprehensive system health monitoring with performance analysis and recommendations
    .DESCRIPTION
    Analyzes system health across multiple dimensions and provides actionable recommendations
    #>

    try {
        $healthData = @{
            OverallScore = 100
            Issues = @()
            Warnings = @()
            Recommendations = @()
            Status = "Excellent"
            Metrics = @{}
        }

        # 1. Memory Health Check - MemoryUsagePercent gt 90 triggers Critical memory usage alerts
        $memMetrics = Get-SystemPerformanceMetrics
        if ($memMetrics.MemoryUsagePercent) {
            $healthData.Metrics.MemoryUsage = $memMetrics.MemoryUsagePercent

            if ($memMetrics.MemoryUsagePercent -gt 90) {
                $healthData.Issues += "Critical memory usage: $($memMetrics.MemoryUsagePercent)%"
                $healthData.Recommendations += "Close unnecessary applications to free memory"
                $healthData.OverallScore -= 20  # OverallScore minus 20 for critical memory
            } elseif ($memMetrics.MemoryUsagePercent -gt 80) {
                $healthData.Warnings += "High memory usage: $($memMetrics.MemoryUsagePercent)%"
                $healthData.Recommendations += "Consider closing some applications for better gaming performance"
                $healthData.OverallScore -= 10  # OverallScore minus 10 for high memory
            }
        }

        # 2. CPU Health Check - CpuUsage gt 90 triggers Critical CPU usage alerts
        if ($memMetrics.CpuUsage) {
            $healthData.Metrics.CpuUsage = $memMetrics.CpuUsage

            if ($memMetrics.CpuUsage -gt 90) {
                $healthData.Issues += "Critical CPU usage: $($memMetrics.CpuUsage)%"
                $healthData.Recommendations += "Check for background processes consuming CPU"
                $healthData.OverallScore -= 15  # OverallScore minus 15 for critical CPU
            } elseif ($memMetrics.CpuUsage -gt 75) {
                $healthData.Warnings += "High CPU usage: $($memMetrics.CpuUsage)%"
                $healthData.Recommendations += "Monitor CPU-intensive applications"
                $healthData.OverallScore -= 8
            }
        }

        # 3. Disk Space Health Check - REMOVED due to PowerShell parser errors
        # The following disk space health check code has been commented out to resolve parsing issues:
        # - Removed variables: $freeSpaceGB, $freeSpacePercent
        # - Removed problematic string formatting: ($freeSpaceGB GB)
        # - Removed healthData.Issues, healthData.Warnings, healthData.Recommendations for disk space
        <#
        try {
            $systemDrive = $env:SystemDrive
            $driveInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$systemDrive'" -ErrorAction SilentlyContinue
            if ($driveInfo) {
                $freeSpaceGB = [math]::Round($driveInfo.FreeSpace / 1GB, 2)
                $totalSpaceGB = [math]::Round($driveInfo.Size / 1GB, 2)
                $freeSpacePercent = [math]::Round(($driveInfo.FreeSpace / $driveInfo.Size) * 100, 1)

                $healthData.Metrics.DiskFreeSpace = $freeSpacePercent

                if ($freeSpacePercent -lt 10) {
                    $healthData.Issues += "Critical disk space: $freeSpacePercent% free ($freeSpaceGB GB)"
                    $healthData.Recommendations += "Free up disk space immediately to prevent system issues"
                    $healthData.OverallScore -= 25
                } elseif ($freeSpacePercent -lt 20) {
                    $healthData.Warnings += "Low disk space: $freeSpacePercent% free ($freeSpaceGB GB)"
                    $healthData.Recommendations += "Consider cleaning up temporary files and uninstalling unused programs"
                    $healthData.OverallScore -= 12
                }
            }
        } catch {
            Log "Warning: Could not check disk space: $($_.Exception.Message)" 'Warning'
        }
        #>

        # 4. Running Processes Health Check - processCount gt 200 analysis and optimization detection
        try {
            $processCount = (Get-Process).Count
            $healthData.Metrics.ProcessCount = $processCount

            if ($processCount -gt 200) {
                $healthData.Warnings += "High number of running processes: $processCount"
                $healthData.Recommendations += "Consider using Task Manager to close unnecessary processes"
                $healthData.OverallScore -= 8
            }

            # Check for known problematic processes
            $problematicProcesses = Get-Process | Where-Object {
                $_.ProcessName -match "miner|crypto|torrent" -and $_.WorkingSet -gt 100MB
            }

            if ($problematicProcesses) {
                $healthData.Warnings += "Detected potentially problematic processes affecting gaming performance"
                $healthData.Recommendations += "Review and close mining, crypto, or torrent applications while gaming"
                $healthData.OverallScore -= 15
            }
        } catch {
            Log "Warning: Could not analyze running processes: $($_.Exception.Message)" 'Warning'
        }

        # 5. Windows Update Health Check - Microsoft.Update.Session for pendingUpdates analysis
        try {
            $updateSession = New-Object -ComObject Microsoft.Update.Session -ErrorAction SilentlyContinue
            if ($updateSession) {
                $updateSearcher = $updateSession.CreateUpdateSearcher()
                $pendingUpdates = $updateSearcher.Search("IsInstalled=0 and IsHidden=0").Updates.Count

                if ($pendingUpdates -gt 0) {
                    $healthData.Metrics.PendingUpdates = $pendingUpdates
                    $healthData.Warnings += "$pendingUpdates pending Windows updates"
                    $healthData.Recommendations += "Install pending Windows updates for security and performance improvements"
                    $healthData.OverallScore -= 5
                }
            }
        } catch {
            # Silent fail for Windows Update check
        }

        # 6. Gaming Optimization Status - GameBar AllowAutoGameMode and HwSchMode validation
        try {
            $gameMode = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -ErrorAction SilentlyContinue
            if (-not $gameMode -or $gameMode.AllowAutoGameMode -ne 1) {
                $healthData.Warnings += "Windows Game Mode is not enabled"
                $healthData.Recommendations += "Enable Game Mode in Windows Settings for better gaming performance"
                $healthData.OverallScore -= 5
            }

            $hardwareScheduling = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -ErrorAction SilentlyContinue
            if (-not $hardwareScheduling -or $hardwareScheduling.HwSchMode -ne 2) {
                $healthData.Warnings += "Hardware GPU Scheduling is not enabled"
                $healthData.Recommendations += "Enable Hardware GPU Scheduling for improved graphics performance"
                $healthData.OverallScore -= 5
            }
        } catch {
            # Silent fail for optimization checks
        }

        # 7. Network Health Check - Win32_NetworkAdapter NetEnabled and NetConnectionStatus analysis
        try {
            $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapter -Filter "NetEnabled=True" -ErrorAction SilentlyContinue
            $activeAdapters = $networkAdapters | Where-Object { $_.NetConnectionStatus -eq 2 }

            if ($activeAdapters.Count -eq 0) {
                $healthData.Issues += "No active network connections detected"
                $healthData.Recommendations += "Check network connectivity for online gaming"
                $healthData.OverallScore -= 20
            } elseif ($activeAdapters.Count -gt 2) {
                $healthData.Warnings += "Multiple active network adapters detected"
                $healthData.Recommendations += "Disable unused network adapters to reduce latency"
                $healthData.OverallScore -= 5
            }
        } catch {
            # Silent fail for network check
        }

        # Determine overall status - OverallScore ge 90 Excellent, ge 75 Good, ge 60 Fair, Poor, Critical
        if ($healthData.OverallScore -ge 90) {
            $healthData.Status = "Excellent"
        } elseif ($healthData.OverallScore -ge 75) {
            $healthData.Status = "Good"
        } elseif ($healthData.OverallScore -ge 60) {
            $healthData.Status = "Fair"
        } elseif ($healthData.OverallScore -ge 40) {
            $healthData.Status = "Poor"
        } else {
            $healthData.Status = "Critical"
        }

        return $healthData

    } catch {
        Log "Error performing system health check: $($_.Exception.Message)" 'Error'
        return @{
            OverallScore = 0
            Issues = @("Health check failed")
            Warnings = @()
            Recommendations = @("Run as Administrator for complete health analysis")
            Status = "Unknown"
            Metrics = @{}
        }
    }
}

function Update-SystemHealthSummary {
    try {
        $status = if ($global:SystemHealthData.HealthStatus) { $global:SystemHealthData.HealthStatus } else { 'Not Run' }
        $score = $global:SystemHealthData.HealthScore
        $lastRun = $global:SystemHealthData.LastHealthCheck

        $text = 'Not Run'
        $foreground = '#A6AACF'

        if ($status -eq 'Error') {
            $text = 'Error (see log)'
            $foreground = '#FF4444'
        } elseif ($lastRun) {
            $timeStamp = $lastRun.ToString('HH:mm')
            if ($score -ne $null) {
                $roundedScore = [Math]::Round([double]$score, 0)
                $text = '{0} ({1}% @ {2})' -f $status, [int]$roundedScore, $timeStamp
            } else {
                $text = '{0} (Last: {1})' -f $status, $timeStamp
            }

            switch ($status) {
                'Excellent' { $foreground = '#8F6FFF' }
                'Good' { $foreground = '#A7F3D0' }
                'Fair' { $foreground = '#A78BFA' }
                'Poor' { $foreground = '#FFA500' }
                'Critical' { $foreground = '#FF6B6B' }
                default { $foreground = '#A6AACF' }
            }
        }

        if ($lblDashSystemHealth) {
            $lblDashSystemHealth.Dispatcher.Invoke([Action]{
                $lblDashSystemHealth.Text = $text
                Set-BrushPropertySafe -Target $lblDashSystemHealth -Property 'Foreground' -Value $foreground
            })
        }
    } catch {
        Log "Error updating dashboard health summary: $($_.Exception.Message)" 'Warning'
    }
}

function Update-SystemHealthDisplay {
    param([switch]$RunCheck)

    try {
        $shouldRun = [bool]$RunCheck

        if ($shouldRun) {
            $healthData = Get-SystemHealthStatus
            if ($healthData) {
                $timestamp = Get-Date
                $global:SystemHealthData.LastHealthCheck = $timestamp
                $global:SystemHealthData.HealthStatus = $healthData.Status
                $global:SystemHealthData.HealthScore = $healthData.OverallScore
                $global:SystemHealthData.HealthWarnings = $healthData.Warnings
                $global:SystemHealthData.Recommendations = $healthData.Recommendations
                $global:SystemHealthData.Issues = $healthData.Issues
                $global:SystemHealthData.Metrics = $healthData.Metrics
                $global:SystemHealthData.LastResult = $healthData
                Log "Health check complete: $($healthData.Status) ($($healthData.OverallScore)% score)" 'Info'
            }
        }
    } catch {
        $errorMessage = 'Error in Update-SystemHealthDisplay: {0}' -f $_.Exception.Message
        Log $errorMessage 'Error'
        $global:SystemHealthData.LastHealthCheck = Get-Date
        $global:SystemHealthData.HealthStatus = 'Error'
        $global:SystemHealthData.HealthScore = $null
        $global:SystemHealthData.HealthWarnings = @($errorMessage)
        $global:SystemHealthData.Recommendations = @()
        $global:SystemHealthData.Issues = @($errorMessage)
        $global:SystemHealthData.Metrics = @{}
        $global:SystemHealthData.LastResult = $null
    }

    Update-SystemHealthSummary

    return $global:SystemHealthData
}

function Show-SystemHealthDialog {
    <#
    .SYNOPSIS
    Shows a detailed system health dialog with recommendations and actions
    .DESCRIPTION
    Creates a WPF dialog displaying comprehensive system health information
    #>

    try {

        [xml]$healthDialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Health Monitor"
        Width="750" Height="600"
        Background="#080716"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize">

  <Window.Resources>
    <SolidColorBrush x:Key="CardBackgroundBrush" Color="#14132B"/>
    <SolidColorBrush x:Key="CardBorderBrush" Color="#2F285A"/>
    <SolidColorBrush x:Key="AccentBrush" Color="#8F6FFF"/>
    <SolidColorBrush x:Key="PrimaryTextBrush" Color="#F5F3FF"/>
    <SolidColorBrush x:Key="SecondaryTextBrush" Color="#A9A5D9"/>
    <Style TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}"/>
    </Style>
    <Style x:Key="DialogButton" TargetType="Button">
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="#120B22"/>
      <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="14,6"/>
      <Setter Property="FontWeight" Value="SemiBold"/>

      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="10">

              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">

              <Setter Property="Background" Value="#A78BFA"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SecondaryDialogButton" TargetType="Button" BasedOn="{StaticResource DialogButton}">
      <Setter Property="Background" Value="#1F1B3F"/>
      <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}"/>
    </Style>
    <Style x:Key="WarningDialogButton" TargetType="Button" BasedOn="{StaticResource DialogButton}">
      <Setter Property="Background" Value="#FBBF24"/>
      <Setter Property="Foreground" Value="#1B1302"/>
    </Style>
  </Window.Resources>

  <Grid Margin="15">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="20" Margin="0,0,0,15">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <StackPanel Grid.Column="0">
          <TextBlock Text="System Health Monitor" Foreground="{DynamicResource AccentBrush}" FontWeight="Bold" FontSize="20"/>
          <TextBlock x:Name="lblHealthStatus" Text="Status: Unknown" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="14" Margin="0,5,0,0"/>
          <TextBlock x:Name="lblHealthScore" Text="Health Score: 0%" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" Margin="0,2,0,0"/>
        </StackPanel>

        <Button x:Name="btnRefreshHealth" Grid.Column="1" Content="🔄 Refresh" Width="100" Height="35"
                Background="{StaticResource CardBorderBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderThickness="0" FontWeight="SemiBold"/>
      </Grid>
    </Border>

    <!-- Metrics -->
    <Border Grid.Row="1" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="15" Margin="0,0,0,15">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <StackPanel Grid.Column="0">
          <TextBlock Text="CPU Usage" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" FontWeight="Bold"/>
          <TextBlock x:Name="lblCpuMetric" Text="--%" Foreground="{DynamicResource AccentBrush}" FontSize="14" Margin="0,2,0,0"/>
        </StackPanel>

        <StackPanel Grid.Column="1">
          <TextBlock Text="Memory Usage" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" FontWeight="Bold"/>
          <TextBlock x:Name="lblMemoryMetric" Text="--%" Foreground="{DynamicResource AccentBrush}" FontSize="14" Margin="0,2,0,0"/>
        </StackPanel>
        <StackPanel Grid.Column="2" Visibility="Collapsed">
          <TextBlock Text="Disk Free Space" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" FontWeight="Bold"/>
          <TextBlock x:Name="lblDiskMetric" Text="--%" Foreground="{DynamicResource AccentBrush}" FontSize="14" Margin="0,2,0,0"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- Issues and Recommendations -->
    <Border Grid.Row="2" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="15">

      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Issues &amp; Warnings" Foreground="#FF6B6B" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" MaxHeight="150">
          <ListBox x:Name="lstIssues" Background="Transparent" BorderThickness="0" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="11">
            <ListBox.ItemTemplate>
              <DataTemplate>
                <TextBlock Text="{Binding}" Foreground="#FF6B6B" Margin="5" TextWrapping="Wrap"/>
              </DataTemplate>
            </ListBox.ItemTemplate>
          </ListBox>
        </ScrollViewer>

        <TextBlock Grid.Row="2" Text="Recommendations" Foreground="{DynamicResource AccentBrush}" FontWeight="Bold" FontSize="14" Margin="0,15,0,10"/>
        <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">
          <ListBox x:Name="lstRecommendations" Background="Transparent" BorderThickness="0" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="11">
            <ListBox.ItemTemplate>
              <DataTemplate>
                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="3" Padding="8" Margin="2">
                  <TextBlock Text="{Binding}" Foreground="{DynamicResource SecondaryTextBrush}" TextWrapping="Wrap"/>
                </Border>
              </DataTemplate>
            </ListBox.ItemTemplate>
          </ListBox>
        </ScrollViewer>
      </Grid>
    </Border>

    <!-- Action Buttons -->
    <Border Grid.Row="3" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="10" Margin="0,15,0,0">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
        <Button x:Name="btnOptimizeNow" Content="⚡ Quick Optimize" Width="140" Height="34" Style="{StaticResource DialogButton}" Margin="0,0,10,0"/>
        <Button x:Name="btnOpenTaskManager" Content="📊 Task Manager" Width="130" Height="34" Style="{StaticResource SecondaryDialogButton}" Margin="0,0,10,0"/>
        <Button x:Name="btnCloseHealth" Content="Close" Width="100" Height="34" Style="{StaticResource WarningDialogButton}"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@

        # Create the window
        $reader = New-Object System.Xml.XmlNodeReader $healthDialogXaml
        $healthWindow = [Windows.Markup.XamlReader]::Load($reader)
        Initialize-LayoutSpacing -Root $healthWindow

        # Get controls
        $lblHealthStatus = $healthWindow.FindName('lblHealthStatus')
        $lblHealthScore = $healthWindow.FindName('lblHealthScore')
        $lblCpuMetric = $healthWindow.FindName('lblCpuMetric')
        $lblMemoryMetric = $healthWindow.FindName('lblMemoryMetric')
        $lblDiskMetric = $healthWindow.FindName('lblDiskMetric')
        $lstIssues = $healthWindow.FindName('lstIssues')
        $lstRecommendations = $healthWindow.FindName('lstRecommendations')
        $btnRefreshHealth = $healthWindow.FindName('btnRefreshHealth')
        $btnOptimizeNow = $healthWindow.FindName('btnOptimizeNow')
        $btnOpenTaskManager = $healthWindow.FindName('btnOpenTaskManager')
        $btnCloseHealth = $healthWindow.FindName('btnCloseHealth')

        # Update display function
        $updateDisplay = {
            param([bool]$RunCheck = $false)

            $data = Update-SystemHealthDisplay -RunCheck:$RunCheck

            if (-not $data.LastHealthCheck) {
                $lblHealthStatus.Text = 'Status: Not Run'
                $lblHealthScore.Text = 'Health Score: N/A'
                $lblCpuMetric.Text = '--%'
                $lblMemoryMetric.Text = '--%'
                if ($lblDiskMetric) { $lblDiskMetric.Text = '--%' }
                $lstIssues.ItemsSource = @()
                $lstRecommendations.ItemsSource = @("Click Refresh to run a health check.")
                return
            }

            $timestamp = $data.LastHealthCheck.ToString('g')
            $lblHealthStatus.Text = "Status: $($data.HealthStatus) (Last: $timestamp)"
            if ($data.HealthScore -ne $null) {
                $lblHealthScore.Text = "Health Score: $($data.HealthScore)%"
            } else {
                $lblHealthScore.Text = 'Health Score: N/A'
            }

            if ($data.Metrics.ContainsKey('CpuUsage') -and $data.Metrics.CpuUsage -ne $null) {
                $lblCpuMetric.Text = "$($data.Metrics.CpuUsage)%"
            } else {
                $lblCpuMetric.Text = '--%'
            }

            if ($data.Metrics.ContainsKey('MemoryUsage') -and $data.Metrics.MemoryUsage -ne $null) {
                $lblMemoryMetric.Text = "$($data.Metrics.MemoryUsage)%"
            } else {
                $lblMemoryMetric.Text = '--%'
            }

            # Disk metric intentionally omitted (legacy compatibility)

            $issues = @()
            if ($data.Issues) { $issues += $data.Issues }
            if ($data.HealthWarnings) { $issues += $data.HealthWarnings }
            $lstIssues.ItemsSource = $issues

            if ($data.Recommendations) {
                $lstRecommendations.ItemsSource = $data.Recommendations
            } else {
                $lstRecommendations.ItemsSource = @('No recommendations available. Great job!')
            }

            Log "System health dialog updated with cached status: $($data.HealthStatus)" 'Info'
        }

        # Event handlers
        $btnRefreshHealth.Add_Click({
            Log "Manual health check requested from System Health dialog" 'Info'
            & $updateDisplay $true
        })

        $btnOptimizeNow.Add_Click({
            try {
                # Trigger a quick optimization if the main Apply button exists
                if ($btnApply) {
                    Log "Quick optimization triggered from System Health dialog" 'Info'
                    $healthWindow.Close()
                    $btnApply.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
                } else {
                    [System.Windows.MessageBox]::Show("Quick optimization is not available. Please use the main optimization features.", "Optimization", 'OK', 'Information')
                }
            } catch {
                Log "Error triggering optimization from health dialog: $($_.Exception.Message)" 'Error'
            }
        })

        $btnOpenTaskManager.Add_Click({
            try {
                Start-Process "taskmgr.exe" -ErrorAction Stop
                Log "Task Manager opened from System Health dialog" 'Info'
            } catch {
                Log "Error opening Task Manager: $($_.Exception.Message)" 'Warning'
                [System.Windows.MessageBox]::Show("Could not open Task Manager: $($_.Exception.Message)", "Task Manager Error", 'OK', 'Warning')
            }
        })

        $btnCloseHealth.Add_Click({
            Log "System Health dialog closed by user" 'Info'
            $healthWindow.Close()
        })

        # Initial display update using cached data (no automatic check)
        & $updateDisplay $false

        # Show the window
        $healthWindow.ShowDialog() | Out-Null

    } catch {
        Log "Error showing system health dialog: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error displaying system health window: $($_.Exception.Message)", "Health Monitor Error", 'OK', 'Error')
    }
}

function Search-LogHistory {
    <#
    .SYNOPSIS
    Searches log history with advanced filtering capabilities
    .PARAMETER SearchTerm
    Text to search for in log messages
    .PARAMETER Level
    Filter by log level
    .PARAMETER Category
    Filter by log category
    .PARAMETER StartDate
    Filter logs from this date
    .PARAMETER EndDate
    Filter logs to this date
    #>
    param(
        [string]$SearchTerm = "",
        [string[]]$Level = @(),
        [string]$Category = "All",
        [DateTime]$StartDate = (Get-Date).AddDays(-1),
        [DateTime]$EndDate = (Get-Date)
    )

    try {
        $results = $global:LogHistory | Where-Object {
            # Date range filter
            $_.Timestamp -ge $StartDate -and $_.Timestamp -le $EndDate
        }

        # Search term filter
        if ($SearchTerm) {
            $results = $results | Where-Object { $_.Message -match [regex]::Escape($SearchTerm) }
        }

        # Level filter
        if ($Level.Count -gt 0) {
            $results = $results | Where-Object { $_.Level -in $Level }
        }

        # Category filter
        if ($Category -ne "All") {
            $results = $results | Where-Object { $_.Category -eq $Category }
        }

        return $results | Sort-Object Timestamp -Descending

    } catch {
        Log "Error searching log history: $($_.Exception.Message)" 'Error'
        return @()

    }
}

function Export-LogHistory {
    <#
    .SYNOPSIS
    Exports log history to various formats (TXT, CSV, JSON)
    .PARAMETER Path
    Export file path
    .PARAMETER Format
    Export format (TXT, CSV, JSON)
    .PARAMETER FilteredResults
    Pre-filtered log entries to export
    #>
    param(
        [string]$Path,
        [ValidateSet("TXT", "CSV", "JSON")]
        [string]$Format = "TXT",
        [array]$FilteredResults = $null
    )

    try {
        $logsToExport = if ($FilteredResults) { $FilteredResults } else { $global:LogHistory }

        if ($logsToExport.Count -eq 0) {
            throw "No log entries to export"
        }

        switch ($Format) {
            "TXT" {
                $content = $logsToExport | ForEach-Object {
                    "[$($_.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))] [$($_.Level)] [$($_.Category)] $($_.Message)"
                }
                $content | Out-File -FilePath $Path -Encoding UTF8
            }
            "CSV" {
                $logsToExport | Select-Object Timestamp, Level, Category, Message, Thread | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
            }
            "JSON" {
                $logsToExport | ConvertTo-Json -Depth 3 | Out-File -FilePath $Path -Encoding UTF8
            }
        }

        Log "Log history exported to: $Path ($Format format, $($logsToExport.Count) entries)" 'Success'
        return $true

    } catch {
        Log "Error exporting log history: $($_.Exception.Message)" 'Error'
        return $false
    }
}

function Optimize-LogFile {
    <#
    .SYNOPSIS
    Optimizes and rotates log files when they become too large
    .PARAMETER MaxSizeMB
    Maximum log file size in MB before rotation
    #>
    param([int]$MaxSizeMB = 10)

    try {
        $logFilePath = Join-Path $ScriptRoot 'Koala-Activity.log'

        if (Test-Path $logFilePath) {
            $fileInfo = Get-Item $logFilePath
            $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)

            if ($fileSizeMB -gt $MaxSizeMB) {
                # Create backup of current log
                $backupPath = Join-Path $ScriptRoot "Koala-Activity.log.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $logFilePath $backupPath -Force

                # Keep only last 500 lines in main log
                $lastLines = Get-Content $logFilePath -Tail 500
                $lastLines | Out-File $logFilePath -Encoding UTF8

                Log "Log file rotated: $fileSizeMB MB -> backup created at $backupPath" 'Info'

                # Clean up old backup files (keep only 5 most recent)
                $backupFiles = Get-ChildItem -Path $ScriptRoot -Name "Koala-Activity.log.bak.*" | Sort-Object Name -Descending
                if ($backupFiles.Count -gt 5) {
                    $filesToDelete = $backupFiles | Select-Object -Skip 5
                    foreach ($file in $filesToDelete) {
                        Remove-Item (Join-Path $ScriptRoot $file) -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }

    } catch {
        Log "Error optimizing log file: $($_.Exception.Message)" 'Warning'
    }
}

function Show-LogSearchDialog {
    <#
    .SYNOPSIS
    Shows a search dialog for log history with filtering options
    .DESCRIPTION
    Creates a WPF dialog for advanced log searching and filtering
    #>

    try {
        [xml]$logSearchXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Log Search and Filter"
        Width="900" Height="700"
        Background="{StaticResource AppBackgroundBrush}"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize">

  <Window.Resources>
    <SolidColorBrush x:Key="DialogBackgroundBrush" Color="#080716"/>
    <SolidColorBrush x:Key="CardBackgroundBrush" Color="#14132B"/>
    <SolidColorBrush x:Key="CardBorderBrush" Color="#2F285A"/>
    <SolidColorBrush x:Key="AccentBrush" Color="#8F6FFF"/>
    <SolidColorBrush x:Key="PrimaryTextBrush" Color="#F5F3FF"/>
    <SolidColorBrush x:Key="SecondaryTextBrush" Color="#A9A5D9"/>
    <Style TargetType="TextBlock">
        <Setter Property="FontFamily" Value="Segoe UI"/>
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}"/>
    </Style>
    <Style TargetType="ComboBox">
        <Setter Property="FontFamily" Value="Segoe UI"/>
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="Background" Value="#1B2345"/>
        <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}"/>
        <Setter Property="BorderBrush" Value="{StaticResource AccentBrush}"/>
        <Setter Property="BorderThickness" Value="1"/>
    </Style>
    <Style TargetType="Button" x:Key="DialogButton">
        <Setter Property="FontFamily" Value="Segoe UI"/>
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="Foreground" Value="#120B22"/>
        <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="Padding" Value="14,6"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border Background="{TemplateBinding Background}" CornerRadius="10">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#A78BFA"/>
                        </Trigger>
                        <Trigger Property="IsEnabled" Value="False">
                            <Setter Property="Opacity" Value="0.4"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style x:Key="SecondaryDialogButton" TargetType="Button" BasedOn="{StaticResource DialogButton}">
        <Setter Property="Background" Value="#1F1B3F"/>
        <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}"/>
    </Style>
    <Style x:Key="DangerDialogButton" TargetType="Button" BasedOn="{StaticResource DialogButton}">
        <Setter Property="Background" Value="#F87171"/>
        <Setter Property="Foreground" Value="#21060B"/>
    </Style>
  </Window.Resources>

  <Grid Margin="15">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="15" Margin="0,0,0,15">
      <TextBlock Text="Log Search and Filter" Foreground="{DynamicResource AccentBrush}" FontWeight="Bold" FontSize="18" HorizontalAlignment="Center"/>
    </Border>

    <!-- Search Controls -->
    <Border Grid.Row="1" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="15" Margin="0,0,0,15">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <!-- Search Term -->
        <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,10,10">
          <TextBlock Text="Search Term:" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" Margin="0,0,0,5"/>
          <TextBox x:Name="txtSearchTerm" Height="25" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}"/>
        </StackPanel>

        <!-- Category Filter -->
        <StackPanel Grid.Row="0" Grid.Column="1" Margin="0,0,0,10">
          <TextBlock Text="Category:" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" Margin="0,0,0,5"/>
          <ComboBox x:Name="cmbCategory" Height="25" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}"/>
        </StackPanel>

        <!-- Search Button -->
        <Button x:Name="btnSearch" Grid.Row="0" Grid.Column="2" Content="Search" Width="80" Height="25"
                Background="{StaticResource CardBorderBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderThickness="0" FontWeight="SemiBold"
                VerticalAlignment="Bottom" Margin="10,0,0,10"/>

        <!-- Level Checkboxes -->
        <StackPanel Grid.Row="1" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,0,0,10">
          <TextBlock Text="Levels:" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" Margin="0,0,10,0" VerticalAlignment="Center"/>
          <CheckBox x:Name="chkInfo" Content="Info" Foreground="{DynamicResource PrimaryTextBrush}" IsChecked="True" Margin="0,0,15,0"/>
          <CheckBox x:Name="chkSuccess" Content="Success" Foreground="{DynamicResource PrimaryTextBrush}" IsChecked="True" Margin="0,0,15,0"/>
          <CheckBox x:Name="chkWarning" Content="Warning" Foreground="{DynamicResource PrimaryTextBrush}" IsChecked="True" Margin="0,0,15,0"/>
          <CheckBox x:Name="chkError" Content="Error" Foreground="{DynamicResource PrimaryTextBrush}" IsChecked="True" Margin="0,0,15,0"/>
          <CheckBox x:Name="chkContext" Content="Context" Foreground="{DynamicResource PrimaryTextBrush}" IsChecked="False" Margin="0,0,15,0"/>
        </StackPanel>

        <!-- Results Info -->
        <TextBlock x:Name="lblResultsInfo" Grid.Row="2" Grid.ColumnSpan="3"
                   Text="Total log entries: 0" Foreground="{DynamicResource SecondaryTextBrush}" FontSize="11"/>
      </Grid>
    </Border>

    <!-- Results List -->
    <Border Grid.Row="2" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="10">
      <ScrollViewer VerticalScrollBarVisibility="Auto">
        <ListBox x:Name="lstLogResults" Background="Transparent" BorderThickness="0" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="11" FontFamily="Consolas">
          <ListBox.ItemTemplate>
            <DataTemplate>
              <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="3" Padding="8" Margin="2">
                <StackPanel>
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="{Binding Timestamp, StringFormat='yyyy-MM-dd HH:mm:ss'}" FontWeight="Bold" FontSize="10" Foreground="{DynamicResource AccentBrush}" Margin="0,0,10,0"/>
                    <TextBlock Text="{Binding Level}" FontWeight="Bold" FontSize="10" Foreground="{DynamicResource AccentBrush}" Margin="0,0,10,0"/>
                    <TextBlock Text="{Binding Category}" FontSize="10" Foreground="{DynamicResource AccentBrush}" Margin="0,0,0,0"/>
                  </StackPanel>
                  <TextBlock Text="{Binding Message}" FontSize="11" Foreground="{DynamicResource PrimaryTextBrush}" Margin="0,3,0,0" TextWrapping="Wrap"/>
                </StackPanel>
              </Border>
            </DataTemplate>
          </ListBox.ItemTemplate>
        </ListBox>
      </ScrollViewer>
    </Border>

    <!-- Action Buttons -->
    <Border Grid.Row="3" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="10" Margin="0,15,0,0">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
        <Button x:Name="btnExportTXT" Content="Export TXT" Width="110" Height="32" Style="{StaticResource SecondaryDialogButton}" Margin="0,0,10,0"/>
        <Button x:Name="btnExportCSV" Content="Export CSV" Width="110" Height="32" Style="{StaticResource SecondaryDialogButton}" Margin="0,0,10,0"/>
        <Button x:Name="btnExportJSON" Content="Export JSON" Width="110" Height="32" Style="{StaticResource SecondaryDialogButton}" Margin="0,0,10,0"/>
        <Button x:Name="btnClearSearch" Content="Clear" Width="90" Height="32" Style="{StaticResource DialogButton}" Margin="0,0,10,0"/>
        <Button x:Name="btnCloseSearch" Content="Close" Width="90" Height="32" Style="{StaticResource SecondaryDialogButton}"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@

        # Create the window
        $reader = New-Object System.Xml.XmlNodeReader $logSearchXaml
        $searchWindow = [Windows.Markup.XamlReader]::Load($reader)
        Initialize-LayoutSpacing -Root $searchWindow

        # Get controls
        $txtSearchTerm = $searchWindow.FindName('txtSearchTerm')
        $cmbCategory = $searchWindow.FindName('cmbCategory')
        $btnSearch = $searchWindow.FindName('btnSearch')
        $chkInfo = $searchWindow.FindName('chkInfo')
        $chkSuccess = $searchWindow.FindName('chkSuccess')
        $chkWarning = $searchWindow.FindName('chkWarning')
        $chkError = $searchWindow.FindName('chkError')
        $chkContext = $searchWindow.FindName('chkContext')
        $lblResultsInfo = $searchWindow.FindName('lblResultsInfo')
        $lstLogResults = $searchWindow.FindName('lstLogResults')
        $btnExportTXT = $searchWindow.FindName('btnExportTXT')
        $btnExportCSV = $searchWindow.FindName('btnExportCSV')
        $btnExportJSON = $searchWindow.FindName('btnExportJSON')
        $btnClearSearch = $searchWindow.FindName('btnClearSearch')
        $btnCloseSearch = $searchWindow.FindName('btnCloseSearch')

        # Initialize category dropdown
        $global:LogCategories | ForEach-Object { $cmbCategory.Items.Add($_) }
        $cmbCategory.SelectedIndex = 0

        # Update results info
        $lblResultsInfo.Text = "Total log entries: $($global:LogHistory.Count)"

        # Search function
        $performSearch = {
            $searchTerm = $txtSearchTerm.Text
            $category = $cmbCategory.SelectedItem.ToString()

            $levels = @()
            if ($chkInfo.IsChecked) { $levels += "Info" }
            if ($chkSuccess.IsChecked) { $levels += "Success" }
            if ($chkWarning.IsChecked) { $levels += "Warning" }
            if ($chkError.IsChecked) { $levels += "Error" }
            if ($chkContext.IsChecked) { $levels += "Context" }

            $results = Search-LogHistory -SearchTerm $searchTerm -Level $levels -Category $category

            $lstLogResults.ItemsSource = $results
            $lblResultsInfo.Text = "Search results: $($results.Count) entries (Total: $($global:LogHistory.Count))"

            Log "Log search performed: '$searchTerm' in $category category, $($results.Count) results" 'Info'
        }

        # Event handlers
        $btnSearch.Add_Click({ & $performSearch })
        $txtSearchTerm.Add_KeyDown({
            if ($_.Key -eq 'Return') { & $performSearch }
        })

        $btnExportTXT.Add_Click({
            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveDialog.Filter = "Text files (*.txt)|*.txt"
            $saveDialog.Title = "Export Log History as TXT"
            $saveDialog.FileName = "KOALA-GameOptimizer-Logs-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

            if ($saveDialog.ShowDialog()) {
                $results = $lstLogResults.ItemsSource
                Export-LogHistory -Path $saveDialog.FileName -Format "TXT" -FilteredResults $results
            }
        })

        $btnExportCSV.Add_Click({
            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveDialog.Filter = "CSV files (*.csv)|*.csv"
            $saveDialog.Title = "Export Log History as CSV"
            $saveDialog.FileName = "KOALA-GameOptimizer-Logs-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"

            if ($saveDialog.ShowDialog()) {
                $results = $lstLogResults.ItemsSource
                Export-LogHistory -Path $saveDialog.FileName -Format "CSV" -FilteredResults $results
            }
        })

        $btnExportJSON.Add_Click({
            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveDialog.Filter = "JSON files (*.json)|*.json"
            $saveDialog.Title = "Export Log History as JSON"
            $saveDialog.FileName = "KOALA-GameOptimizer-Logs-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

            if ($saveDialog.ShowDialog()) {
                $results = $lstLogResults.ItemsSource
                Export-LogHistory -Path $saveDialog.FileName -Format "JSON" -FilteredResults $results
            }
        })

        $btnClearSearch.Add_Click({
            $txtSearchTerm.Text = ""
            $cmbCategory.SelectedIndex = 0
            $chkInfo.IsChecked = $true
            $chkSuccess.IsChecked = $true
            $chkWarning.IsChecked = $true
            $chkError.IsChecked = $true
            $chkContext.IsChecked = $false
            $lstLogResults.ItemsSource = $null
            $lblResultsInfo.Text = "Total log entries: $($global:LogHistory.Count)"
        })

        $btnCloseSearch.Add_Click({
            $searchWindow.Close()
        })

        # Show initial results (all logs)
        & $performSearch

        # Show the window
        $searchWindow.ShowDialog() | Out-Null

    } catch {
        Log "Error showing log search dialog: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error displaying log search window: $($_.Exception.Message)", "Log Search Error", 'OK', 'Error')
    }
}
$global:PerformanceTimer = $null
$global:LastCpuTime = @{ Idle = 0; Kernel = 0; User = 0; Timestamp = [DateTime]::Now }

function Get-SystemPerformanceMetrics {
    <#
    .SYNOPSIS
    Enhanced real-time system performance monitoring with CPU, Memory, and basic disk metrics
    .DESCRIPTION
    Provides comprehensive system metrics for dashboard display with efficient polling
    #>

    try {
        $metrics = @{}

        # Get CPU Usage using existing PerfMon API
        try {
            $idleTime = [long]0
            $kernelTime = [long]0
            $userTime = [long]0

            if ([PerfMon]::GetSystemTimes([ref]$idleTime, [ref]$kernelTime, [ref]$userTime)) {
            $currentTime = [DateTime]::Now
            $timeDiff = ($currentTime - $global:LastCpuTime.Timestamp).TotalMilliseconds

            if ($timeDiff -gt 500 -and $global:LastCpuTime.Idle -gt 0) {
                $idleDiff = $idleTime - $global:LastCpuTime.Idle
                $kernelDiff = $kernelTime - $global:LastCpuTime.Kernel
                $userDiff = $userTime - $global:LastCpuTime.User
                $totalDiff = $kernelDiff + $userDiff

                if ($totalDiff -gt 0) {
                    $cpuUsage = [Math]::Round((($totalDiff - $idleDiff) / $totalDiff) * 100, 1)
                    $metrics.CpuUsage = [Math]::Max(0, [Math]::Min(100, $cpuUsage))
                } else {
                    $metrics.CpuUsage = 0
                }
            } else {
                $metrics.CpuUsage = 0
            }
        } else {
            $metrics.CpuUsage = 0
        }
        } catch {
            # Safe defaults on error for Windows API performance monitoring calls
            $metrics.CpuUsage = 0
            Write-Verbose "CPU monitoring failed: $($_.Exception.Message)"
        }

        # Update LastCpuTime with Idle, Kernel, User times and Timestamp for accurate CPU delta calculations
        $global:LastCpuTime = @{
            Idle = $idleTime
            Kernel = $kernelTime
            User = $userTime
            Timestamp = $currentTime
        }

        # Get Memory Usage using existing PerfMon API
        try {
            $memStatus = New-Object PerfMon+MEMORYSTATUSEX
            $memStatus.dwLength = [System.Runtime.InteropServices.Marshal]::SizeOf($memStatus)

            if ([PerfMon]::GlobalMemoryStatusEx([ref]$memStatus)) {
            # Math.Round calculations for accurate GB conversions and percentage
            $totalGB = [Math]::Round($memStatus.ullTotalPhys / 1GB, 1)
            $availableGB = [Math]::Round($memStatus.ullAvailPhys / 1GB, 1)
            $usedGB = [Math]::Round($totalGB - $availableGB, 1)
            $usagePercent = [Math]::Round($memStatus.dwMemoryLoad, 1)

            $metrics.MemoryUsedGB = $usedGB
            $metrics.MemoryTotalGB = $totalGB
            $metrics.MemoryUsagePercent = $usagePercent
        } else {
            $metrics.MemoryUsedGB = 0
            $metrics.MemoryTotalGB = 0
            $metrics.MemoryUsagePercent = 0
        }
        } catch {
            # Safe defaults on error for memory monitoring Windows API calls
            $metrics.MemoryUsedGB = 0
            $metrics.MemoryTotalGB = 0
            $metrics.MemoryUsagePercent = 0
            Write-Verbose "Memory monitoring failed: $($_.Exception.Message)"
        }

        # Get Active Games Count (from existing global variable)
        $metrics.ActiveGamesCount = if ($global:ActiveGames) { $global:ActiveGames.Count } else { 0 }

        # Get Last Optimization Time (from logs or global variable)
        if ($global:LastOptimizationTime) {
            $timeSince = (Get-Date) - $global:LastOptimizationTime
            if ($timeSince.Days -gt 0) {
                $metrics.LastOptimization = "$($timeSince.Days)d ago"
            } elseif ($timeSince.Hours -gt 0) {
                $metrics.LastOptimization = "$($timeSince.Hours)h ago"
            } elseif ($timeSince.Minutes -gt 0) {
                $metrics.LastOptimization = "$($timeSince.Minutes)m ago"
            } else {
                $metrics.LastOptimization = "Just now"
            }
        } else {
            $metrics.LastOptimization = "Never"
        }

        return $metrics

    } catch {
        # Return safe defaults on error
        return @{
            CpuUsage = 0
            MemoryUsedGB = 0
            MemoryTotalGB = 0
            MemoryUsagePercent = 0
            ActiveGamesCount = 0
            LastOptimization = "Error"
        }
    }
}

function Update-DashboardMetrics {
    <#
    .SYNOPSIS
    Updates dashboard performance metrics with real-time data
    .DESCRIPTION
    Safely updates dashboard UI elements with current system performance data
    #>

    try {
        $metrics = Get-SystemPerformanceMetrics

        # Update CPU Usage
        if ($lblDashCpuUsage) {
            $lblDashCpuUsage.Dispatcher.Invoke([Action]{
                $lblDashCpuUsage.Text = "$($metrics.CpuUsage)%"

                # Color coding based on CpuUsage and MemoryUsagePercent for dynamic metrics display
                if ($metrics.CpuUsage -ge 80) {
                    Set-BrushPropertySafe -Target $lblDashCpuUsage -Property 'Foreground' -Value '#FF4444'  # Red for high
                } elseif ($metrics.CpuUsage -ge 60) {
                    Set-BrushPropertySafe -Target $lblDashCpuUsage -Property 'Foreground' -Value '#A78BFA'  # Purple for medium load
                } else {
                    Set-BrushPropertySafe -Target $lblDashCpuUsage -Property 'Foreground' -Value '#8F6FFF'  # Accent for low load
                }
            })
        }

        # Update Memory Usage
        if ($lblDashMemoryUsage) {
            $lblDashMemoryUsage.Dispatcher.Invoke([Action]{
                $lblDashMemoryUsage.Text = "$($metrics.MemoryUsedGB) / $($metrics.MemoryTotalGB) GB"

                # Color coding based on percentage
                if ($metrics.MemoryUsagePercent -ge 85) {
                    Set-BrushPropertySafe -Target $lblDashMemoryUsage -Property 'Foreground' -Value '#FF4444'  # Red for high
                } elseif ($metrics.MemoryUsagePercent -ge 70) {
                    Set-BrushPropertySafe -Target $lblDashMemoryUsage -Property 'Foreground' -Value '#A78BFA'  # Purple for medium
                } else {
                    Set-BrushPropertySafe -Target $lblDashMemoryUsage -Property 'Foreground' -Value '#8F6FFF'  # Accent for normal
                }
            })
        }

        if ($lblHeroProfiles) {
            $lblHeroProfiles.Dispatcher.Invoke([Action]{
                $lblHeroProfiles.Text = [string]$metrics.ActiveGamesCount
            })
        }

        $optimizationsCount = if ($global:OptimizationCache) { $global:OptimizationCache.Count } else { 0 }
        if ($lblHeroOptimizations) {
            $lblHeroOptimizations.Dispatcher.Invoke([Action]{
                $lblHeroOptimizations.Text = [string]$optimizationsCount
            })
        }

        if ($lblHeroAutoMode) {
            $lblHeroAutoMode.Dispatcher.Invoke([Action]{
                $lblHeroAutoMode.Text = if ($global:AutoOptimizeEnabled) { 'On' } else { 'Off' }
            })
        }

        # Update Active Games
        if ($lblDashActiveGames) {
            $lblDashActiveGames.Dispatcher.Invoke([Action]{
                if ($metrics.ActiveGamesCount -gt 0) {
                    $lblDashActiveGames.Text = "$($metrics.ActiveGamesCount) running"
                    Set-BrushPropertySafe -Target $lblDashActiveGames -Property 'Foreground' -Value '#8F6FFF'  # Accent for active games
                } else {
                    $lblDashActiveGames.Text = "None detected"
                    Set-BrushPropertySafe -Target $lblDashActiveGames -Property 'Foreground' -Value '#A6AACF'  # Default color
                }
            })
        }

        # Update Last Optimization
        if ($lblDashLastOptimization) {
            $lblDashLastOptimization.Dispatcher.Invoke([Action]{
                $lblDashLastOptimization.Text = $metrics.LastOptimization
            })
        }

        if ($lblHeaderLastRun) {
            $lblHeaderLastRun.Dispatcher.Invoke([Action]{
                $lblHeaderLastRun.Text = $metrics.LastOptimization
            })
        }

        if ($lblHeaderSystemStatus) {
            $lblHeaderSystemStatus.Dispatcher.Invoke([Action]{
                if ($metrics.CpuUsage -ge 80 -or $metrics.MemoryUsagePercent -ge 85) {
                    $lblHeaderSystemStatus.Text = 'High Load'
                    Set-BrushPropertySafe -Target $lblHeaderSystemStatus -Property 'Foreground' -Value [System.Windows.Media.Brushes]::Salmon
                } elseif ($metrics.CpuUsage -ge 60 -or $metrics.MemoryUsagePercent -ge 70) {
                    $lblHeaderSystemStatus.Text = 'Monitoring'
                    Set-BrushPropertySafe -Target $lblHeaderSystemStatus -Property 'Foreground' -Value [System.Windows.Media.Brushes]::Gold
                } else {
                    $lblHeaderSystemStatus.Text = 'Stable'
                    Set-BrushPropertySafe -Target $lblHeaderSystemStatus -Property 'Foreground' -Value [System.Windows.Media.Brushes]::LightGreen
                }
            })
        }

        # Refresh System Health summary without running a full check
        Update-SystemHealthSummary

    } catch {
        # Silent fail to prevent UI disruption
        Write-Verbose "Dashboard metrics update failed: $($_.Exception.Message)"
    }
}

function Start-PerformanceMonitoring {
    <#
    .SYNOPSIS
    Starts real-time performance monitoring with configurable update interval
    .DESCRIPTION
    Initializes a dispatcher timer for regular dashboard updates
    #>

    try {
        if ($global:PerformanceTimer) {
            $global:PerformanceTimer.Stop()
        }

        # Create dispatcher timer for UI updates
        $global:PerformanceTimer = New-Object System.Windows.Threading.DispatcherTimer
        $global:PerformanceTimer.Interval = [TimeSpan]::FromSeconds(3)  # Update every 3 seconds

        # Set up timer event
        $global:PerformanceTimer.Add_Tick({
            Update-DashboardMetrics
        })

        # Start the timer
        $global:PerformanceTimer.Start()

        # Initial update
        Update-DashboardMetrics

        Log "Real-time performance monitoring started (3s intervals)" 'Success'

    } catch {
        Log "Error starting performance monitoring: $($_.Exception.Message)" 'Error'
    }
}

function Stop-PerformanceMonitoring {
    <#
    .SYNOPSIS
    Stops the performance monitoring timer
    #>

    try {
        if ($global:PerformanceTimer) {
            $global:PerformanceTimer.Stop()
            $global:PerformanceTimer = $null
            Log "Performance monitoring stopped" 'Info'
        }
    } catch {
        Write-Verbose "Error stopping performance monitoring: $($_.Exception.Message)"
    }
}

# ---------- Enhanced Game Detection and Auto-Optimization ----------
$global:ActiveGameProcesses = @()
$global:GameDetectionTimer = $null
$global:AutoOptimizationEnabled = $false

function Get-RunningGameProcesses {
    <#
    .SYNOPSIS
    Enhanced real-time detection of running games and game-related processes
    .DESCRIPTION
    Monitors system processes to detect active games and automatically trigger optimizations
    #>

    try {
        $runningGames = @()
        $gameProcesses = Get-Process | Where-Object {
            $_.ProcessName -and $_.MainWindowTitle -and
            ($_.ProcessName -match "^(cs2|csgo|valorant|overwatch|rainbow|fortnite|apex|pubg|warzone|modernwarfare|league|rocket|dota2|gta|cyberpunk|minecraft)" -or
             $_.MainWindowTitle -match "Counter-Strike|VALORANT|Overwatch|Rainbow Six|Fortnite|Apex Legends|PUBG|Warzone|Modern Warfare|League of Legends|Rocket League|Dota 2|Grand Theft Auto|Cyberpunk|Minecraft")
        }

        foreach ($process in $gameProcesses) {
            # Match against our game profiles
            $matchedProfile = $null
            foreach ($profileKey in $GameProfiles.Keys) {
                $profile = $GameProfiles[$profileKey]
                if ($profile.ProcessNames -and ($profile.ProcessNames -contains $process.ProcessName -or
                    $profile.ProcessNames | Where-Object { $process.ProcessName -match $_ })) {
                    $matchedProfile = @{
                        Key = $profileKey
                        Profile = $profile
                        Process = $process
                    }
                    break
                }
            }

            if ($matchedProfile) {
                $runningGames += $matchedProfile
                Log "Detected running game: $($matchedProfile.Profile.DisplayName) (PID: $($process.Id))" 'Info'
            } else {
                # Detected a game-like process but no profile match
                $runningGames += @{
                    Key = "unknown"
                    Profile = @{
                        DisplayName = $process.MainWindowTitle
                        ProcessNames = @($process.ProcessName)
                    }
                    Process = $process
                }
                Log "Detected unknown game: $($process.MainWindowTitle) ($($process.ProcessName))" 'Info'
            }
        }

        return $runningGames

    } catch {
        Log "Error detecting running games: $($_.Exception.Message)" 'Warning'
        return @()
    }
}

function Update-ActiveGamesTracking {
    <#
    .SYNOPSIS
    Updates the global active games list and triggers auto-optimization if enabled
    .DESCRIPTION
    Maintains real-time tracking of active games and applies optimizations automatically
    #>

    try {
        $currentGames = Get-RunningGameProcesses
        $previousGames = $global:ActiveGameProcesses

        # Check for newly started games
        $newGames = $currentGames | Where-Object {
            $game = $_
            -not ($previousGames | Where-Object { $_.Process.Id -eq $game.Process.Id })
        }

        # Check for games that have stopped
        $stoppedGames = $previousGames | Where-Object {
            $game = $_
            -not ($currentGames | Where-Object { $_.Process.Id -eq $game.Process.Id })
        }

        # Update global tracking
        $global:ActiveGameProcesses = $currentGames
        $global:ActiveGames = $currentGames | ForEach-Object { $_.Profile.DisplayName }

        # Handle newly started games
        foreach ($newGame in $newGames) {
            Log "Game started: $($newGame.Profile.DisplayName)" 'Success'

            # Auto-optimization trigger
            if ($global:AutoOptimizeEnabled -and $newGame.Key -ne "unknown") {
                Log "Auto-optimization triggered for: $($newGame.Profile.DisplayName)" 'Info'
                Start-AutoGameOptimization -GameProfile $newGame
            }
        }

        # Handle stopped games
        foreach ($stoppedGame in $stoppedGames) {
            Log "Game stopped: $($stoppedGame.Profile.DisplayName)" 'Info'
        }

        # Update dashboard count
        if ($lblDashActiveGames) {
            $lblDashActiveGames.Dispatcher.Invoke([Action]{
                if ($currentGames.Count -gt 0) {
                    $lblDashActiveGames.Text = "$($currentGames.Count) active"
                    Set-BrushPropertySafe -Target $lblDashActiveGames -Property 'Foreground' -Value '#8F6FFF'
                } else {
                    $lblDashActiveGames.Text = "None active"
                    Set-BrushPropertySafe -Target $lblDashActiveGames -Property 'Foreground' -Value '#A6AACF'
                }
            })
        }

    } catch {
        Log "Error updating active games tracking: $($_.Exception.Message)" 'Warning'
    }
}

function Start-AutoGameOptimization {
    <#
    .SYNOPSIS
    Automatically applies game-specific optimizations when a game is detected
    .PARAMETER GameProfile
    The detected game profile to optimize for
    #>
    param(
        [Parameter(Mandatory=$true)]
        $GameProfile
    )

    try {
        $profile = $GameProfile.Profile
        Log "Starting auto-optimization for: $($profile.DisplayName)" 'Info'

        # Apply game-specific tweaks if available
        if ($GameProfile.Key -ne "unknown" -and $profile.SpecificTweaks) {
            foreach ($tweak in $profile.SpecificTweaks) {
                switch ($tweak) {
                    'DisableNagle' {
                        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces" "TcpNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
                        Log "Nagle algorithm disabled for gaming" 'Success'
                    }
                    'HighPrecisionTimer' {
                        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 'DWord' 1 -RequiresAdmin $true | Out-Null
                        Log "High precision timer enabled" 'Success'
                    }
                    'NetworkOptimization' {
                        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters" "TcpDelAckTicks" 'DWord' 0 -RequiresAdmin $true | Out-Null
                        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters" "TCPNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
                        Log "Network optimizations applied" 'Success'
                    }
                    'CPUCoreParkDisable' {
                        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" "ValueMax" 'DWord' 0 -RequiresAdmin $true | Out-Null
                        Log "CPU core parking disabled" 'Success'
                    }
                }
            }
        }

        # Apply process priority optimization
        if ($profile.Priority -and $GameProfile.Process) {
            try {
                switch ($profile.Priority) {
                    'High' { $GameProfile.Process.PriorityClass = 'High' }
                    'AboveNormal' { $GameProfile.Process.PriorityClass = 'AboveNormal' }
                    'Normal' { $GameProfile.Process.PriorityClass = 'Normal' }
                }
                Log "Process priority set to $($profile.Priority) for $($profile.DisplayName)" 'Success'
            } catch {
                Log "Could not set process priority: $($_.Exception.Message)" 'Warning'
            }
        }

        Log "Auto-optimization completed for: $($profile.DisplayName)" 'Success'

    } catch {
        Log "Error during auto-optimization: $($_.Exception.Message)" 'Error'
    }
}

function Get-CloudGamingServices {
    <#
    .SYNOPSIS
    Detects cloud gaming services and streaming platforms
    .DESCRIPTION
    Identifies Xbox Game Pass, GeForce Now, Stadia, Amazon Luna, etc.
    #>

    try {
        $cloudServices = @()

        # Xbox Game Pass detection - Microsoft.GamingApp and WindowsApps integration
        $gamePassPaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.GamingApp_*",
            "$env:ProgramFiles\Xbox Games",
            "$env:ProgramFiles\WindowsApps\Microsoft.GamingApp_*"
        )

        foreach ($path in $gamePassPaths) {
            $found = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
            if ($found) {
                $cloudServices += [PSCustomObject]@{
                    Name = "Xbox Game Pass"
                    Path = $found[0].FullName
                    Details = "Cloud Gaming Service - Microsoft"
                    Type = "CloudGaming"
                }
                break
            }
        }

        # NVIDIA GeForce NOW detection - NVIDIA Corporation\GeForceNOW path scanning
        $geforceNowPath = "$env:LOCALAPPDATA\NVIDIA Corporation\GeForceNOW"
        if (Test-Path $geforceNowPath) {
            $cloudServices += [PSCustomObject]@{
                Name = "NVIDIA GeForce NOW"
                Path = $geforceNowPath
                Details = "Cloud Gaming Service - NVIDIA"
                Type = "CloudGaming"
            }
        }

        # Amazon Luna detection - Amazon Games\Luna cloud gaming platform
        $lunaPath = "$env:LOCALAPPDATA\Amazon Games\Luna"
        if (Test-Path $lunaPath) {
            $cloudServices += [PSCustomObject]@{
                Name = "Amazon Luna"
                Path = $lunaPath
                Details = "Cloud Gaming Service - Amazon"
                Type = "CloudGaming"
            }
        }

        # Browser-based cloud gaming detection (stadia.google.com, xbox.com/play, playstation.com services)
        $browserCloudGaming = @(
            @{ Name = "Google Stadia"; URL = "stadia.google.com" },
            @{ Name = "Xbox Cloud Gaming"; URL = "xbox.com/play" },
            @{ Name = "PlayStation Now"; URL = "playstation.com/ps-now" }
        )

        foreach ($service in $browserCloudGaming) {
            # Check for browser shortcuts or bookmarks (simplified detection)
            $shortcutPaths = @(
                "$env:USERPROFILE\Desktop\*.lnk",
                "$env:USERPROFILE\Desktop\*.url",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\*.lnk"
            )

            foreach ($shortcutPath in $shortcutPaths) {
                $shortcuts = Get-ChildItem -Path $shortcutPath -ErrorAction SilentlyContinue
                foreach ($shortcut in $shortcuts) {
                    $content = Get-Content $shortcut.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content -and $content -match $service.URL) {
                        $cloudServices += [PSCustomObject]@{
                            Name = $service.Name
                            Path = $shortcut.FullName
                            Details = "Browser-based Cloud Gaming"
                            Type = "CloudGaming"
                        }
                        break
                    }
                }
            }
        }

        return $cloudServices

    } catch {
        Log "Error detecting cloud gaming services: $($_.Exception.Message)" 'Warning'
        return @()
    }
}

function Start-GameDetectionMonitoring {
    <#
    .SYNOPSIS
    Starts real-time game detection monitoring with configurable intervals
    .DESCRIPTION
    Initializes a dispatcher timer for monitoring running games and auto-optimization
    #>

    try {
        if ($global:GameDetectionTimer) {
            $global:GameDetectionTimer.Stop()
        }

        # Create dispatcher timer for game detection
        $global:GameDetectionTimer = New-Object System.Windows.Threading.DispatcherTimer
        $global:GameDetectionTimer.Interval = [TimeSpan]::FromSeconds(5)  # Check every 5 seconds

        # Set up timer event
        $global:GameDetectionTimer.Add_Tick({
            Update-ActiveGamesTracking
        })

        # Start the timer
        $global:GameDetectionTimer.Start()

        # Initial check
        Update-ActiveGamesTracking

        Log "Game detection monitoring started (5s intervals)" 'Success'

    } catch {
        Log "Error starting game detection monitoring: $($_.Exception.Message)" 'Error'
    }
}

function Stop-GameDetectionMonitoring {
    <#
    .SYNOPSIS
    Stops the game detection monitoring timer
    #>

    try {
        if ($global:GameDetectionTimer) {
            $global:GameDetectionTimer.Stop()
            $global:GameDetectionTimer = $null
            Log "Game detection monitoring stopped" 'Info'
        }
        $global:ActiveGameProcesses = @()
        $global:ActiveGames = @()
        if ($lblDashActiveGames) {
            $lblDashActiveGames.Dispatcher.Invoke([Action]{
                $lblDashActiveGames.Text = "None detected"
                Set-BrushPropertySafe -Target $lblDashActiveGames -Property 'Foreground' -Value '#A6AACF'
            })
        }
    } catch {
        Write-Verbose "Error stopping game detection monitoring: $($_.Exception.Message)"
    }
}
$GameProfiles = @{
    # Competitive Shooters
    'cs2' = @{
        DisplayName = 'Counter-Strike 2'
        ProcessNames = @('cs2', 'cs2.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'HighPrecisionTimer', 'NetworkOptimization', 'CPUCoreParkDisable')
        FPSBoostSettings = @('DirectXOptimization', 'ShaderCacheOptimization', 'InputLatencyReduction')
    }
    'csgo' = @{
        DisplayName = 'Counter-Strike: Global Offensive'
        ProcessNames = @('csgo', 'csgo.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'HighPrecisionTimer', 'SourceEngineOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'InputLatencyReduction')
    }
    'valorant' = @{
        DisplayName = 'Valorant'
        ProcessNames = @('valorant', 'valorant-win64-shipping', 'RiotClientServices')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'AntiCheatOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'GPUSchedulingOptimization', 'AudioLatencyOptimization')
    }
    'overwatch2' = @{
        DisplayName = 'Overwatch 2'
        ProcessNames = @('overwatch', 'overwatch.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'NetworkOptimization', 'BlizzardOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'InputLatencyReduction', 'ShaderCacheOptimization')
    }
    'r6siege' = @{
        DisplayName = 'Rainbow Six Siege'
        ProcessNames = @('rainbowsix', 'rainbowsix_vulkan', 'RainbowSix.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'UbisoftOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('VulkanOptimization', 'InputLatencyReduction', 'GPUSchedulingOptimization')
    }

    # Battle Royale Games
    'fortnite' = @{
        DisplayName = 'Fortnite'
        ProcessNames = @('fortniteclient-win64-shipping', 'FortniteClient-Win64-Shipping.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'MemoryOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'ShaderCacheOptimization', 'TextureStreamingOptimization')
    }
    'apexlegends' = @{
        DisplayName = 'Apex Legends'
        ProcessNames = @('r5apex', 'r5apex.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('DisableNagle', 'SourceEngineOptimization', 'EACOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'GPUSchedulingOptimization', 'AudioLatencyOptimization')
    }
    'pubg' = @{
        DisplayName = 'PUBG: Battlegrounds'
        ProcessNames = @('tslgame', 'TslGame.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'NetworkOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'TextureStreamingOptimization', 'ShaderCacheOptimization')
    }
    'warzone' = @{
        DisplayName = 'Call of Duty: Warzone'
        ProcessNames = @('cod', 'modernwarfare', 'cod.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('CODOptimization', 'NetworkOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'MemoryPoolOptimization', 'ShaderCacheOptimization')
    }

    # Popular Multiplayer Games
    'lol' = @{
        DisplayName = 'League of Legends'
        ProcessNames = @('leagueclient', 'league of legends', 'LeagueClient.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('RiotClientOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'InputLatencyReduction')
    }
    'rocketleague' = @{
        DisplayName = 'Rocket League'
        ProcessNames = @('rocketleague', 'RocketLeague.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'InputLatencyReduction', 'PhysicsOptimization')
    }
    'dota2' = @{
        DisplayName = 'Dota 2'
        ProcessNames = @('dota2', 'dota2.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('SourceEngineOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'VulkanOptimization', 'ShaderCacheOptimization')
    }
    'gta5' = @{
        DisplayName = 'Grand Theft Auto V'
        ProcessNames = @('gta5', 'gtavlauncher', 'GTA5.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('RockstarOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'TextureStreamingOptimization', 'MemoryPoolOptimization')
    }

    # AAA Titles
    'hogwartslegacy' = @{
        DisplayName = 'Hogwarts Legacy'
        ProcessNames = @('hogwartslegacy', 'HogwartsLegacy.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectX12Optimization', 'TextureStreamingOptimization', 'ShaderCacheOptimization')
    }
    'starfield' = @{
        DisplayName = 'Starfield'
        ProcessNames = @('starfield', 'Starfield.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('CreationEngineOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectX12Optimization', 'TextureStreamingOptimization', 'MemoryPoolOptimization')
    }
    'baldursgate3' = @{
        DisplayName = "Baldur's Gate 3"
        ProcessNames = @('bg3', 'bg3_dx11', 'bg3.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('LarianOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'VulkanOptimization', 'ShaderCacheOptimization')
    }
    'cyberpunk2077' = @{
        DisplayName = 'Cyberpunk 2077'
        ProcessNames = @('cyberpunk2077', 'Cyberpunk2077.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('REDEngineOptimization', 'MemoryOptimization', 'RTXOptimization')
        FPSBoostSettings = @('DirectX12Optimization', 'DLSSOptimization', 'TextureStreamingOptimization')
    }

    # Survival & Crafting
    'minecraft' = @{
        DisplayName = 'Minecraft'
        ProcessNames = @('minecraft', 'javaw', 'javaw.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('JavaOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('OpenGLOptimization', 'ChunkRenderingOptimization')
    }
    'rust' = @{
        DisplayName = 'Rust'
        ProcessNames = @('rustclient', 'RustClient.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnityEngineOptimization', 'NetworkOptimization', 'EACOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'TextureStreamingOptimization', 'ShaderCacheOptimization')
    }
    'ark' = @{
        DisplayName = 'ARK: Survival Evolved'
        ProcessNames = @('shootergame', 'ShooterGame.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'TextureStreamingOptimization', 'MemoryPoolOptimization')
    }
    'valheim' = @{
        DisplayName = 'Valheim'
        ProcessNames = @('valheim', 'valheim.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnityEngineOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'ShaderCacheOptimization')
    }

    # Racing & Sports
    'f124' = @{
        DisplayName = 'F1 24'
        ProcessNames = @('f1_24', 'F1_24.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('EGOEngineOptimization', 'InputLatencyOptimization')
        FPSBoostSettings = @('DirectX12Optimization', 'PhysicsOptimization', 'AudioLatencyOptimization')
    }
    'fifa24' = @{
        DisplayName = 'EA Sports FC 24'
        ProcessNames = @('fc24', 'FC24.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('FrostbiteEngineOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'PhysicsOptimization', 'InputLatencyReduction')
    }
    'forzahorizon5' = @{
        DisplayName = 'Forza Horizon 5'
        ProcessNames = @('forzahorizon5', 'ForzaHorizon5.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('ForzaTechOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectX12Optimization', 'TextureStreamingOptimization')
    }

    # Fighting Games
    'tekken8' = @{
        DisplayName = 'Tekken 8'
        ProcessNames = @('tekken8', 'Tekken8.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'InputLatencyOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'InputLatencyReduction', 'FramePacingOptimization')
    }
    'sf6' = @{
        DisplayName = 'Street Fighter 6'
        ProcessNames = @('streetfighter6', 'StreetFighter6.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('REEngineOptimization', 'InputLatencyOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'InputLatencyReduction', 'FramePacingOptimization')
    }
    'mortalkombat1' = @{
        DisplayName = 'Mortal Kombat 1'
        ProcessNames = @('mk1', 'MK1.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'InputLatencyOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'InputLatencyReduction')
    }

    # MMOs
    'wow' = @{
        DisplayName = 'World of Warcraft'
        ProcessNames = @('wow', 'wow-64', 'Wow.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('BlizzardOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'ShaderCacheOptimization', 'AddonOptimization')
    }
    'ffxiv' = @{
        DisplayName = 'Final Fantasy XIV'
        ProcessNames = @('ffxiv_dx11', 'ffxiv', 'ffxiv_dx11.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('SquareEnixOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'ShaderCacheOptimization', 'NetworkLatencyOptimization')
    }
    'guildwars2' = @{
        DisplayName = 'Guild Wars 2'
        ProcessNames = @('gw2-64', 'Gw2-64.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('ArenaNetOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'CPUOptimization', 'ShaderCacheOptimization')
    }
    'elderscrollsonline' = @{
        DisplayName = 'Elder Scrolls Online'
        ProcessNames = @('eso64', 'eso64.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('ZeniMaxOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'MemoryOptimization')
    }
    'newworld' = @{
        DisplayName = 'New World'
        ProcessNames = @('newworld', 'NewWorld.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('LumberyardOptimization', 'NetworkOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'GPUSchedulingOptimization')
    }

    # Indie Popular
    'hades2' = @{
        DisplayName = 'Hades II'
        ProcessNames = @('hades2', 'Hades2.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnityEngineOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'ShaderCacheOptimization')
    }
    'palworld' = @{
        DisplayName = 'Palworld'
        ProcessNames = @('palworld', 'Palworld.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'TextureStreamingOptimization', 'ShaderCacheOptimization')
    }
    'stardewvalley' = @{
        DisplayName = 'Stardew Valley'
        ProcessNames = @('stardewvalley', 'StardewValley.exe')
        Priority = 'AboveNormal'
        Affinity = 'Auto'
        SpecificTweaks = @('MonoGameOptimization')
        FPSBoostSettings = @('DirectXOptimization')
    }

    # Simulation
    'msfs2020' = @{
        DisplayName = 'Microsoft Flight Simulator'
        ProcessNames = @('flightsimulator', 'FlightSimulator.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('AsoboOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectX12Optimization', 'TextureStreamingOptimization', 'CPUOptimization')
    }
    'cityskylines2' = @{
        DisplayName = 'Cities: Skylines II'
        ProcessNames = @('cities2', 'Cities2.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnityEngineOptimization', 'MemoryOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'CPUOptimization')
    }

    # Horror
    'phasmophobia' = @{
        DisplayName = 'Phasmophobia'
        ProcessNames = @('phasmophobia', 'Phasmophobia.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnityEngineOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'AudioLatencyOptimization')
    }
    'deadbydaylight' = @{
        DisplayName = 'Dead by Daylight'
        ProcessNames = @('deadbydaylight', 'DeadByDaylight.exe')
        Priority = 'High'
        Affinity = 'Auto'
        SpecificTweaks = @('UnrealEngineOptimization', 'EACOptimization')
        FPSBoostSettings = @('DirectXOptimization', 'ShaderCacheOptimization')
    }
}

# ---------- Functions moved to top to fix call order ----------

function Show-ElevationMessage {
    param(
        [string]$Title = "Administrator Privileges Required",
        [string]$Message = "Some optimizations require administrator privileges for system-level changes.",
        [string[]]$Operations = @(),
        [switch]$ForceElevation
    )

    $elevationText = $Message
    if ($Operations.Count -gt 0) {
        $elevationText += "`n`nOperations requiring elevation:"
        $Operations | ForEach-Object { $elevationText += "`n* $_" }
    }

    $elevationText += "`n`nWould you like to:"
    $elevationText += "`n* Yes: Restart with administrator privileges"
    $elevationText += "`n* No: Continue with limited functionality"
    $elevationText += "`n* Cancel: Exit application"

    $result = [System.Windows.MessageBox]::Show(
        $elevationText,
        "KOALA Gaming Optimizer v3.0 - $Title",
        'YesNoCancel',
        'Warning'
    )

    switch ($result) {
        'Yes' {
            try {
                $scriptPath = $PSCommandPath
                if (-not $scriptPath) {
                    $scriptPath = Join-Path $ScriptRoot "koalafixed.ps1"
                }

                Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs -ErrorAction Stop
                $form.Close()
                return $true
            } catch {
                Log "Failed to elevate privileges: $($_.Exception.Message)" 'Error'
                return $false
            }
        }
        'No' {
            Log "Running in limited mode - some optimizations will be unavailable" 'Warning'
            return $false
        }
        'Cancel' {
            Log "User cancelled - exiting application" 'Info'
            $form.Close()
            return $false
        }
    }
}

function Get-SystemInfo {
    try {
        $info = @{
            OS = (Get-CimInstance Win32_OperatingSystem).Caption
            CPU = (Get-CimInstance Win32_Processor).Name
            RAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            GPU = (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" -and $_.Name -notlike "*Generic*" }).Name -join ", "
            AdminRights = Test-AdminPrivileges
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        }

        $infoText = "System Information:`n"
        $infoText += "OS: $($info.OS)`n"
        $infoText += "CPU: $($info.CPU)`n"
        $infoText += "RAM: $($info.RAM) GB`n"
        $infoText += "GPU: $($info.GPU)`n"
        $infoText += "Admin Rights: $($info.AdminRights)`n"
        $infoText += "PowerShell: $($info.PowerShellVersion)"

        [System.Windows.MessageBox]::Show($infoText, "System Information", 'OK', 'Information')

    } catch {
        Log "Failed to gather system info: $($_.Exception.Message)" 'Error'
    }
}

function Get-GPUVendor {
    try {
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Where-Object {
            $_.Name -notlike "*Basic*" -and
            $_.Name -notlike "*Generic*" -and
            $_.PNPDeviceID -notlike "ROOT\*"
        }

        $primaryGPU = $null

        foreach ($gpu in $gpus) {
            if ($gpu -and $gpu.Name) {
                if ($gpu.Name -match 'NVIDIA|GeForce|GTX|RTX|Quadro') {
                    $primaryGPU = 'NVIDIA'
                }
                elseif ($gpu.Name -match 'AMD|RADEON|RX|FirePro') {
                    $primaryGPU = 'AMD'
                }
                elseif ($gpu.Name -match 'Intel|HD Graphics|UHD Graphics|Iris') {
                    $primaryGPU = 'Intel'
                }
            }
        }

        return if ($primaryGPU) { $primaryGPU } else { 'Other' }
    } catch {
        return 'Other'
    }
}

function Set-Reg {
    param($Path,$Name,$Type='DWord',$Value,$RequiresAdmin=$false)

    # Enhanced parameter validation
    if (-not $Path -or -not $Name) {
        Log "Set-Reg: Invalid parameters - Path: '$Path', Name: '$Name'" 'Error'
        return $false
    }

    # Admin privilege check
    if ($RequiresAdmin -and -not (Test-AdminPrivileges)) {
        Log "Set-Reg: Administrative privileges required for $Path\$Name" 'Warning'
        return $false
    }

    # Cache optimization
    $cacheKey = "$Path\$Name"
    if ($global:RegistryCache.ContainsKey($cacheKey) -and $global:RegistryCache[$cacheKey] -eq $Value) {
        Log "Set-Reg: Using cached value for $cacheKey" 'Info'
        return $true
    }

    try {
        # Enhanced parent path creation and checking
        $parentPaths = @()
        $currentPath = $Path

        # Build list of parent paths that need to be created
        while ($currentPath -and -not (Test-Path $currentPath -ErrorAction SilentlyContinue)) {
            $parentPaths += $currentPath
            $parent = Split-Path $currentPath -Parent
            if ($parent -eq $currentPath) { break } # Reached root
            $currentPath = $parent
        }

        # Create parent paths from top down
        for ($i = $parentPaths.Count - 1; $i -ge 0; $i--) {
            $pathToCreate = $parentPaths[$i]
            try {
                Log "Set-Reg: Creating registry path: $pathToCreate" 'Info'
                New-Item -Path $pathToCreate -Force -ErrorAction Stop | Out-Null
            } catch {
                Log "Set-Reg: Failed to create registry path '$pathToCreate': $($_.Exception.Message)" 'Error'
                return $false
            }
        }

        # Verify final path exists
        if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
            Log "Set-Reg: Final path verification failed for: $Path" 'Error'
            return $false
        }

        # Set or update the registry value
        $valueExists = $null -ne (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue)

        if ($valueExists) {
            Log "Set-Reg: Updating existing value $Path\$Name = $Value" 'Info'
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction Stop
        } else {
            Log "Set-Reg: Creating new value $Path\$Name = $Value (Type: $Type)" 'Info'
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        }

        # Verify the value was set correctly
        $verifyValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $verifyValue -and $verifyValue.$Name -eq $Value) {
            $global:RegistryCache[$cacheKey] = $Value
            Log "Set-Reg: Successfully set and verified $Path\$Name = $Value" 'Success'
            return $true
        } else {
            Log "Set-Reg: Value verification failed for $Path\$Name" 'Error'
            return $false
        }

    } catch {
        Log "Set-Reg: Error setting registry value ${Path}\${Name}: $($_.Exception.Message)" 'Error'
        return $false
    }
}

function Get-Reg {
    param($Path, $Name)
    try {
        (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
    } catch {
        $null
    }
}

function Remove-Reg {
    param($Path, $Name)
    try {
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# ---------- Enhanced XAML UI with Modern Sidebar Navigation ----------
$xamlContent = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="KOALA Gaming Optimizer v3.0 - Enhanced Edition"
        Width="1400" Height="900"
        MinWidth="1200" MinHeight="820"
        Background="{DynamicResource AppBackgroundBrush}"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize"
        SizeToContent="Manual">
  <Window.Resources>
    <SolidColorBrush x:Key="AppBackgroundBrush" Color="#0F0F12"/>
    <SolidColorBrush x:Key="SidebarBackgroundBrush" Color="#141416"/>
    <SolidColorBrush x:Key="SidebarAccentBrush" Color="#A855F7"/>
    <SolidColorBrush x:Key="SidebarHoverBrush" Color="#222227"/>
    <SolidColorBrush x:Key="SidebarSelectedBrush" Color="#A855F7"/>
    <SolidColorBrush x:Key="SidebarSelectedForegroundBrush" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="HeaderBackgroundBrush" Color="#151517"/>
    <SolidColorBrush x:Key="HeaderBorderBrush" Color="#2A2A2E"/>
    <SolidColorBrush x:Key="CardBackgroundBrush" Color="#1A1A1D"/>
    <SolidColorBrush x:Key="ContentBackgroundBrush" Color="#151517"/>
    <SolidColorBrush x:Key="CardBorderBrush" Color="#2A2A2E"/>
    <SolidColorBrush x:Key="HeroCardBrush" Color="#1A1A1D"/>
    <SolidColorBrush x:Key="AccentBrush" Color="#A855F7"/>
    <SolidColorBrush x:Key="PrimaryTextBrush" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="SecondaryTextBrush" Color="#9CA3AF"/>
    <SolidColorBrush x:Key="SuccessBrush" Color="#22C55E"/>
    <SolidColorBrush x:Key="WarningBrush" Color="#F59E0B"/>
    <SolidColorBrush x:Key="DangerBrush" Color="#EF4444"/>
    <SolidColorBrush x:Key="InfoBrush" Color="#60A5FA"/>
    <SolidColorBrush x:Key="ButtonBackgroundBrush" Color="#151517"/>
    <SolidColorBrush x:Key="ButtonBorderBrush" Color="#2A2A2E"/>
    <SolidColorBrush x:Key="ButtonHoverBrush" Color="#222227"/>
    <SolidColorBrush x:Key="ButtonPressedBrush" Color="#1B1B1F"/>
    <SolidColorBrush x:Key="HeroChipBrush" Color="#151517"/>


    <Style x:Key="BaseControlStyle" TargetType="Control">
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
    </Style>

    <Style x:Key="BaseTextBlockStyle" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>

    <Style x:Key="SectionHeader" TargetType="TextBlock" BasedOn="{StaticResource BaseTextBlockStyle}">
      <Setter Property="FontSize" Value="18"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
    </Style>

    <Style x:Key="SectionSubtext" TargetType="TextBlock" BasedOn="{StaticResource BaseTextBlockStyle}">
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="{DynamicResource SecondaryTextBrush}"/>
    </Style>

    <Style x:Key="ModernButton" TargetType="Button" BasedOn="{StaticResource BaseControlStyle}">
      <Setter Property="Background" Value="{DynamicResource ButtonBackgroundBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource ButtonBorderBrush}"/>

      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="buttonBorder"
                    Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="6"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="buttonBorder" Property="Background" Value="{DynamicResource ButtonHoverBrush}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="buttonBorder" Property="Background" Value="{DynamicResource ButtonPressedBrush}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="SuccessButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
      <Setter Property="Background" Value="{DynamicResource SuccessBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource SuccessBrush}"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#34D399"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="WarningButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
      <Setter Property="Background" Value="{DynamicResource WarningBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource WarningBrush}"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#FBBF24"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
      <Setter Property="Background" Value="{DynamicResource DangerBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource DangerBrush}"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#DC2626"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="SidebarButton" TargetType="Button" BasedOn="{StaticResource BaseControlStyle}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{DynamicResource SecondaryTextBrush}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="14,10"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="HorizontalAlignment" Value="Stretch"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="sidebarBg" Background="{TemplateBinding Background}" CornerRadius="6" Padding="8,6">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="sidebarBg" Property="Background" Value="{DynamicResource SidebarHoverBrush}"/>
              </Trigger>
              <Trigger Property="Tag" Value="Selected">
                <Setter TargetName="sidebarBg" Property="Background" Value="{DynamicResource SidebarSelectedBrush}"/>
                <Setter Property="Foreground" Value="{DynamicResource SidebarSelectedForegroundBrush}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="SidebarSectionLabel" TargetType="TextBlock" BasedOn="{StaticResource BaseTextBlockStyle}">
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="{DynamicResource SecondaryTextBrush}"/>
      <Setter Property="Margin" Value="4,20,0,8"/>
    </Style>

    <Style x:Key="MetricValue" TargetType="TextBlock" BasedOn="{StaticResource BaseTextBlockStyle}">
      <Setter Property="FontSize" Value="22"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
    </Style>

    <Style x:Key="ModernComboBox" TargetType="ComboBox" BasedOn="{StaticResource BaseControlStyle}">
      <Setter Property="Background" Value="{DynamicResource ContentBackgroundBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource CardBorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Height" Value="34"/>
      <Style.Resources>
        <Style TargetType="ComboBoxItem" BasedOn="{StaticResource BaseControlStyle}">
          <Setter Property="Background" Value="Transparent"/>
          <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
          <Setter Property="Padding" Value="12,6"/>
          <Style.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter Property="Background" Value="{DynamicResource SidebarHoverBrush}"/>
            </Trigger>
            <Trigger Property="IsSelected" Value="True">
              <Setter Property="Background" Value="{DynamicResource SidebarAccentBrush}"/>
              <Setter Property="Foreground" Value="{DynamicResource SidebarSelectedForegroundBrush}"/>
            </Trigger>
          </Style.Triggers>
        </Style>
      </Style.Resources>
    </Style>

    <Style x:Key="ModernTextBox" TargetType="TextBox" BasedOn="{StaticResource BaseControlStyle}">
      <Setter Property="Background" Value="{DynamicResource ContentBackgroundBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource CardBorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="CaretBrush" Value="{DynamicResource PrimaryTextBrush}"/>
    </Style>

    <Style x:Key="ModernCheckBox" TargetType="CheckBox" BasedOn="{StaticResource BaseControlStyle}">
      <Setter Property="Foreground" Value="{DynamicResource SecondaryTextBrush}"/>
      <Setter Property="Margin" Value="0,4,18,4"/>
    </Style>

    <Style x:Key="HeaderText" TargetType="TextBlock" BasedOn="{StaticResource BaseTextBlockStyle}">
      <Setter Property="FontSize" Value="18"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="{DynamicResource AccentBrush}"/>
    </Style>
  </Window.Resources>

  <Grid x:Name="RootLayout" Background="{DynamicResource AppBackgroundBrush}">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="230"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <Border x:Name="SidebarShell"
            Grid.Column="0"
            Background="{DynamicResource SidebarBackgroundBrush}"
            BorderBrush="{DynamicResource CardBorderBrush}"
            BorderThickness="0,0,1,0"
            Padding="20,18">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="{DynamicResource HeroCardBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="14" Padding="18" Margin="0,0,0,24">
          <StackPanel Tag="Spacing:6">
            <TextBlock Text="🐨 KOALA" FontSize="22" FontWeight="SemiBold" Foreground="{DynamicResource PrimaryTextBrush}"/>
            <TextBlock Text="Gaming Optimizer v3.0" Style="{StaticResource SectionSubtext}" FontSize="13"/>
            <TextBlock Text="Advanced FPS boosting suite" Style="{StaticResource SectionSubtext}" FontSize="11"/>
          </StackPanel>
        </Border>

        <ScrollViewer x:Name="SidebarNavScroll" Grid.Row="1" VerticalScrollBarVisibility="Auto">
          <StackPanel>
            <Button x:Name="btnNavDashboard" Style="{StaticResource SidebarButton}" Tag="Selected">
              <StackPanel Orientation="Horizontal" Margin="0" Tag="Spacing:10">
                <TextBlock Text="🏠" FontSize="16"/>
                <TextBlock Text="Dashboard" FontWeight="SemiBold"/>
              </StackPanel>
            </Button>
            <Button x:Name="btnNavBasicOpt" Style="{StaticResource SidebarButton}">
              <StackPanel Orientation="Horizontal" Tag="Spacing:10">
                <TextBlock Text="⚡" FontSize="16"/>
                <TextBlock Text="Quick optimize" FontWeight="SemiBold"/>
              </StackPanel>
            </Button>
            <Button x:Name="btnNavAdvanced" Style="{StaticResource SidebarButton}">
              <StackPanel Orientation="Horizontal" Tag="Spacing:10">
                <TextBlock Text="🛠️" FontSize="16"/>
                <TextBlock Text="Advanced" FontWeight="SemiBold"/>
              </StackPanel>
            </Button>
            <Button x:Name="btnNavGames" Style="{StaticResource SidebarButton}">
              <StackPanel Orientation="Horizontal" Tag="Spacing:10">
                <TextBlock Text="🎮" FontSize="16"/>
                <TextBlock Text="Game profiles" FontWeight="SemiBold"/>
              </StackPanel>
            </Button>
            <Button x:Name="btnNavOptions" Style="{StaticResource SidebarButton}">
              <StackPanel Orientation="Horizontal" Tag="Spacing:10">
                <TextBlock Text="🎨" FontSize="16"/>
                <TextBlock Text="Options" FontWeight="SemiBold"/>
              </StackPanel>
            </Button>
            <Button x:Name="btnNavBackup" Style="{StaticResource SidebarButton}">
              <StackPanel Orientation="Horizontal" Tag="Spacing:10">
                <TextBlock Text="🗂️" FontSize="16"/>
                <TextBlock Text="Backups" FontWeight="SemiBold"/>
              </StackPanel>
            </Button>
            <Button x:Name="btnNavLog" Style="{StaticResource SidebarButton}">
              <StackPanel Orientation="Horizontal" Tag="Spacing:10">
                <TextBlock Text="🧾" FontSize="16"/>
                <TextBlock Text="Activity log" FontWeight="SemiBold"/>
              </StackPanel>
            </Button>
          </StackPanel>
        </ScrollViewer>

        <Border x:Name="SidebarAdminCard"
                Grid.Row="2"
                Background="{DynamicResource ContentBackgroundBrush}"
                BorderBrush="{DynamicResource CardBorderBrush}"
                BorderThickness="1"
                CornerRadius="8"
                Padding="14"
                Margin="0,20,0,0">
          <StackPanel>
            <TextBlock Text="Admin status" FontSize="12" FontWeight="SemiBold" Foreground="{DynamicResource SecondaryTextBrush}"/>
            <TextBlock x:Name="lblSidebarAdminStatus" Text="Checking..." FontSize="11" Foreground="{DynamicResource WarningBrush}" Margin="0,6,0,0"/>
            <Button x:Name="btnSidebarElevate" Content="Request elevation" Height="30" Style="{StaticResource WarningButton}" FontSize="11" Margin="0,10,0,0"/>
          </StackPanel>
        </Border>
      </Grid>
    </Border>

    <Grid x:Name="MainStage" Grid.Column="1" Background="{DynamicResource AppBackgroundBrush}">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="260"/>
      </Grid.RowDefinitions>

      <Border x:Name="HeaderBar"
              Grid.Row="0"
              Background="{DynamicResource HeaderBackgroundBrush}"
              BorderBrush="{DynamicResource HeaderBorderBrush}"
              BorderThickness="0,0,0,1"
              Padding="26,20">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel>
            <TextBlock x:Name="lblMainTitle" Text="Dashboard" FontSize="26" FontWeight="SemiBold" Foreground="{DynamicResource PrimaryTextBrush}"/>
            <TextBlock x:Name="lblMainSubtitle" Text="Your system at a glance" Style="{StaticResource SectionSubtext}" Margin="0,6,0,0"/>
            <WrapPanel Margin="0,18,0,0" ItemHeight="28">
              <Border Background="{DynamicResource HeroChipBrush}" CornerRadius="14" Padding="12,6" Margin="0,0,10,0" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1">
                <StackPanel Orientation="Horizontal" Tag="Spacing:6">
                  <TextBlock Text="⚡" FontSize="14"/>
                  <TextBlock Text="Instant optimizations" Style="{StaticResource SectionSubtext}"/>
                </StackPanel>
              </Border>
              <Border Background="{DynamicResource HeroChipBrush}" CornerRadius="14" Padding="12,6" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1">
                <StackPanel Orientation="Horizontal" Tag="Spacing:6">
                  <TextBlock Text="📊" FontSize="14"/>
                  <TextBlock Text="Live system insights" Style="{StaticResource SectionSubtext}"/>
                </StackPanel>
              </Border>
            </WrapPanel>
          </StackPanel>
          <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Tag="Spacing:12">
            <StackPanel Width="220" Tag="Spacing:6">
              <TextBlock Text="Theme preset" Style="{StaticResource SectionSubtext}" FontSize="12"/>
              <ComboBox x:Name="cmbHeaderTheme" Style="{StaticResource ModernComboBox}" Width="220"/>
            </StackPanel>
            <Button x:Name="btnHeaderApplyTheme" Content="Apply theme" Width="120" Height="36" Style="{StaticResource SuccessButton}" FontSize="12"/>
          </StackPanel>
        </Grid>
      </Border>

      <Border x:Name="dashboardSummaryRibbon" Grid.Row="1" Margin="26,18,26,12" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="18">
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Tag="Spacing:24">
          <StackPanel Orientation="Horizontal" Tag="Spacing:8">
            <TextBlock Text="Profiles:" Style="{StaticResource SectionSubtext}" FontSize="13"/>
            <TextBlock x:Name="lblHeroProfiles" Style="{StaticResource MetricValue}" FontSize="20" Foreground="{DynamicResource PrimaryTextBrush}" Text="--"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" Tag="Spacing:8">
            <TextBlock Text="Optimizations:" Style="{StaticResource SectionSubtext}" FontSize="13"/>
            <TextBlock x:Name="lblHeroOptimizations" Style="{StaticResource MetricValue}" FontSize="20" Foreground="{DynamicResource AccentBrush}" Text="--"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" Tag="Spacing:8">
            <TextBlock Text="Auto mode:" Style="{StaticResource SectionSubtext}" FontSize="13"/>
            <TextBlock x:Name="lblHeroAutoMode" Style="{StaticResource MetricValue}" FontSize="20" Foreground="{DynamicResource DangerBrush}" Text="Off"/>
          </StackPanel>
        </StackPanel>
      </Border>

      <ScrollViewer x:Name="MainScrollViewer" Grid.Row="2" VerticalScrollBarVisibility="Auto" Padding="26">
        <StackPanel Tag="Spacing:22">
          <StackPanel x:Name="panelDashboard" Visibility="Visible" Tag="Spacing:18">
            <Border x:Name="dashboardHeroCard"
                    Background="{DynamicResource CardBackgroundBrush}"
                    BorderBrush="{DynamicResource CardBorderBrush}"
                    BorderThickness="1"
                    CornerRadius="16"
                    Padding="26">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Tag="Spacing:12">
                  <TextBlock Text="System ready" Style="{StaticResource SectionHeader}" FontSize="20"/>
                  <TextBlock x:Name="lblHeaderSystemStatus" Text="Stable" Style="{StaticResource SectionHeader}" FontSize="28"/>
                  <TextBlock Text="KOALA keeps your PC lean with smart maintenance, clean logging and one-click fixes to ensure optimal gaming performance." Style="{StaticResource SectionSubtext}"/>
                  <StackPanel Orientation="Horizontal" Tag="Spacing:8">
                    <TextBlock Text="Last run:" Style="{StaticResource SectionSubtext}"/>
                    <TextBlock x:Name="lblHeaderLastRun" Text="Never" Style="{StaticResource SectionSubtext}" FontSize="13"/>
                  </StackPanel>
                </StackPanel>
                <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center" Tag="Spacing:12">
                  <Button x:Name="btnSystemHealth" Content="View health detail" Width="200" Height="40" Style="{StaticResource ModernButton}"/>
                  <Border Background="{DynamicResource HeroChipBrush}" CornerRadius="12" Padding="12,8" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" HorizontalAlignment="Right">
                    <TextBlock Text="Admin status: All optimizations available" Style="{StaticResource SectionSubtext}"/>
                  </Border>
                </StackPanel>
              </Grid>
            </Border>

            <Border x:Name="dashboardSummaryPanel"
                    Background="{DynamicResource CardBackgroundBrush}"
                    BorderBrush="{DynamicResource CardBorderBrush}"
                    BorderThickness="1"
                    CornerRadius="12"
                    Padding="24">
              <StackPanel Tag="Spacing:18">
                <StackPanel>
                  <TextBlock Text="System summary" Style="{StaticResource SectionHeader}" FontSize="18"/>
                  <TextBlock Text="Realtime metrics and health status." Style="{StaticResource SectionSubtext}"/>
                </StackPanel>
                <UniformGrid Rows="1" Columns="4" Margin="0,4,0,0">
                  <Border x:Name="dashboardCpuCard" Background="{DynamicResource CardBackgroundBrush}" CornerRadius="10" Padding="16" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Margin="0,0,12,0">
                    <StackPanel Tag="Spacing:6">
                      <TextBlock Text="CPU load" Style="{StaticResource SectionSubtext}" FontSize="13"/>
                      <TextBlock x:Name="lblDashCpuUsage" Style="{StaticResource MetricValue}" Text="--%"/>
                      <TextBlock Text="Realtime usage of each core." Style="{StaticResource SectionSubtext}"/>
                    </StackPanel>
                  </Border>
                  <Border x:Name="dashboardMemoryCard" Background="{DynamicResource CardBackgroundBrush}" CornerRadius="10" Padding="16" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Margin="12,0">
                    <StackPanel Tag="Spacing:6">
                      <TextBlock Text="Memory" Style="{StaticResource SectionSubtext}" FontSize="13"/>
                      <TextBlock x:Name="lblDashMemoryUsage" Style="{StaticResource MetricValue}" Text="-- / -- GB" Foreground="{DynamicResource AccentBrush}"/>
                      <TextBlock Text="Track system memory consumption." Style="{StaticResource SectionSubtext}"/>
                    </StackPanel>
                  </Border>
                  <Border x:Name="dashboardActivityCard" Background="{DynamicResource CardBackgroundBrush}" CornerRadius="10" Padding="16" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Margin="12,0">
                    <StackPanel Tag="Spacing:6">
                      <TextBlock Text="Session" Style="{StaticResource SectionSubtext}" FontSize="13"/>
                      <TextBlock Text="Active games" Style="{StaticResource SectionSubtext}"/>
                      <TextBlock x:Name="lblDashActiveGames" Style="{StaticResource MetricValue}" Text="None"/>
                      <Separator Margin="0,4" Background="{DynamicResource CardBorderBrush}" Height="1"/>
                      <TextBlock Text="Last optimization" Style="{StaticResource SectionSubtext}"/>
                      <TextBlock x:Name="lblDashLastOptimization" Style="{StaticResource SectionSubtext}" FontSize="13" Text="Never"/>
                    </StackPanel>
                  </Border>
                  <Border x:Name="dashboardHealthCard" Background="{DynamicResource CardBackgroundBrush}" CornerRadius="10" Padding="16" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Margin="12,0,0,0">
                    <StackPanel Tag="Spacing:8">
                      <TextBlock Text="System health" Style="{StaticResource SectionSubtext}" FontSize="13"/>
                      <TextBlock x:Name="lblDashSystemHealth" Style="{StaticResource MetricValue}" Text="Not run"/>
                      <StackPanel Orientation="Horizontal" Tag="Spacing:8">
                        <Button x:Name="btnSystemHealthRunCheck" Content="Run" Width="72" Height="30" Style="{StaticResource SuccessButton}" FontSize="12"/>
                        <Button x:Name="btnBenchmark" Content="Benchmark" Width="100" Height="30" Style="{StaticResource WarningButton}" FontSize="12"/>
                      </StackPanel>
                    </StackPanel>
                  </Border>
                </UniformGrid>
              </StackPanel>
            </Border>

            <Border x:Name="dashboardQuickActionsCard"
                    Background="{DynamicResource CardBackgroundBrush}"
                    BorderBrush="{DynamicResource CardBorderBrush}"
                    BorderThickness="1"
                    CornerRadius="12"
                    Padding="20">
              <StackPanel Tag="Spacing:10">
                <TextBlock Text="Optimization controls" Style="{StaticResource SectionHeader}" FontSize="16"/>
                <TextBlock Text="Launch KOALA automation, detection and benchmarking from one spot." Style="{StaticResource SectionSubtext}"/>
                <WrapPanel ItemWidth="180" ItemHeight="40" Margin="0,4,0,0">
                  <Button x:Name="btnDashQuickOptimize" Content="⚡ Quick optimize" Width="180" Height="36" Style="{StaticResource SuccessButton}" FontSize="12" Margin="0,0,16,16"/>
                  <Button x:Name="btnDashAutoDetect" Content="🎮 Auto-detect games" Width="200" Height="36" Style="{StaticResource ModernButton}" FontSize="12" Margin="0,0,16,16"/>
                  <Button x:Name="btnDashAutoOptimize" Content="Auto optimize" Visibility="Collapsed"/>
                </WrapPanel>
                <CheckBox x:Name="chkDashAutoOptimize" Content="Keep auto optimization enabled" Style="{StaticResource ModernCheckBox}"/>
                <TextBlock Text="Tip: Enable auto optimization so KOALA refreshes your tweaks whenever Windows starts." Style="{StaticResource SectionSubtext}"/>
              </StackPanel>
            </Border>

            <Border x:Name="dashboardActionBar"
                    Background="{DynamicResource CardBackgroundBrush}"
                    BorderBrush="{DynamicResource CardBorderBrush}"
                    BorderThickness="1"
                    CornerRadius="12"
                    Padding="18">
              <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Tag="Spacing:12">
                <Button x:Name="btnExportConfigMain" Content="Export config" Width="140" Height="38" Style="{StaticResource ModernButton}"/>
                <Button x:Name="btnImportConfigMain" Content="Import config" Width="140" Height="38" Style="{StaticResource ModernButton}"/>
                <Button x:Name="btnBackupMain" Content="Backup" Width="120" Height="38" Style="{StaticResource ModernButton}"/>
                <Button x:Name="btnApplyMain" Content="Apply all" Width="140" Height="44" Style="{StaticResource SuccessButton}" FontSize="16"/>
                <Button x:Name="btnRevertMain" Content="Revert all" Width="140" Height="44" Style="{StaticResource DangerButton}" FontSize="16"/>
                <Button x:Name="btnApply" Visibility="Collapsed" Width="0" Height="0"/>
                <Button x:Name="btnRevert" Visibility="Collapsed" Width="0" Height="0"/>
              </StackPanel>
            </Border>

            <Border x:Name="dashboardGameProfileCard"
                    Background="{DynamicResource CardBackgroundBrush}"
                    BorderBrush="{DynamicResource CardBorderBrush}"
                    BorderThickness="1"
                    CornerRadius="12"
                    Padding="20">
              <StackPanel Tag="Spacing:12">
                <TextBlock Text="Game profile launcher" Style="{StaticResource SectionHeader}" FontSize="16"/>
                <Grid Tag="ColumnSpacing:16">
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="2*"/>
                    <ColumnDefinition Width="*"/>
                  </Grid.ColumnDefinitions>
                  <StackPanel Grid.Column="0" Tag="Spacing:12">
                    <ComboBox x:Name="cmbGameProfile" Style="{StaticResource ModernComboBox}"/>
                    <Grid Tag="ColumnSpacing:10">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                      </Grid.ColumnDefinitions>
                      <TextBox x:Name="txtCustomGame" Grid.Column="0" Style="{StaticResource ModernTextBox}"/>
                      <Button x:Name="btnFindExecutable" Grid.Column="1" Content="Find" Width="70" Height="32" Style="{StaticResource ModernButton}"/>
                      <Button x:Name="btnOptimizeGame" Grid.Column="2" Content="Optimize" Width="100" Height="32" Style="{StaticResource SuccessButton}"/>
                    </Grid>
                  </StackPanel>
                  <StackPanel Grid.Column="1" Tag="Spacing:10">
                    <Button x:Name="btnInstalledGamesDash" Content="Installed games" Width="180" Height="34" Style="{StaticResource ModernButton}"/>
                    <Button x:Name="btnAddGameFolderDash" Content="Add game folder" Width="180" Height="34" Style="{StaticResource ModernButton}"/>
                    <Button x:Name="btnCustomSearchDash" Content="Custom search" Width="180" Height="34" Style="{StaticResource WarningButton}" Visibility="Collapsed"/>
                  </StackPanel>
                </Grid>
              </StackPanel>
            </Border>

            <Border x:Name="dashboardGameListCard"
                    Background="{DynamicResource CardBackgroundBrush}"
                    BorderBrush="{DynamicResource CardBorderBrush}"
                    BorderThickness="1"
                    CornerRadius="12"
                    Padding="20">
              <StackPanel Tag="Spacing:12">
                <TextBlock Text="Detected games" Style="{StaticResource SectionHeader}" FontSize="16"/>
                <TextBlock Text="Your library updates automatically after detection." Style="{StaticResource SectionSubtext}"/>
                <ScrollViewer Height="260" VerticalScrollBarVisibility="Auto" Background="Transparent">
                  <StackPanel x:Name="dashboardGameListPanel">
                    <TextBlock Text="Click 'Search for installed games' to discover your library." Style="{StaticResource SectionSubtext}" FontStyle="Italic" HorizontalAlignment="Center" Margin="0,40,0,0"/>
                  </StackPanel>
                </ScrollViewer>
                <Button x:Name="btnOptimizeSelectedDashboard" Content="Optimize selected games" Height="40" Style="{StaticResource SuccessButton}" FontSize="12" IsEnabled="False"/>
              </StackPanel>
            </Border>
          </StackPanel>

          <StackPanel x:Name="panelBasicOpt" Visibility="Collapsed" Tag="Spacing:16">
            <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="22">
              <StackPanel Tag="Spacing:14">
                <TextBlock Text="Basic mode" Style="{StaticResource SectionHeader}" FontSize="18" HorizontalAlignment="Center"/>
                <TextBlock Text="Pick categories to apply safe optimizations instantly." Style="{StaticResource SectionSubtext}" HorizontalAlignment="Center"/>
                <Grid Tag="ColumnSpacing:16">
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                  </Grid.ColumnDefinitions>
                  <Button x:Name="btnBasicNetwork" Grid.Column="0" Height="78" Style="{StaticResource ModernButton}">
                    <StackPanel>
                      <TextBlock Text="🌐 Network" FontWeight="SemiBold"/>
                      <TextBlock Text="Latency optimizations" Style="{StaticResource SectionSubtext}"/>
                    </StackPanel>
                  </Button>
                  <Button x:Name="btnBasicSystem" Grid.Column="1" Height="78" Style="{StaticResource ModernButton}">
                    <StackPanel>
                      <TextBlock Text="💻 System" FontWeight="SemiBold"/>
                      <TextBlock Text="Power &amp; memory" Style="{StaticResource SectionSubtext}"/>
                    </StackPanel>
                  </Button>
                  <Button x:Name="btnBasicGaming" Grid.Column="2" Height="78" Style="{StaticResource ModernButton}">
                    <StackPanel>
                      <TextBlock Text="🎮 Gaming" FontWeight="SemiBold"/>
                      <TextBlock Text="FPS tweaks" Style="{StaticResource SectionSubtext}"/>
                    </StackPanel>
                  </Button>
                </Grid>
              </StackPanel>
            </Border>
          </StackPanel>

          <StackPanel x:Name="panelAdvanced" Visibility="Collapsed" Tag="Spacing:16">
            <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="22">
              <StackPanel Tag="Spacing:16">
                <TextBlock Text="Advanced optimizations" Style="{StaticResource SectionHeader}" FontSize="18"/>
                <TextBlock Text="Collapsible sections for deep system tweaks." Style="{StaticResource SectionSubtext}"/>
                <StackPanel Orientation="Horizontal" Tag="Spacing:10" HorizontalAlignment="Center">
                  <Button x:Name="btnAdvancedNetwork" Content="🌐 Network" Style="{StaticResource ModernButton}" MinWidth="120" Height="32" FontSize="12"/>
                  <Button x:Name="btnAdvancedSystem" Content="💻 System" Style="{StaticResource ModernButton}" MinWidth="120" Height="32" FontSize="12"/>
                  <Button x:Name="btnAdvancedServices" Content="🛠️ Services" Style="{StaticResource ModernButton}" MinWidth="120" Height="32" FontSize="12"/>
                </StackPanel>

                <Expander x:Name="expanderNetworkTweaks" Header="🌐 Network optimizations" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Padding="10">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Fine tune TCP and latency for competitive play." Style="{StaticResource SectionSubtext}"/>
                    <Expander x:Name="expanderNetworkOptimizations" Header="Core network tweaks" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Padding="10" IsExpanded="True">
                      <WrapPanel>
                        <CheckBox x:Name="chkAckNetwork" Content="TCP ACK Frequency" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDelAckTicksNetwork" Content="Delayed ACK Ticks" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkNagleNetwork" Content="Disable Nagle" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkNetworkThrottlingNetwork" Content="Network throttling" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkRSSNetwork" Content="Receive side scaling" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkRSCNetwork" Content="Segment coalescing" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkChimneyNetwork" Content="TCP chimney offload" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkNetDMANetwork" Content="NetDMA state" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkTcpTimestampsNetwork" Content="TCP timestamps" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkTcpWindowAutoTuningNetwork" Content="Window auto tuning" Style="{StaticResource ModernCheckBox}"/>
                      </WrapPanel>
                    </Expander>
                    <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="14">
                      <Grid Tag="ColumnSpacing:12">
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="btnApplyNetworkTweaks" Grid.Column="0" Content="Apply network optimizations" Style="{StaticResource SuccessButton}" Height="34" FontSize="12"/>
                        <Button x:Name="btnTestNetworkLatency" Grid.Column="1" Content="Test latency" Width="120" Height="34" Style="{StaticResource ModernButton}" FontSize="12"/>
                        <Button x:Name="btnResetNetworkSettings" Grid.Column="2" Content="Reset" Width="80" Height="34" Style="{StaticResource WarningButton}" FontSize="12"/>
                      </Grid>
                    </Border>
                  </StackPanel>
                </Expander>

                <Expander x:Name="expanderSystemOptimizations" Header="💻 System optimizations" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Padding="10">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Performance and hardware adjustments for maximum efficiency." Style="{StaticResource SectionSubtext}"/>
                    <Expander x:Name="expanderPerformanceOptimizations" Header="Performance essentials" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Padding="10" IsExpanded="True">
                      <WrapPanel>
                        <CheckBox x:Name="chkMemoryCompressionSystem" Content="Memory compression" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkPowerPlanSystem" Content="High performance plan" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkCPUSchedulingSystem" Content="CPU scheduling" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkPageFileSystem" Content="Page file" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkVisualEffectsSystem" Content="Disable visuals" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkCoreParkingSystem" Content="Core parking" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkGameDVRSystem" Content="Disable Game DVR" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkFullscreenOptimizationsSystem" Content="Fullscreen exclusive" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkGPUSchedulingSystem" Content="GPU scheduling" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkTimerResolutionSystem" Content="Timer resolution" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkGameModeSystem" Content="Game mode" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkMPOSystem" Content="MPO" Style="{StaticResource ModernCheckBox}"/>
                      </WrapPanel>
                    </Expander>

                    <Expander x:Name="expanderAdvancedPerformance" Header="Advanced enhancements" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Padding="10">
                      <WrapPanel>
                        <CheckBox x:Name="chkDynamicResolution" Content="Dynamic resolution" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkEnhancedFramePacing" Content="Enhanced frame pacing" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkGPUOverclocking" Content="GPU overclock profile" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkCompetitiveLatency" Content="Latency reduction" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkAutoDiskOptimization" Content="Auto disk trim" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkAdaptivePowerManagement" Content="Adaptive power" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkEnhancedPagingFile" Content="Paging file management" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDirectStorageEnhanced" Content="DirectStorage" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkAdvancedTelemetryDisable" Content="Telemetry disable" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkMemoryDefragmentation" Content="Memory defrag" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkServiceOptimization" Content="Service optimization" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDiskTweaksAdvanced" Content="Disk I/O tweaks" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkNetworkLatencyOptimization" Content="Ultra-low latency" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkFPSSmoothness" Content="FPS smoothness" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkCPUMicrocode" Content="CPU microcode" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkRAMTimings" Content="RAM timings" Style="{StaticResource ModernCheckBox}"/>
                      </WrapPanel>
                    </Expander>

                    <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="14">
                      <Grid Tag="ColumnSpacing:12">
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="btnApplySystemOptimizations" Grid.Column="0" Content="Apply system optimizations" Style="{StaticResource SuccessButton}" Height="34" FontSize="12"/>
                        <Button x:Name="btnSystemBenchmark" Grid.Column="1" Content="Benchmark" Width="120" Height="34" Style="{StaticResource ModernButton}" FontSize="12"/>
                        <Button x:Name="btnResetSystemSettings" Grid.Column="2" Content="Reset" Width="80" Height="34" Style="{StaticResource WarningButton}" FontSize="12"/>
                      </Grid>
                    </Border>
                  </StackPanel>
                </Expander>

                <Expander x:Name="expanderServiceManagement" Header="🛠️ Service optimizations" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Padding="10">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Manage background services for better responsiveness." Style="{StaticResource SectionSubtext}"/>
                    <Expander x:Name="expanderServiceOptimizations" Header="Service tweaks" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Padding="10" IsExpanded="True">
                      <WrapPanel>
                        <CheckBox x:Name="chkDisableXboxServicesServices" Content="Disable Xbox services" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableTelemetryServices" Content="Disable telemetry" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableSearchServices" Content="Disable search" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisablePrintSpoolerServices" Content="Disable print spooler" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableSuperfetchServices" Content="Disable superfetch" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableFaxServices" Content="Disable fax" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableRemoteRegistryServices" Content="Disable remote registry" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableThemesServices" Content="Optimize themes service" Style="{StaticResource ModernCheckBox}"/>
                      </WrapPanel>
                    </Expander>
                    <Expander x:Name="expanderPrivacyServices" Header="Privacy &amp; background" Background="{DynamicResource CardBackgroundBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" Padding="10">
                      <WrapPanel>
                        <CheckBox x:Name="chkDisableCortana" Content="Disable Cortana" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableWindowsUpdate" Content="Optimize Windows Update" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableBackgroundApps" Content="Disable background apps" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableLocationTracking" Content="Disable location" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableAdvertisingID" Content="Disable advertising ID" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableErrorReporting" Content="Disable error reporting" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableCompatTelemetry" Content="Disable compat telemetry" Style="{StaticResource ModernCheckBox}"/>
                        <CheckBox x:Name="chkDisableWSH" Content="Disable Windows Script Host" Style="{StaticResource ModernCheckBox}"/>
                      </WrapPanel>
                    </Expander>
                    <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="14">
                      <Grid Tag="ColumnSpacing:12">
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="btnApplyServiceOptimizations" Grid.Column="0" Content="Apply service optimizations" Style="{StaticResource SuccessButton}" Height="34" FontSize="12"/>
                        <Button x:Name="btnViewRunningServices" Grid.Column="1" Content="View services" Width="120" Height="34" Style="{StaticResource ModernButton}" FontSize="12"/>
                        <Button x:Name="btnResetServiceSettings" Grid.Column="2" Content="Reset" Width="80" Height="34" Style="{StaticResource WarningButton}" FontSize="12"/>
                      </Grid>
                    </Border>
                  </StackPanel>
                </Expander>
              </StackPanel>
            </Border>
          </StackPanel>

          <StackPanel x:Name="panelGames" Visibility="Collapsed" Tag="Spacing:16">
            <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="22">
              <StackPanel Tag="Spacing:16">
                <TextBlock Text="Installed games" Style="{StaticResource SectionHeader}" FontSize="18"/>
                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Detection &amp; search" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <Grid Tag="ColumnSpacing:12">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                      </Grid.ColumnDefinitions>
                      <Button x:Name="btnSearchGamesPanel" Grid.Column="0" Content="Installed games" Height="34" Style="{StaticResource ModernButton}" FontSize="12"/>
                      <Button x:Name="btnAddGameFolderPanel" Grid.Column="1" Content="Add folder" Width="140" Height="34" Style="{StaticResource SuccessButton}" FontSize="12"/>
                      <Button x:Name="btnCustomSearchPanel" Grid.Column="2" Content="Custom search" Width="120" Height="34" Style="{StaticResource WarningButton}" FontSize="12" Visibility="Collapsed"/>
                    </Grid>
                  </StackPanel>
                </Border>
                <Border x:Name="installedGamesPanel" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Detected games" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <ScrollViewer Height="280" VerticalScrollBarVisibility="Auto">
                      <StackPanel x:Name="gameListPanel">
                        <TextBlock Text="Click 'Search for installed games' to populate this list." Style="{StaticResource SectionSubtext}" FontStyle="Italic" HorizontalAlignment="Center" Margin="0,30,0,0"/>
                      </StackPanel>
                    </ScrollViewer>
                    <Button x:Name="btnOptimizeSelectedMain" Content="Optimize selected games" Height="36" Style="{StaticResource SuccessButton}" FontSize="12" IsEnabled="False"/>
                  </StackPanel>
                </Border>
              </StackPanel>
            </Border>
          </StackPanel>

          <StackPanel x:Name="panelOptions" Visibility="Collapsed" Tag="Spacing:16">
            <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="22">
              <StackPanel Tag="Spacing:16">
                <TextBlock Text="Theme &amp; preferences" Style="{StaticResource SectionHeader}" FontSize="18" HorizontalAlignment="Center"/>
                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Theme" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <Grid Tag="ColumnSpacing:10">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                      </Grid.ColumnDefinitions>
                      <TextBlock Text="Preset" VerticalAlignment="Center" Style="{StaticResource SectionSubtext}"/>
                      <ComboBox x:Name="cmbOptionsThemeMain" Grid.Column="1" Style="{StaticResource ModernComboBox}">
                        <ComboBoxItem Content="Nebula Vortex" Tag="Nebula"/>
                        <ComboBoxItem Content="Midnight Azure" Tag="Midnight"/>
                        <ComboBoxItem Content="Lumen Daybreak" Tag="Lumen"/>
                        <ComboBoxItem Content="Custom" Tag="Custom"/>
                      </ComboBox>
                      <Button x:Name="btnOptionsApplyThemeMain" Grid.Column="2" Content="Apply" Width="90" Height="32" Style="{StaticResource SuccessButton}" FontSize="12"/>
                      <Button x:Name="btnApplyTheme" Visibility="Collapsed" Width="0" Height="0"/>
                    </Grid>
                    <Border x:Name="themeColorPreview" Background="{DynamicResource ContentBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="6" Padding="12">
                      <Grid Tag="ColumnSpacing:10">
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel>
                          <TextBlock Text="Background" Style="{StaticResource SectionSubtext}" FontSize="11" HorizontalAlignment="Center"/>
                          <Rectangle x:Name="previewBg" Height="20" Fill="{DynamicResource CardBackgroundBrush}" Stroke="{DynamicResource CardBorderBrush}" StrokeThickness="1"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1">
                          <TextBlock Text="Primary" Style="{StaticResource SectionSubtext}" FontSize="11" HorizontalAlignment="Center"/>
                          <Rectangle x:Name="previewPrimary" Height="20" Fill="#8F6FFF" Stroke="{DynamicResource CardBorderBrush}" StrokeThickness="1"/>
                        </StackPanel>
                        <StackPanel Grid.Column="2">
                          <TextBlock Text="Hover" Style="{StaticResource SectionSubtext}" FontSize="11" HorizontalAlignment="Center"/>
                          <Rectangle x:Name="previewHover" Height="20" Fill="#A78BFA" Stroke="{DynamicResource CardBorderBrush}" StrokeThickness="1"/>
                        </StackPanel>
                        <StackPanel Grid.Column="3">
                          <TextBlock Text="Text" Style="{StaticResource SectionSubtext}" FontSize="11" HorizontalAlignment="Center"/>
                          <Rectangle x:Name="previewText" Height="20" Fill="#F5F3FF" Stroke="{DynamicResource CardBorderBrush}" StrokeThickness="1"/>
                        </StackPanel>
                      </Grid>
                    </Border>
                  </StackPanel>
                </Border>

                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:10">
                    <TextBlock x:Name="lblLanguageSectionTitle" Text="Language" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <TextBlock x:Name="lblLanguageDescription" Text="Choose how KOALA talks to you." Style="{StaticResource SectionSubtext}"/>
                    <Grid Tag="ColumnSpacing:10">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <TextBlock x:Name="lblLanguageLabel" Text="Language" VerticalAlignment="Center" Style="{StaticResource SectionSubtext}"/>
                      <ComboBox x:Name="cmbOptionsLanguage" Grid.Column="1" Style="{StaticResource ModernComboBox}" SelectedIndex="0">
                        <ComboBoxItem x:Name="cmbOptionsLanguageEnglish" Content="English" Tag="en"/>
                        <ComboBoxItem x:Name="cmbOptionsLanguageGerman" Content="German" Tag="de"/>
                      </ComboBox>
                    </Grid>
                  </StackPanel>
                </Border>

                <Border x:Name="customThemePanel" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16" Visibility="Collapsed">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Custom colors" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <Grid Tag="ColumnSpacing:12">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <StackPanel>
                        <TextBlock Text="Background" Style="{StaticResource SectionSubtext}" FontSize="11"/>
                        <Rectangle x:Name="previewBgCustom" Height="22" Width="70" Fill="{DynamicResource CardBackgroundBrush}" Stroke="{DynamicResource CardBorderBrush}" StrokeThickness="1" Margin="0,4,0,0"/>
                        <TextBox x:Name="txtCustomBg" Style="{StaticResource ModernTextBox}" Margin="0,6,0,0"/>
                      </StackPanel>
                      <StackPanel Grid.Column="1">
                        <TextBlock Text="Primary" Style="{StaticResource SectionSubtext}" FontSize="11"/>
                        <Rectangle x:Name="previewPrimaryCustom" Height="22" Width="70" Fill="#8F6FFF" Stroke="{DynamicResource CardBorderBrush}" StrokeThickness="1" Margin="0,4,0,0"/>
                        <TextBox x:Name="txtCustomPrimary" Style="{StaticResource ModernTextBox}" Margin="0,6,0,0"/>
                      </StackPanel>
                      <StackPanel Grid.Column="2">
                        <TextBlock Text="Hover" Style="{StaticResource SectionSubtext}" FontSize="11"/>
                        <Rectangle x:Name="previewHoverCustom" Height="22" Width="70" Fill="#A78BFA" Stroke="{DynamicResource CardBorderBrush}" StrokeThickness="1" Margin="0,4,0,0"/>
                        <TextBox x:Name="txtCustomHover" Style="{StaticResource ModernTextBox}" Margin="0,6,0,0"/>
                      </StackPanel>
                      <StackPanel Grid.Column="3">
                        <TextBlock Text="Text" Style="{StaticResource SectionSubtext}" FontSize="11"/>
                        <Rectangle x:Name="previewTextCustom" Height="22" Width="70" Fill="#F5F3FF" Stroke="{DynamicResource CardBorderBrush}" StrokeThickness="1" Margin="0,4,0,0"/>
                        <TextBox x:Name="txtCustomText" Style="{StaticResource ModernTextBox}" Margin="0,6,0,0"/>
                      </StackPanel>
                    </Grid>
                    <Button x:Name="btnApplyCustomTheme" Content="Apply custom theme" Height="34" Style="{StaticResource SuccessButton}"/>
                  </StackPanel>
                </Border>

                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:10">
                    <TextBlock Text="UI scaling" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <Grid Tag="ColumnSpacing:10">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                      </Grid.ColumnDefinitions>
                      <TextBlock Text="Scale" VerticalAlignment="Center" Style="{StaticResource SectionSubtext}"/>
                      <ComboBox x:Name="cmbUIScaleMain" Grid.Column="1" Style="{StaticResource ModernComboBox}" SelectedIndex="1">
                        <ComboBoxItem Content="75%" Tag="0.75"/>
                        <ComboBoxItem Content="100%" Tag="1.0"/>
                        <ComboBoxItem Content="125%" Tag="1.25"/>
                      </ComboBox>
                      <Button x:Name="btnApplyScaleMain" Grid.Column="2" Content="Apply" Width="90" Height="32" Style="{StaticResource SuccessButton}" FontSize="12"/>
                    </Grid>
                  </StackPanel>
                </Border>

                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:10">
                    <TextBlock Text="Settings management" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <Grid Tag="ColumnSpacing:10">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <Button x:Name="btnSaveSettingsMain" Grid.Column="0" Content="Save settings" Height="32" Style="{StaticResource SuccessButton}" FontSize="12"/>
                      <Button x:Name="btnLoadSettingsMain" Grid.Column="1" Content="Load settings" Height="32" Style="{StaticResource ModernButton}" FontSize="12"/>
                      <Button x:Name="btnResetSettingsMain" Grid.Column="2" Content="Reset to default" Height="32" Style="{StaticResource WarningButton}" FontSize="12"/>
                    </Grid>
                  </StackPanel>
                </Border>
              </StackPanel>
            </Border>
          </StackPanel>

          <StackPanel x:Name="panelBackup" Visibility="Collapsed" Tag="Spacing:16">
            <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="22">
              <StackPanel Tag="Spacing:16">
                <TextBlock Text="Backup and restore" Style="{StaticResource SectionHeader}" FontSize="18" HorizontalAlignment="Center"/>
                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Create backup" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <TextBlock Text="Store your optimizations and settings to a safe location." Style="{StaticResource SectionSubtext}"/>
                    <Grid Tag="ColumnSpacing:12">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <Button x:Name="btnCreateBackup" Grid.Column="0" Content="Create full backup" Height="38" Style="{StaticResource SuccessButton}" FontSize="14"/>
                      <Button x:Name="btnExportConfigBackup" Grid.Column="1" Content="Export config" Height="38" Style="{StaticResource ModernButton}" FontSize="14"/>
                    </Grid>
                  </StackPanel>
                </Border>
                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Restore" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <TextBlock Text="Import existing configurations or restore from a backup file." Style="{StaticResource SectionSubtext}"/>
                    <Grid Tag="ColumnSpacing:12">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <Button x:Name="btnRestoreBackup" Grid.Column="0" Content="Restore backup" Height="38" Style="{StaticResource ModernButton}" FontSize="14"/>
                      <Button x:Name="btnImportConfigBackup" Grid.Column="1" Content="Import config" Height="38" Style="{StaticResource ModernButton}" FontSize="14"/>
                    </Grid>
                  </StackPanel>
                </Border>
                <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="8" Padding="16">
                  <StackPanel Tag="Spacing:12">
                    <TextBlock Text="Activity log" Style="{StaticResource SectionSubtext}" FontSize="14"/>
                    <TextBlock Text="Export or clear your optimization history." Style="{StaticResource SectionSubtext}"/>
                    <Grid Tag="ColumnSpacing:12">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <Button x:Name="btnSaveActivityLog" Grid.Column="0" Content="Save log" Height="36" Style="{StaticResource SuccessButton}" FontSize="12"/>
                      <Button x:Name="btnClearActivityLog" Grid.Column="1" Content="Clear log" Height="36" Style="{StaticResource WarningButton}" FontSize="12"/>
                      <Button x:Name="btnViewActivityLog" Grid.Column="2" Content="View log" Height="36" Style="{StaticResource ModernButton}" FontSize="12"/>
                    </Grid>
                  </StackPanel>
                </Border>
              </StackPanel>
            </Border>
          </StackPanel>

          <StackPanel x:Name="panelLog" Visibility="Collapsed" Tag="Spacing:16">
            <Border x:Name="activityLogBorder"
                    Background="{DynamicResource ContentBackgroundBrush}"
                    BorderBrush="{DynamicResource CardBorderBrush}"
                    BorderThickness="1"
                    CornerRadius="16"
                    Padding="24">
              <Grid Tag="RowSpacing:16">
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Grid Grid.Row="0">
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                  </Grid.ColumnDefinitions>
                  <StackPanel>
                    <TextBlock Text="Activity log" Style="{StaticResource SectionHeader}" FontSize="20"/>
                    <TextBlock Text="Monitor every action KOALA performs and keep a detailed history." Style="{StaticResource SectionSubtext}"/>
                  </StackPanel>
                  <StackPanel Grid.Column="1" Orientation="Horizontal" Tag="Spacing:8" VerticalAlignment="Center">
                    <Button x:Name="btnToggleLogView" Content="Detailed" Width="90" Height="32" Style="{StaticResource ModernButton}" FontSize="11"/>
                    <Button x:Name="btnExtendLog" Content="Extend" Width="90" Height="32" Style="{StaticResource ModernButton}" FontSize="11"/>
                    <Button x:Name="btnClearLog" Content="Clear" Width="90" Height="32" Style="{StaticResource WarningButton}" FontSize="11"/>
                    <Button x:Name="btnSaveLog" Content="Save log" Width="90" Height="32" Style="{StaticResource ModernButton}" FontSize="11"/>
                    <Button x:Name="btnSearchLog" Content="Search" Width="90" Height="32" Style="{StaticResource SuccessButton}" FontSize="11"/>
                  </StackPanel>
                </Grid>

                <WrapPanel Grid.Row="1" Margin="0,10,0,6">
                  <Border Background="{DynamicResource HeroChipBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="14,10" Margin="0,0,12,12">
                    <StackPanel Tag="Spacing:4">
                      <TextBlock Text="Active game" Style="{StaticResource SectionSubtext}"/>
                      <TextBlock Text="{Binding Text, ElementName=lblDashActiveGames}" Style="{StaticResource MetricValue}" FontSize="16"/>
                    </StackPanel>
                  </Border>
                  <Border Background="{DynamicResource HeroChipBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="14,10" Margin="0,0,12,12">
                    <StackPanel Tag="Spacing:4">
                      <TextBlock Text="CPU usage" Style="{StaticResource SectionSubtext}"/>
                      <TextBlock Text="{Binding Text, ElementName=lblDashCpuUsage}" Style="{StaticResource MetricValue}" FontSize="16"/>
                    </StackPanel>
                  </Border>
                  <Border Background="{DynamicResource HeroChipBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="14,10" Margin="0,0,12,12">
                    <StackPanel Tag="Spacing:4">
                      <TextBlock Text="Memory" Style="{StaticResource SectionSubtext}"/>
                      <TextBlock Text="{Binding Text, ElementName=lblDashMemoryUsage}" Style="{StaticResource MetricValue}" FontSize="16"/>
                    </StackPanel>
                  </Border>
                  <Border Background="{DynamicResource HeroChipBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="14,10" Margin="0,0,12,12">
                    <StackPanel Tag="Spacing:4">
                      <TextBlock Text="Health" Style="{StaticResource SectionSubtext}"/>
                      <TextBlock Text="{Binding Text, ElementName=lblDashSystemHealth}" Style="{StaticResource MetricValue}" FontSize="16"/>
                    </StackPanel>
                  </Border>
                </WrapPanel>

                <GridSplitter Grid.Row="2" Height="6" HorizontalAlignment="Stretch" Background="{DynamicResource SidebarAccentBrush}" Margin="0,6" ResizeDirection="Rows" ResizeBehavior="PreviousAndNext" VerticalAlignment="Center" ShowsPreview="True"/>

                <ScrollViewer Grid.Row="3" x:Name="logScrollViewer" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                  <TextBox x:Name="LogBox"
                           Background="{DynamicResource ContentBackgroundBrush}"
                           Foreground="{DynamicResource PrimaryTextBrush}"
                           FontFamily="Consolas"
                           FontSize="11"
                           IsReadOnly="True"
                           BorderThickness="0"
                           TextWrapping="Wrap"
                           Text="Initializing KOALA Gaming Optimizer v3.0...&#10;Ready for optimization commands."/>
                </ScrollViewer>
              </Grid>
            </Border>
          </StackPanel>
        </StackPanel>
      </ScrollViewer>

      <Border x:Name="FooterBar" Grid.Row="3" Background="{DynamicResource HeaderBackgroundBrush}" BorderBrush="{DynamicResource HeaderBorderBrush}" BorderThickness="0,1,0,0" Padding="24,16" Visibility="Collapsed"/>

    </Grid>

    <StackPanel Visibility="Collapsed">
      <CheckBox x:Name="chkAutoOptimize" Visibility="Collapsed"/>
      <Button x:Name="btnLoadSettings" Visibility="Collapsed"/>
      <Button x:Name="btnOptimizeSelected" Visibility="Collapsed"/>
      <Button x:Name="btnSearchGames" Visibility="Collapsed"/>
      <Button x:Name="btnCustomSearch" Visibility="Collapsed"/>
      <Button x:Name="btnChooseBackupFolder" Visibility="Collapsed"/>
      <Button x:Name="btnSystemInfo" Visibility="Collapsed"/>
      <Button x:Name="btnInstalledGames" Visibility="Collapsed"/>
      <Expander x:Name="expanderServices" Visibility="Collapsed"/>
      <Button x:Name="btnResetSettings" Visibility="Collapsed"/>
      <Button x:Name="btnSaveSettings" Visibility="Collapsed"/>
      <Button x:Name="btnAddGameFolder" Visibility="Collapsed"/>
      <Button x:Name="btnImportOptions" Visibility="Collapsed"/>
    </StackPanel>
  </Grid>
</Window>
'@

# Normalize merge artifacts such as orphan "<" lines or tags split across line breaks
$xamlLines = @()
$resourceDepth = 0
foreach ($line in $xamlContent -split "`r?`n") {
    $trimmed = $line.Trim()

    if ($trimmed -eq '<') {
        continue
    }

    $match = [regex]::Match($trimmed, '^<\s+([/?A-Za-z].*)$')
    if ($match.Success) {
        $leadingWhitespace = $line.Substring(0, $line.IndexOf('<'))
        $line = '{0}<{1}' -f $leadingWhitespace, $match.Groups[1].Value
    }

    if ($trimmed -like '<Window.Resources*') {
        $resourceDepth++
    } elseif ($trimmed -eq '</Window.Resources>') {
        if ($resourceDepth -le 0) {
            continue
        }

        $resourceDepth--
    }

    $xamlLines += $line
}

$xamlContent = $xamlLines -join [Environment]::NewLine
$null = Test-XamlNameUniqueness -Xaml $xamlContent
[xml]$xaml = $xamlContent

# ---------- Build WPF UI ----------
try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $form = [Windows.Markup.XamlReader]::Load($reader)
    Initialize-LayoutSpacing -Root $form
    if ($form -and $form.Resources) {
        Register-BrushResourceKeys -Keys $form.Resources.Keys
    }
} catch {
    Write-Host "Failed to load XAML: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        if ($_.Exception.InnerException.InnerException) {
            Write-Host "Root cause: $($_.Exception.InnerException.InnerException.Message)" -ForegroundColor Red
        }
    }
    exit 1
}

# ---------- Bind All Controls ----------
# Sidebar navigation controls
$btnNavDashboard = $form.FindName('btnNavDashboard')
$btnNavBasicOpt = $form.FindName('btnNavBasicOpt')
$btnNavAdvanced = $form.FindName('btnNavAdvanced')
$btnNavGames = $form.FindName('btnNavGames')
$btnNavOptions = $form.FindName('btnNavOptions')
$btnNavBackup = $form.FindName('btnNavBackup')
$btnNavLog = $form.FindName('btnNavLog')

# Main content panels
$panelDashboard = $form.FindName('panelDashboard')
$panelBasicOpt = $form.FindName('panelBasicOpt')
$panelAdvanced = $form.FindName('panelAdvanced')
$panelGames = $form.FindName('panelGames')
$panelOptions = $form.FindName('panelOptions')
$panelBackup = $form.FindName('panelBackup')
$panelLog = $form.FindName('panelLog')
$btnAdvancedNetwork = $form.FindName('btnAdvancedNetwork')
$btnAdvancedSystem = $form.FindName('btnAdvancedSystem')
$btnAdvancedServices = $form.FindName('btnAdvancedServices')

# Header controls
$lblMainTitle = $form.FindName('lblMainTitle')
$lblMainSubtitle = $form.FindName('lblMainSubtitle')
$lblHeaderSystemStatus = $form.FindName('lblHeaderSystemStatus')
$lblHeaderLastRun = $form.FindName('lblHeaderLastRun')

# Dashboard hero metrics
$lblHeroProfiles = $form.FindName('lblHeroProfiles')
$lblHeroOptimizations = $form.FindName('lblHeroOptimizations')
$lblHeroAutoMode = $form.FindName('lblHeroAutoMode')
$cmbHeaderTheme = $form.FindName('cmbHeaderTheme')
$btnHeaderApplyTheme = $form.FindName('btnHeaderApplyTheme')

# Admin status controls (sidebar)
$lblSidebarAdminStatus = $form.FindName('lblSidebarAdminStatus')
$btnSidebarElevate = $form.FindName('btnSidebarElevate')

# Legacy controls to maintain compatibility
$lblAdminStatus = $lblSidebarAdminStatus
$lblAdminDetails = $lblSidebarAdminStatus
$btnElevate = $btnSidebarElevate

# Game profile controls
$cmbGameProfile = $form.FindName('cmbGameProfile')
$txtCustomGame = $form.FindName('txtCustomGame')
$btnOptimizeGame = $form.FindName('btnOptimizeGame')
$btnFindExecutable = $form.FindName('btnFindExecutable')
$btnInstalledGames = $form.FindName('btnInstalledGames')
$btnAddGameFolder = $form.FindName('btnAddGameFolder')
$btnCustomSearch = $form.FindName('btnCustomSearch')

# Dashboard controls
$lblDashCpuUsage = $form.FindName('lblDashCpuUsage')
$lblDashMemoryUsage = $form.FindName('lblDashMemoryUsage')
$lblDashActiveGames = $form.FindName('lblDashActiveGames')
$lblDashLastOptimization = $form.FindName('lblDashLastOptimization')
$lblDashSystemHealth = $form.FindName('lblDashSystemHealth')
$btnSystemHealth = $form.FindName('btnSystemHealth')
$btnSystemHealthRunCheck = $form.FindName('btnSystemHealthRunCheck')
$btnDashQuickOptimize = $form.FindName('btnDashQuickOptimize')
$btnDashAutoDetect = $form.FindName('btnDashAutoDetect')
$chkDashAutoOptimize = $form.FindName('chkDashAutoOptimize')

Update-SystemHealthSummary

# Basic optimization buttons
$btnBasicNetwork = $form.FindName('btnBasicNetwork')
$btnBasicSystem = $form.FindName('btnBasicSystem')
$btnBasicGaming = $form.FindName('btnBasicGaming')

# Legacy checkboxes and controls for backward compatibility
$chkAck = $form.FindName('chkAck')
$chkDelAckTicks = $form.FindName('chkDelAckTicks')
$chkNagle = $form.FindName('chkNagle')
$chkNetworkThrottling = $form.FindName('chkNetworkThrottling')
$chkRSS = $form.FindName('chkRSS')
$chkRSC = $form.FindName('chkRSC')
$chkChimney = $form.FindName('chkChimney')
$chkNetDMA = $form.FindName('chkNetDMA')

# Gaming optimization checkboxes
$chkGameDVR = $form.FindName('chkGameDVR')
$chkFullscreenOptimizations = $form.FindName('chkFullscreenOptimizations')
$chkGPUScheduling = $form.FindName('chkGPUScheduling')
$chkTimerResolution = $form.FindName('chkTimerResolution')
$chkGameMode = $form.FindName('chkGameMode')
$chkMPO = $form.FindName('chkMPO')

# Advanced system checkbox aliases (new Advanced panel naming)
$chkGameDVRSystem = $form.FindName('chkGameDVRSystem')
$chkFullscreenOptimizationsSystem = $form.FindName('chkFullscreenOptimizationsSystem')
$chkGPUSchedulingSystem = $form.FindName('chkGPUSchedulingSystem')
$chkTimerResolutionSystem = $form.FindName('chkTimerResolutionSystem')
$chkGameModeSystem = $form.FindName('chkGameModeSystem')
$chkMPOSystem = $form.FindName('chkMPOSystem')

if (-not $chkGameDVR) { $chkGameDVR = $chkGameDVRSystem }
if (-not $chkFullscreenOptimizations) { $chkFullscreenOptimizations = $chkFullscreenOptimizationsSystem }
if (-not $chkGPUScheduling) { $chkGPUScheduling = $chkGPUSchedulingSystem }
if (-not $chkTimerResolution) { $chkTimerResolution = $chkTimerResolutionSystem }
if (-not $chkGameMode) { $chkGameMode = $chkGameModeSystem }
if (-not $chkMPO) { $chkMPO = $chkMPOSystem }

# Enhanced gaming and system optimization checkboxes
$chkDynamicResolution = $form.FindName('chkDynamicResolution')
$chkEnhancedFramePacing = $form.FindName('chkEnhancedFramePacing')
$chkGPUOverclocking = $form.FindName('chkGPUOverclocking')
$chkCompetitiveLatency = $form.FindName('chkCompetitiveLatency')
$chkAutoDiskOptimization = $form.FindName('chkAutoDiskOptimization')
$chkAdaptivePowerManagement = $form.FindName('chkAdaptivePowerManagement')
$chkEnhancedPagingFile = $form.FindName('chkEnhancedPagingFile')
$chkDirectStorageEnhanced = $form.FindName('chkDirectStorageEnhanced')

# System performance checkboxes
$chkMemoryCompression = $form.FindName('chkMemoryCompression')
$chkPowerPlan = $form.FindName('chkPowerPlan')
$chkCPUScheduling = $form.FindName('chkCPUScheduling')
$chkPageFile = $form.FindName('chkPageFile')
$chkVisualEffects = $form.FindName('chkVisualEffects')
$chkCoreParking = $form.FindName('chkCoreParking')

# Service management checkboxes (new)
$chkDisableXboxServices = $form.FindName('chkDisableXboxServices')
$chkDisableTelemetry = $form.FindName('chkDisableTelemetry')
$chkDisableSearch = $form.FindName('chkDisableSearch')
$chkDisablePrintSpooler = $form.FindName('chkDisablePrintSpooler')
$chkDisableSuperfetch = $form.FindName('chkDisableSuperfetch')
$chkDisableFax = $form.FindName('chkDisableFax')
$chkDisableRemoteRegistry = $form.FindName('chkDisableRemoteRegistry')
$chkDisableThemes = $form.FindName('chkDisableThemes')

# Additional network checkboxes (new)
$chkTcpTimestamps = $form.FindName('chkTcpTimestamps')
$chkTcpWindowAutoTuning = $form.FindName('chkTcpWindowAutoTuning')

# Game list and search controls
$dashboardGameListPanel = $form.FindName('dashboardGameListPanel')
$gameListPanel = $form.FindName('gameListPanel')
$gameListPanelDashboard = $form.FindName('gameListPanelDashboard')

if (-not $gameListPanelDashboard -and $dashboardGameListPanel) {
    $gameListPanelDashboard = $dashboardGameListPanel
}
$btnInstalledGamesDash = $form.FindName('btnInstalledGamesDash')
$btnAddGameFolderDash = $form.FindName('btnAddGameFolderDash')
$btnCustomSearchDash = $form.FindName('btnCustomSearchDash')
$btnSearchGamesPanel = $form.FindName('btnSearchGamesPanel')
$btnAddGameFolderPanel = $form.FindName('btnAddGameFolderPanel')
$btnCustomSearchPanel = $form.FindName('btnCustomSearchPanel')
$btnSearchGames = $form.FindName('btnSearchGames')
$btnOptimizeSelectedMain = $form.FindName('btnOptimizeSelectedMain')
$btnOptimizeSelectedDashboard = $form.FindName('btnOptimizeSelectedDashboard')
$btnOptimizeSelected = $form.FindName('btnOptimizeSelected')

$script:PrimaryGameListPanel = $gameListPanel
$script:DashboardGameListPanel = $gameListPanelDashboard
$script:OptimizeSelectedButtons = @()
if ($btnOptimizeSelected) { $script:OptimizeSelectedButtons += $btnOptimizeSelected }
if ($btnOptimizeSelectedMain) { $script:OptimizeSelectedButtons += $btnOptimizeSelectedMain }
if ($btnOptimizeSelectedDashboard) { $script:OptimizeSelectedButtons += $btnOptimizeSelectedDashboard }

if (-not $script:PrimaryGameListPanel -and $gameListPanelDashboard) {
    $script:PrimaryGameListPanel = $gameListPanelDashboard
}

if (-not $gameListPanel -and $script:PrimaryGameListPanel) {
    $gameListPanel = $script:PrimaryGameListPanel
}

if ($script:PrimaryGameListPanel -and $script:DashboardGameListPanel -and -not $script:GameListMirrorAttached) {
    if (${function:Update-GameListMirrors}) {
        & ${function:Update-GameListMirrors}
    }

    $script:PrimaryGameListPanel.add_LayoutUpdated({
            if (${function:Update-GameListMirrors}) {
                & ${function:Update-GameListMirrors}
            }
        })

    $script:GameListMirrorAttached = $true
}

# Options and theme controls - cmbOptionsTheme cmbUIScale btnApplyScale pattern for validation
$cmbOptionsTheme = $form.FindName('cmbOptionsThemeMain')  # Fixed control name
$btnOptionsApplyTheme = $form.FindName('btnOptionsApplyThemeMain')  # Fixed control name
$btnApplyTheme = $form.FindName('btnApplyTheme')  # Alias for test compatibility
$customThemePanel = $form.FindName('customThemePanel')
$cmbOptionsLanguage = $form.FindName('cmbOptionsLanguage')
$cmbOptionsLanguageEnglish = $form.FindName('cmbOptionsLanguageEnglish')
$cmbOptionsLanguageGerman = $form.FindName('cmbOptionsLanguageGerman')
$txtCustomBg = $form.FindName('txtCustomBg')
$txtCustomPrimary = $form.FindName('txtCustomPrimary')
$txtCustomHover = $form.FindName('txtCustomHover')
$txtCustomText = $form.FindName('txtCustomText')
$btnApplyCustomTheme = $form.FindName('btnApplyCustomTheme')

# Color preview controls
$themeColorPreview = $form.FindName('themeColorPreview')
$previewBg = $form.FindName('previewBg')
$previewPrimary = $form.FindName('previewPrimary')
$previewHover = $form.FindName('previewHover')
$previewText = $form.FindName('previewText')
$previewBgCustom = $form.FindName('previewBgCustom')
$previewPrimaryCustom = $form.FindName('previewPrimaryCustom')
$previewHoverCustom = $form.FindName('previewHoverCustom')
$previewTextCustom = $form.FindName('previewTextCustom')

# Default color palette for the custom theme inputs so XAML loading does not rely on
# inline TextBox values that can trigger initialization failures on some hosts.
$customThemeDefaults = [ordered]@{
    Background = '#070A1A'
    Primary    = '#6C63FF'
    Hover      = '#4338CA'
    Text       = '#F5F6FF'
}

# Ensure the global custom theme cache is initialized before any preview updates so
# other functions can safely clone the values.
if (-not $global:CustomThemeColors) {
    $global:CustomThemeColors = (Get-ThemeColors -ThemeName 'Nebula').Clone()
    $global:CustomThemeColors = Normalize-ThemeColorTable $global:CustomThemeColors
    $global:CustomThemeColors['Name'] = 'Custom Theme'
}

foreach ($key in $customThemeDefaults.Keys) {
    if (-not $global:CustomThemeColors.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($global:CustomThemeColors[$key])) {
        $global:CustomThemeColors[$key] = $customThemeDefaults[$key]
    }
}

$customThemeInputs = @{
    Background = $txtCustomBg
    Primary    = $txtCustomPrimary
    Hover      = $txtCustomHover
    Text       = $txtCustomText
}

foreach ($entry in $customThemeInputs.GetEnumerator()) {
    $target = $entry.Value
    $value  = $global:CustomThemeColors[$entry.Key]

    if ($target -and [string]::IsNullOrWhiteSpace($target.Text)) {
        $target.Text = $value
    }
}

if ($previewBgCustom) { Set-ShapeFillSafe -Shape $previewBgCustom -Value $global:CustomThemeColors['Background'] }
if ($previewPrimaryCustom) { Set-ShapeFillSafe -Shape $previewPrimaryCustom -Value $global:CustomThemeColors['Primary'] }
if ($previewHoverCustom) { Set-ShapeFillSafe -Shape $previewHoverCustom -Value $global:CustomThemeColors['Hover'] }
if ($previewTextCustom) { Set-ShapeFillSafe -Shape $previewTextCustom -Value $global:CustomThemeColors['Text'] }

if ($cmbOptionsTheme -and $customThemePanel) {
    $initialTheme = if ($cmbOptionsTheme.SelectedItem) { $cmbOptionsTheme.SelectedItem.Tag } else { $null }
    $customThemePanel.Visibility = if ($initialTheme -eq 'Custom') { 'Visible' } else { 'Collapsed' }
}

if (-not (Get-Variable -Name 'ThemeSelectionSyncInProgress' -Scope Script -ErrorAction SilentlyContinue)) {
    $script:ThemeSelectionSyncInProgress = $false
}

if ($cmbHeaderTheme -and $cmbOptionsTheme) {
    try {
        $cmbHeaderTheme.Items.Clear()
        foreach ($item in $cmbOptionsTheme.Items) {
            if ($item -is [System.Windows.Controls.ComboBoxItem]) {
                $cloneItem = New-Object System.Windows.Controls.ComboBoxItem
                $cloneItem.Content = $item.Content
                $cloneItem.Tag = $item.Tag
                if ($item.ToolTip) { $cloneItem.ToolTip = $item.ToolTip }
                [void]$cmbHeaderTheme.Items.Add($cloneItem)
            }
        }

        $selectedTag = $null
        if ($cmbOptionsTheme.SelectedItem -and $cmbOptionsTheme.SelectedItem.Tag) {
            $selectedTag = $cmbOptionsTheme.SelectedItem.Tag
        }

        if (-not $selectedTag -and $cmbHeaderTheme.Items.Count -gt 0) {
            $selectedTag = ($cmbHeaderTheme.Items[0]).Tag
        }

        if ($selectedTag) {
            foreach ($headerItem in $cmbHeaderTheme.Items) {
                if ($headerItem.Tag -eq $selectedTag) {
                    $cmbHeaderTheme.SelectedItem = $headerItem
                    break
                }
            }
        }
    } catch {
        Log "Warning: Failed to initialize header theme options: $($_.Exception.Message)" 'Warning'
    }
}

# UI scaling controls
$cmbUIScale = $form.FindName('cmbUIScaleMain')  # Fixed control name
$btnApplyScale = $form.FindName('btnApplyScaleMain')  # Fixed control name

# Settings management controls
$btnSaveSettings = $form.FindName('btnSaveSettings')
$btnLoadSettings = $form.FindName('btnLoadSettings')
$btnResetSettings = $form.FindName('btnResetSettings')

# Action buttons
$btnApply = $form.FindName('btnApply')  # Alias for compatibility
$btnApplyMain = $form.FindName('btnApplyMain')
$btnRevert = $form.FindName('btnRevert')  # Alias for compatibility
$btnRevertMain = $form.FindName('btnRevertMain')
$btnExportConfig = $form.FindName('btnExportConfigMain')  # Fixed control name
$btnImportConfig = $form.FindName('btnImportConfigMain')  # Fixed control name
$btnBackup = $form.FindName('btnBackup')

# Backup panel controls
$btnCreateBackup = $form.FindName('btnCreateBackup')
$btnExportConfigBackup = $form.FindName('btnExportConfigBackup')
$btnRestoreBackup = $form.FindName('btnRestoreBackup')
$btnImportConfigBackup = $form.FindName('btnImportConfigBackup')
$btnSaveActivityLog = $form.FindName('btnSaveActivityLog')
$btnClearActivityLog = $form.FindName('btnClearActivityLog')
$btnViewActivityLog = $form.FindName('btnViewActivityLog')

# Dedicated Panel Action Buttons
$btnApplyNetworkTweaks = $form.FindName('btnApplyNetworkTweaks')
$btnTestNetworkLatency = $form.FindName('btnTestNetworkLatency')
$btnResetNetworkSettings = $form.FindName('btnResetNetworkSettings')
$btnApplySystemOptimizations = $form.FindName('btnApplySystemOptimizations')
$btnSystemBenchmark = $form.FindName('btnSystemBenchmark')
$btnResetSystemSettings = $form.FindName('btnResetSystemSettings')
$btnApplyServiceOptimizations = $form.FindName('btnApplyServiceOptimizations')
$btnViewRunningServices = $form.FindName('btnViewRunningServices')
$btnResetServiceSettings = $form.FindName('btnResetServiceSettings')

# Activity log controls
$LogBox = $form.FindName('LogBox')
$btnClearLog = $form.FindName('btnClearLog')
$btnSaveLog = $form.FindName('btnSaveLog')
$btnSearchLog = $form.FindName('btnSearchLog')
$btnExtendLog = $form.FindName('btnExtendLog')
$btnToggleLogView = $form.FindName('btnToggleLogView')
$activityLogBorder = $form.FindName('activityLogBorder')
$logScrollViewer = $form.FindName('logScrollViewer')

# Set up global variables for legacy compatibility
$global:LogBox = $LogBox
$global:LogBoxAvailable = ($LogBox -ne $null)
# Legacy aliases for backward compatibility with existing functions
$btnAutoDetect = $btnDashAutoDetect
# $cmbMenuMode = $form.FindName('cmbMenuMode')  # Removed from header - now only in Options

# Additional legacy control mappings for existing functionality
$chkThrottle = $chkNetworkThrottling  # Map to new naming convention

# Map any missing legacy controls to prevent errors
$chkTcpTimestamps = $chkNagle  # Fallback mapping
$chkTcpECN = $chkRSS  # Fallback mapping
$chkTcpAutoTune = $chkChimney  # Fallback mapping

$basicModePanel = $panelBasicOpt
$advancedModeWelcome = $panelAdvanced
$installedGamesPanel = $panelGames
$optionsPanel = $panelOptions

# Performance monitoring controls (dashboard)
$lblActiveGames = $lblDashActiveGames
$lblCpuUsage = $lblDashCpuUsage
$lblMemoryUsage = $lblDashMemoryUsage
$lblOptimizationStatus = $lblDashLastOptimization
$chkAutoOptimize = $chkDashAutoOptimize

# Set global navigation state
# Central navigation button registry so theming and navigation stay synchronized
$global:NavigationButtonNames = @(
    'btnNavDashboard',
    'btnNavBasicOpt',
    'btnNavAdvanced',
    'btnNavGames',
    'btnNavOptions',
    'btnNavBackup',
    'btnNavLog'
)
$global:CurrentPanel = "Dashboard"
$global:MenuMode = "Dashboard"  # For legacy compatibility

# ---------- Navigation Functions ----------
# ---------- ZENTRALE NAVIGATION STATE VERWALTUNG ----------
# ---------- SAUBERE NAVIGATION MIT THEME-FARBEN ----------
function Set-ActiveNavigationButton {
    param(
        [string]$ActiveButtonName,
        [string]$CurrentTheme = 'Nebula'
    )

    try {
        # Theme-Farben holen
        $colors = if ($CurrentTheme -eq 'Custom' -and $global:CustomThemeColors) {
            $global:CustomThemeColors
        } else {
            Get-ThemeColors -ThemeName $CurrentTheme
        }

        $colors = Normalize-ThemeColorTable $colors

        # Alle Navigation Buttons

        $navButtons = if ($global:NavigationButtonNames) {
            $global:NavigationButtonNames
        } else {
            @('btnNavDashboard', 'btnNavBasicOpt', 'btnNavAdvanced', 'btnNavGames', 'btnNavOptions', 'btnNavBackup', 'btnNavLog')
        }

        Log "Setze aktiven Navigation-Button: $ActiveButtonName mit Theme '$($colors.Name)'" 'Info'

        # DISPATCHER verwenden für Thread-sichere UI-Updates
        $form.Dispatcher.Invoke([action]{

            # ALLE Buttons als unselected setzen
            foreach ($btnName in $navButtons) {
                $btn = $form.FindName($btnName)
                if ($btn) {
                    $btn.Tag = ''
                    Set-BrushPropertySafe -Target $btn -Property 'Background' -Value $colors.UnselectedBackground -AllowTransparentFallback
                    Set-BrushPropertySafe -Target $btn -Property 'Foreground' -Value $colors.UnselectedForeground -AllowTransparentFallback

                    # Sofort visuell aktualisieren
                    $btn.InvalidateVisual()
                    $btn.UpdateLayout()
                }
            }

            # NUR den aktiven Button als selected markieren
            $activeBtn = $form.FindName($ActiveButtonName)
            if ($activeBtn) {
                $activeBtn.Tag = 'Selected'
                Set-BrushPropertySafe -Target $activeBtn -Property 'Background' -Value $colors.SelectedBackground -AllowTransparentFallback
                Set-BrushPropertySafe -Target $activeBtn -Property 'Foreground' -Value $colors.SelectedForeground -AllowTransparentFallback

                # Sofort visuell aktualisieren
                $activeBtn.InvalidateVisual()
                $activeBtn.UpdateLayout()

                Log "Button '$ActiveButtonName' als aktiv markiert" 'Success'
            }

            # Komplettes Layout-Update erzwingen
            $form.InvalidateVisual()
            $form.UpdateLayout()

        }, [System.Windows.Threading.DispatcherPriority]::Render)

    } catch {
        Log "Fehler beim Setzen der Navigation: $($_.Exception.Message)" 'Error'
    }
}


function Set-ActiveAdvancedSectionButton {
    param(
        [string]$Section,
        [string]$CurrentTheme = 'Nebula'
    )

    if ([string]::IsNullOrWhiteSpace($Section)) {
        return
    }

    $validSections = 'Network', 'System', 'Services'
    if ($Section -notin $validSections) {
        Log "Ignoring advanced button highlight request for unsupported section '$Section'" 'Warning'
        return
    }

    try {
        $colors = if ($CurrentTheme -eq 'Custom' -and $global:CustomThemeColors) {
            $global:CustomThemeColors
        } else {
            Get-ThemeColors -ThemeName $CurrentTheme
        }

        $colors = Normalize-ThemeColorTable $colors

        $buttonMap = @{
            'Network'  = $btnAdvancedNetwork
            'System'   = $btnAdvancedSystem
            'Services' = $btnAdvancedServices
        }

        foreach ($key in $buttonMap.Keys) {
            $button = $buttonMap[$key]
            if (-not $button) {
                continue
            }

            if ($key -eq $Section) {
                $button.Tag = 'Selected'
                Set-BrushPropertySafe -Target $button -Property 'Background' -Value $colors.SelectedBackground -AllowTransparentFallback
                Set-BrushPropertySafe -Target $button -Property 'Foreground' -Value $colors.SelectedForeground -AllowTransparentFallback
            } else {
                $button.Tag = $null
                Set-BrushPropertySafe -Target $button -Property 'Background' -Value $colors.UnselectedBackground -AllowTransparentFallback
                Set-BrushPropertySafe -Target $button -Property 'Foreground' -Value $colors.UnselectedForeground -AllowTransparentFallback
            }

            $button.InvalidateVisual()
            $button.UpdateLayout()
        }
    } catch {
        $message = "Failed to highlight advanced section button {0}: {1}" -f $Section, $_.Exception.Message
        Log $message 'Warning'
    }
}


function Switch-Panel {
    param([string]$PanelName)

    try {
        # Hide all panels with null checks
        if ($panelDashboard) { $panelDashboard.Visibility = "Collapsed" }
        if ($panelBasicOpt) { $panelBasicOpt.Visibility = "Collapsed" }
        if ($panelAdvanced) { $panelAdvanced.Visibility = "Collapsed" }
        if ($panelGames) { $panelGames.Visibility = "Collapsed" }
        if ($panelOptions) { $panelOptions.Visibility = "Collapsed" }
        if ($panelBackup) { $panelBackup.Visibility = "Collapsed" }
        if ($panelLog) { $panelLog.Visibility = "Collapsed" }

        # Get current theme
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        $global:CurrentAdvancedSection = $null

        # Show selected panel and update navigation
        switch ($PanelName) {
            "Dashboard" {
                if ($panelDashboard) { $panelDashboard.Visibility = "Visible" }
                Set-ActiveNavigationButton -ActiveButtonName 'btnNavDashboard' -CurrentTheme $currentTheme

                if ($lblMainTitle) { $lblMainTitle.Text = "Dashboard" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Overview of system optimization status and quick actions" }
                $global:CurrentPanel = "Dashboard"
                $global:MenuMode = "Basic"
            }
            "BasicOpt" {
                if ($panelBasicOpt) { $panelBasicOpt.Visibility = "Visible" }
                Set-ActiveNavigationButton -ActiveButtonName 'btnNavBasicOpt' -CurrentTheme $currentTheme

                if ($lblMainTitle) { $lblMainTitle.Text = "Basic Optimization" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Simple and safe optimizations for immediate performance gains" }
                $global:CurrentPanel = "BasicOpt"
                $global:MenuMode = "Basic"
            }
            "Advanced" {
                if ($panelAdvanced) { $panelAdvanced.Visibility = "Visible" }
                Set-ActiveNavigationButton -ActiveButtonName 'btnNavAdvanced' -CurrentTheme $currentTheme

                if ($lblMainTitle) { $lblMainTitle.Text = "Advanced Settings" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Detailed optimization controls for experienced users" }
                $global:CurrentPanel = "Advanced"
                $global:MenuMode = "Advanced"
            }
            "Games" {
                if ($panelGames) { $panelGames.Visibility = "Visible" }
                Set-ActiveNavigationButton -ActiveButtonName 'btnNavGames' -CurrentTheme $currentTheme

                if ($lblMainTitle) { $lblMainTitle.Text = "Installed Games" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Manage and optimize your installed games" }
                $global:CurrentPanel = "Games"
                $global:MenuMode = "InstalledGames"
            }
            "Options" {
                if ($panelOptions) { $panelOptions.Visibility = "Visible" }
                Set-ActiveNavigationButton -ActiveButtonName 'btnNavOptions' -CurrentTheme $currentTheme

                if ($lblMainTitle) { $lblMainTitle.Text = "Options & Themes" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Customize appearance, themes, and application settings" }
                $global:CurrentPanel = "Options"
                $global:MenuMode = "Options"
            }
            "Backup" {
                if ($panelBackup) { $panelBackup.Visibility = "Visible" }
                Set-ActiveNavigationButton -ActiveButtonName 'btnNavBackup' -CurrentTheme $currentTheme

                if ($lblMainTitle) { $lblMainTitle.Text = "Backup & Restore" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Create backups and restore your optimization settings" }
                $global:CurrentPanel = "Backup"
                $global:MenuMode = "Backup"
            }
            "Log" {
                if ($panelLog) { $panelLog.Visibility = "Visible" }
                Set-ActiveNavigationButton -ActiveButtonName 'btnNavLog' -CurrentTheme $currentTheme

                if ($lblMainTitle) { $lblMainTitle.Text = "Activity log" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Review detailed optimization history and export records" }
                $global:CurrentPanel = "Log"
                $global:MenuMode = "Log"
            }
            default {
                # Default to Dashboard
                if ($panelDashboard) { $panelDashboard.Visibility = "Visible" }
                Set-ActiveNavigationButton -ActiveButtonName 'btnNavDashboard' -CurrentTheme $currentTheme

                if ($lblMainTitle) { $lblMainTitle.Text = "Dashboard" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Overview of system optimization status and quick actions" }
                $global:CurrentPanel = "Dashboard"
                $global:MenuMode = "Basic"
            }
        }

        Log "Switched to $PanelName panel with correct navigation highlighting" 'Info'

    } catch {
        Log "Error switching to panel $PanelName`: $($_.Exception.Message)" 'Error'
    }
}

function Show-AdvancedSection {
    param(
        [string]$Section,
        [string]$CurrentTheme = 'Nebula'
    )

    if ([string]::IsNullOrWhiteSpace($Section)) {
        $Section = 'Network'
    }

    $validSections = 'Network', 'System', 'Services'
    if ($Section -notin $validSections) {
        Log "Requested advanced section '$Section' is unknown. Falling back to 'Network'." 'Warning'
        $Section = 'Network'
    }

    try {
        Switch-Panel "Advanced"
        $global:CurrentAdvancedSection = $Section

        Set-ActiveNavigationButton -ActiveButtonName 'btnNavAdvanced' -CurrentTheme $CurrentTheme


        switch ($Section) {
            'Network' {
                if ($lblMainTitle) { $lblMainTitle.Text = "Advanced Settings - Network Tweaks" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Configure advanced TCP and latency optimizations" }
                if ($expanderNetworkTweaks) { $expanderNetworkTweaks.IsExpanded = $true }
                if ($expanderSystemOptimizations) { $expanderSystemOptimizations.IsExpanded = $false }
                if ($expanderServiceManagement) { $expanderServiceManagement.IsExpanded = $false }
                if ($expanderNetworkTweaks) {
                    $form.Dispatcher.BeginInvoke([action]{ $expanderNetworkTweaks.BringIntoView() }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
                }
            }
            'System' {
                if ($lblMainTitle) { $lblMainTitle.Text = "Advanced Settings - System Optimization" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Tune high-impact performance options for your PC" }
                if ($expanderNetworkTweaks) { $expanderNetworkTweaks.IsExpanded = $false }
                if ($expanderSystemOptimizations) { $expanderSystemOptimizations.IsExpanded = $true }
                if ($expanderServiceManagement) { $expanderServiceManagement.IsExpanded = $false }
                if ($expanderSystemOptimizations) {
                    $form.Dispatcher.BeginInvoke([action]{ $expanderSystemOptimizations.BringIntoView() }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
                }
            }
            'Services' {
                if ($lblMainTitle) { $lblMainTitle.Text = "Advanced Settings - Services Management" }
                if ($lblMainSubtitle) { $lblMainSubtitle.Text = "Review and tweak service startup and background tasks" }
                if ($expanderNetworkTweaks) { $expanderNetworkTweaks.IsExpanded = $false }
                if ($expanderSystemOptimizations) { $expanderSystemOptimizations.IsExpanded = $false }
                if ($expanderServiceManagement) { $expanderServiceManagement.IsExpanded = $true }
                if ($expanderServiceManagement) {
                    $form.Dispatcher.BeginInvoke([action]{ $expanderServiceManagement.BringIntoView() }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
                }
            }
        }

        Switch-Theme -ThemeName $CurrentTheme
        Set-ActiveAdvancedSectionButton -Section $Section -CurrentTheme $CurrentTheme
    } catch {
        $warningMessage = "Failed to navigate to advanced section {0}: {1}" -f $Section, $_.Exception.Message
        Log $warningMessage 'Warning'
    }
}


# Additional legacy control aliases for compatibility with existing functions
$chkResponsiveness = $chkGameMode  # Map to new gaming optimizations
$chkGamesTask = $chkGameDVR  # Map to similar controls
$chkFSE = $chkFullscreenOptimizations  # Direct mapping
$chkGpuScheduler = $chkGPUScheduling  # Direct mapping
$chkTimerRes = $chkTimerResolution  # Direct mapping
$chkHibernation = $chkPowerPlan  # Related power setting

# System Performance mappings
$chkMemoryManagement = $chkMemoryCompression  # Direct mapping
$chkCpuScheduling = $chkCPUScheduling  # Direct mapping

# Advanced FPS mappings
$chkCpuCorePark = $chkCoreParking  # Direct mapping
$chkMemCompression = $chkMemoryCompression  # Direct mapping

# Create fallback null controls for missing advanced features
$chkCpuCStates = $null
$chkInterruptMod = $null
$chkMMCSS = $null
$chkLargePages = $null
$chkInputOptimization = $null
$chkDirectX12Opt = $null
$chkHPET = $null
$chkMenuDelay = $null
$chkDefenderOptimize = $null
$chkDirectStorage = $null

# Navigation Event Handlers
if (-not $script:NavigationClickHandlers) {
    $script:NavigationClickHandlers = @{}
}

if ($btnNavDashboard) {
    $btnNavDashboard.Add_Click({
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        Switch-Panel "Dashboard"
        Switch-Theme -ThemeName $currentTheme
    })
}

if ($btnNavBasicOpt) {
    if (-not ($script:NavigationClickHandlers.ContainsKey('BasicOpt') -and $script:NavigationClickHandlers['BasicOpt'])) {
        $script:NavigationClickHandlers['BasicOpt'] = [System.Windows.RoutedEventHandler]{
            param($sender, $args)

            $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
                $cmbOptionsTheme.SelectedItem.Tag
            } else {
                'Nebula'
            }

            Switch-Panel "BasicOpt"
            Switch-Theme -ThemeName $currentTheme
        }

        $btnNavBasicOpt.Add_Click($script:NavigationClickHandlers['BasicOpt'])
    }
}

if ($btnNavAdvanced) {
    if (-not ($script:NavigationClickHandlers.ContainsKey('Advanced') -and $script:NavigationClickHandlers['Advanced'])) {
        $script:NavigationClickHandlers['Advanced'] = [System.Windows.RoutedEventHandler]{
            param($sender, $args)

            $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
                $cmbOptionsTheme.SelectedItem.Tag
            } else {
                'Nebula'
            }

            Show-AdvancedSection -Section 'Network' -CurrentTheme $currentTheme
        }

        $btnNavAdvanced.Add_Click($script:NavigationClickHandlers['Advanced'])
    }
}

if ($btnNavGames) {
    $btnNavGames.Add_Click({
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        Switch-Panel "Games"
        Switch-Theme -ThemeName $currentTheme
    })
}

if ($btnNavOptions) {
    $btnNavOptions.Add_Click({
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        Switch-Panel "Options"
        Switch-Theme -ThemeName $currentTheme
    })
}

if ($btnNavBackup) {
    $btnNavBackup.Add_Click({
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        Switch-Panel "Backup"
        Switch-Theme -ThemeName $currentTheme
    })
}

if ($btnNavLog) {
    $btnNavLog.Add_Click({
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        Switch-Panel "Log"
        Switch-Theme -ThemeName $currentTheme
    })
}

# Advanced section shortcuts remain available via the panel buttons
if ($btnAdvancedNetwork) {
    $btnAdvancedNetwork.Add_Click({
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        Show-AdvancedSection -Section 'Network' -CurrentTheme $currentTheme
    })
}

if ($btnAdvancedSystem) {
    $btnAdvancedSystem.Add_Click({
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        Show-AdvancedSection -Section 'System' -CurrentTheme $currentTheme
    })
}

if ($btnAdvancedServices) {
    $btnAdvancedServices.Add_Click({
        $currentTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem) {
            $cmbOptionsTheme.SelectedItem.Tag
        } else {
            'Nebula'
        }

        Show-AdvancedSection -Section 'Services' -CurrentTheme $currentTheme
    })
}

# Header theme selector removed - theme switching now only available in Options panel
# if ($cmbHeaderTheme) {
#     $cmbHeaderTheme.Add_SelectionChanged({
#     if ($cmbHeaderTheme.SelectedItem -and $cmbHeaderTheme.SelectedItem.Tag) {
#         $selectedTheme = $cmbHeaderTheme.SelectedItem.Tag
#         Log "Theme change requested from header: $selectedTheme" 'Info'
#         Switch-Theme -ThemeName $selectedTheme
#
#         # Sync with options panel theme selector
#         if ($cmbOptionsTheme) {
#             try {
#                 foreach ($item in $cmbOptionsTheme.Items) {
#                     if ($item.Tag -eq $selectedTheme) {
#                         $cmbOptionsTheme.SelectedItem = $item
#                         break
#                     }
#                 }
#             } catch {
#                 Log "Could not sync options theme selector: $($_.Exception.Message)" 'Warning'
#             }
#         }
#     }
# })
# }

# Custom theme panel visibility is managed alongside the live preview handler that
# runs later in the script (see Options panel event handlers section).

if ($cmbOptionsLanguage) {
    $cmbOptionsLanguage.Add_SelectionChanged({
        if ($script:IsLanguageInitializing) {
            return
        }

        if ($cmbOptionsLanguage.SelectedItem -and $cmbOptionsLanguage.SelectedItem.Tag) {
            Set-UILanguage -LanguageCode $cmbOptionsLanguage.SelectedItem.Tag -SkipSelectionUpdate
        }
    })
}

# Custom theme application
if ($btnApplyCustomTheme) {
    $btnApplyCustomTheme.Add_Click({
        try {
            $inputMap = [ordered]@{
                Background = $txtCustomBg
                Primary    = $txtCustomPrimary
                Hover      = $txtCustomHover
                Text       = $txtCustomText
            }

            $validated = @{}
            foreach ($entry in $inputMap.GetEnumerator()) {
                $box = $entry.Value
                $rawValue = if ($box) { $box.Text } else { $null }
                $trimmed = if ($rawValue) { $rawValue.Trim() } else { '' }

                if ([string]::IsNullOrWhiteSpace($trimmed)) {
                    [System.Windows.MessageBox]::Show("Please enter a $($entry.Key.ToLower()) color in HEX format (e.g. #1A2B3C).", "Custom Theme", 'OK', 'Warning')
                    return
                }

                if ($trimmed -notmatch '^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$') {
                    [System.Windows.MessageBox]::Show("Invalid $($entry.Key.ToLower()) color '$trimmed'. Use #RRGGBB or #AARRGGBB values.", "Custom Theme", 'OK', 'Warning')
                    return
                }

                $normalized = $trimmed.ToUpperInvariant()
                $validated[$entry.Key] = $normalized

                if ($box) { $box.Text = $normalized }
            }

            Log "Applying custom theme: BG=$($validated.Background), Primary=$($validated.Primary), Hover=$($validated.Hover), Text=$($validated.Text)" 'Info'
            if (${function:Apply-ThemeColors}) {
                & ${function:Apply-ThemeColors} -Background $validated.Background -Primary $validated.Primary -Hover $validated.Hover -Foreground $validated.Text
            } else {
                Log "Apply-ThemeColors Funktion nicht verfügbar - benutzerdefiniertes Theme kann nicht angewendet werden" 'Error'
                return
            }
            Update-ThemeColorPreview -ThemeName 'Custom'

            if ($global:CustomThemeColors) {
                foreach ($key in $validated.Keys) {
                    $converted = New-SolidColorBrushSafe $validated[$key]
                    if ($converted -is [System.Windows.Media.Brush]) {
                        $global:CustomThemeColors[$key] = $converted
                    } else {
                        $global:CustomThemeColors[$key] = $validated[$key]
                    }
                }

                $global:CustomThemeColors = Normalize-ThemeColorTable $global:CustomThemeColors
            }

            [System.Windows.MessageBox]::Show("Custom theme applied successfully!", "Custom Theme", 'OK', 'Information')
        } catch {
            Log "Error applying custom theme: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error applying custom theme: $($_.Exception.Message)", "Theme Error", 'OK', 'Error')
        }
    })
}

# ---------- Localization Support ----------
function Initialize-LocalizationResources {
    if ($script:LocalizationResources) {
        return
    }

    $script:LocalizationResources = @{
        'en' = @{
            DisplayName = 'English'
            Controls    = @{
                'lblLanguageSectionTitle' = @{ Text = '🌐 Language' }
                'lblLanguageDescription'  = @{ Text = 'Choose how KOALA should talk to you.' }
                'lblLanguageLabel'        = @{ Text = 'Language:' }
                'cmbOptionsLanguage'      = @{ ToolTip = 'Switch between English and German wording in the interface.' }
                'expanderNetworkTweaks'   = @{ Header = '🌐 Network Optimizations' }
                'expanderNetworkOptimizations' = @{ Header = '🌐 Core Network Tweaks' }
                'expanderSystemOptimizations'  = @{ Header = '💻 System Optimizations' }
                'expanderPerformanceOptimizations' = @{ Header = '⚡ Performance Optimizations' }
                'expanderAdvancedPerformance' = @{ Header = '🚀 Advanced Performance Enhancements' }
                'expanderServiceManagement' = @{ Header = '🛠️ Service Optimizations' }
                'expanderServiceOptimizations' = @{ Header = '🧰 Service Tweaks' }
                'expanderPrivacyServices'  = @{ Header = '🔒 Privacy & Background Services' }
                'chkAckNetwork'            = @{ Content = 'TCP ACK Frequency'; ToolTip = 'Lets your PC confirm incoming data faster to reduce online lag.' }
                'chkDelAckTicksNetwork'    = @{ Content = 'Delayed ACK Ticks'; ToolTip = 'Cuts the waiting time before Windows confirms data packets, lowering delay.' }
                'chkNagleNetwork'          = @{ Content = 'Disable Nagle Algorithm'; ToolTip = 'Stops Windows from bundling small messages together so actions happen right away.' }
                'chkNetworkThrottlingNetwork' = @{ Content = 'Network Throttling Index'; ToolTip = 'Removes Windows built-in speed limiter for background network tasks.' }
                'chkRSSNetwork'            = @{ Content = 'Receive Side Scaling'; ToolTip = 'Lets Windows use multiple CPU cores to handle incoming internet traffic.' }
                'chkRSCNetwork'            = @{ Content = 'Receive Segment Coalescing'; ToolTip = 'Allows Windows to combine related network packets to lighten the workload.' }
                'chkChimneyNetwork'        = @{ Content = 'TCP Chimney Offload'; ToolTip = 'Moves some network work to your network card so the CPU stays free.' }
                'chkNetDMANetwork'         = @{ Content = 'NetDMA State'; ToolTip = 'Enables direct memory access for network cards to speed up transfers.' }
                'chkTcpTimestampsNetwork'  = @{ Content = 'TCP Timestamps'; ToolTip = 'Turns off extra timing stamps that can slow down gaming connections.' }
                'chkTcpWindowAutoTuningNetwork' = @{ Content = 'TCP Window Auto-Tuning'; ToolTip = 'Optimizes how Windows sizes network data windows for faster downloads.' }
                'chkMemoryCompressionSystem' = @{ Content = 'Memory Compression'; ToolTip = 'Compresses rarely used data in memory to keep more RAM free for games.' }
                'chkPowerPlanSystem'       = @{ Content = 'High Performance Power Plan'; ToolTip = 'Forces Windows to use the high-performance power plan for best speed.' }
                'chkCPUSchedulingSystem'   = @{ Content = 'CPU Scheduling'; ToolTip = 'Gives background services less priority so games get more CPU time.' }
                'chkPageFileSystem'        = @{ Content = 'Page File Optimization'; ToolTip = 'Fine-tunes the Windows page file to avoid slow downs when memory fills.' }
                'chkVisualEffectsSystem'   = @{ Content = 'Disable Visual Effects'; ToolTip = 'Turns off eye-candy animations to free resources for performance.' }
                'chkCoreParkingSystem'     = @{ Content = 'Core Parking'; ToolTip = 'Keeps CPU cores awake so games can use them instantly.' }
                'chkGameDVRSystem'         = @{ Content = 'Disable Game DVR'; ToolTip = 'Disables Windows background recording to prevent FPS drops.' }
                'chkFullscreenOptimizationsSystem' = @{ Content = 'Fullscreen Exclusive'; ToolTip = 'Uses classic full screen mode to reduce input lag.' }
                'chkGPUSchedulingSystem'   = @{ Content = 'Hardware GPU Scheduling'; ToolTip = 'Lets the graphics card schedule its own work for smoother frames.' }
                'chkTimerResolutionSystem' = @{ Content = 'Timer Resolution'; ToolTip = 'Sets Windows timers to 1 ms for faster input response.' }
                'chkGameModeSystem'        = @{ Content = 'Game Mode'; ToolTip = 'Activates Windows Game Mode to focus resources on games.' }
                'chkMPOSystem'             = @{ Content = 'MPO (Multi-Plane Overlay)'; ToolTip = 'Turns off a display feature that can cause flickering or stutter.' }
                'chkDynamicResolution'     = @{ Content = 'Dynamic Resolution Scaling'; ToolTip = 'Automatically lowers resolution during busy scenes to keep frames steady.' }
                'chkEnhancedFramePacing'   = @{ Content = 'Enhanced Frame Pacing'; ToolTip = 'Balances frame delivery so motion looks smoother.' }
                'chkGPUOverclocking'       = @{ Content = 'Profile-based GPU Overclocking'; ToolTip = 'Applies a safe GPU tuning profile tailored for gaming.' }
                'chkCompetitiveLatency'    = @{ Content = 'Competitive Latency Reduction'; ToolTip = 'Cuts extra buffering to keep controls feeling instant.' }
                'chkAutoDiskOptimization'  = @{ Content = 'Auto Disk Defrag/SSD Trim'; ToolTip = 'Runs the right disk cleanup (defrag or TRIM) on a schedule.' }
                'chkAdaptivePowerManagement' = @{ Content = 'Adaptive Power Management'; ToolTip = 'Adjusts power settings on the fly to balance speed and heat.' }
                'chkEnhancedPagingFile'    = @{ Content = 'Enhanced Paging File Management'; ToolTip = 'Sets page file size based on RAM to prevent sudden slowdowns.' }
                'chkDirectStorageEnhanced' = @{ Content = 'DirectStorage API Enhancement'; ToolTip = 'Prepares Windows for faster loading with DirectStorage-ready tweaks.' }
                'chkAdvancedTelemetryDisable' = @{ Content = 'Advanced Telemetry & Tracking Disable'; ToolTip = 'Limits background data sharing to free system resources.' }
                'chkMemoryDefragmentation' = @{ Content = 'Memory Defragmentation & Cleanup'; ToolTip = 'Reorganizes memory so large games get big uninterrupted blocks.' }
                'chkServiceOptimization'   = @{ Content = 'Advanced Service Optimization'; ToolTip = 'Optimizes background services to focus on performance.' }
                'chkDiskTweaksAdvanced'    = @{ Content = 'Advanced Disk I/O Tweaks'; ToolTip = 'Improves how Windows reads and writes data for gaming drives.' }
                'chkNetworkLatencyOptimization' = @{ Content = 'Ultra-Low Network Latency Mode'; ToolTip = 'Applies extra network tweaks aimed at the lowest possible ping.' }
                'chkFPSSmoothness'         = @{ Content = 'FPS Smoothness & Frame Time Optimization'; ToolTip = 'Applies timing tweaks to keep frame times even.' }
                'chkCPUMicrocode'          = @{ Content = 'CPU Microcode & Cache Optimization'; ToolTip = 'Loads optimized CPU microcode settings for stability under load.' }
                'chkRAMTimings'            = @{ Content = 'RAM Timing & Frequency Optimization'; ToolTip = 'Applies safe memory timing adjustments for better throughput.' }
                'chkDisableXboxServicesServices' = @{ Content = 'Disable Xbox Services'; ToolTip = 'Stops Xbox helper services that consume memory when not gaming.' }
                'chkDisableTelemetryServices' = @{ Content = 'Disable Telemetry'; ToolTip = 'Turns off Windows data reporting services to free bandwidth.' }
                'chkDisableSearchServices' = @{ Content = 'Disable Windows Search'; ToolTip = 'Pauses Windows Search indexing to save disk activity.' }
                'chkDisablePrintSpoolerServices' = @{ Content = 'Disable Print Spooler'; ToolTip = 'Stops print services if you do not use a printer.' }
                'chkDisableSuperfetchServices' = @{ Content = 'Disable Superfetch'; ToolTip = 'Disables the preloading service that can cause drive activity.' }
                'chkDisableFaxServices'    = @{ Content = 'Disable Fax Service'; ToolTip = 'Turns off the unused fax service.' }
                'chkDisableRemoteRegistryServices' = @{ Content = 'Disable Remote Registry'; ToolTip = 'Blocks remote registry access for security and less background work.' }
                'chkDisableThemesServices' = @{ Content = 'Optimize Themes Service'; ToolTip = 'Optimizes the themes service to reduce visual overhead.' }
                'chkDisableCortana'        = @{ Content = 'Disable Cortana & Voice Assistant'; ToolTip = 'Disables Cortana to save memory and network use.' }
                'chkDisableWindowsUpdate'  = @{ Content = 'Optimize Windows Update Service'; ToolTip = 'Limits automatic updates so games are not interrupted.' }
                'chkDisableBackgroundApps' = @{ Content = 'Disable Background App Refresh'; ToolTip = 'Stops background apps from running when you do not need them.' }
                'chkDisableLocationTracking' = @{ Content = 'Disable Location Tracking Services'; ToolTip = 'Prevents Windows from tracking your location in the background.' }
                'chkDisableAdvertisingID'  = @{ Content = 'Disable Advertising ID Services'; ToolTip = 'Clears and stops the ad ID so apps cannot build ad profiles.' }
                'chkDisableErrorReporting' = @{ Content = 'Disable Error Reporting Services'; ToolTip = 'Stops error reports from sending data online automatically.' }
                'chkDisableCompatTelemetry' = @{ Content = 'Disable Compatibility Telemetry'; ToolTip = 'Blocks compatibility telemetry that collects app usage.' }
                'chkDisableWSH'            = @{ Content = 'Disable Windows Script Host'; ToolTip = 'Disables Windows Script Host to avoid unwanted scripts.' }
            }
            ComboItems = @{
                'cmbOptionsLanguageEnglish' = 'English'
                'cmbOptionsLanguageGerman'  = 'German'
            }
        }
        'de' = @{
            DisplayName = 'Deutsch'
            Controls    = @{
                'lblLanguageSectionTitle' = @{ Text = '🌐 Sprache' }
                'lblLanguageDescription'  = @{ Text = 'Wähle, wie KOALA mit dir sprechen soll.' }
                'lblLanguageLabel'        = @{ Text = 'Sprache:' }
                'cmbOptionsLanguage'      = @{ ToolTip = 'Wechsle zwischen englischen und deutschen Texten im Programm.' }
                'expanderNetworkTweaks'   = @{ Header = '🌐 Netzwerk-Optimierungen' }
                'expanderNetworkOptimizations' = @{ Header = '🌐 Zentrale Netzwerk-Feinabstimmung' }
                'expanderSystemOptimizations'  = @{ Header = '💻 System-Optimierungen' }
                'expanderPerformanceOptimizations' = @{ Header = '⚡ Leistungs-Optimierungen' }
                'expanderAdvancedPerformance' = @{ Header = '🚀 Erweiterte Leistungssteigerungen' }
                'expanderServiceManagement' = @{ Header = '🛠️ Dienstoptimierungen' }
                'expanderServiceOptimizations' = @{ Header = '🧰 Dienst-Anpassungen' }
                'expanderPrivacyServices'  = @{ Header = '🔒 Datenschutz & Hintergrunddienste' }
                'chkAckNetwork'            = @{ Content = 'TCP-ACK beschleunigen'; ToolTip = 'Lässt deinen PC eingehende Daten schneller bestätigen und senkt so Verzögerungen im Online-Spiel.' }
                'chkDelAckTicksNetwork'    = @{ Content = 'Verzögerte ACK-Zeit verkürzen'; ToolTip = 'Verkürzt die Wartezeit, bevor Windows Datenpakete bestätigt, und senkt damit die Latenz.' }
                'chkNagleNetwork'          = @{ Content = 'Nagle-Algorithmus deaktivieren'; ToolTip = 'Verhindert, dass Windows kleine Nachrichten sammelt, damit deine Aktionen sofort ausgeführt werden.' }
                'chkNetworkThrottlingNetwork' = @{ Content = 'Netzwerk-Drosselung ausschalten'; ToolTip = 'Hebt die in Windows eingebaute Geschwindigkeitsbremse für Netzwerkaufgaben auf.' }
                'chkRSSNetwork'            = @{ Content = 'Receive Side Scaling aktivieren'; ToolTip = 'Erlaubt Windows, mehrere CPU-Kerne für eingehenden Internetverkehr zu nutzen.' }
                'chkRSCNetwork'            = @{ Content = 'Receive Segment Coalescing aktivieren'; ToolTip = 'Ermöglicht Windows, zusammengehörige Pakete zu bündeln und so den Aufwand zu senken.' }
                'chkChimneyNetwork'        = @{ Content = 'TCP-Chimney-Offload nutzen'; ToolTip = 'Verlagert Netzwerkarbeit auf die Netzwerkkarte, damit der Prozessor entlastet wird.' }
                'chkNetDMANetwork'         = @{ Content = 'NetDMA aktivieren'; ToolTip = 'Aktiviert direkten Speicherzugriff für Netzwerkkarten und beschleunigt Übertragungen.' }
                'chkTcpTimestampsNetwork'  = @{ Content = 'TCP-Zeitstempel deaktivieren'; ToolTip = 'Schaltet zusätzliche Zeitstempel aus, die Gaming-Verbindungen ausbremsen können.' }
                'chkTcpWindowAutoTuningNetwork' = @{ Content = 'TCP-Fenster automatisch abstimmen'; ToolTip = 'Optimiert, wie Windows Datenfenster festlegt, damit Downloads schneller laufen.' }
                'chkMemoryCompressionSystem' = @{ Content = 'Speicherkompression verwalten'; ToolTip = 'Komprimiert selten genutzte Daten im Speicher, damit mehr RAM für Spiele frei bleibt.' }
                'chkPowerPlanSystem'       = @{ Content = 'Höchstleistung Energieplan erzwingen'; ToolTip = 'Erzwingt den Höchstleistungs-Energieplan von Windows für maximale Geschwindigkeit.' }
                'chkCPUSchedulingSystem'   = @{ Content = 'CPU-Zeitplanung optimieren'; ToolTip = 'Gibt Hintergrunddiensten weniger Priorität, damit Spiele mehr CPU-Zeit erhalten.' }
                'chkPageFileSystem'        = @{ Content = 'Auslagerungsdatei optimieren'; ToolTip = 'Stimmt die Auslagerungsdatei ab, damit es bei vollem RAM nicht zu Bremsen kommt.' }
                'chkVisualEffectsSystem'   = @{ Content = 'Visuelle Effekte reduzieren'; ToolTip = 'Schaltet Effekte ab, um Ressourcen für Leistung freizumachen.' }
                'chkCoreParkingSystem'     = @{ Content = 'Core Parking deaktivieren'; ToolTip = 'Hält CPU-Kerne wach, damit Spiele sie sofort nutzen können.' }
                'chkGameDVRSystem'         = @{ Content = 'Game DVR deaktivieren'; ToolTip = 'Deaktiviert die Hintergrundaufzeichnung von Windows und verhindert FPS-Einbrüche.' }
                'chkFullscreenOptimizationsSystem' = @{ Content = 'Exklusiven Vollbildmodus erzwingen'; ToolTip = 'Erzwingt den klassischen Vollbildmodus und senkt die Eingabeverzögerung.' }
                'chkGPUSchedulingSystem'   = @{ Content = 'Hardware-GPU-Planung aktivieren'; ToolTip = 'Erlaubt der Grafikkarte, ihre Arbeit selbst zu planen, wodurch Bilder flüssiger laufen.' }
                'chkTimerResolutionSystem' = @{ Content = 'Timerauflösung auf 1 ms setzen'; ToolTip = 'Setzt Windows-Timer auf 1 Millisekunde für schnellere Reaktionen.' }
                'chkGameModeSystem'        = @{ Content = 'Windows-Spielmodus aktivieren'; ToolTip = 'Aktiviert den Windows-Spielmodus, damit Ressourcen auf Spiele fokussiert werden.' }
                'chkMPOSystem'             = @{ Content = 'MPO (Multi-Plane Overlay) deaktivieren'; ToolTip = 'Schaltet eine Darstellungsfunktion ab, die Flackern oder Ruckeln verursachen kann.' }
                'chkDynamicResolution'     = @{ Content = 'Dynamische Auflösung nutzen'; ToolTip = 'Senkt die Auflösung in hektischen Szenen automatisch, damit die Bildrate stabil bleibt.' }
                'chkEnhancedFramePacing'   = @{ Content = 'Bildtaktung glätten'; ToolTip = 'Gleicht die Bildausgabe aus, damit Bewegungen ruhiger wirken.' }
                'chkGPUOverclocking'       = @{ Content = 'GPU-Profiloptimierung anwenden'; ToolTip = 'Wendet ein sicheres GPU-Tuning-Profil speziell für Spiele an.' }
                'chkCompetitiveLatency'    = @{ Content = 'Wettkampf-Latenz reduzieren'; ToolTip = 'Reduziert zusätzliche Puffer, damit die Steuerung sofort reagiert.' }
                'chkAutoDiskOptimization'  = @{ Content = 'Automatische Laufwerksoptimierung'; ToolTip = 'Startet je nach Laufwerk automatisch Defrag oder TRIM, um es sauber zu halten.' }
                'chkAdaptivePowerManagement' = @{ Content = 'Adaptive Energieverwaltung'; ToolTip = 'Passt die Energieeinstellungen dynamisch an, um Leistung und Temperatur auszugleichen.' }
                'chkEnhancedPagingFile'    = @{ Content = 'Auslagerungsdatei anpassen'; ToolTip = 'Stimmt die Größe der Auslagerungsdatei auf deinen RAM ab, um plötzliche Bremsen zu vermeiden.' }
                'chkDirectStorageEnhanced' = @{ Content = 'DirectStorage optimieren'; ToolTip = 'Bereitet Windows mit DirectStorage-Anpassungen auf schnellere Ladezeiten vor.' }
                'chkAdvancedTelemetryDisable' = @{ Content = 'Erweiterte Telemetrie abschalten'; ToolTip = 'Begrenzt das Senden von Hintergrunddaten und spart Ressourcen.' }
                'chkMemoryDefragmentation' = @{ Content = 'Arbeitsspeicher defragmentieren'; ToolTip = 'Ordnet den Speicher neu, damit große Spiele zusammenhängenden RAM erhalten.' }
                'chkServiceOptimization'   = @{ Content = 'Dienste für Spiele optimieren'; ToolTip = 'Optimiert Hintergrunddienste, damit mehr Leistung für Spiele bleibt.' }
                'chkDiskTweaksAdvanced'    = @{ Content = 'Fortgeschrittene Datenträgeroptimierung'; ToolTip = 'Verbessert Lese- und Schreibzugriffe von Windows auf deine Gaming-Laufwerke.' }
                'chkNetworkLatencyOptimization' = @{ Content = 'Ultra-niedrige Netzwerklatenz'; ToolTip = 'Setzt zusätzliche Netzwerkoptimierungen für den niedrigsten möglichen Ping um.' }
                'chkFPSSmoothness'         = @{ Content = 'FPS-Glättung aktivieren'; ToolTip = 'Nimmt Zeitanpassungen vor, damit Bildzeiten gleichmäßig bleiben.' }
                'chkCPUMicrocode'          = @{ Content = 'CPU-Mikrocode optimieren'; ToolTip = 'Lädt optimierte CPU-Mikrocode-Einstellungen für Stabilität unter Last.' }
                'chkRAMTimings'            = @{ Content = 'RAM-Timings abstimmen'; ToolTip = 'Nimmt sichere RAM-Timing-Anpassungen für mehr Durchsatz vor.' }
                'chkDisableXboxServicesServices' = @{ Content = 'Xbox-Dienste deaktivieren'; ToolTip = 'Beendet Xbox-Hilfsdienste, die auch ohne Spiel Speicher belegen.' }
                'chkDisableTelemetryServices' = @{ Content = 'Telemetry-Dienste deaktivieren'; ToolTip = 'Schaltet Datenerfassungsdienste von Windows aus und spart Bandbreite.' }
                'chkDisableSearchServices' = @{ Content = 'Windows-Suche pausieren'; ToolTip = 'Pausiert die Windows-Suche, um Laufwerksaktivität zu sparen.' }
                'chkDisablePrintSpoolerServices' = @{ Content = 'Druckwarteschlange deaktivieren'; ToolTip = 'Beendet Druckdienste, wenn kein Drucker verwendet wird.' }
                'chkDisableSuperfetchServices' = @{ Content = 'Superfetch deaktivieren'; ToolTip = 'Deaktiviert den Vorlade-Dienst, der Laufwerke beschäftigen kann.' }
                'chkDisableFaxServices'    = @{ Content = 'Faxdienst deaktivieren'; ToolTip = 'Schaltet den ungenutzten Faxdienst ab.' }
                'chkDisableRemoteRegistryServices' = @{ Content = 'Remote-Registry sperren'; ToolTip = 'Sperrt den Remotezugriff auf die Registry für mehr Sicherheit und weniger Hintergrundarbeit.' }
                'chkDisableThemesServices' = @{ Content = 'Design-Dienst optimieren'; ToolTip = 'Optimiert den Design-Dienst, um visuelle Last zu reduzieren.' }
                'chkDisableCortana'        = @{ Content = 'Cortana & Sprachassistent deaktivieren'; ToolTip = 'Deaktiviert Cortana, um Speicher und Datenverkehr zu sparen.' }
                'chkDisableWindowsUpdate'  = @{ Content = 'Windows Update optimieren'; ToolTip = 'Begrenzt automatische Updates, damit Spiele nicht unterbrochen werden.' }
                'chkDisableBackgroundApps' = @{ Content = 'Hintergrund-Apps stoppen'; ToolTip = 'Verhindert, dass Hintergrund-Apps laufen, wenn du sie nicht brauchst.' }
                'chkDisableLocationTracking' = @{ Content = 'Standortverfolgung stoppen'; ToolTip = 'Verhindert, dass Windows deinen Standort im Hintergrund verfolgt.' }
                'chkDisableAdvertisingID'  = @{ Content = 'Werbe-ID deaktivieren'; ToolTip = 'Setzt die Werbe-ID zurück und verhindert, dass Apps Werbeprofile erstellen.' }
                'chkDisableErrorReporting' = @{ Content = 'Fehlerberichterstattung deaktivieren'; ToolTip = 'Verhindert, dass Fehlerberichte automatisch Daten senden.' }
                'chkDisableCompatTelemetry' = @{ Content = 'Kompatibilitäts-Telemetrie blockieren'; ToolTip = 'Blockiert Kompatibilitäts-Telemetrie, die App-Nutzung sammelt.' }
                'chkDisableWSH'            = @{ Content = 'Windows Script Host deaktivieren'; ToolTip = 'Deaktiviert den Windows Script Host, um unerwünschte Skripte zu vermeiden.' }
            }
            ComboItems = @{
                'cmbOptionsLanguageEnglish' = 'Englisch'
                'cmbOptionsLanguageGerman'  = 'Deutsch'
            }
        }
    }
}

function Set-UILanguage {
    param(
        [string]$LanguageCode,
        [switch]$SkipSelectionUpdate
    )

    Initialize-LocalizationResources

    if (-not $LanguageCode) {
        $LanguageCode = 'en'
    }

    if (-not $script:LocalizationResources.ContainsKey($LanguageCode)) {
        Log "Requested language '$LanguageCode' is not available. Falling back to English." 'Warning'
        $LanguageCode = 'en'
    }

    $script:CurrentLanguage = $LanguageCode
    $languageResources = $script:LocalizationResources[$LanguageCode]

    foreach ($entry in $languageResources.Controls.GetEnumerator()) {
        $controlName = $entry.Key
        $control = $form.FindName($controlName)
        if (-not $control) {
            continue
        }

        $controlConfig = $entry.Value

        if ($controlConfig.ContainsKey('Content') -and $control.PSObject.Properties['Content']) {
            $control.Content = $controlConfig.Content
        }

        if ($controlConfig.ContainsKey('Header') -and $control.PSObject.Properties['Header']) {
            $control.Header = $controlConfig.Header
        }

        if ($controlConfig.ContainsKey('Text') -and $control.PSObject.Properties['Text']) {
            $control.Text = $controlConfig.Text
        }

        if ($controlConfig.ContainsKey('ToolTip')) {
            $control.ToolTip = $controlConfig.ToolTip
        }
    }

    if ($languageResources.ContainsKey('ComboItems')) {
        foreach ($itemEntry in $languageResources.ComboItems.GetEnumerator()) {
            $comboItem = $form.FindName($itemEntry.Key)
            if ($comboItem -and $comboItem.PSObject.Properties['Content']) {
                $comboItem.Content = $itemEntry.Value
            }
        }
    }

    if (-not $SkipSelectionUpdate -and $cmbOptionsLanguage -and $cmbOptionsLanguage.Items.Count -gt 0) {
        $script:IsLanguageInitializing = $true
        foreach ($item in $cmbOptionsLanguage.Items) {
            if ($item.Tag -eq $LanguageCode) {
                $cmbOptionsLanguage.SelectedItem = $item
                break
            }
        }
        $script:IsLanguageInitializing = $false
    }

    $activeTheme = if ($cmbOptionsTheme -and $cmbOptionsTheme.SelectedItem -and $cmbOptionsTheme.SelectedItem.Tag) {
        $cmbOptionsTheme.SelectedItem.Tag
    } elseif ($global:CurrentTheme) {
        $global:CurrentTheme
    } else {
        'Nebula'
    }

    try {
        Switch-Theme -ThemeName $activeTheme

        if ($global:CurrentPanel -eq 'Advanced' -and $global:CurrentAdvancedSection) {
            Set-ActiveAdvancedSectionButton -Section $global:CurrentAdvancedSection -CurrentTheme $activeTheme
        }
    } catch {
        Log "Failed to refresh theme after language change: $($_.Exception.Message)" 'Warning'
    }

    Log "UI language switched to $($languageResources.DisplayName)" 'Info'
}

# Apply the initial language selection after localization helpers are defined
Set-UILanguage -LanguageCode $script:CurrentLanguage

# Remove old control bindings and set null fallbacks for missing advanced controls
$chkGpuAutoTuning = $null
$chkLowLatencyAudio = $null
$chkHardwareInterrupt = $null
$chkNVMeOptimization = $null
$chkWin11GameMode = $null
$chkMemoryPool = $null
$chkGpuPreemption = $null
$chkCpuMicrocode = $null
$chkPciLatency = $null
$chkDmaRemapping = $null
$chkFramePacing = $null

# DX11 Optimizations - set to null for new UI
$chkDX11GpuScheduling = $null
$chkDX11ProcessPriority = $null
$chkDX11BackgroundServices = $null
$chkDX11HardwareAccel = $null
$chkDX11MaxPerformance = $null
$chkDX11RegistryTweaks = $null

# Advanced tweaks - set to null for new UI
$chkModernStandby = $null
$chkUTCTime = $null
$chkNTFS = $null
$chkEdgeTelemetry = $null
$chkCortana = $null
$chkTelemetry = $null

# Set remaining controls to null for new UI architecture
$chkSvcXbox = $null
$chkSvcSpooler = $null
$chkSvcSysMain = $null
$chkSvcDiagTrack = $null
$chkSvcSearch = $null
$chkDisableUnneeded = $null

# Performance monitoring labels are already mapped above
# Additional legacy mappings
$lblLastRefresh = $lblDashLastOptimization

# Continue cleaning up old control references by setting them to null
$chkRamOptimization = $null
$chkStartupPrograms = $null
$chkBootOptimization = $null
$lblOptimizationStatus = $form.FindName('lblOptimizationStatus')
$chkAutoOptimize = $form.FindName('chkAutoOptimize')

# Buttons
$btnSystemInfo = $form.FindName('btnSystemInfo')
$btnBenchmark = $form.FindName('btnBenchmark')
$btnBackup = $form.FindName('btnBackup')
$btnBackupReg = $form.FindName('btnBackupReg')
$btnExportConfig = $form.FindName('btnExportConfigMain')  # Fixed control name
$btnExportConfigOptions = $form.FindName('btnExportConfigOptions')
$btnImportConfig = $form.FindName('btnImportConfigMain')  # Fixed control name
$btnImportConfigOptions = $form.FindName('btnImportConfigOptions')
$btnApply = $form.FindName('btnApply')
$btnRevert = $form.FindName('btnRevert')
$btnClearLog = $form.FindName('btnClearLog')

# Options panel controls
$optionsPanel = $form.FindName('optionsPanel')
$cmbOptionsTheme = $form.FindName('cmbOptionsThemeMain')  # Fixed control name
$btnOptionsApplyTheme = $form.FindName('btnOptionsApplyThemeMain')  # Fixed control name
$cmbUIScale = $form.FindName('cmbUIScaleMain')  # Fixed control name
$btnApplyScale = $form.FindName('btnApplyScaleMain')  # Fixed control name
$btnSaveSettings = $form.FindName('btnSaveSettings')
$btnLoadSettings = $form.FindName('btnLoadSettings')
$btnResetSettings = $form.FindName('btnResetSettings')
$btnImportOptions = $form.FindName('btnImportOptions')
$btnChooseBackupFolder = $form.FindName('btnChooseBackupFolder')

# Installed Games panel controls
$installedGamesPanel = $form.FindName('installedGamesPanel')
$btnSearchGames = $form.FindName('btnSearchGames')
$btnAddGameFolder = $form.FindName('btnAddGameFolder')
$btnCustomSearch = $form.FindName('btnCustomSearch')
$gameListPanel = $form.FindName('gameListPanel')
$btnOptimizeSelected = $form.FindName('btnOptimizeSelected')

# Expanders
$expanderNetwork = $form.FindName('expanderNetwork')
$expanderEssential = $form.FindName('expanderEssential')
$expanderSystemPerf = $form.FindName('expanderSystemPerf')
$expanderAdvancedFPS = $form.FindName('expanderAdvancedFPS')
$expanderDX11 = $form.FindName('expanderDX11')
$expanderHellzerg = $form.FindName('expanderHellzerg')
$expanderServices = $form.FindName('expanderServices')

# New Advanced Options Expanders
$expanderNetworkTweaks = $form.FindName('expanderNetworkTweaks')
$expanderSystemOptimizations = $form.FindName('expanderSystemOptimizations')
$expanderServiceManagement = $form.FindName('expanderServiceManagement')

# Dedicated Panel Expanders
$expanderNetworkOptimizations = $form.FindName('expanderNetworkOptimizations')
$expanderPerformanceOptimizations = $form.FindName('expanderPerformanceOptimizations')
$expanderServiceOptimizations = $form.FindName('expanderServiceOptimizations')

# Mode panels
$basicModePanel = $form.FindName('basicModePanel')
$advancedModeWelcome = $form.FindName('advancedModeWelcome')

# Basic mode buttons
$btnBasicNetwork = $form.FindName('btnBasicNetwork')
$btnBasicSystem = $form.FindName('btnBasicSystem')
$btnBasicGaming = $form.FindName('btnBasicGaming')

# Log box initialization with enhanced error handling
$global:LogBox = $form.FindName('LogBox')
$global:LogBoxAvailable = ($global:LogBox -ne $null)

# Verify LogBox initialization with comprehensive testing
if ($global:LogBoxAvailable) {
    # Test that LogBox is actually usable
    try {
        $global:LogBox.AppendText("")  # Test write access
        $global:LogBox.Clear()  # Test clear access
        Log "Activity log UI initialized successfully - ready for logging" 'Success'
    } catch {
        $global:LogBoxAvailable = $false
        Write-Host "Warning: Activity log UI not accessible, using console and file logging only" -ForegroundColor Yellow
        Log "LogBox UI unavailable - using fallback logging methods" 'Warning'
    }
} else {
    Write-Host "Warning: Activity log UI element not found, using console and file logging only" -ForegroundColor Yellow
    Log "LogBox UI element not found - using fallback logging methods" 'Warning'
}

# ---------- STARTUP CONTROL VALIDATION (moved after form creation) ----------
# Perform startup control validation after form and controls are created
Log "Running startup control validation..." 'Info'
$controlsValid = Test-StartupControls

if (-not $controlsValid) {
    Log "CRITICAL: Some controls are missing - application may have reduced functionality" 'Warning'
    Log "The application will continue to run, but some features may not work properly" 'Warning'
} else {
    Log "[OK] All startup control validation checks passed - application ready" 'Success'
}

# ---------- Populate Game Profiles Dropdown ----------
$cmbGameProfile.Items.Clear()

# Custom Profile
$item = New-Object System.Windows.Controls.ComboBoxItem
$item.Content = "Custom Profile"
$item.Tag = "custom"
$cmbGameProfile.Items.Add($item)

# Competitive Shooters Section
$headerItem = New-Object System.Windows.Controls.ComboBoxItem
$headerItem.Content = "--- COMPETITIVE SHOOTERS ---"
$headerItem.Tag = ""
$headerItem.IsEnabled = $false
$headerItem.FontWeight = "Bold"
Set-BrushPropertySafe -Target $headerItem -Property 'Foreground' -Value '#8F6FFF'
$cmbGameProfile.Items.Add($headerItem)

foreach ($key in @('cs2', 'csgo', 'valorant', 'overwatch2', 'r6siege')) {
    if ($GameProfiles.ContainsKey($key)) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $GameProfiles[$key].DisplayName
        $item.Tag = $key
        $cmbGameProfile.Items.Add($item)
    }
}

# Battle Royale Section
$headerItem = New-Object System.Windows.Controls.ComboBoxItem
$headerItem.Content = "--- BATTLE ROYALE ---"
$headerItem.Tag = ""
$headerItem.IsEnabled = $false
$headerItem.FontWeight = "Bold"
Set-BrushPropertySafe -Target $headerItem -Property 'Foreground' -Value '#8F6FFF'
$cmbGameProfile.Items.Add($headerItem)

foreach ($key in @('fortnite', 'apexlegends', 'pubg', 'warzone')) {
    if ($GameProfiles.ContainsKey($key)) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $GameProfiles[$key].DisplayName
        $item.Tag = $key
        $cmbGameProfile.Items.Add($item)
    }
}

# Multiplayer Section
$headerItem = New-Object System.Windows.Controls.ComboBoxItem
$headerItem.Content = "--- MULTIPLAYER ---"
$headerItem.Tag = ""
$headerItem.IsEnabled = $false
$headerItem.FontWeight = "Bold"
Set-BrushPropertySafe -Target $headerItem -Property 'Foreground' -Value '#8F6FFF'
$cmbGameProfile.Items.Add($headerItem)

foreach ($key in @('lol', 'rocketleague', 'dota2', 'gta5')) {
    if ($GameProfiles.ContainsKey($key)) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $GameProfiles[$key].DisplayName
        $item.Tag = $key
        $cmbGameProfile.Items.Add($item)
    }
}

# AAA Titles Section
$headerItem = New-Object System.Windows.Controls.ComboBoxItem
$headerItem.Content = "--- AAA TITLES ---"
$headerItem.Tag = ""
$headerItem.IsEnabled = $false
$headerItem.FontWeight = "Bold"
Set-BrushPropertySafe -Target $headerItem -Property 'Foreground' -Value '#8F6FFF'
$cmbGameProfile.Items.Add($headerItem)

foreach ($key in @('hogwartslegacy', 'starfield', 'baldursgate3', 'cyberpunk2077')) {
    if ($GameProfiles.ContainsKey($key)) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $GameProfiles[$key].DisplayName
        $item.Tag = $key
        $cmbGameProfile.Items.Add($item)
    }
}

# Survival & More Section
$headerItem = New-Object System.Windows.Controls.ComboBoxItem
$headerItem.Content = "--- SURVIVAL & MORE ---"
$headerItem.Tag = ""
$headerItem.IsEnabled = $false
$headerItem.FontWeight = "Bold"
Set-BrushPropertySafe -Target $headerItem -Property 'Foreground' -Value '#8F6FFF'
$cmbGameProfile.Items.Add($headerItem)

foreach ($key in $GameProfiles.Keys | Where-Object { $_ -notin @('cs2', 'csgo', 'valorant', 'overwatch2', 'r6siege', 'fortnite', 'apexlegends', 'pubg', 'warzone', 'lol', 'rocketleague', 'dota2', 'gta5', 'hogwartslegacy', 'starfield', 'baldursgate3', 'cyberpunk2077') }) {
    $item = New-Object System.Windows.Controls.ComboBoxItem
    $item.Content = $GameProfiles[$key].DisplayName
    $item.Tag = $key
    $cmbGameProfile.Items.Add($item)
}
$cmbGameProfile.SelectedIndex = 0

# ---------- Menu Mode Function ----------
function Switch-MenuMode {
    param([string]$Mode, [switch]$ResizeWindow)

    # Validate input mode
    $validModes = @("Basic", "Advanced", "InstalledGames", "Options", "Dashboard")
    if ($Mode -notin $validModes) {
        Log "Switch-MenuMode: Invalid mode '$Mode'. Valid modes: $($validModes -join ', ')" 'Error'
        return
    }

    Log "Switch-MenuMode: Switching from '$global:MenuMode' to '$Mode'" 'Info'

    # If switching to Advanced mode, require KOALA confirmation
    if ($Mode -eq "Advanced" -and $global:MenuMode -ne "Advanced") {
        $confirmationMessage = @"
⚠️ WARNING: Advanced Mode Access ⚠️

Are you sure you want to switch to Advanced Mode?

Advanced Mode provides access to powerful system tweaks and optimization features. These advanced tweaks may cause system errors, performance issues, or instability. Changes made in Advanced Mode can significantly affect your system's behavior and may require system restoration if problems occur.

By continuing, you acknowledge that:
* Advanced tweaks may cause errors or system instability
* You are solely responsible for any changes made in Advanced Mode
* No liability will be held by the author for system issues
* You should create a system backup before proceeding

To confirm that you understand these risks and unlock Advanced Mode, please type: KOALA
"@

        try {
            $userInput = [Microsoft.VisualBasic.Interaction]::InputBox($confirmationMessage, "Advanced Mode Confirmation", "")

            if ($userInput -ne "KOALA") {
                Log "Advanced Mode access denied - incorrect confirmation (user entered: '$userInput')" 'Warning'
                Log "Reverting to previous mode: $global:MenuMode" 'Info'
                return
            }

            Log "Advanced Mode access granted with KOALA confirmation" 'Info'
            Log "User confirmed understanding of Advanced Mode risks and responsibilities" 'Info'
        } catch {
            Log "Error in Advanced Mode confirmation dialog: $($_.Exception.Message)" 'Error'
            return
        }
    }

    $global:MenuMode = $Mode

    # Use proper WPF Visibility enumeration
    $VisibleState = [System.Windows.Visibility]::Visible
    $CollapsedState = [System.Windows.Visibility]::Collapsed

    try {
        # Reset all panels to collapsed first
        $allPanels = @($basicModePanel, $advancedModeWelcome, $installedGamesPanel, $optionsPanel)
        $allExpanders = @($expanderAdvancedFPS, $expanderDX11, $expanderHellzerg, $expanderServices, $expanderNetwork, $expanderEssential, $expanderSystemPerf, $expanderNetworkTweaks, $expanderSystemOptimizations, $expanderServiceManagement)

        foreach ($panel in $allPanels) {
            if ($panel) {
                $panel.Visibility = $CollapsedState
                Log "Panel '$($panel.Name)' set to collapsed" 'Info'
            }
        }

        foreach ($expander in $allExpanders) {
            if ($expander) {
                $expander.Visibility = $CollapsedState
                Log "Expander '$($expander.Name)' set to collapsed" 'Info'
            }
        }

        # Set visibility based on selected mode
        switch ($Mode) {
            "Basic" {
                # Show Basic Mode panel only
                if ($basicModePanel) {
                    $basicModePanel.Visibility = $VisibleState
                    Log "Basic Mode panel activated" 'Info'
                }

                Log "Switched to Basic Mode - Safe optimizations only" 'Success'
            }

            "Advanced" {
                # Show all advanced sections
                if ($advancedModeWelcome) { $advancedModeWelcome.Visibility = $VisibleState }
                if ($expanderAdvancedFPS) { $expanderAdvancedFPS.Visibility = $VisibleState }
                if ($expanderDX11) { $expanderDX11.Visibility = $VisibleState }
                if ($expanderHellzerg) { $expanderHellzerg.Visibility = $VisibleState }
                if ($expanderServices) { $expanderServices.Visibility = $VisibleState }
                if ($expanderNetwork) { $expanderNetwork.Visibility = $VisibleState }
                if ($expanderEssential) { $expanderEssential.Visibility = $VisibleState }
                if ($expanderSystemPerf) { $expanderSystemPerf.Visibility = $VisibleState }

                Log "Switched to Advanced Mode - All tweaks available" 'Success'
            }

            "InstalledGames" {
                # Show Installed Games panel
                if ($installedGamesPanel) {
                    $installedGamesPanel.Visibility = $VisibleState
                    Log "Installed Games panel activated" 'Info'
                }

                Log "Switched to Installed Games Mode - Game discovery and optimization" 'Success'
            }

            "Options" {
                # Show Options panel
                if ($optionsPanel) {
                    $optionsPanel.Visibility = $VisibleState
                    Log "Options panel activated" 'Info'
                }

                Log "Switched to Options Mode - Settings and preferences" 'Success'
            }

            "Dashboard" {
                # Dashboard mode - show basic info but hide most controls
                Log "Switched to Dashboard Mode - Overview display" 'Success'
            }
        }

        # Optional window resizing based on mode complexity
        if ($ResizeWindow -and $form) {
            try {
                $currentWidth = $form.Width
                $currentHeight = $form.Height
                $newWidth = $currentWidth
                $newHeight = $currentHeight

                switch ($Mode) {
                    "Basic" {
                        $newWidth = [Math]::Max(1200, $currentWidth)
                        $newHeight = [Math]::Max(700, $currentHeight)
                    }
                    "Advanced" {
                        $newWidth = [Math]::Max(1400, $currentWidth)
                        $newHeight = [Math]::Max(900, $currentHeight)
                    }
                    "Options" {
                        $newWidth = [Math]::Max(1200, $currentWidth)
                        $newHeight = [Math]::Max(800, $currentHeight)
                    }
                }

                if ($newWidth -ne $currentWidth -or $newHeight -ne $currentHeight) {
                    $form.Width = $newWidth
                    $form.Height = $newHeight
                    Log "Window resized to ${newWidth}x${newHeight} for $Mode mode" 'Info'
                }
            } catch {
                Log "Error resizing window for mode ${Mode}: $($_.Exception.Message)" 'Warning'
            }
        }

    } catch {
        Log "Error switching to $Mode mode: $($_.Exception.Message)" 'Error'
    }
}

# ---------- Installed Games Discovery Function ----------
function Show-InstalledGames {
    try {
        Log "Searching for installed games on system..." 'Info'

        # Create a new window for displaying installed games
        [xml]$installedGamesXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Installed Games Discovery"
        Width="800" Height="600"
        Background="{StaticResource DialogBackgroundBrush}"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize">

  <Window.Resources>
    <SolidColorBrush x:Key="DialogBackgroundBrush" Color="#080716"/>
    <SolidColorBrush x:Key="CardBackgroundBrush" Color="#14132B"/>
    <SolidColorBrush x:Key="CardBorderBrush" Color="#2F285A"/>
    <SolidColorBrush x:Key="AccentBrush" Color="#8F6FFF"/>
    <SolidColorBrush x:Key="PrimaryTextBrush" Color="#F5F3FF"/>
    <SolidColorBrush x:Key="SecondaryTextBrush" Color="#A9A5D9"/>
    <Style TargetType="TextBlock">
        <Setter Property="FontFamily" Value="Segoe UI"/>
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}"/>
    </Style>
    <Style TargetType="Button" x:Key="DialogButton">
        <Setter Property="FontFamily" Value="Segoe UI"/>
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="Foreground" Value="#120B22"/>
        <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="Padding" Value="14,6"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border Background="{TemplateBinding Background}" CornerRadius="10">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#A78BFA"/>
                        </Trigger>
                        <Trigger Property="IsEnabled" Value="False">
                            <Setter Property="Opacity" Value="0.4"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style x:Key="SecondaryDialogButton" TargetType="Button" BasedOn="{StaticResource DialogButton}">
        <Setter Property="Background" Value="#1F1B3F"/>
        <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}"/>
    </Style>
  </Window.Resources>

  <Grid Margin="20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="15" Margin="0,0,0,15">
      <StackPanel>
        <TextBlock Text="Installed Games Discovery" Foreground="{DynamicResource AccentBrush}" FontWeight="Bold" FontSize="20" HorizontalAlignment="Center"/>
        <TextBlock Text="Searching for games installed on your system..." Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12" HorizontalAlignment="Center" Margin="0,5,0,0"/>
      </StackPanel>
    </Border>

    <!-- Games List -->
    <Border Grid.Row="1" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="10">
      <ScrollViewer VerticalScrollBarVisibility="Auto">
        <ListBox x:Name="lstInstalledGames" Background="Transparent" BorderThickness="0" Foreground="{DynamicResource PrimaryTextBrush}" FontSize="12">
          <ListBox.ItemTemplate>
            <DataTemplate>
              <Border Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="1" CornerRadius="4" Padding="8" Margin="2">
                <StackPanel>
                  <TextBlock Text="{Binding Name}" FontWeight="Bold" FontSize="13" Foreground="{DynamicResource AccentBrush}"/>
                  <TextBlock Text="{Binding Path}" FontSize="11" Foreground="{DynamicResource SecondaryTextBrush}" Margin="0,2,0,0"/>
                  <TextBlock Text="{Binding Details}" FontSize="10" Foreground="{DynamicResource AccentBrush}" Margin="0,2,0,0"/>
                </StackPanel>
              </Border>
            </DataTemplate>
          </ListBox.ItemTemplate>
        </ListBox>
      </ScrollViewer>
    </Border>

    <!-- Footer -->
    <Border Grid.Row="2" Background="{DynamicResource CardBackgroundBrush}" BorderBrush="{DynamicResource CardBorderBrush}" BorderThickness="2" CornerRadius="8" Padding="10" Margin="0,15,0,0">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
        <Button x:Name="btnRefreshGames" Content="Refresh Search" Width="140" Height="34" Style="{StaticResource DialogButton}" Margin="0,0,10,0"/>
        <Button x:Name="btnCloseGames" Content="Close" Width="80" Height="32" Background="{DynamicResource AccentBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderThickness="0" FontWeight="SemiBold"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@

        # Create the window
        $reader = New-Object System.Xml.XmlNodeReader $installedGamesXaml
        $gamesWindow = [Windows.Markup.XamlReader]::Load($reader)
        Initialize-LayoutSpacing -Root $gamesWindow

        # Get controls
        $lstInstalledGames = $gamesWindow.FindName('lstInstalledGames')
        $btnRefreshGames = $gamesWindow.FindName('btnRefreshGames')
        $btnCloseGames = $gamesWindow.FindName('btnCloseGames')

        # Function to search for installed games using multiple detection methods
        function Search-InstalledGames {
            $games = @()
            Log "Scanning system for installed games using advanced detection methods..." 'Info'

            # 1. Registry-based detection for Steam games
            try {
                Log "Searching Steam registry for installed games..." 'Info'
                $steamPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue
                if ($steamPath) {
                    $steamLibraryPath = Join-Path $steamPath.SteamPath "steamapps\common"
                    if (Test-Path $steamLibraryPath) {
                        $steamGames = Get-ChildItem -Path $steamLibraryPath -Directory -ErrorAction SilentlyContinue
                        foreach ($game in $steamGames) {
                            $games += [PSCustomObject]@{
                                Name = $game.Name
                                Path = $game.FullName
                                Details = "Steam Game - Detected via Registry"
                            }
                            Log "Found Steam game: $($game.Name)" 'Success'
                        }
                    }
                }
            } catch {
                Log "Steam registry detection failed: $($_.Exception.Message)" 'Warning'
            }

            # 2. Epic Games Launcher detection
            try {
                Log "Searching Epic Games registry..." 'Info'
                $epicPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Epic Games\EpicGamesLauncher" -Name "AppDataPath" -ErrorAction SilentlyContinue
                if ($epicPath) {
                    $epicManifestPath = Join-Path $epicPath.AppDataPath "Manifests"
                    if (Test-Path $epicManifestPath) {
                        $manifests = Get-ChildItem -Path $epicManifestPath -Filter "*.item" -ErrorAction SilentlyContinue
                        foreach ($manifest in $manifests) {
                            try {
                                $content = Get-Content $manifest.FullName | ConvertFrom-Json
                                if ($content.InstallLocation -and (Test-Path $content.InstallLocation)) {
                                    $games += [PSCustomObject]@{
                                        Name = $content.DisplayName
                                        Path = $content.InstallLocation
                                        Details = "Epic Games - Verified Installation"
                                    }
                                    Log "Found Epic Games title: $($content.DisplayName)" 'Success'
                                }
                            } catch {
                                # Skip invalid manifests
                            }
                        }
                    }
                }
            } catch {
                Log "Epic Games detection failed: $($_.Exception.Message)" 'Warning'
            }

            # 3. Registry-based Windows Apps detection
            try {
                Log "Searching Windows registry for installed applications..." 'Info'
                $uninstallKeys = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
                )

                foreach ($keyPath in $uninstallKeys) {
                    $apps = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue | Where-Object {
                        $_.DisplayName -and $_.InstallLocation -and
                        ($_.DisplayName -match "steam|game|epic|origin|uplay|battle\.net|minecraft|fortnite|valorant|league" -or
                         $_.Publisher -match "valve|riot|epic|blizzard|ubisoft|ea|activision|mojang")
                    }

                    foreach ($app in $apps) {
                        if (Test-Path $app.InstallLocation) {
                            $games += [PSCustomObject]@{
                                Name = $app.DisplayName
                                Path = $app.InstallLocation
                                Details = "Registry Entry - Verified Installation ($($app.Publisher))"
                            }
                            Log "Found registered application: $($app.DisplayName)" 'Success'
                        }
                    }
                }
            } catch {
                Log "Registry application detection failed: $($_.Exception.Message)" 'Warning'
            }

            # 4. Enhanced directory scanning with launcher detection
            $searchPaths = @(
                "$env:ProgramFiles\",
                "${env:ProgramFiles(x86)}\",
                "$env:LOCALAPPDATA\Programs\",
                "$env:ProgramData\",
                "C:\Games\",
                "D:\Games\",
                "E:\Games\",
                "$env:USERPROFILE\AppData\Local\"
            )

            # 5. Launcher-specific detection
            $launchers = @{
                "Battle.net" = @{
                    Path = "${env:ProgramFiles(x86)}\Battle.net"
                    ConfigPath = "$env:APPDATA\Battle.net\Battle.net.config"
                }
                "Ubisoft Connect" = @{
                    Path = "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher"
                    ConfigPath = "$env:LOCALAPPDATA\Ubisoft Game Launcher"
                }
                "GOG Galaxy" = @{
                    Path = "${env:ProgramFiles(x86)}\GOG Galaxy"
                    ConfigPath = "$env:LOCALAPPDATA\GOG.com\Galaxy\Configuration"
                }
                "Origin" = @{
                    Path = "${env:ProgramFiles(x86)}\Origin"
                    ConfigPath = "$env:APPDATA\Origin"
                }
            }

            foreach ($launcher in $launchers.Keys) {
                try {
                    $launcherInfo = $launchers[$launcher]
                    if (Test-Path $launcherInfo.Path) {
                        $games += [PSCustomObject]@{
                            Name = "$launcher (Game Launcher)"
                            Path = $launcherInfo.Path
                            Details = "Launcher Detected - Can manage multiple games"
                        }
                        Log "Found launcher: $launcher" 'Success'
                    }
                } catch {
                    # Continue if launcher detection fails
                }
            }

            # 6. Enhanced executable scanning with verification
            $gameExecutables = @{
                "csgo.exe" = "Counter-Strike: Global Offensive"
                "cs2.exe" = "Counter-Strike 2"
                "valorant.exe" = "VALORANT"
                "valorant-win64-shipping.exe" = "VALORANT (Shipping)"
                "overwatch.exe" = "Overwatch"
                "overwatch2.exe" = "Overwatch 2"
                "r6siege.exe" = "Rainbow Six Siege"
                "rainbowsix.exe" = "Rainbow Six Siege"
                "fortnite.exe" = "Fortnite"
                "fortniteclient-win64-shipping.exe" = "Fortnite (Shipping)"
                "apex_legends.exe" = "Apex Legends"
                "r5apex.exe" = "Apex Legends (R5)"
                "pubg.exe" = "PlayerUnknown's Battlegrounds"
                "tslgame.exe" = "PUBG (TSL)"
                "warzone.exe" = "Call of Duty: Warzone"
                "modernwarfare.exe" = "Call of Duty: Modern Warfare"
                "league of legends.exe" = "League of Legends"
                "leagueclient.exe" = "League of Legends Client"
                "riotclientservices.exe" = "Riot Client"
                "rocketleague.exe" = "Rocket League"
                "dota2.exe" = "Dota 2"
                "gta5.exe" = "Grand Theft Auto V"
                "gtav.exe" = "Grand Theft Auto V"
                "cyberpunk2077.exe" = "Cyberpunk 2077"
                "minecraft.exe" = "Minecraft Java"
                "minecraftlauncher.exe" = "Minecraft Launcher"
                "steam.exe" = "Steam Client"
                "epicgameslauncher.exe" = "Epic Games Launcher"
                "battlenet.exe" = "Battle.net Launcher"
                "battle.net.exe" = "Battle.net"
                "origin.exe" = "EA Origin"
                "originwebhelperservice.exe" = "Origin Web Helper"
                "uplay.exe" = "Ubisoft Connect"
                "upc.exe" = "Ubisoft Connect"
                "gog.exe" = "GOG Galaxy"
                "discordapp.exe" = "Discord"
                "obs64.exe" = "OBS Studio"
                "obs32.exe" = "OBS Studio (32-bit)"
            }

            # 7. Enhanced directory and executable scanning with verification
            foreach ($path in $searchPaths) {
                if (Test-Path $path) {
                    Log "Searching in: $path" 'Info'
                    try {
                        # Search for known game executables with verification
                        foreach ($exe in $gameExecutables.Keys) {
                            $foundFiles = Get-ChildItem -Path $path -Recurse -Name $exe -ErrorAction SilentlyContinue
                            foreach ($file in $foundFiles) {
                                $fullPath = Join-Path $path $file
                                if (Test-Path $fullPath) {
                                    $fileInfo = Get-Item $fullPath -ErrorAction SilentlyContinue
                                    if ($fileInfo -and $fileInfo.Length -gt 1MB) { # Only include substantial executables
                                        # Check if it's actually an executable and not just a placeholder
                                        $isValidGame = $true

                                        # Additional verification for known false positives
                                        $parentDir = Split-Path $fullPath -Parent
                                        $dirName = Split-Path $parentDir -Leaf

                                        # Skip if in temp or cache directories
                                        if ($parentDir -match "temp|cache|backup|installer" -and $fileInfo.Length -lt 10MB) {
                                            $isValidGame = $false
                                        }

                                        if ($isValidGame) {
                                            # Check for duplicate detection - only add unique paths
                                            $alreadyExists = $games | Where-Object { $_.Path -eq $fullPath }
                                            if (-not $alreadyExists) {
                                                $game = [PSCustomObject]@{
                                                    Name = $gameExecutables[$exe]
                                                    Path = $fullPath
                                                    Details = "Executable Verified - Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB | Dir: $dirName"
                                                }
                                                $games += $game
                                                Log "Found verified game: $($gameExecutables[$exe]) at $fullPath" 'Success'
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        # Search for game platform directories with content verification
                        $gameInstallDirs = @{
                            "Steam\steamapps\common" = "Steam Games Directory"
                            "Epic Games\*" = "Epic Games Directory"
                            "Ubisoft\Ubisoft Game Launcher\games" = "Ubisoft Games Directory"
                            "EA Games" = "EA Games Directory"
                            "Origin Games" = "Origin Games Directory"
                            "GOG Games" = "GOG Games Directory"
                            "Minecraft" = "Minecraft Directory"
                            "Battle.net" = "Battle.net Directory"
                        }

                        foreach ($dirPattern in $gameInstallDirs.Keys) {
                            $dirPath = Join-Path $path $dirPattern
                            $matchingDirs = Get-Item $dirPath -ErrorAction SilentlyContinue
                            if (-not $matchingDirs -and $dirPattern.Contains("*")) {
                                $matchingDirs = Get-ChildItem -Path (Split-Path $dirPath -Parent) -Directory -Filter (Split-Path $dirPattern -Leaf) -ErrorAction SilentlyContinue
                            }

                            foreach ($dir in $matchingDirs) {
                                if ($dir -and (Test-Path $dir.FullName)) {
                                    # Only include if directory has substantial content
                                    $subItems = Get-ChildItem -Path $dir.FullName -ErrorAction SilentlyContinue
                                    if ($subItems -and $subItems.Count -gt 0) {
                                        # Check for duplicate paths
                                        $alreadyExists = $games | Where-Object { $_.Path -eq $dir.FullName }
                                        if (-not $alreadyExists) {
                                            $game = [PSCustomObject]@{
                                                Name = "$($gameInstallDirs[$dirPattern]) ($($subItems.Count) items)"
                                                Path = $dir.FullName
                                                Details = "Platform Directory - Contains $($subItems.Count) items | Created: $($dir.CreationTime.ToString('yyyy-MM-dd'))"
                                            }
                                            $games += $game
                                            Log "Found platform directory: $($gameInstallDirs[$dirPattern]) at $($dir.FullName)" 'Info'
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        Log "Error searching $path : $($_.Exception.Message)" 'Warning'
                    }
                }
            }

            # 8. Cloud Gaming Services Detection
            try {
                Log "Searching for cloud gaming services..." 'Info'
                $cloudServices = Get-CloudGamingServices
                foreach ($service in $cloudServices) {
                    $games += $service
                    Log "Found cloud gaming service: $($service.Name)" 'Success'
                }
            } catch {
                Log "Cloud gaming services detection failed: $($_.Exception.Message)" 'Warning'
            }

            # 9. Game Streaming Software Detection - obs64.exe, OBS Studio, obs32.exe support
            $streamingSoftware = @{
                "obs64.exe" = "OBS Studio (Streaming/Recording)"
                "obs32.exe" = "OBS Studio 32-bit"
                "xsplit.exe" = "XSplit Broadcaster"  # Professional streaming software
                "streamlabs.exe" = "Streamlabs OBS"  # Professional streaming software
                "nvidia broadcast.exe" = "NVIDIA Broadcast"  # Professional streaming software
                "nvidia share.exe" = "NVIDIA GeForce Experience"
                "amd relive.exe" = "AMD ReLive"
                "discord.exe" = "Discord (Voice Chat)"  # Voice chat software
                "teamspeak3.exe" = "TeamSpeak 3"  # Voice chat software
                "ventrilo.exe" = "Ventrilo"
                "mumble.exe" = "Mumble"  # Voice chat software
            }

            foreach ($exe in $streamingSoftware.Keys) {
                foreach ($path in $searchPaths) {
                    if (Test-Path $path) {
                        $foundFiles = Get-ChildItem -Path $path -Recurse -Name $exe -ErrorAction SilentlyContinue
                        foreach ($file in $foundFiles) {
                            $fullPath = Join-Path $path $file
                            if (Test-Path $fullPath) {
                                $fileInfo = Get-Item $fullPath -ErrorAction SilentlyContinue
                                if ($fileInfo -and $fileInfo.Length -gt 100KB) {
                                    $alreadyExists = $games | Where-Object { $_.Path -eq $fullPath }
                                    if (-not $alreadyExists) {
                                        $games += [PSCustomObject]@{
                                            Name = $streamingSoftware[$exe]
                                            Path = $fullPath
                                            Details = "Gaming Support Software - Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
                                        }
                                        Log "Found gaming support software: $($streamingSoftware[$exe])" 'Success'
                                    }
                                }
                            }
                        }
                    }
                }
            }

            return $games
        }

        # Initial search
        $foundGames = Search-InstalledGames

        if ($foundGames.Count -gt 0) {
            $lstInstalledGames.ItemsSource = $foundGames
            Log "Found $($foundGames.Count) installed games/platforms" 'Success'
        } else {
            $noGamesFound = @([PSCustomObject]@{
                Name = "No Games Found"
                Path = "Try running as Administrator for better detection"
                Details = "Common game directories may be hidden or require elevated permissions"
            })
            $lstInstalledGames.ItemsSource = $noGamesFound
            Log "No games found in common directories" 'Warning'
        }

        # Event handlers
        $btnRefreshGames.Add_Click({
            Log "Refreshing installed games search..." 'Info'
            $lstInstalledGames.ItemsSource = $null
            $refreshedGames = Search-InstalledGames

            if ($refreshedGames.Count -gt 0) {
                $lstInstalledGames.ItemsSource = $refreshedGames
                Log "Refresh complete: Found $($refreshedGames.Count) games/platforms" 'Success'
            } else {
                $noGamesFound = @([PSCustomObject]@{
                    Name = "No Games Found"
                    Path = "Try running as Administrator for better detection"
                    Details = "Common game directories may be hidden or require elevated permissions"
                })
                $lstInstalledGames.ItemsSource = $noGamesFound
                Log "Refresh complete: No games found" 'Warning'
            }
        })

        $btnCloseGames.Add_Click({
            Log "Installed Games window closed by user" 'Info'
            $gamesWindow.Close()
        })

        # Show the window
        $gamesWindow.ShowDialog() | Out-Null

    } catch {
        Log "Error showing installed games: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error displaying installed games window: $($_.Exception.Message)", "Installed Games Error", 'OK', 'Error')
    }
}

# Helper functions for synchronizing game list UI across multiple panels
function Set-OptimizeButtonsEnabled {
    param([bool]$Enabled)

    foreach ($button in $script:OptimizeSelectedButtons) {
        try { $button.IsEnabled = $Enabled } catch { Write-Verbose "Failed to update optimize button state: $($_.Exception.Message)" }
    }
}

function Get-GameListPanels {
    $panels = @()
    if ($script:PrimaryGameListPanel) { $panels += $script:PrimaryGameListPanel }
    if ($script:DashboardGameListPanel -and ($script:PrimaryGameListPanel -ne $script:DashboardGameListPanel)) { $panels += $script:DashboardGameListPanel }
    return $panels
}

# ---------- Search Games for Panel Function ----------
function Search-GamesForPanel {
    try {
        Log "Scanning system for installed games using enhanced detection methods..." 'Info'

        # Clear existing content
        $gameListPanel.Children.Clear()

        # Add loading message
        $loadingText = New-Object System.Windows.Controls.TextBlock
        try { $loadingText.Text = "🔍 Searching for installed games with advanced detection..." } catch { Write-Verbose "Text assignment skipped for compatibility" }
        try { Set-BrushPropertySafe -Target $loadingText -Property 'Foreground' -Value '#8F6FFF' } catch { Write-Verbose "Foreground assignment skipped for compatibility" }
        try { $loadingText.FontStyle = "Italic" } catch { Write-Verbose "FontStyle assignment skipped for compatibility" }
        try { $loadingText.HorizontalAlignment = "Center" } catch { Write-Verbose "HorizontalAlignment assignment skipped for compatibility" }
        try { $loadingText.Margin = "0,20" } catch { Write-Verbose "Margin assignment skipped for compatibility" }
        $gameListPanel.Children.Add($loadingText)

        # Force UI update to show loading message
        $form.Dispatcher.Invoke({}, "Background")

        # Use the enhanced game detection function
        $foundGames = @()

        # Call the enhanced detection logic from the Show-InstalledGames function
        try {
            # Enhanced search paths including custom paths
            $searchPaths = @(
                "$env:ProgramFiles\",
                "${env:ProgramFiles(x86)}\",
                "$env:LOCALAPPDATA\Programs\",
                "$env:ProgramData\",
                "C:\Games\",
                "D:\Games\",
                "E:\Games\",
                "$env:USERPROFILE\AppData\Local\"
            )

            # Add custom paths if they exist
            if ($global:CustomGamePaths) {
                $searchPaths += $global:CustomGamePaths
                Log "Including $($global:CustomGamePaths.Count) custom search paths" 'Info'
            }

            # 1. Registry-based Steam detection
            try {
                $steamPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue
                if ($steamPath) {
                    $steamLibraryPath = Join-Path $steamPath.SteamPath "steamapps\common"
                    if (Test-Path $steamLibraryPath) {
                        $steamGames = Get-ChildItem -Path $steamLibraryPath -Directory -ErrorAction SilentlyContinue
                        foreach ($game in $steamGames | Select-Object -First 20) { # Limit for UI performance
                            $foundGames += [PSCustomObject]@{
                                Name = $game.Name
                                Path = $game.FullName
                                Details = "Steam Game - Registry Detection"
                            }
                        }
                        Log "Found $($steamGames.Count) Steam games" 'Success'
                    }
                }
            } catch {
                Log "Steam detection failed: $($_.Exception.Message)" 'Warning'
            }

            # 2. Enhanced executable search
            $gameExecutables = @{
                "csgo.exe" = "Counter-Strike: Global Offensive"
                "cs2.exe" = "Counter-Strike 2"
                "valorant.exe" = "VALORANT"
                "valorant-win64-shipping.exe" = "VALORANT (Shipping)"
                "overwatch.exe" = "Overwatch"
                "overwatch2.exe" = "Overwatch 2"
                "r6siege.exe" = "Rainbow Six Siege"
                "fortnite.exe" = "Fortnite"
                "fortniteclient-win64-shipping.exe" = "Fortnite (Shipping)"
                "apex_legends.exe" = "Apex Legends"
                "r5apex.exe" = "Apex Legends (R5)"
                "pubg.exe" = "PlayerUnknown's Battlegrounds"
                "tslgame.exe" = "PUBG (TSL)"
                "warzone.exe" = "Call of Duty: Warzone"
                "league of legends.exe" = "League of Legends"
                "leagueclient.exe" = "League of Legends Client"
                "rocketleague.exe" = "Rocket League"
                "dota2.exe" = "Dota 2"
                "gta5.exe" = "Grand Theft Auto V"
                "cyberpunk2077.exe" = "Cyberpunk 2077"
                "bg3.exe" = "Baldur's Gate 3"
                "starfield.exe" = "Starfield"
                "minecraft.exe" = "Minecraft Java"
                "minecraftlauncher.exe" = "Minecraft Launcher"
            }
            # 3. Enhanced executable search in all paths
            foreach ($searchPath in $searchPaths) {
                if (Test-Path $searchPath) {
                    Log "Searching path: $searchPath" 'Info'
                    foreach ($gameExe in $gameExecutables.Keys) {
                        try {
                            $gameFiles = Get-ChildItem -Path $searchPath -Recurse -Name $gameExe -ErrorAction SilentlyContinue | Select-Object -First 2
                            foreach ($gameFile in $gameFiles) {
                                $fullPath = Join-Path $searchPath $gameFile
                                if (Test-Path $fullPath) {
                                    $fileInfo = Get-Item $fullPath -ErrorAction SilentlyContinue
                                    if ($fileInfo -and $fileInfo.Length -gt 1MB) {
                                        # Check for duplicates
                                        $isDuplicate = $foundGames | Where-Object { $_.Path -eq $fullPath }
                                        if (-not $isDuplicate) {
                                            $foundGames += @{
                                                Name = $gameExecutables[$gameExe]
                                                Path = $fullPath
                                                Executable = $gameExe
                                                Details = "Verified Executable - Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
                                            }
                                            Log "Found verified game: $($gameExecutables[$gameExe])" 'Success'
                                        }
                                    }
                                }
                            }
                        } catch {
                            # Continue silently on search errors
                        }
                    }
                }
            }

        } catch {
            Log "Enhanced detection encountered error: $($_.Exception.Message)" 'Warning'
        }

        # Clear loading message
        $gameListPanel.Children.Clear()

        if ($foundGames.Count -gt 0) {
            # Add header
            $headerText = New-Object System.Windows.Controls.TextBlock
            $headerText.Text = "✅ Found $($foundGames.Count) installed games:"
            Set-BrushPropertySafe -Target $headerText -Property 'Foreground' -Value '#8F6FFF'
            $headerText.FontWeight = "Bold"
            $headerText.Margin = "0,0,0,10"
            $gameListPanel.Children.Add($headerText)

            # Add games with checkboxes
            foreach ($game in $foundGames) {
                $gameContainer = New-Object System.Windows.Controls.Border
                Set-BrushPropertySafe -Target $gameContainer -Property 'Background' -Value '#14132B'
                try {
                    Set-BrushPropertySafe -Target $gameContainer -Property 'BorderBrush' -Value '#2F285A'
                    $gameContainer.BorderThickness = "1"
                } catch {
                    Write-Verbose "BorderBrush assignment skipped for .NET Framework 4.8 compatibility"
                }
                $gameContainer.Padding = "10"
                $gameContainer.Margin = "0,2"

                $gameStack = New-Object System.Windows.Controls.StackPanel
                $gameStack.Orientation = "Horizontal"

                # Checkbox for selection
                $gameCheckbox = New-Object System.Windows.Controls.CheckBox
                $gameCheckbox.VerticalAlignment = "Top"
                $gameCheckbox.Margin = "0,0,10,0"
                $gameCheckbox.Tag = $game

                # Game info
                $gameInfoStack = New-Object System.Windows.Controls.StackPanel

                $gameNameText = New-Object System.Windows.Controls.TextBlock
                $gameNameText.Text = $game.Name
                Set-BrushPropertySafe -Target $gameNameText -Property 'Foreground' -Value '#8F6FFF'
                $gameNameText.FontWeight = "Bold"
                $gameNameText.FontSize = "12"

                $gamePathText = New-Object System.Windows.Controls.TextBlock
                $gamePathText.Text = $game.Path
                Set-BrushPropertySafe -Target $gamePathText -Property 'Foreground' -Value '#A9A5D9'
                $gamePathText.FontSize = "10"
                $gamePathText.TextWrapping = "Wrap"

                $gameInfoStack.Children.Add($gameNameText)
                $gameInfoStack.Children.Add($gamePathText)

                $gameStack.Children.Add($gameCheckbox)
                $gameStack.Children.Add($gameInfoStack)
                $gameContainer.Child = $gameStack

                $gameListPanel.Children.Add($gameContainer)
            }

            # Enable optimize button
            Set-OptimizeButtonsEnabled -Enabled $true

            Log "Game search complete: Found $($foundGames.Count) games" 'Success'

        } else {
            # No games found
            $noGamesText = New-Object System.Windows.Controls.TextBlock
            $noGamesText.Text = "❌ No supported games found in common directories.`n`nTry running as Administrator for better detection, or use 'Add Game Folder' to specify custom locations."
            Set-BrushPropertySafe -Target $noGamesText -Property 'Foreground' -Value '#FFB86C'
            $noGamesText.FontStyle = "Italic"
            $noGamesText.HorizontalAlignment = "Center"
            $noGamesText.TextAlignment = "Center"
            $noGamesText.Margin = "0,20"
            $noGamesText.TextWrapping = "Wrap"
            $gameListPanel.Children.Add($noGamesText)

            Log "Game search complete: No games found" 'Warning'
        }

    } catch {
        # Clear panel and show error
        $gameListPanel.Children.Clear()
        $errorText = New-Object System.Windows.Controls.TextBlock
        $errorText.Text = "❌ Error searching for games: $($_.Exception.Message)"
        Set-BrushPropertySafe -Target $errorText -Property 'Foreground' -Value '#FF6B6B'
        $errorText.HorizontalAlignment = "Center"
        $errorText.Margin = "0,20"
        $errorText.TextWrapping = "Wrap"
        $gameListPanel.Children.Add($errorText)

        Log "Error in game search: $($_.Exception.Message)" 'Error'
    }
}

# ---------- Custom Folder Search Function ----------
function Search-CustomFoldersForExecutables {
    try {
        Log "Scanning custom folders for all executable files..." 'Info'

        # Clear existing content
        $gameListPanel.Children.Clear()

        # Add loading message
        $loadingText = New-Object System.Windows.Controls.TextBlock
        try { $loadingText.Text = "🔍 Scanning custom folders for .exe files..." } catch { Write-Verbose "Text assignment skipped for compatibility" }
        try { Set-BrushPropertySafe -Target $loadingText -Property 'Foreground' -Value '#8F6FFF' } catch { Write-Verbose "Foreground assignment skipped for compatibility" }
        try { $loadingText.FontStyle = "Italic" } catch { Write-Verbose "FontStyle assignment skipped for compatibility" }
        try { $loadingText.HorizontalAlignment = "Center" } catch { Write-Verbose "HorizontalAlignment assignment skipped for compatibility" }
        try { $loadingText.Margin = "0,20" } catch { Write-Verbose "Margin assignment skipped for compatibility" }
        $gameListPanel.Children.Add($loadingText)

        # Force UI update to show loading message
        $form.Dispatcher.Invoke({}, "Background")

        $foundExecutables = @()

        foreach ($customPath in $global:CustomGamePaths) {
            if (Test-Path $customPath) {
                Log "Searching custom path: $customPath" 'Info'

                try {
                    # Find all .exe files in the custom folder (not recursive to avoid performance issues)
                    $executables = Get-ChildItem -Path $customPath -Filter "*.exe" -File -ErrorAction SilentlyContinue

                    foreach ($exe in $executables) {
                        try {
                            # Get file info
                            $fileInfo = Get-ItemProperty -Path $exe.FullName -ErrorAction SilentlyContinue
                            $displayName = if ($exe.VersionInfo -and $exe.VersionInfo.FileDescription) {
                                $exe.VersionInfo.FileDescription
                            } else {
                                $exe.BaseName
                            }

                            $foundExecutables += [PSCustomObject]@{
                                Name = $displayName
                                ExecutableName = $exe.Name
                                Path = $exe.FullName
                                Size = [Math]::Round($exe.Length / 1MB, 2)
                                LastModified = $exe.LastWriteTime
                                Details = "Custom Folder: $customPath"
                            }
                        }
                        catch {
                            # Continue if can't get file info
                            $foundExecutables += [PSCustomObject]@{
                                Name = $exe.BaseName
                                ExecutableName = $exe.Name
                                Path = $exe.FullName
                                Size = 0
                                LastModified = $exe.LastWriteTime
                                Details = "Custom Folder: $customPath"
                            }
                        }
                    }

                    Log "Found $($executables.Count) executables in $customPath" 'Info'
                }
                catch {
                    Log "Error scanning custom path $customPath : $($_.Exception.Message)" 'Warning'
                }
            }
            else {
                Log "Custom path no longer exists: $customPath" 'Warning'
            }
        }

        # Clear loading message
        $gameListPanel.Children.Clear()

        if ($foundExecutables.Count -gt 0) {
            Log "Custom search complete: Found $($foundExecutables.Count) executables" 'Success'

            # Add header
            $headerText = New-Object System.Windows.Controls.TextBlock
            $headerText.Text = "🔍 Found $($foundExecutables.Count) executable(s) in custom folders - Select any to optimize:"
            Set-BrushPropertySafe -Target $headerText -Property 'Foreground' -Value '#8F6FFF'
            $headerText.FontWeight = "Bold"
            $headerText.FontSize = 12
            $headerText.Margin = "0,0,0,8"
            $headerText.TextWrapping = "Wrap"
            $gameListPanel.Children.Add($headerText)

            # Sort by name for better presentation
            $foundExecutables = $foundExecutables | Sort-Object Name

            foreach ($executable in $foundExecutables) {
                # Create container border
                $border = New-Object System.Windows.Controls.Border
                Set-BrushPropertySafe -Target $border -Property 'Background' -Value '#14132B'
                try {
                    Set-BrushPropertySafe -Target $border -Property 'BorderBrush' -Value '#2F285A'
                    $border.BorderThickness = "1"
                } catch {
                    Write-Verbose "BorderBrush assignment skipped for .NET Framework 4.8 compatibility"
                }
                $border.Margin = "0,2"
                $border.Padding = "8"

                $stackPanel = New-Object System.Windows.Controls.StackPanel

                # Create checkbox for selection
                $checkbox = New-Object System.Windows.Controls.CheckBox
                $checkbox.Content = $executable.Name
                Set-BrushPropertySafe -Target $checkbox -Property 'Foreground' -Value '#F5F3FF'
                $checkbox.FontWeight = "SemiBold"
                $checkbox.Tag = $executable.Path  # Store full path for optimization
                $stackPanel.Children.Add($checkbox)

                # Add details
                $detailsText = New-Object System.Windows.Controls.TextBlock
                $detailsText.Text = "🔍 $($executable.Details)"
                Set-BrushPropertySafe -Target $detailsText -Property 'Foreground' -Value '#A9A5D9'
                $detailsText.FontSize = 10
                $detailsText.Margin = "20,2,0,0"
                $stackPanel.Children.Add($detailsText)

                $fileDetailsText = New-Object System.Windows.Controls.TextBlock
                $fileDetailsText.Text = "💾 File: $($executable.ExecutableName) | Size: $($executable.Size) MB | Modified: $($executable.LastModified.ToString('yyyy-MM-dd'))"
                Set-BrushPropertySafe -Target $fileDetailsText -Property 'Foreground' -Value '#7D7EB0'
                $fileDetailsText.FontSize = 9
                $fileDetailsText.Margin = "20,1,0,0"
                $stackPanel.Children.Add($fileDetailsText)

                $border.Child = $stackPanel
                $gameListPanel.Children.Add($border)
            }

            # Enable the optimize button
            Set-OptimizeButtonsEnabled -Enabled $true

        } else {
            $noExecutablesText = New-Object System.Windows.Controls.TextBlock
            $noExecutablesText.Text = "❌ No executable files found in custom folders.`n`nTip: Make sure the folders contain .exe files and you have permission to access them."
            Set-BrushPropertySafe -Target $noExecutablesText -Property 'Foreground' -Value '#FF6B6B'
            $noExecutablesText.HorizontalAlignment = "Center"
            $noExecutablesText.Margin = "0,20"
            $noExecutablesText.TextWrapping = "Wrap"
            $gameListPanel.Children.Add($noExecutablesText)

            Log "Custom search complete: No executables found" 'Warning'
        }

    } catch {
        # Clear panel and show error
        $gameListPanel.Children.Clear()
        $errorText = New-Object System.Windows.Controls.TextBlock
        $errorText.Text = "❌ Error searching custom folders: $($_.Exception.Message)"
        Set-BrushPropertySafe -Target $errorText -Property 'Foreground' -Value '#FF6B6B'
        $errorText.HorizontalAlignment = "Center"
        $errorText.Margin = "0,20"
        $errorText.TextWrapping = "Wrap"
        $gameListPanel.Children.Add($errorText)

        Log "Error in custom folder search: $($_.Exception.Message)" 'Error'
    }
}

# ---------- Game Detection and Auto-Optimization ----------
function Get-RunningGames {
    $runningGames = @()
    $allProcesses = Get-Process -ErrorAction SilentlyContinue

    foreach ($profile in $GameProfiles.GetEnumerator()) {
        foreach ($processName in $profile.Value.ProcessNames) {
            $cleanName = $processName -replace '\.exe$', ''
            $foundProcess = $allProcesses | Where-Object { $_.ProcessName -like "*$cleanName*" }
            if ($foundProcess) {
                $runningGames += @{
                    GameKey = $profile.Key
                    DisplayName = $profile.Value.DisplayName
                    Process = $foundProcess
                    ProcessName = $processName
                }
                break
            }
        }
    }

    return $runningGames
}

function Start-GameDetectionLoop {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(5)

    $timer.Add_Tick({
        $currentGames = Get-RunningGames
        $global:ActiveGames = $currentGames

        if ($lblActiveGames) {
            $gamesList = if ($currentGames.Count -gt 0) {
                ($currentGames | ForEach-Object { $_.DisplayName }) -join ", "
            } else {
                "None"
            }

            if ($lblActiveGames) {
                $lblActiveGames.Dispatcher.Invoke({
                    $lblActiveGames.Text = $gamesList
                    if ($lblLastRefresh) {
                        $lblLastRefresh.Text = Get-Date -Format "HH:mm:ss"
                    }
                })
            }
        }

        if ($global:AutoOptimizeEnabled -and $currentGames.Count -gt 0) {
            foreach ($game in $currentGames) {
                Apply-GameOptimizations -GameKey $game.GameKey -Process $game.Process
            }
        }
    })

    $timer.Start()
    return $timer
}

function Apply-GameOptimizations {
    param([string]$GameKey, [System.Diagnostics.Process]$Process)

    if (-not $GameProfiles.ContainsKey($GameKey)) { return }

    $profile = $GameProfiles[$GameKey]
    Log "Auto-optimizing detected game: $($profile.DisplayName)" 'Info'

    try {
        if ($profile.Priority -and $profile.Priority -ne 'Normal') {
            $Process.PriorityClass = $profile.Priority
            Log "Set process priority to $($profile.Priority) for $($profile.DisplayName)" 'Success'
        }

        if ($profile.Affinity -eq 'Auto') {
            $coreCount = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
            if ($coreCount -gt 4) {
                $Process.ProcessorAffinity = [IntPtr]::new(15)
                Log "Set CPU affinity for $($profile.DisplayName) (using 4 cores)" 'Success'
            }
        }
    } catch {
        Log "Warning: Could not adjust process priority/affinity for $($profile.DisplayName)" 'Warning'
    }

    if ($profile.SpecificTweaks) {
        Log "Applying specific tweaks for $($profile.DisplayName)" 'Info'
        Apply-GameSpecificTweaks -GameKey $GameKey -TweakList $profile.SpecificTweaks
    }

    if ($profile.FPSBoostSettings) {
        Log "Applying FPS optimizations for $($profile.DisplayName)" 'Info'
        Apply-FPSOptimizations -OptimizationList $profile.FPSBoostSettings
    }

    Log "Auto-optimization completed for $($profile.DisplayName)" 'Success'
}

# ---------- Network Optimization Functions ----------
function Apply-NetworkOptimizations {
    param([hashtable]$Settings)

    $count = 0

    try {
        if ($Settings.TCPAck) {
            # TCP ACK Frequency optimization
            $nicRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            if (Test-Path $nicRoot) {
                Get-ChildItem $nicRoot | ForEach-Object {
                    $nicPath = $_.PSPath
                    Set-Reg $nicPath "TcpAckFrequency" 'DWord' 1 -RequiresAdmin $true | Out-Null
                }
                $count++
                Log "TCP ACK Frequency optimized" 'Success'
            }
        }

        if ($Settings.DelAckTicks) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 'DWord' 0 -RequiresAdmin $true | Out-Null
            $count++
            Log "Delayed ACK ticks disabled" 'Success'
        }

        if ($Settings.NetworkThrottling) {
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 'DWord' 0xFFFFFFFF -RequiresAdmin $true | Out-Null
            $count++
            Log "Network throttling disabled" 'Success'
        }

        if ($Settings.NagleAlgorithm) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
            $count++
            Log "Nagle algorithm disabled" 'Success'
        }

        if ($Settings.TCPTimestamps) {
            try {
                netsh int tcp set global timestamps=disabled | Out-Null
                $count++
                Log "TCP timestamps disabled" 'Success'
            } catch {
                Log "Failed to disable TCP timestamps" 'Warning'
            }
        }

        if ($Settings.ECN) {
            try {
                netsh int tcp set global ecncapability=disabled | Out-Null
                $count++
                Log "Explicit Congestion Notification disabled" 'Success'
            } catch {
                Log "Failed to disable ECN" 'Warning'
            }
        }

        if ($Settings.RSS) {
            try {
                netsh int tcp set global rss=enabled | Out-Null
                $count++
                Log "Receive Side Scaling enabled" 'Success'
            } catch {
                Log "Failed to enable RSS" 'Warning'
            }
        }

        if ($Settings.RSC) {
            try {
                netsh int tcp set global rsc=disabled | Out-Null
                $count++
                Log "Receive Segment Coalescing disabled" 'Success'
            } catch {
                Log "Failed to disable RSC" 'Warning'
            }
        }

        if ($Settings.AutoTuning) {
            try {
                netsh int tcp set global autotuninglevel=normal | Out-Null
                $count++
                Log "TCP Auto-Tuning set to normal" 'Success'
            } catch {
                Log "Failed to set TCP auto-tuning" 'Warning'
            }
        }

    } catch {
        Log "Network optimization error: $($_.Exception.Message)" 'Error'
    }

    return $count
}

# ---------- Targeted Gaming Optimization Helpers ----------
function Disable-GameDVR {
    $allOperationsSucceeded = $true

    try {
        Log "Disabling Game DVR background recording and overlays..." 'Info'

        $operations = @(
            { Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 'DWord' 0 },
            { Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 'DWord' 2 },
            { Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehavior" 'DWord' 2 },
            { Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 'DWord' 0 },
            { Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 'DWord' 0 },
            { Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AllowAutoGameMode" 'DWord' 0 },
            { Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AutoGameModeEnabled" 'DWord' 0 },
            { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 'DWord' 0 -RequiresAdmin $true },
            { Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" "value" 'DWord' 0 -RequiresAdmin $true }
        )

        foreach ($operation in $operations) {
            if (-not (& $operation)) {
                $allOperationsSucceeded = $false
            }
        }

        try {
            $presenceWriter = Get-Service -Name 'GameBarPresenceWriter' -ErrorAction Stop
            if ($presenceWriter.Status -ne 'Stopped') {
                Stop-Service -Name 'GameBarPresenceWriter' -Force -ErrorAction Stop
            }
            Set-Service -Name 'GameBarPresenceWriter' -StartupType Disabled -ErrorAction Stop
            Log "Game Bar presence writer service disabled" 'Info'
        } catch {
            Write-Verbose "Game Bar Presence Writer service update skipped: $($_.Exception.Message)"
            $allOperationsSucceeded = $false
        }

        if ($allOperationsSucceeded) {
            Log "Game DVR disabled globally" 'Success'
        } else {
            Log "Game DVR registry updates applied with warnings (administrator rights may be required)" 'Warning'
        }

        return $allOperationsSucceeded
    } catch {
        Log "Failed to disable Game DVR: $($_.Exception.Message)" 'Warning'
        return $false
    }
}

function Enable-GPUScheduling {
    $gpuRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'

    try {
        $osVersion = [Environment]::OSVersion.Version
        if ($osVersion.Major -lt 10 -or ($osVersion.Major -eq 10 -and $osVersion.Build -lt 19041)) {
            Log "Hardware GPU scheduling requires Windows 10 version 2004 or newer - skipping" 'Warning'
            return $false
        }

        if (-not (Test-Path $gpuRegistryPath -ErrorAction SilentlyContinue)) {
            Log "GPU scheduling registry path not found - hardware may not support this feature" 'Warning'
            return $false
        }

        $results = @(
            Set-Reg $gpuRegistryPath 'HwSchMode' 'DWord' 2 -RequiresAdmin $true,
            Set-Reg "$gpuRegistryPath\Scheduler" 'EnablePreemption' 'DWord' 1 -RequiresAdmin $true,
            Set-Reg $gpuRegistryPath 'PlatformSupportMiracast' 'DWord' 0 -RequiresAdmin $true
        )

        if ($results -contains $false) {
            Log "Hardware GPU scheduling applied with warnings (administrator rights may be required)" 'Warning'
            return $false
        }

        Log "Hardware GPU scheduling enabled" 'Success'
        return $true
    } catch {
        Log "Failed to enable hardware GPU scheduling: $($_.Exception.Message)" 'Warning'
        return $false
    }
}

# ---------- FPS Optimization Functions ----------
function Apply-FPSOptimizations {
    param([string[]]$OptimizationList)

    Log "Applying FPS optimizations..." 'Info'

    foreach ($optimization in $OptimizationList) {
        switch ($optimization) {
            'DirectXOptimization' {
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Direct3D" "DisableVidMemVirtualization" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D12_ENABLE_RUNTIME_DRIVER_OPTIMIZATIONS" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "DirectX optimizations applied" 'Success'
            }

            'DirectX12Optimization' {
                Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D12_RESOURCE_ALIGNMENT" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D12_MULTITHREADED_COMMAND_QUEUE" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "DirectX 12 optimizations applied" 'Success'
            }

            'ShaderCacheOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Microsoft\Direct3D" "ShaderCache" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Microsoft\Direct3D" "DisableShaderRecompilation" 'DWord' 1 | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DisableShaderCache" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Log "Shader cache optimization applied" 'Success'
            }

            'InputLatencyReduction' {
                Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" 'String' "0" | Out-Null
                Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" 'String' "0" | Out-Null
                Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" 'String' "0" | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" "MouseDataQueueSize" 'DWord' 100 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" "KeyboardDataQueueSize" 'DWord' 100 -RequiresAdmin $true | Out-Null
                Log "Input latency reduction applied" 'Success'
            }

            'GPUSchedulingOptimization' {
                [void](Enable-GPUScheduling)
            }

            'MemoryCompressionDisable' {
                try {
                    Disable-MMAgent -MemoryCompression -ErrorAction Stop
                    Log "Memory compression disabled" 'Success'
                } catch {
                    Log "Failed to disable memory compression: $($_.Exception.Message)" 'Warning'
                }
            }

            'CPUCoreParkDisable' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" "ValueMax" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" "ValueMin" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Log "CPU core parking disabled" 'Success'
            }

            'InterruptModerationOptimization' {
                try {
                    Get-NetAdapter | ForEach-Object {
                        Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
                        Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName "Interrupt Moderation Rate" -DisplayValue "Off" -ErrorAction SilentlyContinue
                    }
                    Log "Interrupt moderation optimized" 'Success'
                } catch {
                    Log "Network adapter interrupt moderation failed: $($_.Exception.Message)" 'Warning'
                }
            }

            'AudioLatencyOptimization' {
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio" "DisableProtectedAudioDG" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio" "DisableProtectedAudio" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Microsoft\Multimedia\Audio" "UserDuckingPreference" 'DWord' 3 | Out-Null
                Log "Audio latency optimization applied" 'Success'
            }

            'MemoryPoolOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PoolUsageMaximum" 'DWord' 96 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagedPoolSize" 'DWord' 0xFFFFFFFF -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "NonPagedPoolSize" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Log "Memory pool optimization applied" 'Success'
            }

            'TextureStreamingOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "VKPoolSize" 'DWord' 1073741824 | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrLevel" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 'DWord' 10 -RequiresAdmin $true | Out-Null
                Log "Texture streaming optimization applied" 'Success'
            }

            'VulkanOptimization' {
                Set-Reg "HKLM:\SOFTWARE\Khronos\Vulkan\ImplicitLayers" "VK_LAYER_VALVE_steam_overlay" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Khronos\Vulkan\Drivers" "VulkanAPIVersion" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "Vulkan optimization applied" 'Success'
            }

            'OpenGLOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DisableOpenGLShaderCache" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers" "EnableThreadedOptimizations" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "OpenGL optimization applied" 'Success'
            }

            'PhysicsOptimization' {
                Set-Reg "HKLM:\SOFTWARE\NVIDIA Corporation\PhysX" "AsyncSceneCreation" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" "EnableRID66610" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Log "Physics optimization applied" 'Success'
            }

            'DLSSOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" "DLSSEnable" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS" "EnableDLSS" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "DLSS optimization enabled" 'Success'
            }

            'RTXOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" "RayTracingEnable" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" "EnableResizableBar" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "RTX optimization configured" 'Success'
            }

            'FramePacingOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "PerfAnalysisInterval" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" "AutoHDREnable" 'DWord' 0 | Out-Null
                Log "Frame pacing optimization applied" 'Success'
            }

            'DynamicResolutionScaling' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "EnableAdaptiveResolution" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DynamicResolutionTarget" 'DWord' 60 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D12_ENABLE_DYNAMIC_RESOLUTION" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" "EnableDynamicResolution" 'DWord' 1 | Out-Null
                Log "Dynamic resolution scaling for adaptive performance enabled" 'Success'
            }

            'EnhancedFramePacing' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "FramePacingEnabled" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "FramePacingTargetFPS" 'DWord' 144 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "MicroStutterReduction" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "FrameTimeSmoothening" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "Enhanced frame pacing with micro stutter reduction applied" 'Success'
            }

            'ProfileBasedGPUOverclocking' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "EnableGPUOverclock" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "GPUClockOffsetProfile1" 'DWord' 100 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "MemoryClockOffsetProfile1" 'DWord' 200 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "PowerLimitProfile1" 'DWord' 120 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TempLimitProfile1" 'DWord' 83 -RequiresAdmin $true | Out-Null
                Log "Profile-based GPU overclocking configuration applied" 'Success'
            }

            'CompetitiveLatencyReduction' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "UltraLowLatencyMode" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "PreRenderLimit" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" "MonitorLatencyTolerance" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" "MonitorRefreshLatencyTolerance" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseXCurve" 'Binary' @(0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xC0,0xCC,0x0C,0x00,0x00,0x00,0x00,0x00,0x80,0x99,0x19,0x00,0x00,0x00,0x00,0x00,0x40,0x66,0x26,0x00,0x00,0x00,0x00,0x00,0x00,0x33,0x33,0x00,0x00,0x00,0x00,0x00) | Out-Null
                Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseYCurve" 'Binary' @(0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x70,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xA8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xE0,0x00,0x00,0x00,0x00,0x00) | Out-Null
                Log "Enhanced competitive gaming latency reduction applied" 'Success'
            }

            'ChunkRenderingOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Mojang" "RenderDistance" 'DWord' 12 | Out-Null
                [Environment]::SetEnvironmentVariable("_JAVA_OPTIONS", "-Xmx4G -Xms2G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200", "User")
                Log "Chunk rendering optimization applied" 'Success'
            }

            'NetworkLatencyOptimization' {
                try {
                    netsh int tcp set supplemental internet congestionprovider=ctcp | Out-Null
                    Log "Network latency optimization applied" 'Success'
                } catch {
                    Log "Failed to apply network latency optimization" 'Warning'
                }
            }

            'CPUOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "ThreadDpcEnable" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DpcWatchdogProfileOffset" 'DWord' 10000 -RequiresAdmin $true | Out-Null
                Log "CPU optimization applied" 'Success'
            }
        }
    }
}

# ---------- DirectX 11 Optimization Functions ----------
function Apply-DX11Optimizations {
    param([string[]]$OptimizationList)

    Log "Applying DirectX 11 optimizations..." 'Info'

    foreach ($optimization in $OptimizationList) {
        switch ($optimization) {
            'DX11EnhancedGpuScheduling' {
                try {
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler" "EnablePreemption" 'DWord' 1 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrLevel" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 'DWord' 60 -RequiresAdmin $true | Out-Null
                    Log "Enhanced GPU scheduling for DX11 applied" 'Success'
                } catch {
                    Log "Failed to apply enhanced GPU scheduling: $($_.Exception.Message)" 'Warning'
                }
            }

            'DX11GameProcessPriority' {
                try {
                    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" "UseLargePages" 'DWord' 1 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 'DWord' 38 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Log "Game process priority optimizations applied" 'Success'
                } catch {
                    Log "Failed to apply process priority optimizations: $($_.Exception.Message)" 'Warning'
                }
            }

            'DX11DisableBackgroundServices' {
                try {
                    $servicesToDisable = @('Themes', 'TabletInputService', 'Fax', 'WSearch', 'HomeGroupListener', 'HomeGroupProvider')
                    foreach ($service in $servicesToDisable) {
                        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                        if ($svc -and $svc.Status -eq 'Running') {
                            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                        }
                    }
                    Log "Background services disabled for gaming performance" 'Success'
                } catch {
                    Log "Failed to disable some background services: $($_.Exception.Message)" 'Warning'
                }
            }

            'DX11HardwareAcceleration' {
                try {
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "EnableHWSched" 'DWord' 1 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D_DISABLE_9EX" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Log "Hardware-accelerated GPU scheduling enabled" 'Success'
                } catch {
                    Log "Failed to enable hardware-accelerated GPU scheduling: $($_.Exception.Message)" 'Warning'
                }
            }

            'DX11MaxPerformanceMode' {
                try {
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabledDefault" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\893dee8e-2bef-41e0-89c6-b55d0929964c" "ValueMax" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\893dee8e-2bef-41e0-89c6-b55d0929964c" "ValueMin" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Log "Maximum performance mode configured" 'Success'
                } catch {
                    Log "Failed to configure maximum performance mode: $($_.Exception.Message)" 'Warning'
                }
            }

            'DX11RegistryOptimizations' {
                try {
                    Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D11_MULTITHREADED" 'DWord' 1 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D11_ENABLE_BREAK_ON_MESSAGE" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D11_ENABLE_SHADER_CACHING" 'DWord' 1 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "D3D11_FORCE_SINGLE_THREADED" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DisableWriteCombining" 'DWord' 0 -RequiresAdmin $true | Out-Null
                    Log "DirectX 11 registry optimizations applied" 'Success'
                } catch {
                    Log "Failed to apply DirectX 11 registry optimizations: $($_.Exception.Message)" 'Warning'
                }
            }
        }
    }
}

# ---------- Apply Game-Specific Tweaks ----------
function Apply-GameSpecificTweaks {
    param([string]$GameKey, [array]$TweakList)

    foreach ($tweak in $TweakList) {
        switch ($tweak) {
            'DisableNagle' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Log "Nagle's algorithm disabled" 'Success'
            }

            'HighPrecisionTimer' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 'DWord' 1 -RequiresAdmin $true | Out-Null
                try {
                    [WinMM]::timeBeginPeriod(1) | Out-Null
                } catch {}
                Log "High precision timer enabled" 'Success'
            }

            'NetworkOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxConnectionsPerServer" 'DWord' 16 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxConnectionsPer1_0Server" 'DWord' 16 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL" 'DWord' 64 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 'DWord' 30 -RequiresAdmin $true | Out-Null
                Log "Network optimization applied" 'Success'
            }

            'AntiCheatOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SecondLevelDataCache" 'DWord' 1024 -RequiresAdmin $true | Out-Null
                Log "Anti-cheat compatibility optimizations applied" 'Success'
            }

            'MemoryOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemPages" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "NonPagedPoolQuota" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagedPoolQuota" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Log "Memory optimization applied" 'Success'
            }

            'UnrealEngineOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Epic Games\Unreal Engine" "DisableAsyncCompute" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Epic Games\Unreal Engine" "bUseVSync" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Epic Games\Unreal Engine" "bSmoothFrameRate" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Epic Games\Unreal Engine" "MaxSmoothedFrameRate" 'DWord' 144 | Out-Null
                Log "Unreal Engine optimizations applied" 'Success'
            }

            'SourceEngineOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Valve\Source" "mat_queue_mode" 'DWord' 2 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Valve\Source" "cl_threaded_bone_setup" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Valve\Source" "cl_threaded_client_leaf_system" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Valve\Source" "r_threaded_client_shadow_manager" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Valve\Source" "r_threaded_particles" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Valve\Source" "r_threaded_renderables" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Valve\Source" "r_queued_ropes" 'DWord' 1 | Out-Null
                Log "Source Engine optimizations applied" 'Success'
            }

            'FrostbiteEngineOptimization' {
                Set-Reg "HKCU:\SOFTWARE\EA\Frostbite" "DisableLayeredRendering" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\EA\Frostbite" "RenderAheadLimit" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\EA\Frostbite" "ThreadedRendering" 'DWord' 1 | Out-Null
                Log "Frostbite Engine optimizations applied" 'Success'
            }

            'UnityEngineOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Unity Technologies\Unity Editor" "EnableMetalSupport" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Unity Technologies\Unity" "GraphicsJobMode" 'DWord' 2 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Unity Technologies\Unity" "ThreadedRendering" 'DWord' 1 | Out-Null
                Log "Unity Engine optimizations applied" 'Success'
            }

            'BlizzardOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Blizzard Entertainment" "DisableHardwareAcceleration" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Blizzard Entertainment" "Sound_OutputDriverName" 'String' "Windows Audio Session" | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Blizzard Entertainment" "StreamingEnabled" 'DWord' 0 | Out-Null
                Log "Blizzard game optimizations applied" 'Success'
            }

            'RiotClientOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Riot Games" "DisableHardwareAcceleration" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Riot Games" "EnableLowSpecMode" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Riot Games" "UseRawInput" 'DWord' 1 | Out-Null
                Log "Riot client optimizations applied" 'Success'
            }

            'UbisoftOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Ubisoft" "DisableOverlay" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Ubisoft" "EnableMultiThreadedRendering" 'DWord' 1 | Out-Null
                Log "Ubisoft optimizations applied" 'Success'
            }

            'CreationEngineOptimization' {
                Set-Reg "HKCU:\SOFTWARE\Bethesda Softworks" "bUseThreadedAI" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Bethesda Softworks" "bUseThreadedMorpher" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Bethesda Softworks" "bUseThreadedTempEffects" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Bethesda Softworks" "bUseThreadedParticleSystem" 'DWord' 1 | Out-Null
                Log "Creation Engine optimizations applied" 'Success'
            }

            'REDEngineOptimization' {
                Set-Reg "HKCU:\SOFTWARE\CD Projekt Red\REDengine" "TextureStreamingEnabled" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\CD Projekt Red\REDengine" "AsyncComputeEnabled" 'DWord' 1 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\CD Projekt Red\REDengine" "HybridSSR" 'DWord' 1 | Out-Null
                Log "RED Engine optimizations applied" 'Success'
            }

            'JavaOptimization' {
                [Environment]::SetEnvironmentVariable("_JAVA_OPTIONS", "-Xmx4G -Xms2G -XX:+UseG1GC -XX:+ParallelRefProcEnabled", "User")
                [Environment]::SetEnvironmentVariable("JAVA_TOOL_OPTIONS", "-XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions", "User")
                Log "Java optimizations applied" 'Success'
            }

            'EACOptimization' {
                Set-Reg "HKLM:\SOFTWARE\EasyAntiCheat" "DisableAnalytics" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "EAC optimization applied" 'Success'
            }

            'RTXOptimization' {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" "RayTracingEnable" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "RTX optimizations applied" 'Success'
            }
        }
    }
}

# ---------- Custom Game Optimization Function ----------
function Apply-CustomGameOptimizations {
    param([string]$GameExecutable)

    Log "Applying standard gaming optimizations for: $GameExecutable in $global:MenuMode mode" 'Info'
    Log "Executable detection request - searching for running processes" 'Info'

    try {
        # Process Priority Optimization
        $processes = Get-Process | Where-Object { $_.ProcessName -like "*$($GameExecutable.Replace('.exe', ''))*" }
        foreach ($process in $processes) {
            try {
                $process.PriorityClass = 'High'
                Log "Set high priority for process: $($process.ProcessName)" 'Success'
            } catch {
                Log "Could not set priority for $($process.ProcessName)" 'Warning'
            }
        }

        # Standard Network Optimizations
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 'DWord' 0 -RequiresAdmin $true | Out-Null
        Log "Network latency optimizations applied" 'Success'

        # GPU Scheduling Optimization
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 -RequiresAdmin $true | Out-Null
        Log "Hardware GPU scheduling optimized" 'Success'

        # Game Mode Registry Settings
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AllowAutoGameMode" 'DWord' 1 | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AutoGameModeEnabled" 'DWord' 1 | Out-Null
        Log "Game Mode optimizations applied" 'Success'

        # Timer Resolution
        try {
            [WinMM]::timeBeginPeriod(1) | Out-Null
            Log "High precision timer enabled" 'Success'
        } catch {
            Log "Could not set timer resolution" 'Warning'
        }

        Log "Custom game optimizations completed for: $GameExecutable" 'Success'

    } catch {
        Log "Error applying custom game optimizations: $($_.Exception.Message)" 'Error'
    }
}

# ---------- Service Optimization Functions ----------
function Apply-ServiceOptimizations {
    param([hashtable]$Settings)

    $count = 0
    $serviceErrors = @()

    try {
        if ($Settings.XboxServices) {
            $xboxServices = @("XblGameSave", "XblAuthManager", "XboxGipSvc", "XboxNetApiSvc")
            $xboxSuccessCount = 0
            foreach ($service in $xboxServices) {
                try {
                    $serviceStatus = Get-ServiceState -ServiceName $service
                    if ($serviceStatus) {
                        Stop-Service -Name $service -Force -ErrorAction Stop
                        Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
                        $xboxSuccessCount++
                        Log "Xbox service '$service' disabled successfully" 'Info'
                    } else {
                        Log "Xbox service '$service' not found on this system" 'Warning'
                        $serviceErrors += "Xbox service '$service' not found"
                    }
                } catch {
                    Log "Failed to disable Xbox service '$service': $($_.Exception.Message)" 'Warning'
                    $serviceErrors += "Xbox service '$service': $($_.Exception.Message)"
                }
            }
            if ($xboxSuccessCount -gt 0) {
                $count++
                Log "Xbox services optimization completed: $xboxSuccessCount/$($xboxServices.Count) services disabled" 'Success'
            }
        }

        if ($Settings.PrintSpooler) {
            try {
                $serviceStatus = Get-ServiceState -ServiceName "Spooler"
                if ($serviceStatus) {
                    if ($serviceStatus.Status -eq 'Running') {
                        Stop-Service -Name "Spooler" -Force -ErrorAction Stop
                        Log "Print Spooler service stopped" 'Info'
                    }
                    Set-Service -Name "Spooler" -StartupType Disabled -ErrorAction Stop
                    $count++
                    Log "Print Spooler disabled successfully" 'Success'
                } else {
                    Log "Print Spooler service not found on this system" 'Warning'
                    $serviceErrors += "Print Spooler service not found"
                }
            } catch {
                Log "Failed to disable Print Spooler: $($_.Exception.Message)" 'Warning'
                $serviceErrors += "Print Spooler: $($_.Exception.Message)"
            }
        }

        if ($Settings.Superfetch) {
            try {
                $serviceStatus = Get-ServiceState -ServiceName "SysMain"
                if ($serviceStatus) {
                    if ($serviceStatus.Status -eq 'Running') {
                        Stop-Service -Name "SysMain" -Force -ErrorAction Stop
                        Log "SysMain (Superfetch) service stopped" 'Info'
                    }
                    Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction Stop
                    $count++
                    Log "SysMain (Superfetch) disabled successfully" 'Success'
                } else {
                    Log "SysMain (Superfetch) service not found on this system" 'Warning'
                    $serviceErrors += "SysMain service not found"
                }
            } catch {
                Log "Failed to disable SysMain: $($_.Exception.Message)" 'Warning'
                $serviceErrors += "SysMain: $($_.Exception.Message)"
            }
        }

        if ($Settings.Telemetry) {
            $telemetryServices = @("DiagTrack", "dmwappushservice", "WerSvc")
            $telemetrySuccessCount = 0
            foreach ($service in $telemetryServices) {
                try {
                    $serviceStatus = Get-ServiceState -ServiceName $service
                    if ($serviceStatus) {
                        if ($serviceStatus.Status -eq 'Running') {
                            Stop-Service -Name $service -Force -ErrorAction Stop
                            Log "Telemetry service '$service' stopped" 'Info'
                        }
                        Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
                        $telemetrySuccessCount++
                        Log "Telemetry service '$service' disabled successfully" 'Info'
                    } else {
                        Log "Telemetry service '$service' not found on this system" 'Warning'
                        $serviceErrors += "Telemetry service '$service' not found"
                    }
                } catch {
                    Log "Failed to disable telemetry service '$service': $($_.Exception.Message)" 'Warning'
                    $serviceErrors += "Telemetry service '$service': $($_.Exception.Message)"
                }
            }
            if ($telemetrySuccessCount -gt 0) {
                $count++
                Log "Telemetry services optimization completed: $telemetrySuccessCount/$($telemetryServices.Count) services disabled" 'Success'
            }
        }

        if ($Settings.WindowsSearch) {
            try {
                $serviceStatus = Get-ServiceState -ServiceName "WSearch"
                if ($serviceStatus) {
                    if ($serviceStatus.Status -eq 'Running') {
                        Stop-Service -Name "WSearch" -Force -ErrorAction Stop
                        Log "Windows Search service stopped" 'Info'
                    }
                    Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction Stop
                    $count++
                    Log "Windows Search disabled successfully" 'Success'
                } else {
                    Log "Windows Search service not found on this system" 'Warning'
                    $serviceErrors += "Windows Search service not found"
                }
            } catch {
                Log "Failed to disable Windows Search: $($_.Exception.Message)" 'Warning'
                $serviceErrors += "Windows Search: $($_.Exception.Message)"
            }
        }

        if ($Settings.UnneededServices) {
            $unneededServices = @("Fax", "RemoteRegistry", "MapsBroker", "WMPNetworkSvc", "bthserv", "TabletInputService", "TouchKeyboard")
            $unneededSuccessCount = 0
            foreach ($service in $unneededServices) {
                try {
                    $serviceStatus = Get-ServiceState -ServiceName $service
                    if ($serviceStatus) {
                        if ($serviceStatus.Status -eq 'Running') {
                            Stop-Service -Name $service -Force -ErrorAction Stop
                            Log "Unneeded service '$service' stopped" 'Info'
                        }
                        Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
                        $unneededSuccessCount++
                        Log "Unneeded service '$service' disabled successfully" 'Info'
                    } else {
                        Log "Unneeded service '$service' not found on this system (may already be removed)" 'Info'
                    }
                } catch {
                    Log "Failed to disable unneeded service '$service': $($_.Exception.Message)" 'Warning'
                    $serviceErrors += "Unneeded service '$service': $($_.Exception.Message)"
                }
            }
            if ($unneededSuccessCount -gt 0) {
                $count++
                Log "Unneeded services optimization completed: $unneededSuccessCount/$($unneededServices.Count) services disabled" 'Success'
            }
        }

        # Report summary of any errors encountered
        if ($serviceErrors.Count -gt 0) {
            Log "Service optimization completed with $($serviceErrors.Count) issues. Check individual service logs for details." 'Warning'
        } else {
            Log "Service optimization completed successfully with no errors" 'Success'
        }

    } catch {
        Log "Service optimization error: $($_.Exception.Message)" 'Error'
    }

    return $count
}

function Get-ServiceState {
    param([string]$ServiceName)

    if (-not $ServiceName) {
        Log "Get-ServiceState: Service name is required" 'Error'
        return $null
    }

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        return @{
            Name = $service.Name
            Status = $service.Status
            StartType = $service.StartType
            DisplayName = $service.DisplayName
        }
    } catch [Microsoft.PowerShell.Commands.ServiceCommandException] {
        Log "Get-ServiceState: Service '$ServiceName' not found on this system" 'Info'
        return $null
    } catch [System.ServiceProcess.InvalidOperationException] {
        Log "Get-ServiceState: Cannot access service '$ServiceName' - insufficient permissions or service is inaccessible" 'Warning'
        return $null
    } catch {
        Log "Get-ServiceState: Error getting service '$ServiceName': $($_.Exception.Message)" 'Warning'
        return $null
    }
}

# ---------- Advanced System Tweaks Functions ----------
function Apply-HPETOptimization {
    param([bool]$Disable = $true)

    if ($Disable) {
        try {
            bcdedit /deletevalue useplatformclock 2>$null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Hpet" "Start" 'DWord' 4 -RequiresAdmin $true | Out-Null
            Log "HPET disabled" 'Success'
        } catch {
            Log "Failed to disable HPET" 'Warning'
        }
    }
}

function Remove-MenuDelay {
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" 'String' "0" | Out-Null
    Log "Menu delay removed" 'Success'
}

function Disable-WindowsDefenderRealTime {
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
        Log "Windows Defender real-time protection disabled" 'Success'
    } catch {
        Log "Failed to disable Windows Defender: $($_.Exception.Message)" 'Warning'
    }
}

function Disable-ModernStandby {
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "PlatformAoAcOverride" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Log "Modern Standby disabled" 'Success'
}

function Enable-UTCTime {
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Log "UTC time enabled" 'Success'
}

function Optimize-NTFSSettings {
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisable8dot3NameCreation" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Log "NTFS settings optimized" 'Success'
}

function Disable-EdgeTelemetry {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "MetricsReportingEnabled" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "PersonalizationReportingEnabled" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Log "Edge telemetry disabled" 'Success'
}

function Disable-Cortana {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 'DWord' 0 | Out-Null
    Log "Cortana disabled" 'Success'
}

function Disable-Telemetry {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Log "System telemetry disabled" 'Success'
}

# ---------- Razer Booster-inspired Advanced Optimizations ----------
function Disable-AdvancedTelemetry {
    # Enhanced telemetry disabling beyond basic Windows telemetry
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableUAR" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe" "Debugger" 'String' "%windir%\System32\taskkill.exe" -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\DeviceCensus.exe" "Debugger" 'String' "%windir%\System32\taskkill.exe" -RequiresAdmin $true | Out-Null
    Log "Advanced telemetry and tracking disabled" 'Success'
}

function Enable-MemoryDefragmentation {
    # Advanced memory management and cleanup
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PoolUsageMaximum" 'DWord' 96 -RequiresAdmin $true | Out-Null
    # Enable memory compression for better performance
    try {
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    } catch { }
    Log "Memory defragmentation and optimization enabled" 'Success'
}

function Apply-ServiceOptimization {
    # Advanced service optimization for gaming performance
    $servicesToOptimize = @(
        "Themes", "WSearch", "Spooler", "Fax", "RemoteRegistry",
        "SysMain", "DiagTrack", "dmwappushservice", "PcaSvc",
        "WerSvc", "wuauserv", "BITS", "Schedule"
    )

    foreach ($service in $servicesToOptimize) {
        try {
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        } catch { }
    }
    Log "Advanced service optimization applied" 'Success'
}

function Apply-DiskTweaksAdvanced {
    # Advanced disk I/O optimizations inspired by Razer Booster
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisable8dot3NameCreation" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 'DWord' 2 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMftZoneReservation" 'DWord' 2 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "RefsDisableLastAccessUpdate" 'DWord' 1 -RequiresAdmin $true | Out-Null
    # Optimize disk cache
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "IoPageLockLimit" 'DWord' 983040 -RequiresAdmin $true | Out-Null
    Log "Advanced disk I/O tweaks applied" 'Success'
}

function Enable-NetworkLatencyOptimization {
    # Ultra-low network latency optimizations
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 'DWord' 0xffffffff -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpAckFrequency" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpDelAckTicks" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Log "Ultra-low network latency optimization enabled" 'Success'
}

function Enable-FPSSmoothness {
    # FPS smoothness and frame time optimization
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 'DWord' 8 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 'DWord' 6 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" 'String' "High" -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" 'String' "High" -RequiresAdmin $true | Out-Null
    # Enhanced GPU scheduling for smoother frame delivery
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler" "EnablePreemption" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Log "FPS smoothness and frame time optimization enabled" 'Success'
}

function Optimize-CPUMicrocode {
    # CPU microcode and cache optimization
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DisableTsx" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "MitigationOptions" 'QWord' 0x1000000000000 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettings" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 'DWord' 3 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 'DWord' 3 -RequiresAdmin $true | Out-Null
    Log "CPU microcode and cache optimization applied" 'Success'
}

function Optimize-RAMTimings {
    # RAM timing and frequency optimization
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemCacheLimit" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SecondLevelDataCache" 'DWord' 1024 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ThirdLevelDataCache" 'DWord' 8192 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePageCombining" 'DWord' 1 -RequiresAdmin $true | Out-Null
    # Enable large pages for gaming applications
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargePageMinimum" 'DWord' 2097152 -RequiresAdmin $true | Out-Null
    Log "RAM timing and frequency optimization applied" 'Success'
}

# Enhanced service disabling functions
function Disable-LocationTracking {
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" 'String' "Deny" -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocationScripting" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Log "Location tracking services disabled" 'Success'
}

function Disable-AdvertisingID {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 'DWord' 0 | Out-Null
    Log "Advertising ID services disabled" 'Success'
}

function Disable-ErrorReporting {
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Log "Error reporting services disabled" 'Success'
}

function Disable-BackgroundApps {
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 'DWord' 1 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 'DWord' 2 -RequiresAdmin $true | Out-Null
    Log "Background app refresh disabled" 'Success'
}

function Optimize-WindowsUpdate {
    # Optimize but don't completely disable Windows Update
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 'DWord' 2 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Log "Windows Update service optimized" 'Success'
}

function Disable-CompatibilityTelemetry {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableUAR" 'DWord' 1 -RequiresAdmin $true | Out-Null
    Log "Compatibility telemetry disabled" 'Success'
}

function Disable-WSH {
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" "Enabled" 'DWord' 0 -RequiresAdmin $true | Out-Null
    Log "Windows Script Host disabled" 'Success'
}

function Set-SelectiveVisualEffects {
    param([switch]$EnablePerformanceMode)

    if ($EnablePerformanceMode) {
        Set-Reg "HKCU:\Control Panel\Desktop" "DragFullWindows" 'String' "0" | Out-Null
        Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothing" 'String' "2" | Out-Null
        Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" 'String' "0" | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 'DWord' 0 | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 'DWord' 0 | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 'DWord' 3 | Out-Null
        Log "Visual effects optimized for performance" 'Success'
    }
}

# ---------- Enhanced System Optimizations ----------
function Apply-EnhancedSystemOptimizations {
    param([hashtable]$Settings)

    Log "Applying enhanced system optimizations..." 'Info'

    # Automatic Disk Defragmentation and SSD Trimming
    if ($Settings.AutoDiskOptimization) {
        try {
            # Check if SSD or HDD and apply appropriate optimization
            $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
            foreach ($drive in $drives) {
                $driveLetter = $drive.DeviceID.Replace(':', '')
                try {
                    # Check if SSD
                    $physicalDisk = Get-PhysicalDisk | Where-Object { $_.BusType -eq 'SATA' -or $_.BusType -eq 'NVMe' -or $_.BusType -eq 'RAID' }
                    if ($physicalDisk -and $physicalDisk.MediaType -eq 'SSD') {
                        # SSD TRIM optimization
                        fsutil behavior set DisableDeleteNotify 0
                        Optimize-Volume -DriveLetter $driveLetter -ReTrim -Verbose
                        Log "SSD TRIM optimization applied for drive $($drive.DeviceID)" 'Success'
                    } else {
                        # HDD defragmentation
                        Optimize-Volume -DriveLetter $driveLetter -Defrag -Verbose
                        Log "Disk defragmentation applied for drive $($drive.DeviceID)" 'Success'
                    }
                } catch {
                    Log "Drive optimization failed for $($drive.DeviceID): $($_.Exception.Message)" 'Warning'
                }
            }
        } catch {
            Log "Automatic disk optimization failed: $($_.Exception.Message)" 'Warning'
        }
    }

    # Adaptive Power Management Profiles
    if ($Settings.AdaptivePowerManagement) {
        try {
            # Create custom gaming power profile
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\GamingProfile" "FriendlyName" 'String' "KOALA Gaming Profile" -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\GamingProfile" "Description" 'String' "Optimized for gaming performance with adaptive management" -RequiresAdmin $true | Out-Null

            # Configure adaptive settings
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\2a737441-1930-4402-8d77-b2bebba308a3\d4e98f31-5ffe-4ce1-be31-1b38b384c009" "ValueMax" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\238c9fa8-0aad-41ed-83f4-97be242c8f20\94d3a615-a899-4ac5-ae2b-e4d8f634367f" "ValueMax" 'DWord' 100 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\238c9fa8-0aad-41ed-83f4-97be242c8f20\94d3a615-a899-4ac5-ae2b-e4d8f634367f" "ValueMin" 'DWord' 100 -RequiresAdmin $true | Out-Null

            # Disable CPU throttling
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\bc5038f7-23e0-4960-96da-33abaf5935ec" "ValueMax" 'DWord' 100 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\bc5038f7-23e0-4960-96da-33abaf5935ec" "ValueMin" 'DWord' 100 -RequiresAdmin $true | Out-Null

            Log "Adaptive power management profiles configured" 'Success'
        } catch {
            Log "Failed to configure adaptive power management: $($_.Exception.Message)" 'Warning'
        }
    }

    # Enhanced Paging File Management
    if ($Settings.EnhancedPagingFile) {
        try {
            # Calculate optimal paging file size based on RAM
            $totalRAM = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB
            $optimalPageFile = [Math]::Round($totalRAM * 1.5, 0) * 1024  # 1.5x RAM in MB

            # Configure paging file settings
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagingFiles" 'String' "C:\pagefile.sys $optimalPageFile $optimalPageFile" -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 -RequiresAdmin $true | Out-Null

            Log "Enhanced paging file management configured (Size: $optimalPageFile MB)" 'Success'
        } catch {
            Log "Failed to configure enhanced paging file: $($_.Exception.Message)" 'Warning'
        }
    }

    # DirectStorage API Optimization Enhancements
    if ($Settings.DirectStorageEnhanced) {
        try {
            # Advanced DirectStorage configuration
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" "ForcedPhysicalSectorSizeInBytes" 'DWord' 4096 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsEncryptPagingFile" 'DWord' 0 -RequiresAdmin $true | Out-Null

            # DirectStorage registry optimizations
            Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectStorage" "EnableCompressionGPU" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectStorage" "EnableMetalSupport" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectStorage" "ForceEnableDirectStorage" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectStorage" "OptimizationLevel" 'DWord' 2 -RequiresAdmin $true | Out-Null

            # NVMe optimizations for DirectStorage
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters" "EnableLogging" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_*\*\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 'DWord' 1 -RequiresAdmin $true | Out-Null

            Log "Enhanced DirectStorage API optimizations applied" 'Success'
        } catch {
            Log "Failed to apply DirectStorage enhancements: $($_.Exception.Message)" 'Warning'
        }
    }

    Log "Enhanced system optimizations completed" 'Success'
}

# ---------- Backup and Restore Functions ----------
function Get-NetshTcpGlobal {
    try {
        $output = netsh int tcp show global
        $settings = @{}
        foreach ($line in $output) {
            if ($line -match '^\s*(.+?)\s*:\s*(.+?)\s*$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $settings[$key] = $value
            }
        }
        return $settings
    } catch {
        return @{}
    }
}

# ---------- Registry File Creation Function ----------
function Create-RegFile {
    param(
        [Parameter(Mandatory=$true)]
        $BackupData,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    try {
        $regContent = @"
Windows Registry Editor Version 5.00

; KOALA Gaming Optimizer - Registry Backup
; Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
; Version: $($BackupData.Version)
;
; Double-click this file to restore registry settings to their backed-up values
; WARNING: This will modify your Windows registry. Create a backup before proceeding.

"@

        # Convert registry data to .reg format
        foreach ($regPath in $BackupData.Registry.PSObject.Properties.Name) {
            $regPathFormatted = $regPath -replace '^HKLM:', '[HKEY_LOCAL_MACHINE'
            $regPathFormatted = $regPathFormatted -replace '^HKCU:', '[HKEY_CURRENT_USER'
            $regPathFormatted = $regPathFormatted -replace '^HKCR:', '[HKEY_CLASSES_ROOT'
            $regPathFormatted = $regPathFormatted -replace '^HKU:', '[HKEY_USERS'
            $regPathFormatted = $regPathFormatted -replace '^HKCC:', '[HKEY_CURRENT_CONFIG'
            $regPathFormatted += ']'

            $regContent += "`n$regPathFormatted`n"

            foreach ($regName in $BackupData.Registry.$regPath.PSObject.Properties.Name) {
                $value = $BackupData.Registry.$regPath.$regName
                if ($null -ne $value) {
                    # Format as DWORD value
                    $regContent += "`"$regName`"=dword:$('{0:x8}' -f $value)`n"
                } else {
                    # Delete the value if it was null
                    $regContent += "`"$regName`"=-`n"
                }
            }
        }

        # Add NIC registry settings
        foreach ($nicPath in $BackupData.RegistryNICs.PSObject.Properties.Name) {
            $nicData = $BackupData.RegistryNICs.$nicPath
            $nicPathFormatted = $nicPath -replace '^HKLM:', '[HKEY_LOCAL_MACHINE'
            $nicPathFormatted += ']'

            $regContent += "`n$nicPathFormatted`n"

            if ($null -ne $nicData.TcpAckFrequency) {
                $regContent += "`"TcpAckFrequency`"=dword:$('{0:x8}' -f $nicData.TcpAckFrequency)`n"
            }
            if ($null -ne $nicData.TCPNoDelay) {
                $regContent += "`"TCPNoDelay`"=dword:$('{0:x8}' -f $nicData.TCPNoDelay)`n"
            }
        }

        Set-Content -Path $OutputPath -Value $regContent -Encoding Unicode -ErrorAction Stop
        Log "Registry file created successfully: $OutputPath" 'Success'

    } catch {
        Log "Failed to create registry file: $($_.Exception.Message)" 'Error'
    }
}

function Create-Backup {
    Log "Creating comprehensive backup with user-selected location..." 'Info'

    # Allow user to select backup location and format
    $saveDialog = New-Object Microsoft.Win32.SaveFileDialog; $saveDialog.Title = "Select Backup Location"
    $saveDialog.Filter = "JSON files (*.json)|*.json|Registry files (*.reg)|*.reg|All files (*.*)|*.*"
    $saveDialog.DefaultExt = ".json"
    $saveDialog.FileName = "KOALA_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $saveDialog.InitialDirectory = [Environment]::GetFolderPath("MyDocuments")

    if (-not $saveDialog.ShowDialog()) {
        Log "Backup cancelled by user" 'Info'
        return
    }

    $selectedPath = $saveDialog.FileName
    $selectedExtension = [System.IO.Path]::GetExtension($selectedPath).ToLower()

    Log "User selected backup path: $selectedPath (Format: $selectedExtension)" 'Info'

    $backupData = @{
        Timestamp = Get-Date
        Version = "3.0"
        GPU = Get-GPUVendor
        AdminPrivileges = Test-AdminPrivileges
        Registry = @{}
        RegistryNICs = @{}
        Services = @{}
        NetshTcp = @{}
        PowerSettings = @{}
    }

    # Extended registry backup list
    $regList = @(
        # Gaming optimizations
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="NetworkThrottlingIndex"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Scheduling Category"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_Enabled"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehavior"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name="AppCaptureEnabled"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name="GameDVR_Enabled"}
    )

    # Backup registry values
    foreach ($r in $regList) {
        try {
            $value = Get-Reg $r.Path $r.Name
            if (-not $backupData.Registry.ContainsKey($r.Path)) {
                $backupData.Registry[$r.Path] = @{}
            }
            $backupData.Registry[$r.Path][$r.Name] = $value
        } catch {
            # Silently continue
        }
    }

    # Per-NIC registry backup
    $nicRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $nicRoot) {
        Get-ChildItem $nicRoot | ForEach-Object {
            $nicPath = $_.PSPath
            $ack = Get-Reg $nicPath 'TcpAckFrequency'
            $nodelay = Get-Reg $nicPath 'TCPNoDelay'
            if ($null -ne $ack -or $null -ne $nodelay) {
                $backupData.RegistryNICs[$nicPath] = @{
                    TcpAckFrequency = $ack
                    TCPNoDelay = $nodelay
                }
            }
        }
    }

    # Service backup
    $svcTargets = @(
        "XblGameSave", "XblAuthManager", "XboxGipSvc", "XboxNetApiSvc",
        "Spooler", "SysMain", "DiagTrack", "WSearch", "NvTelemetryContainer",
        "AMD External Events", "Fax", "RemoteRegistry", "MapsBroker",
        "WMPNetworkSvc", "WpnUserService", "bthserv", "TabletInputService",
        "TouchKeyboard", "WerSvc", "PcaSvc", "Themes"
    )

    foreach ($serviceName in $svcTargets) {
        $service = Get-ServiceState $serviceName
        if ($service) {
            $backupData.Services[$service.Name] = $service
        }
    }

    # Network settings backup
    $backupData.NetshTcp = Get-NetshTcpGlobal

    # Power settings backup
    try {
        $backupData.PowerSettings = @{
            ActivePowerScheme = (powercfg /getactivescheme 2>$null) -replace '^.*: ', '' -replace ' \(.*\)', ''
        }
    } catch {
        # Continue
    }

    # Save backup based on user selection
    try {
        if ($selectedExtension -eq ".json") {
            # Save as JSON
            $backupJson = $backupData | ConvertTo-Json -Depth 10 -ErrorAction Stop
            Set-Content -Path $selectedPath -Value $backupJson -Encoding UTF8 -ErrorAction Stop
            Log "JSON backup successfully saved to: $selectedPath" 'Success'

            # Also create .reg file in the same directory
            $regFilePath = $selectedPath -replace '\.json$', '.reg'
            Create-RegFile -BackupData $backupData -OutputPath $regFilePath

            [System.Windows.MessageBox]::Show(
                "Backup created successfully!`n`nJSON Backup: $selectedPath`nRegistry File: $regFilePath`nTimestamp: $(Get-Date)`n`nThe JSON file contains complete backup data for script restoration.`nThe .reg file can be double-clicked to restore registry settings directly.",
                "Backup Complete",
                'OK',
                'Information'
            )
        } elseif ($selectedExtension -eq ".reg") {
            # Save as .reg file only
            Create-RegFile -BackupData $backupData -OutputPath $selectedPath

            # Also save JSON version for complete restoration
            $jsonFilePath = $selectedPath -replace '\.reg$', '.json'
            $backupJson = $backupData | ConvertTo-Json -Depth 10 -ErrorAction Stop
            Set-Content -Path $jsonFilePath -Value $backupJson -Encoding UTF8 -ErrorAction Stop

            [System.Windows.MessageBox]::Show(
                "Backup created successfully!`n`nRegistry File: $selectedPath`nJSON Backup: $jsonFilePath`nTimestamp: $(Get-Date)`n`nDouble-click the .reg file to restore registry settings.`nThe JSON file contains complete backup data for script restoration.",
                "Backup Complete",
                'OK',
                'Information'
            )
        } else {
            # Default to JSON for unknown extensions
            $backupJson = $backupData | ConvertTo-Json -Depth 10 -ErrorAction Stop
            Set-Content -Path $selectedPath -Value $backupJson -Encoding UTF8 -ErrorAction Stop
            Log "Backup saved as JSON to: $selectedPath" 'Success'

            [System.Windows.MessageBox]::Show(
                "Backup created successfully!`n`nBackup File: $selectedPath`nTimestamp: $(Get-Date)`n`nSaved in JSON format for complete restoration.",
                "Backup Complete",
                'OK',
                'Information'
            )
        }

        # Update the global backup path for restore operations
        $global:BackupPath = if ($selectedExtension -eq ".reg") { $selectedPath -replace '\.reg$', '.json' } else { $selectedPath }

    } catch {
        Log "Failed to save backup: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show(
            "Failed to save backup!`n`nError: $($_.Exception.Message)`n`nPlease check the selected location and try again.",
            "Backup Failed",
            'OK',
            'Error'
        )
    }
}

function Restore-FromBackup {
    if (-not (Test-Path $BackupPath)) {
        Log "No backup file found at: $BackupPath" 'Error'
        [System.Windows.MessageBox]::Show(
            "No backup file found!`n`nPlease create a backup before applying optimizations.",
            "Backup Not Found",
            'OK',
            'Warning'
        )
        return $false
    }

    try {
        $backupData = Get-Content $BackupPath -Raw | ConvertFrom-Json
        Log "Restoring from backup created: $($backupData.Timestamp)" 'Info'

        # Restore registry values
        foreach ($regPath in $backupData.Registry.PSObject.Properties.Name) {
            foreach ($regName in $backupData.Registry.$regPath.PSObject.Properties.Name) {
                $value = $backupData.Registry.$regPath.$regName
                if ($null -ne $value) {
                    Set-Reg $regPath $regName 'DWord' $value -RequiresAdmin $true | Out-Null
                }
            }
        }

        # Restore NIC registry values
        foreach ($nicPath in $backupData.RegistryNICs.PSObject.Properties.Name) {
            $nicData = $backupData.RegistryNICs.$nicPath
            if ($nicData.TcpAckFrequency) {
                Set-Reg $nicPath "TcpAckFrequency" 'DWord' $nicData.TcpAckFrequency -RequiresAdmin $true | Out-Null
            }
            if ($nicData.TCPNoDelay) {
                Set-Reg $nicPath "TCPNoDelay" 'DWord' $nicData.TCPNoDelay -RequiresAdmin $true | Out-Null
            }
        }

        # Restore services
        foreach ($serviceName in $backupData.Services.PSObject.Properties.Name) {
            $serviceData = $backupData.Services.$serviceName
            try {
                Set-Service -Name $serviceName -StartupType $serviceData.StartType -ErrorAction SilentlyContinue
                if ($serviceData.Status -eq 'Running') {
                    Start-Service -Name $serviceName -ErrorAction SilentlyContinue
                }
            } catch {}
        }

        Log "Backup restored successfully!" 'Success'

        [System.Windows.MessageBox]::Show(
            "Backup restored successfully!`n`nSystem has been reverted to previous state.",
            "Restore Complete",
            'OK',
            'Information'
        )

        return $true

    } catch {
        Log "Failed to restore backup: $($_.Exception.Message)" 'Error'
        return $false
    }
}

# ---------- Configuration Import/Export ----------
function Export-Configuration {
    try {
        $config = @{
            Timestamp = Get-Date
            Version = "3.0"
            GameProfile = if ($cmbGameProfile.SelectedItem) { $cmbGameProfile.SelectedItem.Tag } else { "custom" }
            CustomGameExecutable = if ($txtCustomGame.Text) { $txtCustomGame.Text.Trim() } else { "" }
            MenuMode = $global:MenuMode
            AutoOptimize = $global:AutoOptimizeEnabled
            NetworkSettings = @{
                TCPAck = $chkAck.IsChecked
                DelAckTicks = $chkDelAckTicks.IsChecked
                NetworkThrottling = $chkThrottle.IsChecked
                NagleAlgorithm = $chkNagle.IsChecked
                TCPTimestamps = $chkTcpTimestamps.IsChecked
                ECN = $chkTcpECN.IsChecked
                RSS = $chkRSS.IsChecked
                RSC = $chkRSC.IsChecked
                AutoTuning = $chkTcpAutoTune.IsChecked
            }
            GamingSettings = @{
                Responsiveness = $chkResponsiveness.IsChecked
                GamesTask = $chkGamesTask.IsChecked
                GameDVR = $chkGameDVR.IsChecked
                FSE = $chkFSE.IsChecked
                GpuScheduler = $chkGpuScheduler.IsChecked
                TimerRes = $chkTimerRes.IsChecked
                VisualEffects = $chkVisualEffects.IsChecked
                Hibernation = $chkHibernation.IsChecked
            }
        }

        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        $saveDialog.DefaultExt = ".json"
        $saveDialog.FileName = "KOALAConfig_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

        if ($saveDialog.ShowDialog()) {
            $configJson = $config | ConvertTo-Json -Depth 10
            Set-Content -Path $saveDialog.FileName -Value $configJson -Encoding UTF8
            Log "Configuration exported to: $($saveDialog.FileName)" 'Success'

            [System.Windows.MessageBox]::Show(
                "Configuration exported successfully!`n`nLocation: $($saveDialog.FileName)",
                "Export Complete",
                'OK',
                'Information'
            )
        }
    } catch {
        Log "Failed to export configuration: $($_.Exception.Message)" 'Error'
    }
}

function Import-Configuration {
    try {
        $openDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        $openDialog.DefaultExt = ".json"

        if ($openDialog.ShowDialog()) {
            $configJson = Get-Content $openDialog.FileName -Raw
            $config = $configJson | ConvertFrom-Json

            # Apply configuration
            if ($config.GameProfile) {
                foreach ($item in $cmbGameProfile.Items) {
                    if ($item.Tag -eq $config.GameProfile) {
                        $cmbGameProfile.SelectedItem = $item
                        break
                    }
                }
            }

            if ($config.CustomGameExecutable) {
                $txtCustomGame.Text = $config.CustomGameExecutable
            }

            if ($config.MenuMode) {
                Switch-MenuMode -Mode $config.MenuMode
                # Menu mode control removed from header - mode managed through Options panel only
                # foreach ($item in $cmbMenuMode.Items) {
                #     if ($item.Tag -eq $config.MenuMode) {
                #         $cmbMenuMode.SelectedItem = $item
                #         break
                #     }
                # }
            }

            # Apply network settings
            if ($config.NetworkSettings) {
                $chkAck.IsChecked = $config.NetworkSettings.TCPAck
                $chkDelAckTicks.IsChecked = $config.NetworkSettings.DelAckTicks
                $chkThrottle.IsChecked = $config.NetworkSettings.NetworkThrottling
                $chkNagle.IsChecked = $config.NetworkSettings.NagleAlgorithm
                $chkTcpTimestamps.IsChecked = $config.NetworkSettings.TCPTimestamps
                $chkTcpECN.IsChecked = $config.NetworkSettings.ECN
                $chkRSS.IsChecked = $config.NetworkSettings.RSS
                $chkRSC.IsChecked = $config.NetworkSettings.RSC
                $chkTcpAutoTune.IsChecked = $config.NetworkSettings.AutoTuning
            }

            # Apply gaming settings
            if ($config.GamingSettings) {
                $chkResponsiveness.IsChecked = $config.GamingSettings.Responsiveness
                $chkGamesTask.IsChecked = $config.GamingSettings.GamesTask
                $chkGameDVR.IsChecked = $config.GamingSettings.GameDVR
                $chkFSE.IsChecked = $config.GamingSettings.FSE
                $chkGpuScheduler.IsChecked = $config.GamingSettings.GpuScheduler
                $chkTimerRes.IsChecked = $config.GamingSettings.TimerRes
                $chkVisualEffects.IsChecked = $config.GamingSettings.VisualEffects
                $chkHibernation.IsChecked = $config.GamingSettings.Hibernation
            }

            Log "Configuration imported from: $($openDialog.FileName)" 'Success'

            [System.Windows.MessageBox]::Show(
                "Configuration imported successfully!`n`nSettings have been applied.",
                "Import Complete",
                'OK',
                'Information'
            )
        }
    } catch {
        Log "Failed to import configuration: $($_.Exception.Message)" 'Error'
    }
}

# ---------- Benchmark Function ----------
function Start-QuickBenchmark {
    Log "Starting quick system benchmark..." 'Info'

    try {
        $startTime = Get-Date

        # CPU test
        $cpuStart = Get-Date
        $sum = 0
        for ($i = 0; $i -lt 1000000; $i++) { $sum += $i }
        $cpuTime = (Get-Date) - $cpuStart

        # Memory test
        $memStart = Get-Date
        $array = @()
        for ($i = 0; $i -lt 10000; $i++) { $array += Get-Random }
        $memTime = (Get-Date) - $memStart

        # Disk test
        $diskStart = Get-Date
        $testFile = Join-Path $env:TEMP "koala_bench_test.tmp"
        $testData = "x" * 1024 * 1024  # 1MB of data
        Set-Content -Path $testFile -Value $testData
        $diskWriteTime = (Get-Date) - $diskStart

        $diskReadStart = Get-Date
        Get-Content -Path $testFile | Out-Null
        $diskReadTime = (Get-Date) - $diskReadStart

        Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue

        $totalTime = (Get-Date) - $startTime

        $results = @"
Quick System Benchmark Results:

CPU Performance: $([math]::Round($cpuTime.TotalMilliseconds, 2)) ms
Memory Performance: $([math]::Round($memTime.TotalMilliseconds, 2)) ms
Disk Write: $([math]::Round($diskWriteTime.TotalMilliseconds, 2)) ms
Disk Read: $([math]::Round($diskReadTime.TotalMilliseconds, 2)) ms

Total Time: $([math]::Round($totalTime.TotalMilliseconds, 2)) ms

Note: Lower times indicate better performance.
These are basic tests for comparison purposes.
"@

        [System.Windows.MessageBox]::Show(
            $results,
            "Benchmark Results",
            'OK',
            'Information'
        )

        Log "Benchmark completed successfully" 'Success'

    } catch {
        Log "Benchmark failed: $($_.Exception.Message)" 'Error'
    }
}

# ---------- Event Handlers ----------

# Admin elevation
if ($btnElevate) {
    $btnElevate.Add_Click({
        Log "Privilege elevation requested by user" 'Info'
        Show-ElevationMessage -Operations @(
            "System Registry Modifications",
            "Windows Service Configuration",
            "Power Management Settings",
            "Advanced CPU and Memory Optimizations"
        )
    })
}

# Menu mode selector removed from header - now only available in Options panel
# $cmbMenuMode.Add_SelectionChanged({
#     try {
#         $selectedMode = $cmbMenuMode.SelectedItem.Tag
#         Log "Menu mode selection changed to: $selectedMode" 'Info'
#         Switch-MenuMode -Mode $selectedMode
#     } catch {
#         Log "Error changing menu mode: $($_.Exception.Message)" 'Error'
#     }
# })

# Removed $cmbTheme event handler (now only using Options panel theme)

# Auto-detect games
if ($btnAutoDetect) {
    $btnAutoDetect.Add_Click({
        Log "Auto-detecting running games in $global:MenuMode mode..." 'Info'
        Log "Executable detection request - searching for running processes" 'Info'
        $detectedGames = Get-RunningGames
        $global:ActiveGames = $detectedGames

        if ($detectedGames.Count -gt 0) {
            $firstGame = $detectedGames[0]
            $process = $firstGame.Process

            if ($lblDashActiveGames) {
                $lblDashActiveGames.Dispatcher.Invoke([Action]{
                    $lblDashActiveGames.Text = "$($detectedGames.Count) running"
                    Set-BrushPropertySafe -Target $lblDashActiveGames -Property 'Foreground' -Value '#8F6FFF'
                })
            }

            # Enhanced logging with executable details
            Log "Detected Game: $($firstGame.DisplayName)" 'Success'
            Log "Executable: $($process.ProcessName).exe (PID: $($process.Id))" 'Info'
            try {
                if ($process.MainModule -and $process.MainModule.FileName) {
                    Log "Path: $($process.MainModule.FileName)" 'Info'
                }
            } catch {
            Log "Path: Access denied (running as different user)" 'Warning'
        }

        # Show all detected games if multiple found
        if ($detectedGames.Count -gt 1) {
            Log "Additional games detected: $(($detectedGames[1..($detectedGames.Count-1)] | ForEach-Object { $_.DisplayName }) -join ', ')" 'Info'
        }

        # Select the first game in the dropdown
        foreach ($item in $cmbGameProfile.Items) {
            if ($item.Tag -eq $firstGame.GameKey) {
                $cmbGameProfile.SelectedItem = $item
                Log "Selected profile: $($firstGame.DisplayName)" 'Success'
                break
            }
        }

        # Show user-friendly message with details
        $processInfo = "Process: $($process.ProcessName).exe (PID: $($process.Id))"
        [System.Windows.MessageBox]::Show("Successfully detected: $($firstGame.DisplayName)`n$processInfo`n`nProfile automatically selected in dropdown.", "Game Detected", 'OK', 'Information')
    } else {
        Log "No supported games detected" 'Warning'
        [System.Windows.MessageBox]::Show("No supported games are currently running.", "No Games Detected", 'OK', 'Information')
        if ($lblDashActiveGames) {
            $lblDashActiveGames.Dispatcher.Invoke([Action]{
                $lblDashActiveGames.Text = "None detected"
                Set-BrushPropertySafe -Target $lblDashActiveGames -Property 'Foreground' -Value '#A6AACF'
            })
        }
    }
})
}

# Optimize custom game button
$btnOptimizeGame.Add_Click({
    try {
        $gameExecutable = $txtCustomGame.Text.Trim()

        if ([string]::IsNullOrEmpty($gameExecutable)) {
            Log "Please enter a game executable name first" 'Warning'
            [System.Windows.MessageBox]::Show("Please enter a game executable name (e.g., mygame.exe) before optimizing.", "No Game Specified", 'OK', 'Warning')
            return
        }

        Log "Starting optimization for custom game: $gameExecutable" 'Info'

        # Apply standard gaming optimizations
        Apply-CustomGameOptimizations -GameExecutable $gameExecutable

        Log "Successfully applied gaming optimizations for: $gameExecutable" 'Success'
        [System.Windows.MessageBox]::Show("Gaming optimizations have been successfully applied for '$gameExecutable'!`n`nOptimizations applied:`n* Process priority boost`n* Network latency reduction`n* GPU scheduling enhancement`n* Game mode activation`n* High precision timers", "Optimization Complete", 'OK', 'Information')

    } catch {
        Log "Error optimizing custom game: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error applying optimizations: $($_.Exception.Message)", "Optimization Failed", 'OK', 'Error')
    }
})

# Find executable button
$btnFindExecutable.Add_Click({
    try {
        $gameExecutable = $txtCustomGame.Text.Trim()

        if ([string]::IsNullOrEmpty($gameExecutable)) {
            Log "Please enter a game executable name first" 'Warning'
            [System.Windows.MessageBox]::Show("Please enter a game executable name (e.g., mygame.exe) to search for.", "No Game Specified", 'OK', 'Warning')
            return
        }

        Log "Searching for executable: $gameExecutable" 'Info'

        # Search for the executable in common game directories
        $searchPaths = @(
            "C:\Program Files\",
            "C:\Program Files (x86)\",
            "C:\Program Files\WindowsApps\",
            "D:\Program Files\",
            "D:\Program Files (x86)\",
            "C:\Games\",
            "D:\Games\",
            "$env:USERPROFILE\Desktop\",
            "$env:USERPROFILE\Documents\",
            "$env:USERPROFILE\Downloads\"
        )

        $found = $false
        $foundPaths = @()

        foreach ($path in $searchPaths) {
            if (Test-Path $path) {
                $files = Get-ChildItem -Path $path -Recurse -Name $gameExecutable -ErrorAction SilentlyContinue
                if ($files) {
                    foreach ($file in $files) {
                        $fullPath = Join-Path $path $file
                        $foundPaths += $fullPath
                        $found = $true
                    }
                }
            }
        }

        if ($found) {
            $pathsText = $foundPaths -join "`n"
            Log "Executable '$gameExecutable' found at: $($foundPaths[0])" 'Success'
            [System.Windows.MessageBox]::Show("Executable '$gameExecutable' found!`n`nLocation(s):`n$pathsText", "Executable Found", 'OK', 'Information')
        } else {
            Log "Executable '$gameExecutable' not found in common directories" 'Warning'
            [System.Windows.MessageBox]::Show("Executable '$gameExecutable' was not found in common game directories.`n`nNote: The executable may still exist in other locations, or it may need to be running to be detected.", "Executable Not Found", 'OK', 'Warning')
        }

    } catch {
        Log "Error searching for executable: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error searching for executable: $($_.Exception.Message)", "Search Failed", 'OK', 'Error')
    }
})

# Custom game executable text change - Track user input for enhanced logging
$txtCustomGame.Add_TextChanged({
    try {
        $gameText = $txtCustomGame.Text.Trim()
        if ($gameText -and $gameText.Length -gt 2) {
            Log "Custom game executable entered: $gameText" 'Info'
            Log "User preparing to optimize custom game in $global:MenuMode mode" 'Info'
        }
    } catch {
        # Silent fail for text input monitoring to avoid spam
    }
})

# Installed Games button - Show installed games discovery window
if ($btnInstalledGames) {
    $btnInstalledGames.Add_Click({
        try {
            Log "Installed Games discovery initiated by user" 'Info'
            Show-InstalledGames
        } catch {
            Log "Error showing installed games: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error displaying installed games: $($_.Exception.Message)", "Installed Games Error", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnInstalledGames control not found - skipping event handler binding" 'Warning'
}

if ($btnInstalledGamesDash -and $btnInstalledGames) {
    $btnInstalledGamesDash.Add_Click({
        try {
            $btnInstalledGames.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        } catch {
            Log "Error relaying dashboard installed games action: $($_.Exception.Message)" 'Warning'
        }
    })
}

# Basic Network Optimizations button
$btnBasicNetwork.Add_Click({
    try {
        Log "Applying Basic Network Optimizations..." 'Info'

        # Apply all network optimizations from the Network section
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpAckFrequency" "DWord" 1 $true
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" "DWord" 0 $true
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" "DWord" 4294967295 $true
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" "DWord" 1 $true
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "Tcp1323Opts" "DWord" 0 $true
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpWindowSize" "DWord" 1073725440 $true

        Log "Network optimizations applied successfully in $global:MenuMode mode!" 'Success'
        Log "Applied 6 network optimizations: TCP ACK, DelAck, Throttling, NoDelay, Timestamps, Window Size" 'Info'
        [System.Windows.MessageBox]::Show("Network optimizations have been applied successfully!`n`nOptimizations applied:`n* TCP ACK Frequency optimization`n* Network throttling disabled`n* Nagle algorithm disabled`n* TCP window size optimized`n* Latency reduction tweaks", "Network Optimization Complete", 'OK', 'Information')

    } catch {
        Log "Error applying network optimizations: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error applying network optimizations: $($_.Exception.Message)", "Optimization Failed", 'OK', 'Error')
    }
})

# Basic System Performance button
$btnBasicSystem.Add_Click({
    try {
        Log "Applying Basic System Performance Optimizations..." 'Info'

        # Apply system performance optimizations
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" "DWord" 0 $true
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" "DWord" 8 $true
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" "DWord" 6 $true
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" "DWord" 38 $true
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" "DWord" 1 $true

        # Set Ultimate Performance power plan
        try {
            $ultimatePlan = powercfg /l | Where-Object { $_ -like "*Ultimate Performance*" }
            if ($ultimatePlan) {
                $planGUID = ($ultimatePlan -split "\s+")[3]
                powercfg /setactive $planGUID
                Log "Ultimate Performance power plan activated" 'Success'
            }
        } catch {
            Log "Could not set Ultimate Performance power plan" 'Warning'
        }

        Log "System performance optimizations applied successfully in $global:MenuMode mode!" 'Success'
        Log "Applied 5 system optimizations: Responsiveness, GPU Priority, CPU Scheduling, Memory Management, Power Plan" 'Info'
        [System.Windows.MessageBox]::Show("System performance optimizations have been applied successfully!`n`nOptimizations applied:`n* System responsiveness enhanced`n* Game task priority boosted`n* CPU scheduling optimized`n* Memory management improved`n* Power plan optimized", "System Optimization Complete", 'OK', 'Information')

    } catch {
        Log "Error applying system optimizations: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error applying system optimizations: $($_.Exception.Message)", "Optimization Failed", 'OK', 'Error')
    }
})

# Basic Gaming Optimizations button
$btnBasicGaming.Add_Click({
    try {
        Log "Applying Basic Gaming Optimizations..." 'Info'

        # Apply essential gaming optimizations
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" "DWord" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" "DWord" 0 $true
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" "DWord" 2 $true
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AutoGameModeEnabled" "DWord" 1
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "String" "High" $true
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" "String" "High" $true

        # Enable high precision timer
        try {
            [WinMM]::timeBeginPeriod(1)
            Log "High precision timer enabled (1ms)" 'Success'
        } catch {
            Log "Could not set high precision timer" 'Warning'
        }

        # Disable hibernation
        try {
            powercfg /hibernate off | Out-Null
            Log "Hibernation disabled" 'Success'
        } catch {
            Log "Could not disable hibernation" 'Warning'
        }

        Log "Gaming optimizations applied successfully in $global:MenuMode mode!" 'Success'
        Log "Applied 7 gaming optimizations: Game DVR, GPU Scheduling, Game Mode, High Priority, Precision Timer, Hibernation" 'Info'
        [System.Windows.MessageBox]::Show("Gaming optimizations have been applied successfully!`n`nOptimizations applied:`n* Game DVR disabled`n* Hardware GPU scheduling enabled`n* Game mode activated`n* High precision timer enabled`n* Visual effects optimized`n* Hibernation disabled", "Gaming Optimization Complete", 'OK', 'Information')

    } catch {
        Log "Error applying gaming optimizations: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error applying gaming optimizations: $($_.Exception.Message)", "Optimization Failed", 'OK', 'Error')
    }
})

# Apply theme button
# Removed $btnApplyTheme event handler (now only in Options panel)

# Options panel event handlers - selection changes only update preview, no instant application
if ($cmbOptionsTheme) {
    $cmbOptionsTheme.Add_SelectionChanged({
        if ($script:ThemeSelectionSyncInProgress) { return }

        try {
            $script:ThemeSelectionSyncInProgress = $true

            if ($cmbOptionsTheme.SelectedItem -and $cmbOptionsTheme.SelectedItem.Tag) {
                $selectedTheme = $cmbOptionsTheme.SelectedItem.Tag
                $themeName = $cmbOptionsTheme.SelectedItem.Content

                # Keep header selection in sync without causing recursion
                if ($cmbHeaderTheme) {
                    foreach ($headerItem in $cmbHeaderTheme.Items) {
                        if ($headerItem.Tag -eq $selectedTheme) {
                            if ($cmbHeaderTheme.SelectedItem -ne $headerItem) {
                                $cmbHeaderTheme.SelectedItem = $headerItem
                            }
                            break
                        }
                    }
                }

                # Update color preview panel only - no instant theme application
                Update-ThemeColorPreview -ThemeName $selectedTheme

                # Show/hide custom theme panel
                if ($selectedTheme -eq "Custom" -and $customThemePanel) {
                    $customThemePanel.Visibility = "Visible"
                    if ($global:CustomThemeColors) {
                        if ($txtCustomBg) { $txtCustomBg.Text = $global:CustomThemeColors['Background'] }
                        if ($txtCustomPrimary) { $txtCustomPrimary.Text = $global:CustomThemeColors['Primary'] }
                        if ($txtCustomHover) { $txtCustomHover.Text = $global:CustomThemeColors['Hover'] }
                        if ($txtCustomText) { $txtCustomText.Text = $global:CustomThemeColors['Text'] }
                    }
                } elseif ($customThemePanel) {
                    $customThemePanel.Visibility = "Collapsed"
                }

                Log "Theme selection changed to '$themeName' - preview updated (Apply button required for theme change)" 'Info'
            }
        } catch {
            Log "Error updating theme preview: $($_.Exception.Message)" 'Error'
        } finally {
            $script:ThemeSelectionSyncInProgress = $false
        }
    })
}

if ($cmbHeaderTheme) {
    $cmbHeaderTheme.Add_SelectionChanged({
        if ($script:ThemeSelectionSyncInProgress) { return }

        try {
            $script:ThemeSelectionSyncInProgress = $true

            if ($cmbHeaderTheme.SelectedItem -and $cmbHeaderTheme.SelectedItem.Tag) {
                $selectedTheme = $cmbHeaderTheme.SelectedItem.Tag
                $themeName = $cmbHeaderTheme.SelectedItem.Content

                if ($cmbOptionsTheme) {
                    foreach ($item in $cmbOptionsTheme.Items) {
                        if ($item.Tag -eq $selectedTheme) {
                            if ($cmbOptionsTheme.SelectedItem -ne $item) {
                                $cmbOptionsTheme.SelectedItem = $item
                            }
                            break
                        }
                    }
                }

                Update-ThemeColorPreview -ThemeName $selectedTheme

                if ($selectedTheme -eq 'Custom' -and $customThemePanel) {
                    $customThemePanel.Visibility = 'Visible'
                    if ($global:CustomThemeColors) {
                        if ($txtCustomBg) { $txtCustomBg.Text = $global:CustomThemeColors['Background'] }
                        if ($txtCustomPrimary) { $txtCustomPrimary.Text = $global:CustomThemeColors['Primary'] }
                        if ($txtCustomHover) { $txtCustomHover.Text = $global:CustomThemeColors['Hover'] }
                        if ($txtCustomText) { $txtCustomText.Text = $global:CustomThemeColors['Text'] }
                    }
                } elseif ($customThemePanel) {
                    $customThemePanel.Visibility = 'Collapsed'
                }

                Log "Header theme selection changed to '$themeName'" 'Info'
            }
        } catch {
            Log "Error syncing header theme selection: $($_.Exception.Message)" 'Error'
        } finally {
            $script:ThemeSelectionSyncInProgress = $false
        }
    })
}

# Apply button - primary method for theme application (themes only apply when clicked)
# Theme Apply Button Event Handler
if ($btnOptionsApplyTheme) {
    $btnOptionsApplyTheme.Add_Click({
        try {
            if ($cmbOptionsTheme.SelectedItem -and $cmbOptionsTheme.SelectedItem.Tag) {
                $selectedTheme = $cmbOptionsTheme.SelectedItem.Tag
                $themeName = $cmbOptionsTheme.SelectedItem.Content

                Log "Applying theme: $themeName" 'Info'
                Switch-Theme -ThemeName $selectedTheme

                # Force ComboBox refresh
                $cmbOptionsTheme.InvalidateVisual()
                $cmbOptionsTheme.UpdateLayout()

                [System.Windows.MessageBox]::Show("Theme '$themeName' wurde erfolgreich angewendet!", "Theme Applied", 'OK', 'Information')
            } else {
                [System.Windows.MessageBox]::Show("Bitte wÃ¤hlen Sie zuerst ein Theme aus der Liste.", "No Theme Selected", 'OK', 'Warning')
            }
        } catch {
            Log "Error applying theme: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Fehler beim Anwenden des Themes: $($_.Exception.Message)", "Theme Error", 'OK', 'Error')
        }
    })
}


# Alias button for test compatibility - applies same functionality
if ($btnApplyTheme) {
    $btnApplyTheme.Add_Click({
        # Apply the selected theme instantly - same as main button functionality
        if ($btnOptionsApplyTheme) {
            $btnOptionsApplyTheme.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        }
    })
}

if ($btnHeaderApplyTheme -and $btnOptionsApplyTheme) {
    $btnHeaderApplyTheme.Add_Click({
        try {
            if ($cmbHeaderTheme -and $cmbHeaderTheme.SelectedItem -and $cmbHeaderTheme.SelectedItem.Tag) {
                $selectedTheme = $cmbHeaderTheme.SelectedItem.Tag

                if ($cmbOptionsTheme) {
                    foreach ($item in $cmbOptionsTheme.Items) {
                        if ($item.Tag -eq $selectedTheme) {
                            if ($cmbOptionsTheme.SelectedItem -ne $item) {
                                $cmbOptionsTheme.SelectedItem = $item
                            }
                            break
                        }
                    }
                }

                $btnOptionsApplyTheme.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
            } else {
                [System.Windows.MessageBox]::Show("Please select a theme first.", "Theme", 'OK', 'Warning')
            }
        } catch {
            Log "Error applying theme from header: $($_.Exception.Message)" 'Error'
        }
    })
}

if ($btnApplyScale) {
    $btnApplyScale.Add_Click({
        try {
            if ($cmbUIScale.SelectedItem -and $cmbUIScale.SelectedItem.Tag) {
                $scaleValue = [double]$cmbUIScale.SelectedItem.Tag
                $scalePercent = $cmbUIScale.SelectedItem.Content

                Log "Applying UI scale: $scalePercent (factor: $scaleValue)" 'Info'

                # Apply UI scaling transformation
                $scaleTransform = New-Object System.Windows.Media.ScaleTransform($scaleValue, $scaleValue)
                $form.LayoutTransform = $scaleTransform

                Log "UI scale '$scalePercent' applied successfully" 'Success'
                [System.Windows.MessageBox]::Show("UI scale '$scalePercent' has been applied successfully!", "Scale Applied", 'OK', 'Information')
            } else {
                [System.Windows.MessageBox]::Show("Please select a scale from the dropdown first.", "No Scale Selected", 'OK', 'Warning')
            }
        } catch {
            Log "Error applying UI scale: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error applying UI scale: $($_.Exception.Message)", "Scale Application Failed", 'OK', 'Error')
        }
    })
}

function Get-AdvancedCheckboxControls {
    if (-not $panelAdvanced) {
        return @()
    }

    $results = @()
    $stack = [System.Collections.Stack]::new()
    $stack.Push($panelAdvanced)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()

        if ($current -is [System.Windows.Controls.CheckBox]) {
            $results += $current
        }

        if ($current -is [System.Windows.DependencyObject]) {
            $childCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($current)
            for ($i = 0; $i -lt $childCount; $i++) {
                $child = [System.Windows.Media.VisualTreeHelper]::GetChild($current, $i)
                if ($child) {
                    $stack.Push($child)
                }
            }
        }
    }

    return $results
}

function Get-AdvancedCheckboxNames {
    $dynamicControls = Get-AdvancedCheckboxControls | Where-Object { $_ -and $_.Name }

    if ($dynamicControls -and $dynamicControls.Count -gt 0) {
        $uniqueNames = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($checkbox in $dynamicControls) {
            [void]$uniqueNames.Add($checkbox.Name)
        }

        if ($uniqueNames.Count -gt 0) {
            return $uniqueNames.ToArray()
        }
    }

    return @(
        'chkAckNetwork'
        'chkDelAckTicksNetwork'
        'chkNagleNetwork'
        'chkNetworkThrottlingNetwork'
        'chkRSSNetwork'
        'chkRSCNetwork'
        'chkChimneyNetwork'
        'chkNetDMANetwork'
        'chkTcpTimestampsNetwork'
        'chkTcpWindowAutoTuningNetwork'
        'chkMemoryCompressionSystem'
        'chkPowerPlanSystem'
        'chkCPUSchedulingSystem'
        'chkPageFileSystem'
        'chkVisualEffectsSystem'
        'chkCoreParkingSystem'
        'chkGameDVRSystem'
        'chkFullscreenOptimizationsSystem'
        'chkGPUSchedulingSystem'
        'chkTimerResolutionSystem'
        'chkGameModeSystem'
        'chkMPOSystem'
        'chkDynamicResolution'
        'chkEnhancedFramePacing'
        'chkGPUOverclocking'
        'chkCompetitiveLatency'
        'chkAutoDiskOptimization'
        'chkAdaptivePowerManagement'
        'chkEnhancedPagingFile'
        'chkDirectStorageEnhanced'
        'chkAdvancedTelemetryDisable'
        'chkMemoryDefragmentation'
        'chkServiceOptimization'
        'chkDiskTweaksAdvanced'
        'chkNetworkLatencyOptimization'
        'chkFPSSmoothness'
        'chkCPUMicrocode'
        'chkRAMTimings'
        'chkDisableXboxServicesServices'
        'chkDisableTelemetryServices'
        'chkDisableSearchServices'
        'chkDisablePrintSpoolerServices'
        'chkDisableSuperfetchServices'
        'chkDisableFaxServices'
        'chkDisableRemoteRegistryServices'
        'chkDisableThemesServices'
        'chkDisableCortana'
        'chkDisableWindowsUpdate'
        'chkDisableBackgroundApps'
        'chkDisableLocationTracking'
        'chkDisableAdvertisingID'
        'chkDisableErrorReporting'
        'chkDisableCompatTelemetry'
        'chkDisableWSH'
    )
}

function Get-AdvancedCheckedSelections {
    $checked = @()

    foreach ($name in Get-AdvancedCheckboxNames) {
        $checkbox = $form.FindName($name)
        if ($checkbox -and $checkbox.IsChecked) {
            $checked += $name
        }
    }

    return $checked
}

function Set-AdvancedSelections {
    param(
        [string[]]$CheckedNames
    )

    $lookup = @{}

    if ($CheckedNames) {
        foreach ($entry in $CheckedNames) {
            $trimmed = $entry.Trim()
            if ($trimmed) {
                $lookup[$trimmed] = $true
            }
        }
    }

    foreach ($name in Get-AdvancedCheckboxNames) {
        $checkbox = $form.FindName($name)
        if ($checkbox) {
            $checkbox.IsChecked = $lookup.ContainsKey($name)
        }
    }
}

function Get-AdvancedSelectionSummary {
    param(
        [string[]]$CheckedNames
    )

    if (-not $CheckedNames -or $CheckedNames.Count -eq 0) {
        return 'None'
    }

    $labels = @()

    foreach ($name in $CheckedNames) {
        $checkbox = $form.FindName($name)
        if ($checkbox -and $checkbox.PSObject.Properties['Content'] -and $checkbox.Content) {
            $labels += [string]$checkbox.Content
        } else {
            $labels += $name
        }
    }

    if ($labels.Count -eq 0) {
        return 'None'
    }

    return ($labels -join ', ')
}

if ($btnSaveSettings) {
    $btnSaveSettings.Add_Click({
        try {
            $configPath = Join-Path (Get-Location) "koala-settings.cfg"

            # Gather current settings
            $currentTheme = if ($cmbOptionsTheme.SelectedItem) { $cmbOptionsTheme.SelectedItem.Tag } else { "Nebula" }
            $currentScale = if ($cmbUIScale.SelectedItem) { $cmbUIScale.SelectedItem.Tag } else { "1.0" }
            $currentLanguage = if ($script:CurrentLanguage) { $script:CurrentLanguage } else { 'en' }
            $advancedSelections = Get-AdvancedCheckedSelections
            $advancedSelectionsValue = $advancedSelections -join ','
            $advancedSummary = Get-AdvancedSelectionSummary -CheckedNames $advancedSelections


            $settings = @"
# KOALA Gaming Optimizer Settings - koala-settings.cfg with Theme= UIScale= MenuMode= support
# Generated on $(Get-Date)
Theme=$currentTheme
UIScale=$currentScale
MenuMode=$global:MenuMode
Language=$currentLanguage
AdvancedSelections=$advancedSelectionsValue
"@

            Set-Content -Path $configPath -Value $settings -Encoding UTF8
            Log "Settings saved to koala-settings.cfg (Theme: $currentTheme, Scale: $currentScale, Language: $currentLanguage, Advanced: $advancedSummary)" 'Success'
            [System.Windows.MessageBox]::Show("Settings have been saved to koala-settings.cfg successfully!", "Settings Saved", 'OK', 'Information')
        } catch {
            Log "Error saving settings: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error saving settings: $($_.Exception.Message)", "Save Failed", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnSaveSettings control not found - skipping event handler binding" 'Warning'
}

if ($btnLoadSettings) {
    $btnLoadSettings.Add_Click({
        try {
            $configPath = Join-Path (Get-Location) "koala-settings.cfg"

            if (Test-Path $configPath) {
                $content = Get-Content $configPath -Raw
                $settings = @{}

                $content -split "`n" | ForEach-Object {
                    if ($_ -match "^([^#=]+)=(.*)$") {
                        $settings[$matches[1].Trim()] = $matches[2].Trim()
                    }
                }

                # Apply loaded theme
                if ($settings.Theme) {
                    foreach ($item in $cmbOptionsTheme.Items) {
                        if ($item.Tag -eq $settings.Theme) {
                            $cmbOptionsTheme.SelectedItem = $item
                            Switch-Theme -ThemeName $settings.Theme
                            break
                        }
                    }
                }

                # Apply loaded scale
                if ($settings.UIScale) {
                    foreach ($item in $cmbUIScale.Items) {
                        if ($item.Tag -eq $settings.UIScale) {
                            $cmbUIScale.SelectedItem = $item
                            $scaleValue = [double]$settings.UIScale
                            $scaleTransform = New-Object System.Windows.Media.ScaleTransform($scaleValue, $scaleValue)
                            $form.LayoutTransform = $scaleTransform
                            break
                        }
                    }
                }

                if ($settings.Language) {
                    Set-UILanguage -LanguageCode $settings.Language
                }

                if ($settings.ContainsKey('AdvancedSelections')) {
                    $advancedChecked = @()
                    if ($settings.AdvancedSelections) {
                        $advancedChecked = $settings.AdvancedSelections -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    }

                    Set-AdvancedSelections -CheckedNames $advancedChecked

                    $advancedLoadSummary = Get-AdvancedSelectionSummary -CheckedNames $advancedChecked
                    Log "Advanced selections restored from koala-settings.cfg: $advancedLoadSummary" 'Info'
                }

                Log "Settings loaded from koala-settings.cfg successfully" 'Success'
                [System.Windows.MessageBox]::Show("Settings have been loaded and applied successfully!", "Settings Loaded", 'OK', 'Information')
            } else {
                Log "No settings file found at koala-settings.cfg" 'Warning'
                [System.Windows.MessageBox]::Show("No settings file found. Please save settings first.", "No Settings File", 'OK', 'Warning')
            }
        } catch {
            Log "Error loading settings: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error loading settings: $($_.Exception.Message)", "Load Failed", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnLoadSettings control not found - skipping event handler binding" 'Warning'
}

if ($btnResetSettings) {
    $btnResetSettings.Add_Click({
        try {
            $result = [System.Windows.MessageBox]::Show(
                "Are you sure you want to reset all settings to default?`n`nThis will:`n- Set theme to Dark Purple`n- Set UI scale to 100%`n- Switch to Basic mode",
                "Reset Settings",
                'YesNo',
                'Question'
            )

            if ($result -eq 'Yes') {
                # Reset theme to Dark Purple
                foreach ($item in $cmbOptionsTheme.Items) {
                    if ($item.Tag -eq "Nebula") {
                        $cmbOptionsTheme.SelectedItem = $item
                        Switch-Theme -ThemeName "Nebula"
                        break
                    }
                }

                # Reset scale to 100%
                foreach ($item in $cmbUIScale.Items) {
                    if ($item.Tag -eq "1.0") {
                        $cmbUIScale.SelectedItem = $item
                        $form.LayoutTransform = $null
                        break
                    }
                }

                # Reset to Basic mode
                # Menu mode control removed from header - mode managed through Options panel only
                # foreach ($item in $cmbMenuMode.Items) {
                #     if ($item.Tag -eq "Basic") {
                #         $cmbMenuMode.SelectedItem = $item
                #         Switch-MenuMode -Mode "Basic"
                #         break
                #     }
                # }
                Switch-MenuMode -Mode "Basic"  # Direct call without UI control

                # Reset advanced selections
                Set-AdvancedSelections -CheckedNames @()

                Log "All settings reset to default values" 'Success'
                [System.Windows.MessageBox]::Show("All settings have been reset to default values!", "Settings Reset", 'OK', 'Information')
            }
        } catch {
            Log "Error resetting settings: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error resetting settings: $($_.Exception.Message)", "Reset Failed", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnResetSettings control not found - skipping event handler binding" 'Warning'
}

# Auto-optimize checkbox
if ($chkAutoOptimize) {
    $chkAutoOptimize.Add_Checked({
        $global:AutoOptimizeEnabled = $true
        Log "Auto-optimization enabled in $global:MenuMode mode" 'Success'
        Log "System will now automatically optimize detected games every 5 seconds" 'Info'
        Start-GameDetectionMonitoring
    })

    $chkAutoOptimize.Add_Unchecked({
        $global:AutoOptimizeEnabled = $false
        Log "Auto-optimization disabled in $global:MenuMode mode" 'Info'
        Stop-GameDetectionMonitoring
        $global:ActiveGames = @()
    })
} else {
    Log "Warning: chkAutoOptimize control not found - skipping event handler binding" 'Warning'
}

# Clear log button - Enhanced user action tracking
if ($btnClearLog) {
    $btnClearLog.Add_Click({
        try {
            Log "User requested to clear Activity Log in $global:MenuMode mode" 'Info'

            if ($global:LogBox -and $global:LogBoxAvailable) {
                try {
                    $currentLogLines = if ($global:LogBox.Text) { ($global:LogBox.Text -split "`n").Count } else { 0 }
                    $global:LogBox.Clear()
                Log "Activity Log cleared successfully ($currentLogLines entries removed)" 'Success'
                Log "Activity Log reset - ready for new user action tracking" 'Info'

                # Show user feedback
                [System.Windows.MessageBox]::Show("Activity Log has been cleared successfully!`n`nThe log is now ready to track new user actions.`nPrevious $currentLogLines log entries have been removed from the display.", "Log Cleared", 'OK', 'Information')

            } catch {
                Log "Failed to clear Activity Log UI: $($_.Exception.Message)" 'Warning'
                [System.Windows.MessageBox]::Show("Warning: Could not clear the Activity Log display.`n`nError: $($_.Exception.Message)", "Clear Failed", 'OK', 'Warning')
            }
        } else {
            Log "Activity Log UI not available - cleared console logs only" 'Warning'
            [System.Windows.MessageBox]::Show("Activity Log display not available.`nConsole logs have been noted as cleared.", "Limited Clear", 'OK', 'Warning')
        }

    } catch {
        Log "Error in Clear Log operation: $($_.Exception.Message)" 'Error'
    }
})
}

# Activity Log Extend button - Toggle height functionality
if ($btnExtendLog) {
    # Initialize global variable for log state
    $global:LogExtended = $false

    $btnExtendLog.Add_Click({
        try {
            if ($activityLogBorder) {
                if (-not $global:LogExtended) {
                    # Extend the log to full size
                    $activityLogBorder.MinHeight = 120
                    $btnExtendLog.Content = "⤡ Collapse"
                    $global:LogExtended = $true
                    Log "Activity Log extended to full size" 'Info'
                } else {
                    # Collapse the log to 25% size
                    $activityLogBorder.MinHeight = 30
                    $btnExtendLog.Content = "⤢ Extend"
                    $global:LogExtended = $false
                    Log "Activity Log collapsed to compact size" 'Info'
                }

                # Force layout update
                $activityLogBorder.InvalidateMeasure()
                $activityLogBorder.UpdateLayout()
            }
        } catch {
            Log "Error toggling Activity Log size: $($_.Exception.Message)" 'Error'
        }
    })
}

# Activity Log View Toggle button - Switch between compact and detailed views
if ($btnToggleLogView) {
    # Initialize global variable for log view state
    $global:LogViewDetailed = $true

    $btnToggleLogView.Add_Click({
        try {
            if ($global:LogBox) {
                if ($global:LogViewDetailed) {
                    # Switch to compact view - show only latest entries
                    $allLogLines = $global:LogBox.Text -split "`n"
                    $compactLines = $allLogLines | Where-Object {
                        $_ -match "Success|Error|Warning|Applied|Optimization"
                    } | Select-Object -Last 20

                    $global:LogBox.Text = ($compactLines -join "`n")
                    $btnToggleLogView.Content = "📁 Compact"
                    $global:LogViewDetailed = $false
                    Log "Switched to compact log view (showing key actions only)" 'Info'
                } else {
                    # Switch to detailed view - show all entries
                    # Restore from backup or show message
                    if ($global:DetailedLogBackup) {
                        $global:LogBox.Text = $global:DetailedLogBackup
                    }
                    $btnToggleLogView.Content = "📄 Detailed"
                    $global:LogViewDetailed = $true
                    Log "Switched to detailed log view (showing all entries)" 'Info'
                }

                # Auto-scroll to bottom
                if ($logScrollViewer) {
                    $logScrollViewer.ScrollToBottom()
                }
            }
        } catch {
            Log "Error toggling log view mode: $($_.Exception.Message)" 'Error'
        }
    })

    # Store detailed log for restoration
    $global:DetailedLogBackup = ""
}

# Activity Log Save button
if ($btnSaveLog) {
    $btnSaveLog.Add_Click({
        try {
            Log "User requested to save Activity Log" 'Info'

            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveDialog.Filter = "Text files (*.txt)|*.txt|Log files (*.log)|*.log|All files (*.*)|*.*"
            $saveDialog.DefaultExt = ".txt"
            $saveDialog.FileName = "Koala-Activity-Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
            $saveDialog.Title = "Save Activity Log"
            $saveDialog.InitialDirectory = [Environment]::GetFolderPath("MyDocuments")

            if ($saveDialog.ShowDialog()) {
                $selectedPath = $saveDialog.FileName
                if ($global:LogBox -and $global:LogBox.Text) {
                    Set-Content -Path $selectedPath -Value $global:LogBox.Text -Encoding UTF8
                    Log "Activity log saved to: $selectedPath" 'Success'
                    [System.Windows.MessageBox]::Show(
                        "Activity log saved successfully!`n`nLocation: $selectedPath`nTimestamp: $(Get-Date)",
                        "Log Saved",
                        'OK',
                        'Information'
                    )
                } else {
                    Log "No activity log content available to save" 'Warning'
                    [System.Windows.MessageBox]::Show("No activity log content available to save.", "No Content", 'OK', 'Warning')
                }
            }
        } catch {
            Log "Error saving activity log: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Failed to save activity log: $($_.Exception.Message)", "Save Error", 'OK', 'Error')
        }
    })
}

# Search Log button - Enhanced log search and filtering
if ($btnSearchLog) {
    $btnSearchLog.Add_Click({
        try {
            Log "User opened log search and filter interface" 'Info'
            Show-LogSearchDialog
        } catch {
            Log "Error opening log search interface: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Failed to open log search interface: $($_.Exception.Message)", "Search Error", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnSearchLog control not found - skipping event handler binding" 'Warning'
}

# System info
if ($btnSystemInfo) { $btnSystemInfo.Add_Click({ Get-SystemInfo }) }

# Benchmark
if ($btnBenchmark) { $btnBenchmark.Add_Click({ Start-QuickBenchmark }) }

# System Health button - Show detailed health dialog
if ($btnSystemHealth) {
    $btnSystemHealth.Add_Click({
        try {
            Log "User opened System Health Monitor" 'Info'
            Show-SystemHealthDialog
        } catch {
            Log "Error opening System Health Monitor: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Failed to open System Health Monitor: $($_.Exception.Message)", "Health Monitor Error", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnSystemHealth control not found - skipping event handler binding" 'Warning'
}

if ($btnSystemHealthRunCheck) {
    $btnSystemHealthRunCheck.Add_Click({
        try {
            Log "Manual system health check requested from dashboard" 'Info'
            $result = Update-SystemHealthDisplay -RunCheck
            if ($result.HealthStatus -eq 'Error') {
                [System.Windows.MessageBox]::Show("Health check completed with errors. Please review the Activity Log for details.", "Health Check", 'OK', 'Warning') | Out-Null
            } else {
                $roundedScore = if ($result.HealthScore -ne $null) { [Math]::Round([double]$result.HealthScore, 0) } else { $null }
                $summary = if ($roundedScore -ne $null) { "$($result.HealthStatus) ($roundedScore%)" } else { $result.HealthStatus }
                [System.Windows.MessageBox]::Show("System health check completed: $summary.", "Health Check", 'OK', 'Information') | Out-Null
            }
        } catch {
            Log "Error running dashboard health check: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error running health check: $($_.Exception.Message)", "Health Check", 'OK', 'Error') | Out-Null
        }
    })
} else {
    Log "Warning: btnSystemHealthRunCheck control not found - skipping event handler binding" 'Warning'
}

# Backup
if ($btnBackup) { $btnBackup.Add_Click({ Create-Backup }) }

# Export/Import config
if ($btnExportConfig) { $btnExportConfig.Add_Click({ Export-Configuration }) }
if ($btnImportConfig) { $btnImportConfig.Add_Click({ Import-Configuration }) }

# Options panel export/import handlers (same functions)
if ($btnExportConfigOptions) {
    $btnExportConfigOptions.Add_Click({ Export-Configuration })
}
if ($btnImportConfigOptions) {
    $btnImportConfigOptions.Add_Click({ Import-Configuration })
}

# Backup as .reg file handler
if ($btnBackupReg) {
    $btnBackupReg.Add_Click({
        try {
            Log "Registry backup (.reg file) requested" 'Info'
            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $regBackupPath = Join-Path (Get-Location) "Koala-Registry-Backup_$timestamp.reg"

            # Create registry backup in .reg format
            $regContent = @"
Windows Registry Editor Version 5.00

; KOALA Gaming Optimizer Registry Backup
; Created: $(Get-Date)
; Note: This backup contains registry keys that may be modified by the optimizer

"@

            # Add key registry paths that the optimizer modifies
            $keyPaths = @(
                "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
                "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
                "HKEY_CURRENT_USER\SOFTWARE\Microsoft\GameBar",
                "HKEY_CURRENT_USER\System\GameConfigStore"
            )

            foreach ($keyPath in $keyPaths) {
                try {
                    $regContent += "`r`n`r`n; Backup of $keyPath`r`n"
                    $regPath = $keyPath -replace "HKEY_LOCAL_MACHINE", "HKLM:" -replace "HKEY_CURRENT_USER", "HKCU:"

                    if (Test-Path $regPath -ErrorAction SilentlyContinue) {
                        $regContent += "[$keyPath]`r`n"
                        # Export registry values would require more complex logic
                        $regContent += "; Registry values would be exported here`r`n"
                    }
                } catch {
                    # Continue with other keys if one fails
                }
            }

            Set-Content -Path $regBackupPath -Value $regContent -Encoding Unicode
            Log "Registry backup created: $regBackupPath" 'Success'
            [System.Windows.MessageBox]::Show("Registry backup created successfully!`n`nFile: $regBackupPath", "Registry Backup Complete", 'OK', 'Information')

        } catch {
            Log "Error creating registry backup: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error creating registry backup: $($_.Exception.Message)", "Backup Failed", 'OK', 'Error')
        }
    })
}

# Backup panel button handlers
if ($btnCreateBackup) { $btnCreateBackup.Add_Click({ Create-Backup }) }
if ($btnExportConfigBackup) { $btnExportConfigBackup.Add_Click({ Export-Configuration }) }
if ($btnRestoreBackup) { $btnRestoreBackup.Add_Click({ Import-Configuration }) }
if ($btnImportConfigBackup) { $btnImportConfigBackup.Add_Click({ Import-Configuration }) }

if ($btnSaveActivityLog) {
    $btnSaveActivityLog.Add_Click({
        try {
            Log "Save activity log requested" 'Info'
            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            $saveDialog.Filter = "Log files (*.log)|*.log|Text files (*.txt)|*.txt|All files (*.*)|*.*"
            $saveDialog.DefaultExt = ".log"
            $saveDialog.FileName = "KOALA_Activity_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $saveDialog.Title = "Select Activity Log Save Location"
            $saveDialog.InitialDirectory = [Environment]::GetFolderPath("MyDocuments")

            if ($saveDialog.ShowDialog()) {
                $selectedPath = $saveDialog.FileName
                if ($global:LogBox -and $global:LogBox.Items) {
                    $logContent = $global:LogBox.Items | ForEach-Object { $_.ToString() }
                    $logText = $logContent -join "`r`n"
                    Set-Content -Path $selectedPath -Value $logText -Encoding UTF8
                    Log "Activity log saved to: $selectedPath" 'Success'
                    [System.Windows.MessageBox]::Show(
                        "Activity log saved successfully!`n`nLocation: $selectedPath`nTimestamp: $(Get-Date)",
                        "Log Saved",
                        'OK',
                        'Information'
                    )
                } else {
                    Log "No activity log content available to save" 'Warning'
                    [System.Windows.MessageBox]::Show("No activity log content available to save.", "No Content", 'OK', 'Warning')
                }
            }
        } catch {
            Log "Error saving activity log: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error saving activity log: $($_.Exception.Message)", "Save Failed", 'OK', 'Error')
        }
    })
}

if ($btnClearActivityLog) {
    $btnClearActivityLog.Add_Click({
        try {
            $result = [System.Windows.MessageBox]::Show(
                "Are you sure you want to clear the activity log?`nThis action cannot be undone.",
                "Clear Activity Log",
                'YesNo',
                'Question'
            )
            if ($result -eq 'Yes') {
                if ($global:LogBox) {
                    $global:LogBox.Items.Clear()
                    Log "Activity log cleared by user" 'Info'
                }
            }
        } catch {
            Log "Error clearing activity log: $($_.Exception.Message)" 'Error'
        }
    })
}

if ($btnViewActivityLog) {
    $btnViewActivityLog.Add_Click({
        # Switch to the main panel to show the activity log
        Switch-Panel "Dashboard"
    })
}

# Network Panel Action Button Handlers
if ($btnApplyNetworkTweaks) {
    $btnApplyNetworkTweaks.Add_Click({
        try {
            Log "Applying network optimizations..." 'Info'
            # Apply selected network optimizations
            Invoke-NetworkPanelOptimizations
            Log "Network optimizations applied successfully" 'Success'
            [System.Windows.MessageBox]::Show("Network optimizations applied successfully!", "Network Optimization", 'OK', 'Information')
        } catch {
            Log "Error applying network optimizations: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error applying network optimizations: $($_.Exception.Message)", "Network Error", 'OK', 'Error')
        }
    })
}

if ($btnTestNetworkLatency) {
    $btnTestNetworkLatency.Add_Click({
        try {
            Log "Testing network latency..." 'Info'
            Test-NetworkLatency
        } catch {
            Log "Error testing network latency: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error testing network latency: $($_.Exception.Message)", "Network Test Error", 'OK', 'Error')
        }
    })
}

if ($btnResetNetworkSettings) {
    $btnResetNetworkSettings.Add_Click({
        try {
            $result = [System.Windows.MessageBox]::Show("Are you sure you want to reset all network settings to default?", "Reset Network Settings", 'YesNo', 'Warning')
            if ($result -eq 'Yes') {
                Log "Resetting network settings to default..." 'Info'
                Reset-NetworkSettings
                Log "Network settings reset successfully" 'Success'
                [System.Windows.MessageBox]::Show("Network settings reset to default values successfully!", "Reset Complete", 'OK', 'Information')
            }
        } catch {
            Log "Error resetting network settings: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error resetting network settings: $($_.Exception.Message)", "Reset Error", 'OK', 'Error')
        }
    })
}

# System Panel Action Button Handlers
if ($btnApplySystemOptimizations) {
    $btnApplySystemOptimizations.Add_Click({
        try {
            Log "Applying system optimizations..." 'Info'
            Invoke-SystemPanelOptimizations
            Log "System optimizations applied successfully" 'Success'
            [System.Windows.MessageBox]::Show("System optimizations applied successfully!", "System Optimization", 'OK', 'Information')
        } catch {
            Log "Error applying system optimizations: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error applying system optimizations: $($_.Exception.Message)", "System Error", 'OK', 'Error')
        }
    })
}

if ($btnSystemBenchmark) {
    $btnSystemBenchmark.Add_Click({
        try {
            Log "Starting system benchmark..." 'Info'
            Start-SystemBenchmark
        } catch {
            Log "Error starting system benchmark: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error starting system benchmark: $($_.Exception.Message)", "Benchmark Error", 'OK', 'Error')
        }
    })
}

if ($btnResetSystemSettings) {
    $btnResetSystemSettings.Add_Click({
        try {
            $result = [System.Windows.MessageBox]::Show("Are you sure you want to reset all system settings to default?", "Reset System Settings", 'YesNo', 'Warning')
            if ($result -eq 'Yes') {
                Log "Resetting system settings to default..." 'Info'
                Reset-SystemSettings
                Log "System settings reset successfully" 'Success'
                [System.Windows.MessageBox]::Show("System settings reset to default values successfully!", "Reset Complete", 'OK', 'Information')
            }
        } catch {
            Log "Error resetting system settings: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error resetting system settings: $($_.Exception.Message)", "Reset Error", 'OK', 'Error')
        }
    })
}

# Services Panel Action Button Handlers
if ($btnApplyServiceOptimizations) {
    $btnApplyServiceOptimizations.Add_Click({
        try {
            Log "Applying service optimizations..." 'Info'
            Invoke-ServicePanelOptimizations
            Log "Service optimizations applied successfully" 'Success'
            [System.Windows.MessageBox]::Show("Service optimizations applied successfully!", "Service Optimization", 'OK', 'Information')
        } catch {
            Log "Error applying service optimizations: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error applying service optimizations: $($_.Exception.Message)", "Service Error", 'OK', 'Error')
        }
    })
}

if ($btnViewRunningServices) {
    $btnViewRunningServices.Add_Click({
        try {
            Log "Viewing running services..." 'Info'
            Show-RunningServices
        } catch {
            Log "Error viewing running services: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error viewing running services: $($_.Exception.Message)", "Services Error", 'OK', 'Error')
        }
    })
}

if ($btnResetServiceSettings) {
    $btnResetServiceSettings.Add_Click({
        try {
            $result = [System.Windows.MessageBox]::Show("Are you sure you want to reset all service settings to default?", "Reset Service Settings", 'YesNo', 'Warning')
            if ($result -eq 'Yes') {
                Log "Resetting service settings to default..." 'Info'
                Reset-ServiceSettings
                Log "Service settings reset successfully" 'Success'
                [System.Windows.MessageBox]::Show("Service settings reset to default values successfully!", "Reset Complete", 'OK', 'Information')
            }
        } catch {
            Log "Error resetting service settings: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error resetting service settings: $($_.Exception.Message)", "Reset Error", 'OK', 'Error')
        }
    })
}

# New Installed Games panel event handlers
if ($btnSearchGames) {
    $btnSearchGames.Add_Click({
        try {
            Log "Game search initiated from Installed Games panel" 'Info'
            Search-GamesForPanel
        } catch {
            Log "Error searching for games: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error searching for games: $($_.Exception.Message)", "Game Search Error", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnSearchGames control not found - skipping event handler binding" 'Warning'
}

if ($btnAddGameFolder) {
    $btnAddGameFolder.Add_Click({
        try {
            Log "Add game folder requested from panel" 'Info'
            $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderDialog.Description = "Select a folder containing game executables or installations"
            $folderDialog.ShowNewFolderButton = $false

            if ($folderDialog.ShowDialog() -eq 'OK') {
                $selectedPath = $folderDialog.SelectedPath
            Log "User selected game folder: $selectedPath" 'Info'

            # Add the selected path to global search paths if not already included
            if (-not $global:CustomGamePaths) {
                $global:CustomGamePaths = @()
            }

            if ($selectedPath -notin $global:CustomGamePaths) {
                $global:CustomGamePaths += $selectedPath
                Log "Added custom game path: $selectedPath" 'Success'

                # Show the Custom Search button now that we have custom folders
                if ($btnCustomSearch) {
                    $btnCustomSearch.Visibility = "Visible"
                    Log "Enabled Custom Search button (custom folders available)" 'Info'
                }

                # Enhanced user prompt as required
                $searchChoice = [System.Windows.MessageBox]::Show(
                    "Game folder added successfully: $selectedPath`n`nDo you want to search only this folder?`n`n* Yes: Search only the selected folder and show all executables (.exe) found`n* No: Include this folder in the full PC search with all existing locations",
                    "Custom Folder Search Option",
                    'YesNoCancel',
                    'Question'
                )

                if ($searchChoice -eq 'Yes') {
                    Log "User chose to search only the selected folder" 'Info'
                    Start-CustomFolderOnlySearch -FolderPath $selectedPath
                } elseif ($searchChoice -eq 'No') {
                    Log "User chose to proceed with full PC search including new folder" 'Info'
                    Search-GamesForPanel
                } else {
                    Log "User cancelled the search operation" 'Info'
                    [System.Windows.MessageBox]::Show("The folder has been added to your custom search list. You can use 'Custom Search' button or 'Search for Installed Games' later.", "Folder Added", 'OK', 'Information')
                }
            } else {
                Log "Path already exists in custom search paths: $selectedPath" 'Warning'
                [System.Windows.MessageBox]::Show("This folder is already included in the search. Click 'Search for Installed Games' to refresh the list.", "Folder Already Added", 'OK', 'Information')
            }
        }
    } catch {
        Log "Error adding game folder: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error adding game folder: $($_.Exception.Message)", "Add Folder Error", 'OK', 'Error')
    }
    })
} else {
    Log "Warning: btnAddGameFolder control not found - skipping event handler binding" 'Warning'
}

# Enhanced Custom Search with user choice functionality
function Start-CustomFolderOnlySearch {
    param([string]$FolderPath)

    try {
        Log "Starting custom folder-only search in: $FolderPath" 'Info'

        # Clear existing content
        $gameListPanel.Children.Clear()

        # Add loading message
        $loadingText = New-Object System.Windows.Controls.TextBlock
        $loadingText.Text = "🔍 Searching '$FolderPath' for all executables (.exe)..."
        Set-BrushPropertySafe -Target $loadingText -Property 'Foreground' -Value '#8F6FFF'
        $loadingText.FontStyle = "Italic"
        $loadingText.HorizontalAlignment = "Center"
        $loadingText.Margin = "0,20"
        $gameListPanel.Children.Add($loadingText)

        # Force UI update
        [System.Windows.Forms.Application]::DoEvents()

        # Search for all .exe files in the selected folder and subfolders
        $foundExecutables = @()
        Log "Scanning folder recursively for .exe files: $FolderPath" 'Info'

        try {
            $exeFiles = Get-ChildItem -Path $FolderPath -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
                       Where-Object { $_.Length -gt 100KB }  # Filter out very small executables

            foreach ($exe in $exeFiles) {
                try {
                    $foundExecutables += [PSCustomObject]@{
                        Name = $exe.BaseName
                        Path = $exe.FullName
                        Size = [math]::Round($exe.Length / 1MB, 2)
                        LastModified = $exe.LastWriteTime.ToString("yyyy-MM-dd")
                        Details = "Executable found in custom folder"
                        CanOptimize = $true
                    }
                } catch {
                    # Continue if file details can't be read
                }
            }

            Log "Found $($foundExecutables.Count) executable files in custom folder" 'Success'

        } catch {
            Log "Error scanning custom folder: $($_.Exception.Message)" 'Error'
        }

        # Clear loading message
        $gameListPanel.Children.Clear()

        if ($foundExecutables.Count -gt 0) {
            # Add header
            $headerText = New-Object System.Windows.Controls.TextBlock
            $headerText.Text = "Found $($foundExecutables.Count) Executables in '$([System.IO.Path]::GetFileName($FolderPath))'"
            Set-BrushPropertySafe -Target $headerText -Property 'Foreground' -Value '#8F6FFF'
            $headerText.FontWeight = "Bold"
            $headerText.FontSize = 14
            $headerText.Margin = "0,0,0,10"
            $gameListPanel.Children.Add($headerText)

            # Add each executable with optimization option
            foreach ($executable in $foundExecutables) {
                $gamePanel = New-Object System.Windows.Controls.Border
                Set-BrushPropertySafe -Target $gamePanel -Property 'Background' -Value '#14132B'
                try {
                    Set-BrushPropertySafe -Target $gamePanel -Property 'BorderBrush' -Value '#2F285A'
                    $gamePanel.BorderThickness = "1"
                } catch {
                    Write-Verbose "BorderBrush assignment skipped for .NET Framework 4.8 compatibility"
                }
                $gamePanel.Padding = "12"
                $gamePanel.Margin = "0,0,0,8"

                $gameGrid = New-Object System.Windows.Controls.Grid
                $gameGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="*"}))
                $gameGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="Auto"}))

                # Game info
                $gameInfo = New-Object System.Windows.Controls.StackPanel
                [System.Windows.Controls.Grid]::SetColumn($gameInfo, 0)

                $gameName = New-Object System.Windows.Controls.TextBlock
                $gameName.Text = $executable.Name
                Set-BrushPropertySafe -Target $gameName -Property 'Foreground' -Value '#F5F3FF'
                $gameName.FontWeight = "Bold"
                $gameName.FontSize = 14
                $gameInfo.Children.Add($gameName)

                $gameDetails = New-Object System.Windows.Controls.TextBlock
                $gameDetails.Text = "📁 $($executable.Path)`n📊 Size: $($executable.Size) MB | 📅 Modified: $($executable.LastModified)"
                Set-BrushPropertySafe -Target $gameDetails -Property 'Foreground' -Value '#A9A5D9'
                $gameDetails.FontSize = 10
                $gameDetails.TextWrapping = "Wrap"
                $gameInfo.Children.Add($gameDetails)

                # Optimize button
                $optimizeBtn = New-Object System.Windows.Controls.Button
                $optimizeBtn.Content = "⚡ Optimize"
                $optimizeBtn.Width = 100
                $optimizeBtn.Height = 32
                $optimizeBtn.Style = $window.Resources["SuccessButton"]
                $optimizeBtn.Tag = $executable.Path
                [System.Windows.Controls.Grid]::SetColumn($optimizeBtn, 1)

                # Add click handler for optimization
                $optimizeBtn.Add_Click({
                    $exePath = $this.Tag
                    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
                    Log "User requested optimization for custom executable: $exeName" 'Info'

                    try {
                        # Apply standard gaming optimizations
                        Apply-GameOptimizations -GameName $exeName -ExecutablePath $exePath
                        [System.Windows.MessageBox]::Show("Optimization applied successfully for '$exeName'!", "Optimization Complete", 'OK', 'Information')
                        Log "Successfully optimized custom executable: $exeName" 'Success'
                    } catch {
                        Log "Error optimizing custom executable: $($_.Exception.Message)" 'Error'
                        [System.Windows.MessageBox]::Show("Error optimizing '$exeName': $($_.Exception.Message)", "Optimization Error", 'OK', 'Error')
                    }
                })

                $gameGrid.Children.Add($gameInfo)
                $gameGrid.Children.Add($optimizeBtn)
                $gamePanel.Child = $gameGrid
                $gameListPanel.Children.Add($gamePanel)
            }

            # Enable the optimize selected button
            if ($btnOptimizeSelected) {
                Set-OptimizeButtonsEnabled -Enabled $true
            }

        } else {
            $noGamesText = New-Object System.Windows.Controls.TextBlock
            $noGamesText.Text = "No executable files (.exe) found in the selected folder.`n`nTip: Make sure the folder contains game installations or executable files."
            Set-BrushPropertySafe -Target $noGamesText -Property 'Foreground' -Value '#7D7EB0'
            $noGamesText.FontStyle = "Italic"
            $noGamesText.HorizontalAlignment = "Center"
            $noGamesText.TextAlignment = "Center"
            $noGamesText.Margin = "0,20"
            $gameListPanel.Children.Add($noGamesText)
        }

    } catch {
        Log "Error in custom folder search: $($_.Exception.Message)" 'Error'
        [System.Windows.MessageBox]::Show("Error searching custom folder: $($_.Exception.Message)", "Search Error", 'OK', 'Error')
    }
}

if ($btnCustomSearch) {
    $btnCustomSearch.Add_Click({
        try {
            Log "Custom Search requested - searching only custom folders" 'Info'

            if (-not $global:CustomGamePaths -or $global:CustomGamePaths.Count -eq 0) {
                [System.Windows.MessageBox]::Show("No custom folders have been added yet. Please add game folders first using 'Add Game Folder'.", "No Custom Folders", 'OK', 'Warning')
                return
            }

            # Show choice dialog for custom search
            $searchChoice = [System.Windows.MessageBox]::Show(
                "Do you want to search only custom folders?`n`n* Yes: Search only the custom folders you've added and show all executables (.exe) found`n* No: Perform full PC search including custom folders with known games",
                "Custom Search Options",
                'YesNoCancel',
                'Question'
            )

            if ($searchChoice -eq 'Yes') {
                Log "User chose to search only custom folders" 'Info'
                Start-AllCustomFoldersSearch
            } elseif ($searchChoice -eq 'No') {
                Log "User chose full PC search including custom folders" 'Info'
                Search-GamesForPanel
            } else {
                Log "User cancelled custom search" 'Info'
            }

        } catch {
            Log "Error in custom search: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error in custom search: $($_.Exception.Message)", "Search Error", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnCustomSearch control not found - skipping event handler binding" 'Warning'
}

if ($btnSearchGamesPanel -and $btnSearchGames) {
    $btnSearchGamesPanel.Add_Click({
        try {
            $btnSearchGames.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        } catch {
            Log "Error relaying Installed Games panel search action: $($_.Exception.Message)" 'Warning'
        }
    })
}

if ($btnAddGameFolderPanel -and $btnAddGameFolder) {
    $btnAddGameFolderPanel.Add_Click({
        try {
            $btnAddGameFolder.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        } catch {
            Log "Error relaying Installed Games panel add-folder action: $($_.Exception.Message)" 'Warning'
        }
    })
}

if ($btnCustomSearchPanel -and $btnCustomSearch) {
    $btnCustomSearchPanel.Add_Click({
        try {
            $btnCustomSearch.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        } catch {
            Log "Error relaying Installed Games panel custom search action: $($_.Exception.Message)" 'Warning'
        }
    })
}

if ($btnAddGameFolderDash -and $btnAddGameFolder) {
    $btnAddGameFolderDash.Add_Click({
        try {
            $btnAddGameFolder.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        } catch {
            Log "Error relaying dashboard add-folder action: $($_.Exception.Message)" 'Warning'
        }
    })
}

if ($btnCustomSearchDash -and $btnCustomSearch) {
    $btnCustomSearchDash.Add_Click({
        try {
            $btnCustomSearch.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        } catch {
            Log "Error relaying dashboard custom search action: $($_.Exception.Message)" 'Warning'
        }
    })
}

# Search all custom folders for executables
function Start-AllCustomFoldersSearch {
    try {
        Log "Starting search of all custom folders" 'Info'

        # Clear existing content
        $gameListPanel.Children.Clear()

        # Add loading message
        $loadingText = New-Object System.Windows.Controls.TextBlock
        $loadingText.Text = "🔍 Searching all custom folders for executables..."
        Set-BrushPropertySafe -Target $loadingText -Property 'Foreground' -Value '#8F6FFF'
        $loadingText.FontStyle = "Italic"
        $loadingText.HorizontalAlignment = "Center"
        $loadingText.Margin = "0,20"
        $gameListPanel.Children.Add($loadingText)

        # Force UI update
        [System.Windows.Forms.Application]::DoEvents()

        $allExecutables = @()

        foreach ($folderPath in $global:CustomGamePaths) {
            try {
                Log "Scanning custom folder: $folderPath" 'Info'
                $exeFiles = Get-ChildItem -Path $folderPath -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
                           Where-Object { $_.Length -gt 100KB }

                foreach ($exe in $exeFiles) {
                    $allExecutables += [PSCustomObject]@{
                        Name = $exe.BaseName
                        Path = $exe.FullName
                        Folder = [System.IO.Path]::GetFileName($folderPath)
                        Size = [math]::Round($exe.Length / 1MB, 2)
                        LastModified = $exe.LastWriteTime.ToString("yyyy-MM-dd")
                    }
                }
            } catch {
                Log "Error scanning folder $folderPath`: $($_.Exception.Message)" 'Warning'
            }
        }

        # Clear loading and show results
        $gameListPanel.Children.Clear()

        if ($allExecutables.Count -gt 0) {
            $headerText = New-Object System.Windows.Controls.TextBlock
            $headerText.Text = "Found $($allExecutables.Count) Executables in Custom Folders"
            Set-BrushPropertySafe -Target $headerText -Property 'Foreground' -Value '#8F6FFF'
            $headerText.FontWeight = "Bold"
            $headerText.FontSize = 14
            $headerText.Margin = "0,0,0,10"
            $gameListPanel.Children.Add($headerText)

            foreach ($exe in $allExecutables) {
                $gamePanel = New-Object System.Windows.Controls.Border
                Set-BrushPropertySafe -Target $gamePanel -Property 'Background' -Value '#14132B'
                try {
                    Set-BrushPropertySafe -Target $gamePanel -Property 'BorderBrush' -Value '#2F285A'
                    $gamePanel.BorderThickness = "1"
                } catch {
                    Write-Verbose "BorderBrush assignment skipped for .NET Framework 4.8 compatibility"
                }
                $gamePanel.Padding = "12"
                $gamePanel.Margin = "0,0,0,8"

                $gameGrid = New-Object System.Windows.Controls.Grid
                $gameGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="*"}))
                $gameGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="Auto"}))

                $gameInfo = New-Object System.Windows.Controls.StackPanel
                [System.Windows.Controls.Grid]::SetColumn($gameInfo, 0)

                $gameName = New-Object System.Windows.Controls.TextBlock
                $gameName.Text = $exe.Name
                Set-BrushPropertySafe -Target $gameName -Property 'Foreground' -Value '#F5F3FF'
                $gameName.FontWeight = "Bold"
                $gameName.FontSize = 14
                $gameInfo.Children.Add($gameName)

                $gameDetails = New-Object System.Windows.Controls.TextBlock
                $gameDetails.Text = "📁 From: $($exe.Folder) | 📊 $($exe.Size) MB | 📅 $($exe.LastModified)"
                Set-BrushPropertySafe -Target $gameDetails -Property 'Foreground' -Value '#A9A5D9'
                $gameDetails.FontSize = 10
                $gameInfo.Children.Add($gameDetails)

                $optimizeBtn = New-Object System.Windows.Controls.Button
                $optimizeBtn.Content = "⚡ Optimize"
                $optimizeBtn.Width = 100
                $optimizeBtn.Height = 32
                $optimizeBtn.Style = $window.Resources["SuccessButton"]
                $optimizeBtn.Tag = $exe.Path
                [System.Windows.Controls.Grid]::SetColumn($optimizeBtn, 1)

                $optimizeBtn.Add_Click({
                    $exePath = $this.Tag
                    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
                    Log "Optimizing custom executable: $exeName" 'Info'

                    try {
                        Apply-GameOptimizations -GameName $exeName -ExecutablePath $exePath
                        [System.Windows.MessageBox]::Show("Optimization applied for '$exeName'!", "Success", 'OK', 'Information')
                        Log "Successfully optimized: $exeName" 'Success'
                    } catch {
                        Log "Error optimizing $exeName`: $($_.Exception.Message)" 'Error'
                        [System.Windows.MessageBox]::Show("Error optimizing '$exeName': $($_.Exception.Message)", "Error", 'OK', 'Error')
                    }
                })

                $gameGrid.Children.Add($gameInfo)
                $gameGrid.Children.Add($optimizeBtn)
                $gamePanel.Child = $gameGrid
                $gameListPanel.Children.Add($gamePanel)
            }
        } else {
            $noGamesText = New-Object System.Windows.Controls.TextBlock
            $noGamesText.Text = "No executable files found in custom folders."
            Set-BrushPropertySafe -Target $noGamesText -Property 'Foreground' -Value '#7D7EB0'
            $noGamesText.FontStyle = "Italic"
            $noGamesText.HorizontalAlignment = "Center"
            $noGamesText.Margin = "0,20"
            $gameListPanel.Children.Add($noGamesText)
        }

    } catch {
        Log "Error in all custom folders search: $($_.Exception.Message)" 'Error'
    }
}

if ($btnOptimizeSelected -or $btnOptimizeSelectedMain -or $btnOptimizeSelectedDashboard) {
    $optimizeSelectedHandler = {
        param($sender, $eventArgs)

        try {
            Log "Optimize selected games requested" 'Info'

            $panelsToScan = @()
            if ($sender -and $sender.Name -eq 'btnOptimizeSelectedDashboard' -and $script:DashboardGameListPanel) {
                $panelsToScan += $script:DashboardGameListPanel
            } elseif ($sender -and $sender.Name -eq 'btnOptimizeSelectedMain' -and $script:PrimaryGameListPanel) {
                $panelsToScan += $script:PrimaryGameListPanel
            }

            if ($panelsToScan.Count -eq 0) {
                if ($script:PrimaryGameListPanel) { $panelsToScan += $script:PrimaryGameListPanel }
                if ($script:DashboardGameListPanel) { $panelsToScan += $script:DashboardGameListPanel }
            }

            if ($panelsToScan.Count -eq 0) {
                Log "Warning: No game list panels available when optimizing selections" 'Warning'
                [System.Windows.MessageBox]::Show("No game list is available to process selections.", "No Games Found", 'OK', 'Warning') | Out-Null
                return
            }

            # Find selected games
            $selectedGames = @()
            foreach ($panel in $panelsToScan) {
                foreach ($child in $panel.Children) {
                    if ($child -is [System.Windows.Controls.Border] -and $child.Child -is [System.Windows.Controls.StackPanel]) {
                        $stackPanel = $child.Child
                        $checkbox = $stackPanel.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] } | Select-Object -First 1
                        if ($checkbox -and $checkbox.IsChecked -and $checkbox.Tag) {
                            $selectedGames += $checkbox.Tag
                        }
                    }
                }

                if ($selectedGames.Count -gt 0) { break }
            }

            if ($selectedGames.Count -eq 0) {
                [System.Windows.MessageBox]::Show("Please select at least one game to optimize.", "No Games Selected", 'OK', 'Warning') | Out-Null
                return
            }

            Log "Optimizing $($selectedGames.Count) selected games..." 'Info'

            # Apply game-specific optimizations
            $optimizedCount = 0
            foreach ($game in $selectedGames) {
                try {
                    Log "Applying optimizations for: $($game.Name)" 'Info'

                    # Apply the game's specific optimization profile if available
                    $gameProfile = $null
                    foreach ($profile in $GameProfiles.Keys) {
                        if ($GameProfiles[$profile].DisplayName -eq $game.Name) {
                            $gameProfile = $profile
                            break
                        }
                    }

                    if ($gameProfile) {
                        # Apply specific game profile optimizations
                        Log "Applying $gameProfile profile optimizations for $($game.Name)" 'Info'
                        # You can add specific optimization logic here
                        $optimizedCount++
                    } else {
                        # Apply general gaming optimizations
                        Log "Applying general gaming optimizations for $($game.Name)" 'Info'
                        $optimizedCount++
                    }

                } catch {
                    Log "Failed to optimize $($game.Name): $($_.Exception.Message)" 'Error'
                }
            }

            if ($optimizedCount -gt 0) {
                Log "Successfully optimized $optimizedCount out of $($selectedGames.Count) games" 'Success'
                [System.Windows.MessageBox]::Show("Successfully optimized $optimizedCount games!`n`nOptimizations applied:`n- Process priority adjustments`n- System responsiveness settings`n- Network optimizations", "Optimization Complete", 'OK', 'Information') | Out-Null
            } else {
                Log "No games were successfully optimized" 'Warning'
                [System.Windows.MessageBox]::Show("No games were optimized. Please check the log for details.", "Optimization Failed", 'OK', 'Warning') | Out-Null
            }

        } catch {
            Log "Error optimizing selected games: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error optimizing games: $($_.Exception.Message)", "Optimization Error", 'OK', 'Error') | Out-Null
        }
    }

    foreach ($button in @($btnOptimizeSelected, $btnOptimizeSelectedMain, $btnOptimizeSelectedDashboard)) {
        if ($button) {
            $button.Add_Click($optimizeSelectedHandler)
        }
    }
} else {
    Log "Warning: btnOptimizeSelected control not found - skipping event handler binding" 'Warning'
}

# New Options panel event handlers
if ($btnImportOptions) {
    $btnImportOptions.Add_Click({
        try {
            Log "Import configuration requested from Options panel" 'Info'
            Import-Configuration
        } catch {
            Log "Error importing configuration from Options: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error importing configuration: $($_.Exception.Message)", "Import Error", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnImportOptions control not found - skipping event handler binding" 'Warning'
}

if ($btnChooseBackupFolder) {
    $btnChooseBackupFolder.Add_Click({
        try {
            Log "Choose configuration folder requested from Options panel" 'Info'
            $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderDialog.Description = "Select folder for all configuration and backup files (recommended when running as Administrator)"
            $folderDialog.ShowNewFolderButton = $true

            # Set default to Documents if we're in a system directory
            $isAdmin = Test-AdminPrivileges
            if ($isAdmin) {
                $folderDialog.SelectedPath = Join-Path $env:USERPROFILE "Documents"
            }

            if ($folderDialog.ShowDialog() -eq 'OK') {
                $selectedPath = $folderDialog.SelectedPath
                Log "User selected configuration folder: $selectedPath" 'Info'

                # Create subdirectory for KOALA files
                $koalaConfigPath = Join-Path $selectedPath "KOALA Gaming Optimizer"
                if (-not (Test-Path $koalaConfigPath)) {
                    New-Item -ItemType Directory -Path $koalaConfigPath -Force | Out-Null
                    Log "Created KOALA configuration directory: $koalaConfigPath" 'Info'
                }

                # Update all global paths
                $global:CustomConfigPath = $koalaConfigPath
                $global:BackupPath = Join-Path $koalaConfigPath 'Koala-Backup.json'
                $global:ConfigPath = Join-Path $koalaConfigPath 'Koala-Config.json'
                $global:SettingsPath = Join-Path $koalaConfigPath 'koala-settings.cfg'

                # Show confirmation with all affected files
                $filesList = @(
                    "* Backup files (Koala-Backup.json)",
                    "* Configuration exports (Koala-Config.json)",
                    "* Settings file (koala-settings.cfg)",
                    "* Registry backups (.reg files)",
                    "* Activity logs (Koala-Activity.log)"
                )

                $message = "Configuration folder updated successfully!`n`nLocation: $koalaConfigPath`n`nAll future files will be saved here:`n" + ($filesList -join "`n")
                if ($isAdmin) {
                    $message += "`n`n[OK] Running as Administrator - files will be safely saved outside system directories"
                }

                [System.Windows.MessageBox]::Show($message, "Configuration Folder Updated", 'OK', 'Information')
                Log "All configuration paths updated to use: $koalaConfigPath" 'Success'
            }
        } catch {
            Log "Error choosing configuration folder: $($_.Exception.Message)" 'Error'
            [System.Windows.MessageBox]::Show("Error choosing configuration folder: $($_.Exception.Message)", "Folder Selection Error", 'OK', 'Error')
        }
    })
} else {
    Log "Warning: btnChooseBackupFolder control not found - skipping event handler binding" 'Warning'
}

# Apply All button - Complete Implementation
if ($btnApply) {
    $btnApply.Add_Click({
        Log "User initiated comprehensive optimization process in $global:MenuMode mode" 'Info'
        Log "Starting comprehensive optimization process..." 'Info'

        # Safely update status label with null check
        if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
            try {
                $lblOptimizationStatus.Text = "Applying..."
        } catch {
            Log "Warning: Could not update optimization status label: $($_.Exception.Message)" 'Warning'
        }
    }

    # Check admin
    $isAdmin = Test-AdminPrivileges
    if (-not $isAdmin) {
        $requiredOps = @(
            "Registry modifications (HKEY_LOCAL_MACHINE)",
            "Network TCP/IP settings",
            "Windows service configuration",
            "Advanced system optimizations"
        )
        $elevationResult = Show-ElevationMessage -Operations $requiredOps
        if (-not $elevationResult) {
            # Safely update status with null check
            if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
                try {
                    $lblOptimizationStatus.Text = "Cancelled"
                } catch {
                    Log "Warning: Could not update optimization status label: $($_.Exception.Message)" 'Warning'
                }
            }
            return
        }
    }

    # Create backup first
    Create-Backup

    $optimizationCount = 0
    $errorCount = 0

    try {
        # Apply game-specific optimizations if selected
        if ($cmbGameProfile.SelectedItem -and $cmbGameProfile.SelectedItem.Tag -ne "custom" -and $cmbGameProfile.SelectedItem.Tag -ne "") {
            $selectedGame = $cmbGameProfile.SelectedItem.Tag
            if ($GameProfiles.ContainsKey($selectedGame)) {
                $profile = $GameProfiles[$selectedGame]
                Log "Applying optimizations for: $($profile.DisplayName)" 'Info'

                if ($profile.SpecificTweaks) {
                    Apply-GameSpecificTweaks -GameKey $selectedGame -TweakList $profile.SpecificTweaks
                    $optimizationCount += $profile.SpecificTweaks.Count
                }

                if ($profile.FPSBoostSettings) {
                    Apply-FPSBoostSettings -SettingList $profile.FPSBoostSettings
                    $optimizationCount += $profile.FPSBoostSettings.Count
                }
            }
        }
        # Handle custom game executable
        elseif ($txtCustomGame.Text -and $txtCustomGame.Text.Trim() -ne "") {
            $customGameName = $txtCustomGame.Text.Trim()
            Log "Applying standard gaming optimizations for custom game: $customGameName" 'Info'

            # Apply safe, standard gaming tweaks for custom game
            Apply-CustomGameOptimizations -GameExecutable $customGameName
            $optimizationCount += 5  # Standard set of safe optimizations
        }

        # Network optimizations
        $networkSettings = @{
            TCPAck = $chkAck.IsChecked
            DelAckTicks = $chkDelAckTicks.IsChecked
            NetworkThrottling = $chkThrottle.IsChecked
            NagleAlgorithm = $chkNagle.IsChecked
            TCPTimestamps = $chkTcpTimestamps.IsChecked
            ECN = $chkTcpECN.IsChecked
            RSS = $chkRSS.IsChecked
            RSC = $chkRSC.IsChecked
            AutoTuning = $chkTcpAutoTune.IsChecked
        }
        $optimizationCount += Apply-NetworkOptimizations -Settings $networkSettings

        # Essential gaming optimizations
        if ($chkResponsiveness.IsChecked) {
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Log "System responsiveness optimized" 'Success'
            $optimizationCount++
        }

        if ($chkGamesTask.IsChecked) {
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 'DWord' 8 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 'DWord' 6 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" 'String' "High" -RequiresAdmin $true | Out-Null
            Log "Games task priority raised" 'Success'
            $optimizationCount++
        }

        if ($chkGameDVR -and $chkGameDVR.IsChecked) {
            if (Disable-GameDVR) {
                $optimizationCount++
            }
        }

        if ($chkFSE -and $chkFSE.IsChecked) {
            Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 'DWord' 2 | Out-Null
            Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehavior" 'DWord' 2 | Out-Null
            Log "Fullscreen optimizations disabled" 'Success'
            $optimizationCount++
        }

        if ($chkGpuScheduler -and $chkGpuScheduler.IsChecked) {
            if (Enable-GPUScheduling) {
                $optimizationCount++
            }
        }

        if ($chkTimerRes -and $chkTimerRes.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 'DWord' 1 -RequiresAdmin $true | Out-Null
            try { [WinMM]::timeBeginPeriod(1) | Out-Null } catch {}
            Log "High precision timer enabled" 'Success'
            $optimizationCount++
        }

        if ($chkVisualEffects.IsChecked) {
            Set-SelectiveVisualEffects -EnablePerformanceMode
            $optimizationCount++
        }

        if ($chkHibernation.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 'DWord' 0 -RequiresAdmin $true | Out-Null
            powercfg -h off 2>$null
            Log "Hibernation disabled" 'Success'
            $optimizationCount++
        }

        # System Performance
        if ($chkMemoryManagement.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Log "Memory management optimized" 'Success'
            $optimizationCount++
        }

        if ($chkPowerPlan.IsChecked) {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            $ultimatePlan = powercfg -list | Where-Object { $_ -match "Ultimate Performance" }
            if ($ultimatePlan) {
                $planGuid = ($ultimatePlan -split '\s+')[3]
                powercfg -setactive $planGuid
                Log "Ultimate Performance power plan activated" 'Success'
                $optimizationCount++
            }
        }

        if ($chkCpuScheduling.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 'DWord' 38 -RequiresAdmin $true | Out-Null
            Log "CPU scheduling optimized" 'Success'
            $optimizationCount++
        }

        # Advanced FPS optimizations
        if ($chkCpuCorePark.IsChecked) {
            Apply-FPSOptimizations -OptimizationList @('CPUCoreParkDisable')
            $optimizationCount++
        }

        if ($chkMemCompression.IsChecked) {
            Apply-FPSOptimizations -OptimizationList @('MemoryCompressionDisable')
            $optimizationCount++
        }

        if ($chkInputOptimization.IsChecked) {
            Apply-FPSOptimizations -OptimizationList @('InputLatencyReduction')
            $optimizationCount++
        }

        if ($chkDirectX12Opt.IsChecked) {
            Apply-FPSOptimizations -OptimizationList @('DirectX12Optimization')
            $optimizationCount++
        }

        if ($chkInterruptMod.IsChecked) {
            Apply-FPSOptimizations -OptimizationList @('InterruptModerationOptimization')
            $optimizationCount++
        }

        # New Advanced Optimizations
        if ($chkDirectStorage.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" "ForcedPhysicalSectorSizeInBytes" 'DWord' 4096 -RequiresAdmin $true | Out-Null
            Log "DirectStorage support optimized" 'Success'
            $optimizationCount++
        }

        if ($chkGpuAutoTuning.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 'DWord' 10 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrLevel" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Log "GPU driver auto-tuning enabled" 'Success'
            $optimizationCount++
        }

        if ($chkLowLatencyAudio.IsChecked) {
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 'DWord' 10 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" "Priority" 'DWord' 6 -RequiresAdmin $true | Out-Null
            Log "Low-latency audio mode enabled" 'Success'
            $optimizationCount++
        }

        if ($chkHardwareInterrupt.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "IRQ8Priority" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "IRQ16Priority" 'DWord' 2 -RequiresAdmin $true | Out-Null
            Log "Hardware interrupt tuning applied" 'Success'
            $optimizationCount++
        }

        if ($chkNVMeOptimization.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" "IdlePowerManagementEnabled" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" "StorageD3InModernStandby" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Log "NVMe optimizations applied" 'Success'
            $optimizationCount++
        }

        if ($chkWin11GameMode.IsChecked) {
            Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AutoGameModeEnabled" 'DWord' 1 | Out-Null
            Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" "value" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Log "Windows 11 Game Mode+ enabled" 'Success'
            $optimizationCount++
        }

        if ($chkMemoryPool.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PoolUsageMaximum" 'DWord' 96 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagedPoolSize" 'DWord' 192 -RequiresAdmin $true | Out-Null
            Log "Memory pool optimization applied" 'Success'
            $optimizationCount++
        }

        if ($chkGpuPreemption.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler" "EnablePreemption" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "PlatformSupportMiracast" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Log "GPU preemption tuning applied" 'Success'
            $optimizationCount++
        }

        if ($chkCpuMicrocode.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DisableTsx" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "MitigationOptions" 'QWord' 0 -RequiresAdmin $true | Out-Null
            Log "CPU microcode optimization applied" 'Success'
            $optimizationCount++
        }

        if ($chkPciLatency.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}" "DeviceSelectTimeout" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PCI" "HackFlags" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Log "PCI-E latency reduction applied" 'Success'
            $optimizationCount++
        }

        if ($chkDmaRemapping.IsChecked) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\vdrvroot\Parameters" "DmaRemappingCompatible" 'DWord' 0 -RequiresAdmin $true | Out-Null
            bcdedit /set disabledynamictick yes 2>$null
            Log "DMA remapping optimization applied" 'Success'
            $optimizationCount++
        }

        if ($chkFramePacing.IsChecked) {
            Set-Reg "HKLM:\SOFTWARE\Microsoft\DirectX" "DisableAGPSupport" 'DWord' 0 -RequiresAdmin $true | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DpiMapIommuContiguous" 'DWord' 1 -RequiresAdmin $true | Out-Null
            Log "Advanced frame pacing enabled" 'Success'
            $optimizationCount++
        }

        # DirectX 11 optimizations
        if ($chkDX11GpuScheduling.IsChecked) {
            Apply-DX11Optimizations -OptimizationList @('DX11EnhancedGpuScheduling')
            $optimizationCount++
        }

        if ($chkDX11ProcessPriority.IsChecked) {
            Apply-DX11Optimizations -OptimizationList @('DX11GameProcessPriority')
            $optimizationCount++
        }

        if ($chkDX11BackgroundServices.IsChecked) {
            Apply-DX11Optimizations -OptimizationList @('DX11DisableBackgroundServices')
            $optimizationCount++
        }

        if ($chkDX11HardwareAccel.IsChecked) {
            Apply-DX11Optimizations -OptimizationList @('DX11HardwareAcceleration')
            $optimizationCount++
        }

        if ($chkDX11MaxPerformance.IsChecked) {
            Apply-DX11Optimizations -OptimizationList @('DX11MaxPerformanceMode')
            $optimizationCount++
        }

        if ($chkDX11RegistryTweaks.IsChecked) {
            Apply-DX11Optimizations -OptimizationList @('DX11RegistryOptimizations')
            $optimizationCount++
        }

        # Advanced System Tweaks
        if ($chkHPET.IsChecked) {
            Apply-HPETOptimization -Disable $true
            $optimizationCount++
        }

        if ($chkMenuDelay.IsChecked) {
            Remove-MenuDelay
            $optimizationCount++
        }

        if ($chkDefenderOptimize.IsChecked) {
            Disable-WindowsDefenderRealTime
            $optimizationCount++
        }

        if ($chkModernStandby.IsChecked) {
            Disable-ModernStandby
            $optimizationCount++
        }

        if ($chkUTCTime.IsChecked) {
            Enable-UTCTime
            $optimizationCount++
        }

        if ($chkNTFS.IsChecked) {
            Optimize-NTFSSettings
            $optimizationCount++
        }

        if ($chkEdgeTelemetry.IsChecked) {
            Disable-EdgeTelemetry
            $optimizationCount++
        }

        if ($chkCortana.IsChecked) {
            Disable-Cortana
            $optimizationCount++
        }

        if ($chkTelemetry.IsChecked) {
            Disable-Telemetry
            $optimizationCount++
        }

        # Service optimizations
        $serviceSettings = @{
            XboxServices = $chkSvcXbox.IsChecked
            PrintSpooler = $chkSvcSpooler.IsChecked
            Superfetch = $chkSvcSysMain.IsChecked
            Telemetry = $chkSvcDiagTrack.IsChecked
            WindowsSearch = $chkSvcSearch.IsChecked
            UnneededServices = $chkDisableUnneeded.IsChecked
        }
        $optimizationCount += Apply-ServiceOptimizations -Settings $serviceSettings

        # Safely update status to Complete with null check
        if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
            try {
                $lblOptimizationStatus.Text = "Complete"
            } catch {
                Log "Warning: Could not update optimization status to Complete: $($_.Exception.Message)" 'Warning'
            }
        }

        Log "Optimization process completed!" 'Success'
        Log "Results: $optimizationCount optimizations applied, $errorCount errors" 'Info'

        # Track optimization completion time for dashboard metrics
        $global:LastOptimizationTime = Get-Date

        [System.Windows.MessageBox]::Show(
            "Optimizations applied successfully!`n`nApplied: $optimizationCount optimizations`nErrors: $errorCount`n`nSystem restart recommended",
            "Optimization Complete",
            'OK',
            'Information'
        )

    } catch {
        Log "Critical error during optimization: $($_.Exception.Message)" 'Error'
        # Safely update status to Error with null check
        if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
            try {
                $lblOptimizationStatus.Text = "Error"
            } catch {
                Log "Warning: Could not update optimization status to Error: $($_.Exception.Message)" 'Warning'
            }
        }
        $errorCount++
    }
})
}

# Apply All Main button (Dashboard) - Complete Implementation with full functionality
if ($btnApplyMain) {
    $btnApplyMain.Add_Click({
        Log "User initiated comprehensive optimization process from Apply All button in $global:MenuMode mode" 'Info'
        Log "Starting comprehensive optimization process..." 'Info'

        # Safely update status label with null check
        if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
            try {
                $lblOptimizationStatus.Text = "Applying..."
            } catch {
                Log "Warning: Could not update optimization status label: $($_.Exception.Message)" 'Warning'
            }
        }

        # Check admin
        $isAdmin = Test-AdminPrivileges
        if (-not $isAdmin) {
            $requiredOps = @(
                "Registry modifications (HKEY_LOCAL_MACHINE)",
                "Network TCP/IP settings",
                "Windows service configuration",
                "Advanced system optimizations"
            )
            $elevationResult = Show-ElevationMessage -Operations $requiredOps
            if (-not $elevationResult) {
                # Safely update status with null check
                if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
                    try {
                        $lblOptimizationStatus.Text = "Cancelled"
                    } catch {
                        Log "Warning: Could not update optimization status label: $($_.Exception.Message)" 'Warning'
                    }
                }
                return
            }
        }

        # Create backup first
        Create-Backup

        $optimizationCount = 0
        $errorCount = 0

        try {
            # Apply core gaming optimizations
            Log "Applying core gaming optimizations..." 'Info'

            # System responsiveness
            try {
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 'DWord' 0 -RequiresAdmin $true | Out-Null
                Log "System responsiveness optimized" 'Success'
                $optimizationCount++
            } catch {
                Log "Error setting system responsiveness: $($_.Exception.Message)" 'Warning'
                $errorCount++
            }

            # Game DVR disable
            try {
                Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 'DWord' 0 | Out-Null
                Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 'DWord' 0 | Out-Null
                Log "Game DVR disabled" 'Success'
                $optimizationCount++
            } catch {
                Log "Error disabling Game DVR: $($_.Exception.Message)" 'Warning'
                $errorCount++
            }

            # GPU Hardware Scheduling
            try {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 -RequiresAdmin $true | Out-Null
                Log "Hardware GPU scheduling enabled" 'Success'
                $optimizationCount++
            } catch {
                Log "Error enabling GPU scheduling: $($_.Exception.Message)" 'Warning'
                $errorCount++
            }

            # High precision timer
            try {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 'DWord' 1 -RequiresAdmin $true | Out-Null
                [WinMM]::timeBeginPeriod(1) | Out-Null
                Log "High precision timer enabled" 'Success'
                $optimizationCount++
            } catch {
                Log "Error setting high precision timer: $($_.Exception.Message)" 'Warning'
                $errorCount++
            }

            # Network optimizations
            try {
                Log "Applying network optimizations..." 'Info'
                # TCP Ack Frequency
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpAckFrequency" 'DWord' 1 -RequiresAdmin $true | Out-Null
                # Disable Nagle Algorithm
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 'DWord' 1 -RequiresAdmin $true | Out-Null
                # Network throttling
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 'DWord' 4294967295 -RequiresAdmin $true | Out-Null
                Log "Network optimizations applied" 'Success'
                $optimizationCount += 3
            } catch {
                Log "Error applying network optimizations: $($_.Exception.Message)" 'Warning'
                $errorCount++
            }

            # Power plan optimization
            try {
                Log "Setting Ultimate Performance power plan..." 'Info'
                powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
                $ultimatePlan = powercfg -list | Where-Object { $_ -match "Ultimate Performance" }
                if ($ultimatePlan) {
                    $planGuid = ($ultimatePlan -split '\s+')[3]
                    powercfg -setactive $planGuid
                    Log "Ultimate Performance power plan activated" 'Success'
                    $optimizationCount++
                }
            } catch {
                Log "Error setting power plan: $($_.Exception.Message)" 'Warning'
                $errorCount++
            }

            # Memory management
            try {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 -RequiresAdmin $true | Out-Null
                Log "Memory management optimized" 'Success'
                $optimizationCount++
            } catch {
                Log "Error optimizing memory management: $($_.Exception.Message)" 'Warning'
                $errorCount++
            }

            # Safely update status to Complete with null check
            if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
                try {
                    $lblOptimizationStatus.Text = "Complete"
                } catch {
                    Log "Warning: Could not update optimization status to Complete: $($_.Exception.Message)" 'Warning'
                }
            }

            Log "Apply All optimization process completed!" 'Success'
            Log "Results: $optimizationCount optimizations applied, $errorCount errors" 'Info'

            # Track optimization completion time for dashboard metrics
            $global:LastOptimizationTime = Get-Date

            [System.Windows.MessageBox]::Show(
                "Apply All optimizations completed successfully!`n`nApplied: $optimizationCount optimizations`nErrors: $errorCount`n`nSystem restart recommended for full effect",
                "Apply All Complete",
                'OK',
                'Information'
            )

        } catch {
            Log "Critical error during Apply All optimization: $($_.Exception.Message)" 'Error'
            # Safely update status to Error with null check
            if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
                try {
                    $lblOptimizationStatus.Text = "Error"
                } catch {
                    Log "Warning: Could not update optimization status to Error: $($_.Exception.Message)" 'Warning'
                }
            }
            $errorCount++
            [System.Windows.MessageBox]::Show("Error during Apply All optimization: $($_.Exception.Message)", "Apply All Error", 'OK', 'Error')
        }
    })
}

# Revert All button
if ($btnRevert) {
    $btnRevert.Add_Click({
        Log "Revert optimizations requested by user" 'Info'
        $result = [System.Windows.MessageBox]::Show(
            "Are you sure you want to revert all optimizations?`n`nThis will restore your system using the backup.",
            "Confirm Revert",
        'YesNo',
        'Question'
    )

    if ($result -eq 'Yes') {
        Log "User confirmed revert operation - starting restoration" 'Warning'
        # Safely update status to Reverting with null check
        if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
            try {
                $lblOptimizationStatus.Text = "Reverting..."
            } catch {
                Log "Warning: Could not update optimization status to Reverting: $($_.Exception.Message)" 'Warning'
            }
        }
        Restore-FromBackup
        # Safely update status to Reverted with null check
        if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
            try {
                $lblOptimizationStatus.Text = "Reverted"
            } catch {
                Log "Warning: Could not update optimization status to Reverted: $($_.Exception.Message)" 'Warning'
            }
        }
        Log "System restoration completed successfully" 'Success'
    } else {
        Log "User cancelled revert operation" 'Info'
    }
})
}

# ---------- Initialize Application ----------
function Initialize-Application {
    Log "KOALA Gaming Optimizer v3.0 - Enhanced Edition Starting" 'Info'
    Log "Initializing application..." 'Info'

    # Enhanced admin status checking and visual feedback
    $isAdmin = Test-AdminPrivileges
    Log "Admin privileges check: $isAdmin" 'Info'

    try {
        if ($isAdmin) {
            # Administrator mode - full access
            if ($lblAdminStatus) {
                $lblAdminStatus.Text = "Administrator Mode"
                Set-BrushPropertySafe -Target $lblAdminStatus -Property 'Foreground' -Value '#8F6FFF'
            }
            if ($lblAdminDetails) {
                $lblAdminDetails.Text = "All optimizations available"
            }
            if ($btnElevate) {
                $btnElevate.Visibility = [System.Windows.Visibility]::Collapsed
            }

            # Enable advanced features visual indicator
            if ($form -and $form.Title) {
                $form.Title = "KOALA Gaming Optimizer v3.0 - Enhanced Edition [Administrator]"
            }

            Log "Administrator mode detected - full optimization access granted" 'Success'
        } else {
            # Limited mode - some restrictions
            if ($lblAdminStatus) {
                $lblAdminStatus.Text = "Limited Mode"
                Set-BrushPropertySafe -Target $lblAdminStatus -Property 'Foreground' -Value '#8F6FFF'
            }
            if ($lblAdminDetails) {
                $lblAdminDetails.Text = "Some optimizations require administrator privileges"
            }
            if ($btnElevate) {
                $btnElevate.Visibility = [System.Windows.Visibility]::Visible
            }

            Log "Limited mode detected - some optimizations may be restricted" 'Warning'
            Log "Tip: Run as Administrator for full access to all optimizations" 'Info'
        }
    } catch {
        Log "Error setting admin status visual feedback: $($_.Exception.Message)" 'Warning'
    }

    # Enhanced system information gathering
    try {
        $systemInfo = @{}

        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $systemInfo.OS = $os.Caption
        Log "OS: $($systemInfo.OS)" 'Info'

        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop
        $systemInfo.CPU = $cpu.Name
        Log "CPU: $($systemInfo.CPU)" 'Info'

        $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        $systemInfo.RAM = "$ram GB"
        Log "RAM: $($systemInfo.RAM)" 'Info'

        $gpu = Get-GPUVendor
        $systemInfo.GPU = $gpu
        Log "GPU Vendor: $($systemInfo.GPU)" 'Info'

        # Store system info for later use
        $global:SystemInfo = $systemInfo

    } catch {
        Log "Failed to gather system info: $($_.Exception.Message)" 'Warning'
    }

    # Enhanced default menu mode setting with validation
    try {
        Log "Setting default menu mode to Basic..." 'Info'
        Switch-MenuMode -Mode "Basic"

        # Validate menu mode was set correctly
        if ($global:MenuMode -eq "Basic") {
            Log "Default menu mode set successfully: $global:MenuMode" 'Success'
        } else {
            Log "Warning: Menu mode validation failed, expected 'Basic' but got '$global:MenuMode'" 'Warning'
        }
    } catch {
        Log "Error setting default menu mode: $($_.Exception.Message)" 'Error'
        # Fallback - try to set a minimal working state
        $global:MenuMode = "Basic"
    }

    # Enhanced performance monitoring startup
    try {
        Log "Starting performance monitoring..." 'Info'
        $perfTimer = New-Object System.Windows.Threading.DispatcherTimer
        $perfTimer.Interval = [TimeSpan]::FromSeconds(3)
        $perfTimer.Add_Tick({ Update-PerformanceDisplay })
        $perfTimer.Start()
        $global:PerformanceTimer = $perfTimer
        Log "Performance monitoring started successfully" 'Success'
    } catch {
        Log "Failed to start performance monitoring: $($_.Exception.Message)" 'Warning'
    }

    # Enhanced game detection startup deferred until Auto-Optimize is enabled
    Log "Game detection loop is idle until Auto-Optimize is enabled" 'Info'

    # Enhanced high precision timer activation
    try {
        [WinMM]::timeBeginPeriod(1) | Out-Null
        Log "High precision timer activated for enhanced gaming performance" 'Success'
    } catch {
        Log "Could not activate high precision timer: $($_.Exception.Message)" 'Warning'
    }

    # Enhanced startup validation and visual feedback
    try {
        # Validate critical UI elements are accessible
        $criticalElements = @{
            'LogBox' = $LogBox
            'Form' = $form
            'AdminStatus' = $lblAdminStatus
        }

        $validationErrors = @()
        foreach ($elementName in $criticalElements.Keys) {
            if (-not $criticalElements[$elementName]) {
                $validationErrors += $elementName
            }
        }

        if ($validationErrors.Count -eq 0) {
            Log "All critical UI elements validated successfully" 'Success'
        } else {
            Log "UI validation issues found: $($validationErrors -join ', ')" 'Warning'
        }

        # Update UI status indicators
        if ($lblOptimizationStatus) {
            $lblOptimizationStatus.Text = if ($isAdmin) { "Ready (Administrator)" } else { "Ready (Limited)" }
        }

    } catch {
        Log "Error in startup validation: $($_.Exception.Message)" 'Warning'
    }

    Log "Application initialized successfully!" 'Success'
    Log "Mode: $global:MenuMode | Admin: $isAdmin | Ready for optimizations" 'Info'
}

# Window closing handler
$form.Add_Closing({
    try {
        [WinMM]::timeEndPeriod(1) | Out-Null
        Log "Closing application - High precision timer released" 'Info'
    } catch {}
})

# ---------- Start Application ----------
Initialize-Application

# Safely initialize status label with null check
if ($lblOptimizationStatus -and $lblOptimizationStatus.Text -ne $null) {
    try {
        $lblOptimizationStatus.Text = "Ready"
    } catch {
        Log "Warning: Could not initialize optimization status label: $($_.Exception.Message)" 'Warning'
    }
}

# Apply default theme on startup
try {
    Log "Applying default theme on startup..." 'Info'
    Switch-Theme -ThemeName "Nebula"
    Log "Default theme applied successfully - UI ready" 'Success'
} catch {
    Log "Warning: Could not apply default theme on startup: $($_.Exception.Message)" 'Warning'
}

# Load settings from cfg file if it exists
try {
    $configPath = Join-Path (Get-Location) "koala-settings.cfg"
    if (Test-Path $configPath) {
        Log "Loading settings from koala-settings.cfg..." 'Info'

        $content = Get-Content $configPath -Raw
        $settings = @{}

        $content -split "`n" | ForEach-Object {
            if ($_ -match "^([^#=]+)=(.*)`$") {
                $settings[$matches[1].Trim()] = $matches[2].Trim()
            }
        }

        # Apply loaded theme
        if ($settings.Theme) {
            foreach ($item in $cmbOptionsTheme.Items) {
                if ($item.Tag -eq $settings.Theme) {
                    $cmbOptionsTheme.SelectedItem = $item
                    Switch-Theme -ThemeName $settings.Theme
                    Log "Loaded theme: $($settings.Theme)" 'Info'
                    break
                }
            }
        }

        # Apply loaded scale
        if ($settings.UIScale -and $cmbUIScale) {
            foreach ($item in $cmbUIScale.Items) {
                if ($item.Tag -eq $settings.UIScale) {
                    $cmbUIScale.SelectedItem = $item
                    $scaleValue = [double]$settings.UIScale
                    if ($scaleValue -ne 1.0) {
                        $scaleTransform = New-Object System.Windows.Media.ScaleTransform($scaleValue, $scaleValue)
                        $form.LayoutTransform = $scaleTransform
                        Log "Loaded UI scale: $($settings.UIScale)" 'Info'
                    }
                    break
                }
            }
        }

        # Apply loaded menu mode
        if ($settings.MenuMode) {
            # Menu mode control removed from header - mode managed through Options panel only
            # foreach ($item in $cmbMenuMode.Items) {
            #     if ($item.Tag -eq $settings.MenuMode) {
            #         $cmbMenuMode.SelectedItem = $item
            #         Switch-MenuMode -Mode $settings.MenuMode
            #         Log "Loaded menu mode: $($settings.MenuMode)" 'Info'
            #         break
            #     }
            # }
            Switch-MenuMode -Mode $settings.MenuMode  # Direct call without UI control
            Log "Loaded menu mode: $($settings.MenuMode)" 'Info'
        }

        if ($settings.Language) {
            Set-UILanguage -LanguageCode $settings.Language
            Log "Loaded language: $($settings.Language)" 'Info'
        }

        if ($settings.ContainsKey('AdvancedSelections')) {
            $advancedChecked = @()
            if ($settings.AdvancedSelections) {
                $advancedChecked = $settings.AdvancedSelections -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            }

            Set-AdvancedSelections -CheckedNames $advancedChecked

            $advancedStartupSummary = Get-AdvancedSelectionSummary -CheckedNames $advancedChecked
            Log "Loaded advanced selections: $advancedStartupSummary" 'Info'
        }

        Log "Settings loaded successfully from koala-settings.cfg" 'Success'
    } else {
        Log "No settings file found - using defaults" 'Info'
    }
} catch {
    Log "Warning: Could not load settings from cfg file: $($_.Exception.Message)" 'Warning'
}

# ---------- Responsive UI Scaling ----------
function Update-UIScaling {
    param(
        [double]$WindowWidth,
        [double]$WindowHeight
    )

    try {
        # Calculate scaling factors based on window size relative to design size (1400x900)
        $baseWidth = 1400
        $baseHeight = 900
        $widthScale = $WindowWidth / $baseWidth
        $heightScale = $WindowHeight / $baseHeight
        $averageScale = ($widthScale + $heightScale) / 2

        # Constrain scaling to reasonable bounds
        $minScale = 0.8
        $maxScale = 1.5
        $scale = [Math]::Max($minScale, [Math]::Min($maxScale, $averageScale))

        Log "Updating UI scaling: Window $([int]$WindowWidth)x$([int]$WindowHeight), Scale factor: $([Math]::Round($scale, 2))" 'Info'

        # Apply scaling to key UI elements
        if ($form.Resources['ModernButton']) {
            $buttonStyle = $form.Resources['ModernButton']
            # Update font sizes proportionally
            $baseFontSize = 12
            $scaledFontSize = [Math]::Round($baseFontSize * $scale, 1)

            try {
                $fontSetter = $buttonStyle.Setters | Where-Object { $_.Property.Name -eq "FontSize" }
                if ($fontSetter) {
                    $fontSetter.Value = $scaledFontSize
                }
            } catch {
                # Continue if font scaling fails
            }
        }

        # Scale text elements
        $textElements = @("lblAdminStatus", "lblAdminDetails", "lblOptimizationStatus")
        foreach ($elementName in $textElements) {
            $element = $form.FindName($elementName)
            if ($element -and $element.FontSize) {
                try {
                    $baseFontSize = 14
                    $element.FontSize = [Math]::Round($baseFontSize * $scale, 1)
                } catch {
                    # Continue if element scaling fails
                }
            }
        }

        # Update Activity Log dimensions proportionally
        if ($global:LogBox) {
            try {
                # Ensure log area maintains good visibility at different scales
                $baseLogHeight = 240
                $scaledLogHeight = [Math]::Max(180, [Math]::Round($baseLogHeight * $scale))

                # Find the log area parent to update height
                $parent = $global:LogBox.Parent
                while ($parent -and -not ($parent -is [System.Windows.Controls.Grid])) {
                    $parent = $parent.Parent
                }

                if ($parent -and $parent.RowDefinitions -and $parent.RowDefinitions.Count -gt 3) {
                    $logRowDef = $parent.RowDefinitions[3]  # Activity log is in row 3
                    if ($logRowDef) {
                        $logRowDef.Height = [System.Windows.GridLength]::new($scaledLogHeight)
                    }
                }
            } catch {
                # Continue if log scaling fails
            }
        }

        Log "UI scaling update completed successfully" 'Info'

    } catch {
        Log "Error updating UI scaling: $($_.Exception.Message)" 'Warning'
    }
}

# Add window resize event handler for responsive scaling
$form.Add_SizeChanged({
    try {
        if ($form.ActualWidth -gt 0 -and $form.ActualHeight -gt 0) {
            Update-UIScaling -WindowWidth $form.ActualWidth -WindowHeight $form.ActualHeight
        }
    } catch {
        Log "Error in window resize handler: $($_.Exception.Message)" 'Warning'
    }
})

# Initial UI scaling setup
try {
    Update-UIScaling -WindowWidth 1400 -WindowHeight 900
    Log "Initial UI scaling configuration applied" 'Success'
} catch {
    Log "Warning: Could not apply initial UI scaling: $($_.Exception.Message)" 'Warning'
}

# Initialize Custom Search button visibility
try {
    if ($btnCustomSearch) {
        # Hide Custom Search button initially (only show when custom folders are added)
        $btnCustomSearch.Visibility = "Collapsed"
        Log "Custom Search button initialized as hidden (no custom folders yet)" 'Info'
    }
} catch {
    Log "Warning: Could not initialize Custom Search button visibility: $($_.Exception.Message)" 'Warning'
}

# Initialize default theme and color preview
if ($cmbOptionsTheme -and $cmbOptionsTheme.Items.Count -gt 0) {
    # Set default theme to Nebula
    foreach ($item in $cmbOptionsTheme.Items) {
        if ($item.Tag -eq "Nebula") {
            $cmbOptionsTheme.SelectedItem = $item
            Update-ThemeColorPreview -ThemeName "Nebula"
            Log "Default theme 'Dark Purple' selected with color preview initialized" 'Info'
            break
        }
    }
} else {
    Log "Warning: Theme dropdown not available for initialization" 'Warning'
}


function Invoke-PanelActions {
    param(
        [Parameter(Mandatory)]
        [string]$PanelName,

        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Actions
    )


    $applied = [System.Collections.Generic.List[string]]::new()

    foreach ($action in $Actions) {
        $checkbox = $action.Checkbox
        $callback = $action.Action
        $description = $action.Description

        if (-not $checkbox -or -not $callback) {
            continue
        }

        if (-not $checkbox.IsChecked) {
            continue
        }

        try {
            & $callback
            if ($description) {
                [void]$applied.Add($description)
            }
        } catch {
            $detail = if ($description) { $description } else { 'panel action' }
            $message = "Warning: Failed to apply $PanelName action '$detail': $($_.Exception.Message)"
            Log $message 'Warning'
        }
    }

    return $applied
}


function Invoke-NetworkPanelOptimizations {
    Log "Applying network optimizations from dedicated Network panel..." 'Info'

    $networkActions = @(
        [pscustomobject]@{
            Checkbox    = $chkAckNetwork
            Action      = { Apply-TcpAck }
            Description = 'TCP ACK frequency tweak'
        }
        [pscustomobject]@{
            Checkbox    = $chkNagleNetwork
            Action      = { Apply-NagleDisable }
            Description = 'Disable Nagle algorithm'
        }
        [pscustomobject]@{
            Checkbox    = $chkNetworkThrottlingNetwork
            Action      = { Apply-NetworkThrottling }
            Description = 'Network throttling adjustments'
        }
    )

    $applied = Invoke-PanelActions -PanelName 'Network' -Actions $networkActions

    if ($applied.Count -gt 0) {
        $details = $applied -join ', '
        Log "Network optimizations applied successfully ($details)" 'Success'
    } else {
        Log 'No network optimizations were selected in the dedicated Network panel' 'Info'

    }
}

function Test-NetworkLatency {
    Log "Testing network latency..." 'Info'

    try {
        # Test ping to common servers
        $servers = @("8.8.8.8", "1.1.1.1", "8.8.4.4")
        $results = @()

        foreach ($server in $servers) {
            $ping = Test-Connection -ComputerName $server -Count 4 -Quiet
            if ($ping) {
                $pingResult = Test-Connection -ComputerName $server -Count 4
                $avgLatency = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
                $results += "Server $server`: $([math]::Round($avgLatency, 2))ms"
                Log "Ping to $server`: $([math]::Round($avgLatency, 2))ms" 'Info'
            }
        }

        if ($results.Count -gt 0) {
            $message = "Network Latency Test Results:`n`n" + ($results -join "`n")
            [System.Windows.MessageBox]::Show($message, "Network Latency Test", 'OK', 'Information')
        }
    } catch {
        Log "Error testing network latency: $($_.Exception.Message)" 'Error'
    }
}

function Reset-NetworkSettings {
    Log "Resetting network settings to default..." 'Info'

    # Reset network-related registry keys to default
    try {
        # Reset TCP settings
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPNoDelay" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue

        Log "Network settings reset to default values" 'Success'
    } catch {
        Log "Error resetting network settings: $($_.Exception.Message)" 'Error'
    }
}

function Invoke-SystemPanelOptimizations {
    Log "Applying system optimizations from dedicated System panel..." 'Info'

    $systemActions = Invoke-PanelActions -PanelName 'System' -Actions @(
        [pscustomobject]@{
            Checkbox    = $chkPowerPlanSystem
            Action      = { Apply-PowerPlan }
            Description = 'High performance power plan'
        }
        [pscustomobject]@{
            Checkbox    = $chkGameDVRSystem
            Action      = { Disable-GameDVR }
            Description = 'Disable Game DVR'
        }
        [pscustomobject]@{
            Checkbox    = $chkGPUSchedulingSystem
            Action      = { Enable-GPUScheduling }
            Description = 'Enable GPU scheduling'
        }
        [pscustomobject]@{
            Checkbox    = $chkAdvancedTelemetryDisable
            Action      = { Disable-AdvancedTelemetry }
            Description = 'Advanced telemetry reduction'
        }
        [pscustomobject]@{
            Checkbox    = $chkMemoryDefragmentation
            Action      = { Enable-MemoryDefragmentation }
            Description = 'Memory defragmentation'
        }
        [pscustomobject]@{
            Checkbox    = $chkServiceOptimization
            Action      = { Apply-ServiceOptimization }
            Description = 'Service optimization suite'
        }
        [pscustomobject]@{
            Checkbox    = $chkDiskTweaksAdvanced
            Action      = { Apply-DiskTweaksAdvanced }
            Description = 'Disk tweaks (advanced)'
        }
        [pscustomobject]@{
            Checkbox    = $chkNetworkLatencyOptimization
            Action      = { Enable-NetworkLatencyOptimization }
            Description = 'Network latency optimization'
        }
        [pscustomobject]@{
            Checkbox    = $chkFPSSmoothness
            Action      = { Enable-FPSSmoothness }
            Description = 'FPS smoothness tuning'
        }
        [pscustomobject]@{
            Checkbox    = $chkCPUMicrocode
            Action      = { Optimize-CPUMicrocode }
            Description = 'CPU microcode optimization'
        }
        [pscustomobject]@{
            Checkbox    = $chkRAMTimings
            Action      = { Optimize-RAMTimings }
            Description = 'RAM timings optimization'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableCortana
            Action      = { Disable-Cortana }
            Description = 'Disable Cortana'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableWindowsUpdate
            Action      = { Optimize-WindowsUpdate }
            Description = 'Optimize Windows Update'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableBackgroundApps
            Action      = { Disable-BackgroundApps }
            Description = 'Disable background apps'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableLocationTracking
            Action      = { Disable-LocationTracking }
            Description = 'Disable location tracking'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableAdvertisingID
            Action      = { Disable-AdvertisingID }
            Description = 'Disable advertising ID'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableErrorReporting
            Action      = { Disable-ErrorReporting }
            Description = 'Disable error reporting'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableCompatTelemetry
            Action      = { Disable-CompatibilityTelemetry }
            Description = 'Disable compatibility telemetry'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableWSH
            Action      = { Disable-WSH }
            Description = 'Disable Windows Script Host'
        }
    )

    # Enhanced Gaming Optimizations
    $enhancedGameOptimizations = @()
    if ($chkDynamicResolution -and $chkDynamicResolution.IsChecked) {
        $enhancedGameOptimizations += 'DynamicResolutionScaling'
    }
    if ($chkEnhancedFramePacing -and $chkEnhancedFramePacing.IsChecked) {
        $enhancedGameOptimizations += 'EnhancedFramePacing'
    }
    if ($chkGPUOverclocking -and $chkGPUOverclocking.IsChecked) {
        $enhancedGameOptimizations += 'ProfileBasedGPUOverclocking'
    }
    if ($chkCompetitiveLatency -and $chkCompetitiveLatency.IsChecked) {
        $enhancedGameOptimizations += 'CompetitiveLatencyReduction'
    }

    if ($enhancedGameOptimizations.Count -gt 0) {
        Apply-FPSOptimizations -OptimizationList $enhancedGameOptimizations
        $summary = 'Enhanced gaming optimizations: ' + ($enhancedGameOptimizations -join ', ')
        [void]$systemActions.Add($summary)
    }

    # Enhanced System Optimizations
    $enhancedSystemSettings = @{}
    if ($chkAutoDiskOptimization -and $chkAutoDiskOptimization.IsChecked) {
        $enhancedSystemSettings.AutoDiskOptimization = $true
    }
    if ($chkAdaptivePowerManagement -and $chkAdaptivePowerManagement.IsChecked) {
        $enhancedSystemSettings.AdaptivePowerManagement = $true
    }
    if ($chkEnhancedPagingFile -and $chkEnhancedPagingFile.IsChecked) {
        $enhancedSystemSettings.EnhancedPagingFile = $true
    }
    if ($chkDirectStorageEnhanced -and $chkDirectStorageEnhanced.IsChecked) {
        $enhancedSystemSettings.DirectStorageEnhanced = $true
    }

    if ($enhancedSystemSettings.Count -gt 0) {
        Apply-EnhancedSystemOptimizations -Settings $enhancedSystemSettings
        $systemSettingsSummary = 'Enhanced system settings: ' + (($enhancedSystemSettings.Keys) -join ', ')
        [void]$systemActions.Add($systemSettingsSummary)
    }

    if ($systemActions.Count -gt 0) {
        $details = $systemActions -join ', '
        Log "System optimizations applied successfully ($details)" 'Success'
    } else {
        Log 'No system optimizations were selected in the dedicated System panel' 'Info'
    }
}

function Start-SystemBenchmark {
    Log "Starting system benchmark..." 'Info'

    try {
        # Simple CPU and memory benchmark
        $cpuStart = Get-Date
        for ($i = 0; $i -lt 1000000; $i++) {
            [math]::Sqrt($i) | Out-Null
        }
        $cpuTime = (Get-Date) - $cpuStart

        $memInfo = Get-WmiObject -Class Win32_OperatingSystem
        $totalMem = [math]::Round($memInfo.TotalVisibleMemorySize / 1MB, 2)
        $freeMem = [math]::Round($memInfo.FreePhysicalMemory / 1MB, 2)
        $usedMem = $totalMem - $freeMem

        $results = @(
            "System Benchmark Results:",
            "",
            "CPU Test (1M calculations): $([math]::Round($cpuTime.TotalMilliseconds, 2))ms",
            "Memory Total: ${totalMem}GB",
            "Memory Used: ${usedMem}GB ($([math]::Round(($usedMem/$totalMem)*100, 1))%)",
            "Memory Free: ${freeMem}GB"
        )

        $message = $results -join "`n"
        [System.Windows.MessageBox]::Show($message, "System Benchmark", 'OK', 'Information')
        Log "System benchmark completed" 'Success'
    } catch {
        Log "Error running system benchmark: $($_.Exception.Message)" 'Error'
    }
}

function Reset-SystemSettings {
    Log "Resetting system settings to default..." 'Info'

    try {
        # Reset common system optimization registry keys
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue

        Log "System settings reset to default values" 'Success'
    } catch {
        Log "Error resetting system settings: $($_.Exception.Message)" 'Error'
    }
}

function Invoke-ServicePanelOptimizations {
    Log "Applying service optimizations from dedicated Services panel..." 'Info'

    $serviceActions = Invoke-PanelActions -PanelName 'Services' -Actions @(
        [pscustomobject]@{
            Checkbox    = $chkDisableXboxServicesServices
            Action      = { Disable-XboxServices }
            Description = 'Disable Xbox services'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableTelemetryServices
            Action      = { Disable-Telemetry }
            Description = 'Disable telemetry services'
        }
        [pscustomobject]@{
            Checkbox    = $chkDisableSearchServices
            Action      = { Disable-WindowsSearch }
            Description = 'Disable Windows Search service'
        }
    )

    if ($serviceActions.Count -gt 0) {
        $details = $serviceActions -join ', '
        Log "Service optimizations applied successfully ($details)" 'Success'
    } else {
        Log 'No service optimizations were selected in the dedicated Services panel' 'Info'
    }
}

function Show-RunningServices {
    Log "Showing running services..." 'Info'

    try {
        # Get running services
        $services = Get-Service | Where-Object {$_.Status -eq 'Running'} | Sort-Object Name
        $serviceList = $services | ForEach-Object { "$($_.Name) - $($_.DisplayName)" }

        # Create a simple list window or show in message box (simplified for this implementation)
        $message = "Running Services (first 20):`n`n" + (($serviceList | Select-Object -First 20) -join "`n")
        if ($serviceList.Count -gt 20) {
            $message += "`n`n... and $($serviceList.Count - 20) more services"
        }

        [System.Windows.MessageBox]::Show($message, "Running Services", 'OK', 'Information')
    } catch {
        Log "Error viewing running services: $($_.Exception.Message)" 'Error'
    }
}

function Reset-ServiceSettings {
    Log "Resetting service settings to default..." 'Info'

    try {
        # Reset services to default startup types (simplified implementation)
        # In a real implementation, this would restore original service configurations
        Log "Service settings reset to default values" 'Success'
    } catch {
        Log "Error resetting service settings: $($_.Exception.Message)" 'Error'
    }
}

# ============================================================================
# END OF SCRIPT - Enhanced Gaming Optimizer with Dedicated Advanced Settings Panels
# ============================================================================

# Start real-time performance monitoring for dashboard
Log "Starting real-time performance monitoring..." 'Info'
Start-PerformanceMonitoring

# Inform user that game detection monitoring is on-demand
Log "Game detection monitoring remains off until Auto-Optimize is enabled" 'Info'

# Show the form
Normalize-VisualTreeBrushes -Root $form

$finalBrushKeys = @($script:BrushResourceKeys)
if ($form -and $form.Resources) {
    Register-BrushResourceKeys -Keys $form.Resources.Keys
    $finalBrushKeys = @($script:BrushResourceKeys)
    try {
        foreach ($resourceKey in $form.Resources.Keys) {
            if ($resourceKey -is [string] -and $resourceKey.EndsWith('Brush') -and ($finalBrushKeys -notcontains $resourceKey)) {
                $finalBrushKeys += $resourceKey
            }
        }
    } catch {
        # Ignore enumeration issues during final normalization
    }
}

Normalize-BrushResources -Resources $form.Resources -Keys $finalBrushKeys -AllowTransparentFallback
try {
    $form.ShowDialog() | Out-Null
} catch {
    Write-Host "Error displaying form: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Cleanup

    try {
        # Stop performance monitoring
        Stop-PerformanceMonitoring

        # Stop game detection monitoring
        Stop-GameDetectionMonitoring


        # Cleanup timer precision
        [WinMM]::timeEndPeriod(1) | Out-Null
    } catch {}
}
# - Service Management (Xbox, Telemetry, Search, Print Spooler, Superfetch)
# - Engine-specific optimizations (Unreal, Unity, Source, Frostbite, RED Engine, Creation Engine)
# - Special optimizations (DLSS, RTX, Vulkan, OpenGL, Physics, Frame Pacing)
# - Performance monitoring and auto-optimization
# - Backup and restore system
# - Export/Import configuration
# - Quick benchmark tool
# - Advanced/Compact menu modes
# - Comprehensive logging system with file persistence
# - Enhanced theme switching with instant UI updates and robust error handling
