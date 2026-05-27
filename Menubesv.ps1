#Requires -RunAsAdministrator
# ============================================================
# Auteur  : besv
# Bestand : Menubesv.ps1
# Doel    : Hoofdmenu voor automatische installatie en
#           configuratie van Windows Server 2025 en Windows 11
#
# Bronnen :
#   F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022/2025
#   https://learn.microsoft.com/en-us/powershell/module/
#     microsoft.powershell.core/about/about_modules
#   https://learn.microsoft.com/en-us/powershell/module/
#     microsoft.powershell.host/start-transcript
# ============================================================

$global:scriptRoot = $PSScriptRoot
$global:logBestand = "$PSScriptRoot\logs\InstallatieLogbesv.txt"

# ── Logmap aanmaken als die nog niet bestaat ──────────────────────────
$logMap = "$PSScriptRoot\logs"
if (-not (Test-Path $logMap)) {
    New-Item -ItemType Directory -Path $logMap -Force | Out-Null
}

# ── Transcript starten ────────────────────────────────────────────────
# Start-Transcript legt ALLES vast wat in deze PowerShell-sessie
# op het scherm verschijnt: menu-keuzes, foutmeldingen, module-output,
# cmdlet-resultaten – ook wat Schrijf-Log NIET expliciet logt.
# Het transcript wordt aangevuld (-Append) zodat herstarts niet
# het vorige transcript overschrijven.
# Bron: https://learn.microsoft.com/en-us/powershell/module/
#         microsoft.powershell.host/start-transcript
# Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 4
$transcriptBestand = "$PSScriptRoot\logs\TranscriptLogbesv.txt"
Start-Transcript -Path $transcriptBestand -Append -NoClobber:$false

Import-Module "$PSScriptRoot\modules\algemeenbesv.psm1"       -Force
Import-Module "$PSScriptRoot\modules\domainsettingsbesv.psm1" -Force

Write-Host "Logging actief:"                          -ForegroundColor DarkGray
Write-Host "  Installatielogboek : $global:logBestand" -ForegroundColor DarkGray
Write-Host "  Volledig transcript: $transcriptBestand"  -ForegroundColor DarkGray
Write-Host ""

# ─────────────────────────────────────────────────────────────────────
function Toon-HoofdMenu {
<#
.SYNOPSIS
    Toont het hoofdmenu van de installatietool.
.DESCRIPTION
    Startpunt van alle scripts. De gebruiker kiest tussen
    Windows Server 2025, Windows 11 of domein configuratie.
    Roept het bijhorende submenu op.
.EXAMPLE
    Toon-HoofdMenu
#>
    do {
        Clear-Host
        Write-Host "===============================" -ForegroundColor Cyaan
        Write-Host "   PowerShell Installatietool"  -ForegroundColor Cyaan
        Write-Host "===============================" -ForegroundColor Cyaan
        Write-Host ""
        Write-Host "  1 : Windows Server 2025"
        Write-Host "  2 : Windows 11"
        Write-Host "  3 : Domein configuratie"
        Write-Host ""
        Write-Host "  Q : Afsluiten"
        Write-Host ""

        $keuze = Read-Host "Maak uw keuze"

        switch ($keuze.ToUpper()) {
            "1" { Toon-ServerMenu }
            "2" { Toon-ClientMenu }
            "3" { Toon-DomeinMenu }
            "Q" {
                    Write-Host "Programma afgesloten."
                    # Transcript netjes afsluiten voor we stoppen
                    # Bron: https://learn.microsoft.com/en-us/powershell/module/
                    #         microsoft.powershell.host/stop-transcript
                    Stop-Transcript
                    exit
                }
            default { Write-Host "Ongeldige keuze, probeer opnieuw." -ForegroundColor Rood ; Start-Sleep 1 }
        }
    } while ($true)
}

