<#
.NOTES
    Author         : Chris Titus @christitustech
    Runspace Author: @DeveloperDurp
    GitHub         : https://github.com/ChrisTitusTech
    Version        : #{replaceme}
#>

param (
    [switch]$Debug,
    [string]$Config,
    [switch]$Run
)

# Set DebugPreference based on the -Debug switch
if ($Debug) {
    $DebugPreference = "Continue"
}

if ($Config) {
    $PARAM_CONFIG = $Config
}

$PARAM_RUN = $false
# Handle the -Run switch
if ($Run) {
    Write-Host "Running config file tasks..."
    $PARAM_RUN = $true
}

# Load DLLs
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Variable to sync between runspaces
$sync = [Hashtable]::Synchronized(@{})
$sync.PSScriptRoot = $PSScriptRoot
$sync.version = "#{replaceme}"
$sync.configs = @{}
$sync.ProcessRunning = $false

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Winutil needs to be run as Administrator. Attempting to relaunch."

    $wtInstalled = Get-Command wt.exe -ErrorAction SilentlyContinue
    $pwshInstalled = Get-Command pwsh -ErrorAction SilentlyContinue 
    if ($pwshInstalled) {
        $powershellcmd = "pwsh"
    } else {
        $powershellcmd = "powershell"
    }

    if ($wtInstalled) {
        Start-Process wt.exe -ArgumentList "new-tab $powershellcmd -ExecutionPolicy Bypass -Command `"irm https://christitus.com/win | iex`"" -Verb RunAs
    } else {
        Start-Process $powershellcmd -ArgumentList "-ExecutionPolicy Bypass -Command `"irm https://christitus.com/win | iex`"" -Verb RunAs
    }

    break
}

$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

$logdir = "$env:localappdata\winutil\logs"
[System.IO.Directory]::CreateDirectory("$logdir") | Out-Null
Start-Transcript -Path "$logdir\winutil_$dateTime.log" -Append -NoClobber | Out-Null

# Set PowerShell window title
$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Admin)"
clear-host
