# GPU Crash Event Viewer Checker
# Searches for display driver crashes and TDR (Timeout Detection and Recovery) events
# Created by Fjord and Claude

# ============================================
# SELF-ELEVATION TO ADMINISTRATOR
# ============================================
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Relaunch as administrator
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "GPU Crash Event Checker - by Fjord (Administrator)"

# ============================================
# CONFIGURATION
# ============================================
$discordWebhook = "https://discord.com/api/webhooks/1458739535797293159/HMi3DW6Gxq9jTgeXvMFPsCMjtH7isoGQ4er2g_1Fh4bm5AYNjKU87W0JVi4lYgIDp2Jj"
$discordInvite = "https://discord.gg/FM5gvVNSRQ"

# Create output folder in user's Documents
$outputFolder = Join-Path $env:USERPROFILE "Documents\GPU-Crash-Logs"
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputFile = Join-Path $outputFolder "GPU-Crash-Report_$timestamp.txt"

# ============================================
# FUNCTIONS
# ============================================

# Function to write to both console and file
function Write-Log {
    param($Message, $Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $Message | Out-File -FilePath $outputFile -Append -Encoding UTF8
}

# Function to show ASCII progress bar countdown
function Show-CountdownBar {
    param([int]$Seconds)

    $totalBlocks = 16
    $blockChar = [char]0x2588  # █
    $emptyChar = '-'  

    # Save cursor position for the input line
    $inputRow = [Console]::CursorTop

    # Move down 2 lines for the progress bar
    Write-Host ""
    Write-Host ""
    $barRow = [Console]::CursorTop - 1

    # Return cursor to input line
    [Console]::SetCursorPosition(0, $inputRow)

    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Seconds)

    while ((Get-Date) -lt $endTime) {
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $remaining = ($endTime - (Get-Date)).TotalSeconds
        $progress = $elapsed / $Seconds
        $filled = [Math]::Floor($totalBlocks * (1 - $progress))
        $empty = $totalBlocks - $filled

        # Draw progress bar on its own line
        $currentRow = [Console]::CursorTop
        [Console]::SetCursorPosition(0, $barRow)
        Write-Host ("[" + ($blockChar.ToString() * $filled) + ($emptyChar * $empty) + "]") -ForegroundColor Cyan -NoNewline
        [Console]::SetCursorPosition(0, $currentRow)

        Start-Sleep -Milliseconds 50

        # Check if user pressed a key (return to caller to handle)
        if ([Console]::KeyAvailable) {
            return $false  # User interrupted
        }
    }

    # Wait one extra beat after last block disappears
    Start-Sleep -Milliseconds 1000

    # Clear the progress bar line
    [Console]::SetCursorPosition(0, $barRow)
    Write-Host (" " * 30) -NoNewline
    [Console]::SetCursorPosition(0, $barRow)

    return $true  # Timed out normally
}

