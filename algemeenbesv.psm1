# ============================================================
# Auteur  : besv
# Bestand : algemeenbesv.psm1
# Doel    : Algemene configuratiefuncties voor:
#           - Windows Server 2025
#           - Windows 11 client
#           - netwerkconfiguratie
#           - logging
#           - computernaam
#           - VMware netwerkadapters
#
# Beschrijving :
# Deze module bevat alle basisfuncties die nodig zijn
# voor de initiële configuratie van server en client.
#
# Bronnen :
#
# Boek:
#   F. Vanhoo,
#   "PowerShell Vlot gebruiken",
#   Die Keure, tweede editie, 2022/2025
#
#   Gebruikte hoofdstukken:
#   - Hfst. 24  : PowerShell automatisch starten
#   - Hfst. 41  : Modules in PowerShell
#   - Hfst. 71  : Methoden, functies en cmdlets
#   - Hfst. 79  : CSV-bestanden
#   - Hfst. 80  : XML-bestanden
#   - Hfst. 83  : Where-Object
#   - Hfst. 107 : WMI
#   - Hfst. 108 : CIM-variabelen
#   - Hfst. 138 : Scripts en modules
#   - Hfst. 144 : Scripts, modules en functies opbouwen
#   - Hfst. 149 : Fouten opvangen
#   - Hfst. 151 : Try, catch en finally
#
# Microsoft Learn:
#   https://learn.microsoft.com/en-us/powershell/
#
# ============================================================

# ============================================================
# VARIABELEN
# ============================================================

$ScriptRoot = Split-Path `
    -Parent `
    $PSScriptRoot

$ComputerSettingsFile = `
    "$ScriptRoot\settings\Computer.Settings.xml"

$LogFolder = `
    "$ScriptRoot\logs"

$LogFile = `
    "$LogFolder\InstallatieLogbesv.txt"

# ============================================================
# FUNCTION : Write-BESVGeneralLog
# ============================================================

function Write-BESVGeneralLog {

<#
.SYNOPSIS
Schrijft meldingen weg naar logbestand.

.DESCRIPTION
Deze functie schrijft informatie weg naar het
centrale logbestand van het scriptingproject.

Elke regel bevat:
- datum
- tijdstip
- melding

.EXAMPLE
Write-BESVGeneralLog -Message "Server gestart"

.NOTES
Auteur : besv

Bestand :
algemeenbesv.psm1

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 71  : Methoden, functies en cmdlets
- Hfst. 144 : Scripts, modules en functies opbouwen

Microsoft Learn:
https://learn.microsoft.com/en-us/powershell/

Out-File:
https://learn.microsoft.com/en-us/powershell/module/
microsoft.powershell.utility/out-file

#>

    param(
        [string]$Message
    )

    if (-not(Test-Path $LogFolder)) {

        New-Item `
            -Path $LogFolder `
            -ItemType Directory `
            -Force | Out-Null
    }

    $CurrentDate = `
        Get-Date -Format "dd-MM-yyyy HH:mm:ss"

    "$CurrentDate - $Message" |
        Out-File `
        -FilePath $LogFile `
        -Append
}

# ============================================================
# FUNCTION : Import-BESVXMLSettings
# ============================================================

function Import-BESVXMLSettings {

<#
.SYNOPSIS
Leest XML configuratiebestand in.

.DESCRIPTION
Deze functie leest het XML-bestand in waarin
de netwerkconfiguratie van de machine staat.

Het bestand bevat:
- hostname
- adapters
- IP adressen
- DNS
- gateway
- DHCP instellingen

.EXAMPLE
Import-BESVXMLSettings

.NOTES
Auteur : besv

Bestand :
algemeenbesv.psm1

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 80 : XML-bestanden
- Hfst. 71 : Methoden, functies en cmdlets

Microsoft Learn:
https://learn.microsoft.com/en-us/powershell/

about_Xml:
https://learn.microsoft.com/en-us/powershell/module/
microsoft.powershell.utility/import-clixml

#>

    try {

        [xml]$Settings = `
            Get-Content $ComputerSettingsFile

        Write-BESVGeneralLog `
            -Message "XML instellingen geladen"

        return $Settings
    }
    catch {

        Write-Host ""
        Write-Host `
            "Fout bij laden XML instellingen." `
            -ForegroundColor Red

        Write-BESVGeneralLog `
            -Message "Fout bij laden XML instellingen"

        return $null
    }
}

# ============================================================
# FUNCTION : Set-BESVHostname
# ============================================================

