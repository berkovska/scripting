# Voornaam en naam student: Svetlana Berkovska (BESV)
# Olod: Scripting - Projectwerk exam
# Projectwerkbegeleider: Nick Van Acker
# Academiejaar: 2025/2026
# AP Hogeschool
# Bestand: algemeenbesv.psm1
# Doel: algemene functies voor Windows Server 2025 en Windows 11 basisconfiguratie.
#
# Bronnen per functie met paginanummers:
# - Write-BESVLog: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   datumbewerkingen p. 131; output extern verwijzen/bestanden schrijven p. 42;
#   scripts en modules p. 221-224.
# - Test-BESVAdministrator: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   PowerShell automatisch starten als administrator p. 35 en p. 124.
# - Get-BESVComputerSettings: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   XML-bestanden p. 105; functies/scripts p. 221-224.
# - Set-BESVComputerName: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   cmdlets en parameters p. 18-21; credentials via object p. 34;
#   automatisch starten/RunOnce-context p. 35 en p. 124.
# - Set-BESVNetworkConfiguration: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   GUI-netwerk Windows Server en Windows Client p. 179;
#   WSCore snel configureren p. 189; DNS instellen op DC p. 191.
# - New-BESVFolders: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   eigenschappen van bestanden en mappen p. 136; ForEach-Object p. 110.
# - New-BESVShares: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   centrale informatiemap maken p. 148-149; scripts/modules p. 221-224.
# - Set-BESVShareAndNtfsRights: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   rechten van bestanden en mappen p. 137; rechten wijzigen p. 138.
# - Enable-BESVAutoLogon: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   credentials via object p. 34; automatisch starten als administrator p. 35 en p. 124.
# - Disable-BESVAutoLogon: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   automatisch starten/registry-context p. 35 en p. 124.
# - Register-BESVRunOnce: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   PowerShell automatisch starten als administrator II p. 124.
# - Register-BESVStartupTask: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   achtergrondtaken inplannen p. 64; PowerShell-script koppelen aan Taakplanner p. 293.
# - Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and
#   Active Directory Management": achtergrondbron voor Windows Server automatisatie,
#   logging, netwerkconfiguratie en beheerautomatisatie; EPUB heeft geen vaste papieren paginanummers.

