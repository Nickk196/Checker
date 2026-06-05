<#
.SYNOPSIS
    Automated Full System Scan & Forensics Suite.
.DESCRIPTION
    Runs a comprehensive linear scan of system health, security, and forensics automatically.
.VERSION
    3.1 (Automated)
#>

# --- REQUIREMENTS ---
 $isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Clear-Host
    Write-Host "[FATAL] Administrator Privileges Required." -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit
}

# --- UI HELPER FUNCTIONS ---

function Draw-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║" -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-78}" -f $Title) -NoNewline -ForegroundColor White
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Draw-Separator {
    Write-Host ("─" * 80) -ForegroundColor DarkGray
}

function Show-Spinner {
    param([string]$Message = "Processing")
    Write-Host " [ $Message... ] " -NoNewline -ForegroundColor Yellow
    Start-Sleep -Milliseconds 400 # Visual pause
    Write-Host "[DONE]" -ForegroundColor Green
}

# --- MODULE 1: SYSTEM OVERVIEW ---
function Invoke-SystemModule {
    Draw-Header "MODULE 1/6: SYSTEM OVERVIEW"
    Show-Spinner "Gathering System Metrics"
    
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $uptime = (Get-Date) - $os.LastBootUpTime

    Write-Host "`n[MACHINE DETAILS]" -ForegroundColor Yellow
    Write-Host "  Name        : " -NoNewline; Write-Host $cs.Name -ForegroundColor Cyan
    Write-Host "  Model       : " -NoNewline; Write-Host $cs.Model -ForegroundColor Gray
    Write-Host "  OS Version  : " -NoNewline; Write-Host $os.Caption -ForegroundColor White
    Write-Host "  Build       : " -NoNewline; Write-Host $os.BuildNumber -ForegroundColor Gray
    Write-Host "  Uptime      : " -NoNewline; Write-Host "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Green
    
    Draw-Separator
    Write-Host "[PHYSICAL DISK HEALTH]" -ForegroundColor Yellow
    Get-PhysicalDisk | Format-Table DeviceId, FriendlyName, MediaType, HealthStatus -AutoSize
}

# --- MODULE 2: SERVICES & REGISTRY ---
function Invoke-ServicesModule {
    Draw-Header "MODULE 2/6: SERVICES & REGISTRY"
    Show-Spinner "Querying Service States"
    
    $criticalServices = @("SysMain", "WinDefend", "EventLog", "Schedule", "wuauserv", "Themes", "Spooler")
    
    $results = foreach ($s in $criticalServices) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            [PSCustomObject]@{
                Name = $svc.Name
                DisplayName = $svc.DisplayName
                Status = $svc.Status
            }
        }
    }
    Write-Host "`n[CRITICAL SERVICES STATUS]" -ForegroundColor Yellow
    $results | Format-Table -AutoSize

    Draw-Separator
    Write-Host "[REGISTRY SECURITY CHECKS]" -ForegroundColor Yellow
    
    $pf = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -ErrorAction SilentlyContinue).EnablePrefetcher
    Write-Host "  Prefetch   : " -NoNewline
    if ($pf -eq 3) { Write-Host "Enabled (Safe)" -ForegroundColor Green } else { Write-Host "Disabled/Modified ($pf)" -ForegroundColor Red }

    $cmd = (Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\System" -ErrorAction SilentlyContinue).DisableCMD
    Write-Host "  CMD Access : " -NoNewline
    if ($cmd -eq 1) { Write-Host "DISABLED (Warning)" -ForegroundColor Red } else { Write-Host "Enabled (Safe)" -ForegroundColor Green }
}

# --- MODULE 3: NETWORK DIAGNOSTICS ---
function Invoke-NetworkModule {
    Draw-Header "MODULE 3/6: NETWORK DIAGNOSTICS"
    Show-Spinner "Scanning Adapters"
    
    Write-Host "`n[ACTIVE ADAPTERS]" -ForegroundColor Yellow
    Get-NetAdapter | Where-Object Status -eq "Up" | Format-Table Name, InterfaceDescription, LinkSpeed -AutoSize

    Draw-Separator
    Show-Spinner "Testing Internet Connectivity"
    Write-Host "`n[CONNECTIVITY]" -ForegroundColor Yellow
    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
    if ($ping) { Write-Host "  Google DNS (8.8.8.8): " -NoNewline; Write-Host "ONLINE" -ForegroundColor Green }
    else { Write-Host "  Google DNS (8.8.8.8): " -NoNewline; Write-Host "OFFLINE" -ForegroundColor Red }

    Write-Host "`n[DNS CACHE (Top 10)]" -ForegroundColor Yellow
    Get-DnsClientCache | Select-Object -First 10 | Format-Table Entry, Data, Status -AutoSize
}

# --- MODULE 4: SECURITY & USERS ---
function Invoke-SecurityModule {
    Draw-Header "MODULE 4/6: SECURITY & USERS"
    Show-Spinner "Auditing Permissions"

    Write-Host "`n[LOCAL ADMINISTRATORS]" -ForegroundColor Yellow
    try {
        Get-LocalGroupMember -Group "Administrators" | ForEach-Object {
            $name = $_.Name
            if ($name -like "*$env:COMPUTERNAME*") { Write-Host "  [LOCAL] $name" -ForegroundColor Cyan }
            else { Write-Host "  [DOMAIN] $name" -ForegroundColor Magenta }
        }
    } catch {
        Write-Host "  Error retrieving members." -ForegroundColor Red
    }

    Draw-Separator
    Write-Host "[FIREWALL PROFILES]" -ForegroundColor Yellow
    Get-NetFirewallProfile | Format-Table Name, Enabled -AutoSize

    Draw-Separator
    Write-Host "[BITLOCKER STATUS]" -ForegroundColor Yellow
    Get-BitLockerVolume | Format-Table MountPoint, VolumeStatus, ProtectionStatus -AutoSize
}

