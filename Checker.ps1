 $isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║           ADMINISTRATOR PRIVILEGES REQUIRED       ║" -ForegroundColor Magenta
    Write-Host "║     Please run this script as Administrator!      ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Magenta
    exit
}

Write-Host "made with love by Nic<3" -ForegroundColor Magenta
Write-Host ""

try {
    $bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $uptime = (Get-Date) - $bootTime
    Write-Host "SYSTEM BOOT TIME" -ForegroundColor Magenta
    Write-Host ("  Last Boot: {0}" -f $bootTime.ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor White
    Write-Host ("  Uptime: {0} days, {1:D2}:{2:D2}:{3:D2}" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds) -ForegroundColor Cyan
} catch {
    Write-Host "Unable to retrieve boot time information" -ForegroundColor Red
}

# --- NETWORK INFO (IP & Gateway Removed) ---
Write-Host "`nNETWORK ADAPTERS" -ForegroundColor Magenta
try {
    $adapters = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }
    if ($adapters) {
        foreach ($adapter in $adapters) {
            Write-Host ("  {0,-20} : {1}" -f "Interface", $adapter.InterfaceAlias) -ForegroundColor White
            Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  No active internet connection found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Unable to retrieve network information." -ForegroundColor Red
}

 $drives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -ne 5 }
if ($drives) {
    Write-Host "`nCONNECTED DRIVES" -ForegroundColor Magenta
    foreach ($drive in $drives) {
        $freeSpace = [math]::Round($drive.FreeSpace / 1GB, 2)
        $size = [math]::Round($drive.Size / 1GB, 2)
        Write-Host ("  {0}: {1} ({2} GB Free / {3} GB Total)" -f $drive.DeviceID, $drive.FileSystem, $freeSpace, $size) -ForegroundColor Cyan
    }
}

Write-Host "`nSERVICE STATUS" -ForegroundColor Magenta

 $services = @(
    @{Name = "SysMain"; DisplayName = "SysMain"},
    @{Name = "PcaSvc"; DisplayName = "Program Compatibility Assistant Service"},
    @{Name = "DPS"; DisplayName = "Diagnostic Policy Service"},
    @{Name = "EventLog"; DisplayName = "Windows Event Log"},
    @{Name = "Schedule"; DisplayName = "Task Scheduler"},
    @{Name = "Bam"; DisplayName = "Background Activity Moderator"},
    @{Name = "Dusmsvc"; DisplayName = "Data Usage"},
    @{Name = "Appinfo"; DisplayName = "Application Information"},
    @{Name = "CDPSvc"; DisplayName = "Connected Devices Platform Service"},
    @{Name = "DcomLaunch"; DisplayName = "DCOM Server Process Launcher"},
    @{Name = "PlugPlay"; DisplayName = "Plug and Play"},
    @{Name = "wsearch"; DisplayName = "Windows Search"},
    @{Name = "WinDefend"; DisplayName = "Windows Defender"}
)

foreach ($svc in $services) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -eq "Running") {
            $displayName = $service.DisplayName
            if ($displayName.Length -gt 40) {
                $displayName = $displayName.Substring(0, 37) + "..."
            }
            Write-Host ("  {0,-12} {1,-40}" -f $svc.Name, $displayName) -ForegroundColor Cyan -NoNewline
            
            if ($svc.Name -eq "Bam") {
                Write-Host " | Enabled" -ForegroundColor Yellow
            } else {
                try {
                    $process = Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'" | Select-Object ProcessId
                    if ($process.ProcessId -gt 0) {
                        $proc = Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
                        if ($proc) {
                            Write-Host (" | {0}" -f $proc.StartTime.ToString("HH:mm:ss")) -ForegroundColor Yellow
                        } else {
                            Write-Host " | N/A" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host " | N/A" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host " | N/A" -ForegroundColor Yellow
                }
            }
        } else {
            $displayName = $service.DisplayName
            if ($displayName.Length -gt 40) {
                $displayName = $displayName.Substring(0, 37) + "..."
            }
            Write-Host ("  {0,-12} {1,-40} {2}" -f $svc.Name, $displayName, $service.Status) -ForegroundColor Red
        }
    } else {
        Write-Host ("  {0,-12} {1,-40} {2}" -f $svc.Name, "Not Found", "Stopped") -ForegroundColor Yellow
    }
}

