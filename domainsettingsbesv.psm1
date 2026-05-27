# ============================================================
# Auteur  : besv
# Bestand : domainsettingsbesv.psm1
# Doel    : Domeinconfiguratie: DC installatie, OUs, security
#           groups, gebruikers, groepsleden, NTFS/share-rechten
#
# Bronnen :
#   F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022/2025
#     - Hoofdstuk 10 : Active Directory
#     - Hoofdstuk 11 : Gebruikers en groepen
#   https://learn.microsoft.com/en-us/powershell/module/
#     addsdeployment/install-addsforest
#   https://learn.microsoft.com/en-us/powershell/module/
#     activedirectory/
#   https://learn.microsoft.com/en-us/powershell/module/
#     smbshare/grant-smbshareaccess
#   https://learn.microsoft.com/en-us/powershell/module/
#     microsoft.powershell.security/set-acl
# ============================================================


# ─────────────────────────────────────────────────────────────────────
function Haal-DomeinInstellingenOp {
<#
.SYNOPSIS
    Laadt Domain.Settings.xml en geeft het XML-object terug.
.DESCRIPTION
    Zoekt het bestand in de map \scripting\settings\.
    Gooit een fout als het bestand niet gevonden wordt.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 7
.EXAMPLE
    $xml = Haal-DomeinInstellingenOp
    $xml.Settings.Domain.domainname
#>
    $pad = "$global:scriptRoot\settings\Domain.Settings.xml"

    if (-not (Test-Path $pad)) {
        Schrijf-Log "FOUT: Domain.Settings.xml niet gevonden op $pad"
        throw "Bestand niet gevonden: $pad"
    }

    return [xml](Get-Content $pad -Encoding UTF8)
}


# ─────────────────────────────────────────────────────────────────────
function Installeer-Domeincontroller {
<#
.SYNOPSIS
    Installeert een domeincontroller of voegt een extra DC toe
    aan een bestaand domein.
.DESCRIPTION
    Leest domeinnaam en NetBIOS-naam uit Domain.Settings.xml.
    Controleert eerst of het domein al bestaat via Get-ADDomain:
      - Domein bestaat  : server wordt toegevoegd als extra DC
                          via Install-ADDSDomainController.
      - Domein bestaat niet : nieuw domein aangemaakt
                              via Install-ADDSForest.
    De AD DS-rol wordt eerst geïnstalleerd.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 10
    https://learn.microsoft.com/en-us/powershell/module/
      addsdeployment/install-addsforest
    https://learn.microsoft.com/en-us/powershell/module/
      addsdeployment/install-addsdomaincontroller
.EXAMPLE
    Installeer-Domeincontroller
#>
    Schrijf-Log "#### Start installatie domeincontroller... ####"

    try {
        $xml      = Haal-DomeinInstellingenOp
        $domein   = $xml.Settings.Domain.domainname
        $netbios  = $xml.Settings.Domain.domainNetbiosName
        $veiligWw = ConvertTo-SecureString $xml.Settings.UserSettings.defaultPassword -AsPlainText -Force

        # AD DS-rol installeren
        # Bron: https://learn.microsoft.com/en-us/powershell/module/
        #         servermanager/install-windowsfeature
        Write-Host "AD DS-rol installeren..." -ForegroundColor Cyan
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
        Schrijf-Log "Windows-feature AD-Domain-Services geïnstalleerd."

        # Controleer of domein al bestaat
        try {
            Get-ADDomain -Identity $domein -ErrorAction Stop | Out-Null
            $domeinBestaat = $true
        }
        catch {
            $domeinBestaat = $false
        }

        if ($domeinBestaat) {
            Write-Host "Domein '$domein' bestaat al. Extra DC toevoegen..." -ForegroundColor Yellow
            Schrijf-Log "Domein '$domein' bestaat. Extra DC wordt toegevoegd."

            $beheerdersgegevens = Get-Credential -Message "Domein administrator-credentials"

            Install-ADDSDomainController `
                -DomainName                    $domein `
                -Credential                    $beheerdersgegevens `
                -SafeModeAdministratorPassword $veiligWw `
                -InstallDns `
                -Force | Out-Null
        }
        else {
            Write-Host "Domein '$domein' bestaat niet. Nieuw domein aanmaken..." -ForegroundColor Cyan
            Schrijf-Log "Nieuw domein aanmaken: $domein (NetBIOS: $netbios)"

            Install-ADDSForest `
                -DomainName                    $domein `
                -DomainNetBiosName             $netbios `
                -SafeModeAdministratorPassword $veiligWw `
                -InstallDns `
                -Force | Out-Null
        }

        Schrijf-Log "#### Finished domeincontroller installatie. Systeem wordt herstart. ####"
    }
    catch {
        Schrijf-Log "FOUT bij installatie domeincontroller: $_"
        Write-Host "FOUT: $_" -ForegroundColor Red
        Read-Host "Druk op ENTER om verder te gaan"
    }
}


