BESV scriptingproject - Nederlandse versie

Juiste structuur:

\scripting\
  Menubesv.ps1
  modules\
    algemeenbesv.psm1
    domainsettingsbesv.psm1
  settings\
    Computer.Settings.xml
    Domain.Settings.xml
    users.json
    securitygroups.csv
    shares.csv
    rechten.csv
    mappen.txt
  logs\
    InstallatieLogbesv.txt

Gebruik:
1. Kopieer deze volledige map naar C:\scripting op de Windows Server 2025 VM of Windows 11 VM.
2. Vertrek altijd van de settingsbestanden uit de school-ZIP. De structuur, kolomnamen en bestandsnamen mogen niet wijzigen.
3. Pas alleen de inhoud aan die de opdracht expliciet vraagt:
   - voeg de initialen toe aan de hostname en domeinnaam;
   - wijzig de MAC-adressen naar de echte VMware-adapters.
4. Start PowerShell als Administrator.
5. Voer uit:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\scripting\Menubesv.ps1

Belangrijk:
- Er zijn geen aparte AutoStart.ps1 of RegisterTask.ps1 bestanden.
- De autostart- en scheduled-task-logica zit in algemeenbesv.psm1.
- Menubesv.ps1 is het enige startscript.
- Alle uitvoer wordt gelogd naar logs\InstallatieLogbesv.txt.
- Neem VMware snapshots voor elke grote stap.
