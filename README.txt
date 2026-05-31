BESV scripting project - English version

Correct structure:

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

Use:
1. Copy this complete folder to C:\scripting on the Windows Server 2025 VM or Windows 11 VM.
2. Always start from the settings files in the school ZIP. The structure, headers and filenames must not change.
3. Only edit the content that the assignment explicitly asks for:
   - add the initials to the hostname and domain name;
   - change the MAC addresses to the real VMware adapters.
4. Start PowerShell as Administrator.
5. Run:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\scripting\Menubesv.ps1

Important:
- There are no separate AutoStart.ps1 or RegisterTask.ps1 files.
- The autostart and scheduled-task logic is integrated in algemeenbesv.psm1.
- Menubesv.ps1 is the only startup script.
- All output is logged to logs\InstallatieLogbesv.txt.
- Take VMware snapshots before every major step.