# ─────────────────────────────────────────────────────────────────────
function Toon-ServerMenu {
<#
.SYNOPSIS
    Submenu voor de basisconfiguratie van Windows Server 2025.
.DESCRIPTION
    Biedt twee opties: computernaam instellen met automatische
    herstart, en IP-configuratie instellen via Computer.Settings.xml.
.EXAMPLE
    Toon-ServerMenu
#>
    do {
        Clear-Host
        Write-Host "===============================" -ForegroundColor Cyaan
        Write-Host "   Windows Server 2025"          -ForegroundColor Cyaan
        Write-Host "===============================" -ForegroundColor Cyaan
        Write-Host ""
        Write-Host "  1 : Computernaam instellen (met herstart)"
        Write-Host "  2 : IP-configuratie instellen"
        Write-Host ""
        Write-Host "  Q : Terug naar hoofdmenu"
        Write-Host ""

        $keuze = Read-Host "Maak uw keuze"

        switch ($keuze.ToUpper()) {
            "1" { Stel-ComputernaamIn -ComputerType "Server" }
            "2" { Stel-NetwerkconfigIn }
            "Q" { return }
            default { Write-Host "Ongeldige keuze." -ForegroundColor Rood ; Start-Sleep 1 }
        }
    } while ($true)
}

# ─────────────────────────────────────────────────────────────────────
function Toon-ClientMenu {
<#
.SYNOPSIS
    Submenu voor de basisconfiguratie van Windows 11.
.DESCRIPTION
    Biedt twee opties: computernaam instellen met automatische
    herstart, en IP-configuratie instellen via Computer.Settings.xml.
.EXAMPLE
    Toon-ClientMenu
#>
    do {
        Clear-Host
        Write-Host "===============================" -ForegroundColor Cyaan
        Write-Host "   Windows 11"                   -ForegroundColor Cyaan
        Write-Host "===============================" -ForegroundColor Cyaan
        Write-Host ""
        Write-Host "  1 : Computernaam instellen (met herstart)"
        Write-Host "  2 : IP-configuratie instellen"
        Write-Host ""
        Write-Host "  Q : Terug naar hoofdmenu"
        Write-Host ""

        $keuze = Read-Host "Maak uw keuze"

        switch ($keuze.ToUpper()) {
            "1" { Stel-ComputernaamIn -ComputerType "Client" }
            "2" { Stel-NetwerkconfigIn }
            "Q" { return }
            default { Write-Host "Ongeldige keuze." -ForegroundColor Rood ; Start-Sleep 1 }
        }
    } while ($true)
}

# ─────────────────────────────────────────────────────────────────────
function Toon-DomeinMenu {
<#
.SYNOPSIS
    Submenu voor de volledige domeinconfiguratie.
.DESCRIPTION
    Biedt alle opties voor Active Directory: domeincontroller,
    OUs, security groups, gebruikers, groepsleden,
    mappen, shares en NTFS/share-rechten.
.EXAMPLE
    Toon-DomeinMenu
#>
    do {
        Clear-Host
        Write-Host "===============================" -ForegroundColor Cyaan
        Write-Host "   Domein configuratie"          -ForegroundColor Cyaan
        Write-Host "===============================" -ForegroundColor Cyaan
        Write-Host ""
        Write-Host "  1 : Domeincontroller installeren"
        Write-Host "  2 : OUs aanmaken"
        Write-Host "  3 : Security groups aanmaken"
        Write-Host "  4 : Gebruikers aanmaken"
        Write-Host "  5 : Gebruikers aan groepen toevoegen"
        Write-Host "  6 : Mappen aanmaken"
        Write-Host "  7 : Shares aanmaken"
        Write-Host "  8 : NTFS- en share-rechten instellen"
        Write-Host ""
        Write-Host "  Q : Terug naar hoofdmenu"
        Write-Host ""

        $keuze = Read-Host "Maak uw keuze"

        switch ($keuze.ToUpper()) {
            "1" { Installeer-Domeincontroller }
            "2" { Maak-OUsAan }
            "3" { Maak-SecurityGroupsAan }
            "4" { Maak-DomeingebruikersAan }
            "5" { Voeg-GebruikersToeAanGroepen }
            "6" { Maak-MappensctructuurAan }
            "7" { Maak-SharesAan }
            "8" { Stel-RechtenIn }
            "Q" { return }
            default { Write-Host "Ongeldige keuze." -ForegroundColor Rood ; Start-Sleep 1 }
        }
    } while ($true)
}

# ─────────────────────────────────────────────────────────────────────
Toon-HoofdMenu
