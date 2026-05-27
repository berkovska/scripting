# ============================================================
# Auteur  : besv
# Bestand : RegisterTask.ps1
# Doel    : Registreert AutoStart.ps1 als geplande taak in
#           Windows Taakplanner. Na elke herstart van de VM
#           wordt het installatiemenu automatisch gestart.
#           RUN THIS SCRIPT ONCE AS ADMINISTRATOR.
#
# Bronnen :
#   https://learn.microsoft.com/en-us/powershell/module/
#     scheduledtasks/register-scheduledtask
#   https://learn.microsoft.com/en-us/powershell/module/
#     scheduledtasks/new-scheduledtaskaction
#   F. Vanhoo, "PowerShell Vlot gebruiken", Die Keure, 2022
# ============================================================

#Requires -RunAsAdministrator

$scriptPad  = "C:\scripting\AutoStart.ps1"
$taaknaam   = "BesV - Installatietool opstarten"

# Verwijder bestaande taak als die al bestaat
Unregister-ScheduledTask -TaskName $taaknaam -Confirm:$false -ErrorAction SilentlyContinue

# Actie: PowerShell starten met AutoStart.ps1
# Bron: https://learn.microsoft.com/en-us/powershell/module/
#         scheduledtasks/new-scheduledtaskaction
$actie = New-ScheduledTaskAction `
    -Execute    "powershell.exe" `
    -Argument   "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$scriptPad`""

# Trigger: bij aanmelden van elke gebruiker
# Bron: https://learn.microsoft.com/en-us/powershell/module/
#         scheduledtasks/new-scheduledtasktrigger
$trigger = New-ScheduledTaskTrigger -AtLogOn

# Instellingen: als hoogste rechten uitvoeren
# Bron: https://learn.microsoft.com/en-us/powershell/module/
#         scheduledtasks/new-scheduledtaskprincipal
$principal = New-ScheduledTaskPrincipal `
    -UserId    "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel  Highest

$instellingen = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -RestartCount 0

# Taak registreren
Register-ScheduledTask `
    -TaskName  $taaknaam `
    -Action    $actie `
    -Trigger   $trigger `
    -Principal $principal `
    -Settings  $instellingen `
    -Force

Write-Host ""
Write-Host "Taak '$taaknaam' succesvol geregistreerd." -ForegroundColor Green
Write-Host "AutoStart.ps1 wordt nu automatisch gestart na elke herstart." -ForegroundColor Green
Write-Host ""
Read-Host "Druk op ENTER om af te sluiten"
