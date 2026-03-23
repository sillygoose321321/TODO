Great question, Tomáš. Short answer first:

> You don’t *integrate Sysmon “into”* **Microsoft‑Windows‑Security‑Vault**. Instead, you collect **Security‑Vault/Credential Manager** events side‑by‑side with **Sysmon** telemetry and correlate them in your SIEM (e.g., Microsoft Sentinel). For “preventive EDR” and “proactive sandboxing API prehooks,” you enable **Defender for Endpoint** controls (EDR in block mode, ASR, WDAC), and use Windows’ **pre‑execution scanning hooks** such as **AMSI** and **Attachment Execution Services (IAttachmentExecute/IOfficeAntiVirus)**. [\[github.com\]](https://github.com/libyal/winevt-kb/blob/main/docs/sources/eventlog-providers/Provider-Microsoft-Windows-Security-Vault.md?plain=1), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-events), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/use-windows-event-forwarding-to-assist-in-intrusion-detection), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/edr-in-block-mode)

Below is a practical, step‑by‑step blueprint you can apply.

***

## 1) What to collect: Sysmon + Security/Vault + Security‑Auditing

**a) Sysmon (rich behavioral telemetry)**  
Install Sysmon and deploy a tuned configuration (process starts, network, registry, file, DNS, process access). This data lands in *Applications and Services Logs → Microsoft → Windows → Sysmon/Operational* and is ideal to correlate with vault activity. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-events), [\[binarydefense.com\]](https://binarydefense.com/resources/blog/using-sysmon-and-etw-for-so-much-more/)

**b) Credential Manager / Vault events**  
Windows logs Credential Manager activity under the **Security** log and via the **Microsoft‑Windows‑Security‑Vault** provider. At minimum, collect:

*   **Event 5376** – *Credential Manager credentials were backed up* (Security‑Auditing). [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5376)
*   **Event 5377** – *Credential Manager credentials were restored from a backup* (Security‑Auditing). [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5377)
*   **Microsoft‑Windows‑Security‑Vault provider** (Operational channel), for low‑level vault operations. (This is the ETW/EventLog provider you can subscribe to/forward.) [\[github.com\]](https://github.com/libyal/winevt-kb/blob/main/docs/sources/eventlog-providers/Provider-Microsoft-Windows-Security-Vault.md?plain=1)
*   (Optional) Some environments also see **Security 5615 – Vault access**; if your build logs it, collect and alert on it. [\[anavem.com\]](https://anavem.com/en/windows-events/windows-event-id-5615-security-credential-manager-vault-access)

**c) Centralize via WEF (or AMA to Sentinel)**  
Use **Windows Event Forwarding** (baseline + suspect subscriptions) to ship the above logs to a collector or directly into Sentinel/your SIEM. WEF can forward any Admin/Operational channel, including Sysmon and Security‑Vault. In Sentinel/Log Analytics you can also use the **Windows Security Events via AMA** connector. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/use-windows-event-forwarding-to-assist-in-intrusion-detection), [\[techcommun...rosoft.com\]](https://techcommunity.microsoft.com/blog/fasttrackforazureblog/windows-events-how-to-collect-them-in-sentinel-and-which-way-is-preferred-to-det/3997342)

***

## 2) “Preventive EDR”: turn on the right *blocking* controls

The goal is to stop credential‑theft and unsigned code *before* it runs, and to block post‑breach behavior your primary AV might miss.

**a) Enable Defender for Endpoint “EDR in block mode”**  
If a third‑party AV is primary (Defender in passive mode), **EDR in block mode** lets Defender’s EDR *remediate and block* malicious artifacts/behaviors anyway. Toggle it in Defender portal → *Settings → Endpoints → Advanced features*. Note: ASR, Network Protection and indicators require Defender AV in *active* mode; block mode focuses on post‑breach behavioral blocks. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/edr-in-block-mode), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/edr-block-mode-faqs)

**b) Apply Attack Surface Reduction (ASR) rules**  
At minimum, **Block credential stealing from LSASS** to reduce Mimikatz‑style theft paths; deploy other standard protection rules (e.g., Office child‑process, script abuse). Microsoft research and ASR reference outline the LSASS control and broader rule set. [\[microsoft.com\]](https://www.microsoft.com/en-us/security/blog/2022/10/05/detecting-and-preventing-lsass-credential-dumping-attacks/), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference)

**c) Application allow‑listing with WDAC (App Control for Business)**  
Use **Windows Defender Application Control** to only allow trusted code and enforce constrained language mode for PowerShell on high‑risk systems. Start in *Audit* and move to *Enforce* following Microsoft’s design guide or the WDAC Policy Wizard. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/appcontrol-design-guide), [\[github.com\]](https://github.com/MicrosoftDocs/WDAC-Toolkit)

***

## 3) “Proactive sandboxing API prehooks”: use Windows pre‑execution scanning

Windows offers two native “pre‑execution” hooks you can leverage (no kernel drivers required):

**a) AMSI (Antimalware Scan Interface)**  
AMSI lets the OS submit script/macro/managed content (PowerShell, WSH, Office VBA, .NET dynamic loads) to your AV/EDR **before** execution. It’s built‑in and Defender uses it to catch fileless/scripted attacks. Ensure AMSI is enabled via Defender/your EPP policy. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/win32/amsi/antimalware-scan-interface-portal), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/amsi-on-mdav)

