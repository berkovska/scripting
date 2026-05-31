# Auteur: besv
# Bestand: domainsettingsbesv.psm1
# Doel: Active Directory domeinconfiguratie voor het scriptingproject.

# Sources per function with page numbers:
# - Get-BESVDomainSettings: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   XML files p. 105; functions/scripts p. 221-224.
# - ConvertTo-BESVDomainDN: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   string handling p. 127; Active Directory via PowerShell p. 193-196.
# - Get-BESVOrganizationalUnitPath: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   arrays p. 67-69; string handling p. 127; OU creation p. 193.
# - New-BESVOrganizationalUnitIfMissing: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   Active Directory via PowerShell - OU creation p. 193.
# - New-BESVDomainController: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   domain controller installation p. 179; second domain controller p. 186;
#   DNS on DC p. 191.
# - New-BESVOrganizationalUnits: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   CSV files p. 104; building Active Directory via CSV files p. 196.
# - New-BESVSecurityGroups: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   group creation p. 193; CSV files p. 104.
# - New-BESVDomainUsers: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   adding users p. 194; JSON files p. 107; secure password management p. 143.
# - Add-BESVUsersToGroups: F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022,
#   groups and users p. 193-194; JSON files p. 107.
# - Evan Pierce, "PowerShell for IT Professionals: Automating Windows Server and
#   Active Directory Management": background source for AD, users, groups,
#   Windows Server automation and administration automation; the EPUB has no fixed printed page numbers.

# Sources for function Get-BESVDomainSettings:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, XML files p. 105,
#   functions/scripts p. 221-224.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on configuration-driven domain automation.
function Get-BESVDomainSettings {
<#
.SYNOPSIS
Leest Domain.Settings.xml.

.DESCRIPTION
Laadt domeinnaam, NetBIOS-naam, fileservernaam, standaardwachtwoord,
homefolder- en profilefolderinstellingen uit settings\Domain.Settings.xml.

.EXAMPLE
$settings = Get-BESVDomainSettings

.NOTES
Auteur : besv
Bronnen:
- F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, hoofdstuk XML.
- Microsoft Learn, Everything about XML:
  https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-xml
#>
    [CmdletBinding()]
    param()

    $path = Join-Path $global:scriptRoot 'settings\Domain.Settings.xml'
    if (-not (Test-Path -LiteralPath $path)) { throw "Domain.Settings.xml niet gevonden: $path" }
    return [xml](Get-Content -LiteralPath $path -Raw)
}

# Sources for function ConvertTo-BESVDomainDN:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, string handling p. 127,
#   Active Directory via PowerShell p. 193-196.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on Active Directory naming and domain automation.
function ConvertTo-BESVDomainDN {
<#
.SYNOPSIS
Zet een DNS-domeinnaam om naar Distinguished Name.

.DESCRIPTION
Maakt van bijvoorbeeld BelgoCorpbesv.lab de waarde DC=BelgoCorpbesv,DC=lab.

.PARAMETER DomainName
DNS-naam van het domein.

.EXAMPLE
ConvertTo-BESVDomainDN -DomainName "BelgoCorpbesv.lab"

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Active Directory module:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DomainName)

    (($DomainName -split '\.') | ForEach-Object { "DC=$_" }) -join ','
}

# Sources for function Get-BESVOrganizationalUnitPath:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, arrays p. 67-69,
#   string handling p. 127, OU creation p. 193.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on Active Directory OU structure automation.
function Get-BESVOrganizationalUnitPath {
<#
.SYNOPSIS
Bouwt een OU Distinguished Name op basis van naam en bovenliggend pad.

.DESCRIPTION
De kolom Path in ous.csv bevat ouders van laag naar hoog, bijvoorbeeld
Management,Corporate. Deze functie draait de volgorde om en maakt een
correct OU-pad binnen het huidige domein.

.PARAMETER Name
Naam van de OU.

.PARAMETER ParentPath
Kommagescheiden ouderpad.

.EXAMPLE
Get-BESVOrganizationalUnitPath -Name "Executives" -ParentPath "Management,Corporate"

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, New-ADOrganizationalUnit:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adorganizationalunit
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$ParentPath
    )

    $dn = (Get-ADDomain).DistinguishedName
    if (-not [string]::IsNullOrWhiteSpace($ParentPath)) {
            [array]$parents = $ParentPath -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        [array]::Reverse($parents)
        foreach ($parent in $parents) {
            $dn = "OU=$parent,$dn"
        }
    }
    return "OU=$Name,$dn"
}

