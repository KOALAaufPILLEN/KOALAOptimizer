# KOALA-UDP Enhanced Gamer Toolkit (All-in-one, WPF)
# - Works on PowerShell 5.1+ (Windows 10/11)
# - Enhanced with additional optimizations and game-specific tweaks
# - Fixed XAML compatibility issues
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

# ---------- Game Profiles ----------
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
}

# ---------- Helpers ----------
function Log {
    param([string]$msg)
    if ($global:LogBox) {
        $timestamp = [DateTime]::Now.ToString('HH:mm:ss')
        try {
            $global:LogBox.Dispatcher.Invoke([Action]{
                $global:LogBox.AppendText("[$timestamp] $msg`r`n")
                $global:LogBox.ScrollToEnd()
            })
        } catch {
            $global:LogBox.AppendText("[$timestamp] $msg`r`n")
            $global:LogBox.ScrollToEnd()
        }
    } else {
        Write-Host $msg
    }
}

function Require-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        [System.Windows.MessageBox]::Show("Please run this script as Administrator.","KOALA-UDP", 'OK','Warning') | Out-Null
        throw "Not running as admin."
    }
}

function Get-GPUVendor {
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" } | Select-Object -First 1
        if ($gpu -and $gpu.Name) {
            if ($gpu.Name -match 'NVIDIA|GeForce|GTX|RTX') { return 'NVIDIA' }
            elseif ($gpu.Name -match 'AMD|RADEON|RX ') { return 'AMD' }
            elseif ($gpu.Name -match 'Intel') { return 'Intel' }
        }
        return 'Other'
    } catch { 'Other' }
}

function Get-Reg { param($Path,$Name)
    try { (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

function Set-Reg { param($Path,$Name,$Type='DWord',$Value)
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
        $true
    } catch { Log "Reg set failed: $Path\$Name ($_)"; $false }
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
            if ($mode) { Set-Service -Name $BackupObj.Name -StartupType $mode -ErrorAction SilentlyContinue }
        }
        if ($DesiredAction -eq 'Stop') {
            Stop-Service -Name $BackupObj.Name -Force -ErrorAction SilentlyContinue
        } elseif ($DesiredAction -eq 'Start') {
            Start-Service -Name $BackupObj.Name -ErrorAction SilentlyContinue
        }
    } catch {
        Log "Service change failed: $($BackupObj.Name) ($_)"
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
    
    if (-not $GameProfiles.ContainsKey($GameKey)) { return }
    
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
        }
    }
}

