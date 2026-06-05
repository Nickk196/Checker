# PowerShell Auto Clicker
# Made for Nic

# Import C# Mouse Events
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class MouseClicker {
    [DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);

    private const uint MOUSEEVENTF_LEFTDOWN = 0x02;
    private const uint MOUSEEVENTF_LEFTUP = 0x04;
    private const uint MOUSEEVENTF_RIGHTDOWN = 0x08;
    private const uint MOUSEEVENTF_RIGHTUP = 0x10;

    public static void LeftClick() {
        mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
    }

    public static void RightClick() {
        mouse_event(MOUSEEVENTF_RIGHTDOWN | MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0);
    }
}
"@

# --- UI Header ---
Clear-Host
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "           AUTO CLICKER v1.0               " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- User Inputs ---
 $clickCount = Read-Host "How many times to click? (e.g., 100, or '0' for infinite)"
 $intervalMs = Read-Host "Delay between clicks (ms)? (e.g., 100 for 0.1s)"
 $buttonChoice = Read-Host "Which button? (L for Left, R for Right)"

# --- Validation ---
if ($clickCount -eq 0) { $clickCount = [int]::MaxValue } # Max value to simulate infinite

try { $interval = [int]$intervalMs } catch { $interval = 500 }
try { $count = [int]$clickCount } catch { $count = 10 }

# --- Countdown ---
Write-Host ""
Write-Host "Starting in..." -ForegroundColor Yellow
Write-Host "3" -ForegroundColor Red
Start-Sleep -Seconds 1
Write-Host "2" -ForegroundColor Red
Start-Sleep -Seconds 1
Write-Host "1" -ForegroundColor Red
Start-Sleep -Seconds 1
Write-Host "CLICKING STARTED! (Press any key to stop)" -ForegroundColor Green
Write-Host ""

# --- Click Loop ---
for ($i = 0; $i -lt $count; $i++) {
    
    # Check if user pressed a key to stop
    if ([console]::KeyAvailable) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-Host "`nStopped by user." -ForegroundColor Red
        break
    }

    # Perform Click
    if ($buttonChoice -eq "R" -or $buttonChoice -eq "r") {
        [MouseClicker]::RightClick()
    } else {
        [MouseClicker]::LeftClick()
    }

    # Wait for interval
    Start-Sleep -Milliseconds $interval
    
    # Optional: Show progress if not infinite
    if ($count -ne [int]::MaxValue -and $i % 10 -eq 0) {
        Write-Host "`rClicks performed: $i / $count" -NoNewline
    }
}

Write-Host "`nFinished." -ForegroundColor Green