# Sources for function New-BESVOrganizationalUnitIfMissing:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, Active Directory via PowerShell,
#   OU creation p. 193.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on OU provisioning.
function New-BESVOrganizationalUnitIfMissing {
<#
.SYNOPSIS
Maakt een OU aan als die nog niet bestaat.

.DESCRIPTION
Controleert via Get-ADOrganizationalUnit of de opgegeven OU al bestaat.
Als de OU ontbreekt wordt ze aangemaakt met ProtectedFromAccidentalDeletion
op false, zodat testen in VMware eenvoudiger blijft.

.PARAMETER Name
Naam van de OU.

.PARAMETER Path
Distinguished Name van het bovenliggende object.

.EXAMPLE
New-BESVOrganizationalUnitIfMissing -Name "Corporate" -Path "DC=BelgoCorpbesv,DC=lab"

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Get-ADOrganizationalUnit:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adorganizationalunit
- Microsoft Learn, New-ADOrganizationalUnit:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adorganizationalunit
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path
    )

    $dn = "OU=$Name,$Path"
    if (Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$dn)" -ErrorAction SilentlyContinue) {
        Write-BESVLog "OU bestaat al: $dn" WARN
        return $dn
    }

    New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
    Write-BESVLog "OU aangemaakt: $dn" OK
    return $dn
}

# Sources for function New-BESVDomainController:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, domain controller installation p. 179,
#   second domain controller p. 186, DNS on DC p. 191.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on AD DS/domain controller automation.
function New-BESVDomainController {
<#
.SYNOPSIS
Installeert een nieuwe domeincontroller of voegt een extra DC toe.

.DESCRIPTION
Installeert de AD-Domain-Services Windows feature. Daarna wordt gecontroleerd
of het domein uit Domain.Settings.xml al bestaat. Als het niet bestaat, wordt
een nieuw forest aangemaakt. Als het wel bestaat, wordt deze server als extra
domeincontroller toegevoegd.

.EXAMPLE
New-BESVDomainController

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Install-WindowsFeature:
  https://learn.microsoft.com/en-us/powershell/module/servermanager/install-windowsfeature
- Microsoft Learn, Install-ADDSForest:
  https://learn.microsoft.com/en-us/powershell/module/addsdeployment/install-addsforest
- Microsoft Learn, Install-ADDSDomainController:
  https://learn.microsoft.com/en-us/powershell/module/addsdeployment/install-addsdomaincontroller
- PowerShell for IT Professionals, Evan Pierce, hoofdstuk Active Directory Domain Services.
#>
    [CmdletBinding()]
    param()

    $settings = Get-BESVDomainSettings
    $domainName = [string]$settings.Settings.Domain.domainname
    $netbios = [string]$settings.Settings.Domain.domainNetbiosName
    $installDns = [System.Convert]::ToBoolean([string]$settings.Settings.Domain.IsDnsIncluded)
    $safePassword = ConvertTo-SecureString ([string]$settings.Settings.UserSettings.defaultPassword) -AsPlainText -Force

    Import-Module ServerManager -ErrorAction Stop
    if (-not (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue)) {
        throw 'Install-WindowsFeature is not available. Run this on Windows Server with Windows PowerShell as Administrator.'
    }

    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop | Out-Null
    Write-BESVLog 'Windows feature AD-Domain-Services geinstalleerd of was al aanwezig.' OK

    Import-Module ADDSDeployment -ErrorAction Stop
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue

    $domainExists = $false
    try {
        Get-ADDomain -Identity $domainName -ErrorAction Stop | Out-Null
        $domainExists = $true
    } catch {
        $domainExists = $false
    }

    if ($domainExists) {
        $credential = Get-Credential -Message "Domeinadministrator voor $domainName"
        Write-BESVLog "Domein $domainName bestaat. Extra domain controller wordt toegevoegd." INFO
        Install-ADDSDomainController -DomainName $domainName -Credential $credential -SafeModeAdministratorPassword $safePassword -InstallDns:$installDns -Force
    } else {
        Write-BESVLog "Nieuw forest wordt aangemaakt: $domainName / $netbios" INFO
        Install-ADDSForest -DomainName $domainName -DomainNetbiosName $netbios -SafeModeAdministratorPassword $safePassword -InstallDns:$installDns -Force
    }
}

