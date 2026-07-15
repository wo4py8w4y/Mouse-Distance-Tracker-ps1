# Mouse Distance Tracker

A PowerShell-based mouse movement tracking utility with a modern GUI and real-time distance measurement.

## Features

- **Real-time Tracking**: Monitor mouse movement distance in pixels, centimeters, and meters
- **Persistent Tracking**: Total distance accumulates across sessions
- **DPI Calibration**: Adjustable DPI settings for accurate distance measurements
- **Modern GUI**: Easy-to-use graphical interface with live updates
- **Console Mode**: Optional command-line mode for background tracking
- **Detailed Reports**: Export tracking data to configuration files

## Getting Started

### Quick Start

Simply run the script to launch the GUI:

```powershell
.\MouseDistanceTracker.ps1
```

### DPI Calibration

For accurate distance measurements, visit **https://dpi.lv/** to determine your monitor's real DPI, then:

1. Launch the application
2. Enter your DPI value in the DPI field
3. Click "Update DPI" to recalculate distances

### Files

- `MouseDistanceTracker.ps1` - Main script file
- `mouse-tracker.cfg.txt` - Configuration file (auto-created)

## Usage

### GUI Mode (Default)

The GUI provides:
- Real-time distance statistics
- Start/Stop/Reset controls
- DPI adjustment
- Automatic config saving on exit

### Console Mode

Run in console mode with:

```powershell
.\MouseDistanceTracker.ps1 -GUI:$false
```

## Parameters

- `-GUI` - Launch GUI mode (default: true)
- `-DPI` - Set DPI value (default: auto-detect)
- `-ConfigPath` - Custom config file path
- `-DurationSeconds` - Console mode tracking duration (0 = continuous)

## Examples

```powershell
# GUI with custom DPI
.\MouseDistanceTracker.ps1 -DPI 144

# Console mode for 60 seconds
.\MouseDistanceTracker.ps1 -GUI:$false -DurationSeconds 60
```

## Data Persistence

Total distance is automatically saved and loaded from the configuration file, allowing you to track your mouse movement over time.

## Author

Aaron Francis
