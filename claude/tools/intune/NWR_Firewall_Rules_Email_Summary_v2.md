# NWR Project - Firewall Rules Request (v2.2 — EDL/ISDB Approach)

**Priority: CRITICAL** - Blocking Entra ID Connect deployment
**Date**: February 2025
**Supersedes**: v1 (January 2025, FQDN-based)

---

## Why This Update

The original v1 request used 48+ FQDN rules. Microsoft's official guidance states: *"IP addresses should be used when possible, for security and performance reasons."*

We are replacing most FQDN rules with **IP-based and URL-based feeds** that are auto-updated and don't depend on DNS:
- **FortiGate (perimeter)**: Built-in ISDB objects (FortiGuard auto-updated)
- **Palo Alto (internal)**: EDL Hosting Service (saasedl.paloaltonetworks.com)

**v2.1 addition**: M365 EDL feeds use `any` service area (broadest IP coverage — required because auth shares IPs with other M365 services). **Outlook, Teams, and OneDrive blocked at L7** via Palo Alto App-ID deny rules and FortiGate ISDB deny rules.

**v2.2 correction**: EDL feed URLs verified against [Palo Alto EDL Hosting Service](https://saasedl.paloaltonetworks.com/feeds.html). M365 Default and Defender have **URL-type feeds only** (no IPv4). Intune feed requires `/all/` path segment. EDLs split into IP List + URL List types.

**Result**: 48+ rules → ~20 rules, zero maintenance, Azure Front Door resilient, M365 apps blocked.

---

## Network Architecture

```
  Field Device / EC Server
          |
    [Palo Alto] ← INTERNAL — EDL feeds + App-ID blocking
          |
    [FortiGate] ← PERIMETER — ISDB objects + ISDB deny rules
          |
    [Internet] → Microsoft Services
```

---

## Servers Requiring Access

| Server | Site | Role |
|--------|------|------|
| M7EC-EC1-CYB-01 | M7EC | Primary Entra Connect |
| PH-EC2-CYB-01 | PH | Standby Entra Connect |
| Field Devices | All | Intune-managed endpoints |

---

## Palo Alto (Internal Firewall) — EDL Configuration

### Step 1: Create 5 EDL Objects

Objects > External Dynamic Lists > Add (Refresh: Hourly)

**Note**: Uses `any` service area (auth shares IPs with other M365 services — no `common`-only feed exists). Outlook/Teams/OneDrive blocked at L7 via App-ID deny rules.

**3 IP List EDLs** (Type: IP List — used as destination address in security rules):

| EDL Name | Type | Feed URL |
|----------|------|----------|
| MS365-Optimize-IPv4 | IP List | `https://saasedl.paloaltonetworks.com/feeds/m365/worldwide/any/optimize/ipv4` |
| MS365-Allow-IPv4 | IP List | `https://saasedl.paloaltonetworks.com/feeds/m365/worldwide/any/allow/ipv4` |
| MS-Intune-IPv4 | IP List | `https://saasedl.paloaltonetworks.com/feeds/msintune/all/ipv4` |

**2 URL List EDLs** (Type: URL List — used in URL Filtering profiles):

| EDL Name | Type | Feed URL | Note |
|----------|------|----------|------|
| MS365-Default-URL | URL List | `https://saasedl.paloaltonetworks.com/feeds/m365/worldwide/any/default/url` | No IPv4 feed exists for Default category |
| MS-Defender-URL | URL List | `https://saasedl.paloaltonetworks.com/feeds/msdefender/uk/any/url` | Region-specific (uk/eu/us/dod), no IPv4 feed exists |

**v2.2 Note**: URL List EDLs cannot be used as destination addresses — they require a URL Filtering profile with a Custom URL Category. FortiGate ISDB at the perimeter covers both Defender (`Microsoft-Defender`) and Windows Update (`Microsoft-Microsoft.Update`), so the PA URL EDLs provide defense-in-depth.

### Step 2: App-ID Deny Rule (FIRST in policy order)

| # | Rule Name | Source | Application (App-ID) | Action |
|---|-----------|--------|---------------------|--------|
| 1 | Block-M365-Productivity | EC-Servers, Field-Devices | ms-teams, ms-teams-audio-video, ms-onedrive, sharepoint-online, outlook-web-online, ms-office365-base | **Deny** |

**Note**: App-ID requires SSL decryption for full M365 sub-app identification. Since Microsoft services bypass SSL inspection (cert pinning), App-ID is best-effort. Primary M365 blocking relies on **FortiGate ISDB deny rules** (perimeter) and **Conditional Access** (Entra ID).

### Step 3: Security Policies — Entra Connect Servers

| # | Rule Name | Source | Destination | Port | Action |
|---|-----------|--------|-------------|------|--------|
| 2 | Allow-EC-MS-Auth | EC-Servers | MS365-Optimize-IPv4 (IP EDL) | 443 | Allow |
| 3 | Allow-EC-MS-Services | EC-Servers | MS365-Allow-IPv4 (IP EDL) | 443 | Allow |
| 4 | Allow-EC-MS-Updates | EC-Servers | Any + URL Filter: MS365-Default-URL | 443 | Allow |
| 5 | Allow-EC-CRL-OCSP | EC-Servers | CRL-OCSP-Group | 80 | Allow |
| 6 | Allow-EC-ServiceBus | EC-Servers | *.servicebus.windows.net | 443, 5671 | Allow |
| 7 | Allow-EC-AD | EC-Servers | Domain Controllers | AD Ports | Allow |
| 8 | Block-EC-All | EC-Servers | Any | Any | Deny |

### Step 4: Security Policies — Field Devices

| # | Rule Name | Source | Destination | Port | Action |
|---|-----------|--------|-------------|------|--------|
| 2 | Allow-FD-MS-Auth | Field-Devices | MS365-Optimize-IPv4 (IP EDL) | 443 | Allow |
| 3 | Allow-FD-MS-Intune | Field-Devices | MS-Intune-IPv4 (IP EDL) | 443 | Allow |
| 4 | Allow-FD-MS-Defender | Field-Devices | Any + URL Filter: MS-Defender-URL | 443 | Allow |
| 5 | Allow-FD-MS-Services | Field-Devices | MS365-Allow-IPv4 (IP EDL) | 443 | Allow |
| 6 | Allow-FD-MS-Updates | Field-Devices | Any + URL Filter: MS365-Default-URL | 443 | Allow |
| 7 | Allow-FD-CRL-OCSP | Field-Devices | CRL-OCSP-Group | 80 | Allow |
| 8 | Allow-FD-Apps | Field-Devices | Apps-FQDN-Group | 443 | Allow |
| 9 | Block-FD-All | Field-Devices | Any | Any | Deny |

### Step 5: SSL Inspection Bypass

Policies > Decryption > Add (ABOVE any "Decrypt All" rule):
- Source: EC-Servers, Field-Devices
- Destination: MS-Intune-IPv4, MS365-Optimize-IPv4, MS365-Allow-IPv4
- Action: **No Decrypt**

**Note**: MS-Defender-URL and MS365-Default-URL are URL List EDLs — SSL bypass handled via URL category exception or relies on FortiGate perimeter ISDB (certificate-inspection).

---

## FortiGate (Perimeter Firewall) — ISDB Configuration

### ISDB Objects (Built-In — Already Available)

| ISDB Object | What It Covers | Action |
|-------------|---------------|--------|
| Microsoft-Office365.Exchange | Outlook / Exchange | **DENY** |
| Microsoft-Office365.SharePoint | OneDrive / SharePoint | **DENY** |
| Microsoft-Teams | Microsoft Teams | **DENY** |
| Microsoft-Office365 | Auth, Graph, Entra ID, M365 core | Allow |
| Microsoft-Intune | Intune MDM, enrollment | Allow |
| Microsoft-Defender | Defender cloud, definitions | Allow |
| Microsoft-Microsoft.Update | Windows Update | Allow |
| Microsoft-Azure | Azure management, portal, blobs | Allow |
| Microsoft-Azure.Bastion | Azure Bastion service | Allow |

### Deny Rules (FIRST in policy order)

| # | Rule Name | ISDB Object | Action |
|---|-----------|-------------|--------|
| 1 | Block-M365-Exchange | Microsoft-Office365.Exchange | **Deny** |
| 2 | Block-M365-SharePoint | Microsoft-Office365.SharePoint | **Deny** |
| 3 | Block-M365-Teams | Microsoft-Teams | **Deny** |

### Allow Policies — Entra Connect Servers

| # | Rule Name | ISDB / Destination | SSL Profile | Action |
|---|-----------|-------------------|-------------|--------|
| 4 | Allow-EC-MS-Auth-Core | Microsoft-Office365 | certificate-inspection | Allow |
| 5 | Allow-EC-MS-Azure | Microsoft-Azure | certificate-inspection | Allow |
| 6 | Allow-EC-MS-Updates | Microsoft-Microsoft.Update | certificate-inspection | Allow |
| 7 | Allow-EC-CRL-OCSP | CRL-OCSP-Group (FQDN) | — | Allow |
| 8 | Allow-EC-ServiceBus | *.servicebus.windows.net (FQDN) | — | Allow |
| 9 | Allow-EC-AD-Internal | Domain Controllers | — | Allow |
| 10 | Deny-EC-All | All | — | Deny |

### Allow Policies — Field Devices

| # | Rule Name | ISDB / Destination | SSL Profile | Action |
|---|-----------|-------------------|-------------|--------|
| 4 | Allow-FD-MS-Auth-Core | Microsoft-Office365 | certificate-inspection | Allow |
| 5 | Allow-FD-MS-Intune | Microsoft-Intune | certificate-inspection | Allow |
| 6 | Allow-FD-MS-Defender | Microsoft-Defender | certificate-inspection | Allow |
| 7 | Allow-FD-MS-Updates | Microsoft-Microsoft.Update | certificate-inspection | Allow |
| 8 | Allow-FD-MS-Azure | Microsoft-Azure, Microsoft-Azure.Bastion | certificate-inspection | Allow |
| 9 | Allow-FD-CRL-OCSP | CRL-OCSP-Group (FQDN) | — | Allow |
| 10 | Allow-FD-ShareFile | ShareFile-Group (FQDN) | — | Allow |
| 11 | Deny-FD-All | All | — | Deny |

---

## FQDN Rules (Still Required — No EDL/ISDB Coverage)

### CRL/OCSP — Port 80 HTTP (Both Firewalls)

| # | FQDN | Port | Note |
|---|------|------|------|
| 1 | crl.microsoft.com | 80 | Microsoft CRL |
| 2 | mscrl.microsoft.com | 80 | Microsoft CRL |
| 3 | crl3.digicert.com | 80 | DigiCert CRL |
| 4 | crl4.digicert.com | 80 | DigiCert CRL |
| 5 | ocsp.digicert.com | 80 | DigiCert OCSP |
| 6 | ocsp.msocsp.com | 80 | Microsoft OCSP |
| 7 | www.microsoft.com | 80 | CRL distribution |
| 8 | ctldl.windowsupdate.com | 80 | Certificate Trust List |

**Port 80 is NOT a mistake** — CRL/OCSP uses HTTP, not HTTPS.

### App-Specific — Port 443 HTTPS (Field Devices Only)

| # | FQDN | Purpose |
|---|------|---------|
| 9 | *.sharefile.com | ShareFile service |
| 10 | *.sf-api.com | ShareFile API |
| 11 | *.citrixdata.com | ShareFile storage |
| 12 | *.bastion.azure.com | Azure Bastion |
| 13 | *.portal.azure.com | Azure Portal |

### Entra Connect Only — Port 443 + 5671

| # | FQDN | Port | Purpose |
|---|------|------|---------|
| 14 | *.servicebus.windows.net | 443, 5671 | Password writeback |

---

## M365 App Blocking — Defense in Depth

| Layer | Platform | What's Blocked | How | Effectiveness |
|-------|----------|---------------|-----|---------------|
| 1. ISDB deny | FortiGate (perimeter) | Exchange, SharePoint, Teams ISDB objects | ISDB deny rules before allow | **PRIMARY** — no decryption needed |
| 2. App-ID | Palo Alto (internal) | ms-teams, ms-onedrive, outlook-web-online, sharepoint-online | App-ID deny rule | **BEST-EFFORT** — limited without SSL decrypt |
| 3. Conditional Access | Entra ID (recommended) | Block M365 app tokens for device group | CA policy | **STRONGEST** — token-level enforcement |

---

## Comparison: v1 (FQDN) vs v2.2 (EDL/ISDB)

| | v1 (FQDN) | v2.2 (EDL/ISDB) |
|---|-----------|-----------------|
| Microsoft service rules | 35+ FQDNs | 3 IP EDLs + 2 URL EDLs + ISDB objects |
| CRL/OCSP rules | 8 FQDNs | 8 FQDNs (unchanged) |
| App-specific | 5 FQDNs | 5 FQDNs (unchanged) |
| M365 app blocking | Implicit (no FQDN = blocked) | Explicit (App-ID + ISDB deny at L7) |
| Total rules | 48+ | ~20 |
| DNS dependency | All rules | CRL/OCSP + apps only |
| Maintenance | Manual FQDN updates | Zero (auto-updated feeds) |
| Azure Front Door | Breaks on IP rotation | Auto-covered |
| SSL bypass | FQDN matching | EDL/ISDB object matching |

---

## Verification

After firewall changes, run on Entra Connect servers:

```powershell
# Quick check — these should PASS
Test-NetConnection login.microsoftonline.com -Port 443
Test-NetConnection graph.microsoft.com -Port 443
Test-NetConnection crl.microsoft.com -Port 80

# Quick check — these should FAIL (blocked)
Test-NetConnection outlook.office365.com -Port 443
Test-NetConnection teams.microsoft.com -Port 443
```

Full verification scripts (with expected PASS/FAIL for each endpoint) are in the detailed document: `NWR_Firewall_Request_SICE_v2.md` (Sections 9.3 and 9.4).

---

## Important Notes

1. **SSL Inspection**: Use `certificate-inspection` (not deep-inspection) for Microsoft services on both firewalls
2. **Port 80 Required**: CRL/OCSP uses HTTP — will cause TLS failures if blocked
3. **Azure Front Door**: Auto-covered by EDL/ISDB feeds — no manual IP updates needed
4. **Policy Order**: Deny rules (M365 productivity) MUST come BEFORE allow rules on both firewalls
5. **Feed Monitoring**: Palo Alto EDLs refresh hourly; FortiGate ISDB updates via FortiGuard automatically
6. **EDL Types (v2.2)**: Palo Alto uses TWO EDL types — IP List (destination address matching) and URL List (URL Filtering profile matching). Not all Microsoft feeds have IPv4 versions.
7. **Defender Region**: MS-Defender-URL feed is region-specific — change `uk` to match your tenant region (`eu`/`us`/`dod`)

---

## Attachments

- Full firewall request: `NWR_Firewall_Request_SICE_v2.md`
- Original request (superseded): `NWR_Firewall_Request_SICE.md`
- Implementation guide: `Field_Device_Network_Restriction_Implementation_Guide.md`

---

**Contact**: Principal Endpoint Engineer
**Urgency**: CRITICAL - Blocking project deployment