# Sources for function New-BESVOrganizationalUnits:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, CSV files p. 104,
#   building Active Directory via CSV files p. 196.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on bulk OU automation.
function New-BESVOrganizationalUnits {
<#
.SYNOPSIS
Maakt alle OUs uit ous.csv aan.

.DESCRIPTION
Leest settings\ous.csv en maakt bovenliggende OUs automatisch eerst aan.
Bestaande OUs worden gelogd en stoppen de uitvoering niet.

.EXAMPLE
New-BESVOrganizationalUnits

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Import-Csv:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv
- Microsoft Learn, New-ADOrganizationalUnit:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adorganizationalunit
#>
    [CmdletBinding()]
    param()

    Import-Module ActiveDirectory -ErrorAction Stop
    $domainDn = (Get-ADDomain).DistinguishedName
    $file = Join-Path $global:scriptRoot 'settings\ous.csv'

    if (-not (Test-Path -LiteralPath $file)) {
        $usersFile = Join-Path $global:scriptRoot 'settings\users.json'
        $groupsFile = Join-Path $global:scriptRoot 'settings\securitygroups.csv'

        $ouNames = @()
        if (Test-Path -LiteralPath $usersFile) {
            $userData = Get-Content -LiteralPath $usersFile -Raw | ConvertFrom-Json
            $ouNames += $userData.users | ForEach-Object { $_.ou }
        }
        if (Test-Path -LiteralPath $groupsFile) {
            $ouNames += Import-Csv -LiteralPath $groupsFile -Delimiter ';' | ForEach-Object { $_.ou }
        }

        $ouNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique | ForEach-Object {
            New-BESVOrganizationalUnitIfMissing -Name $_ -Path $domainDn | Out-Null
        }
        return
    }

    Import-Csv -LiteralPath $file -Delimiter ';' | ForEach-Object {
        $base = $domainDn
        if (-not [string]::IsNullOrWhiteSpace($_.Path)) {
            [array]$parents = $_.Path -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            [array]::Reverse($parents)
            foreach ($parent in $parents) {
                $base = New-BESVOrganizationalUnitIfMissing -Name $parent -Path $base
            }
        }
        New-BESVOrganizationalUnitIfMissing -Name $_.Name.Trim() -Path $base | Out-Null
    }
}

# Sources for function New-BESVSecurityGroups:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, group creation p. 193,
#   CSV files p. 104.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on AD security group automation.
function New-BESVSecurityGroups {
<#
.SYNOPSIS
Maakt security groups aan uit securitygroups.csv.

.DESCRIPTION
Groepen die beginnen met DL_ worden DomainLocal. Groepen die beginnen met
GL_ worden Global. Als rechten.csv groepen bevat die ontbreken in
securitygroups.csv, worden die als extra kwaliteitcontrole ook aangemaakt.

.EXAMPLE
New-BESVSecurityGroups

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, New-ADGroup:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adgroup
- Microsoft Learn, Get-ADGroup:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adgroup
- PowerShell for IT Professionals, Evan Pierce, hoofdstuk AD group automation.
#>
    [CmdletBinding()]
    param()

    Import-Module ActiveDirectory -ErrorAction Stop
    $groupsFile = Join-Path $global:scriptRoot 'settings\securitygroups.csv'
    $rows = @(Import-Csv -LiteralPath $groupsFile -Delimiter ';')

    foreach ($row in $rows) {
        $name = $row.GroepNaam.Trim()
        $scope = if ($name -like 'DL_*') { 'DomainLocal' } else { 'Global' }
        $ouName = $row.ou.Trim()
        $ouDn = New-BESVOrganizationalUnitIfMissing -Name $ouName -Path (Get-ADDomain).DistinguishedName

        $groupExists = Get-ADGroup -Filter "SamAccountName -eq '$name'" -ErrorAction SilentlyContinue
        if ($groupExists) {
            Write-BESVLog "Security group bestaat al: $name" WARN
            continue
        }

        New-ADGroup -Name $name -SamAccountName $name -GroupCategory Security -GroupScope $scope -Path $ouDn -ErrorAction Stop
        Write-BESVLog "Security group aangemaakt: $name ($scope) in $ouDn" OK
    }
}