# ─────────────────────────────────────────────────────────────────────
function Maak-OUsAan {
<#
.SYNOPSIS
    Maakt organisatie-eenheden aan op basis van ous.csv.
.DESCRIPTION
    Kolommen in ous.csv: Name;Path
    De kolom Path bevat kommagescheiden ouder-OUs van laag naar hoog,
    bv. "Management,Corporate" = Corporate is de bovenste OU.
    Ouder-OUs worden eerst aangemaakt indien ze nog niet bestaan.
    Bestaande OUs geven een melding maar stoppen het script niet.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 10
    https://learn.microsoft.com/en-us/powershell/module/
      activedirectory/new-adorganizationalunit
.EXAMPLE
    Maak-OUsAan
#>
    Schrijf-Log "#### Creating organizational units... ####"

    $bestand = "$global:scriptRoot\settings\ous.csv"

    if (-not (Test-Path $bestand)) {
        Schrijf-Log "FOUT: ous.csv niet gevonden op $bestand"
        Read-Host "Druk op ENTER om verder te gaan"
        return
    }

    $domeinDN = (Get-ADDomain).DistinguishedName
    $rijen    = Import-Csv $bestand -Delimiter ";" -Encoding UTF8

    foreach ($rij in $rijen) {
        $naam = $rij.Name.Trim()
        $pad  = $rij.Path.Trim()

        # Bepaal het bovenliggende OU-pad
        if ([string]::IsNullOrEmpty($pad)) {
            $bovenliggende = $domeinDN
        }
        else {
            # Keer de volgorde om: "Management,Corporate" => [Corporate, Management]
            # Bron: F. Vanhoo, 2022, p. 78 – arrays en omdraaien
            $ouders = ($pad -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            [array]::Reverse($ouders)

            $bovenliggende = $domeinDN
            foreach ($ouder in $ouders) {
                $ouderDN = "OU=$ouder,$bovenliggende"
                if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouderDN'" -ErrorAction SilentlyContinue)) {
                    New-ADOrganizationalUnit -Name $ouder -Path $bovenliggende -ProtectedFromAccidentalDeletion $false
                    Schrijf-Log "Bovenliggende OU aangemaakt: $ouder"
                }
                $bovenliggende = $ouderDN
            }
        }

        # De OU zelf aanmaken
        $volleDN = "OU=$naam,$bovenliggende"

        if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$volleDN'" -ErrorAction SilentlyContinue) {
            Write-Host "Didn't create OU $naam in $domeinDN, must exist already" -ForegroundColor Yellow
            Schrijf-Log "Didn't create OU $naam in $domeinDN, must exist already"
        }
        else {
            try {
                New-ADOrganizationalUnit -Name $naam -Path $bovenliggende -ProtectedFromAccidentalDeletion $false
                Schrijf-Log "Created OU $naam in $domeinDN"
                Write-Host "Created OU $naam" -ForegroundColor Green
            }
            catch {
                Schrijf-Log "FOUT bij aanmaken OU '$naam': $_"
                Write-Host "FOUT: $_" -ForegroundColor Red
            }
        }
    }

    Schrijf-Log "#### Finished creating organizational units... ####"
    Read-Host "Druk op ENTER om verder te gaan"
}


