#Requires -RunAsAdministrator
#Requires -Module OSD
#Requires -Module OSDCloud
#=============================================================================
#region SCRIPT DETAILS
#=============================================================================

<#
.SYNOPSIS
Boots into the OSDCloud environment, updates OSD modules, and configures the startnet.cmd script.

.NOTES
The initial PowerShell commands should always contain the -WindowStyle Hidden parameter to prevent the PowerShell window from appearing on the screen.
powershell.exe -WindowStyle Hidden -Command {command}

This will prevent PowerShell from rebooting since the window will not be visible.
powershell.exe -WindowStyle Hidden -NoExit -Command {command}

The final PowerShell command should contain the -NoExit parameter to keep the PowerShell window open and to prevent the WinPE environment from restarting.
powershell.exe -WindowStyle Hidden -NoExit -Command {command}

Wpeinit and Startnet.cmd: Using WinPE Startup Scripts
https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/wpeinit-and-startnetcmd-using-winpe-startup-scripts?view=windows-11

.EXAMPLE
PS C:\> OSDCloudV2_Start-Webscript.ps1
#>

#=============================================================================
#endregion
#=============================================================================
#region Prerequisites
#=============================================================================

$OS = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
$Windows = ($OS -match 'Windows')
if (!$Windows) {
    Write-Output 'OS is not Windows.  This script is only intended for Windows devices'
    exit 666
}

#=============================================================================
#endregion
#=============================================================================
#region VARIABLES
#=============================================================================

# Run with verbose to see all output
$VerbosePreference = 'Continue'
# Disable logging to the console
$EnableLogging = $False
# Logfile Name
$LogFileName = 'ExampleScript.log'
# Logfile Path
$LogFile = "$ENV:ProgramData\Microsoft\IntuneManagementExtension\Logs\$LogFileName"

#=============================================================================
#endregion
#=============================================================================
#region FUNCTIONS
#=============================================================================

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,Position = 0)][String]$LogText,
        [Parameter(Mandatory = $false,Position = 1)][System.ConsoleColor]$Color = [System.ConsoleColor]::White
    )
    <#
    .SYNOPSIS
    Reusable snippet for logging

    .INPUTS
    String to go into the log

    .OUTPUTS
    Writes date+time and entered string to log file
    #>

    if ($EnableLogging) {
        $CurrentTime = Get-Date
        Add-Content $LogFile "$CurrentTime - $LogText"
    }
    Write-Host $LogText -ForegroundColor $Color
}

#=============================================================================
#endregion
#=============================================================================
#region EXECUTION
#=============================================================================

if ($EnableLogging) {
    if (!(Test-Path $LogFile)) {
        New-Item -ItemType File -Path $LogFile -Force
    }
}
Write-Log "Computer Name is: $((Get-CimInstance -ClassName Win32_ComputerSystem).Name)" DarkYellow
Write-Log "Current Time Zone is $((Get-TimeZone).DisplayName)" DarkYellow
#=============================================================================
# Copy PowerShell Modules
#=============================================================================
# Make sure they are up to date on your device before running this script.
$ModuleNames = @('OSD', 'OSDCloud')
$ModuleNames | ForEach-Object {
    $ModuleName = $_
    Write-Host -ForegroundColor DarkGray "[$(Get-Date -Format G)] [$($MyInvocation.MyCommand.Source)] Copy PowerShell Module to BootImage: $ModuleName"
    Copy-PSModuleToWindowsImage -Name $ModuleName -Path $MountPath | Out-Null
    # As an alternative, you can use the following command to get the latest from PowerShell Gallery:
    # Save-Module -Name $ModuleName -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
}

#=============================================================================
#Setup WinPE with Wallpaper
#=============================================================================

$Wallpaper = 'C:\OSDWorkspace\submodules\osdcloud_wallpaper\Hennepin.jpg'
# if wallpaper file exists, update the mounted windows image
if (Test-Path $Wallpaper) {
    Copy-Item -Path $Wallpaper -Destination "$env:TEMP\winpe.jpg" -Force | Out-Null
    Copy-Item -Path $Wallpaper -Destination "$env:TEMP\winre.jpg" -Force | Out-Null
    robocopy "$env:TEMP" "$MountPath\Windows\System32" winpe.jpg /ndl /njh /njs /b /np /r:0 /w:0
    robocopy "$env:TEMP" "$MountPath\Windows\System32" winre.jpg /ndl /njh /njs /b /np /r:0 /w:0
}
#=============================================================================
#endregion
#=============================================================================
#=============================================================================
# Startnet.cmd
#=============================================================================
# Set Variables
$OSDVersion = (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version

# Set Startnet.cmd
$StartnetCMD = @"
@ECHO OFF
wpeinit
cd\
title OSD $OSDVersion
wpeinit
wpeutil DisableFirewall
wpeutil UpdateBootInfo
powershell.exe -w h -c Invoke-OSDCloudPEStartup DeviceHardware
powershell.exe -w h -c Invoke-OSDCloudPEStartup WiFi
powershell.exe -w h -c Invoke-OSDCloudPEStartup IPConfig
powershell.exe -w h -c Invoke-OSDCloudPEStartup UpdateModule -Value OSD
powershell.exe -w h -c Invoke-OSDCloudPEStartup UpdateModule -Value OSDCloud
@ECHO OFF
start /wait PowerShell -NoL -W Mi -C Invoke-WebPSScript 'https://bit.ly/3u04v1d'
"@

Write-Host -ForegroundColor DarkGray "[$(Get-Date -Format G)] [$($MyInvocation.MyCommand.Source)] Adding $MountPath\Windows\System32\startnet.cmd"
$StartnetCMD | Out-File -FilePath "$MountPath\Windows\System32\startnet.cmd" -Encoding ascii -Width 2000 -Force
#=============================================================================
#endregion
#=============================================================================