# TODO work
Repo for ideas I came up with for effective security work



# Windows enum and discovery commands

```
Get-PnpDevice -FriendlyName "*Trusted Platform Module*" -ErrorAction SilentlyContinue
schtasks /query /fo LIST /v 
```

```
$filePath = "C:\Windows\System32\dllhost.exe"
(Get-ItemProperty $filePath).VersionInfo | format-list * -force 
```

```
wevtutil qe Microsoft-Windows-WMI-Activity/Operational /f:text /c:20
wevtutil qe System /q:"*[System[(EventID=7036)]] and *[EventData[Data='Windows Event Log']]" /f:text /c:20
wevtutil qe Application /q:"*[System[(Level=2)]]" /c:20 /f:text
wevtutil qe Security /q:"*[System[(EventID=4688)]]" /f:text | findstr /i "wevtutil auditpol logman powershell"
```

```
Get-MpComputerStatus | Select-Object AMServiceEnabled, AntispywareEnabled, RealTimeProtectionEnabled
Get-NetEventProvider -ShowInstalled
Resolve-DnsName -Name "imaginary-host" -Type A
Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
irm https://ollama.com/install.ps1 | iex
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, InstallDate
powershell.exe -ExecutionPolicy Bypass -File .\check-sys.ps1
auditpol /list /subcategory:*
```