Write-Host "`nREGISTRY" -ForegroundColor Magenta

 $settings = @(
    @{ Name = "CMD"; Path = "HKCU:\Software\Policies\Microsoft\Windows\System"; Key = "DisableCMD"; Warning = "Disabled"; Safe = "Available" },
    @{ Name = "PowerShell Logging"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"; Key = "EnableScriptBlockLogging"; Warning = "Disabled"; Safe = "Enabled" },
    @{ Name = "Activities Cache"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Key = "EnableActivityFeed"; Warning = "Disabled"; Safe = "Enabled" },
    @{ Name = "Prefetch Enabled"; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"; Key = "EnablePrefetcher"; Warning = "Disabled"; Safe = "Enabled" }
)

foreach ($s in $settings) {
    $status = Get-ItemProperty -Path $s.Path -Name $s.Key -ErrorAction SilentlyContinue
    Write-Host "  " -NoNewline
    if ($status -and $status.$($s.Key) -eq 0) {
        Write-Host "$($s.Name): " -NoNewline -ForegroundColor White
        Write-Host "$($s.Warning)" -ForegroundColor Red
    } else {
        Write-Host "$($s.Name): " -NoNewline -ForegroundColor White
        Write-Host "$($s.Safe)" -ForegroundColor Cyan
    }
}

function Check-EventLog {
    param ($logName, $eventID, $message)
    $event = Get-WinEvent -LogName $logName -FilterXPath "*[System[EventID=$eventID]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($event) {
        Write-Host "  $message at: " -NoNewline -ForegroundColor White
        Write-Host $event.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
    } else {
        Write-Host "  $message - No records found" -ForegroundColor Cyan
    }
}

function Check-RecentEventLog {
    param ($logName, $eventIDs, $message)
    $event = Get-WinEvent -LogName $logName -FilterXPath "*[System[EventID=$($eventIDs -join ' or EventID=')]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($event) {
        Write-Host "  $message (ID: $($event.Id)) at: " -NoNewline -ForegroundColor White
        Write-Host $event.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
    } else {
        Write-Host "  $message - No records found" -ForegroundColor Cyan
    }
}

function Check-DeviceDeleted {
    try {
        $event = Get-WinEvent -LogName "Microsoft-Windows-Kernel-PnP/Configuration" -FilterXPath "*[System[EventID=400]]" -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($event) {
            Write-Host "  Device configuration changed at: " -NoNewline -ForegroundColor White
            Write-Host $event.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
            return
        }
    } catch {}

    try {
        $event = Get-WinEvent -FilterHashtable @{LogName="System"; ID=225} -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($event) {
            Write-Host "  Device removed at: " -NoNewline -ForegroundColor White
            Write-Host $event.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
            return
        }
    } catch {}

    try {
        $events = Get-WinEvent -LogName "System" | Where-Object {$_.Id -eq 225 -or $_.Id -eq 400} | Sort-Object TimeCreated -Descending | Select-Object -First 1
        if ($events) {
            Write-Host "  Last device change at: " -NoNewline -ForegroundColor White
            Write-Host $events.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
            return
        }
    } catch {}

    Write-Host "  Device changes - No records found" -ForegroundColor Cyan
}

Write-Host "`nEVENT LOGS" -ForegroundColor Magenta

Check-EventLog "Application" 3079 "USN Journal cleared"
Check-RecentEventLog "System" @(104, 1102) "Event Logs cleared"
Check-EventLog "System" 1074 "Last PC Shutdown"
Check-EventLog "Security" 4616 "System time changed"
Check-EventLog "System" 6005 "Event Log Service started"
Check-DeviceDeleted


 $prefetchPath = "$env:SystemRoot\Prefetch"
