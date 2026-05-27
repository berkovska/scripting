# ============================================================
# Auteur  : xxx
# Bestand : algemeenxxx.psm1
# Doel    : Basisconfiguratie van Windows apparaten:
#           logging, computernaam, netwerk, mappen, shares
#
# Bronnen :
#   F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022/2025
#     - Hoofdstuk 4  : Functies en modules
#     - Hoofdstuk 6  : Werken met bestanden en mappen
#     - Hoofdstuk 9  : Registry en systeembeheer
#   https://learn.microsoft.com/en-us/powershell/module/
#     microsoft.powershell.management/rename-computer
#   https://learn.microsoft.com/en-us/powershell/module/
#     nettcpip/new-netipaddress
#   https://learn.microsoft.com/en-us/powershell/module/
#     smbshare/new-smbshare
# ============================================================


# ─────────────────────────────────────────────────────────────────────
function Schrijf-Log {
<#
.SYNOPSIS
    Schrijft een bericht met tijdstempel naar het logbestand.
.DESCRIPTION
    Elke loginstelling begint met datum en uur in het formaat
    "dd-MM-yyyy HH:mm:ss". Het bericht wordt ook op het scherm
    getoond. Map en bestand worden aangemaakt als ze niet bestaan.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 6
.PARAMETER Bericht
    De tekst die gelogd moet worden.
.EXAMPLE
    Schrijf-Log "Computernaam gewijzigd naar dc01xxx"
    # Uitvoer: 22-04-2026 14:05:01 - Computernaam gewijzigd naar dc01xxx
#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Bericht
    )

    $tijdstempel = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $logRegel    = "$tijdstempel - $Bericht"

    # Logmap aanmaken als die nog niet bestaat
    # Bron: F. Vanhoo, 2022, p. 133 – New-Item
    $logMap = Split-Path $global:logBestand -Parent
    if (-not (Test-Path $logMap)) {
        New-Item -ItemType Directory -Path $logMap -Force | Out-Null
    }

    Add-Content -Path $global:logBestand -Value $logRegel -Encoding UTF8
    Write-Host $logRegel
}


# ─────────────────────────────────────────────────────────────────────
function Haal-ComputerInstellingenOp {
<#
.SYNOPSIS
    Laadt Computer.Settings.xml en geeft het XML-object terug.
.DESCRIPTION
    Zoekt het bestand in de map \scripting\settings\.
    Geeft een foutmelding als het bestand niet gevonden wordt.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 7
.EXAMPLE
    $xml = Haal-ComputerInstellingenOp
    $xml.Settings.name
#>
    $pad = "$global:scriptRoot\settings\Computer.Settings.xml"

    if (-not (Test-Path $pad)) {
        Schrijf-Log "FOUT: Computer.Settings.xml niet gevonden op $pad"
        throw "Bestand niet gevonden: $pad"
    }

    return [xml](Get-Content $pad -Encoding UTF8)
}


# ─────────────────────────────────────────────────────────────────────
function Stel-ComputernaamIn {
<#
.SYNOPSIS
    Stelt de computernaam in en zorgt voor automatische herstart
    met hervatting van het script nadien.
.DESCRIPTION
    Vraagt de gebruiker om een nieuwe computernaam en autologon-
    credentials. Slaat de autologon op via de Winlogon registry-
    sleutel zodat Windows na herstart automatisch aanmeldt.
    Configureert RunOnce zodat het script na herstart hervat wordt.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 9
    Registry-sleutels:
      HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
      HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
    https://learn.microsoft.com/en-us/powershell/module/
      microsoft.powershell.management/rename-computer
.PARAMETER ComputerType
    "Server" of "Client" – enkel voor de logmelding.
.EXAMPLE
    Stel-ComputernaamIn -ComputerType "Server"
.EXAMPLE
    Stel-ComputernaamIn -ComputerType "Client"
#>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Server","Client")]
        [string]$ComputerType
    )

    $nieuweNaam = Read-Host "Geef de nieuwe computernaam op"

    if ([string]::IsNullOrWhiteSpace($nieuweNaam)) {
        Write-Host "Geen naam opgegeven. Actie geannuleerd." -ForegroundColor Red
        Read-Host "Druk op ENTER om verder te gaan"
        return
    }

    # Credentials opvragen voor automatisch aanmelden na herstart
    # Bron: https://learn.microsoft.com/en-us/powershell/module/
    #         microsoft.powershell.security/get-credential
    $aanmeldgegevens = Get-Credential -Message "Account voor automatisch aanmelden na herstart"

    # Autologon instellen via Winlogon
    # Bron: https://learn.microsoft.com/en-us/troubleshoot/windows-server/
    #         user-profiles-and-logon/turn-on-automatic-logon
    $winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $winlogon -Name "AutoAdminLogon"    -Value "1"
    Set-ItemProperty -Path $winlogon -Name "DefaultUsername"   -Value $aanmeldgegevens.UserName
    Set-ItemProperty -Path $winlogon -Name "DefaultPassword"   -Value ($aanmeldgegevens.GetNetworkCredential().Password)
    Set-ItemProperty -Path $winlogon -Name "DefaultDomainName" -Value $env:COMPUTERNAME

    # Script hervatten na herstart via RunOnce
    # Bron: https://learn.microsoft.com/en-us/windows/win32/setupapi/
    #         run-and-runonce-registry-keys
    $runOnce = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Set-ItemProperty -Path $runOnce -Name "HervatScript" `
        -Value "powershell.exe -ExecutionPolicy Bypass -File `"$global:scriptRoot\Menuxxx.ps1`""

    Schrijf-Log "#### Start computernaam instellen ($ComputerType)... ####"

    try {
        Rename-Computer -NewName $nieuweNaam -Force
        Schrijf-Log "Computernaam gewijzigd naar: $nieuweNaam"
        Write-Host "Systeem wordt herstart in 3 seconden..." -ForegroundColor Yellow
        Start-Sleep 3
        Restart-Computer -Force
    }
    catch {
        Schrijf-Log "FOUT bij hernoemen: $_"
        Write-Host "FOUT: $_" -ForegroundColor Red
        Read-Host "Druk op ENTER om verder te gaan"
    }
}