# --- MODULE 5: FORENSICS ---
function Invoke-ForensicsModule {
    Draw-Header "MODULE 5/6: FORENSICS ARTIFACTS"
    
    # 1. Event Logs
    Show-Spinner "Checking Event Logs"
    Write-Host "`n[EVENT LOG ANALYSIS]" -ForegroundColor Yellow
    $events = @("System", "Security", "Application")
    foreach ($e in $events) {
        $last = Get-WinEvent -ListLog $e -ErrorAction SilentlyContinue | Select-Object LastWriteTime
        if($last) { Write-Host "  $e : Last write $($last.LastWriteTime)" -ForegroundColor White }
    }
    
    $clear = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=1102)]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if($clear) { Write-Host "  [!] Logs cleared on: $($clear.TimeCreated)" -ForegroundColor Red }
    else { Write-Host "  [+] No log clearing traces found." -ForegroundColor Green }

    Draw-Separator
    
    # 2. Prefetch
    Show-Spinner "Analyzing Prefetch"
    Write-Host "`n[PREFETCH ANALYSIS]" -ForegroundColor Yellow
    $pf = Get-ChildItem "$env:SystemRoot\Prefetch\*.pf" -ErrorAction SilentlyContinue
    Write-Host "  Total Files: $($pf.Count)" -ForegroundColor White
    $suspicious = $pf | Where-Object { $_.Attributes -match "Hidden|ReadOnly" }
    if($suspicious) { Write-Host "  [!] Suspicious Attributes: $($suspicious.Count)" -ForegroundColor Red }
    else { Write-Host "  [+] Prefetch Attributes Clean." -ForegroundColor Green }

    Draw-Separator

    # 3. Recycle Bin
    Show-Spinner "Scanning Recycle Bin"
    Write-Host "`n[RECYCLE BIN SCAN]" -ForegroundColor Yellow
    $rb = Get-ChildItem "$env:SystemDrive\`$Recycle.Bin" -Recurse -ErrorAction SilentlyContinue
    Write-Host "  Items found: $($rb.Count)" -ForegroundColor White
    if($rb) {
        $latest = $rb | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "  Latest: $($latest.Name) at $($latest.LastWriteTime)" -ForegroundColor Gray
    }

    Draw-Separator

    # 4. Scheduled Tasks
    Show-Spinner "Listing Scheduled Tasks"
    Write-Host "`n[SCHEDULED TASKS]" -ForegroundColor Yellow
    Get-ScheduledTask | Where-Object State -eq 'Ready' | Select-Object TaskName, Author | Format-Table -AutoSize
}

# --- MODULE 6: PERFORMANCE ---
function Invoke-PerformanceModule {
    Draw-Header "MODULE 6/6: PERFORMANCE MONITOR"
    
    Show-Spinner "Sorting Processes"
    Write-Host "`n[TOP 5 CPU HOGS]" -ForegroundColor Yellow
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property Name, CPU, Id | Format-Table -AutoSize
    
    Draw-Separator
    
    Write-Host "[TOP 5 MEMORY HOGS]" -ForegroundColor Yellow
    Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 -Property Name, @{Name="Memory(MB)";Expression={[math]::Round($_.WorkingSet/1MB,2)}} | Format-Table -AutoSize

    Draw-Separator

    Show-Spinner "Checking for Updates"
    Write-Host "`n[WINDOWS UPDATES]" -ForegroundColor Yellow
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search("IsInstalled=0")
        Write-Host "  Pending Updates Found: " -NoNewline
        Write-Host $result.Updates.Count -ForegroundColor $(if($result.Updates.Count -gt 0){'Red'}else{'Green'})
    } catch {
        Write-Host "  Could not query Windows Update." -ForegroundColor Gray
    }
}


# --- MAIN EXECUTION ---

Clear-Host

# ASCII Art Header
Write-Host @"
   ____  ___  ____   __   __ _  ____  _   _ 
  |  _ \|_ _||  _ \  \ \ / /| ||  _ \| | | |
  | |_) || | | |_) |  \ V / | || |_) | | | |
  |  __/ | | |  _ <    | |  | ||  __/| |_| |
  |_|   |___||_| \_\   |_|  |_||_|    \___/ 
"@ -ForegroundColor Cyan
Write-Host "   AUTOMATED DIAGNOSTIC SCAN" -ForegroundColor White
Write-Host ""
Write-Host "Initiating full sequence scan..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# Run Modules Automatically
Invoke-SystemModule
Start-Sleep -Seconds 1

Invoke-ServicesModule
Start-Sleep -Seconds 1

Invoke-NetworkModule
Start-Sleep -Seconds 1

Invoke-SecurityModule
Start-Sleep -Seconds 1

Invoke-ForensicsModule
Start-Sleep -Seconds 1

Invoke-PerformanceModule

# Final Summary
Draw-Header "SCAN COMPLETE"
Write-Host "  All modules executed successfully." -ForegroundColor Green
Write-Host "  Review the logs above for issues." -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor DarkGray
 $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