# Bronnen functie Write-BESVLog:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, datumbewerkingen p. 131,
#   output naar bestanden p. 42, scripts/modules p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie logging en beheerautomatisatie.
function Write-BESVLog {
<#
.SYNOPSIS
Schrijft een bericht naar het centrale installatielogboek.

.DESCRIPTION
Voegt datum, tijd, niveau en bericht toe aan logs\InstallatieLogbesv.txt.
De functie maakt de logmap automatisch aan als die nog ontbreekt.

.PARAMETER Message
Het bericht dat gelogd moet worden.

.PARAMETER Level
INFO, OK, WARN of ERROR.

.EXAMPLE
Write-BESVLog -Message "Computernaam gecontroleerd" -Level OK

.NOTES
Auteur : besv
Bronnen:
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, hoofdstuk bestanden en functies.
- Microsoft Learn, Add-Content:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/add-content
- PowerShell for IT Professionals, Evan Pierce, hoofdstuk logging en beheerautomatisatie.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','OK','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $global:scriptRoot) { $global:scriptRoot = Split-Path $PSScriptRoot -Parent }
    if (-not $global:logBestand) { $global:logBestand = Join-Path $global:scriptRoot 'logs\InstallatieLogbesv.txt' }

    $logMap = Split-Path $global:logBestand -Parent
    if (-not (Test-Path -LiteralPath $logMap)) {
        New-Item -ItemType Directory -Path $logMap -Force | Out-Null
    }

    $line = '{0} - [{1}] {2}' -f (Get-Date -Format 'M-d-yyyy HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $global:logBestand -Value $line -Encoding UTF8

    $color = switch ($Level) {
        'OK' { 'Green' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
}

# Bronnen functie Test-BESVAdministrator:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, administratorcontext p. 35 en p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie privileged automation.
function Test-BESVAdministrator {
<#
.SYNOPSIS
Controleert of PowerShell als administrator draait.

.DESCRIPTION
Gebruikt WindowsPrincipal om te controleren of de huidige gebruiker lid is
van de lokale Administrators groep. Bij ontbreken van rechten wordt gestopt.

.PARAMETER Geen
Deze functie gebruikt geen parameters.

.EXAMPLE
Test-BESVAdministrator

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, WindowsPrincipal.IsInRole:
  https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsprincipal.isinrole
- PowerShell for IT Professionals, Evan Pierce, hoofdstuk privileged automation.
#>
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw 'Start PowerShell als administrator en voer Menubesv.ps1 opnieuw uit.'
    }
}

# Bronnen functie Get-BESVComputerSettings:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, XML-bestanden p. 105,
#   functies/scripts p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie configuration-driven automation.
function Get-BESVComputerSettings {
<#
.SYNOPSIS
Leest Computer.Settings.xml.

.DESCRIPTION
Laadt de XML met computernaam en netwerkadapters uit de map settings.
De structuur van het bestand blijft ongewijzigd zoals gevraagd in de opdracht.

.PARAMETER Geen
Deze functie gebruikt geen parameters.

.EXAMPLE
$settings = Get-BESVComputerSettings

.NOTES
Auteur : besv
Bronnen:
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, hoofdstuk XML.
- Microsoft Learn, Everything about XML:
  https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-xml
#>
    [CmdletBinding()]
    param()

    $path = Join-Path $global:scriptRoot 'settings\Computer.Settings.xml'
    if (-not (Test-Path -LiteralPath $path)) { throw "Computer.Settings.xml niet gevonden: $path" }
    return [xml](Get-Content -LiteralPath $path -Raw)
}

# Bronnen functie Set-BESVComputerName:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, cmdlets/parameters p. 18-21,
#   credentials p. 34, autostart/RunOnce-context p. 35 en p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie Windows Server configuration automation.
function Set-BESVComputerName {
<#
.SYNOPSIS
Stelt de computernaam in op basis van Computer.Settings.xml.

.DESCRIPTION
Leest Settings.name uit Computer.Settings.xml en toont deze als standaardwaarde.
De gebruiker kan de computernaam ingeven of ENTER drukken om de XML-waarde te
gebruiken. Als de naam anders is, wordt RunOnce ingesteld zodat het menu na de
volgende login opnieuw opent. Daarna wordt de computer hernoemd en automatisch
herstart.

.PARAMETER ConfigureAutoLogon
Vraagt aanmeldgegevens voor automatische aanmelding na de herstart. Dit volgt
de opdrachtregel dat het script na een verplichte herstart automatisch opnieuw
moet kunnen opstarten en verdergaan.

.EXAMPLE
Set-BESVComputerName -ConfigureAutoLogon

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Rename-Computer:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/rename-computer
- Microsoft Learn, Restart-Computer:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/restart-computer
- Microsoft Learn, RunOnce:
  https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys
#>
    [CmdletBinding()]
    param(
        [switch]$ConfigureAutoLogon
    )

    $settings = Get-BESVComputerSettings
    $xmlName = [string]$settings.Settings.name
    if ([string]::IsNullOrWhiteSpace($xmlName)) { throw 'Computernaam ontbreekt in Computer.Settings.xml.' }

    $inputName = Read-Host "Geef de nieuwe computernaam op, druk ENTER voor '$xmlName' of typ Q om te annuleren"
    if ($inputName -ieq 'Q') {
        throw [System.OperationCanceledException]::new('Computernaam wijzigen geannuleerd door gebruiker.')
    }
    $newName = if ([string]::IsNullOrWhiteSpace($inputName)) { $xmlName } else { $inputName.Trim() }

    if ($env:COMPUTERNAME -ieq $newName) {
        Write-BESVLog "Computernaam is al correct: $newName" OK
        return
    }

    if ($ConfigureAutoLogon) {
        Write-Host "De computernaam wordt gewijzigd. Daarna volgt een automatische herstart." -ForegroundColor Yellow
        Write-Host "Geef de gebruikersnaam en het wachtwoord voor automatische aanmelding na de herstart." -ForegroundColor Yellow
        Write-Host "Klik Annuleren om terug te keren naar het menu." -ForegroundColor Yellow
        $credential = Get-Credential -Message 'Geef de gebruiker op voor automatische aanmelding na de herstart.'
        if (-not $credential) {
            throw [System.OperationCanceledException]::new('Geen credentials ingegeven. Computernaam wijzigen geannuleerd om autostart-fouten te vermijden.')
        }
        Enable-BESVAutoLogon -Credential $credential
        Write-BESVLog "Tijdelijke automatische aanmelding ingesteld voor herstart na computernaamwijziging." OK
    }

    Register-BESVRunOnce -ScriptPath (Join-Path $global:scriptRoot 'Menubesv.ps1')
    Rename-Computer -NewName $newName -Force -ErrorAction Stop
    Write-BESVLog "Computernaam gewijzigd van $env:COMPUTERNAME naar $newName. Automatische herstart wordt uitgevoerd." OK
    Restart-Computer -Force
}

# Bronnen functie Set-BESVNetworkConfiguration:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, Windows Server/Client netwerk p. 179,
#   WSCore snel configureren p. 189, DNS op DC p. 191.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie Windows Server network automation.
function Set-BESVNetworkConfiguration {
<#
.SYNOPSIS
Configureert netwerkadapters op basis van Computer.Settings.xml.

.DESCRIPTION
Zoekt adapters op MAC-adres, hernoemt ze naar de naam uit XML en configureert
DHCP of statisch IPv4-adres, gateway en DNS. Met Target Server worden de eerste
twee netwerkadapterblokken uit Computer.Settings.xml verwerkt. Met Target Client
wordt alleen het derde netwerkadapterblok verwerkt. Zo blijft de originele
XML-structuur met lan, wan en lan behouden.

.PARAMETER Target
Bepaalt welke adapters uit Computer.Settings.xml worden verwerkt.
Server verwerkt adapterblok 1 en 2. Client verwerkt adapterblok 3. All verwerkt
alle adapters.

.EXAMPLE
Set-BESVNetworkConfiguration -Target Server

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Get-NetAdapter:
  https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapter
- Microsoft Learn, Rename-NetAdapter:
  https://learn.microsoft.com/en-us/powershell/module/netadapter/rename-netadapter
- Microsoft Learn, New-NetIPAddress:
  https://learn.microsoft.com/en-us/powershell/module/nettcpip/new-netipaddress
- Microsoft Learn, Set-DnsClientServerAddress:
  https://learn.microsoft.com/en-us/powershell/module/dnsclient/set-dnsclientserveraddress
- PowerShell for IT Professionals, Evan Pierce, hoofdstuk Windows Server netwerkautomatisatie.
#>
    [CmdletBinding()]
    param(
        [ValidateSet('All', 'Server', 'Client')]
        [string]$Target = 'All'
    )

    $settings = Get-BESVComputerSettings
    $adapterSettings = @($settings.Settings.networksettings.networkadapter)
    switch ($Target) {
        'Server' { $adapterSettings = @($adapterSettings | Select-Object -First 2) }
        'Client' { $adapterSettings = @($adapterSettings | Select-Object -Skip 2 -First 1) }
    }

    Write-BESVLog "Netwerkconfiguratie gestart voor doel: $Target." INFO

    foreach ($adapterSetting in $adapterSettings) {
        $mac = ([string]$adapterSetting.macaddress).ToUpper()
        $targetName = [string]$adapterSetting.name
        $adapter = Get-NetAdapter -IncludeHidden | Where-Object { $_.MacAddress.ToUpper() -eq $mac } | Select-Object -First 1

        if (-not $adapter) {
            Write-BESVLog "Netwerkadapter met MAC $mac niet gevonden." WARN
            continue
        }

        $interfaceIndex = $adapter.ifIndex
        $existingTarget = Get-NetAdapter -Name $targetName -IncludeHidden -ErrorAction SilentlyContinue

        if ($adapter.Name -ne $targetName -and -not $existingTarget) {
            try {
                Rename-NetAdapter -Name $adapter.Name -NewName $targetName -ErrorAction Stop
                Write-BESVLog "Adapter $($adapter.MacAddress) hernoemd naar $targetName." OK
            }
            catch {
                Write-BESVLog "Adapter $($adapter.MacAddress) kon niet hernoemd worden naar ${targetName}: $($_.Exception.Message). Configuratie gebeurt via interface-index $interfaceIndex." WARN
            }
        }
        elseif ($adapter.Name -ne $targetName -and $existingTarget) {
            Write-BESVLog "Adapter $($adapter.MacAddress) niet hernoemd naar $targetName omdat die naam al bestaat. Configuratie gebeurt via interface-index $interfaceIndex." WARN
        }

        $dhcp = ([string]$adapterSetting.dhcpenabled) -eq 'true'
        if ($dhcp) {
            Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Enabled -ErrorAction Stop
            Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
            Write-BESVLog "DHCP ingeschakeld voor adapter met interface-index $interfaceIndex." OK
            continue
        }

        Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -ne '127.0.0.1' } |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

        Get-NetRoute -InterfaceIndex $interfaceIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

        Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled -ErrorAction SilentlyContinue
        $desiredIp = [string]$adapterSetting.ip
        $existingDesiredIp = Get-NetIPAddress -AddressFamily IPv4 -IPAddress $desiredIp -ErrorAction SilentlyContinue
        if ($existingDesiredIp -and ($existingDesiredIp.InterfaceIndex -contains $interfaceIndex)) {
            Write-BESVLog "IP-adres $desiredIp staat al op interface-index $interfaceIndex. Nieuw IP-object wordt niet opnieuw aangemaakt." WARN
        }
        elseif ($existingDesiredIp) {
            $duplicateSummary = ($existingDesiredIp | ForEach-Object { "$($_.IPAddress) op ifIndex $($_.InterfaceIndex)" }) -join '; '
            Write-BESVLog "IP-adres $desiredIp bestaat al op een andere adapter: $duplicateSummary. Controleer MAC-adressen in Computer.Settings.xml." ERROR
            continue
        }
        else {
            New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress $desiredIp -PrefixLength ([int]$adapterSetting.prefixlength) -ErrorAction Stop | Out-Null
        }

        $gateway = ([string]$adapterSetting.gateway).Trim()
        if ([string]::IsNullOrWhiteSpace($gateway)) {
            Write-BESVLog "Geen default gateway ingesteld voor $targetName omdat gateway leeg is in Computer.Settings.xml." WARN
        }
        elseif ($gateway -eq [string]$adapterSetting.ip) {
            Write-BESVLog "Default gateway $gateway niet ingesteld voor $targetName omdat dit gelijk is aan het eigen IP-adres. XML blijft ongewijzigd." WARN
        }
        else {
            $existingDefaultRoutes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' }

            if ($existingDefaultRoutes) {
                $routeSummary = ($existingDefaultRoutes | ForEach-Object { "$($_.NextHop) via ifIndex $($_.InterfaceIndex)" }) -join '; '
                Write-BESVLog "Default gateway $gateway niet ingesteld voor $targetName omdat er al een default route bestaat: $routeSummary." WARN
            }
            else {
                New-NetRoute -InterfaceIndex $interfaceIndex -DestinationPrefix '0.0.0.0/0' -NextHop $gateway -RouteMetric 100 -ErrorAction Stop | Out-Null
                Write-BESVLog "Default gateway $gateway ingesteld voor $targetName." OK
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($adapterSetting.dns)) {
            Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses $adapterSetting.dns -ErrorAction Stop
        }
        Write-BESVLog "Statische netwerkconfig ingesteld voor interface-index ${interfaceIndex}: IP $($adapterSetting.ip)/$($adapterSetting.prefixlength), gateway $($adapterSetting.gateway), DNS $($adapterSetting.dns)." OK
    }
}

# Bronnen functie Enable-BESVAutoLogon:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, credentials p. 34,
#   PowerShell automatisch starten p. 35 en p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie unattended reboot automation.
function Enable-BESVAutoLogon {
<#
.SYNOPSIS
Configureert tijdelijke automatische aanmelding na een herstart.

.DESCRIPTION
Schrijft AutoAdminLogon, DefaultUserName, DefaultDomainName en
DefaultPassword naar de Winlogon registry-sleutel. Deze functie wordt enkel
gebruikt wanneer een herstart nodig is om automatisch verder te kunnen werken.

.PARAMETER Credential
De aanmeldgegevens die na de herstart gebruikt mogen worden.

.EXAMPLE
Enable-BESVAutoLogon -Credential (Get-Credential)

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Turn on automatic logon:
  https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon
- Microsoft Learn, Set-ItemProperty:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-itemproperty
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscredential]$Credential)

    $winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $userName = $Credential.UserName
    $password = $Credential.GetNetworkCredential().Password
    $domain = if ($userName -match '\\') { ($userName -split '\\')[0] } else { $env:COMPUTERNAME }
    $plainUser = if ($userName -match '\\') { ($userName -split '\\')[1] } else { $userName }

    Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '1'
    Set-ItemProperty -Path $winlogon -Name DefaultDomainName -Value $domain
    Set-ItemProperty -Path $winlogon -Name DefaultUserName -Value $plainUser
    Set-ItemProperty -Path $winlogon -Name DefaultPassword -Value $password
}