function Set-BESVHostname {

<#
.SYNOPSIS
Wijzigt computernaam.

.DESCRIPTION
Deze functie leest de hostname uit het XML-bestand
en wijzigt de computernaam.

xxx wordt automatisch vervangen door besv.

.EXAMPLE
Set-BESVHostname

.NOTES
Auteur : besv

Bestand :
algemeenbesv.psm1

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 71  : Methoden, functies en cmdlets
- Hfst. 107 : WMI
- Hfst. 149 : Fouten opvangen

Microsoft Learn:
https://learn.microsoft.com/en-us/powershell/

Rename-Computer:
https://learn.microsoft.com/en-us/powershell/module/
microsoft.powershell.management/rename-computer

#>

    $Settings = `
        Import-BESVXMLSettings

    if ($null -eq $Settings) {

        return
    }

    $ComputerName = `
        $Settings.Settings.name

    $ComputerName = `
        $ComputerName.Replace("xxx","besv")

    Write-Host ""
    Write-Host `
        "Computernaam wijzigen naar $ComputerName" `
        -ForegroundColor Cyan

    try {

        Rename-Computer `
            -NewName $ComputerName `
            -Force

        Write-BESVGeneralLog `
            -Message `
            "Computernaam gewijzigd naar $ComputerName"

        Write-Host `
            "Computernaam succesvol gewijzigd." `
            -ForegroundColor Green
    }
    catch {

        Write-Host `
            "Fout bij wijzigen computernaam." `
            -ForegroundColor Red

        Write-BESVGeneralLog `
            -Message `
            "Fout bij wijzigen computernaam"
    }
}

# ============================================================
# FUNCTION : Set-BESVNetworkAdapters
# ============================================================

function Set-BESVNetworkAdapters {

<#
.SYNOPSIS
Hernoemt netwerkadapters.

.DESCRIPTION
Deze functie zoekt netwerkadapters op basis van
MAC-address en hernoemt deze volgens de XML
configuratie.

Geschikt voor VMware adapters.

.EXAMPLE
Set-BESVNetworkAdapters

.NOTES
Auteur : besv

Bestand :
algemeenbesv.psm1

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 83  : Where-Object
- Hfst. 107 : WMI
- Hfst. 108 : CIM-variabelen
- Hfst. 149 : Fouten opvangen

Microsoft Learn:
https://learn.microsoft.com/en-us/powershell/

Get-NetAdapter:
https://learn.microsoft.com/en-us/powershell/module/
netadapter/get-netadapter

Rename-NetAdapter:
https://learn.microsoft.com/en-us/powershell/module/
netadapter/rename-netadapter

#>

    $Settings = `
        Import-BESVXMLSettings

    foreach ($Adapter in $Settings.Settings.networksettings.networkadapter) {

        $MacAddress = `
            $Adapter.macaddress.Replace("-",":")

        $AdapterName = `
            $Adapter.name

        $NetworkCard = `
            Get-NetAdapter | Where-Object {

                $_.MacAddress -eq $MacAddress
            }

        if ($null -ne $NetworkCard) {

            try {

                Rename-NetAdapter `
                    -Name $NetworkCard.Name `
                    -NewName $AdapterName `
                    -Confirm:$false

                Write-Host `
                    "Adapter hernoemd naar $AdapterName" `
                    -ForegroundColor Green

                Write-BESVGeneralLog `
                    -Message `
                    "Adapter hernoemd naar $AdapterName"
            }
            catch {

                Write-Host `
                    "Fout bij hernoemen adapter." `
                    -ForegroundColor Red

                Write-BESVGeneralLog `
                    -Message `
                    "Fout bij hernoemen adapter"
            }
        }
        else {

            Write-Host `
                "Adapter met MAC $MacAddress niet gevonden." `
                -ForegroundColor Yellow
        }
    }
}

# ============================================================
# FUNCTION : Set-BESVStaticIP
# ============================================================

