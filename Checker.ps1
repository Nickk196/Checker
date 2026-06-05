<#
.SYNOPSIS
    NEON TERMINAL // DEEP SYSTEM AUDIT
.NOTES
    Custom UI Logic // Socket Scanning // Driver Forensics
#>

 $ErrorActionPreference = "SilentlyContinue"

# --- CHECK PRIVILEGES ---
if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ACCESS DENIED: ADMIN RIGHTS REQUIRED." -ForegroundColor Red
    Start-Sleep 2; exit
}

# --- VISUAL FUNCTIONS ---

function Draw-Box {
    param([string]$Title, [string]$Color = "Cyan")
    $width = 80
    Write-Host "`n┌─ $Title " -NoNewline -ForegroundColor $Color
    Write-Host ("─" * ($width - $Title.Length - 5)) -ForegroundColor $Color
}

function Write-Status {
    param([string]$Msg, [string]$Status)
    $pad = 60 - $Msg.Length
    Write-Host "  $Msg" -NoNewline -ForegroundColor White
    Write-Host ("." * $pad) -NoNewline -ForegroundColor DarkGray
    
    if ($Status -eq "OK")     { Write-Host " [✓]" -ForegroundColor Green }
    elseif ($Status -eq "FAIL") { Write-Host " [✗]" -ForegroundColor Red }
    elseif ($Status -eq "WARN") { Write-Host " [!]" -ForegroundColor Yellow }
    else { Write-Host " [$Status]" -ForegroundColor Gray }
}

function Beep-Complete {
    [console]::beep(800, 200)
    Start-Sleep -m 100
    [console]::beep(1200, 400)
}

# --- CORE SCANNING LOGIC ---

function Test-LocalPorts {
    Write-Host "  Scanning Local Sockets..." -ForegroundColor Gray
    $commonPorts = @(21, 22, 80, 443, 8080, 3389, 5900, 445)
    $openPorts = @()
    
    foreach ($port in $commonPorts) {
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $tcp.Connect("127.0.0.1", $port)
            $openPorts += $port
            $tcp.Close()
        } catch { }
    }
    return $openPorts
}

function Get-UnsignedDrivers {
    # Checks for drivers without a digital signature (Malware risk)
    $drivers = Get-WindowsDriver -Online | Where-Object { $_.OriginalFileName -like "*.sys" }
    $unsigned = $drivers | Where-Object { $_.Signer -like "*unsigned*" -or $_.Signer -eq $null }
    return $unsigned
}

function Get-NetworkListeners {
    # See what executable is listening on ports
    $listeners = Get-NetTCPConnection -State Listen | Select-Object -First 5
    return $listeners
}

# --- MAIN EXECUTION ---

Clear-Host
Write-Host @"
 __  __  ____  ____  ____    ____   ___   _  _   ____  _   _ 
|  \/  ||  _ \|  _ \|  _ \  / ___| / _ \ | || | |  _ \| | | |
| |\/| || |_) | | | | | | | \___ \| | | || || |_| | | | |_| |
| |  | ||  __/| |_| | |_| |  ___) | |_| ||__   _| |_| |  _  |
|_|  |_||_|   |____/|____/  |____/ \___/   |_| |____/|_| |_|
"@ -ForegroundColor Magenta
Write-Host " [AUTONOMOUS DIAGNOSTIC PROTOCOL INITIATED] `n" -ForegroundColor Cyan

# --- SECTION 1: FIRMWARE & OS ---
Draw-Box "KERNEL & FIRMWARE"
 $os = Get-CimInstance Win32_OperatingSystem
Write-Host "  OS    : $($os.Caption)" -ForegroundColor White
Write-Host "  Build : $($os.BuildNumber)" -ForegroundColor Gray
Write-Host "  Uptime: $((Get-Date) - $os.LastBootUpTime | Select-Object -ExpandProperty Days) Days" -ForegroundColor Gray

# --- SECTION 2: SECURITY HOLE CHECKING ---
Draw-Box "SECURITY AUDIT" "Yellow"

# Check RDP
 $rdp = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server").fDenyTSConnections
if ($rdp -eq 0) { Write-Status "Remote Desktop (RDP)" "FAIL (Open)" }
else { Write-Status "Remote Desktop (RDP)" "OK" }