# ─────────────────────────────────────────────────────────────────────
function Maak-SecurityGroupsAan {
<#
.SYNOPSIS
    Maakt domain security groups aan op basis van securitygroups.csv.
.DESCRIPTION
    Kolommen in securitygroups.csv: GroepNaam;ou
    Groepen met prefix DL_ worden als DomainLocal aangemaakt.
    Groepen met prefix GL_ worden als Global aangemaakt.
    De doelOU wordt aangemaakt als ze nog niet bestaat.
    Bestaande groepen geven een melding maar stoppen het script niet.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 11
    https://learn.microsoft.com/en-us/powershell/module/
      activedirectory/new-adgroup
.EXAMPLE
    Maak-SecurityGroupsAan
#>
    Schrijf-Log "#### Creating security groups... ####"

    $bestand = "$global:scriptRoot\settings\securitygroups.csv"

    if (-not (Test-Path $bestand)) {
        Schrijf-Log "FOUT: securitygroups.csv niet gevonden op $bestand"
        Read-Host "Druk op ENTER om verder te gaan"
        return
    }

    $domeinDN = (Get-ADDomain).DistinguishedName
    $rijen    = Import-Csv $bestand -Delimiter ";" -Encoding UTF8

    foreach ($rij in $rijen) {
        $groepNaam = $rij.GroepNaam.Trim()
        $ouNaam    = $rij.ou.Trim()

        # Groepsscope bepalen op basis van prefix
        # Bron: F. Vanhoo, 2022, p. 201
        $groepScope = if ($groepNaam -like "DL_*") { "DomainLocal" } else { "Global" }

        # OU aanmaken als ze niet bestaat
        $ouDN = "OU=$ouNaam,$domeinDN"
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $ouNaam -Path $domeinDN -ProtectedFromAccidentalDeletion $false
            Schrijf-Log "Extra OU aangemaakt voor groep '$groepNaam': $ouNaam"
        }

        if (Get-ADGroup -Filter "Name -eq '$groepNaam'" -ErrorAction SilentlyContinue) {
            Write-Host "Groep bestaat al: $groepNaam" -ForegroundColor Yellow
            Schrijf-Log "Groep bestaat reeds: $groepNaam"
        }
        else {
            try {
                New-ADGroup -Name $groepNaam -GroupScope $groepScope -GroupCategory Security -Path $ouDN
                Schrijf-Log "Groep aangemaakt: $groepNaam ($groepScope) in OU=$ouNaam"
                Write-Host "Groep aangemaakt: $groepNaam ($groepScope)" -ForegroundColor Green
            }
            catch {
                Schrijf-Log "FOUT bij aanmaken groep '$groepNaam': $_"
                Write-Host "FOUT: $_" -ForegroundColor Red
            }
        }
    }

    Schrijf-Log "#### Finished creating security groups... ####"
    Read-Host "Druk op ENTER om verder te gaan"
}