if (Test-Path $prefetchPath) {
    Write-Host "`nPREFETCH INTEGRITY" -ForegroundColor Magenta
    
    $files = Get-ChildItem -Path $prefetchPath -Filter *.pf -Force -ErrorAction SilentlyContinue
    if (-not $files) {
        Write-Host "  No prefetch found?? Check the folder please" -ForegroundColor Yellow
    } else {
        $hashTable = @{}
        $suspiciousFiles = @{}
        $totalFiles = $files.Count

        $hiddenFiles = @()
        $readOnlyFiles = @()
        $hiddenAndReadOnlyFiles = @()
        $errorFiles = @()

        foreach ($file in $files) {
            try {
                $isHidden = $file.Attributes -band [System.IO.FileAttributes]::Hidden
                $isReadOnly = $file.Attributes -band [System.IO.FileAttributes]::ReadOnly
                
                if ($isHidden -and $isReadOnly) {
                    $hiddenAndReadOnlyFiles += $file
                    if (-not $suspiciousFiles.ContainsKey($file.Name)) {
                        $suspiciousFiles[$file.Name] = "Hidden and Read-only"
                    }
                } elseif ($isHidden) {
                    $hiddenFiles += $file
                    if (-not $suspiciousFiles.ContainsKey($file.Name)) {
                        $suspiciousFiles[$file.Name] = "Hidden file"
                    }
                } elseif ($isReadOnly) {
                    $readOnlyFiles += $file
                    if (-not $suspiciousFiles.ContainsKey($file.Name)) {
                        $suspiciousFiles[$file.Name] = "Read-only file"
                    }
                }

                $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue
                if ($hash) {
                    if ($hashTable.ContainsKey($hash.Hash)) {
                        $hashTable[$hash.Hash].Add($file.Name)
                    } else {
                        $hashTable[$hash.Hash] = [System.Collections.Generic.List[string]]::new()
                        $hashTable[$hash.Hash].Add($file.Name)
                    }
                }
            } catch {
                $errorFiles += $file
                if (-not $suspiciousFiles.ContainsKey($file.Name)) {
                    $suspiciousFiles[$file.Name] = "Error analyzing file: $($_.Exception.Message)"
                }
            }
        }

        if ($hiddenAndReadOnlyFiles.Count -gt 0) {
            Write-Host "  Hidden & Read-only Files: $($hiddenAndReadOnlyFiles.Count) found" -ForegroundColor Yellow
            foreach ($file in $hiddenAndReadOnlyFiles) {
                Write-Host ("    {0}" -f $file.Name) -ForegroundColor White
            }
        }

        if ($hiddenFiles.Count -gt 0) {
            Write-Host "  Hidden Files: $($hiddenFiles.Count) found" -ForegroundColor Yellow
            foreach ($file in $hiddenFiles) {
                Write-Host ("    {0}" -f $file.Name) -ForegroundColor White
            }
        } else {
            Write-Host "  Hidden Files: None" -ForegroundColor Cyan
        }

        if ($readOnlyFiles.Count -gt 0) {
            Write-Host "  Read-Only Files: $($readOnlyFiles.Count)" -ForegroundColor Yellow
            foreach ($file in $readOnlyFiles) {
                Write-Host ("    {0}" -f $file.Name) -ForegroundColor White
            }
        } else {
            Write-Host "  Read-Only Files: None" -ForegroundColor Cyan
        }

        $repeatedHashes = $hashTable.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
        if ($repeatedHashes) {
            Write-Host "  Duplicate Files: $($repeatedHashes.Count) sets found" -ForegroundColor Yellow
            foreach ($entry in $repeatedHashes) {
                foreach ($file in $entry.Value) {
                    if (-not $suspiciousFiles.ContainsKey($file)) {
                        $suspiciousFiles[$file] = "Duplicate file"
                    }
                }
                Write-Host ("    Duplicate set: {0}" -f ($entry.Value -join ", ")) -ForegroundColor White
            }
        } else {
            Write-Host "  Duplicates: None" -ForegroundColor Cyan
        }

        if ($suspiciousFiles.Count -gt 0) {
            Write-Host "`n  SUSPICIOUS FILES FOUND: $($suspiciousFiles.Count)/$totalFiles" -ForegroundColor Yellow
            foreach ($entry in $suspiciousFiles.GetEnumerator() | Sort-Object Key) {
                Write-Host ("    {0} : {1}" -f $entry.Key, $entry.Value) -ForegroundColor White
            }
        } else {
            Write-Host "`n  Prefetch integrity: Clean ($totalFiles files checked)" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "`nCouldnt find prefetch folder?? (check yo paths hoe)" -ForegroundColor Red
}

try {
    $recycleBinPath = "$env:SystemDrive" + '\$Recycle.Bin'
    
    Write-Host "`nRecycle Bin" -ForegroundColor Magenta

    if (Test-Path $recycleBinPath) {
        $recycleBinFolder = Get-Item -LiteralPath $recycleBinPath -Force
        $userFolders = Get-ChildItem -LiteralPath $recycleBinPath -Directory -Force -ErrorAction SilentlyContinue
        
        if ($userFolders) {
            $allDeletedItems = @()
            $latestModTime = $recycleBinFolder.LastWriteTime
            
            foreach ($userFolder in $userFolders) {
                if ($userFolder.LastWriteTime -gt $latestModTime) {
                    $latestModTime = $userFolder.LastWriteTime
                }
                
                $userItems = Get-ChildItem -LiteralPath $userFolder.FullName -File -Force -ErrorAction SilentlyContinue
                if ($userItems) {
                    $allDeletedItems += $userItems
                    
                    $latestFile = $userItems | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    if ($latestFile -and $latestFile.LastWriteTime -gt $latestModTime) {
                        $latestModTime = $latestFile.LastWriteTime
                    }
                }
            }
            
            Write-Host "  Last Modified: " -NoNewline -ForegroundColor White
            Write-Host $latestModTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Yellow
            
            if ($allDeletedItems.Count -gt 0) {
                Write-Host "  Total Items: " -NoNewline -ForegroundColor White
                Write-Host $allDeletedItems.Count -ForegroundColor Yellow
                
                $latestItem = $allDeletedItems | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Host "  Latest Item: " -NoNewline -ForegroundColor White
                Write-Host $latestItem.Name -ForegroundColor Gray
            } else {
                Write-Host "  Status: " -NoNewline -ForegroundColor White
                Write-Host "Folders present but empty" -ForegroundColor Cyan
            }
        } else {
            Write-Host "  Status: " -NoNewline -ForegroundColor White
            Write-Host "Emptyy" -ForegroundColor Cyan
            Write-Host "  Last Modified: " -NoNewline -ForegroundColor White
            Write-Host $recycleBinFolder.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Cyan
        }
        
        $clearEvent = Get-WinEvent -FilterHashtable @{LogName="System"; Id=10006} -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($clearEvent) {
            Write-Host "  Last Cleared (Event): " -NoNewline -ForegroundColor White
            Write-Host $clearEvent.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Red
        }
    } else {
        Write-Host "  Recycle Bin not found at: $recycleBinPath" -ForegroundColor Yellow
        Write-Host "  Note: Recycle Bin may be empty or on different drive" -ForegroundColor Gray
    }


    $consoleHistoryPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
    Write-Host "`n  Console Host History:" -ForegroundColor Magenta
    
    if (Test-Path $consoleHistoryPath) {
        $historyFile = Get-Item -Path $consoleHistoryPath -Force
        Write-Host "    Last Modified: " -NoNewline -ForegroundColor White
        Write-Host $historyFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Yellow
        

        $attributes = $historyFile.Attributes
        if ($attributes -ne "Archive") {
            Write-Host "    Attributes: " -NoNewline -ForegroundColor White
            Write-Host $attributes -ForegroundColor Yellow
        } else {
            Write-Host "    Attributes: Normal" -ForegroundColor Cyan
        }
        

        $fileSize = $historyFile.Length
        Write-Host "    File Size: " -NoNewline -ForegroundColor White
        Write-Host "$([math]::Round($fileSize/1024, 2)) KB" -ForegroundColor Yellow
        
    } else {
        Write-Host "    File not found: $consoleHistoryPath" -ForegroundColor Yellow
        Write-Host "    Note: PowerShell history may be disabled or never used" -ForegroundColor Gray
    }

} catch {
    Write-Host "  Error accessing system information: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nWINDOWS UPDATES (Last 5)" -ForegroundColor Magenta
try {
    $updates = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5
    if ($updates) {
        foreach ($u in $updates) {
            Write-Host ("  {0,-15} {1}" -f $u.HotFixID, $u.InstalledOn.ToString("yyyy-MM-dd")) -ForegroundColor White
        }
    } else {
        Write-Host "  No updates found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Unable to retrieve updates." -ForegroundColor Red
}

Write-Host "`nBIOS INFO" -ForegroundColor Magenta
try {
    $bios = Get-CimInstance Win32_BIOS
    Write-Host ("  {0,-20} : {1}" -f "Manufacturer", $bios.Manufacturer) -ForegroundColor White
    Write-Host ("  {0,-20} : {1}" -f "Serial Number", $bios.SerialNumber) -ForegroundColor White
    Write-Host ("  {0,-20} : {1}" -f "Version", $bios.SMBIOSBIOSVersion) -ForegroundColor Cyan
} catch {
    Write-Host "  Unable to retrieve BIOS info." -ForegroundColor Red
}

# --- NEW: GPU INFO ---
Write-Host "`nVIDEO CARD (GPU)" -ForegroundColor Magenta
try {
    $gpu = Get-CimInstance Win32_VideoController
    Write-Host ("  Name : {0}" -f $gpu.Name) -ForegroundColor White
    $vram = [math]::Round($gpu.AdapterRAM / 1GB, 2)
    Write-Host ("  VRAM : {0} GB" -f $vram) -ForegroundColor Cyan
} catch {
    Write-Host "  Unable to retrieve GPU info." -ForegroundColor Red
}

# --- NEW: MOTHERBOARD INFO ---
Write-Host "`nMOTHERBOARD" -ForegroundColor Magenta
try {
    $mobo = Get-CimInstance Win32_BaseBoard
    Write-Host ("  Manufacturer : {0}" -f $mobo.Manufacturer) -ForegroundColor White
    Write-Host ("  Product      : {0}" -f $mobo.Product) -ForegroundColor Cyan
} catch {
    Write-Host "  Unable to retrieve Motherboard info." -ForegroundColor Red
}

# --- NEW: TEMP FOLDER STATUS ---
Write-Host "`nTEMP FOLDER STATUS" -ForegroundColor Magenta
try {
    $tempPath = $env:TEMP
    if (Test-Path $tempPath) {
        $tempInfo = Get-Item $tempPath
        Write-Host ("  Location       : {0}" -f $tempPath) -ForegroundColor Gray
        Write-Host ("  Last Write     : {0}" -f $tempInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor White
        Write-Host ("  Last Access    : {0}" -f $tempInfo.LastAccessTime.ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor White
        
        # Check Recycle Bin for recently deleted temp files
        $deletedTemps = Get-ChildItem "$env:SystemDrive\`$Recycle.Bin" -Recurse -Filter "*.tmp" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) }
        if ($deletedTemps) {
            Write-Host ("  Recent Deletions: {0} .tmp files in Recycle Bin" -f $deletedTemps.Count) -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  Unable to retrieve Temp folder info." -ForegroundColor Red
}

# --- NEW: RECENT FOLDER ACTIVITY (LAST 10 MINS) ---
Write-Host "`nRECENT FOLDER ACTIVITY (Last 10 Mins)" -ForegroundColor Magenta
Write-Host "  Scanning user directories..." -ForegroundColor DarkGray
try {
    $cutoff = (Get-Date).AddMinutes(-10)
    $searchPaths = @("$env:USERPROFILE", "$env:PUBLIC")
    $activeFolders = @()
    
    foreach ($path in $searchPaths) {
         if (Test-Path $path) {
             # Scan recursively
             $folders = Get-ChildItem $path -Recurse -Directory -ErrorAction SilentlyContinue
             $recent = $folders | Where-Object { $_.LastWriteTime -gt $cutoff }
             $activeFolders += $recent
         }
    }

    if ($activeFolders) {
         # Exclude noise: AppData, Temp, Windows, ProgramData
         $noisePatterns = @("*AppData*", "*Temp*", "*Windows*", "*ProgramData*")
         
         $cleanList = $activeFolders | Where-Object {
             $isNoise = $false
             foreach ($pattern in $noisePatterns) {
                 if ($_.FullName -like $pattern) { $isNoise = $true; break }
             }
             -not $isNoise
         }

         if ($cleanList) {
            $top5 = $cleanList | Sort-Object LastWriteTime -Descending | Select-Object -First 5
            foreach ($f in $top5) {
                Write-Host ("  Path: {0}" -f $f.FullName) -ForegroundColor Cyan
                Write-Host ("    Modified: {0}" -f $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor White
            }
         } else {
            Write-Host "  Only system folder activity detected (noise filtered)." -ForegroundColor Gray
         }
    } else {
         Write-Host "  No folders modified in the last 10 minutes." -ForegroundColor Gray
    }
} catch {
    Write-Host "  Error scanning folder activity." -ForegroundColor Red
}

Write-Host "`nCheck Complete, hit up @Nic if u run into any issues." -ForegroundColor Magenta
