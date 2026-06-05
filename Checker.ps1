
<#
.SYNOPSIS
    Interactive System Dashboard & Forensics Suite.
.DESCRIPTION
    A modular, menu-driven tool for deep system analysis, health checks, and security auditing.
.VERSION
    3.0 (Ultimate Edition)
.AUTHOR
    Enhanced for Lily & Community
#>

# --- REQUIREMENTS ---
 $isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Clear-Host
    Write-Host "[FATAL] Administrator Privileges Required." -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'." -ForegroundColor White
    Start-Sleep -Seconds 3
    exit
}

# --- UI HELPER FUNCTIONS ---

function Draw-Header {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║" -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-78}" -f $Title) -NoNewline -ForegroundColor White
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Draw-Separator {
    Write-Host ("─" * 80) -ForegroundColor DarkGray
}

function Show-Spinner {
    param([int]$Seconds = 1, [string]$Message = "Processing")
    $spinner = "/-\|"
    $job = 0
    for ($i = 0; $i -lt ($Seconds * 4); $i++) {
        Write-Host "`r$($spinner[$job]) $Message..." -NoNewline -ForegroundColor Yellow
        $job = ($job + 1) % 4
        Start-Sleep -Milliseconds 250
    }
    Write-Host "`r[✓] $Message Completed. " -NoNewline -ForegroundColor Green
    Write-Host ""
}

function Get-MenuSelection {
    param([string[]]$Options)
    $selection = 0
    do {
        Clear-Host
        Draw-Header "SYSTEM DASHBOARD // MAIN MENU"
        
        # ASCII Art Logo
        Write-Host @"
   ____  ___  ____   __   __ _  ____  _   _ 
  |  _ \|_ _||  _ \  \ \ / /| ||  _ \| | | |
  | |_) || | | |_) |  \ V / | || |_) | | | |
  |  __/ | | |  _ <    | |  | ||  __/| |_| |
  |_|   |___||_| \_\   |_|  |_||_|    \___/ 
"@ -ForegroundColor Cyan
        Write-Host ""

        for ($i = 0; $i -lt $Options.Count; $i++) {
            if ($i -eq $selection) {
                Write-Host (" > [{0}] {1}" -f ($i + 1), $Options[$i]) -ForegroundColor Black -BackgroundColor Green
            } else {
                Write-Host ("   [{0}] {1}" -f ($i + 1), $Options[$i]) -ForegroundColor White
            }
        }
        Write-Host ""
        Write-Host "   [Q] Quit" -ForegroundColor Red
        Write-Host ""

        $key = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown").VirtualKeyCode
        
        if ($key -eq 38) { # Up Arrow
            if ($selection -gt 0) { $selection-- }
        } elseif ($key -eq 40) { # Down Arrow
            if ($selection -lt $Options.Count - 1) { $selection++ }
        } elseif ($key -eq 13) { # Enter
            return $selection + 1
        } elseif ($key -eq 81) { # Q
            return "Q"
        }
    } while ($true)
}