**b) Attachment Execution Services (IAttachmentExecute) & IOfficeAntiVirus (IOAV)**  
Browsers/email clients call **IAttachmentExecute::Save** which (a) applies **Mark‑of‑the‑Web (MOTW)**, and (b) invokes **IOfficeAntiVirus** scanners to pre‑scan downloads. You can integrate with this pipeline by registering an IOAV provider or by relying on Defender’s IOAV. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-iattachmentexecute), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/platform-apis/ms537369%28v=vs.85%29)

> Why mention MOTW/SmartScreen?  
> MOTW feeds **SmartScreen reputation** and Office’s Protected View. Keep Windows patched because several **SmartScreen/MOTW bypass** CVEs were exploited recently; don’t depend on MOTW alone. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/virus-and-threat-protection/microsoft-defender-smartscreen/), [\[bleepingcomputer.com\]](https://www.bleepingcomputer.com/news/microsoft/new-windows-smartscreen-bypass-exploited-as-zero-day-since-march/)

***

## 4) How to wire it all together (battle‑tested workflow)

### Step A — Collection & correlation

1.  **Deploy Sysmon** with a hardened config (e.g., watch `vaultcmd.exe`, `rundll32.exe` with `keymgr.dll`, PowerShell, LSASS process access, sensitive registry paths). Send to WEF/SIEM. [\[binarydefense.com\]](https://binarydefense.com/resources/blog/using-sysmon-and-etw-for-so-much-more/)
2.  **Enable Security auditing** and forward **5376/5377** (and 5615 if present). Also enable the **Microsoft‑Windows‑Security‑Vault** provider channel and forward it. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5376), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5377), [\[github.com\]](https://github.com/libyal/winevt-kb/blob/main/docs/sources/eventlog-providers/Provider-Microsoft-Windows-Security-Vault.md?plain=1)
3.  **Centralize via WEF** (Baseline + Suspect subscriptions) or use **Windows Security Events via AMA** to Sentinel. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/use-windows-event-forwarding-to-assist-in-intrusion-detection), [\[techcommun...rosoft.com\]](https://techcommunity.microsoft.com/blog/fasttrackforazureblog/windows-events-how-to-collect-them-in-sentinel-and-which-way-is-preferred-to-det/3997342)

### Step B — Prevent, then detect

4.  **Turn on EDR in block mode** (if Defender AV is passive) or run Defender AV in **active** mode to get full ASR/Network Protection. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/edr-in-block-mode)
5.  **Deploy ASR rules**, at least LSASS protection; roll out in **Audit → Warn → Block**. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference)
6.  **Plan WDAC** for your privileged/critical endpoints (audit first). [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/appcontrol-design-guide)

### Step C — Pre‑execution “hooks”

7.  **Verify AMSI** is on (Defender, Intune/MDM policy). This gives pre‑execution scanning of scripts/macros and in‑memory loads. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/amsi-on-mdav)
8.  **Rely on Attachment Services/IOAV** for download scanning + MOTW tagging; keep SmartScreen enabled and patch CVEs tied to MOTW bypasses. Consider hardening Attachment Manager policies (e.g., don’t suppress zone info). [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-iattachmentexecute), [\[support.mi...rosoft.com\]](https://support.microsoft.com/en-us/topic/information-about-the-attachment-manager-in-microsoft-windows-c48a4dcd-8de5-2af5-ee9b-cd795ae42738)

***

## 5) Detections you’ll want on day one

*   **Vault backup/restore**:  
    *Security 5376/5377* by non‑admin users, or on servers where this shouldn’t happen → **High severity**. Correlate with Sysmon **ProcessCreate** (Event 1) for the invoking process and **ProcessAccess** (Event 10) against `lsass.exe`. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5376), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5377), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-events)

*   **LSASS access**:  
    Sysmon **Event 10** targeting `lsass.exe` + non‑system tool (e.g., `rundll32`, `procdump`, unsigned process). Pair this with ASR LSASS rule set to *Block*. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-events), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference)

