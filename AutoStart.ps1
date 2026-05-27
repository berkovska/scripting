# ============================================================
# Auteur  : besv
# Bestand : AutoStart.ps1
# Doel    : Wordt automatisch gestart via Windows Taakplanner
#           of via de Startup-map na elke herstart van de VM.
#           Controleert of PowerShell als Administrator draait
#           en start dan Menubesv.ps1 op.
#
# Bronnen :
#   F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022
#   https://learn.microsoft.com/en-us/powershell/module/
#     scheduledtasks/register-scheduledtask
#   https://learn.microsoft.com/en-us/powershell/module/
#     microsoft.powershell.management/start-process
# ============================================================

# Controleer of het script al als Administrator draait
# Bron: https://learn.microsoft.com/en-us/dotnet/api/
#         system.security.principal.windowsprincipal
$isAdmin = ([Security.Principal.WindowsPrincipal]
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Herstart zichzelf als Administrator
    Start-Process powershell.exe `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

# Menubesv.ps1 ligt in dezelfde map als AutoStart.ps1
$menuScript = Join-Path $PSScriptRoot "Menubesv.ps1"

if (Test-Path $menuScript) {
    & $menuScript
}
else {
    Write-Host "FOUT: Menubesv.ps1 niet gevonden op: $menuScript" -ForegroundColor Red
    Read-Host "Druk op ENTER om af te sluiten"
}