# Bronnen functie Disable-BESVAutoLogon:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, autostart/registry-context p. 35 en p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie cleanup after unattended automation.
function Disable-BESVAutoLogon {
<#
.SYNOPSIS
Schakelt tijdelijke automatische aanmelding opnieuw uit.

.DESCRIPTION
Zet AutoAdminLogon terug op nul en verwijdert de tijdelijk opgeslagen
aanmeldgegevens uit de Winlogon registry-sleutel.

.PARAMETER Geen
Deze functie gebruikt geen parameters.

.EXAMPLE
Disable-BESVAutoLogon

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Remove-ItemProperty:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-itemproperty
#>
    [CmdletBinding()]
    param()

    $winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '0'
    foreach ($name in 'DefaultPassword','DefaultUserName','DefaultDomainName') {
        Remove-ItemProperty -Path $winlogon -Name $name -ErrorAction SilentlyContinue
    }
}

# Bronnen functie Register-BESVRunOnce:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, automatisch starten als administrator II p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie reboot continuation automation.
function Register-BESVRunOnce {
<#
.SYNOPSIS
Registreert Menubesv.ps1 om na de volgende herstart automatisch te starten.

.DESCRIPTION
Schrijft een RunOnce waarde naar HKLM zodat het hoofdmenu na de volgende
aanmelding opnieuw wordt gestart.

.PARAMETER ScriptPath
Volledig pad naar Menubesv.ps1.

.EXAMPLE
Register-BESVRunOnce -ScriptPath "C:\scripting\Menubesv.ps1"

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Run and RunOnce registry keys:
  https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ScriptPath)

    $runOnce = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Set-ItemProperty -Path $runOnce -Name 'BESV-Scripting-Hervatten' -Value $command
}