# Sources for function New-BESVDomainUsers:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, adding users p. 194,
#   JSON files p. 107, secure password management p. 143.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on Active Directory user provisioning.
function New-BESVDomainUsers {
<#
.SYNOPSIS
Maakt Active Directory gebruikers aan.

.DESCRIPTION
Deze functie leest users.json en maakt alle geconfigureerde gebruikers aan in
Active Directory. De standaardwachtwoordwaarde, homefolder, profielenpad en
home drive worden uit Domain.Settings.xml gehaald.

.EXAMPLE
New-BESVDomainUsers

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, New-ADUser:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser
- Microsoft Learn, ConvertFrom-Json:
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json
- PowerShell for IT Professionals, Evan Pierce, hoofdstuk user provisioning.
#>
    [CmdletBinding()]
    param()

    Import-Module ActiveDirectory -ErrorAction Stop
    $settings = Get-BESVDomainSettings
    $usersPath = Join-Path $global:scriptRoot 'settings\users.json'
    $data = Get-Content -LiteralPath $usersPath -Raw | ConvertFrom-Json
    $password = ConvertTo-SecureString ([string]$settings.Settings.UserSettings.defaultPassword) -AsPlainText -Force
    $domain = [string]$settings.Settings.Domain.domainname
    $homeRoot = [string]$settings.Settings.UserSettings.homeFolder.location
    $profileRoot = [string]$settings.Settings.UserSettings.profileFolder.location
    $homeShare = [string]$settings.Settings.UserSettings.homeFolder.sharename
    $homeDrive = ([string]$settings.Settings.UserSettings.homeFolder.homeDrive).TrimEnd(':') + ':'

    $ouFile = Join-Path $global:scriptRoot 'settings\ous.csv'
    $ouRows = if (Test-Path -LiteralPath $ouFile) { @(Import-Csv -LiteralPath $ouFile -Delimiter ';') } else { @() }

    foreach ($user in $data.users) {
        $ouRow = $ouRows | Where-Object { $_.Name -eq $user.ou } | Select-Object -First 1
        $parentPath = if ($ouRow) { $ouRow.Path } else { '' }
        $ouDn = Get-BESVOrganizationalUnitPath -Name $user.ou -ParentPath $parentPath
        if (-not (Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$ouDn)" -ErrorAction SilentlyContinue)) {
            New-BESVOrganizationalUnits
        }

        $login = [string]$user.login
        $userExists = Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue
        if ($userExists) {
            Write-BESVLog "Gebruiker bestaat al: $($user.login)" WARN
            continue
        }

        $displayName = "$($user.firstName) $($user.lastName)"
        $upn = "$login@$domain"
        $homeDirectory = "\\$env:COMPUTERNAME\$homeShare\$login"
        $profilePath = Join-Path $profileRoot $login
        $localHome = Join-Path $homeRoot $login

        if (-not (Test-Path -LiteralPath $localHome)) { New-Item -ItemType Directory -Path $localHome -Force | Out-Null }
        if (-not (Test-Path -LiteralPath $profilePath)) { New-Item -ItemType Directory -Path $profilePath -Force | Out-Null }

        New-ADUser -Name $displayName -GivenName $user.firstName -Surname $user.lastName -SamAccountName $login -UserPrincipalName $upn -Path $ouDn -AccountPassword $password -Enabled $true -ChangePasswordAtLogon $true -HomeDrive $homeDrive -HomeDirectory $homeDirectory -ProfilePath $profilePath -ErrorAction Stop
        Write-BESVLog "Gebruiker aangemaakt: $displayName ($login) in $ouDn" OK
    }
}

# Sources for function Add-BESVUsersToGroups:
# - F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022, groups and users p. 193-194,
#   JSON files p. 107.
# - Evan Pierce, "PowerShell for IT Professionals", chapter/section on group membership automation.
function Add-BESVUsersToGroups {
<#
.SYNOPSIS
Voegt domeingebruikers toe aan security groups.

.DESCRIPTION
Leest de securityGroups array per gebruiker uit users.json. Ontbrekende
groepen of gebruikers worden gelogd maar stoppen de lus niet.

.EXAMPLE
Add-BESVUsersToGroups

.NOTES
Auteur : besv
Bronnen:
- Microsoft Learn, Add-ADGroupMember:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/add-adgroupmember
- Microsoft Learn, Get-ADUser:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser
- Microsoft Learn, Get-ADGroup:
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adgroup
#>
    [CmdletBinding()]
    param()

    Import-Module ActiveDirectory -ErrorAction Stop
    $usersPath = Join-Path $global:scriptRoot 'settings\users.json'
    $data = Get-Content -LiteralPath $usersPath -Raw | ConvertFrom-Json

    foreach ($user in $data.users) {
        $login = [string]$user.login
        $userExists = Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue
        if (-not $userExists) {
            Write-BESVLog "Gebruiker bestaat niet voor groepslidmaatschap: $($user.login)" ERROR
            continue
        }

        foreach ($group in $user.securityGroups) {
            $groupName = [string]$group
            $groupExists = Get-ADGroup -Filter "SamAccountName -eq '$groupName'" -ErrorAction SilentlyContinue
            if (-not $groupExists) {
                Write-BESVLog "Security group bestaat niet: $group voor gebruiker $($user.login)" ERROR
                continue
            }
            Add-ADGroupMember -Identity $group -Members $user.login -ErrorAction SilentlyContinue
            Write-BESVLog "Gebruiker $($user.login) toegevoegd aan groep $group." OK
        }
    }
}

Export-ModuleMember -Function Get-BESVDomainSettings, ConvertTo-BESVDomainDN, Get-BESVOrganizationalUnitPath, New-BESVOrganizationalUnitIfMissing, New-BESVDomainController, New-BESVOrganizationalUnits, New-BESVSecurityGroups, New-BESVDomainUsers, Add-BESVUsersToGroups

