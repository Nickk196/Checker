 $isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║           ADMINISTRATOR PRIVILEGES REQUIRED       ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Red
    exit
}

Write-Host "made with love by lily<3" -ForegroundColor Cyan
Write-Host ""

# --- MODULE 1: NETWORK LISTENERS ---
Write-Host "NETWORK LISTENERS" -ForegroundColor Cyan

try {
    $listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -notlike "127.0.0.1" -and $_.LocalAddress -notlike "::1" }
    
    if ($listeners) {
        Write-Host "  Active Listening Ports (External Facing):" -ForegroundColor White
        foreach ($listener in $listeners) {
            try {
                $process = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
                $procName = if ($process) { $process.ProcessName } else { "Unknown" }
                
                Write-Host ("  {0,-8} {1,-40}" -f $listener.LocalPort, $procName) -ForegroundColor Green -NoNewline
                Write-Host (" | {0}" -f $listener.LocalAddress) -ForegroundColor Yellow
            } catch {
                Write-Host ("  {0,-8} {1,-40}" -f $listener.LocalPort, "Access Denied") -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  No external listening ports found." -ForegroundColor Green
    }
} catch {
    Write-Host "  Unable to retrieve network listeners." -ForegroundColor Red
}

# --- MODULE 2: ACTIVE USERS ---
Write-Host "`nACTIVE USER SESSIONS" -ForegroundColor Cyan

try {
    $users = Get-CimInstance -ClassName Win32_LoggedOnUser -ErrorAction SilentlyContinue | Select-Object -Unique
    if ($users) {
        Write-Host "  Logged in users:" -ForegroundColor White
        foreach ($user in $users) {
            $name = $user.Antecedent -replace '.+Domain="(.+?)".+', '$1'
            $account = $user.Antecedent -replace '.+Name="(.+?)".+', '$1'
            Write-Host ("  {0,-20} {1}" -f "$name\$account", $user.Dependent) -ForegroundColor Yellow
        }
    } else {
        Write-Host "  No user sessions detected." -ForegroundColor Gray
    }
} catch {
    Write-Host "  Unable to retrieve user sessions." -ForegroundColor Red
}

# --- MODULE 3: STARTUP PERSISTENCE ---
Write-Host "`nSTARTUP PERSISTENCE CHECK" -ForegroundColor Cyan

 $runKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)

 $suspicousFound = $false

foreach ($keyPath in $runKeys) {
    if (Test-Path $keyPath) {
        $items = Get-Item -Path $keyPath
        foreach ($item in $items.Property) {
            $value = (Get-ItemProperty -Path $keyPath -Name $item).$item
            $valueString = $value.ToString()
            
            # Heuristic: Check for AppData, Temp, or Downloads in startup path
            if ($valueString -like "*AppData\Local\Temp*" -or $valueString -like "*Downloads*") {
                $suspicousFound = $true
                Write-Host ("  {0,-30} {1}" -f $item, $valueString) -ForegroundColor Red
            }
        }
    }
}

if (-not $suspicousFound) {
    Write-Host "  No suspicious startup entries found." -ForegroundColor Green
}

# --- MODULE 4: UNSIGNED DRIVERS ---
Write-Host "`nDRIVER INTEGRITY" -ForegroundColor Cyan

try {
    $drivers = Get-WindowsDriver -Online -ErrorAction SilentlyContinue | Where-Object { $_.OriginalFileName -like "*.sys" }
    $unsignedDrivers = @()

    foreach ($driver in $drivers) {
        if ($driver.Signer -like "*unsigned*" -or $driver.Signer -eq $null) {
            $unsignedDrivers += $driver
        }
    }

    if ($unsignedDrivers.Count -gt 0) {
        Write-Host ("  Unsigned Drivers Found: {0}" -f $unsignedDrivers.Count) -ForegroundColor Yellow
        foreach ($driver in $unsignedDrivers) {
            $name = $driver.OriginalFileName
            if ($name.Length -gt 50) { $name = $name.Substring(0, 47) + "..." }
            Write-Host ("    {0}" -f $name) -ForegroundColor Red
        }
    } else {
        Write-Host "  All drivers are digitally signed." -ForegroundColor Green
    }
} catch {
    Write-Host "  Unable to audit drivers." -ForegroundColor Red
}

# --- MODULE 5: PROCESS ANOMALIES ---
Write-Host "`nPROCESS ANOMALY DETECTION" -ForegroundColor Cyan

# Check for Svchost running outside of System32
 $svchosts = Get-Process -Name svchost -ErrorAction SilentlyContinue
if ($svchosts) {
    $badPath = $false
    foreach ($proc in $svchosts) {
        if ($proc.Path -and $proc.Path -notlike "*System32*") {
            Write-Host ("  {0,-20} {1}" -f "SUSPICIOUS SVCHOST", $proc.Path) -ForegroundColor Red
            $badPath = $true
        }
    }
    if (-not $badPath) {
        Write-Host "  Svchost path integrity verified." -ForegroundColor Green
    }
} else {
    Write-Host "  Svchost not running (Unusual)." -ForegroundColor Yellow
}

# Check for high CPU usage processes
Write-Host "  Top CPU Consumers:" -ForegroundColor White
 $topCPU = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
foreach ($proc in $topCPU) {
    $cpuTime = [math]::Round($proc.CPU, 2)
    Write-Host ("  {0,-20} CPU: {1}" -f $proc.ProcessName, "$cpuTime sec") -ForegroundColor Yellow
}

# --- MODULE 6: HOST FILE INTEGRITY ---
Write-Host "`nHOST FILE INTEGRITY" -ForegroundColor Cyan

 $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
if (Test-Path $hostsPath) {
    $content = Get-Content $hostsPath | Where-Object { $_ -notmatch "^#" -and $_.trim() -ne "" }
    $badEntries = $content | Where-Object { $_ -notmatch "^0.0.0.0" -and $_ -notmatch "^127.0.0.1" }
    
    if ($badEntries) {
        Write-Host "  Suspicious Hosts Entries Found:" -ForegroundColor Red
        foreach ($entry in $badEntries) {
            Write-Host ("    {0}" -f $entry) -ForegroundColor White
        }
    } else {
        Write-Host "  Hosts file appears clean." -ForegroundColor Green
    }
} else {
    Write-Host "  Hosts file not found." -ForegroundColor Yellow
}

Write-Host "`nDeep Scan Complete, hit up @praiselily if u run into any issues." -ForegroundColor Cyan