# Check Guest Account
 $guest = Get-LocalUser -Name "Guest"
if ($guest.Enabled) { Write-Status "Guest Account" "FAIL (Enabled)" }
else { Write-Status "Guest Account" "OK" }

# Check Admin Password Policy
 $passPolicy = Get-LocalUser | Where-Object { $_.SID -like "*-500" }
if ($passPolicy.PasswordLastSet -eq $null) { Write-Status "Admin Password Set" "WARN" }
else { Write-Status "Admin Password Set" "OK" }

# --- SECTION 3: ACTIVE NETWORKING ---
Draw-Box "NETWORK SURVEILLANCE" "Magenta"

 $ports = Test-LocalPorts
Write-Host "  Open Common Ports: " -NoNewline -ForegroundColor Gray
if ($ports.Count -gt 0) { Write-Host ($ports -join ", ") -ForegroundColor Yellow }
else { Write-Host "None" -ForegroundColor Green }

Write-Host "`n  ACTIVE LISTENERS (Top 5):" -ForegroundColor Gray
Get-NetworkListeners | ForEach-Object {
    $process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host ("    Port: {0,5} -> " -f $_.LocalPort) -NoNewline -ForegroundColor White
        Write-Host $process.ProcessName -ForegroundColor Cyan
    }
}

# --- SECTION 4: DRIVER FORENSICS ---
Draw-Box "DRIVER INTEGRITY" "Yellow"
Write-Host "  Scanning System32 Drivers for Signatures..." -ForegroundColor Gray
 $badDrivers = Get-UnsignedDrivers

if ($badDrivers) {
    Write-Host "  [!] UNSIGNED DRIVERS DETECTED:" -ForegroundColor Red
    $badDrivers | Select-Object -First 3 | ForEach-Object {
        Write-Host ("    - " + $_.OriginalFileName) -ForegroundColor DarkRed
    }
} else {
    Write-Status "Digital Signature Check" "OK"
}

# --- SECTION 5: PROCESS ANOMALIES ---
Draw-Box "PROCESS ANOMALY DETECTION" "Green"

# Check for processes masquerading (e.g., svchost.exe running from wrong path)
 $svchost = Get-Process -Name svchost -ErrorAction SilentlyContinue
if ($svchost) {
    $badPath = $false
    foreach ($proc in $svchost) {
        if ($proc.Path -notlike "*System32*") {
            Write-Host "  [!] SUSPICIOUS SVCHOST: $($proc.Path)" -ForegroundColor Red
            $badPath = $true
        }
    }
    if (-not $badPath) { Write-Status "Svchost Integrity" "OK" }
} else {
    Write-Status "Svchost Running" "OK" 
}

# Check high CPU usage
 $highCpu = Get-Process | Where-Object { $_.CPU -gt 10 } | Select-Object -First 3
if ($highCpu) {
    Write-Host "  High Load Processes:" -ForegroundColor Yellow
    $highCpu | ForEach-Object { Write-Host "    - $($_.Name) ($($_.CPU))" -ForegroundColor Gray }
}

# --- SECTION 6: REGISTRY CHECKS ---
Draw-Box "REGISTRY ARTIFACTS" "Cyan"

# Persistence Keys
 $runKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)

 $persistenceFound = $false
foreach ($key in $runKeys) {
    $items = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
    if ($items.PSObject.Properties.Name -notcontains "PSPath") { continue }
    
    foreach ($prop in $items.PSObject.Properties) {
        if ($prop.Name -notin @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) {
            $val = $prop.Value
            # Simple heuristics for weird looking paths
            if ($val -like "*temp*" -or $val -like "*Downloads*") {
                Write-Host "  [!] SUSPICIOUS STARTUP: $($prop.Name) -> $val" -ForegroundColor Red
                $persistenceFound = $true
            }
        }
    }
}
if (-not $persistenceFound) { Write-Status "Startup Locations" "OK" }

# --- FINAL ---
Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║                    SCAN SEQUENCE COMPLETE                      ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

Beep-Complete
Write-Host "`nPress any key to terminate session..." -ForegroundColor DarkGray
 $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
