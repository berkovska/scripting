# ============================================================
# Auteur  : besv
# Bestand : domainsettingsbesv.psm1
# Doel    : Domeinconfiguratie:
#           - installatie domain controller
#           - aanmaken OU's
#           - security groups
#           - domain users
#           - groepslidmaatschappen
#           - folders
#           - SMB shares
#           - NTFS rechten
#
# Beschrijving :
# Deze module bevat alle functies voor de
# Active Directory en fileserver configuratie.
#
# Bronnen :
#
# Boek:
#   F. Vanhoo,
#   "PowerShell Vlot gebruiken",
#   Die Keure, tweede editie, 2022/2025
#
#   Gebruikte hoofdstukken:
#   - Hfst. 41  : Modules
#   - Hfst. 71  : Methoden, functies en cmdlets
#   - Hfst. 79  : CSV-bestanden
#   - Hfst. 80  : XML-bestanden
#   - Hfst. 81  : JSON-bestanden
#   - Hfst. 83  : Where-Object
#   - Hfst. 129 : Active Directory
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

$DomainSettingsFile = `
    "$ScriptRoot\settings\Domain.Settings.xml"

$UsersFile = `
    "$ScriptRoot\settings\users.json"

$GroupsFile = `
    "$ScriptRoot\settings\securitygroups.csv"

$SharesFile = `
    "$ScriptRoot\settings\shares.csv"

$RightsFile = `
    "$ScriptRoot\settings\rechten.csv"

$FoldersFile = `
    "$ScriptRoot\settings\mappen.txt"

$LogFile = `
    "$ScriptRoot\logs\InstallatieLogbesv.txt"

# ============================================================
# ACTIVE DIRECTORY MODULE
# ============================================================

if (-not(Get-Module -ListAvailable -Name ActiveDirectory)) {

    Write-Host ""
    Write-Host `
        "Active Directory module niet gevonden." `
        -ForegroundColor Red

    return
}

Import-Module ActiveDirectory

# ============================================================
# FUNCTION : Write-BESVDomainLog
# ============================================================

function Write-BESVDomainLog {

<#
.SYNOPSIS
Schrijft informatie weg naar logbestand.

.DESCRIPTION
Deze functie schrijft meldingen weg naar het
centrale logbestand van het project.

.EXAMPLE
Write-BESVDomainLog -Message "OU aangemaakt"

.NOTES
Auteur : besv

Bronnen :
F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 71
- Hfst. 144

#>

    param(
        [string]$Message
    )

    $Date = `
        Get-Date -Format "dd-MM-yyyy HH:mm:ss"

    "$Date - $Message" |
        Out-File `
        -FilePath $LogFile `
        -Append
}

# ============================================================
# FUNCTION : Test-BESVDomainExists
# ============================================================

function Test-BESVDomainExists {

<#
.SYNOPSIS
Controleert of domein bestaat.

.DESCRIPTION
Controleert of Active Directory reeds actief is.

.EXAMPLE
Test-BESVDomainExists

.NOTES
Auteur : besv

Bronnen :
- Hfst. 129 : Active Directory

#>

    try {

        Get-ADDomain | Out-Null

        return $true
    }
    catch {

        return $false
    }
}

# ============================================================
# FUNCTION : Install-BESVDomainController
# ============================================================

