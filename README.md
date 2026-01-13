# 🎮 GPU Crash Event Viewer Checker

> **Diagnose GPU crashes and driver timeouts that might be ruining your Fortnite sessions**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Created by Fjord** 🌊

---

## 📋 Table of Contents

- [What Is This?](#-what-is-this)
- [Features](#-features)
- [Quick Start](#-quick-start)
- [Menu Options](#-menu-options)
- [What Gets Scanned](#-what-gets-scanned)
- [Understanding Results](#-understanding-results)
- [Discord Integration](#-discord-integration)
- [Troubleshooting](#-troubleshooting)
- [Requirements](#-requirements)

---

## 🤔 What Is This?

Ever had Fortnite crash with no clear reason? This tool digs deep into Windows Event Viewer to find **GPU driver crashes**, **TDR (Timeout Detection and Recovery) events**, and other graphics-related errors that might be the culprit.

Instead of manually combing through thousands of system events, this PowerShell script does the heavy lifting for you and generates a clean, readable report.

---

## ✨ Features

- 🔍 **Automated Event Log Scanning** - Searches System and Application logs for GPU-related crashes
- 📊 **Detailed Reports** - Generates timestamped reports with crash summaries and event details
- 🎯 **Smart Detection** - Finds TDR events, NVIDIA/AMD driver crashes, LiveKernelEvents, and more
- 📅 **Flexible Date Range** - Search anywhere from 1-30 days back
- 🔄 **Interactive Menu** - User-friendly interface with multiple options
- 💾 **Auto-Save** - Reports saved to `Documents\GPU-Crash-Logs\`
- 🌐 **Discord Webhook Integration** - Optionally share your report with support teams via Discord
- 📎 **File Attachments** - Full reports sent as downloadable `.txt` files
- 🛡️ **Admin Detection** - Automatically elevates to administrator for full event access
- 📈 **Crash Statistics** - View crash counts by date and event type

---

## 🚀 Quick Start

### Method 1: Easy Launch (Recommended)

1. **Double-click** `Run-GPU-Crash-Checker.bat`
2. Choose **Option 1** to search for GPU crashes
3. Enter how many days back to search (e.g., `7` for the last week)
4. Review results on-screen
5. A folder opens automatically with your detailed report

### Method 2: PowerShell Direct

1. **Right-click** `GPU-Crash-Checker.ps1`
2. Select **"Run with PowerShell"** (or **"Run as Administrator"** for best results)
3. Follow the interactive menu

---

## 📖 Menu Options

### 1️⃣ Search for GPU Crashes
Scans Windows Event Viewer for crash events over your chosen time period.

**What happens:**
- Prompts you to select how many days back to search (1-30)
- Asks if you want to share the report via Discord (optional)
- Scans System and Application logs
- Displays results in real-time
- Saves a detailed report with timestamps, event IDs, and messages
- Opens the output folder automatically

### 2️⃣ View Information About TDR Events
Educational screen explaining:
- What TDR (Timeout Detection and Recovery) means
- Common TDR Event IDs (4101, 117, 141)
- Typical causes (overheating, overclocking, driver issues, etc.)

### 3️⃣ Exit
Close the program cleanly.

---

## 🔬 What Gets Scanned

The script searches for these specific issues:

| Category | What It Finds |
|----------|---------------|
| 🟢 **NVIDIA Crashes** | `nvlddmkm` stopped responding events |
| 🔴 **AMD Crashes** | `amdkmdag` stopped responding events |
| ⚠️ **TDR Events** | Timeout Detection and Recovery (Event IDs 4101, 117, 141) |
| 💥 **LiveKernelEvents** | Critical kernel-level GPU errors |
| 🎮 **Fortnite Crashes** | Application errors related to Fortnite or D3D |
| ⏱️ **Display Driver Timeouts** | Generic display driver timeout messages |

---

## 📊 Understanding Results

### ✅ No Events Found

**Good news!** Event Viewer shows no driver resets or TDR events.

If Fortnite is still crashing, the issue might be:
- 🐛 **Game-specific bug** - Check for Fortnite updates
- 🔥 **Overheating** - Monitor GPU temps with MSI Afterburner or HWiNFO
- ⚡ **Overclocking instability** - Revert GPU/CPU to stock clocks
- 🔌 **Power supply issues** - Check PSU wattage and cable connections
- 💿 **Corrupted game files** - Verify game files in Epic Games Launcher

---

### ⚠️ TDR Events Found

**Warning!** Windows detected your GPU driver stopped responding and attempted recovery.

#### Common Causes:

1. **🔥 GPU Overheating**
   - Monitor temps while gaming (should be under 80-85°C)
   - Clean dust from GPU fans and heatsink
   - Improve case airflow

2. **⚡ Unstable Overclock**
   - Reduce GPU core and memory clocks to stock
   - Use MSI Afterburner or EVGA Precision to adjust
   - Test stability with 3DMark or Heaven Benchmark

3. **🔄 Outdated or Corrupt Drivers**
   - Update to latest GPU drivers (NVIDIA GeForce Experience / AMD Software)
   - Consider clean install with DDU (Display Driver Uninstaller)

4. **🔌 Insufficient Power Supply**
   - Ensure PSU meets GPU power requirements
   - Check all PCIe power cables are firmly connected
   - Test with a known-good PSU if possible

5. **🛠️ Faulty Hardware**
   - GPU may be defective
   - Try GPU in another system or try another GPU in your system
   - Contact manufacturer about RMA if under warranty

---

## 🌐 Discord Integration

### How It Works

When you run a GPU crash scan, the script offers to **share your report with Fjord via Discord**. This is completely **optional** and helps improve the tool while potentially getting you direct support.

#### What Gets Sent:

1. **📋 Summary Message** (visible in Discord):
   - Computer name and OS version
   - Total number of crashes found
   - TDR detection status
   - Most common Event IDs
   - Latest crash timestamp

2. **📎 Full Report Attachment** (downloadable `.txt` file):
   - Complete event log details
   - All crash messages and timestamps
   - Crash summary by date

#### Privacy:

- ✅ You're asked **before** every upload (opt-in)
- ✅ Only includes: computer name, OS info, and event logs
- ❌ No personal data, usernames, or file paths are shared
- 💾 Reports are **always saved locally** regardless of Discord choice

#### Technical Details:

- Uses Discord webhooks (no bot required)
- Sends via `curl.exe` (included in Windows 10 1803+)
- Falls back to summary-only if `curl.exe` unavailable
- File size limit: 25MB (typical reports are <100KB)

---

## 🛠️ Troubleshooting

### ❌ "Script is not digitally signed"

**Solution 1 (Easiest):**
Use the `.bat` file instead of running the `.ps1` directly.

**Solution 2 (Advanced):**
1. Right-click PowerShell → **Run as Administrator**
2. Run this command:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. Then run the script

---

### 🔍 No Events Found But Game Still Crashes

Try these steps:

1. **Verify game files** in Epic Games Launcher
2. **Check GPU temps** with HWiNFO64 or MSI Afterburner while gaming
3. **Update Windows** and GPU drivers to latest versions
4. **Test other games** - if they crash too, it's likely hardware/driver related
5. **Check RAM** with Windows Memory Diagnostic or MemTest86

---

### 📂 Where Are Reports Saved?

```
C:\Users\[YourName]\Documents\GPU-Crash-Logs\
```

Each run creates a new timestamped file:
```
GPU-Crash-Report_2026-01-09_14-30-45.txt
```

---

### 🌐 Discord Upload Failed

**Possible causes:**
- Firewall blocking `curl.exe`
- No internet connection
- Discord webhook URL changed/expired

**Your report is still saved locally!** You can:
- Manually upload the `.txt` file to Discord
- Share it in support forums
- Email it to support teams

---

## 📋 Requirements

| Requirement | Details |
|-------------|---------||
| 🖥️ **Operating System** | Windows 10 (1803+) or Windows 11 |
| ⚙️ **PowerShell** | Version 5.1+ (included with Windows) |
| 🔐 **Permissions** | Administrator recommended (auto-elevates if needed) |
| 🌐 **Internet** | Optional (only for Discord webhook feature) |
| 💾 **Disk Space** | Minimal (~1MB for reports) |

---

## 💡 Tips for Best Results

- ✅ **Run as Administrator** for access to all event logs
- ✅ **Check logs soon after a crash** for most relevant data
- ✅ **Search 7-14 days** for pattern detection
- ✅ **Keep reports** to track crash frequency over time
- ✅ **Share reports** with support communities for faster diagnosis

---

## 📜 License

This project is licensed under the MIT License - feel free to use, modify, and distribute.

---

## 🙏 Credits

**Created by Fjord** 🌊

Special thanks to the TAU Discord community for testing and feedback!

---

## 🔗 Support

Need help? Found a bug? Have suggestions?

- 💬 Join the **TAU Discord**: [https://discord.gg/FM5gvVNSRQ](https://discord.gg/FM5gvVNSRQ)
- 📧 Share your crash reports when asking for help
- 🐛 Report issues on GitHub (if applicable)

---

**Happy gaming! May your frames be high and your crashes be low.** 🎮✨