# --- MODULE 1: SYSTEM OVERVIEW ---
function Invoke-SystemModule {
    Draw-Header "MODULE: SYSTEM OVERVIEW"
    Show-Spinner -Seconds 1 -Message "Gathering System Metrics"
    
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $uptime = (Get-Date) - $os.LastBootUpTime

    Write-Host "[Machine Name] : " -NoNewline; Write-Host $cs.Name -ForegroundColor Cyan
    Write-Host "[OS Version]  : " -NoNewline; Write-Host $os.Caption -ForegroundColor White
    Write-Host "[Build Number] : " -NoNewline; Write-Host $os.BuildNumber -ForegroundColor Gray
    Write-Host "[Uptime]      : " -NoNewline; Write-Host "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Green
    
    Draw-Separator
    
    # Disk Health
    Write-Host "Physical Drive Health:" -ForegroundColor Yellow
    Get-PhysicalDisk | Format-Table DeviceId, FriendlyName, MediaType, HealthStatus -AutoSize

    Draw-Separator
    Write-Host "Press any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# --- MODULE 2: SERVICES & REGISTRY ---
function Invoke-ServicesModule {
    Draw-Header "MODULE: SERVICES & REGISTRY"
    
    $criticalServices = @("SysMain", "WinDefend", "EventLog", "Schedule", "wuauserv", "Themes", "Spooler")
    
    Show-Spinner -Seconds 1 -Message "Querying Service States"
    
    $results = foreach ($s in $criticalServices) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            $color = if ($svc.Status -eq "Running") { "Green" } else { "Red" }
            [PSCustomObject]@{
                Name = $svc.Name
                DisplayName = $svc.DisplayName
                Status = $svc.Status
            }
        }
    }
    
    $results | Format-Table -AutoSize

    Draw-Separator
    
    # Registry Quick Check
    Write-Host "Registry Security Checks:" -ForegroundColor Yellow
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    $prefetch = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).EnablePrefetcher
    
    Write-Host "  Prefetch Status: " -NoNewline
    if ($prefetch -eq 3) { Write-Host "Enabled (Safe)" -ForegroundColor Green } 
    else { Write-Host "Disabled/Modified ($prefetch)" -ForegroundColor Red }

    Write-Host "  CMD Status: " -NoNewline
    $cmdStat = (Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\System" -ErrorAction SilentlyContinue).DisableCMD
    if ($cmdStat -eq 1) { Write-Host "DISABLED (Warning)" -ForegroundColor Red }
    else { Write-Host "Enabled (Safe)" -ForegroundColor Green }

    Write-Host "`nPress any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# --- MODULE 3: NETWORK DIAGNOSTICS ---
function Invoke-NetworkModule {
    Draw-Header "MODULE: NETWORK DIAGNOSTICS"
    Show-Spinner -Seconds 1 -Message "Scanning Adapters"
    
    Write-Host "Active Adapters:" -ForegroundColor Yellow
    Get-NetAdapter | Where-Object Status -eq "Up" | Format-Table Name, InterfaceDescription, LinkSpeed -AutoSize

    Draw-Separator
    
    Write-Host "Connectivity Test (Ping 8.8.8.8):" -ForegroundColor Yellow
    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet
    if ($ping) { Write-Host "  [+] Internet Connection: ACTIVE" -ForegroundColor Green }
    else { Write-Host "  [-] Internet Connection: FAILED" -ForegroundColor Red }

    Draw-Separator
    
    Write-Host "DNS Cache Entries (Top 10):" -ForegroundColor Yellow
    Get-DnsClientCache | Select-Object -First 10 | Format-Table Entry, Data -AutoSize

    Write-Host "`nPress any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# --- MODULE 4: SECURITY & USERS ---
function Invoke-SecurityModule {
    Draw-Header "MODULE: SECURITY & USERS"
    Show-Spinner -Seconds 1 -Message "Auditing User Permissions"

    Write-Host "Local Administrator Group Members:" -ForegroundColor Yellow
    try {
        Get-LocalGroupMember -Group "Administrators" | ForEach-Object {
            $name = $_.Name
            if ($name -like "*$env:COMPUTERNAME*") { Write-Host "  [LOCAL] $name" -ForegroundColor Cyan }
            else { Write-Host "  [DOMAIN] $name" -ForegroundColor Magenta }
        }
    } catch {
        Write-Host "  Error retrieving group members." -ForegroundColor Red
    }

    Draw-Separator

    Write-Host "Firewall Profiles:" -ForegroundColor Yellow
    Get-NetFirewallProfile | Format-Table Name, Enabled -AutoSize

    Draw-Separator

    Write-Host "BitLocker Status:" -ForegroundColor Yellow
    Get-BitLockerVolume | Format-Table MountPoint, VolumeStatus, ProtectionStatus -AutoSize

    Write-Host "`nPress any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# --- MODULE 5: FORENSICS (Logs, Prefetch, Bin) ---
function Invoke-ForensicsModule {
    Draw-Header "MODULE: FORENSICS ARTIFACTS"
    
    Write-Host "[1] Event Logs" -ForegroundColor White
    Write-Host "[2] Prefetch Analysis" -ForegroundColor White
    Write-Host "[3] Recycle Bin" -ForegroundColor White
    Write-Host "[4] Recent Scheduled Tasks" -ForegroundColor White
    Write-Host "`nSelect Sub-Module (1-4) or 'M' for Main Menu: " -NoNewline -ForegroundColor Cyan
    $subChoice = Read-Host

    switch ($subChoice) {
        '1' {
            Write-Host "`nRecent Critical Events:" -ForegroundColor Yellow
            $events = @("System", "Security", "Application")
            foreach ($e in $events) {
                Write-Host "  Checking $e log..."
                $last = Get-WinEvent -ListLog $e -ErrorAction SilentlyContinue | Select-Object LastWriteTime
                if($last) { Write-Host "    Last Write: $($last.LastWriteTime)" -ForegroundColor Green }
            }
            
            Write-Host "`nChecking for Event Log Clearing痕迹" -ForegroundColor Red
            $clear = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=1102)]]" -MaxEvents 1 -ErrorAction SilentlyContinue
            if($clear) { Write-Host "  [!] Logs cleared on: $($clear.TimeCreated)" -ForegroundColor Red }
            else { Write-Host "  [+] No log clear traces found." -ForegroundColor Green }
        }
        '2' {
            Write-Host "`nAnalyzing Prefetch..." -ForegroundColor Yellow
            $pf = Get-ChildItem "$env:SystemRoot\Prefetch\*.pf" -ErrorAction SilentlyContinue
            Write-Host "  Total Files: $($pf.Count)" -ForegroundColor White
            
            # Check for weird attributes
            $suspicious = $pf | Where-Object { $_.Attributes -match "Hidden|ReadOnly" }
            if($suspicious) { Write-Host "  [!] Found Suspicious Attributes on $($suspicious.Count) files." -ForegroundColor Red }
            else { Write-Host "  [+] Prefetch Attributes Clean." -ForegroundColor Green }
        }
        '3' {
            Write-Host "`nRecycle Bin Scan..." -ForegroundColor Yellow
            $rb = Get-ChildItem "$env:SystemDrive\`$Recycle.Bin" -Recurse -ErrorAction SilentlyContinue
            Write-Host "  Items found: $($rb.Count)" -ForegroundColor White
            if($rb) {
                $latest = $rb | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Host "  Latest Deletion: $($latest.Name) at $($latest.LastWriteTime)" -ForegroundColor Gray
            }
        }
        '4' {
            Write-Host "`nScheduled Tasks (Ready State):" -ForegroundColor Yellow
            Get-ScheduledTask | Where-Object State -eq 'Ready' | Select-Object TaskName, Author | Format-Table -AutoSize
        }
    }

    Write-Host "`nPress any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# --- MODULE 6: PERFORMANCE ---
function Invoke-PerformanceModule {
    Draw-Header "MODULE: PERFORMANCE MONITOR"
    
    Write-Host "Top 5 Processes by CPU:" -ForegroundColor Yellow
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property Name, CPU, Id | Format-Table -AutoSize
    
    Draw-Separator
    
    Write-Host "Top 5 Processes by Memory (MB):" -ForegroundColor Yellow
    Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 -Property Name, @{Name="Memory(MB)";Expression={[math]::Round($_.WorkingSet/1MB,2)}} | Format-Table -AutoSize

    Draw-Separator

    Write-Host "Windows Updates Status:" -ForegroundColor Yellow
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search("IsInstalled=0")
        Write-Host "  Pending Updates Found: " -NoNewline
        Write-Host $result.Updates.Count -ForegroundColor $(if($result.Updates.Count -gt 0){'Red'}else{'Green'})
    } catch {
        Write-Host "  Could not query Windows Update." -ForegroundColor Gray
    }

    Write-Host "`nPress any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# --- MAIN LOOP ---

 $menuOptions = @(
    "System Overview (OS & Disk)",
    "Services & Registry Health",
    "Network Diagnostics",
    "Security & User Audit",
    "Forensics Artifacts (Logs/Prefetch)",
    "Performance Monitor"
)

do {
    $choice = Get-MenuSelection -Options $menuOptions
    
    switch ($choice) {
        1 { Invoke-SystemModule }
        2 { Invoke-ServicesModule }
        3 { Invoke-NetworkModule }
        4 { Invoke-SecurityModule }
        5 { Invoke-ForensicsModule }
        6 { Invoke-PerformanceModule }
    }
} while ($choice -ne "Q")

# Exit
Clear-Host
Write-Host "Session Terminated." -ForegroundColor Cyan
Start-Sleep -Seconds 1