# Bronnen functie Register-BESVStartupTask:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, achtergrondtaken inplannen p. 64,
#   PowerShell-script koppelen aan Taakplanner p. 293.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie scheduled automation.
function Register-BESVStartupTask {
<#
.SYNOPSIS
Maakt een geplande taak aan voor het starten van Menubesv.ps1.

.DESCRIPTION
Registreert een Scheduled Task die bij aanmelden het hoofdmenu kan starten.
De scheduled-task logica is geintegreerd in deze module en wordt vanuit het
hoofdmenu aangeroepen.

.PARAMETER ScriptPath
Volledig pad naar Menubesv.ps1.

.EXAMPLE
Register-BESVStartupTask -ScriptPath "C:\scripting\Menubesv.ps1"

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Register-ScheduledTask:
  https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/register-scheduledtask
- Microsoft Learn, New-ScheduledTaskAction:
  https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtaskaction
- Microsoft Learn, New-ScheduledTaskTrigger:
  https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasktrigger
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ScriptPath)

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
    Register-ScheduledTask -TaskName 'BESV-Scripting-Menu' -Action $action -Trigger $trigger -Principal $principal -Description 'Start BESV scripting project menu at logon.' -Force | Out-Null
}

# Bronnen functie New-BESVFolders:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, bestanden en mappen p. 136,
#   ForEach-Object p. 110.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie file-system automation.
function New-BESVFolders {
<#
.SYNOPSIS
Maakt de mappenstructuur uit mappen.txt aan.

.DESCRIPTION
Leest elk pad uit settings\mappen.txt en maakt ontbrekende mappen aan.
Bestaande mappen worden niet overschreven maar wel gelogd.

.PARAMETER Geen
Deze functie gebruikt geen parameters.

.EXAMPLE
New-BESVFolders

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, New-Item:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item
- Microsoft Learn, Test-Path:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-path
#>
    [CmdletBinding()]
    param()

    $path = Join-Path $global:scriptRoot 'settings\mappen.txt'
    Get-Content -LiteralPath $path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        $folder = $_.Trim()
        if (Test-Path -LiteralPath $folder) {
            Write-BESVLog "Map bestaat al: $folder" WARN
        } else {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Write-BESVLog "Map aangemaakt: $folder" OK
        }
    }
}