# Function to read input with timer - Variant 1
function Read-InputWithDefault {
    param(
        [string]$Prompt,
        [string]$DefaultValue,
        [int]$TimeoutSeconds = 60,
        [ValidateSet('Number', 'YesNo', 'Text')]
        [string]$ValidationType = 'Text',
        [int]$MaxNumber = 30
    )

    # Display prompt with default in brackets
    Write-Host "$Prompt " -ForegroundColor Cyan -NoNewline

    $userInput = ""
    $cursorStart = [Console]::CursorLeft
    $inputRow = [Console]::CursorTop

    # Timer setup - pipes at BOTTOM of screen disappearing from right to left
    $windowHeight = $Host.UI.RawUI.WindowSize.Height
    $windowWidth = $Host.UI.RawUI.WindowSize.Width
    $timerBarRow = $windowHeight - 1  # BOTTOM of screen
    $totalChars = 120  # Fine granularity
    $timerChar = '|'

    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TimeoutSeconds)
    $timedOut = $false

    while ($true) {
        # Update timer bar at BOTTOM (yellow pipes disappearing right to left)
        if ((Get-Date) -lt $endTime -and -not $timedOut) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            $progress = $elapsed / $TimeoutSeconds
            $remaining = [Math]::Ceiling($totalChars * (1 - $progress))

            # Save current cursor position
            $currentRow = [Console]::CursorTop
            $currentCol = [Console]::CursorLeft

            # Draw timer at bottom
            [Console]::SetCursorPosition(0, $timerBarRow)
            if ($remaining -gt 0) {
                Write-Host ($timerChar * $remaining) -NoNewline -ForegroundColor Yellow
            }
            # Clear rest of line
            $clearSpace = $windowWidth - $remaining
            if ($clearSpace -gt 0) {
                Write-Host (" " * $clearSpace) -NoNewline
            }

            # Return cursor to input position
            [Console]::SetCursorPosition($currentCol, $currentRow)
        }
        elseif (-not $timedOut) {
            # Timeout reached
            $timedOut = $true

            # Clear timer bar completely
            [Console]::SetCursorPosition(0, $timerBarRow)
            Write-Host (" " * $windowWidth) -NoNewline

            # If user typed valid input but didn't hit Enter, use their input instead of default
            [Console]::SetCursorPosition($cursorStart, $inputRow)
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                # No input typed - use default
                Write-Host $DefaultValue -ForegroundColor White
                return $DefaultValue
            } else {
                # User typed something - use it
                Write-Host $userInput -ForegroundColor White
                return $userInput
            }
        }

        # Check for user input
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)

            if ($key.Key -eq 'Enter') {
                # Clear timer bar at top
                [Console]::SetCursorPosition(0, $timerBarRow)
                Write-Host (" " * $windowWidth) -NoNewline
                [Console]::SetCursorPosition($cursorStart, $inputRow)

                # If nothing typed, use default
                if ([string]::IsNullOrWhiteSpace($userInput)) {
                    Write-Host $DefaultValue -ForegroundColor White
                    return $DefaultValue
                }

                # User typed something valid
                Write-Host ""
                return $userInput
            }
            elseif ($key.Key -eq 'Backspace') {
                if ($userInput.Length -gt 0) {
                    $userInput = $userInput.Substring(0, $userInput.Length - 1)
                    [Console]::SetCursorPosition([Console]::CursorLeft - 1, [Console]::CursorTop)
                    Write-Host " " -NoNewline
                    [Console]::SetCursorPosition([Console]::CursorLeft - 1, [Console]::CursorTop)
                }
            }
            elseif ($key.KeyChar -eq ' ') {
                # Block spacebar - do nothing
            }
            elseif ($ValidationType -eq 'Number' -and $key.KeyChar -match '\d') {
                # Smart number validation for 1-30
                $testInput = $userInput + $key.KeyChar
                $testNum = 0

                if ([int]::TryParse($testInput, [ref]$testNum)) {
                    if ($testInput.Length -eq 1) {
                        if ($testNum -ge 1 -and $testNum -le $MaxNumber) {
                            $userInput = $testInput
                            Write-Host $key.KeyChar -NoNewline -ForegroundColor White
                        }
                    }
                    elseif ($testInput.Length -eq 2) {
                        if ($testNum -ge 1 -and $testNum -le $MaxNumber) {
                            $userInput = $testInput
                            Write-Host $key.KeyChar -NoNewline -ForegroundColor White
                        }
                        elseif ($key.KeyChar -match '[1-3]') {
                            # Invalid 2-digit, restart with new valid digit
                            [Console]::SetCursorPosition($cursorStart, $inputRow)
                            Write-Host (" " * $userInput.Length) -NoNewline
                            [Console]::SetCursorPosition($cursorStart, $inputRow)
                            $userInput = $key.KeyChar.ToString()
                            Write-Host $key.KeyChar -NoNewline -ForegroundColor White
                        }
                    }
                    else {
                        # 3+ digits, restart
                        if ($key.KeyChar -match '[1-3]') {
                            [Console]::SetCursorPosition($cursorStart, $inputRow)
                            Write-Host (" " * $userInput.Length) -NoNewline
                            [Console]::SetCursorPosition($cursorStart, $inputRow)
                            $userInput = $key.KeyChar.ToString()
                            Write-Host $key.KeyChar -NoNewline -ForegroundColor White
                        }
                    }
                }
            }
            elseif ($ValidationType -eq 'YesNo' -and $key.KeyChar -match '[YyNn]') {
                # Clear any previous input and show new Y/N
                if ($userInput.Length -gt 0) {
                    [Console]::SetCursorPosition($cursorStart, $inputRow)
                    Write-Host " " -NoNewline
                    [Console]::SetCursorPosition($cursorStart, $inputRow)
                }
                $userInput = $key.KeyChar.ToString().ToUpper()
                Write-Host $userInput -NoNewline -ForegroundColor White
            }
            elseif ($ValidationType -eq 'Text') {
                $userInput += $key.KeyChar
                Write-Host $key.KeyChar -NoNewline -ForegroundColor White
            }
        }

        Start-Sleep -Milliseconds 100
    }
}

