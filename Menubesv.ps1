#Requires -RunAsAdministrator
# Author: besv
# File: Menubesv.ps1
# Purpose: main menu for Windows Server 2025, Windows 11 and Active Directory automation.
#
# Sources per function with page numbers:
# - Pause-BESV: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   functions/scripts p. 221-224; basic cmdlets/help p. 18-21.
# - Show-BESVHeader: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   output/screen formatting p. 40-43; functions/scripts p. 221-224.
# - Invoke-BESVAction: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   functions/scripts p. 221-224; error handling and try/catch/finally p. 238-239.
# - Main menu and switch choices: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   switch statement p. 85; scripts and modules p. 221-224.
# - Register Task option: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   linking a PowerShell script to Task Scheduler p. 293.
# - AutoStart/RunOnce option: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   automatically starting PowerShell as administrator p. 35 and p. 124.
# - Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and
#   Active Directory Management": background source for menu-driven administration,
#   logging and Windows Server automation; the EPUB has no fixed printed page numbers.

$global:scriptRoot = $PSScriptRoot
$global:logBestand = Join-Path $PSScriptRoot 'logs\InstallatieLogbesv.txt'

Import-Module (Join-Path $PSScriptRoot 'modules\algemeenbesv.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'modules\domainsettingsbesv.psm1') -Force

Test-BESVAdministrator
Write-BESVLog 'Menubesv.ps1 started.' INFO

# Sources for function Pause-BESV:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functions/scripts p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on menu-driven administration automation.
function Pause-BESV {
<#
.SYNOPSIS
Pauses the menu until the user presses ENTER.

.DESCRIPTION
Keeps the result of an action visible before the main menu is shown again.

.EXAMPLE
Pause-BESV

.NOTES
Author : besv
Sources:
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functions chapter.
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functions/scripts p. 221-224.
- Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and Active Directory Management",
  chapter/section on menu-driven administration automation and logging.
#>
    Write-Host ''
    Read-Host 'Press ENTER to continue'
}

# Sources for function Show-BESVHeader:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, output/screen formatting p. 40-43,
#   functions/scripts p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on readable console output.
function Show-BESVHeader {
<#
.SYNOPSIS
Shows the title bar of the main menu.

.DESCRIPTION
Uses colors and a fixed title layout to make the menu more readable.

.PARAMETER Title
The title shown at the top of the menu.

.EXAMPLE
Show-BESVHeader -Title 'BESV PowerShell automation'

.NOTES
Author : besv
Sources:
- Microsoft Learn, Write-Host:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/write-host
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, output/screen formatting p. 40-43,
  functions/scripts p. 221-224.
- Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and Active Directory Management",
  chapter/section on administration menus and readable console output.
#>
    param([string]$Title)

    Clear-Host
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ('  ' + $Title) -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

# Sources for function Invoke-BESVAction:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functions/scripts p. 221-224,
#   try/catch/finally p. 238-239.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on logging and error handling.
function Invoke-BESVAction {
<#
.SYNOPSIS
Runs a selected menu action and logs the result.

.DESCRIPTION
Starts a script block from the menu, writes start/end entries to the log file
and catches errors so the menu does not stop completely.

.PARAMETER Name
Action name for screen output and logging.

.PARAMETER Action
Script block to execute.

.EXAMPLE
Invoke-BESVAction -Name 'Create OUs' -Action { New-BESVOrganizationalUnits }

.NOTES
Author : besv
Sources:
- Microsoft Learn, about_Try_Catch_Finally:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functions/scripts p. 221-224,
  error handling and try/catch/finally p. 238-239.
- Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and Active Directory Management",
  chapter/section on logging, error handling and robust automation.
#>
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    try {
        Write-BESVLog "Starting action: $Name" INFO
        & $Action
        Write-BESVLog "Finished action: $Name" OK
    }
    catch {
        Write-BESVLog "ERROR in action '$Name': $($_.Exception.Message)" ERROR
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Pause-BESV
}

do {
    Show-BESVHeader 'BESV scripting project - AP Hogeschool SNB'
    Write-Host '  1  Base configuration Windows Server: set computer name' -ForegroundColor Green
    Write-Host '  2  Base configuration Windows Server: set network' -ForegroundColor Green
    Write-Host '  3  Base configuration Windows Client: set computer name' -ForegroundColor DarkYellow
    Write-Host '  4  Base configuration Windows Client: set network' -ForegroundColor DarkYellow
    Write-Host '  5  Install domain controller' -ForegroundColor Green
    Write-Host '  6  Create OUs' -ForegroundColor Green
    Write-Host '  7  Create security groups' -ForegroundColor Green
    Write-Host '  8  Create folders and shares' -ForegroundColor Green
    Write-Host '  9  Create domain users' -ForegroundColor Green
    Write-Host ' 10  Add domain users to security groups' -ForegroundColor Green
    Write-Host ' 11  Apply NTFS and share permissions' -ForegroundColor Green
    Write-Host ' 12  Configure Register Task' -ForegroundColor Cyan
    Write-Host ' 13  Configure AutoStart with RunOnce' -ForegroundColor Cyan
    Write-Host ' 14  Disable autologon' -ForegroundColor Cyan
    Write-Host ' 15  Full configuration after domain controller installation' -ForegroundColor Cyan
    Write-Host '  Q  Exit script' -ForegroundColor Yellow
    Write-Host ''

    $choice = Read-Host 'Choice'

    switch ($choice.ToUpper()) {
        '1'  { Invoke-BESVAction 'Set server computer name' { Set-BESVComputerName -ConfigureAutoLogon } }
        '2'  { Invoke-BESVAction 'Set server network configuration' { Set-BESVNetworkConfiguration } }
        '3'  { Invoke-BESVAction 'Set client computer name' { Set-BESVComputerName -ConfigureAutoLogon } }
        '4'  { Invoke-BESVAction 'Set client network configuration' { Set-BESVNetworkConfiguration } }
        '5'  { Invoke-BESVAction 'Install domain controller' { New-BESVDomainController } }
        '6'  { Invoke-BESVAction 'Create OUs' { New-BESVOrganizationalUnits } }
        '7'  { Invoke-BESVAction 'Create security groups' { New-BESVSecurityGroups } }
        '8'  { Invoke-BESVAction 'Create folders and shares' { New-BESVFolders; New-BESVShares } }
        '9'  { Invoke-BESVAction 'Create domain users' { New-BESVDomainUsers } }
        '10' { Invoke-BESVAction 'Add users to groups' { Add-BESVUsersToGroups } }
        '11' { Invoke-BESVAction 'Apply permissions' { Set-BESVShareAndNtfsRights } }
        '12' { Invoke-BESVAction 'Configure Register Task' { Register-BESVStartupTask -ScriptPath (Join-Path $PSScriptRoot 'Menubesv.ps1') } }
        '13' { Invoke-BESVAction 'Configure AutoStart with RunOnce' { Register-BESVRunOnce -ScriptPath (Join-Path $PSScriptRoot 'Menubesv.ps1') } }
        '14' { Invoke-BESVAction 'Disable autologon' { Disable-BESVAutoLogon } }
        '15' { Invoke-BESVAction 'Full configuration' { New-BESVOrganizationalUnits; New-BESVSecurityGroups; New-BESVFolders; New-BESVShares; New-BESVDomainUsers; Add-BESVUsersToGroups; Set-BESVShareAndNtfsRights } }
        'Q'  { Write-BESVLog 'Menubesv.ps1 closed.' INFO; break }
        default {
            Write-Host 'Invalid choice.' -ForegroundColor Red
            Start-Sleep 1
        }
    }
} while ($true)
