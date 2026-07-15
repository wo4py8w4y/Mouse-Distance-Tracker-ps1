<#
.SYNOPSIS
    Measures and tracks mouse movement distance with GUI and CLI support, converts to multiple units.

.DESCRIPTION
    Monitors mouse cursor position changes, calculates total distance traveled in pixels/cm/meters,
    and saves metrics to a configuration file. Supports continuous tracking or GUI mode.

.PARAMETER DurationSeconds
    How long to track (seconds). If 0, runs continuously until stopped (default: 0 = continuous)

.PARAMETER OutputPath
    Path to save the INI file (default: current directory)

.PARAMETER FileName
    Name of the INI file (default: mouse-tracker.cfg)

.PARAMETER GUI
    Display a GUI window for real-time tracking and control

.PARAMETER DPI
    Screen DPI for pixel-to-distance conversion (default: auto-detect)

.EXAMPLE
    .\MouseDistanceTracker.ps1 -GUI

.EXAMPLE
    .\MouseDistanceTracker.ps1 -DurationSeconds 60 -OutputPath "C:\Reports"

.EXAMPLE
    .\MouseDistanceTracker.ps1 -GUI -DPI 96
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$DurationSeconds = 0,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'mouse-tracker-state.cfg'),

    [Parameter(Mandatory = $false)]
    [switch]$GUI,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [string]$FileName = 'mouse-tracker.cfg',

    [Parameter(Mandatory = $false)]
    [int]$DPI = 0
)

if (-not $PSBoundParameters.ContainsKey('GUI'))
{
    $GUI = $true
}

# Add Windows API calls for mouse position
Add-Type @'
using System;
using System.Runtime.InteropServices;

public class MouseTracker {
    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    public static POINT GetMousePosition() {
        POINT pt;
        GetCursorPos(out pt);
        return pt;
    }
}
'@

# Display message about DPI calibration
Write-Host '═══════════════════════════════════════════' -ForegroundColor Cyan
Write-Host 'Mouse Distance Tracker' -ForegroundColor Cyan
Write-Host '═══════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
Write-Host 'For accurate distance measurements, visit:' -ForegroundColor Yellow
Write-Host 'https://dpi.lv/' -ForegroundColor Green -NoNewline
Write-Host ' to get your real monitor DPI' -ForegroundColor Yellow
Write-Host ''

# Get DPI setting from system if not specified
if ($DPI -eq 0)
{
    try
    {
        $dpiValue = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'LogPixels' -ErrorAction SilentlyContinue
        $DPI = if ($dpiValue) { $dpiValue.LogPixels } else { 96 }
    }
    catch
    {
        $DPI = 96  # Default Windows DPI
    }
}

# Configuration file functions
function Get-TrackerConfig
{
    param([string]$ConfigPath)
    
    $config = @{
        TotalDistance = 0
        DPI           = $DPI
    }
    
    if (Test-Path $ConfigPath)
    {
        $content = Get-Content $ConfigPath -Raw
        if ($content -match 'TotalDistancePixels=([\d.]+)')
        {
            $config.TotalDistance = [double]$matches[1]
        }
        if ($content -match 'CurrentDPI=([\d]+)')
        {
            $config.DPI = [int]$matches[1]
        }
    }
    
    return $config
}

function Set-TrackerConfig
{
    param(
        [string]$ConfigPath,
        [double]$TotalDistance,
        [int]$DPI
    )
    
    $configContent = @"
; Mouse Distance Tracker Configuration
; Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

[CONFIG]
TotalDistancePixels=$TotalDistance
CurrentDPI=$DPI
"@
    
    $configContent | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
}

# Load configuration
$loadedConfig = Get-TrackerConfig -ConfigPath $ConfigPath
if ($DPI -eq 0) { $DPI = $loadedConfig.DPI }

# Calculate conversion factors (1 inch = 2.54 cm) - use script scope for GUI updates
$script:pixelsPerInch = $DPI
$script:pixelsPerCm = $script:pixelsPerInch / 2.54
$script:pixelsPerMeter = $script:pixelsPerCm * 100