# ─────────────────────────────────────────────────────────────────────
function Stel-NetwerkconfigIn {
<#
.SYNOPSIS
    Stelt de IP-configuratie in op basis van Computer.Settings.xml.
.DESCRIPTION
    Leest alle netwerkadapters uit het XML-bestand. Per adapter
    wordt op basis van het MAC-adres de bijhorende netwerkkaart
    opgezocht. DHCP wordt in- of uitgeschakeld op basis van
    dhcpenabled. Bij statisch IP worden IP-adres, subnetmasker,
    gateway en DNS ingesteld. Alle wijzigingen worden gelogd.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 7
    https://learn.microsoft.com/en-us/powershell/module/
      nettcpip/new-netipaddress
    https://learn.microsoft.com/en-us/powershell/module/
      dnsclient/set-dnsclientserveraddress
.EXAMPLE
    Stel-NetwerkconfigIn
#>
    Schrijf-Log "#### Start IP-configuratie via XML... ####"

    try {
        $xml = Haal-ComputerInstellingenOp

        foreach ($adapter in $xml.Settings.networksettings.networkadapter) {

            # Adapter opzoeken via MAC-adres
            # Bron: https://learn.microsoft.com/en-us/powershell/module/
            #         netadapter/get-netadapter
            $netwerkkaart = Get-NetAdapter | Where-Object { $_.MacAddress -eq $adapter.macaddress }

            if (-not $netwerkkaart) {
                Schrijf-Log "WAARSCHUWING: Geen adapter gevonden met MAC $($adapter.macaddress)"
                Write-Host "WAARSCHUWING: Adapter met MAC $($adapter.macaddress) niet gevonden." -ForegroundColor Yellow
                continue
            }

            if ($adapter.dhcpenabled -eq "true") {
                # DHCP inschakelen
                Set-NetIPInterface -InterfaceAlias $netwerkkaart.Name -Dhcp Enabled
                Set-DnsClientServerAddress -InterfaceAlias $netwerkkaart.Name -ResetServerAddresses
                Schrijf-Log "Adapter '$($netwerkkaart.Name)' ingesteld op DHCP."
            }
            else {
                # Bestaande IP-configuratie verwijderen
                Get-NetIPAddress -InterfaceAlias $netwerkkaart.Name -ErrorAction SilentlyContinue |
                    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
                Get-NetRoute -InterfaceAlias $netwerkkaart.Name -ErrorAction SilentlyContinue |
                    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

                # Statisch IP-adres instellen
                New-NetIPAddress `
                    -InterfaceAlias $netwerkkaart.Name `
                    -IPAddress      $adapter.ip `
                    -PrefixLength   ([int]$adapter.prefixlength) `
                    -DefaultGateway $adapter.gateway | Out-Null

                # DNS instellen
                Set-DnsClientServerAddress `
                    -InterfaceAlias  $netwerkkaart.Name `
                    -ServerAddresses ($adapter.dns -split ',')

                Schrijf-Log "Adapter '$($netwerkkaart.Name)': IP=$($adapter.ip), GW=$($adapter.gateway), DNS=$($adapter.dns)"
                Write-Host "#### Finished setting ip config... ####" -ForegroundColor Green
            }
        }
    }
    catch {
        Schrijf-Log "FOUT bij IP-configuratie: $_"
        Write-Host "FOUT: $_" -ForegroundColor Red
    }

    Schrijf-Log "#### Finished IP-configuratie... ####"
    Read-Host "Druk op ENTER om verder te gaan"
}