# Bronnen functie New-BESVShares:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, centrale informatiemap p. 148-149,
#   scripts/modules p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie SMB shares/file server automation.
function New-BESVShares {
<#
.SYNOPSIS
Maakt SMB-shares aan op basis van shares.csv.

.DESCRIPTION
Leest settings\shares.csv. Als de map nog niet bestaat, wordt ze eerst
aangemaakt. Bestaande shares worden gemeld en gelogd.

.PARAMETER Geen
Deze functie gebruikt geen parameters.

.EXAMPLE
New-BESVShares

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, New-SmbShare:
  https://learn.microsoft.com/en-us/powershell/module/smbshare/new-smbshare
- Microsoft Learn, Get-SmbShare:
  https://learn.microsoft.com/en-us/powershell/module/smbshare/get-smbshare
#>
    [CmdletBinding()]
    param()

    $path = Join-Path $global:scriptRoot 'settings\shares.csv'
    Import-Csv -LiteralPath $path -Delimiter ';' | ForEach-Object {
        if (-not (Test-Path -LiteralPath $_.map)) {
            New-Item -ItemType Directory -Path $_.map -Force | Out-Null
            Write-BESVLog "Map voor share aangemaakt: $($_.map)" OK
        }

        if (Get-SmbShare -Name $_.share -ErrorAction SilentlyContinue) {
            Write-BESVLog "Share bestaat al: $($_.share)" WARN
        } else {
            New-SmbShare -Name $_.share -Path $_.map -FullAccess 'Administrators' -ChangeAccess 'Authenticated Users' -ErrorAction Stop | Out-Null
            Write-BESVLog "Share aangemaakt: $($_.share) -> $($_.map)" OK
        }
    }
}

