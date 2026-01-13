# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Script

**Primary method:**
```cmd
Run-GPU-Crash-Checker.bat
```
This launches the PowerShell script with auto-elevation to administrator.

**Direct PowerShell execution:**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "GPU-Crash-Checker.ps1"
```

The script must run with administrator privileges to access Windows Event Viewer logs. It will self-elevate if not already running as admin.

## Architecture Overview

This is a single-file PowerShell diagnostic tool with three core components:

### 1. Interactive Input System (`Read-InputWithDefault`)
- Console-based input with visual countdown timer (60s default)
- Timer renders at bottom of screen as yellow pipes (`|`) disappearing right-to-left (120 chars)
- Three validation modes: `Number` (1-30), `YesNo` (Y/N), `Text` (freeform)
- **Critical behavior**: If user types valid input but timer expires before Enter is pressed, their typed input is used instead of default
- Smart number validation: Prevents invalid multi-digit entries (only 1-30 accepted, auto-restarts input on invalid second digit)
- Spacebar is blocked on Number/YesNo fields
- Uses `[Console]::SetCursorPosition()` for timer positioning without disrupting input cursor

### 2. Event Log Scanner (`Search-GPUEvents`)
Searches Windows Event Viewer across multiple logs:
- **System log**: TDR events (IDs 4101, 117, 141), driver crashes (`nvlddmkm`, `amdkmdag`)
- **Application log**: Fortnite crashes, D3D errors, graphics driver errors
- **LiveKernelEvent**: Critical kernel GPU errors (IDs 117, 141)
- Uses `Get-WinEvent` with FilterHashtable for performance
- Returns events sorted by TimeCreated (descending)

### 3. Discord Integration (`Send-DiscordReport`)
**File attachment implementation** (this was tricky to get right):
- Discord webhooks require multipart/form-data with `payload_json` field
- PowerShell's `Invoke-RestMethod` doesn't handle this properly for file uploads
- **Solution**: Use native `curl.exe` (available Windows 10 1803+):
  ```powershell
  curl.exe -X POST $webhook -F "payload_json=<temp.json" -F "file=@report.txt"
  ```
- Note the `<` vs `@` syntax: `<` reads file content as field value, `@` sends as file attachment
- Fallback to summary-only if `curl.exe` unavailable
- Discord function returns `void` to prevent "True" from printing to console

## Key UX Design Decisions

### Timer Positioning
After extensive iteration, the timer is positioned at the **bottom of screen** because:
- Top positioning required viewport buffering (complex, brittle)
- Bottom positioning causes scroll conflicts on full screens
- **Solution**: `Clear-Host` after each menu cycle (after "Press Enter to return to menu")
- This ensures at least one clean run per menu cycle without visual glitches

### Input Display Pattern ("Variant 1")
- Prompt text includes default value in brackets: `"Enter number of days (1-30) [7]:"`
- Input cursor starts blank (no pre-filled text)
- When user presses Enter or timer expires with no input: default value echoes in white
- When user types valid input: their input echoes in white

### Screen Management
`Clear-Host` is called after:
1. Menu option 1 completes (after "Press Enter to return to menu")
2. Menu option 2 completes (TDR info screen)

This prevents scrolling content from conflicting with bottom timer on subsequent runs.

## Discord Webhook Configuration

Webhook URL is hardcoded in the script (line 22):
```powershell
$discordWebhook = "https://discord.com/api/webhooks/[ID]/[TOKEN]"
```

When modifying Discord integration, remember:
- Never use `return $true` or `return $false` - use plain `return` to avoid printing to console
- File uploads require `curl.exe`, not `Invoke-RestMethod`
- Create temp JSON file for `payload_json` field (PowerShell string escaping is problematic with curl)

## Output Structure

Reports save to: `$env:USERPROFILE\Documents\GPU-Crash-Logs\`

Filename format: `GPU-Crash-Report_YYYY-MM-DD_HH-mm-ss.txt`

Each report contains:
- Search parameters (date range)
- Event details (Time, Event ID, Level, Source, Message)
- Crash summary by date
- Diagnostic recommendations based on event types found

## Testing Notes

When testing input timer behavior:
- Set `$TimeoutSeconds` param to lower value (e.g., 5) for faster iteration
- Watch for cursor jumping (indicates position calculation issues)
- Verify timer clears completely before returning to menu
- Test edge cases: typing then backspacing to empty, typing invalid numbers, holding spacebar