# ─────────────────────────────────────────────────────────────────────
function Maak-MappensctructuurAan {
<#
.SYNOPSIS
    Maakt een mappenstructuur aan op basis van mappen.txt.
.DESCRIPTION
    Elke niet-lege regel in mappen.txt is een volledig mappad.
    Bestaande mappen worden gemeld maar niet overschreven.
    Ontbrekende bovenliggende mappen worden automatisch aangemaakt
    via de -Force parameter van New-Item.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 6
    https://learn.microsoft.com/en-us/powershell/module/
      microsoft.powershell.management/new-item
.EXAMPLE
    Maak-MappensctructuurAan
#>
    Schrijf-Log "#### Creating folders... ####"

    $bestand = "$global:scriptRoot\settings\mappen.txt"

    if (-not (Test-Path $bestand)) {
        Schrijf-Log "FOUT: mappen.txt niet gevonden op $bestand"
        Read-Host "Druk op ENTER om verder te gaan"
        return
    }

    $regels = Get-Content $bestand -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*$' }

    foreach ($pad in $regels) {
        $pad = $pad.Trim()

        if (Test-Path $pad) {
            Write-Host "Map bestaat al: $pad" -ForegroundColor Yellow
            Schrijf-Log "Map bestaat reeds: $pad"
        }
        else {
            try {
                New-Item -ItemType Directory -Path $pad -Force | Out-Null
                Schrijf-Log "Map aangemaakt: $pad"
                Write-Host "Map aangemaakt: $pad" -ForegroundColor Green
            }
            catch {
                Schrijf-Log "FOUT bij aanmaken map $pad : $_"
                Write-Host "FOUT: $_" -ForegroundColor Red
            }
        }
    }

    Schrijf-Log "#### Finished creating folders... ####"
    Read-Host "Druk op ENTER om verder te gaan"
}


# ─────────────────────────────────────────────────────────────────────
function Maak-SharesAan {
<#
.SYNOPSIS
    Maakt netwerkshares aan op basis van shares.csv.
.DESCRIPTION
    Kolommen in shares.csv: map;share
    Als de opgegeven map niet bestaat, wordt ze eerst aangemaakt.
    Als de share al bestaat, wordt een melding getoond maar stopt
    het script niet.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 8
    https://learn.microsoft.com/en-us/powershell/module/
      smbshare/new-smbshare
.EXAMPLE
    Maak-SharesAan
#>
    Schrijf-Log "#### Creating shares... ####"

    $bestand = "$global:scriptRoot\settings\shares.csv"

    if (-not (Test-Path $bestand)) {
        Schrijf-Log "FOUT: shares.csv niet gevonden op $bestand"
        Read-Host "Druk op ENTER om verder te gaan"
        return
    }

    $rijen = Import-Csv $bestand -Delimiter ";" -Encoding UTF8

    foreach ($rij in $rijen) {
        $pad       = $rij.map.Trim()
        $shareNaam = $rij.share.Trim()

        # Map aanmaken als die niet bestaat
        if (-not (Test-Path $pad)) {
            New-Item -ItemType Directory -Path $pad -Force | Out-Null
            Schrijf-Log "Map aangemaakt voor share '$shareNaam': $pad"
        }

        if (Get-SmbShare -Name $shareNaam -ErrorAction SilentlyContinue) {
            Write-Host "Share bestaat al: $shareNaam" -ForegroundColor Yellow
            Schrijf-Log "Share bestaat reeds: $shareNaam"
        }
        else {
            try {
                New-SmbShare -Name $shareNaam -Path $pad -FullAccess "Everyone" | Out-Null
                Schrijf-Log "Share aangemaakt: $shareNaam -> $pad"
                Write-Host "Share aangemaakt: $shareNaam" -ForegroundColor Green
            }
            catch {
                Schrijf-Log "FOUT bij aanmaken share '$shareNaam': $_"
                Write-Host "FOUT: $_" -ForegroundColor Red
            }
        }
    }

    Schrijf-Log "#### Finished creating shares... ####"
    Read-Host "Druk op ENTER om verder te gaan"
}