# Bronnen functie Set-BESVShareAndNtfsRights:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, rechten van bestanden en mappen p. 137,
#   rechten wijzigen p. 138.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie NTFS/share permissions automation.
function Set-BESVShareAndNtfsRights {
<#
.SYNOPSIS
Kent NTFS- en share-rechten toe volgens rechten.csv.

.DESCRIPTION
Controleert per regel of map, share en groep bestaan. Ontbrekende objecten
worden gelogd zonder het script te stoppen. NTFS-rechten worden toegepast via
FileSystemAccessRule en share-rechten via Grant-SmbShareAccess.

.PARAMETER Geen
Deze functie gebruikt geen parameters.

.EXAMPLE
Set-BESVShareAndNtfsRights

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Set-Acl:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-acl
- Microsoft Learn, Grant-SmbShareAccess:
  https://learn.microsoft.com/en-us/powershell/module/smbshare/grant-smbshareaccess
- Microsoft Learn, Get-ADGroup:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adgroup
#>
    [CmdletBinding()]
    param()

    Import-Module ActiveDirectory -ErrorAction Stop
    $path = Join-Path $global:scriptRoot 'settings\rechten.csv'

    foreach ($right in (Import-Csv -LiteralPath $path -Delimiter ';')) {
        $folder = $right.map
        $share = $right.share
        $group = $right.Groep

        $groupName = [string]$group
        $groupExists = Get-ADGroup -Filter "SamAccountName -eq '$groupName'" -ErrorAction SilentlyContinue
        if (-not $groupExists) {
            Write-BESVLog "Rechten overgeslagen: groep bestaat niet: $group" ERROR
            continue
        }
        if (-not (Test-Path -LiteralPath $folder)) {
            Write-BESVLog "Rechten overgeslagen: map bestaat niet: $folder" ERROR
            continue
        }
        if (-not (Get-SmbShare -Name $share -ErrorAction SilentlyContinue)) {
            Write-BESVLog "Share-recht overgeslagen: share bestaat niet: $share" ERROR
        } else {
            $shareRight = if ($right.share_permission -eq 'change') { 'Change' } else { 'Read' }
            Grant-SmbShareAccess -Name $share -AccountName $group -AccessRight $shareRight -Force -ErrorAction SilentlyContinue | Out-Null
            Write-BESVLog "Share-recht $shareRight toegekend aan $group op $share." OK
        }

        $ntfsRight = if ($right.NTFS_permission -eq 'modify') { 'Modify' } else { 'ReadAndExecute' }
        $acl = Get-Acl -LiteralPath $folder
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new($group, $ntfsRight, 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $folder -AclObject $acl
        Write-BESVLog "NTFS-recht $ntfsRight toegekend aan $group op $folder." OK
    }
}

# Bronnen functie Join-BESVDomain:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, client toevoegen aan domein via PowerShell p. 182,
#   credentials meegeven via object p. 34.
# - Evan Pierce, "PowerShell for IT Professionals", hoofdstuk/sectie domain join automation.
function Join-BESVDomain {
<#
.SYNOPSIS
Voegt de Windows 11 client toe aan het domein.

.DESCRIPTION
Leest de domeinnaam uit settings\Domain.Settings.xml en vraagt om een
domeinadministrator. Daarna wordt de client met Add-Computer aan het domein
toegevoegd. Met -Restart wordt de client automatisch herstart na een geslaagde
domeinjoin.

.PARAMETER Restart
Herstart de computer automatisch na het toevoegen aan het domein.

.EXAMPLE
Join-BESVDomain -Restart

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Add-Computer:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/add-computer
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, client toevoegen aan domein via PowerShell p. 182,
  credentials p. 34.
- Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and Active Directory Management",
  hoofdstuk/sectie domain join automation.
#>
    [CmdletBinding()]
    param([switch]$Restart)

    $domainSettingsPath = Join-Path $global:scriptRoot 'settings\Domain.Settings.xml'
    if (-not (Test-Path -LiteralPath $domainSettingsPath)) { throw "Domain.Settings.xml niet gevonden: $domainSettingsPath" }

    [xml]$domainSettings = Get-Content -LiteralPath $domainSettingsPath -Raw
    $domainName = [string]$domainSettings.Settings.Domain.domainname
    $netbiosName = [string]$domainSettings.Settings.Domain.domainNetbiosName
    if ([string]::IsNullOrWhiteSpace($domainName)) { throw 'Domeinnaam ontbreekt in Domain.Settings.xml.' }
    if ($domainName -match 'xxx' -or $netbiosName -match 'xxx') {
        throw "Domain.Settings.xml bevat nog 'xxx'. Pas dit aan naar BelgoCorpbesv.lab en BelgoCorpbesv voordat je de client aan het domein toevoegt."
    }

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    if ($computerSystem.PartOfDomain -and $computerSystem.Domain -ieq $domainName) {
        Write-BESVLog "Deze computer is al lid van domein $domainName." OK
        return
    }

    $credential = Get-Credential -Message "Geef domeinadministrator op, bijvoorbeeld $netbiosName\Administrator. Klik Annuleren om terug te keren naar het menu."
    if (-not $credential) {
        throw [System.OperationCanceledException]::new('Domain join geannuleerd door gebruiker.')
    }
    Write-BESVLog "Client wordt toegevoegd aan domein $domainName." INFO
    Add-Computer -DomainName $domainName -Credential $credential -ErrorAction Stop
    Write-BESVLog "Client toegevoegd aan domein $domainName. Herstart is nodig." OK

    if ($Restart) {
        Write-BESVLog 'Automatische herstart na domain join wordt uitgevoerd.' INFO
        Restart-Computer -Force
    }
}

Export-ModuleMember -Function Write-BESVLog, Test-BESVAdministrator, Get-BESVComputerSettings, Set-BESVComputerName, Set-BESVNetworkConfiguration, New-BESVFolders, New-BESVShares, Set-BESVShareAndNtfsRights, Enable-BESVAutoLogon, Disable-BESVAutoLogon, Register-BESVRunOnce, Register-BESVStartupTask, Join-BESVDomain