# ─────────────────────────────────────────────────────────────────────
function Maak-DomeingebruikersAan {
<#
.SYNOPSIS
    Maakt domeingebruikers aan op basis van users.json.
.DESCRIPTION
    Per gebruiker worden voornaam, achternaam, login en doelOU
    gelezen. Het standaardwachtwoord komt uit Domain.Settings.xml.
    De homemap wordt ingesteld als UNC-pad: \\server\share$\login.
    De doelOU wordt aangemaakt als ze nog niet bestaat.
    Bestaande gebruikers geven een melding maar stoppen het script niet.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 11
    https://learn.microsoft.com/en-us/powershell/module/
      activedirectory/new-aduser
.EXAMPLE
    Maak-DomeingebruikersAan
#>
    Schrijf-Log "#### Creating domain users... ####"

    $bestand = "$global:scriptRoot\settings\users.json"

    if (-not (Test-Path $bestand)) {
        Schrijf-Log "FOUT: users.json niet gevonden op $bestand"
        Read-Host "Druk op ENTER om verder te gaan"
        return
    }

    $xml        = Haal-DomeinInstellingenOp
    $domeinDN   = (Get-ADDomain).DistinguishedName
    $dnsRoot    = (Get-ADDomain).DNSRoot
    $standWw    = ConvertTo-SecureString $xml.Settings.UserSettings.defaultPassword -AsPlainText -Force
    $bestandsServer = $xml.Settings.FileServer.name
    $homeShare  = $xml.Settings.UserSettings.homeFolder.sharename
    $homeLetter = $xml.Settings.UserSettings.homeFolder.homeDrive + ":"

    # JSON inlezen
    # Bron: F. Vanhoo, 2022, hfst. 7 – ConvertFrom-Json
    $gebruikers = (Get-Content $bestand -Raw -Encoding UTF8 | ConvertFrom-Json).users

    foreach ($gebruiker in $gebruikers) {
        $aanmelding = $gebruiker.login.Trim()
        $ouNaam     = $gebruiker.ou.Trim()

        # OU opzoeken of aanmaken
        $ouObject = Get-ADOrganizationalUnit -Filter "Name -eq '$ouNaam'" -ErrorAction SilentlyContinue |
                    Select-Object -First 1

        if (-not $ouObject) {
            New-ADOrganizationalUnit -Name $ouNaam -Path $domeinDN -ProtectedFromAccidentalDeletion $false
            Schrijf-Log "OU aangemaakt voor gebruiker '$aanmelding': $ouNaam"
            $ouObject = Get-ADOrganizationalUnit -Filter "Name -eq '$ouNaam'" | Select-Object -First 1
        }

        if (Get-ADUser -Filter "SamAccountName -eq '$aanmelding'" -ErrorAction SilentlyContinue) {
            Write-Host "Gebruiker bestaat al: $aanmelding" -ForegroundColor Yellow
            Schrijf-Log "Gebruiker bestaat reeds: $aanmelding"
        }
        else {
            try {
                # UNC-pad voor homemap (verplicht voor netwerkshares)
                # Bron: F. Vanhoo, 2022, p. 215 – UNC-paden
                $thuisMap = "\\$bestandsServer\$homeShare\$aanmelding"

                New-ADUser `
                    -GivenName             $gebruiker.firstName `
                    -Surname               $gebruiker.lastName `
                    -Name                  "$($gebruiker.firstName) $($gebruiker.lastName)" `
                    -SamAccountName        $aanmelding `
                    -UserPrincipalName     "$aanmelding@$dnsRoot" `
                    -Path                  $ouObject.DistinguishedName `
                    -AccountPassword       $standWw `
                    -ChangePasswordAtLogon $false `
                    -Enabled               $true `
                    -HomeDirectory         $thuisMap `
                    -HomeDrive             $homeLetter

                Schrijf-Log "Gebruiker aangemaakt: $aanmelding ($($gebruiker.firstName) $($gebruiker.lastName)) in OU=$ouNaam"
                Write-Host "Gebruiker aangemaakt: $aanmelding" -ForegroundColor Green
            }
            catch {
                Schrijf-Log "FOUT bij aanmaken gebruiker '$aanmelding': $_"
                Write-Host "FOUT: $_" -ForegroundColor Red
            }
        }
    }

    Schrijf-Log "#### Finished creating domain users... ####"
    Read-Host "Druk op ENTER om verder te gaan"
}


# ─────────────────────────────────────────────────────────────────────
function Voeg-GebruikersToeAanGroepen {
<#
.SYNOPSIS
    Voegt domeingebruikers toe aan security groups via users.json.
.DESCRIPTION
    Leest het veld securityGroups per gebruiker uit users.json.
    Als een groep niet bestaat: foutmelding op scherm en in logbestand,
    maar het script stopt niet en gaat verder met de volgende groep.
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 11
    https://learn.microsoft.com/en-us/powershell/module/
      activedirectory/add-adgroupmember
.EXAMPLE
    Voeg-GebruikersToeAanGroepen
#>
    Schrijf-Log "#### Adding users to security groups... ####"

    $bestand = "$global:scriptRoot\settings\users.json"

    if (-not (Test-Path $bestand)) {
        Schrijf-Log "FOUT: users.json niet gevonden op $bestand"
        Read-Host "Druk op ENTER om verder te gaan"
        return
    }

    $gebruikers = (Get-Content $bestand -Raw -Encoding UTF8 | ConvertFrom-Json).users

    foreach ($gebruiker in $gebruikers) {
        $aanmelding = $gebruiker.login.Trim()

        foreach ($groep in $gebruiker.securityGroups) {
            $groep = $groep.Trim()

            if (-not (Get-ADGroup -Filter "Name -eq '$groep'" -ErrorAction SilentlyContinue)) {
                Write-Host "FOUT: Groep '$groep' bestaat niet." -ForegroundColor Red
                Schrijf-Log "FOUT: Groep '$groep' bestaat niet voor gebruiker '$aanmelding'."
                continue
            }

            try {
                Add-ADGroupMember -Identity $groep -Members $aanmelding
                Schrijf-Log "Gebruiker '$aanmelding' toegevoegd aan groep '$groep'."
                Write-Host "Toegevoegd: $aanmelding -> $groep" -ForegroundColor Green
            }
            catch {
                Schrijf-Log "FOUT: '$aanmelding' -> '$groep': $_"
                Write-Host "FOUT: $_" -ForegroundColor Red
            }
        }
    }

    Schrijf-Log "#### Finished adding users to groups... ####"
    Read-Host "Druk op ENTER om verder te gaan"
}


# ─────────────────────────────────────────────────────────────────────
function Stel-RechtenIn {
<#
.SYNOPSIS
    Kent NTFS- en share-rechten toe op basis van rechten.csv.
.DESCRIPTION
    Kolommen in rechten.csv:
      map;share;Groep;NTFS_permission;share_permission
    Per rij wordt gecontroleerd of de groep, share en map bestaan.
    Niet-bestaand element geeft een foutmelding maar stopt het script
    niet. NTFS-rechten worden erfelijk ingesteld
    (ContainerInherit + ObjectInherit).
    Bron: F. Vanhoo, "PowerShell Vlot gebruiken", 2022, hfst. 8
    https://learn.microsoft.com/en-us/powershell/module/
      smbshare/grant-smbshareaccess
    https://learn.microsoft.com/en-us/powershell/module/
      microsoft.powershell.security/set-acl
.EXAMPLE
    Stel-RechtenIn
#>
    Schrijf-Log "#### Setting NTFS and share permissions... ####"

    $bestand = "$global:scriptRoot\settings\rechten.csv"

    if (-not (Test-Path $bestand)) {
        Schrijf-Log "FOUT: rechten.csv niet gevonden op $bestand"
        Read-Host "Druk op ENTER om verder te gaan"
        return
    }

    $domein = (Get-ADDomain).NetBIOSName
    $rijen  = Import-Csv $bestand -Delimiter ";" -Encoding UTF8

    foreach ($rij in $rijen) {
        $map       = $rij.map.Trim()
        $share     = $rij.share.Trim()
        $groep     = $rij.Groep.Trim()
        $ntfsRecht = $rij.NTFS_permission.Trim()
        $shareRecht= $rij.share_permission.Trim()
        $account   = "$domein\$groep"

        # Groep controleren
        if (-not (Get-ADGroup -Filter "Name -eq '$groep'" -ErrorAction SilentlyContinue)) {
            Write-Host "FOUT: Groep '$groep' bestaat niet." -ForegroundColor Red
            Schrijf-Log "FOUT: Groep '$groep' bestaat niet."
            continue
        }

        # ── Share-rechten ─────────────────────────────────────────────────
        if ($share -ne "") {
            if (Get-SmbShare -Name $share -ErrorAction SilentlyContinue) {
                # Vertaal share_permission naar SMB-toegangsniveau
                $smbNiveau = switch ($shareRecht.ToLower()) {
                    "read"   { "Read" }
                    "change" { "Change" }
                    "full"   { "Full" }
                    default  { "Read" }
                }
                try {
                    Grant-SmbShareAccess -Name $share -AccountName $account -AccessRight $smbNiveau -Force | Out-Null
                    Schrijf-Log "Share-recht '$smbNiveau' toegekend: $account op '$share'"
                    Write-Host "Share-recht: $account -> $share ($smbNiveau)" -ForegroundColor Green
                }
                catch {
                    Schrijf-Log "FOUT bij share-recht voor '$groep' op '$share': $_"
                    Write-Host "FOUT: $_" -ForegroundColor Red
                }
            }
            else {
                Write-Host "FOUT: Share '$share' bestaat niet." -ForegroundColor Red
                Schrijf-Log "FOUT: Share '$share' bestaat niet."
            }
        }

        # ── NTFS-rechten ──────────────────────────────────────────────────
        if ($map -ne "") {
            if (Test-Path $map) {
                # Vertaal NTFS_permission naar FileSystemRights
                # Bron: https://learn.microsoft.com/en-us/dotnet/api/
                #         system.security.accesscontrol.filesystemrights
                $bestandsRecht = switch ($ntfsRecht.ToLower()) {
                    "read"   { [System.Security.AccessControl.FileSystemRights]::ReadAndExecute }
                    "modify" { [System.Security.AccessControl.FileSystemRights]::Modify }
                    "full"   { [System.Security.AccessControl.FileSystemRights]::FullControl }
                    default  { [System.Security.AccessControl.FileSystemRights]::ReadAndExecute }
                }
                try {
                    $acl        = Get-Acl $map
                    $toegangsRegel = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $account,
                        $bestandsRecht,
                        "ContainerInherit,ObjectInherit",
                        "None",
                        "Allow"
                    )
                    $acl.SetAccessRule($toegangsRegel)
                    Set-Acl -Path $map -AclObject $acl
                    Schrijf-Log "NTFS-recht '$ntfsRecht' toegekend: $account op '$map'"
                    Write-Host "NTFS-recht: $account -> $map ($ntfsRecht)" -ForegroundColor Green
                }
                catch {
                    Schrijf-Log "FOUT bij NTFS-recht voor '$groep' op '$map': $_"
                    Write-Host "FOUT: $_" -ForegroundColor Red
                }
            }
            else {
                Write-Host "FOUT: Map '$map' bestaat niet." -ForegroundColor Red
                Schrijf-Log "FOUT: Map '$map' bestaat niet."
            }
        }
    }

    Schrijf-Log "#### Finished setting permissions... ####"
    Read-Host "Druk op ENTER om verder te gaan"
}
