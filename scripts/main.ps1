# SPDX-License-Identifier: MIT

# Set the maximum number of threads for the RunspacePool to the number of threads on the machine
$maxthreads = [int]$env:NUMBER_OF_PROCESSORS

# Create a new session state for parsing variables into our runspace
$hashVars = New-object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'sync',$sync,$Null
$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

# Add the variable to the session state
$InitialSessionState.Variables.Add($hashVars)

# Get every private function and add them to the session state
$functions = Get-ChildItem function:\ | Where-Object {$_.name -like "*winutil*" -or $_.name -like "*WPF*"}
foreach ($function in $functions){
    $functionDefinition = Get-Content function:\$($function.name)
    $functionEntry = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $($function.name), $functionDefinition

    $initialSessionState.Commands.Add($functionEntry)
}

# Create the runspace pool
$sync.runspace = [runspacefactory]::CreateRunspacePool(
    1,                      # Minimum thread count
    $maxthreads,            # Maximum thread count
    $InitialSessionState,   # Initial session state
    $Host                   # Machine to create runspaces on
)

# Open the RunspacePool instance
$sync.runspace.Open()

# Create classes for different exceptions

    class WingetFailedInstall : Exception {
        [string] $additionalData

        WingetFailedInstall($Message) : base($Message) {}
    }

    class ChocoFailedInstall : Exception {
        [string] $additionalData

        ChocoFailedInstall($Message) : base($Message) {}
    }

    class GenericException : Exception {
        [string] $additionalData

        GenericException($Message) : base($Message) {}
    }


$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'

if ((Get-WinUtilToggleStatus WPFToggleDarkMode) -eq $True){
    $ctttheme = 'Matrix'
}
Else{
    $ctttheme = 'Classic'
}

$inputXML = Set-WinUtilUITheme -inputXML $inputXML -themeName $ctttheme

[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML

# Read the XAML file
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try { $sync["Form"] = [Windows.Markup.XamlReader]::Load( $reader ) }
catch [System.Management.Automation.MethodInvocationException] {
    Write-Warning "We ran into a problem with the XAML code.  Check the syntax for this control..."
    Write-Host $error[0].Exception.Message -ForegroundColor Red
    If ($error[0].Exception.Message -like "*button*") {
        write-warning "Ensure your &lt;button in the `$inputXML does NOT have a Click=ButtonClick property.  PS can't handle this`n`n`n`n"
    }
}
catch {
    Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."
}

#===========================================================================
# Store Form Objects In PowerShell
#===========================================================================

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {$sync["$("$($psitem.Name)")"] = $sync["Form"].FindName($psitem.Name)}

$sync.keys | ForEach-Object {
    if($sync.$psitem){
        if($($sync["$psitem"].GetType() | Select-Object -ExpandProperty Name) -eq "Button"){
            $sync["$psitem"].Add_Click({
                [System.Object]$Sender = $args[0]
                Invoke-WPFButton $Sender.name
            })
        }
    }
}


$sync.keys | ForEach-Object {
    if($sync.$psitem){
        if(
            $($sync["$psitem"].GetType() | Select-Object -ExpandProperty Name) -eq "CheckBox" `
            -and $sync["$psitem"].Name -like "WPFToggle*"
        ){
            $sync["$psitem"].IsChecked = Get-WinUtilToggleStatus $sync["$psitem"].Name

            $sync["$psitem"].Add_Click({
                [System.Object]$Sender = $args[0]
                Invoke-WPFToggle $Sender.name
            })
        }
    }
}


#===========================================================================
# Setup background config
#===========================================================================

# Load computer information in the background
Invoke-WPFRunspace -ScriptBlock {
    $sync.ConfigLoaded = $False

    $sync.ComputerInfo = Get-ComputerInfo

    $sync.ConfigLoaded = $True
} | Out-Null

#===========================================================================
# Setup and Show the Form
#===========================================================================

# Print the logo
Invoke-WPFFormVariables

# Check if Chocolatey is installed
Install-WinUtilChoco

# Set the titlebar
$sync["Form"].title = $sync["Form"].title + " " + $sync.version
# Set the commands that will run when the form is closed
$sync["Form"].Add_Closing({
    $sync.runspace.Dispose()
    $sync.runspace.Close()
    [System.GC]::Collect()
})

# adding some left mouse window move on drag capability
$sync["Form"].Add_MouseLeftButtonDown({
    $sync["Form"].DragMove()
})

# setting window icon to make it look more professional
$sync["Form"].add_Loaded({
   
    $sync["Form"].Icon = "https://christitus.com/images/logo-full.png"

    Try { 
        [Void][Window]
    } Catch {
        Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class Window {
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool MoveWindow(IntPtr handle, int x, int y, int width, int height, bool redraw);
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool ShowWindow(IntPtr handle, int state);
        }
        public struct RECT {
            public int Left;   // x position of upper-left corner
            public int Top;    // y position of upper-left corner
            public int Right;  // x position of lower-right corner
            public int Bottom; // y position of lower-right corner
        }
"@
    }
    
    $processId  = [System.Diagnostics.Process]::GetCurrentProcess().Id
    $windowHandle  = (Get-Process -Id $processId).MainWindowHandle
    $rect = New-Object RECT
    [Void][Window]::GetWindowRect($windowHandle,[ref]$rect)
    
    # only snap upper edge don't move left to right, in case people have multimon setup
    $x = $rect.Left
    $y = 0
    $width  = $rect.Right  - $rect.Left
    $height = $rect.Bottom - $rect.Top
    
    # Move the window to that position...
    [Void][Window]::MoveWindow($windowHandle, $x, $y, $width, $height, $True)
})
$sync["Form"].ShowDialog() | out-null
Stop-Transcript