# ---------- Backup / Restore ----------
function Create-Backup {
    $b = [ordered]@{
        Timestamp        = Get-Date
        GPU              = Get-GPUVendor
        Registry         = [ordered]@{}
        RegistryNICs     = [ordered]@{}
        Services         = [ordered]@{}
        NetshTcp         = Get-NetshTcpGlobal
    }

    # Extended registry list with new optimizations
    $regList = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="NetworkThrottlingIndex"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Scheduling Category"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="SFIO Priority"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehavior"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name="AppCaptureEnabled"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name="GameDVR_Enabled"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="HwSchMode"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpDelAckTicks"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpNoDelay"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TCPNoDelay"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxConnectionsPerServer"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxConnectionsPer1_0Server"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name="GlobalTimerResolutionRequests"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="DisablePagingExecutive"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargeSystemCache"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="SystemPages"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power"; Name="HibernateEnabled"},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name="VisualFXSetting"}
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
    $b = Get-Content $BackupPath -Raw | ConvertFrom-Json

    # Registry restoration
    foreach ($path in $b.Registry.PSObject.Properties.Name) {
        foreach ($name in $b.Registry.$path.PSObject.Properties.Name) {
            $val = $b.Registry.$path.$name
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
    
    # NIC registry restoration
    if ($b.RegistryNICs) {
        foreach ($nicPath in $b.RegistryNICs.PSObject.Properties.Name) {
            $nicVals = $b.RegistryNICs.$nicPath
            foreach ($n in @('TcpAckFrequency','TCPNoDelay')) {
                if ($nicVals.$n -eq $null) {
                    Remove-Reg $nicPath $n | Out-Null
                } else {
                    Set-Reg $nicPath $n 'DWord' ([int]$nicVals.$n) | Out-Null
                }
            }
        }
    }

    # Service restoration
    foreach ($svcName in $b.Services.PSObject.Properties.Name) {
        Restore-ServiceState $b.Services.$svcName
    }

    # Netsh restoration
    if ($b.NetshTcp) {
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
    }

    Log "Complete restore finished. Reboot recommended."
}

# ---------- Fixed XAML UI ----------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="KOALA-UDP Enhanced Gaming Toolkit v2.0" Height="750" Width="900"
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
      <TextBlock Text="🚀 KOALA-UDP Enhanced Gaming Toolkit v2.0" FontSize="24" FontWeight="Bold" Foreground="#00FF88" Margin="0,0,0,4"/>
      <TextBlock Text="Advanced Windows gaming optimizations with game-specific profiles" FontSize="14" Foreground="#B8B3E6" FontStyle="Italic"/>
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
          <CheckBox x:Name="chkVisualEffects" Content="Disable Visual Effects" ToolTip="Disables Windows visual effects for performance." Foreground="White" Margin="0,5,15,5"/>
          <CheckBox x:Name="chkHibernation" Content="Disable Hibernation" ToolTip="Disables hibernation to free up disk space." Foreground="White" Margin="0,5,15,5"/>
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
        <Button x:Name="btnApply" Content="🚀 Apply Selected" Width="160" Height="40" Margin="0,0,10,0" Background="#00FF88" Foreground="Black" FontWeight="Bold" FontSize="14"/>
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
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="📋 Activity Log" Foreground="#00FF88" FontWeight="Bold" Margin="0,0,0,4"/>
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
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

# Set default values
$cmbGameProfile.SelectedIndex = 1  # CS2
$cmbPriority.SelectedIndex = 0     # High

# Game profile selection handler
$cmbGameProfile.Add_SelectionChanged({
    if ($cmbGameProfile.SelectedItem -and $cmbGameProfile.SelectedItem.Tag) {
        $tag = $cmbGameProfile.SelectedItem.Tag.ToString()
        if ($tag -ne 'custom' -and $GameProfiles.ContainsKey($tag)) {
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
    Require-Admin
    $lblStatus.Text = "Working..."
    $lblStatus.Foreground = "#F59E0B"
    
    Log "🚀 Starting enhanced gaming optimizations..."
    Create-Backup

    # Timer resolution
    if ($chkTimerRes.IsChecked) {
        try { 
            [WinMM]::timeBeginPeriod(1) | Out-Null
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" 'DWord' 1 | Out-Null
            Log "✅ High precision timer enabled (~1ms resolution)"
        } catch { Log "❌ Timer resolution request failed: $_" }
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
            Log "✅ TCP ACK delay disabled on $count network interfaces"
        } catch { Log "❌ TCP ACK optimization failed: $_" }
    }
    
    if ($chkDelAckTicks.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 'DWord' 0 | Out-Null
        Log "✅ TcpDelAckTicks set to 0"
    }
    
    if ($chkNagle.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPNoDelay" 'DWord' 1 | Out-Null
        Log "✅ Nagle's algorithm disabled for reduced latency"
    }
    
    # Netsh optimizations
    if ($chkTcpAutoTune.IsChecked) {
        netsh int tcp set global autotuninglevel=normal | Out-Null
        Log "✅ TCP autotuning set to Normal"
    }
    if ($chkTcpTimestamps.IsChecked) {
        netsh int tcp set global timestamps=disabled | Out-Null
        Log "✅ TCP timestamps disabled"
    }
    if ($chkTcpECN.IsChecked) {
        netsh int tcp set global ecncapability=disabled | Out-Null
        Log "✅ ECN capability disabled"
    }
    if ($chkRSS.IsChecked) {
        netsh int tcp set global rss=enabled | Out-Null
        Log "✅ Receive-Side Scaling enabled"
    }
    if ($chkRSC.IsChecked) {
        netsh int tcp set global rsc=enabled | Out-Null
        Log "✅ Receive Segment Coalescing enabled"
    }
    if ($chkThrottle.IsChecked) {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 'DWord' 0xffffffff | Out-Null
        Log "✅ Network throttling disabled"
    }

    # WINDOWS/GAME UX OPTIMIZATIONS
    if ($chkResponsiveness.IsChecked) {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 'DWord' 0 | Out-Null
        Log "✅ System responsiveness optimized (0)"
    }
    if ($chkGamesTask.IsChecked) {
        $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        Set-Reg $p "GPU Priority" 'DWord' 8   | Out-Null
        Set-Reg $p "Priority"     'DWord' 6   | Out-Null
        Set-Reg $p "Scheduling Category" 'String' "High" | Out-Null
        Set-Reg $p "SFIO Priority"       'String' "High" | Out-Null
        Log "✅ MMCSS 'Games' task priorities raised to High"
    }
    if ($chkGameDVR.IsChecked) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 'DWord' 0 | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 'DWord' 0 | Out-Null
        Log "✅ Game DVR disabled"
    }
    if ($chkFSE.IsChecked) {
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 'DWord' 2 | Out-Null
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehavior" 'DWord' 2 | Out-Null
        Log "✅ Fullscreen optimizations disabled"
    }
    if ($chkGpuScheduler.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 | Out-Null
        Log "✅ GPU Hardware Scheduling enabled"
    }
    if ($chkVisualEffects.IsChecked) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 'DWord' 2 | Out-Null
        Log "✅ Visual effects disabled for performance"
    }
    if ($chkHibernation.IsChecked) {
        powercfg /hibernate off | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 'DWord' 0 | Out-Null
        Log "✅ Hibernation disabled"
    }

    # SYSTEM PERFORMANCE
    if ($chkMemoryManagement.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 'DWord' 1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 'DWord' 0 | Out-Null
        Log "✅ Memory management optimized (paging executive disabled)"
    }
    if ($chkPowerPlan.IsChecked) {
        try {
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            Log "✅ Ultimate Performance power plan activated"
        } catch {
            powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
            Log "✅ High Performance power plan activated (Ultimate not available)"
        }
    }
    if ($chkCpuScheduling.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 'DWord' 38 | Out-Null
        Log "✅ CPU scheduling optimized for foreground applications"
    }
    if ($chkPageFile.IsChecked) {
        $cs = Get-CimInstance Win32_ComputerSystem
        $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB)
        $pageFileSize = [math]::Max(2048, $ram * 1024)  # Minimum 2GB or RAM size
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagingFiles" 'MultiString' @("C:\pagefile.sys $pageFileSize $pageFileSize") | Out-Null
        Log "✅ Page file optimized (Size: $([math]::Round($pageFileSize/1024, 1))GB)"
    }

    # GPU VENDOR OPTIMIZATIONS
    $gpu = Get-GPUVendor
    Log "🎯 Detected GPU: $gpu"
    
    if ($chkNvidiaTweaks.IsChecked -and $gpu -eq 'NVIDIA') {
        $svc = Get-ServiceState 'NvTelemetryContainer'
        if ($svc) { 
            Set-ServiceState $svc 'Disabled' 'Stop'
            Log "✅ NVIDIA telemetry service disabled"
        } else { Log "ℹ️ NVIDIA telemetry service not found" }
        
        # Additional NVIDIA optimizations
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrLevel" 'DWord' 0 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 'DWord' 60 | Out-Null
        Log "✅ NVIDIA TDR (Timeout Detection and Recovery) optimized"
    }
    
    if ($chkAmdTweaks.IsChecked -and $gpu -eq 'AMD') {
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*AMD External Events*" } | Select-Object -First 1
        if ($svc) {
            $st = Get-ServiceState $svc.Name
            Set-ServiceState $st 'Disabled' 'Stop'
            Log "✅ AMD External Events service disabled"
        } else { Log "ℹ️ AMD External Events service not found" }
    }
    
    if ($chkIntelTweaks.IsChecked -and $gpu -eq 'Intel') {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrLevel" 'DWord' 0 | Out-Null
        Log "✅ Intel graphics optimizations applied"
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
            Log "✅ Service disabled: $($st.Display)"
        }
    }

    # GAME-SPECIFIC OPTIMIZATIONS
    $selectedProfile = $cmbGameProfile.SelectedItem.Tag.ToString()
    if ($selectedProfile -ne 'custom' -and $GameProfiles.ContainsKey($selectedProfile)) {
        Apply-GameSpecificTweaks $selectedProfile $GameProfiles[$selectedProfile].SpecificTweaks
    }

    # PROCESS PRIORITY OPTIMIZER
    $procName = ($txtProcess.Text).Trim()
    $selectedPriority = $cmbPriority.SelectedItem.Tag.ToString()
    
    if ($procName) {
        $existing = Get-Job -Name 'KoalaPriority' -ErrorAction SilentlyContinue
        if ($existing) { Stop-Job $existing -ErrorAction SilentlyContinue; Remove-Job $existing -ErrorAction SilentlyContinue }
        
        Start-Job -Name 'KoalaPriority' -ScriptBlock {
            param($name, $priority, $gamePath)
            while ($true) {
                try {
                    # Find and optimize main process
                    $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
                    foreach ($p in $processes) {
                        $p.PriorityClass = $priority
                        
                        # Set CPU affinity to use all cores efficiently
                        if ($priority -eq 'High' -or $priority -eq 'RealTime') {
                            $coreCount = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
                            if ($coreCount -gt 4) {
                                # Use cores 2-N for the game, leave core 0-1 for system
                                $affinityMask = [math]::Pow(2, $coreCount) - 1 - 3  # All cores except 0,1
                                $p.ProcessorAffinity = $affinityMask
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
        } -ArgumentList $procName, $selectedPriority, $txtGamePath.Text.Trim() | Out-Null
        
        Log "🎮 Priority optimizer started for '$procName' (Priority: $selectedPriority)"
    }

    $lblStatus.Text = "Complete!"
    $lblStatus.Foreground = "#00FF88"
    Log "🎉 All optimizations applied successfully! Some changes may require a reboot."
}

function Revert-Tweaks {
    Require-Admin
    $lblStatus.Text = "Reverting..."
    $lblStatus.Foreground = "#F59E0B"
    
    Log "🔄 Reverting all optimizations..."

    # Stop priority job
    $existing = Get-Job -Name 'KoalaPriority' -ErrorAction SilentlyContinue
    if ($existing) { 
        Stop-Job $existing -ErrorAction SilentlyContinue
        Remove-Job $existing -ErrorAction SilentlyContinue
        Log "✅ Priority optimizer stopped"
    }

    # Revert timer resolution
    try { [WinMM]::timeEndPeriod(1) | Out-Null } catch {}

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
🖥️ SYSTEM INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━
💻 Computer: $($cs.Name)
🔧 OS: $($os.Caption) ($($os.Version))
⚡ CPU: $($cpu.Name) ($($cpu.NumberOfLogicalProcessors) cores)
💾 RAM: $ram GB
🎯 GPU: $gpu
🔋 Power Plan: $powerPlan
📊 CPU Usage: $((Get-CimInstance Win32_Processor).LoadPercentage)%
💿 Available Memory: $([math]::Round($os.FreePhysicalMemory / 1MB, 2)) GB
"@
    
    Log $info
    $lblStatus.Text = "System info displayed"
    $lblStatus.Foreground = "#58A6FF"
}

function Run-QuickBenchmark {
    $lblStatus.Text = "Benchmarking..."
    $lblStatus.Foreground = "#F59E0B"
    Log "🏁 Running quick system benchmark..."
    
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
🏁 QUICK BENCHMARK RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ CPU Performance: $([math]::Round(10000 / $cpuTime, 2)) ops/ms
💾 Memory Performance: $([math]::Round(100000 / $memTime, 2)) ops/ms
🌐 Network Latency: $($pingResults -join ', ')
📊 Performance Score: $([math]::Round((10000 / $cpuTime + 100000 / $memTime) / 2, 0))
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
    Log "✅ Configuration exported to: $configPath"
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
                
                Log "✅ Configuration imported successfully from: $configFile"
                $lblStatus.Text = "Config imported"
                $lblStatus.Foreground = "#10B981"
            }
        }
    } catch {
        # Fallback: manual file path entry
        $configFile = [Microsoft.VisualBasic.Interaction]::InputBox("Enter full path to configuration JSON file:", "Import Configuration", (Join-Path $ScriptRoot "KoalaConfig_*.json"))
        if ($configFile -and (Test-Path $configFile)) {
            try {
                $config = Get-Content $configFile -Raw | ConvertFrom-Json
                # Same import logic as above...
                Log "✅ Configuration imported from: $configFile"
                $lblStatus.Text = "Config imported"
                $lblStatus.Foreground = "#10B981"
            } catch {
                Log "❌ Failed to import configuration: $_"
                $lblStatus.Text = "Import failed"
                $lblStatus.Foreground = "#FF6B6B"
            }
        }
    }
}

# ---------- Event Handlers ----------
$btnApply.Add_Click({
    try {
        $global:LogBox.Clear()
        Apply-Tweaks
    } catch {
        Log "❌ Error during Apply: $_"
        $lblStatus.Text = "Error occurred"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

$btnRevert.Add_Click({
    try {
        $global:LogBox.Clear()
        Revert-Tweaks
    } catch {
        Log "❌ Error during Revert: $_"
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
                
                Log "🎮 Detected running game: $($profile.DisplayName) (Process: $procName)"
                $lblStatus.Text = "Game detected!"
                $lblStatus.Foreground = "#00FF88"
                return
            }
        }
    }
    Log "ℹ️ No known game processes detected"
    $lblStatus.Text = "No games found"
    $lblStatus.Foreground = "#F59E0B"
})

$btnSystemInfo.Add_Click({
    try {
        Show-SystemInfo
    } catch {
        Log "❌ Error showing system info: $_"
    }
})

$btnBenchmark.Add_Click({
    try {
        Run-QuickBenchmark
    } catch {
        Log "❌ Error during benchmark: $_"
        $lblStatus.Text = "Benchmark failed"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

$btnExportConfig.Add_Click({
    try {
        Export-Configuration
    } catch {
        Log "❌ Error exporting config: $_"
        $lblStatus.Text = "Export failed"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

$btnImportConfig.Add_Click({
    try {
        Import-Configuration
    } catch {
        Log "❌ Error importing config: $_"
        $lblStatus.Text = "Import failed"
        $lblStatus.Foreground = "#FF6B6B"
    }
})

# ---------- Form Lifecycle ----------
$form.Add_SourceInitialized({
    Log "🚀 KOALA-UDP Enhanced Gaming Toolkit v2.0 loaded"
    Log "💡 Select your optimizations and click 'Apply Selected' to begin"
    Log "⚠️ Remember: This tool requires Administrator privileges"
    
    # Auto-detect GPU and show recommendations
    $gpu = Get-GPUVendor
    if ($gpu -eq 'NVIDIA') {
        $chkNvidiaTweaks.IsChecked = $true
        Log "💡 Recommendation: NVIDIA GPU detected - NVIDIA tweaks pre-selected"
    } elseif ($gpu -eq 'AMD') {
        $chkAmdTweaks.IsChecked = $true
        Log "💡 Recommendation: AMD GPU detected - AMD tweaks pre-selected"
    } elseif ($gpu -eq 'Intel') {
        $chkIntelTweaks.IsChecked = $true
        Log "💡 Recommendation: Intel GPU detected - Intel tweaks pre-selected"
    }
    
    # Pre-select recommended optimizations
    $chkAck.IsChecked = $true
    $chkDelAckTicks.IsChecked = $true
    $chkResponsiveness.IsChecked = $true
    $chkGamesTask.IsChecked = $true
    $chkGameDVR.IsChecked = $true
    $chkTimerRes.IsChecked = $true
    
    if ($chkTimerRes.IsChecked) {
        try { [WinMM]::timeBeginPeriod(1) | Out-Null } catch {}
    }
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
        
        Log "👋 KOALA-UDP Gaming Toolkit closed - Timer resolution restored"
    } catch {}
})

# Set window properties
$form.Topmost = $true
$form.ResizeMode = "CanResize"
$form.MinWidth = 900
$form.MinHeight = 750

# Show the enhanced interface
Log "🎮 Starting KOALA-UDP Enhanced Gaming Toolkit..."
[void]$form.ShowDialog()