function Install-BESVDomainController {

<#
.SYNOPSIS
Installeert domain controller.

.DESCRIPTION
Deze functie:
- installeert ADDS
- maakt domein aan
- configureert DNS

Gebruikt:
Domain.Settings.xml

.EXAMPLE
Install-BESVDomainController

.NOTES
Auteur : besv

Bronnen :

F. Vanhoo,
"PowerShell Vlot gebruiken"

- Hfst. 129 : Active Directory
- Hfst. 149 : Fouten opvangen
- Hfst. 151 : Try/Catch

Microsoft Learn:
Install-ADDSForest

#>

    [xml]$Settings = `
        Get-Content $DomainSettingsFile

    $DomainName = `
        $Settings.Settings.Domain.domainname

    $DomainName = `
        $DomainName.Replace("xxx","besv")

    if (Test-BESVDomainExists) {

        Write-Host ""
        Write-Host `
            "Domein bestaat reeds." `
            -ForegroundColor Yellow

        Write-BESVDomainLog `
            -Message "Domein bestaat reeds"

        return
    }

    try {

        Install-WindowsFeature `
            AD-Domain-Services `
            -IncludeManagementTools

        Write-Host ""
        Write-Host `
            "Installatie ADDS gestart..." `
            -ForegroundColor Cyan

        Install-ADDSForest `
            -DomainName $DomainName `
            -InstallDns `
            -Force:$true

        Write-BESVDomainLog `
            -Message `
            "Domain controller geïnstalleerd"
    }
    catch {

        Write-Host `
            "Fout tijdens installatie domain controller." `
            -ForegroundColor Red

        Write-BESVDomainLog `
            -Message `
            "Fout tijdens installatie domain controller"
    }
}

# ============================================================
# FUNCTION : New-BESVOUs
# ============================================================

function New-BESVOUs {

<#
.SYNOPSIS
Maakt OU's aan.

.DESCRIPTION
Deze functie maakt de Organizational Units aan
voor het domein.

.EXAMPLE
New-BESVOUs

.NOTES
Auteur : besv

Bronnen :
- Hfst. 129 : Active Directory
- Hfst. 79  : CSV-bestanden

#>

    $OUs = @(
        "Corporate",
        "Management",
        "HR",
        "Finance",
        "Operations",
        "IT",
        "Production",
        "Sales",
        "Domestic",
        "International",
        "Infrastructure"
    )

    $DomainDN = `
        (Get-ADDomain).DistinguishedName

    foreach ($OU in $OUs) {

        try {

            $Exists = `
                Get-ADOrganizationalUnit `
                -Filter "Name -eq '$OU'" `
                -ErrorAction SilentlyContinue

            if (-not($Exists)) {

                New-ADOrganizationalUnit `
                    -Name $OU `
                    -Path $DomainDN

                Write-Host `
                    "OU aangemaakt: $OU" `
                    -ForegroundColor Green

                Write-BESVDomainLog `
                    -Message `
                    "OU aangemaakt: $OU"
            }
            else {

                Write-Host `
                    "OU bestaat reeds: $OU" `
                    -ForegroundColor Yellow
            }
        }
        catch {

            Write-Host `
                "Fout tijdens aanmaken OU." `
                -ForegroundColor Red
        }
    }
}

# ============================================================
# FUNCTION : New-BESVSecurityGroups
# ============================================================

function New-BESVSecurityGroups {

<#
.SYNOPSIS
Maakt security groups aan.

.DESCRIPTION
Deze functie leest securitygroups.csv
en maakt alle groepen aan.

DL_ = Domain Local
GL_ = Global

.EXAMPLE
New-BESVSecurityGroups

.NOTES
Auteur : besv

Bronnen :
- Hfst. 79  : CSV-bestanden
- Hfst. 129 : Active Directory

#>

    $Groups = `
        Import-Csv $GroupsFile

    foreach ($Group in $Groups) {

        $GroupName = `
            $Group.Name

        if ($GroupName -match "^DL_") {

            $Scope = "DomainLocal"
        }
        else {

            $Scope = "Global"
        }

        try {

            $Exists = `
                Get-ADGroup `
                -Filter "Name -eq '$GroupName'" `
                -ErrorAction SilentlyContinue

            if (-not($Exists)) {

                New-ADGroup `
                    -Name $GroupName `
                    -GroupScope $Scope `
                    -GroupCategory Security

                Write-Host `
                    "Group aangemaakt: $GroupName" `
                    -ForegroundColor Green

                Write-BESVDomainLog `
                    -Message `
                    "Group aangemaakt: $GroupName"
            }
        }
        catch {

            Write-Host `
                "Fout tijdens group creatie." `
                -ForegroundColor Red
        }
    }
}

# ============================================================
# FUNCTION : New-BESVUsers
# ============================================================

function New-BESVUsers {

<#
.SYNOPSIS
Maakt domain users aan.

.DESCRIPTION
Deze functie leest users.json
en maakt alle gebruikers aan.

.EXAMPLE
New-BESVUsers

.NOTES
Auteur : besv

Bronnen :
- Hfst. 81  : JSON-bestanden
- Hfst. 129 : Active Directory

#>

    [xml]$Settings = `
        Get-Content $DomainSettingsFile

    $Password = `
        $Settings.Settings.UserSettings.defaultPassword

    $SecurePassword = `
        ConvertTo-SecureString `
        $Password `
        -AsPlainText `
        -Force

    $Users = `
        (Get-Content $UsersFile -Raw |
        ConvertFrom-Json).users

    $DomainName = `
        $Settings.Settings.Domain.domainname

    $DomainName = `
        $DomainName.Replace("xxx","besv")

    foreach ($User in $Users) {

        $DisplayName = `
            "$($User.firstName) $($User.lastName)"

        try {

            $Exists = `
                Get-ADUser `
                -Filter "SamAccountName -eq '$($User.login)'" `
                -ErrorAction SilentlyContinue

            if (-not($Exists)) {

                New-ADUser `
                    -Name $DisplayName `
                    -GivenName $User.firstName `
                    -Surname $User.lastName `
                    -SamAccountName $User.login `
                    -UserPrincipalName `
                    "$($User.login)@$DomainName" `
                    -AccountPassword $SecurePassword `
                    -Enabled $true

                Write-Host `
                    "User aangemaakt: $DisplayName" `
                    -ForegroundColor Green

                Write-BESVDomainLog `
                    -Message `
                    "User aangemaakt: $DisplayName"
            }
            else {

                Write-Host `
                    "User bestaat reeds: $DisplayName" `
                    -ForegroundColor Yellow
            }
        }
        catch {

            Write-Host `
                "Fout tijdens user creatie." `
                -ForegroundColor Red
        }
    }
}

# ============================================================
# FUNCTION : Add-BESVUsersToGroups
# ============================================================

function Add-BESVUsersToGroups {

<#
.SYNOPSIS
Voegt users toe aan groups.

.DESCRIPTION
Deze functie leest users.json
en voegt gebruikers toe aan de juiste groups.

.EXAMPLE
Add-BESVUsersToGroups

.NOTES
Auteur : besv

Bronnen :
- Hfst. 81  : JSON-bestanden
- Hfst. 129 : Active Directory

#>

    $Users = `
        (Get-Content $UsersFile -Raw |
        ConvertFrom-Json).users

    foreach ($User in $Users) {

        foreach ($Group in $User.securityGroups) {

            try {

                $GroupExists = `
                    Get-ADGroup `
                    -Filter "Name -eq '$Group'" `
                    -ErrorAction SilentlyContinue

                if ($GroupExists) {

                    Add-ADGroupMember `
                        -Identity $Group `
                        -Members $User.login `
                        -ErrorAction Stop

                    Write-Host `
                        "$($User.login) toegevoegd aan $Group" `
                        -ForegroundColor Green

                    Write-BESVDomainLog `
                        -Message `
                        "$($User.login) toegevoegd aan $Group"
                }
                else {

                    Write-Host `
                        "Group bestaat niet: $Group" `
                        -ForegroundColor Yellow
                }
            }
            catch {

                Write-Host `
                    "Fout tijdens toevoegen group." `
                    -ForegroundColor Red
            }
        }
    }
}

# ============================================================
# FUNCTION : New-BESVFolders
# ============================================================

function New-BESVFolders {

<#
.SYNOPSIS
Maakt folderstructuur aan.

.DESCRIPTION
Deze functie leest mappen.txt
en maakt folders aan.

.EXAMPLE
New-BESVFolders

.NOTES
Auteur : besv

Bronnen :
- Hfst. 71
- Hfst. 79

#>

    $Folders = `
        Get-Content $FoldersFile

    foreach ($Folder in $Folders) {

        try {

            if (-not(Test-Path $Folder)) {

                New-Item `
                    -Path $Folder `
                    -ItemType Directory `
                    -Force | Out-Null

                Write-Host `
                    "Folder aangemaakt: $Folder" `
                    -ForegroundColor Green

                Write-BESVDomainLog `
                    -Message `
                    "Folder aangemaakt: $Folder"
            }
            else {

                Write-Host `
                    "Folder bestaat reeds: $Folder" `
                    -ForegroundColor Yellow
            }
        }
        catch {

            Write-Host `
                "Fout tijdens folder creatie." `
                -ForegroundColor Red
        }
    }
}

# ============================================================
# FUNCTION : New-BESVShares
# ============================================================

function New-BESVShares {

<#
.SYNOPSIS
Maakt SMB shares aan.

.DESCRIPTION
Deze functie leest shares.csv
en maakt SMB shares aan.

.EXAMPLE
New-BESVShares

.NOTES
Auteur : besv

Bronnen :
- Hfst. 79
- Hfst. 129

Microsoft Learn:
New-SmbShare

#>

    $Shares = `
        Import-Csv $SharesFile

    foreach ($Share in $Shares) {

        try {

            if (-not(Test-Path $Share.Path)) {

                New-Item `
                    -Path $Share.Path `
                    -ItemType Directory `
                    -Force | Out-Null
            }

            $Exists = `
                Get-SmbShare `
                -Name $Share.Name `
                -ErrorAction SilentlyContinue

            if (-not($Exists)) {

                New-SmbShare `
                    -Name $Share.Name `
                    -Path $Share.Path `
                    -FullAccess "Everyone"

                Write-Host `
                    "Share aangemaakt: $($Share.Name)" `
                    -ForegroundColor Green

                Write-BESVDomainLog `
                    -Message `
                    "Share aangemaakt: $($Share.Name)"
            }
        }
        catch {

            Write-Host `
                "Fout tijdens share creatie." `
                -ForegroundColor Red
        }
    }
}

# ============================================================
# FUNCTION : Set-BESVPermissions
# ============================================================

function Set-BESVPermissions {

<#
.SYNOPSIS
Stelt NTFS rechten in.

.DESCRIPTION
Deze functie leest rechten.csv
en configureert NTFS rechten.

.EXAMPLE
Set-BESVPermissions

.NOTES
Auteur : besv

Bronnen :
- Hfst. 129
- Hfst. 149
- Hfst. 151

Microsoft Learn:
Set-Acl

#>

    $Rights = `
        Import-Csv $RightsFile

    foreach ($Right in $Rights) {

        try {

            if (Test-Path $Right.Path) {

                $Acl = `
                    Get-Acl $Right.Path

                $AccessRule = `
                    New-Object `
                    System.Security.AccessControl.FileSystemAccessRule(
                        $Right.Group,
                        $Right.Permission,
                        "ContainerInherit,ObjectInherit",
                        "None",
                        "Allow"
                    )

                $Acl.AddAccessRule($AccessRule)

                Set-Acl `
                    -Path $Right.Path `
                    -AclObject $Acl

                Write-Host `
                    "NTFS rechten ingesteld op $($Right.Path)" `
                    -ForegroundColor Green

                Write-BESVDomainLog `
                    -Message `
                    "NTFS rechten ingesteld op $($Right.Path)"
            }
            else {

                Write-Host `
                    "Pad bestaat niet: $($Right.Path)" `
                    -ForegroundColor Yellow
            }
        }
        catch {

            Write-Host `
                "Fout tijdens NTFS configuratie." `
                -ForegroundColor Red
        }
    }
}

# ============================================================
# EXPORT FUNCTIONS
# ============================================================

Export-ModuleMember -Function *