function Set-BESVStaticIP {

<#
.SYNOPSIS
Configureert IP instellingen.

.DESCRIPTION
Deze functie configureert:
- DHCP
- statisch IP
- gateway
- DNS

volgens het XML configuratiebestand.

.EXAMPLE
Set-BESVStaticIP

.NOTES
Auteur : besv

Bestand :
algemeenbesv.psm1

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 80  : XML-bestanden
- Hfst. 83  : Where-Object
- Hfst. 107 : WMI
- Hfst. 149 : Fouten opvangen
- Hfst. 151 : Try, catch en finally

Microsoft Learn:
https://learn.microsoft.com/en-us/powershell/

New-NetIPAddress:
https://learn.microsoft.com/en-us/powershell/module/
nettcpip/new-netipaddress

Set-DnsClientServerAddress:
https://learn.microsoft.com/en-us/powershell/module/
dnsclient/set-dnsclientserveraddress

#>

    $Settings = `
        Import-BESVXMLSettings

    foreach ($Adapter in $Settings.Settings.networksettings.networkadapter) {

        $AdapterName = `
            $Adapter.name

        $DhcpEnabled = `
            $Adapter.dhcpenabled

        Write-Host ""
        Write-Host `
            "Configuratie adapter $AdapterName" `
            -ForegroundColor Cyan

        try {

            if ($DhcpEnabled -eq "true") {

                Set-NetIPInterface `
                    -InterfaceAlias $AdapterName `
                    -Dhcp Enabled

                Set-DnsClientServerAddress `
                    -InterfaceAlias $AdapterName `
                    -ResetServerAddresses

                Write-Host `
                    "DHCP ingeschakeld op $AdapterName" `
                    -ForegroundColor Green

                Write-BESVGeneralLog `
                    -Message `
                    "DHCP ingeschakeld op $AdapterName"
            }
            else {

                New-NetIPAddress `
                    -InterfaceAlias $AdapterName `
                    -IPAddress $Adapter.ip `
                    -PrefixLength $Adapter.prefixlength `
                    -DefaultGateway $Adapter.gateway `
                    -ErrorAction SilentlyContinue

                Set-DnsClientServerAddress `
                    -InterfaceAlias $AdapterName `
                    -ServerAddresses $Adapter.dns

                Write-Host `
                    "Statisch IP ingesteld op $AdapterName" `
                    -ForegroundColor Green

                Write-BESVGeneralLog `
                    -Message `
                    "Statisch IP ingesteld op $AdapterName"
            }
        }
        catch {

            Write-Host `
                "Fout tijdens netwerkconfiguratie." `
                -ForegroundColor Red

            Write-BESVGeneralLog `
                -Message `
                "Fout tijdens netwerkconfiguratie"
        }
    }
}

# ============================================================
# FUNCTION : Restart-BESVComputer
# ============================================================

function Restart-BESVComputer {

<#
.SYNOPSIS
Herstart computer.

.DESCRIPTION
Deze functie herstart de computer nadat
belangrijke configuraties uitgevoerd zijn.

.EXAMPLE
Restart-BESVComputer

.NOTES
Auteur : besv

Bestand :
algemeenbesv.psm1

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 149 : Fouten opvangen

Microsoft Learn:
https://learn.microsoft.com/en-us/powershell/

Restart-Computer:
https://learn.microsoft.com/en-us/powershell/module/
microsoft.powershell.management/restart-computer

#>

    Write-Host ""
    Write-Host `
        "Computer zal herstarten binnen 10 seconden..." `
        -ForegroundColor Yellow

    Start-Sleep -Seconds 10

    Restart-Computer -Force
}

# ============================================================
# FUNCTION : Set-ServerConfiguration
# ============================================================

function Set-ServerConfiguration {

<#
.SYNOPSIS
Voert serverconfiguratie uit.

.DESCRIPTION
Deze functie voert de volledige basisconfiguratie
uit voor Windows Server.

De configuratie bevat:
- hostname
- netwerkadapters
- IP configuratie

.EXAMPLE
Set-ServerConfiguration

.NOTES
Auteur : besv

Bestand :
algemeenbesv.psm1

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 138 : Scripts en modules
- Hfst. 144 : Scripts, modules en functies opbouwen
- Hfst. 151 : Try, catch en finally

Microsoft Learn:
https://learn.microsoft.com/en-us/powershell/

#>

    Write-Host ""
    Write-Host `
        "Start serverconfiguratie..." `
        -ForegroundColor Cyan

    Write-BESVGeneralLog `
        -Message "Serverconfiguratie gestart"

    Set-BESVHostname

    Set-BESVNetworkAdapters

    Set-BESVStaticIP

    Write-Host ""
    Write-Host `
        "Serverconfiguratie voltooid." `
        -ForegroundColor Green

    Write-BESVGeneralLog `
        -Message "Serverconfiguratie voltooid"
}

# ============================================================
# FUNCTION : Set-ClientConfiguration
# ============================================================

function Set-ClientConfiguration {

<#
.SYNOPSIS
Voert clientconfiguratie uit.

.DESCRIPTION
Deze functie voert de basisconfiguratie uit
voor een Windows client.

.EXAMPLE
Set-ClientConfiguration

.NOTES
Auteur : besv

Bestand :
algemeenbesv.psm1

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 138 : Scripts en modules
- Hfst. 144 : Scripts, modules en functies opbouwen

Microsoft Learn:
https://learn.microsoft.com/en-us/powershell/

#>

    Write-Host ""
    Write-Host `
        "Start clientconfiguratie..." `
        -ForegroundColor Cyan

    Write-BESVGeneralLog `
        -Message "Clientconfiguratie gestart"

    Set-BESVHostname

    Set-BESVNetworkAdapters

    Set-BESVStaticIP

    Write-Host ""
    Write-Host `
        "Clientconfiguratie voltooid." `
        -ForegroundColor Green

    Write-BESVGeneralLog `
        -Message "Clientconfiguratie voltooid"
}

# ============================================================
# EXPORT FUNCTIONS
# ============================================================

Export-ModuleMember -Function * -Alias *