# Auteur: besv
# Bestand: algemeenbesv.psm1
# Doel: algemene functies voor Windows Server 2025 en Windows 11 basisconfiguratie.

# Sources per function with page numbers:
# - Write-BESVLog: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   date handling p. 131; external output/file writing p. 42;
#   scripts and modules p. 221-224.
# - Test-BESVAdministrator: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   automatically starting PowerShell as administrator p. 35 and p. 124.
# - Get-BESVComputerSettings: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   XML files p. 105; functions/scripts p. 221-224.
# - Set-BESVComputerName: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   cmdlets and parameters p. 18-21; credentials via object p. 34;
#   automatic startup/RunOnce context p. 35 and p. 124.
# - Set-BESVNetworkConfiguration: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   GUI network Windows Server and Windows Client p. 179;
#   quick WSCore configuration p. 189; DNS on DC p. 191.
# - New-BESVFolders: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   file and folder properties p. 136; ForEach-Object p. 110.
# - New-BESVShares: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   central information folder p. 148-149; scripts/modules p. 221-224.
# - Set-BESVShareAndNtfsRights: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   file and folder rights p. 137; changing rights p. 138.
# - Enable-BESVAutoLogon: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   credentials via object p. 34; automatic administrator startup p. 35 and p. 124.
# - Disable-BESVAutoLogon: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   automatic startup/registry context p. 35 and p. 124.
# - Register-BESVRunOnce: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   automatically starting PowerShell as administrator II p. 124.
# - Register-BESVStartupTask: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   scheduling background tasks p. 64; linking a PowerShell script to Task Scheduler p. 293.
# - Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and
#   Active Directory Management": background source for Windows Server automation,
#   logging, network configuration and administration automation; the EPUB has no fixed printed page numbers.

# Sources for function Write-BESVLog:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, date handling p. 131,
#   file output p. 42, scripts/modules p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on logging and administration automation.
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