# Function to format distance in multiple units
function script:Format-Distance
{
    param([double]$Pixels)
    $cm = $Pixels / $script:pixelsPerCm
    $m = $cm / 100
    $inches = $Pixels / $script:pixelsPerInch
    
    return @{
        Pixels      = [Math]::Round($Pixels, 2)
        Centimeters = [Math]::Round($cm, 2)
        Meters      = [Math]::Round($m, 4)
        Inches      = [Math]::Round($inches, 2)
    }
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath))
{
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$iniPath = Join-Path $OutputPath $FileName

# GUI Mode
if ($GUI)
{
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore

    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Mouse Distance Tracker" Width="650" Height="550"
    Background="#f0f0f0" Foreground="#333333"
    WindowStartupLocation="CenterScreen" ResizeMode="CanResize">
    <Window.Resources>
        <Style x:Key="ColoredButton" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                CornerRadius="3" Padding="{TemplateBinding Padding}"
                                BorderThickness="1">
                            <Border.BorderBrush>
                                <SolidColorBrush Color="{Binding Background.Color, RelativeSource={RelativeSource TemplatedParent}}"/>
                            </Border.BorderBrush>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Background" Value="Transparent"/>
                                <Setter Property="Foreground" Value="{Binding Tag, RelativeSource={RelativeSource Self}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
        <Grid>
            <StackPanel Margin="20">
            <TextBlock Text="Mouse Distance Tracker" FontSize="24" FontWeight="Bold" 
                       Foreground="#667eea" Margin="0,0,0,20"/>
            
            <Border Background="White" BorderBrush="#ddd" BorderThickness="1" 
                    Padding="15" Margin="0,0,0,15" CornerRadius="5">
                <StackPanel>
                    <TextBlock Text="Real-time Statistics" FontSize="14" FontWeight="Bold" 
                               Margin="0,0,0,10"/>
                    
                    <Grid Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Margin="0,0,10,0">
                            <TextBlock Text="Pixels" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="TotalDistance" Text="0.00" FontSize="16" 
                                       FontWeight="Bold" Foreground="#667eea"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1" Margin="0,0,10,0">
                            <TextBlock Text="Centimeters" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="CentimeterValue" Text="0.00" FontSize="16" 
                                       FontWeight="Bold" Foreground="#764ba2"/>
                        </StackPanel>
                        <StackPanel Grid.Column="2">
                            <TextBlock Text="Meters" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="MeterValue" Text="0.0000" FontSize="16" 
                                       FontWeight="Bold" Foreground="#764ba2"/>
                        </StackPanel>
                    </Grid>

                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Margin="0,0,10,0">
                            <TextBlock Text="Total Samples" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="SampleCount" Text="0" FontSize="14" 
                                       FontWeight="Bold" Foreground="#667eea"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Elapsed Time" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="ElapsedTime" Text="00:00:00" FontSize="14" 
                                       FontWeight="Bold" Foreground="#667eea"/>
                        </StackPanel>
                    </Grid>
                </StackPanel>
            </Border>

            <Border Background="White" BorderBrush="#ddd" BorderThickness="1" 
                    Padding="15" Margin="0,0,0,15" CornerRadius="5">
                <StackPanel>
                    <TextBlock Text="Performance Metrics" FontSize="14" FontWeight="Bold" 
                               Margin="0,0,0,10"/>
                    
                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Margin="0,0,10,0">
                            <TextBlock Text="Average/Sample" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="AverageDistance" Text="0.00 px" FontSize="12"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Max/Sample" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="MaxDistance" Text="0.00 px" FontSize="12"/>
                        </StackPanel>
                    </Grid>

                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Margin="0,0,10,0">
                            <TextBlock Text="Min/Sample" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="MinDistance" Text="0.00 px" FontSize="12"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Pixels/Second" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="PixelsPerSecond" Text="0.00" FontSize="12"/>
                        </StackPanel>
                    </Grid>

                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Margin="0,0,10,0">
                            <TextBlock Text="CM/Second" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="CmPerSecond" Text="0.00" FontSize="12"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Meters/Second" FontSize="11" Foreground="#999"/>
                            <TextBlock Name="MPerSecond" Text="0.0000" FontSize="12"/>
                        </StackPanel>
                    </Grid>
                </StackPanel>
            </Border>

            <Border Background="White" BorderBrush="#ddd" BorderThickness="1" 
                    Padding="15" Margin="0,0,0,15" CornerRadius="5">
                <StackPanel>
                    <TextBlock Text="Lap Times" FontSize="14" FontWeight="Bold" 
                               Margin="0,0,0,10"/>
                    <ScrollViewer MaxHeight="150" VerticalScrollBarVisibility="Auto">
                        <TextBlock Name="LapList" Text="No laps recorded" FontSize="11" 
                                   Foreground="#666" TextWrapping="Wrap"/>
                    </ScrollViewer>
                </StackPanel>
            </Border>

            <Border Background="White" BorderBrush="#ddd" BorderThickness="1" 
                    Padding="15" Margin="0,0,0,15" CornerRadius="5">
                <StackPanel>
                    <TextBlock Text="DPI Settings" FontSize="14" FontWeight="Bold" 
                               Margin="0,0,0,10"/>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="Visit https://dpi.lv/ to get your real monitor DPI" 
                                   FontSize="10" Foreground="#666" Margin="0,5,10,0"/>
                        <Button Name="OpenDpiBtn" Content="Open DPI.LV" Background="#10b981" 
                                Foreground="White" Padding="8,3" FontSize="10" 
                                Cursor="Hand" MinWidth="80" Style="{StaticResource ColoredButton}" Tag="#10b981"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="DPI:" Margin="0,5,10,0" FontWeight="Bold"/>
                        <TextBox Name="DpiTextBox" Width="80" Padding="5" Margin="0,0,10,0"/>
                        <Button Name="UpdateDpiBtn" Content="Update DPI" Background="#667eea" 
                                Foreground="White" Padding="10,5" FontSize="11" 
                                Cursor="Hand" MinWidth="100" Style="{StaticResource ColoredButton}" Tag="#667eea"/>
                    </StackPanel>
                </StackPanel>
            </Border>

            <StackPanel Orientation="Horizontal" Margin="0,0,0,15">
                <TextBlock Text="Status:" Margin="0,5,10,0" FontWeight="Bold"/>
                <TextBlock Name="StatusText" Text="Ready" Foreground="#666" Margin="0,5,0,0"/>
            </StackPanel>

            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                <Button Name="StartBtn" Content="Start Tracking" Background="#667eea" 
                        Foreground="White" Padding="15,10" FontSize="12" 
                        Cursor="Hand" MinWidth="130" Margin="0,0,10,0" Style="{StaticResource ColoredButton}" Tag="#667eea"/>
                <Button Name="StopBtn" Content="Stop &amp; Save" Background="#764ba2" 
                        Foreground="White" Padding="15,10" FontSize="12" IsEnabled="False"
                        Cursor="Hand" MinWidth="130" Margin="0,0,10,0" Style="{StaticResource ColoredButton}" Tag="#764ba2"/>
                <Button Name="ResetBtn" Content="Reset" Background="#999" 
                        Foreground="White" Padding="15,10" FontSize="12" IsEnabled="False"
                        Cursor="Hand" MinWidth="80" Style="{StaticResource ColoredButton}" Tag="#999"/>
            </StackPanel>

            <StackPanel Orientation="Horizontal">
                <Button Name="LapBtn" Content="Lap" Background="#f59e0b" 
                        Foreground="White" Padding="15,10" FontSize="12" IsEnabled="False"
                        Cursor="Hand" MinWidth="130" Style="{StaticResource ColoredButton}" Tag="#f59e0b"/>
            </StackPanel>
        </StackPanel>
    </Grid>
    </ScrollViewer>
</Window>
'@

    $reader = New-Object Xml.XmlNodeReader ([Xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()

    $startBtn = $window.FindName('StartBtn')
    $stopBtn = $window.FindName('StopBtn')
    $resetBtn = $window.FindName('ResetBtn')
    $lapBtn = $window.FindName('LapBtn')
    $statusText = $window.FindName('StatusText')
    $totalDistanceText = $window.FindName('TotalDistance')
    $sampleCountText = $window.FindName('SampleCount')
    $elapsedTimeText = $window.FindName('ElapsedTime')
    $centimeterText = $window.FindName('CentimeterValue')
    $meterText = $window.FindName('MeterValue')
    $avgDistanceText = $window.FindName('AverageDistance')
    $maxDistanceText = $window.FindName('MaxDistance')
    $minDistanceText = $window.FindName('MinDistance')
    $pixPerSecText = $window.FindName('PixelsPerSecond')
    $cmPerSecText = $window.FindName('CmPerSecond')
    $mPerSecText = $window.FindName('MPerSecond')
    $dpiTextBox = $window.FindName('DpiTextBox')
    $updateDpiBtn = $window.FindName('UpdateDpiBtn')
    $openDpiBtn = $window.FindName('OpenDpiBtn')
    $lapListText = $window.FindName('LapList')

    # Initialize DPI field
    $dpiTextBox.Text = $DPI

    # Load total distance from config
    $script:tracking = $false
    $script:totalDistance = $loadedConfig.TotalDistance
    $script:sampleCount = 0
    $script:maxDistance = 0
    $script:minDistance = [double]::MaxValue
    $script:samples = @()
    $script:startTime = $null
    $script:lastPos = $null
    $script:laps = @()
    $script:lapStartDistance = 0
    $script:lapStartTime = $null
    $updateInterval = 50
    $script:timer = $null

    function Start-TrackingSession
    {
        if ($script:tracking)
        {
            return
        }

        $script:tracking = $true
        # Don't reset totalDistance - it accumulates
        $script:sampleCount = 0
        $script:maxDistance = 0
        $script:minDistance = [double]::MaxValue
        $script:samples = @()
        $script:startTime = Get-Date
        $script:lastPos = [MouseTracker]::GetMousePosition()

        $startBtn.IsEnabled = $false
        $stopBtn.IsEnabled = $true
        $resetBtn.IsEnabled = $false
        $lapBtn.IsEnabled = $true
        $script:lapStartDistance = $script:totalDistance
        $script:lapStartTime = $script:startTime
        $statusText.Text = 'Tracking...'
        $statusText.Foreground = [Windows.Media.Brushes]::Green

        $script:timer = New-Object System.Windows.Threading.DispatcherTimer
        $script:timer.Interval = [TimeSpan]::FromMilliseconds($updateInterval)

        $script:timer.Add_Tick({
                if ($script:tracking)
                {
                    $currentPos = [MouseTracker]::GetMousePosition()
                    $deltaX = $currentPos.X - $script:lastPos.X
                    $deltaY = $currentPos.Y - $script:lastPos.Y
                    $distance = [Math]::Sqrt(($deltaX * $deltaX) + ($deltaY * $deltaY))

                    if ($distance -gt 0)
                    {
                        $script:totalDistance += $distance
                        $script:sampleCount++
                        $script:samples += $distance

                        if ($distance -gt $script:maxDistance) { $script:maxDistance = $distance }
                        if ($distance -lt $script:minDistance) { $script:minDistance = $distance }
                    }

                    $script:lastPos = $currentPos

                    # Update UI
                    $distanceFormatted = Format-Distance $script:totalDistance
                    $totalDistanceText.Text = $distanceFormatted.Pixels
                    $centimeterText.Text = $distanceFormatted.Centimeters
                    $meterText.Text = $distanceFormatted.Meters
                    $sampleCountText.Text = $script:sampleCount

                    $elapsed = ((Get-Date) - $script:startTime)
                    $elapsedTimeText.Text = $elapsed.ToString('hh\:mm\:ss')

                    if ($script:sampleCount -gt 0)
                    {
                        $avg = $script:totalDistance / $script:sampleCount
                        $avgDistanceText.Text = "$([Math]::Round($avg, 2)) px"
                        $maxDistanceText.Text = "$([Math]::Round($script:maxDistance, 2)) px"
                        $minDistanceText.Text = "$([Math]::Round($script:minDistance, 2)) px"
                    }

                    if ($elapsed.TotalSeconds -gt 0)
                    {
                        $pixPerSec = $script:totalDistance / $elapsed.TotalSeconds
                        $pixPerSecText.Text = "$([Math]::Round($pixPerSec, 2))"
                        $cmPerSecText.Text = "$([Math]::Round($pixPerSec / $pixelsPerCm, 2))"
                        $mPerSecText.Text = "$([Math]::Round($pixPerSec / $pixelsPerMeter, 4))"
                    }
                }
            })

        $script:timer.Start()
    }

    $startBtn.Add_Click({
            Start-TrackingSession
        })

    $stopBtn.Add_Click({
            if ($script:timer) { $script:timer.Stop() }
            $script:tracking = $false
            $startBtn.IsEnabled = $true
            $stopBtn.IsEnabled = $false
            $resetBtn.IsEnabled = $true
            $lapBtn.IsEnabled = $false
            $statusText.Text = 'Stopped'
            $statusText.Foreground = [Windows.Media.Brushes]::Orange
        })

    $resetBtn.Add_Click({
            if ($script:timer) { $script:timer.Stop() }
            $script:tracking = $false
            $script:totalDistance = 0
            $script:sampleCount = 0
            $script:maxDistance = 0
            $script:minDistance = [double]::MaxValue
            $script:samples = @()
            $script:laps = @()
            $script:lapStartDistance = 0
            $script:lapStartTime = $null
        
            $totalDistanceText.Text = '0.00'
            $centimeterText.Text = '0.00'
            $meterText.Text = '0.0000'
            $sampleCountText.Text = '0'
            $elapsedTimeText.Text = '00:00:00'
            $avgDistanceText.Text = '0.00 px'
            $maxDistanceText.Text = '0.00 px'
            $minDistanceText.Text = '0.00 px'
            $pixPerSecText.Text = '0.00'
            $cmPerSecText.Text = '0.00'
            $mPerSecText.Text = '0.0000'
            $lapListText.Text = 'No laps recorded'
        
            $startBtn.IsEnabled = $true
            $stopBtn.IsEnabled = $false
            $resetBtn.IsEnabled = $false
            $lapBtn.IsEnabled = $false
            $statusText.Text = 'Ready'
            $statusText.Foreground = [Windows.Media.Brushes]::Black
        })

    $lapBtn.Add_Click({
            if ($script:tracking)
            {
                $lapDistance = $script:totalDistance - $script:lapStartDistance
                $lapTime = (Get-Date) - $script:lapStartTime
                $lapNumber = $script:laps.Count + 1
                
                $lapFormatted = Format-Distance $lapDistance
                
                $lapInfo = [PSCustomObject]@{
                    Number   = $lapNumber
                    Distance = $lapFormatted
                    Time     = $lapTime
                }
                
                $script:laps += $lapInfo
                
                # Update lap display
                $lapText = ($script:laps | ForEach-Object {
                        $timeStr = $_.Time.ToString('hh\:mm\:ss\.ff')
                        "Lap $($_.Number): $($_.Distance.Pixels) px ($($_.Distance.Centimeters) cm, $($_.Distance.Meters) m) - Time: $timeStr"
                    }) -join "`n"
                
                $lapListText.Text = $lapText
                
                # Reset lap counters for next lap
                $script:lapStartDistance = $script:totalDistance
                $script:lapStartTime = Get-Date
            }
        })

    $updateDpiBtn.Add_Click({
            $newDpi = 0
            if ([int]::TryParse($dpiTextBox.Text, [ref]$newDpi) -and $newDpi -gt 0)
            {
                $script:DPI = $newDpi
                $script:pixelsPerInch = $newDpi
                $script:pixelsPerCm = $newDpi / 2.54
                $script:pixelsPerMeter = $script:pixelsPerCm * 100
                
                # Update display with new DPI
                if ($script:totalDistance -gt 0)
                {
                    $distanceFormatted = Format-Distance $script:totalDistance
                    $centimeterText.Text = $distanceFormatted.Centimeters
                    $meterText.Text = $distanceFormatted.Meters
                }
                
                [System.Windows.MessageBox]::Show("DPI updated to $newDpi`nConversions have been recalculated.", 'DPI Updated')
            }
            else
            {
                [System.Windows.MessageBox]::Show('Please enter a valid DPI value (positive integer)', 'Invalid DPI')
            }
        })

    $openDpiBtn.Add_Click({
            Start-Process 'https://dpi.lv/'
        })

    $window.Add_Closed({
            if ($script:timer) { $script:timer.Stop() }
            
            # Always save config with total distance
            Set-TrackerConfig -ConfigPath $ConfigPath -TotalDistance $script:totalDistance -DPI $DPI
            
            if ($script:sampleCount -gt 0)
            {
                $result = [System.Windows.MessageBox]::Show('Save tracking data to INI file?', 'Save Results', [System.Windows.MessageBoxButton]::YesNo)
                if ($result -eq 'Yes')
                {
                    $elapsed = ((Get-Date) - $script:startTime).TotalSeconds
                    $averageDistance = $script:totalDistance / $script:sampleCount
                    $pixelsPerSecond = $script:totalDistance / $elapsed
                    $minDistanceDisplay = if ($script:sampleCount -gt 0) { [Math]::Round($script:minDistance, 2) } else { 0 }
                
                    $distanceFormatted = Format-Distance $script:totalDistance
                    $iniContent = @"
; Mouse Distance Tracker Report - GUI Mode
; Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
; Duration: $([Math]::Round($elapsed, 2)) seconds
; DPI: $DPI

[SUMMARY]
TotalDistancePixels=$($distanceFormatted.Pixels)
TotalDistanceCentimeters=$($distanceFormatted.Centimeters)
TotalDistanceMeters=$($distanceFormatted.Meters)
TotalDistanceInches=$($distanceFormatted.Inches)
TotalSamples=$($script:sampleCount)
TrackingDurationSeconds=$([Math]::Round($elapsed, 2))
AverageDistancePerSample=$([Math]::Round($averageDistance, 2))
MaxDistanceInSample=$([Math]::Round($script:maxDistance, 2))
MinDistanceInSample=$minDistanceDisplay
PixelsPerSecond=$([Math]::Round($pixelsPerSecond, 2))
CentimetersPerSecond=$([Math]::Round($pixelsPerSecond / $pixelsPerCm, 2))
MetersPerSecond=$([Math]::Round($pixelsPerSecond / $pixelsPerMeter, 4))
SamplingIntervalMilliseconds=$updateInterval

[TIMESTAMPS]
StartTime=$(Get-Date $script:startTime -Format 'yyyy-MM-dd HH:mm:ss.fff')
EndTime=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')

[SETTINGS]
DPI=$DPI
PixelsPerInch=$pixelsPerInch
PixelsPerCentimeter=$([Math]::Round($pixelsPerCm, 4))
PixelsPerMeter=$([Math]::Round($pixelsPerMeter, 2))
ScriptPath=$PSCommandPath
OutputFile=$ConfigPath
"@

                    if ($script:sampleCount -le 500)
                    {
                        $iniContent += "`r`n[SAMPLES]`r`n"
                        for ($i = 0; $i -lt $script:samples.Count; $i++)
                        {
                            $iniContent += "Sample$(($i + 1).ToString('D4'))=$([Math]::Round($script:samples[$i], 2))`r`n"
                        }
                    }

                    $iniContent | Out-File -FilePath $iniPath -Encoding UTF8 -Force
                    [System.Windows.MessageBox]::Show("Results saved to:`r`n$iniPath", 'Saved')
                }
            }
        })

    # Display loaded total distance
    if ($loadedConfig.TotalDistance -gt 0)
    {
        $distanceFormatted = Format-Distance $loadedConfig.TotalDistance
        $totalDistanceText.Text = $distanceFormatted.Pixels
        $centimeterText.Text = $distanceFormatted.Centimeters
        $meterText.Text = $distanceFormatted.Meters
    }

    Start-TrackingSession

    $window.ShowDialog() | Out-Null
    exit
}

# Console Mode - Continuous tracking until Ctrl+C
Write-Host '════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '   Mouse Distance Tracker' -ForegroundColor Cyan
Write-Host '════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Mode: Continuous (auto-start, press Ctrl+C to stop)' -ForegroundColor Yellow
Write-Host "DPI: $DPI" -ForegroundColor Yellow
Write-Host "Output File: $iniPath" -ForegroundColor Yellow
Write-Host ''
Write-Host 'Tracking is active immediately. Move your mouse to record distance.' -ForegroundColor Green
Write-Host 'Press Ctrl+C when finished.' -ForegroundColor Green
Write-Host ''

$startTime = Get-Date
$script:tracking = $true
$totalDistance = 0
$sampleCount = 0
$maxDistance = 0
$minDistance = [double]::MaxValue
$samples = @()
$lastPos = [MouseTracker]::GetMousePosition()
$updateInterval = 50

Write-Host "Tracking started at $(Get-Date -Format 'HH:mm:ss.fff')" -ForegroundColor Gray

try
{
    while ($true)
    {
        $currentPos = [MouseTracker]::GetMousePosition()
        $deltaX = $currentPos.X - $lastPos.X
        $deltaY = $currentPos.Y - $lastPos.Y
        $distance = [Math]::Sqrt(($deltaX * $deltaX) + ($deltaY * $deltaY))

        if ($distance -gt 0)
        {
            $totalDistance += $distance
            $sampleCount++
            $samples += $distance

            if ($distance -gt $maxDistance) { $maxDistance = $distance }
            if ($distance -lt $minDistance) { $minDistance = $distance }

            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            $distFormatted = Format-Distance $totalDistance
            Write-Progress -Activity 'Tracking Mouse Movement' `
                -Status "Distance: $($distFormatted.Pixels) px / $($distFormatted.Centimeters) cm / $($distFormatted.Meters) m | Samples: $sampleCount | Elapsed: $([Math]::Round($elapsed, 1))s" `
                -PercentComplete 0
        }

        $lastPos = $currentPos
        Start-Sleep -Milliseconds $updateInterval
    }
}
catch
{
    Write-Progress -Activity 'Tracking Mouse Movement' -Completed
}

Write-Host ''
Write-Host "Tracking stopped at $(Get-Date -Format 'HH:mm:ss.fff')" -ForegroundColor Gray

$endTime = Get-Date
$elapsed = ($endTime - $startTime).TotalSeconds

# Calculate statistics
$averageDistance = if ($sampleCount -gt 0) { $totalDistance / $sampleCount } else { 0 }
$pixelsPerSecond = if ($elapsed -gt 0) { $totalDistance / $elapsed } else { 0 }
$minDistanceDisplay = if ($sampleCount -gt 0) { [Math]::Round($minDistance, 2) } else { 0 }

$distanceFormatted = Format-Distance $totalDistance

Write-Host ''
Write-Host '═══════════════════════════════════════════' -ForegroundColor Green
Write-Host '   Tracking Results' -ForegroundColor Green
Write-Host '═══════════════════════════════════════════' -ForegroundColor Green
Write-Host ''
Write-Host 'Total Distance:' -ForegroundColor White
Write-Host "  Pixels: $($distanceFormatted.Pixels)" -ForegroundColor Cyan
Write-Host "  Centimeters: $($distanceFormatted.Centimeters) cm" -ForegroundColor Cyan
Write-Host "  Meters: $($distanceFormatted.Meters) m" -ForegroundColor Cyan
Write-Host "  Inches: $($distanceFormatted.Inches) in" -ForegroundColor Cyan
Write-Host ''
Write-Host 'Statistics:' -ForegroundColor White
Write-Host "  Total Samples: $sampleCount" -ForegroundColor White
Write-Host "  Duration: $([Math]::Round($elapsed, 2)) seconds" -ForegroundColor White
Write-Host "  Average/Sample: $([Math]::Round($averageDistance, 2)) px" -ForegroundColor White
Write-Host "  Max/Sample: $([Math]::Round($maxDistance, 2)) px" -ForegroundColor White
Write-Host "  Min/Sample: $minDistanceDisplay px" -ForegroundColor White
Write-Host ''
Write-Host 'Velocity:' -ForegroundColor White
Write-Host "  Pixels/Second: $([Math]::Round($pixelsPerSecond, 2))" -ForegroundColor White
Write-Host "  CM/Second: $([Math]::Round($pixelsPerSecond / $script:pixelsPerCm, 2))" -ForegroundColor White
Write-Host "  Meters/Second: $([Math]::Round($pixelsPerSecond / $script:pixelsPerMeter, 4))" -ForegroundColor White
Write-Host ''

# Create INI file content
$iniContent = @"
; Mouse Distance Tracker Report - Console Mode
; Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
; Duration: $([Math]::Round($elapsed, 2)) seconds
; DPI: $DPI

[SUMMARY]
TotalDistancePixels=$($distanceFormatted.Pixels)
TotalDistanceCentimeters=$($distanceFormatted.Centimeters)
TotalDistanceMeters=$($distanceFormatted.Meters)
TotalDistanceInches=$($distanceFormatted.Inches)
TotalSamples=$sampleCount
TrackingDurationSeconds=$([Math]::Round($elapsed, 2))
AverageDistancePerSample=$([Math]::Round($averageDistance, 2))
MaxDistanceInSample=$([Math]::Round($maxDistance, 2))
MinDistanceInSample=$minDistanceDisplay
PixelsPerSecond=$([Math]::Round($pixelsPerSecond, 2))
CentimetersPerSecond=$([Math]::Round($pixelsPerSecond / $script:pixelsPerCm, 2))
MetersPerSecond=$([Math]::Round($pixelsPerSecond / $script:pixelsPerMeter, 4))
SamplingIntervalMilliseconds=$updateInterval

[TIMESTAMPS]
StartTime=$(Get-Date $startTime -Format 'yyyy-MM-dd HH:mm:ss.fff')
EndTime=$(Get-Date $endTime -Format 'yyyy-MM-dd HH:mm:ss.fff')

[SETTINGS]
DPI=$DPI
PixelsPerInch=$script:pixelsPerInch
PixelsPerCentimeter=$([Math]::Round($script:pixelsPerCm, 4))
PixelsPerMeter=$([Math]::Round($script:pixelsPerMeter, 2))
ScriptPath=$PSCommandPath
OutputFile=$iniPath
"@

# Append detailed samples if there are relatively few
if ($sampleCount -le 500)
{
    $iniContent += "`r`n[SAMPLES]`r`n"
    for ($i = 0; $i -lt $samples.Count; $i++)
    {
        $iniContent += "Sample$(($i + 1).ToString('D4'))=$([Math]::Round($samples[$i], 2))`r`n"
    }
}

# Save to INI file
$iniContent | Out-File -FilePath $iniPath -Encoding UTF8 -Force

Write-Host "✓ Results saved to: $iniPath" -ForegroundColor Green
Write-Host ''
Write-Host 'To view the INI file:' -ForegroundColor Cyan
Write-Host "  notepad `"$iniPath`"" -ForegroundColor Gray
Write-Host ''
Write-Host 'Thank you for using Mouse Distance Tracker!' -ForegroundColor Magenta

