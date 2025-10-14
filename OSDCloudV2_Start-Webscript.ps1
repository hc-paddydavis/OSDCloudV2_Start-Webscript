#=============================================================================
#region SCRIPT DETAILS
#=============================================================================

<#
.SYNOPSIS
Boots into the OSDCloud environment, updates OSD modules, and configures the startnet.cmd script.

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
# Set Variables
$OSDVersion = (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version

# Add OSD to Boot Image
Save-Module -Name OSD -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force

# Set Startnet.cmd
$StartnetCMD = @"
@ECHO OFF
wpeinit
cd\
title OSD $OSDVersion
PowerShell -Nol -C Initialize-OSDCloudStartnet
PowerShell -Nol -C Initialize-OSDCloudStartnetUpdate
@ECHO OFF
start /wait PowerShell -NoL -W Mi -C Invoke-WebPSScript 'https://bit.ly/3u04v1d'
"@

$StartnetCMD | Out-File -FilePath "$MountPath\Windows\System32\Startnet.cmd" -Encoding ascii -Width 2000 -Force
#=============================================================================
#endregion
#=============================================================================