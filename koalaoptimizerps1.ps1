# KOALA-UDP Gamer Toolkit (All-in-one, WPF)
# - Works on PowerShell 5.1+ (Windows 10/11)
# - No C# ternary operators; pure PowerShell if/else
# - Fixes XAML '&' entity parsing errors
# - Robust $ScriptRoot detection (handles console/ISE)
# - JSON backup/restore for registry, services, netsh
# - Process priority booster (background job)
# - Safe service/network/registry toggles with revert
# - Optional "Unneeded Services" pack
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

# ---------- Helpers ----------
function Log {
    param([string]$msg)
    if ($global:LogBox) {
        $global:LogBox.AppendText("[$([DateTime]::Now.ToString('HH:mm:ss'))] $msg`r`n")
        $global:LogBox.ScrollToEnd()
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
        $gpu = Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1
        if ($gpu -and $gpu.Name) {
            if ($gpu.Name -match 'NVIDIA') { return 'NVIDIA' }
            elseif ($gpu.Name -match 'AMD|RADEON') { return 'AMD' }
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
    param($BackupObj,[string]$DesiredStartMode,[string]$DesiredAction) # DesiredStartMode: Disabled/Manual/Automatic; DesiredAction: Stop/Start/None
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

# ---------- Backup / Restore ----------
function Create-Backup {
    $b = [ordered]@{
        Timestamp        = Get-Date
        GPU              = Get-GPUVendor
        Registry         = [ordered]@{}
        RegistryNICs     = [ordered]@{}   # per-interface ack/nodelay
        Services         = [ordered]@{}
        NetshTcp         = Get-NetshTcpGlobal
    }

    # Registry values we may touch
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
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpDelAckTicks"}
    )
    foreach ($r in $regList) {
        $v = Get-Reg $r.Path $r.Name
        if (-not $b.Registry.ContainsKey($r.Path)) { $b.Registry[$r.Path] = @{} }
        $b.Registry[$r.Path][$r.Name] = $v
    }

    # Per-NIC: TcpAckFrequency / TCPNoDelay
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

    # Services we may touch
    $svcTargets = @(
        "XblGameSave","XblAuthManager","XboxGipSvc","XboxNetApiSvc",
        "Spooler",
        "SysMain",
        "DiagTrack",
        "WSearch",
        "NvTelemetryContainer",
        "AMD External Events",
        "Fax","RemoteRegistry","MapsBroker","WMPNetworkSvc","WpnUserService","bthserv"
    )
    foreach ($t in $svcTargets) {
        $s = Get-ServiceState $t
        if ($s) { $b.Services[$s.Name] = $s }
    }

    $b | ConvertTo-Json -Depth 6 | Set-Content -Path $BackupPath -Encoding UTF8
    Log "Backup saved to $BackupPath"
}

function Restore-FromBackup {
    if (-not (Test-Path $BackupPath)) { Log "No backup file found at $BackupPath"; return }
    $b = Get-Content $BackupPath -Raw | ConvertFrom-Json

    # Registry (global set)
    foreach ($path in $b.Registry.PSObject.Properties.Name) {
        foreach ($name in $b.Registry.$path.PSObject.Properties.Name) {
            $val = $b.Registry.$path.$name
            if ($null -eq $val) {
                Remove-Reg $path $name | Out-Null
            } else {
                # Type guess: integer -> DWord else String
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
    # Registry per-NIC
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

    # Services
    foreach ($svcName in $b.Services.PSObject.Properties.Name) {
        Restore-ServiceState $b.Services.$svcName
    }

    # Netsh TCP (restore common flags)
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

    Log "Restore complete (registry, services, netsh). A reboot may be required for some items."
}

# ---------- XAML UI ----------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="KOALA-UDP Gamer Toolkit" Height="660" Width="820"
        Background="#1E1B2E" WindowStartupLocation="CenterScreen" ShowInTaskbar="True">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="180"/>
    </Grid.RowDefinitions>

    <TextBlock Text="KOALA-UDP Gamer Toolkit" FontSize="22" FontWeight="Bold" Foreground="White" Margin="0,0,0,8" Grid.Row="0"/>

    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Background="#292746" BorderThickness="1" BorderBrush="#5A4DB9" Padding="8">
      <StackPanel x:Name="TweaksPanel">

        <TextBlock Text="Networking" Foreground="#C1BFFF" FontWeight="Bold" Margin="0,0,0,4"/>
        <WrapPanel>
          <CheckBox x:Name="chkAck" Content="Disable TCP ACK Delay" ToolTip="Sets TcpAckFrequency=1 on all active NIC interfaces." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkDelAckTicks" Content="Set TcpDelAckTicks=0" ToolTip="Sets TcpDelAckTicks=0 for faster acknowledgements." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkTcpAutoTune" Content="TCP Autotuning: Normal" ToolTip="netsh int tcp set global autotuninglevel=normal" Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkTcpTimestamps" Content="Disable TCP Timestamps" ToolTip="netsh int tcp set global timestamps=disabled" Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkTcpECN" Content="Disable ECN" ToolTip="netsh int tcp set global ecncapability=disabled" Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkRSS" Content="Enable RSS" ToolTip="Enable Receive-Side Scaling (if supported)." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkRSC" Content="Enable RSC" ToolTip="Enable Receive Segment Coalescing (if supported)." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkThrottle" Content="Disable Network Throttling" ToolTip="Sets NetworkThrottlingIndex to 0xFFFFFFFF." Foreground="White" Margin="0,5,12,5"/>
        </WrapPanel>

        <TextBlock Text="Windows / Game UX" Foreground="#C1BFFF" FontWeight="Bold" Margin="10,10,0,4"/>
        <WrapPanel>
          <CheckBox x:Name="chkResponsiveness" Content="System Responsiveness (0)" ToolTip="HKLM...SystemProfile:SystemResponsiveness=0" Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkGamesTask" Content="Games Task: High" ToolTip="Raise MMCSS 'Games' task priorities (GPU Priority=8, Priority=6)." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkGameDVR" Content="Disable Game DVR" ToolTip="Disables GameDVR background capture and Xbox services." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkFSE" Content="Disable Fullscreen Optimizations" ToolTip="Turns off FSE optimizations via GameConfigStore." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkGpuScheduler" Content="Enable GPU Hardware Scheduling" ToolTip="GraphicsDrivers: HwSchMode=2 (if supported)." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkTimerRes" Content="Timer Resolution (while open)" ToolTip="Requests ~1ms timer resolution while the app is open; automatically reverts on exit." Foreground="White" Margin="0,5,12,5"/>
        </WrapPanel>

        <TextBlock Text="GPU Vendor Tweaks" Foreground="#C1BFFF" FontWeight="Bold" Margin="10,10,0,4"/>
        <WrapPanel>
          <CheckBox x:Name="chkNvidiaTweaks" Content="NVIDIA: Disable Telemetry Service" ToolTip="Stops &amp; disables NvTelemetryContainer if present." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkAmdTweaks" Content="AMD: Disable External Events" ToolTip="Stops &amp; disables AMD External Events Utility if present." Foreground="White" Margin="0,5,12,5"/>
        </WrapPanel>

        <TextBlock Text="Services (optional)" Foreground="#C1BFFF" FontWeight="Bold" Margin="10,10,0,4"/>
        <WrapPanel>
          <CheckBox x:Name="chkSvcXbox" Content="Disable Xbox Services" ToolTip="XblAuthManager, XblGameSave, XboxGipSvc, XboxNetApiSvc" Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkSvcSpooler" Content="Disable Print Spooler" ToolTip="Stops print spooler for FPS gains on some systems." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkSvcSysMain" Content="Disable SysMain" ToolTip="Stops prefetcher service to reduce background I/O." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkSvcDiagTrack" Content="Disable Telemetry (DiagTrack)" ToolTip="Reduces telemetry background usage." Foreground="White" Margin="0,5,12,5"/>
          <CheckBox x:Name="chkSvcSearch" Content="Disable Windows Search" ToolTip="Optional. Disables indexing service." Foreground="White" Margin="0,5,12,5"/>
        </WrapPanel>

        <TextBlock Text="Disable Unneeded Services (extra FPS)" Foreground="#C1BFFF" FontWeight="Bold" Margin="10,10,0,4"/>
        <WrapPanel>
          <CheckBox x:Name="chkDisableUnneeded" Content="Disable Fax / RemoteRegistry / MapsBroker / WMPNetworkSvc / WpnUserService / bthserv" ToolTip="Optional: Disables Fax, RemoteRegistry, MapsBroker, Windows Media Player Network Sharing, Windows Push Notifications (WpnUserService), Bluetooth Support (bthserv)." Foreground="White" Margin="0,5,12,5"/>
        </WrapPanel>

      </StackPanel>
    </ScrollViewer>

    <Grid Grid.Row="2" Margin="0,10,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Grid.Column="0">
        <TextBlock Text="Process to prioritize:" Foreground="White" VerticalAlignment="Center" Width="160"/>
        <TextBox x:Name="txtProcess" Width="220" Height="28" Text="cs2"/>
        <Button x:Name="btnDetect" Content="Auto Detect Game" Width="150" Height="28" Margin="8,0,0,0" Background="#5A4DB9" Foreground="White"/>
        <ComboBox x:Name="cmbKnown" Width="160" Height="28" Margin="8,0,0,0">
          <ComboBoxItem Content="cs2"/>
          <ComboBoxItem Content="csgo"/>
          <ComboBoxItem Content="valorant"/>
          <ComboBoxItem Content="fortnite"/>
          <ComboBoxItem Content="r6"/>
          <ComboBoxItem Content="apexlegends"/>
          <ComboBoxItem Content="overwatch"/>
          <ComboBoxItem Content="warzone"/>
          <ComboBoxItem Content="pubg"/>
        </ComboBox>
      </StackPanel>
      <StackPanel Orientation="Horizontal" Grid.Column="1">
        <Button x:Name="btnApply"  Content="Apply Selected" Width="150" Height="36" Margin="0,0,8,0" Background="#9146FF" Foreground="White" FontWeight="Bold"/>
        <Button x:Name="btnRevert" Content="Revert (from JSON)" Width="150" Height="36" Background="Gray" Foreground="White"/>
      </StackPanel>
    </Grid>

    <TextBox x:Name="txtLog" Grid.Row="3" Background="#0F0D1A" Foreground="#B7F397"
             BorderBrush="#5A4DB9" BorderThickness="1" FontFamily="Consolas"
             FontSize="14" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"/>
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

$chkResponsiveness = $form.FindName('chkResponsiveness')
$chkGamesTask      = $form.FindName('chkGamesTask')
$chkGameDVR        = $form.FindName('chkGameDVR')
$chkFSE            = $form.FindName('chkFSE')
$chkGpuScheduler   = $form.FindName('chkGpuScheduler')
$chkTimerRes       = $form.FindName('chkTimerRes')

$chkNvidiaTweaks   = $form.FindName('chkNvidiaTweaks')
$chkAmdTweaks      = $form.FindName('chkAmdTweaks')

$chkSvcXbox        = $form.FindName('chkSvcXbox')
$chkSvcSpooler     = $form.FindName('chkSvcSpooler')
$chkSvcSysMain     = $form.FindName('chkSvcSysMain')
$chkSvcDiagTrack   = $form.FindName('chkSvcDiagTrack')
$chkSvcSearch      = $form.FindName('chkSvcSearch')

$chkDisableUnneeded= $form.FindName('chkDisableUnneeded')

$txtProcess        = $form.FindName('txtProcess')
$cmbKnown          = $form.FindName('cmbKnown')
$btnDetect         = $form.FindName('btnDetect')
$btnApply          = $form.FindName('btnApply')
$btnRevert         = $form.FindName('btnRevert')
$global:LogBox     = $form.FindName('txtLog')

# Combo -> textbox sync
$cmbKnown.Add_SelectionChanged({
    if ($cmbKnown.SelectedItem -and $cmbKnown.SelectedItem.Content) {
        $txtProcess.Text = $cmbKnown.SelectedItem.Content.ToString()
    }
})

# ---------- Tweaks ----------
function Apply-Tweaks {
    Require-Admin
    Log "Creating JSON backup..."
    Create-Backup

    # Timer resolution (request while open)
    if ($chkTimerRes.IsChecked) {
        try { [WinMM]::timeBeginPeriod(1) | Out-Null; Log "Timer resolution requested (~1 ms) while app is open." } catch { Log "Timer resolution request failed: $_" }
    }

    # NETWORK
    if ($chkAck.IsChecked) {
        try {
            $ifs = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
            foreach ($i in $ifs) {
                Set-Reg $i.PSPath 'TcpAckFrequency' 'DWord' 1 | Out-Null
                Set-Reg $i.PSPath 'TCPNoDelay' 'DWord' 1 | Out-Null
            }
            Log "TCP ACK delay disabled (TcpAckFrequency=1, TCPNoDelay=1 on all NICs)."
        } catch { Log "Failed TCP ACK tweak: $_" }
    }
    if ($chkDelAckTicks.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 'DWord' 0 | Out-Null
        Log "TcpDelAckTicks set to 0."
    }
    if ($chkTcpAutoTune.IsChecked) {
        netsh int tcp set global autotuninglevel=normal | Out-Null
        Log "TCP autotuning set to Normal."
    }
    if ($chkTcpTimestamps.IsChecked) {
        netsh int tcp set global timestamps=disabled | Out-Null
        Log "TCP timestamps disabled."
    }
    if ($chkTcpECN.IsChecked) {
        netsh int tcp set global ecncapability=disabled | Out-Null
        Log "ECN disabled."
    }
    if ($chkRSS.IsChecked) {
        netsh int tcp set global rss=enabled | Out-Null
        Log "RSS enabled."
    }
    if ($chkRSC.IsChecked) {
        netsh int tcp set global rsc=enabled | Out-Null
        Log "RSC enabled."
    }
    if ($chkThrottle.IsChecked) {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 'DWord' 0xffffffff | Out-Null
        Log "NetworkThrottlingIndex disabled (FFFFFFFF)."
    }

    # WINDOWS/GAME UX
    if ($chkResponsiveness.IsChecked) {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 'DWord' 0 | Out-Null
        Log "SystemResponsiveness set to 0."
    }
    if ($chkGamesTask.IsChecked) {
        $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        Set-Reg $p "GPU Priority" 'DWord' 8   | Out-Null
        Set-Reg $p "Priority"     'DWord' 6   | Out-Null
        Set-Reg $p "Scheduling Category" 'String' "High" | Out-Null
        Set-Reg $p "SFIO Priority"       'String' "High" | Out-Null
        Log "Raised MMCSS 'Games' task priorities."
    }
    if ($chkGameDVR.IsChecked) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 'DWord' 0 | Out-Null
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 'DWord' 0 | Out-Null
        Log "GameDVR disabled (HKCU)."
    }
    if ($chkFSE.IsChecked) {
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 'DWord' 2 | Out-Null
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehavior" 'DWord' 2 | Out-Null
        Log "Fullscreen optimizations disabled."
    }
    if ($chkGpuScheduler.IsChecked) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 'DWord' 2 | Out-Null
        Log "GPU Hardware Scheduling requested (HwSchMode=2)."
    }

    # GPU VENDOR SERVICES
    $gpu = Get-GPUVendor
    Log "Detected GPU: $gpu"
    if ($chkNvidiaTweaks.IsChecked -and $gpu -eq 'NVIDIA') {
        $svc = Get-ServiceState 'NvTelemetryContainer'
        if ($svc) { Set-ServiceState $svc 'Disabled' 'Stop'; Log "NvTelemetryContainer disabled/stopped." } else { Log "NvTelemetryContainer not found." }
    }
    if ($chkAmdTweaks.IsChecked -and $gpu -eq 'AMD') {
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*AMD External Events*" } | Select-Object -First 1
        if ($svc) {
            $st = Get-ServiceState $svc.Name
            Set-ServiceState $st 'Disabled' 'Stop'
            Log "AMD External Events disabled/stopped."
        } else { Log "AMD External Events service not found." }
    }

    # OPTIONAL SERVICES
    if ($chkSvcXbox.IsChecked) {
        foreach ($n in @('XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc')) {
            $st = Get-ServiceState $n
            if ($st) { Set-ServiceState $st 'Disabled' 'Stop'; Log "$($st.Name) disabled/stopped." }
        }
    }
    if ($chkSvcSpooler.IsChecked) {
        $st = Get-ServiceState 'Spooler'
        if ($st) { Set-ServiceState $st 'Disabled' 'Stop'; Log "Print Spooler disabled/stopped." }
    }
    if ($chkSvcSysMain.IsChecked) {
        $st = Get-ServiceState 'SysMain'
        if ($st) { Set-ServiceState $st 'Disabled' 'Stop'; Log "SysMain disabled/stopped." }
    }
    if ($chkSvcDiagTrack.IsChecked) {
        $st = Get-ServiceState 'DiagTrack'
        if ($st) { Set-ServiceState $st 'Disabled' 'Stop'; Log "DiagTrack disabled/stopped." }
    }
    if ($chkSvcSearch.IsChecked) {
        $st = Get-ServiceState 'WSearch'
        if ($st) { Set-ServiceState $st 'Disabled' 'Stop'; Log "Windows Search disabled/stopped." }
    }
    if ($chkDisableUnneeded.IsChecked) {
        foreach ($n in @('Fax','RemoteRegistry','MapsBroker','WMPNetworkSvc','WpnUserService','bthserv')) {
            $st = Get-ServiceState $n
            if ($st) { Set-ServiceState $st 'Disabled' 'Stop'; Log "$($st.Name) disabled/stopped." }
        }
    }

    # Process priority booster (background job)
    $procName = ($txtProcess.Text).Trim()
    if ($procName) {
        $existing = Get-Job -Name 'KoalaPriority' -ErrorAction SilentlyContinue
        if ($existing) { Stop-Job $existing -ErrorAction SilentlyContinue; Remove-Job $existing -ErrorAction SilentlyContinue }
        Start-Job -Name 'KoalaPriority' -ScriptBlock {
            param($name)
            while ($true) {
                try {
                    $p = Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($p) {
                        $p.PriorityClass = 'High'
                    }
                } catch {}
                Start-Sleep -Seconds 3
            }
        } -ArgumentList $procName | Out-Null
        Log "Priority watcher started for '$procName' (High)."
    }

    Log "All selected tweaks applied. Some items may need a reboot."
}

function Revert-Tweaks {
    Require-Admin
    Log "Reverting from JSON backup..."

    # Stop priority job
    $existing = Get-Job -Name 'KoalaPriority' -ErrorAction SilentlyContinue
    if ($existing) { Stop-Job $existing -ErrorAction SilentlyContinue; Remove-Job $existing -ErrorAction SilentlyContinue; Log "Priority watcher stopped." }

    Restore-FromBackup
}

# ---------- Buttons ----------
$btnApply.Add_Click({
    try {
        $global:LogBox.Clear()
        Apply-Tweaks
    } catch {
        Log "Error during Apply: $_"
    }
})
$btnRevert.Add_Click({
    try {
        $global:LogBox.Clear()
        Revert-Tweaks
    } catch {
        Log "Error during Revert: $_"
    }
})
$btnDetect.Add_Click({
    $known = @('cs2','csgo','valorant','fortnite','r6','apexlegends','overwatch','warzone','pubg')
    foreach ($k in $known) {
        $p = Get-Process -Name $k -ErrorAction SilentlyContinue
        if ($p) { $txtProcess.Text = $k; Log "Detected running game: $k"; return }
    }
    Log "No known game process detected."
})

# ---------- Form lifecycle ----------
$form.Add_SourceInitialized({
    # If checkbox pre-checked at startup, request timer
    if ($chkTimerRes.IsChecked) {
        try { [WinMM]::timeBeginPeriod(1) | Out-Null } catch {}
    }
})
$form.Add_Closing({
    try {
        # Revert timer request
        [WinMM]::timeEndPeriod(1) | Out-Null
        # Stop background job
        $existing = Get-Job -Name 'KoalaPriority' -ErrorAction SilentlyContinue
        if ($existing) { Stop-Job $existing -ErrorAction SilentlyContinue; Remove-Job $existing -ErrorAction SilentlyContinue }
    } catch {}
})

$form.Topmost = $true
[void]$form.ShowDialog()