# Sources for function Test-BESVAdministrator:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, administrator context p. 35 and p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on privileged automation.
function Test-BESVAdministrator {
<#
.SYNOPSIS
Controleert of PowerShell als administrator draait.

.DESCRIPTION
Gebruikt WindowsPrincipal om te controleren of de huidige gebruiker lid is
van de lokale Administrators groep. Bij ontbreken van rechten wordt gestopt.

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

# Sources for function Get-BESVComputerSettings:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, XML files p. 105,
#   functions/scripts p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on configuration-driven automation.
function Get-BESVComputerSettings {
<#
.SYNOPSIS
Leest Computer.Settings.xml.

.DESCRIPTION
Laadt de XML met computernaam en netwerkadapters uit de map settings.
De structuur van het bestand blijft ongewijzigd zoals gevraagd in de opdracht.

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

# Sources for function Set-BESVComputerName:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, cmdlets/parameters p. 18-21,
#   credentials p. 34, autostart/RunOnce context p. 35 and p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on Windows Server configuration automation.
function Set-BESVComputerName {
<#
.SYNOPSIS
Stelt de computernaam in op basis van Computer.Settings.xml.

.DESCRIPTION
Reads Settings.name from Computer.Settings.xml and shows it as the default value.
The user can enter a computer name or press ENTER to use the XML value. If the
name is different, RunOnce is configured so the menu opens again after the next
logon. The computer is then renamed and restarted automatically.

.PARAMETER ConfigureAutoLogon
Kept for menu compatibility, but it no longer asks for credentials. Continuation
is handled through RunOnce after the next logon.

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

    $inputName = Read-Host "Enter the new computer name or press ENTER for '$xmlName'"
    $newName = if ([string]::IsNullOrWhiteSpace($inputName)) { $xmlName } else { $inputName.Trim() }

    if ($env:COMPUTERNAME -ieq $newName) {
        Write-BESVLog "Computernaam is al correct: $newName" OK
        return
    }

    Register-BESVRunOnce -ScriptPath (Join-Path $global:scriptRoot 'Menubesv.ps1')
    Rename-Computer -NewName $newName -Force -ErrorAction Stop
    Write-BESVLog "Computer name changed from $env:COMPUTERNAME to $newName. Automatic restart will be performed." OK
    Restart-Computer -Force
}

# Sources for function Set-BESVNetworkConfiguration:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, Windows Server/Client network p. 179,
#   quick WSCore configuration p. 189, DNS on DC p. 191.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on Windows Server network automation.
function Set-BESVNetworkConfiguration {
<#
.SYNOPSIS
Configureert netwerkadapters op basis van Computer.Settings.xml.

.DESCRIPTION
Zoekt adapters op MAC-adres, hernoemt ze naar de naam uit XML en configureert
DHCP of statisch IPv4-adres, gateway en DNS. Bestaande IPv4-adressen en routes
worden gecontroleerd en verwijderd waar nodig.

.EXAMPLE
Set-BESVNetworkConfiguration

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
    param()

    $settings = Get-BESVComputerSettings
    foreach ($adapterSetting in $settings.Settings.networksettings.networkadapter) {
        $mac = ([string]$adapterSetting.macaddress).ToUpper()
        $targetName = [string]$adapterSetting.name
        $adapter = Get-NetAdapter | Where-Object { $_.MacAddress.ToUpper() -eq $mac } | Select-Object -First 1

        if (-not $adapter) {
            Write-BESVLog "Netwerkadapter met MAC $mac niet gevonden." WARN
            continue
        }

        $interfaceIndex = $adapter.ifIndex
        $existingTarget = Get-NetAdapter -Name $targetName -ErrorAction SilentlyContinue

        if ($adapter.Name -ne $targetName -and -not $existingTarget) {
            Rename-NetAdapter -Name $adapter.Name -NewName $targetName -ErrorAction Stop
            Write-BESVLog "Adapter $($adapter.MacAddress) hernoemd naar $targetName." OK
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

        New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress $adapterSetting.ip -PrefixLength ([int]$adapterSetting.prefixlength) -DefaultGateway $adapterSetting.gateway -ErrorAction Stop | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($adapterSetting.dns)) {
            Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses $adapterSetting.dns -ErrorAction Stop
        }
        Write-BESVLog "Statische netwerkconfig ingesteld voor interface-index ${interfaceIndex}: IP $($adapterSetting.ip)/$($adapterSetting.prefixlength), gateway $($adapterSetting.gateway), DNS $($adapterSetting.dns)." OK
    }
}

# Sources for function Enable-BESVAutoLogon:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, credentials p. 34,
#   automatic PowerShell startup p. 35 and p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on unattended reboot automation.
function Enable-BESVAutoLogon {
<#
.SYNOPSIS
Configures temporary automatic logon after a reboot.

.DESCRIPTION
Writes AutoAdminLogon, DefaultUserName, DefaultDomainName and DefaultPassword
to the Winlogon registry key. This function replaces a separate AutoStart
script and is called from Menubesv.ps1.

.PARAMETER Credential
The credential used after reboot.

.EXAMPLE
Enable-BESVAutoLogon -Credential (Get-Credential)

.NOTES
Author : besv
Sources:
- Microsoft Learn, Turn on automatic logon:
  https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon
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

# Sources for function Disable-BESVAutoLogon:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, autostart/registry context p. 35 and p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on cleanup after unattended automation.
function Disable-BESVAutoLogon {
<#
.SYNOPSIS
Disables temporary automatic logon.

.DESCRIPTION
Sets AutoAdminLogon to zero and removes the temporary logon values from the
Winlogon registry key.

.EXAMPLE
Disable-BESVAutoLogon

.NOTES
Author : besv
Sources:
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

# Sources for function Register-BESVRunOnce:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, automatically starting as administrator II p. 124.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on reboot continuation automation.
function Register-BESVRunOnce {
<#
.SYNOPSIS
Registers Menubesv.ps1 to start once after the next reboot.

.DESCRIPTION
Writes a RunOnce value to HKLM so the main menu opens again after the next
logon.

.PARAMETER ScriptPath
Full path to Menubesv.ps1.

.EXAMPLE
Register-BESVRunOnce -ScriptPath "C:\scripting\Menubesv.ps1"

.NOTES
Author : besv
Sources:
- Microsoft Learn, Run and RunOnce registry keys:
  https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ScriptPath)

    $runOnce = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Set-ItemProperty -Path $runOnce -Name 'BESV-Scripting-Hervatten' -Value $command
}

# Sources for function Register-BESVStartupTask:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, scheduling background tasks p. 64,
#   linking a PowerShell script to Task Scheduler p. 293.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on scheduled automation.
function Register-BESVStartupTask {
<#
.SYNOPSIS
Creates a scheduled task to start Menubesv.ps1.

.DESCRIPTION
Registers a scheduled task that can start the main menu at logon. This replaces
a separate RegisterTask.ps1 file and is called from Menubesv.ps1.

.PARAMETER ScriptPath
Full path to Menubesv.ps1.

.EXAMPLE
Register-BESVStartupTask -ScriptPath "C:\scripting\Menubesv.ps1"

.NOTES
Author : besv
Sources:
- Microsoft Learn, Register-ScheduledTask:
  https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/register-scheduledtask
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ScriptPath)

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
    Register-ScheduledTask -TaskName 'BESV-Scripting-Menu' -Action $action -Trigger $trigger -Principal $principal -Description 'Start BESV scripting project menu at logon.' -Force | Out-Null
}

# Sources for function New-BESVFolders:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, files and folders p. 136,
#   ForEach-Object p. 110.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on file-system automation.
function New-BESVFolders {
<#
.SYNOPSIS
Maakt de mappenstructuur uit mappen.txt aan.

.DESCRIPTION
Leest elk pad uit settings\mappen.txt en maakt ontbrekende mappen aan.
Bestaande mappen worden niet overschreven maar wel gelogd.

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

# Sources for function New-BESVShares:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, central information folder p. 148-149,
#   scripts/modules p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on SMB shares/file server automation.
function New-BESVShares {
<#
.SYNOPSIS
Maakt SMB-shares aan op basis van shares.csv.

.DESCRIPTION
Leest settings\shares.csv. Als de map nog niet bestaat, wordt ze eerst
aangemaakt. Bestaande shares worden gemeld en gelogd.

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

# Sources for function Set-BESVShareAndNtfsRights:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, file/folder rights p. 137,
#   changing rights p. 138.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on NTFS/share permissions automation.
function Set-BESVShareAndNtfsRights {
<#
.SYNOPSIS
Kent NTFS- en share-rechten toe volgens rechten.csv.

.DESCRIPTION
Controleert per regel of map, share en groep bestaan. Ontbrekende objecten
worden gelogd zonder het script te stoppen. NTFS-rechten worden toegepast via
FileSystemAccessRule en share-rechten via Grant-SmbShareAccess.

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

# Sources for function Join-BESVDomain:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, adding a client to the domain p. 182,
#   credentials p. 34.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on domain join automation.
function Join-BESVDomain {
<#
.SYNOPSIS
Joins the Windows 11 client to the domain.

.DESCRIPTION
Reads the domain name from settings\Domain.Settings.xml and asks for a domain
administrator credential. The client is then joined to the domain with
Add-Computer. With -Restart, the client restarts automatically after a
successful domain join.

.PARAMETER Restart
Restarts the computer automatically after joining the domain.

.EXAMPLE
Join-BESVDomain -Restart

.NOTES
Author : besv
Sources:
- Microsoft Learn, Add-Computer:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/add-computer
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, adding a client to the domain p. 182,
  credentials p. 34.
- Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and Active Directory Management",
  chapter/section on domain join automation.
#>
    [CmdletBinding()]
    param([switch]$Restart)

    $domainSettingsPath = Join-Path $global:scriptRoot 'settings\Domain.Settings.xml'
    if (-not (Test-Path -LiteralPath $domainSettingsPath)) { throw "Domain.Settings.xml not found: $domainSettingsPath" }

    [xml]$domainSettings = Get-Content -LiteralPath $domainSettingsPath -Raw
    $domainName = [string]$domainSettings.Settings.Domain.domainname
    $netbiosName = [string]$domainSettings.Settings.Domain.domainNetbiosName
    if ([string]::IsNullOrWhiteSpace($domainName)) { throw 'Domain name is missing in Domain.Settings.xml.' }

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    if ($computerSystem.PartOfDomain -and $computerSystem.Domain -ieq $domainName) {
        Write-BESVLog "This computer is already joined to domain $domainName." OK
        return
    }

    $credential = Get-Credential -Message "Enter domain administrator, for example $netbiosName\Administrator"
    Write-BESVLog "Client is joining domain $domainName." INFO
    Add-Computer -DomainName $domainName -Credential $credential -ErrorAction Stop
    Write-BESVLog "Client joined domain $domainName. Restart is required." OK

    if ($Restart) {
        Write-BESVLog 'Automatic restart after domain join is starting.' INFO
        Restart-Computer -Force
    }
}

Export-ModuleMember -Function Write-BESVLog, Test-BESVAdministrator, Get-BESVComputerSettings, Set-BESVComputerName, Set-BESVNetworkConfiguration, New-BESVFolders, New-BESVShares, Set-BESVShareAndNtfsRights, Enable-BESVAutoLogon, Disable-BESVAutoLogon, Register-BESVRunOnce, Register-BESVStartupTask, Join-BESVDomain
