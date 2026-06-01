#Requires -RunAsAdministrator
# Voornaam en naam student: Svetlana Berkovska (BESV)
# Olod: Scripting - Projectwerk exam
# Projectwerkbegeleider: Nick Van Acker
# Academiejaar: 2025/2026
# AP Hogeschool
# Bestand: Menubesv.ps1
# Doel: hoofdmenu voor automatisatie van Windows Server 2025, Windows 11 en Active Directory.
#
# Bronnen per functie met paginanummers:
# - Pause-BESV: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   functies/scripts p. 221-224; basis-cmdlets en hulp p. 18-21.
# - Show-BESVHeader: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   output wijzigen/schermuitvoer p. 40-43; functies/scripts p. 221-224.
# - Invoke-BESVAction: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   functies/scripts p. 221-224; fouten opvangen en try/catch/finally p. 238-239.
# - Hoofdmenu en switch-keuzes: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   switch-statement p. 85; scripts en modules p. 221-224.
# - Register Task optie: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   PowerShell-script koppelen aan Taakplanner p. 293.
# - AutoStart/RunOnce optie: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   PowerShell automatisch starten als administrator p. 35 en p. 124.
# - Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and
#   Active Directory Management": achtergrondbron voor menu-gedreven beheer,
#   logging en Windows Server automatisatie; EPUB heeft geen vaste papieren paginanummers.

$global:scriptRoot = $PSScriptRoot
$global:logBestand = Join-Path $PSScriptRoot 'logs\InstallatieLogbesv.txt'