# Function to send report to Discord
function Send-DiscordReport {
    param([string]$ReportPath)

    try {
        Write-Host ""
        Write-Host "Sending report to TAU Discord..." -ForegroundColor Cyan

        # Read the report file to generate summary
        $reportContent = Get-Content -Path $ReportPath -Raw

        # Get computer info for context
        $computerName = $env:COMPUTERNAME
        $username = $env:USERNAME
        $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption

        # Extract key information from report for summary
        $lines = $reportContent -split "`n"
        $crashCount = 0
        $tdrDetected = $false
        $dates = @()
        $eventIds = @()

        foreach ($line in $lines) {
            if ($line -match "Event ID: (\d+)") {
                $eventIds += $matches[1]
                $crashCount++
            }
            if ($line -match "Time: (.+)") {
                $dates += $matches[1]
            }
            if ($line -match "stopped responding|TDR|Timeout Detection") {
                $tdrDetected = $true
            }
        }

        # Create a concise summary
        $summary = "**New GPU Crash Report**`n"
        $summary += "Computer: ``$computerName`` | OS: ``$osInfo```n"
        $summary += "Generated: ``$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')```n"
        $summary += ("-" * 40) + "`n`n"

        if ($crashCount -gt 0) {
            $summary += ":warning: **Found $crashCount GPU-related event(s)**`n"
            if ($tdrDetected) {
                $summary += ":x: TDR (Timeout Detection & Recovery) events detected`n"
            }
            $summary += "`nMost common Event IDs: " + (($eventIds | Group-Object | Sort-Object Count -Descending | Select-Object -First 3 -ExpandProperty Name) -join ", ") + "`n"
            if ($dates.Count -gt 0) {
                $summary += "Latest crash: " + $dates[0] + "`n"
            }
        } else {
            $summary += ":white_check_mark: No GPU crashes found`n"
        }

        $summary += "`n:page_facing_up: **Full report attached below**"

        # Create JSON payload for the message
        $payload = @{
            content = $summary
            username = "GPU Crash Checker"
        } | ConvertTo-Json -Depth 3 -Compress

        # Check if curl.exe is available (Windows 10 1803+ / Windows 11)
        $curlPath = Get-Command curl.exe -ErrorAction SilentlyContinue

        if ($curlPath) {
            # Use curl.exe to send file attachment with payload
            # curl.exe is available on Windows 10+ and handles multipart/form-data properly
            $fileName = Split-Path $ReportPath -Leaf

            Write-Host "Uploading report with attachment..." -ForegroundColor Yellow

            # Create a temporary JSON file for payload_json since PowerShell string escaping is tricky with curl
            $tempJsonPath = Join-Path $env:TEMP "discord-payload-temp.json"
            $payload | Out-File -FilePath $tempJsonPath -Encoding UTF8 -NoNewline

            try {
                # Send payload from file and attach the report file
                # Using < instead of @ reads the file content as the field value
                $curlOutput = & curl.exe -X POST $discordWebhook `
                    -F "payload_json=<$tempJsonPath" `
                    -F "file=@$ReportPath" `
                    2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Report sent successfully with file attachment!" -ForegroundColor Green
                } else {
                    throw "curl.exe failed with exit code $LASTEXITCODE : $curlOutput"
                }
            }
            finally {
                # Clean up temp JSON file
                if (Test-Path $tempJsonPath) {
                    Remove-Item $tempJsonPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            # Fallback: Send summary only without file attachment
            Write-Host "curl.exe not found - sending summary without file attachment" -ForegroundColor Yellow
            Write-Host "(curl.exe is included in Windows 10 version 1803 and later)" -ForegroundColor DarkGray

            $summary += "`n`n*Note: Full report could not be attached (curl.exe not available). Report saved locally.*"

            $fallbackPayload = @{
                content = $summary
                username = "GPU Crash Checker"
            } | ConvertTo-Json -Depth 3

            $null = Invoke-RestMethod -Uri $discordWebhook -Method Post -Body $fallbackPayload -ContentType "application/json; charset=utf-8"
            Write-Host "Summary sent successfully (without attachment)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Report sent successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Join the TAU Discord to follow up on your report:" -ForegroundColor Cyan
        Write-Host "  $discordInvite" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Would you like to open the Discord invite link? (Y/N): " -ForegroundColor Cyan -NoNewline

        $openLink = Read-Host

        # Show what was selected
        if ([string]::IsNullOrWhiteSpace($openLink)) {
            $openLink = "N"  # Default to No
            Write-Host "N (default)" -ForegroundColor DarkGray
        }

        if ($openLink -eq 'Y' -or $openLink -eq 'y') {
            Start-Process $discordInvite
            Write-Host "Opening Discord invite in your browser..." -ForegroundColor Green
        } else {
            Write-Host "Skipping Discord link." -ForegroundColor DarkGray
        }

        # Don't return anything to prevent "True" from printing
        return
    }
    catch {
        Write-Host ""
        Write-Host "Failed to send report to Discord." -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Your report is still saved locally at:" -ForegroundColor Yellow
        Write-Host "  $ReportPath" -ForegroundColor Cyan
        Write-Host ""
        return
    }
}

# Function to show a fast-filling progress bar
function Show-ProgressBar {
    param(
        [string]$Activity,
        [scriptblock]$ScriptBlock
    )

    Write-Host $Activity -ForegroundColor Yellow

    # Create progress bar
    $barWidth = [Console]::WindowWidth - 4
    if ($barWidth -lt 20) { $barWidth = 20 }
    if ($barWidth -gt 80) { $barWidth = 80 }

    $blockChar = [char]0x2588
    $emptyChar = ' '

    # Start the scriptblock in background (simulated - PowerShell doesn't have true threading here)
    # So we'll fake a fast progress bar
    $steps = 20
    $result = $null

    for ($i = 0; $i -le $steps; $i++) {
        $percent = [Math]::Floor(($i / $steps) * 100)
        $filled = [Math]::Floor(($i / $steps) * $barWidth)
        $empty = $barWidth - $filled

        $bar = "[" + ($blockChar.ToString() * $filled) + ($emptyChar * $empty) + "] $percent%"

        [Console]::SetCursorPosition(0, [Console]::CursorTop)
        Write-Host $bar -ForegroundColor Cyan -NoNewline

        if ($i -eq 0) {
            # Execute the actual work on first iteration
            $result = & $ScriptBlock
        }

        Start-Sleep -Milliseconds 50
    }

    Write-Host ""
    return $result
}

# Function to search for GPU events
function Search-GPUEvents {
    param([int]$DaysBack)

    $startTime = (Get-Date).AddDays(-$DaysBack)

    Write-Log ""
    Write-Log "========================================"  "Cyan"
    Write-Log "Searching Event Viewer logs from the last $DaysBack days..." "Cyan"
    Write-Log "Start time: $startTime" "Cyan"
    Write-Log "========================================"  "Cyan"
    Write-Log ""

    # Search patterns for GPU crashes
    $patterns = @(
        "*nvlddmkm*stopped responding*",
        "*Display driver*stopped responding*",
        "*has successfully recovered*",
        "*nvlddmkm*",
        "*amdkmdag*stopped responding*",
        "*timeout*display*driver*"
    )

    $allEvents = @()

    # Search System log for display driver events with progress bar
    $systemEvents = Show-ProgressBar -Activity "Searching System event log..." -ScriptBlock {
        try {
            Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                StartTime = $startTime
            } -ErrorAction SilentlyContinue | Where-Object {
                $message = $_.Message
                ($_.Id -in @(4101, 13, 14, 15, 17)) -or
                ($patterns | Where-Object { $message -like $_ }).Count -gt 0
            }
        } catch {
            @()
        }
    }

    if ($systemEvents) {
        $allEvents += $systemEvents
        Write-Host "  Found $($systemEvents.Count) potential events in System log" -ForegroundColor Green
    }

    # Search Application log for potential related errors
    $appEvents = Show-ProgressBar -Activity "Searching Application event log..." -ScriptBlock {
        try {
            Get-WinEvent -FilterHashtable @{
                LogName = 'Application'
                StartTime = $startTime
            } -ErrorAction SilentlyContinue | Where-Object {
                $message = $_.Message
                ($message -like "*Fortnite*" -and ($message -like "*crash*" -or $message -like "*error*")) -or
                ($message -like "*d3d*" -and $message -like "*error*") -or
                ($message -like "*graphics*driver*error*")
            }
        } catch {
            @()
        }
    }

    if ($appEvents) {
        $allEvents += $appEvents
        Write-Host "  Found $($appEvents.Count) potential events in Application log" -ForegroundColor Green
    }

    # Look for LiveKernelEvent errors
    $liveKernelEvents = Show-ProgressBar -Activity "Searching for LiveKernelEvent reports..." -ScriptBlock {
        try {
            Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                Id = 117, 141
                StartTime = $startTime
            } -ErrorAction SilentlyContinue
        } catch {
            @()
        }
    }

    if ($liveKernelEvents) {
        $allEvents += $liveKernelEvents
        Write-Host "  Found $($liveKernelEvents.Count) LiveKernelEvent entries (IDs 117/141)" -ForegroundColor Green
    }
    
    return $allEvents | Sort-Object TimeCreated -Descending
}

# Main menu
function Show-Menu {
    Write-Host ""
    Write-Host "========================================"  -ForegroundColor Cyan
    Write-Host "MAIN MENU" -ForegroundColor Cyan
    Write-Host "========================================"  -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Search for GPU crashes" -ForegroundColor White
    Write-Host "2. View information about TDR events" -ForegroundColor White
    Write-Host "3. Exit" -ForegroundColor White
    Write-Host ""
    Write-Host "Enter your choice (1-3): " -ForegroundColor Cyan -NoNewline
}

function Show-TDRInfo {
    Write-Host ""
    Write-Host "========================================"  -ForegroundColor Cyan
    Write-Host "ABOUT TDR (Timeout Detection & Recovery)" -ForegroundColor Cyan
    Write-Host "========================================"  -ForegroundColor Cyan
    Write-Host ""
    Write-Host "TDR is a Windows feature that detects when your GPU driver" -ForegroundColor White
    Write-Host "stops responding and attempts to recover it." -ForegroundColor White
    Write-Host ""
    Write-Host "Common TDR Event IDs:" -ForegroundColor Yellow
    Write-Host "  - Event ID 4101: Display driver stopped responding" -ForegroundColor White
    Write-Host "  - Event ID 117: Display driver timeout" -ForegroundColor White
    Write-Host "  - Event ID 141: Display driver stopped responding and recovered" -ForegroundColor White
    Write-Host ""
    Write-Host "What causes TDR events:" -ForegroundColor Yellow
    Write-Host "  1. GPU overheating" -ForegroundColor White
    Write-Host "  2. Unstable overclock" -ForegroundColor White
    Write-Host "  3. Outdated or corrupted drivers" -ForegroundColor White
    Write-Host "  4. Insufficient power supply" -ForegroundColor White
    Write-Host "  5. Hardware failure" -ForegroundColor White
    Write-Host ""
    Write-Host "Press Enter to return to menu..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

# ============================================
# MAIN PROGRAM
# ============================================

# Header
Write-Log "========================================"  "Cyan"
Write-Log "GPU Crash Event Viewer Checker" "Cyan"
Write-Log "Created by Fjord and Claude" "Cyan"
Write-Log "========================================"  "Cyan"
Write-Log ""

# Confirm admin status
Write-Host "Running as Administrator" -ForegroundColor Green
Write-Host ""

# Main program loop
$continue = $true
while ($continue) {
    Show-Menu
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            # Ask how many days to search
            Write-Host ""
            Write-Host "How many days back would you like to search?" -ForegroundColor White
            Write-Host "Recommended: 7 for recent issues, 14-30 for patterns." -ForegroundColor Yellow
            

            $daysInput = Read-InputWithDefault -Prompt "Enter number of days (1-30) [7]:" -DefaultValue "7" -TimeoutSeconds 60 -ValidationType Number -MaxNumber 30
            $daysToSearch = 7

            if ($daysInput -match '^\d+$') {
                $daysToSearch = [Math]::Min([Math]::Max([int]$daysInput, 1), 30)
            } else {
                $daysToSearch = 7
            }

            # Ask about Discord sharing BEFORE running the search
            Write-Host ""
            Write-Host "========================================"  -ForegroundColor Cyan
            Write-Host "SHARE REPORT WITH FJORD?" -ForegroundColor Cyan
            Write-Host "========================================"  -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Would you like to share your report with Fjord via Discord?" -ForegroundColor White
            Write-Host "This helps improve the tool and may get you direct support." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  [Y] Yes, share my report (recommended)" -ForegroundColor Green
            Write-Host "  [N] No, keep it private" -ForegroundColor Gray
            Write-Host ""

            $shareChoice = Read-InputWithDefault -Prompt "Share report? (Y/N) [Y]:" -DefaultValue "Y" -TimeoutSeconds 60 -ValidationType YesNo
            $shareReport = ($shareChoice -ne 'N' -and $shareChoice -ne 'n')
            
            # Search for events
            $events = Search-GPUEvents -DaysBack $daysToSearch
            
            # Display results
            Write-Log ""
            Write-Log "========================================"  "Cyan"
            Write-Log "RESULTS" "Cyan"
            Write-Log "========================================"  "Cyan"
            Write-Log ""

            if ($events.Count -eq 0) {
                Write-Log "Good news! No GPU crash or TDR events found in the last $daysToSearch days!" "Green"
                Write-Log ""
                Write-Log "Event Viewer does not show display driver resets." "Green"
                Write-Log ""
                Write-Log "If Fortnite is still crashing, the issue may be:" "White"
                Write-Log "  - Game-specific bug" "White"
                Write-Log "  - Overheating (check GPU temperatures)" "White"
                Write-Log "  - Overclocking instability" "White"
                Write-Log "  - Power supply issues" "White"
                Write-Log "  - Corrupted game files (verify game files in Epic launcher)" "White"
            } else {
                Write-Log "WARNING: Found $($events.Count) potential GPU-related event(s)" "Red"
                Write-Log ""
                
                $crashCount = @{}
                
                foreach ($event in $events) {
                    $dateKey = $event.TimeCreated.ToString("yyyy-MM-dd")
                    if (-not $crashCount.ContainsKey($dateKey)) {
                        $crashCount[$dateKey] = 0
                    }
                    $crashCount[$dateKey]++
                    
                    Write-Log "----------------------------------------" "DarkGray"
                    Write-Log "Time: $($event.TimeCreated)" "White"
                    Write-Log "Event ID: $($event.Id)" "White"
                    Write-Log "Level: $($event.LevelDisplayName)" "White"
                    Write-Log "Source: $($event.ProviderName)" "White"
                    Write-Log ""
                    Write-Log "Message:" "Yellow"
                    Write-Log $event.Message "White"
                    Write-Log "----------------------------------------" "DarkGray"
                    Write-Log ""
                }
                
                # Summary by date
                Write-Log ""
                Write-Log "========================================"  "Cyan"
                Write-Log "CRASH SUMMARY BY DATE" "Cyan"
                Write-Log "========================================"  "Cyan"
                Write-Log ""
                
                foreach ($date in $crashCount.Keys | Sort-Object -Descending) {
                    Write-Log "$date : $($crashCount[$date]) event(s)" "Yellow"
                }
                
                Write-Log ""
                Write-Log "========================================"  "Cyan"
                Write-Log "WHAT THIS MEANS" "Cyan"
                Write-Log "========================================"  "Cyan"
                Write-Log ""
                
                # Check for TDR events
                $tdrEvents = $events | Where-Object { 
                    $_.Message -like "*stopped responding*" -or 
                    $_.Id -in @(4101, 117, 141)
                }
                
                if ($tdrEvents) {
                    Write-Log "WARNING: TDR (Timeout Detection and Recovery) events detected!" "Red"
                    Write-Log "This means Windows detected your GPU driver stopped responding." "White"
                    Write-Log ""
                    Write-Log "Common causes:" "Yellow"
                    Write-Log "  1. GPU overheating - Check temperatures" "White"
                    Write-Log "  2. Unstable overclock - Reduce GPU/memory clocks" "White"
                    Write-Log "  3. Outdated or corrupt drivers - Try DDU and clean driver install" "White"
                    Write-Log "  4. Insufficient power - Check PSU connections and wattage" "White"
                    Write-Log "  5. Faulty GPU - May need hardware diagnosis" "White"
                    Write-Log ""
                    Write-Log "Recommended steps:" "Yellow"
                    Write-Log "  - Update GPU drivers (or rollback if recently updated)" "White"
                    Write-Log "  - Check GPU temperatures while gaming" "White"
                    Write-Log "  - Disable any GPU overclocking" "White"
                    Write-Log "  - Increase TDR timeout (advanced, not recommended as first step)" "White"
                }
            }

            Write-Log ""
            Write-Log "========================================"  "Cyan"
            Write-Log "Report saved to:" "Cyan"
            Write-Log $outputFile "Green"
            Write-Log "========================================"  "Cyan"
            Write-Log ""

            # Open the folder
            Write-Host "Opening output folder..." -ForegroundColor Cyan
            Start-Process explorer.exe -ArgumentList $outputFolder

            # Send to Discord if user opted in
            if ($shareReport) {
                Send-DiscordReport -ReportPath $outputFile
            } else {
                Write-Host ""
                Write-Host "Report NOT shared (you opted out)." -ForegroundColor Yellow
                Write-Host "Your report is saved locally at:" -ForegroundColor Cyan
                Write-Host "  $outputFile" -ForegroundColor White
            }
            
            Write-Host ""
            Write-Host "Press Enter to return to menu..." -ForegroundColor DarkGray
            Read-Host | Out-Null
            Clear-Host
        }
        '2' {
            Show-TDRInfo
            Clear-Host
        }
        '3' {
            Write-Host ""
            Write-Host "Exiting..." -ForegroundColor Cyan
            $continue = $false
        }
        default {
            Write-Host ""
            Write-Host "Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
        }
    }
}