*   **MOTW bypass patterns**:  
    Processes spawning from files that *lack* Zone.Identifier after download (ISO/VHD mounts, copy‑paste from WebDAV) + SmartScreen disabled/errored paths → raise alert. (Keep an eye on the known SmartScreen bypass CVEs patched mid‑2024.) [\[bleepingcomputer.com\]](https://www.bleepingcomputer.com/news/microsoft/new-windows-smartscreen-bypass-exploited-as-zero-day-since-march/)

***

## 6) Why Sysmon can’t “subscribe” to the Security‑Vault provider (and what to do instead)

Sysmon emits a fixed set of event types (1–29, etc.)—it does not act as a general ETW multiplexer for arbitrary providers like **Microsoft‑Windows‑Security‑Vault**. The correct pattern is to **collect both** (Sysmon + provider/Security) and **correlate centrally** (WEF/SIEM/Sentinel). [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-events), [\[github.com\]](https://github.com/libyal/winevt-kb/blob/main/docs/sources/eventlog-providers/Provider-Microsoft-Windows-Security-Vault.md?plain=1)

***

## 7) Hardening tips for credentials & vaults

*   Enable **ASR LSASS** and consider **LSA Protection/Credential Guard** where compatible, to reduce plaintext/derivative secrets exposure (Microsoft also highlights the importance of hardening LSASS to stop lateral movement). [\[microsoft.com\]](https://www.microsoft.com/en-us/security/blog/2022/10/05/detecting-and-preventing-lsass-credential-dumping-attacks/), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference)
*   If you use **SmartScreen/MOTW**, stay patched—multiple bypasses were used in the wild in 2024. [\[bleepingcomputer.com\]](https://www.bleepingcomputer.com/news/microsoft/new-windows-smartscreen-bypass-exploited-as-zero-day-since-march/)
*   Keep **Defender cloud protection / Block‑at‑first‑sight** on to block new malware within seconds (ties into Attachment Services + reputation). [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/configure-block-at-first-sight-microsoft-defender-antivirus)

***

## 8) Example: minimal watch‑list (what to alert on)

1.  **Security 5376/5377** on user workstations **outside** IT admin change windows. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5376), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-5377)
2.  Any **Sysmon Event 10** with `TargetImage = C:\Windows\System32\lsass.exe` from unsigned/rare parent processes. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-events)
3.  **ProcessCreate** of `vaultcmd.exe`, `rundll32.exe` loading `keymgr.dll`, or unusual credential tools, followed by outbound network connects. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-events)
4.  Files executed without **Zone.Identifier** shortly after download/mount → investigate possible **MOTW bypass** paths. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-iattachmentexecute), [\[bleepingcomputer.com\]](https://www.bleepingcomputer.com/news/microsoft/new-windows-smartscreen-bypass-exploited-as-zero-day-since-march/)

***

## 9) Quick Sentinel starting points (if you use it)

*   Ingest **Sysmon** (Sysmon table) + **SecurityEvent** (5376/5377) + **custom WEF channel** for `Microsoft-Windows-Security-Vault`. Use KQL to join on `DeviceId`, `TimeGenerated` ±1–5 min.
*   Use the **Windows Security Events via AMA** connector for Security log, and custom DCR for additional channels. [\[techcommun...rosoft.com\]](https://techcommunity.microsoft.com/blog/fasttrackforazureblog/windows-events-how-to-collect-them-in-sentinel-and-which-way-is-preferred-to-det/3997342)

***

### Wrap‑up

So, to answer your original phrasing precisely:

*   **Sysmon ↔ Security‑Vault**: Collect **both** and **correlate**; Sysmon doesn’t plug into the Security‑Vault provider directly. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/operating-system-security/sysmon/sysmon-events), [\[github.com\]](https://github.com/libyal/winevt-kb/blob/main/docs/sources/eventlog-providers/Provider-Microsoft-Windows-Security-Vault.md?plain=1)
*   **Preventive EDR**: Turn on **EDR in block mode** (if using 3rd‑party AV) and **ASR (LSASS)**; consider **WDAC** for allow‑listing. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/edr-in-block-mode), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/appcontrol-design-guide)
*   **Proactive sandboxing API prehooks**: Rely on **AMSI** for scripts and **Attachment Execution Services/IOAV** + **SmartScreen/MOTW** for downloads; keep patched due to known bypasses. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/win32/amsi/antimalware-scan-interface-portal), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-iattachmentexecute), [\[bleepingcomputer.com\]](https://www.bleepingcomputer.com/news/microsoft/new-windows-smartscreen-bypass-exploited-as-zero-day-since-march/)

***

### A couple of quick questions so I can tailor this to your environment in Brno:

1.  Are you running **Defender for Endpoint** (Plan 1/2) and **Intune**, or a 3rd‑party AV/EDR stack? [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/defender-endpoint/edr-in-block-mode)
2.  Which SIEM are you centralizing into (Sentinel, Splunk, ELK)? If Sentinel, do you already have **Windows Security Events via AMA** set up? [\[techcommun...rosoft.com\]](https://techcommunity.microsoft.com/blog/fasttrackforazureblog/windows-events-how-to-collect-them-in-sentinel-and-which-way-is-preferred-to-det/3997342)
3.  Do you prefer **WEF** or agent‑based collection on endpoints right now?

If you share those, I’ll draft the exact GPO/Intune policies, WEF subscriptions, and a few ready‑to‑run KQL rules for your vault + Sysmon correlation.
que