Import-Module (Join-Path $PSScriptRoot 'modules\algemeenbesv.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'modules\domainsettingsbesv.psm1') -Force

Test-BESVAdministrator
Write-BESVLog 'Menubesv.ps1 gestart.' INFO

# Bronnen functie Pause-BESV:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functies/scripts p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie menu-gedreven beheerautomatisatie.
function Pause-BESV {
<#
.SYNOPSIS
Pauzeert het menu tot de gebruiker op ENTER drukt.

.DESCRIPTION
Deze hulpfunctie houdt het resultaat van een actie zichtbaar voordat het
hoofdmenu opnieuw getoond wordt.

.EXAMPLE
Pause-BESV

.NOTES
Auteur : besv
Bronnen:
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, hoofdstuk functies.
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functies/scripts p. 221-224.
- Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and Active Directory Management",
  hoofdstuk/sectie over menu-gedreven beheerautomatisatie en logging.
#>
    Write-Host ''
    Read-Host 'Druk op ENTER om verder te gaan'
}

# Bronnen functie Show-BESVHeader:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, output wijzigen/schermuitvoer p. 40-43,
#   functies/scripts p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie leesbare console-output.
function Show-BESVHeader {
<#
.SYNOPSIS
Toont de titelbalk van het hoofdmenu.

.DESCRIPTION
Maakt het menu overzichtelijker met kleurgebruik en een vaste titelstructuur.

.PARAMETER Title
De titel die bovenaan het menu getoond wordt.

.EXAMPLE
Show-BESVHeader -Title 'BESV PowerShell automatisatie'

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Write-Host:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/write-host
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, output wijzigen/schermuitvoer p. 40-43,
  functies/scripts p. 221-224.
- Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and Active Directory Management",
  hoofdstuk/sectie over beheermenu's en duidelijke console-output.
#>
    param([string]$Title)

    Clear-Host
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host '  		Windows Server 2025 ' -ForegroundColor Green -NoNewline
    Write-Host '/ ' -ForegroundColor Blue -NoNewline
    Write-Host 'Windows 11' -ForegroundColor Magenta
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

# Bronnen functie Invoke-BESVAction:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functies/scripts p. 221-224,
#   try/catch/finally p. 238-239.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie logging en foutafhandeling.
function Invoke-BESVAction {
<#
.SYNOPSIS
Voert een gekozen menuactie uit en logt het resultaat.

.DESCRIPTION
Start een scriptblok vanuit het menu, schrijft begin/einde naar het logbestand
en vangt fouten op zodat het menu niet volledig stopt.

.PARAMETER Name
Naam van de actie voor schermuitvoer en logging.

.PARAMETER Action
Het scriptblok dat uitgevoerd moet worden.

.EXAMPLE
Invoke-BESVAction -Name 'OUs aanmaken' -Action { New-BESVOrganizationalUnits }

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, about_Try_Catch_Finally:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, functies/scripts p. 221-224,
  fouten opvangen en try/catch/finally p. 238-239.
- Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and Active Directory Management",
  hoofdstuk/sectie over logging, foutafhandeling en robuuste automatisatie.
#>
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    try {
        Write-BESVLog "Start actie: $Name" INFO
        & $Action
        Write-BESVLog "Einde actie: $Name" OK
    }
    catch {
        if ($_.Exception -is [System.OperationCanceledException]) {
            Write-BESVLog "Actie geannuleerd: $Name" WARN
            Write-Host 'Actie geannuleerd. Je keert terug naar het menu.' -ForegroundColor Yellow
        } else {
            Write-BESVLog "FOUT in actie '$Name': $($_.Exception.Message)" ERROR
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    Pause-BESV
}

do {
    Show-BESVHeader
    Write-Host '  1  Basisconfiguratie Windows Server: computernaam instellen' -ForegroundColor Green
    Write-Host '  2  Basisconfiguratie Windows Server: netwerk instellen' -ForegroundColor Green
    Write-Host '  3  Basisconfiguratie Windows Client: computernaam instellen' -ForegroundColor Magenta
    Write-Host '  4  Basisconfiguratie Windows Client: netwerk instellen' -ForegroundColor Magenta
    Write-Host '  5  Domain controller installeren' -ForegroundColor Green
    Write-Host '  6  OUs aanmaken' -ForegroundColor Green
    Write-Host '  7  Security groups aanmaken' -ForegroundColor Green
    Write-Host '  8  Mappen en shares aanmaken' -ForegroundColor Green
    Write-Host '  9  Domain users aanmaken' -ForegroundColor Green
    Write-Host ' 10  Domain users aan security groups toevoegen' -ForegroundColor Green
    Write-Host ' 11  NTFS- en share-rechten instellen' -ForegroundColor Green
    Write-Host ' 12  Register Task instellen' -ForegroundColor Cyan
    Write-Host ' 13  AutoStart instellen via RunOnce' -ForegroundColor Cyan
    Write-Host ' 14  Autologon uitschakelen' -ForegroundColor Cyan
    Write-Host ' 15  Volledige configuratie na domain controller installatie' -ForegroundColor Cyan
    Write-Host ' 16  Windows Client toevoegen aan domain' -ForegroundColor Magenta
    Write-Host '  Q  Script afsluiten' -ForegroundColor Yellow
    Write-Host ''

    $choice = Read-Host 'Keuze'

    switch ($choice.ToUpper()) {
        '1'  { Invoke-BESVAction 'Server computernaam instellen' { Set-BESVComputerName -ConfigureAutoLogon } }
        '2'  { Invoke-BESVAction 'Server netwerk instellen' { Set-BESVNetworkConfiguration -Target Server } }
        '3'  { Invoke-BESVAction 'Client computernaam instellen' { Set-BESVComputerName -ConfigureAutoLogon } }
        '4'  { Invoke-BESVAction 'Client netwerk instellen' { Set-BESVNetworkConfiguration -Target Client } }
        '5'  { Invoke-BESVAction 'Domain controller installeren' { New-BESVDomainController } }
        '6'  { Invoke-BESVAction 'OUs aanmaken' { New-BESVOrganizationalUnits } }
        '7'  { Invoke-BESVAction 'Security groups aanmaken' { New-BESVSecurityGroups } }
        '8'  { Invoke-BESVAction 'Mappen en shares aanmaken' { New-BESVFolders; New-BESVShares } }
        '9'  { Invoke-BESVAction 'Domain users aanmaken' { New-BESVDomainUsers } }
        '10' { Invoke-BESVAction 'Users aan groepen toevoegen' { Add-BESVUsersToGroups } }
        '11' { Invoke-BESVAction 'Rechten toekennen' { Set-BESVShareAndNtfsRights } }
        '12' { Invoke-BESVAction 'Register Task instellen' { Register-BESVStartupTask -ScriptPath (Join-Path $PSScriptRoot 'Menubesv.ps1') } }
        '13' { Invoke-BESVAction 'AutoStart instellen via RunOnce' { Register-BESVRunOnce -ScriptPath (Join-Path $PSScriptRoot 'Menubesv.ps1') } }
        '14' { Invoke-BESVAction 'Autologon uitschakelen' { Disable-BESVAutoLogon } }
        '15' { Invoke-BESVAction 'Volledige configuratie' { New-BESVOrganizationalUnits; New-BESVSecurityGroups; New-BESVFolders; New-BESVShares; New-BESVDomainUsers; Add-BESVUsersToGroups; Set-BESVShareAndNtfsRights } }
        '16' { Invoke-BESVAction 'Windows Client toevoegen aan domain' { Join-BESVDomain -Restart } }
        'Q'  { Write-BESVLog 'Menubesv.ps1 afgesloten.' INFO; break }
        default {
            Write-Host 'Ongeldige keuze.' -ForegroundColor Red
            Start-Sleep 1
        }
    }
} while ($true)
