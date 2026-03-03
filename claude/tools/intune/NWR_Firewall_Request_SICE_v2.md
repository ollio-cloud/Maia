# NWR Project - Firewall Request for SICE (v2 — EDL/ISDB Approach)

**Document Version**: 2.2
**Date**: February 2025
**Supersedes**: NWR_Firewall_Request_SICE v1.0 (January 2025, FQDN-based)
**Project**: NWR Field Device Network Restriction
**Requested By**: Principal Endpoint Engineer
**Priority**: **CRITICAL** - Blocking Entra ID Connect deployment

---

## Executive Summary

This document contains all required firewall rules for:
1. **Entra ID Connect Servers** (M7EC-EC1-CYB-01, PH-EC2-CYB-01) — Tier 0 infrastructure
2. **Intune-Managed Field Devices** — Windows endpoints with restricted network access

**Architecture**: FortiGate (perimeter) → Palo Alto (internal) — layered firewall design.

**Key Change from v1**: Migrated from 48+ FQDN rules to **IP-based approach** using FortiGate ISDB and Palo Alto EDLs. This aligns with Microsoft's official recommendation: *"IP addresses should be used when possible, for security and performance reasons."*

**Key Change in v2.1**: Uses `any` service category for M365 EDL feeds (broadest IP coverage), combined with **explicit App-ID deny rules** on Palo Alto and **ISDB deny rules** on FortiGate to block Outlook, Teams, and OneDrive at L7.

**Key Change in v2.2**: Corrected EDL feed URLs after verification against [Palo Alto EDL Hosting Service](https://saasedl.paloaltonetworks.com/feeds.html). M365 Default and Defender feeds only have URL-type feeds (no IPv4). Intune feed requires `/all/` path segment. EDL configuration updated to use mixed IP List + URL List types.

**Why the change from FQDN**:
- Microsoft's Azure Front Door migration (active since 2024) causes FQDN-based rules to break as IPs rotate
- FQDN rules depend on DNS — DNS failure = total connectivity loss
- TLS 1.3 Encrypted Client Hello will break SNI-based FQDN inspection
- EDL/ISDB feeds auto-update daily — zero maintenance vs manual FQDN list management

| Metric | v1 (FQDN) | v2 (EDL/ISDB) |
|--------|-----------|---------------|
| Microsoft service rules | 35+ FQDNs | 3 IP EDLs + 2 URL EDLs + ISDB objects |
| CRL/OCSP rules | 8 FQDNs | 8 FQDNs (unchanged) |
| App-specific rules | 5 FQDNs | 5 FQDNs (unchanged) |
| Total rules | 48+ | ~20 (incl. deny rules) |
| DNS dependency | All rules | CRL/OCSP + apps only |
| Maintenance | Manual FQDN updates | Auto-updated (zero) |
| Azure Front Door resilient | No | Yes |
| Outlook/Teams/OneDrive | Blocked (no FQDN) | Blocked (App-ID + ISDB deny at L7) |

---

## SECTION 1: Network Architecture

```
Traffic flow:

  Field Device / EC Server
          |
    [Palo Alto] ← INTERNAL firewall
          |         EDL feeds (saasedl.paloaltonetworks.com)
          |         App-ID for L7 application blocking
          |
    [FortiGate] ← PERIMETER firewall
          |         ISDB objects (FortiGuard auto-updated)
          |         Application Control for L7 blocking
          |
    [Internet] → Microsoft Services
```

Both layers use IP-based matching from independent feed sources:
- **Palo Alto (internal)**: EDL feeds from saasedl.paloaltonetworks.com (Palo Alto-maintained)
- **FortiGate (perimeter)**: ISDB from FortiGuard (Fortinet-maintained)

This provides defense-in-depth with zero DNS dependency for Microsoft traffic.

---

## SECTION 2: Server & Device Details

### 2.1 Entra Connect Servers

| Server | Site | IP Address | Purpose |
|--------|------|------------|---------|
| M7EC-EC1-CYB-01 | M7EC | TBD (SICE to provide) | Primary Entra Connect |
| PH-EC2-CYB-01 | PH | TBD (SICE to provide) | Standby Entra Connect |

### 2.2 Field Devices

These rules apply to all field devices in the `Field-Devices-Restricted-Network` group.

---

## SECTION 3: Palo Alto Configuration (Internal Firewall)

### 3.1 EDL Object Configuration

Palo Alto maintains pre-built, auto-updated Microsoft IP feeds via the EDL Hosting Service.

**PAN-OS path**: Objects > External Dynamic Lists > Add

**Note**: The M365 feeds use the `any` service area, which covers all M365 services including Exchange, SharePoint, and Teams IPs. This is necessary because authentication and Graph API share IP ranges with other M365 services — there is no `common`-only feed. Outlook, Teams, and OneDrive access is blocked via **App-ID deny rules** (Section 3.3) and **FortiGate ISDB deny rules** (Section 4.3) at L7 instead.

#### IPv4 EDLs (Type: IP List — used as destination address in security rules)

| EDL Name | Type | Feed URL | Refresh | Covers |
|----------|------|----------|---------|--------|
| MS365-Optimize-IPv4 | IP List | `https://saasedl.paloaltonetworks.com/feeds/m365/worldwide/any/optimize/ipv4` | Hourly | M365 Optimize — auth, Graph, core services (IPs) |
| MS365-Allow-IPv4 | IP List | `https://saasedl.paloaltonetworks.com/feeds/m365/worldwide/any/allow/ipv4` | Hourly | M365 Allow — management, health, notifications (IPs) |
| MS-Intune-IPv4 | IP List | `https://saasedl.paloaltonetworks.com/feeds/msintune/all/ipv4` | Hourly | Intune MDM, enrollment, device management (IPs) |

#### URL EDLs (Type: URL List — used in URL Filtering profiles, NOT as destination address)

| EDL Name | Type | Feed URL | Refresh | Covers |
|----------|------|----------|---------|--------|
| MS365-Default-URL | URL List | `https://saasedl.paloaltonetworks.com/feeds/m365/worldwide/any/default/url` | Hourly | M365 Default — Windows Update, delivery, telemetry (FQDNs only — no IPv4 feed exists) |
| MS-Defender-URL | URL List | `https://saasedl.paloaltonetworks.com/feeds/msdefender/all/any/url` | Hourly | Defender ATP, cloud protection, SmartScreen (FQDNs only — no IPv4 feed exists) |

**v2.2 IMPORTANT — IPv4 vs URL feed types**:
- M365 **Optimize** and **Allow** have IPv4 feeds → IP List EDL → used directly as destination address in security rules
- M365 **Default** has NO IPv4 feed (returns empty) → URL List EDL only → used in URL Filtering profile
- **Intune** has IPv4 feed but requires `/all/` in path: `msintune/all/ipv4` (NOT `msintune/ipv4`)
- **Defender** has NO IPv4 feed and is region-specific → URL List EDL only → used in URL Filtering profile
- Defender available regions: `eu`, `us`, `uk`, `dod` — select the region matching your tenant geography

**EDL Settings:**
- **IP List EDLs**: Type: IP List, Certificate Profile: Default (HTTPS), Refresh: Hourly
- **URL List EDLs**: Type: URL List, Certificate Profile: Default (HTTPS), Refresh: Hourly
  - URL List EDLs require a **URL Filtering profile** with a **Custom URL Category** referencing the EDL
  - Alternatively, FortiGate ISDB at the perimeter covers both Defender and Microsoft Update — PA URL EDLs provide defense-in-depth

**Note**: Create matching IPv6 EDLs with `/ipv6` suffix for Optimize and Allow feeds if IPv6 is in use. Default category only has `/url` (no IPv6 feed).

**Available EDL service areas** ([Palo Alto EDL Hosting Service docs](https://docs.paloaltonetworks.com/resources/edl-hosting-service)):
```
M365 feed path structure: m365/worldwide/{SERVICE}/{CATEGORY}/{TYPE}
Intune feed path: msintune/all/{TYPE}
Defender feed path: msdefender/{REGION}/any/{TYPE}

SERVICE values (M365):
  any        → ALL M365 services (auth, Exchange, SharePoint, Teams)
  exchange   → Exchange Online / Outlook only
  sharepoint → SharePoint Online / OneDrive only
  skype      → Microsoft Teams only

CATEGORY values (M365):
  optimize   → Latency-sensitive endpoints (has ipv4 + ipv6 + url)
  allow      → Required but less latency-sensitive (has ipv4 + ipv6 + url)
  default    → Default endpoints (has url ONLY — no ipv4/ipv6!)
  all        → All categories combined

TYPE values:
  ipv4       → IP address ranges in CIDR notation (for IP List EDLs)
  ipv6       → IPv6 address ranges (for IP List EDLs)
  url        → FQDNs / domain names (for URL List EDLs)

REGION values (Defender):
  eu, us, uk, dod — region-specific feeds (url type ONLY)

Note: There is NO "common" service area. Auth + Graph share IPs with
other M365 services, so "any" is required. M365 productivity app
blocking is enforced at L7 via App-ID (PA) and ISDB deny (FortiGate).
```

### 3.2 FQDN Objects (CRL/OCSP + App-Specific Only)

These endpoints have no Service Tag or EDL coverage — FQDN is the only option.

**PAN-OS path**: Objects > Address Groups

**CRL-OCSP-Group** (Port 80, HTTP):

| FQDN | Purpose |
|------|---------|
| crl.microsoft.com | Microsoft CRL |
| mscrl.microsoft.com | Microsoft CRL |
| crl3.digicert.com | DigiCert CRL |
| crl4.digicert.com | DigiCert CRL |
| ocsp.digicert.com | DigiCert OCSP |
| ocsp.msocsp.com | Microsoft OCSP |
| www.microsoft.com | CRL distribution |
| ctldl.windowsupdate.com | Certificate Trust List |

**Apps-FQDN-Group** (Port 443, HTTPS — Field Devices only):

| FQDN | Purpose |
|------|---------|
| *.sharefile.com | ShareFile service |
| *.sf-api.com | ShareFile API |
| *.citrixdata.com | ShareFile storage |
| *.bastion.azure.com | Azure Bastion |
| *.portal.azure.com | Azure Portal |

**ServiceBus-FQDN** (Ports 443 + 5671 — Entra Connect only):

| FQDN | Port | Purpose |
|------|------|---------|
| *.servicebus.windows.net | 443, 5671 | Password writeback (AMQP + HTTPS fallback) |

### 3.3 Security Policy Rules — Block M365 Productivity Apps (App-ID)

**These deny rules MUST be placed BEFORE the allow rules.**

Palo Alto App-ID identifies specific applications at L7. This is the second line of defense — even if an IP overlaps between auth and a productivity service, App-ID blocks the specific application.

**PAN-OS path**: Policies > Security > Add

| Ord | Rule Name | Source | Application (App-ID) | Action | Log |
|-----|-----------|--------|---------------------|--------|-----|
| 1 | Block-M365-Productivity | EC-Servers, Field-Devices | ms-teams, ms-teams-audio-video, ms-onedrive, sharepoint-online, outlook-web-online, ms-office365-base | Deny | Yes |

**Valid App-ID names** (verified via [Applipedia](https://applipedia.paloaltonetworks.com/)):
- `outlook-web-online` — Outlook Web Access (NOT `ms-outlook-365`)
- `sharepoint-online` — SharePoint Online
- `ms-onedrive` — OneDrive for Business
- `ms-teams` — Teams base application
- `ms-teams-audio-video` — Teams audio + video (NOT separate `ms-teams-audio` / `ms-teams-video`)
- `ms-office365-base` — Base M365 container app

**SSL Decryption requirement for App-ID**:
App-ID for M365 sub-applications requires SSL decryption to distinguish individual services. Without decryption, the firewall can only identify base `ms-office365-base` traffic. Since Microsoft services use certificate pinning (Section 3.6 bypasses SSL inspection), App-ID effectiveness is limited for M365 traffic.

**This means the primary M365 blocking layers are**:
1. **FortiGate ISDB deny rules** (perimeter, Section 4.3) — most effective, no decryption needed
2. **Conditional Access policies** (Entra ID, Section 6) — strongest control at identity level
3. **Palo Alto App-ID** (internal) — best-effort without decryption, catches unencrypted patterns

### 3.4 Security Policy Rules — Entra Connect Servers

| Ord | Rule Name | Source | Destination | Service/Port | Action | Log |
|-----|-----------|--------|-------------|-------------|--------|-----|
| 2 | Allow-EC-MS-Auth | EC-Servers | MS365-Optimize-IPv4 | HTTPS (443) | Allow | Yes |
| 3 | Allow-EC-MS-Services | EC-Servers | MS365-Allow-IPv4 | HTTPS (443) | Allow | Yes |
| 4 | Allow-EC-MS-Updates | EC-Servers | Any + URL Filter: MS365-Default-URL | HTTPS (443) | Allow | Yes |
| 5 | Allow-EC-CRL-OCSP | EC-Servers | CRL-OCSP-Group | HTTP (80) | Allow | Yes |
| 6 | Allow-EC-ServiceBus | EC-Servers | ServiceBus-FQDN | TCP 443, 5671 | Allow | Yes |
| 7 | Allow-EC-AD-Internal | EC-Servers | DomainControllers | AD Ports* | Allow | Yes |
| 8 | Block-EC-All | EC-Servers | Any | Any | Deny | Yes |

**Note on Rule 4**: MS365-Default-URL is a URL List EDL (not IP List). It must be used via a URL Filtering profile with a Custom URL Category. The destination is set to `Any` and the URL Filtering profile restricts to matching URLs. Alternatively, FortiGate ISDB covers Microsoft Update at the perimeter — this PA rule provides defense-in-depth.

*AD Ports: TCP/UDP 53, TCP/UDP 88, TCP 135, TCP/UDP 389, TCP 636, TCP 445, TCP 3268-3269, TCP 49152-65535

### 3.5 Security Policy Rules — Field Devices

| Ord | Rule Name | Source | Destination | Service/Port | Action | Log |
|-----|-----------|--------|-------------|-------------|--------|-----|
| 2 | Allow-FD-MS-Auth | Field-Devices | MS365-Optimize-IPv4 | HTTPS (443) | Allow | Yes |
| 3 | Allow-FD-MS-Intune | Field-Devices | MS-Intune-IPv4 | HTTPS (443) | Allow | Yes |
| 4 | Allow-FD-MS-Defender | Field-Devices | Any + URL Filter: MS-Defender-URL | HTTPS (443) | Allow | Yes |
| 5 | Allow-FD-MS-Services | Field-Devices | MS365-Allow-IPv4 | HTTPS (443) | Allow | Yes |
| 6 | Allow-FD-MS-Updates | Field-Devices | Any + URL Filter: MS365-Default-URL | HTTPS (443) | Allow | Yes |
| 7 | Allow-FD-CRL-OCSP | Field-Devices | CRL-OCSP-Group | HTTP (80) | Allow | Yes |
| 8 | Allow-FD-Apps | Field-Devices | Apps-FQDN-Group | HTTPS (443) | Allow | Yes |
| 9 | Block-FD-All | Field-Devices | Any | Any | Deny | Yes |

**Note on Rules 4 & 6**: MS-Defender-URL and MS365-Default-URL are URL List EDLs (not IP List). They must be used via a URL Filtering profile with Custom URL Categories. The destination is set to `Any` and the URL Filtering profile restricts to matching URLs. Alternatively, FortiGate ISDB covers both Defender and Microsoft Update at the perimeter — these PA rules provide defense-in-depth.

### 3.6 SSL Inspection Bypass (Decryption Policy)

**PAN-OS path**: Policies > Decryption > Add

| Ord | Rule Name | Source | Destination | Action | Position |
|-----|-----------|--------|-------------|--------|----------|
| 1 | No-Decrypt-MS-Services | EC-Servers, Field-Devices | MS-Intune-IPv4, MS365-Optimize-IPv4, MS365-Allow-IPv4 | No Decrypt | ABOVE any "Decrypt All" |

**Note**: MS-Defender-URL and MS365-Default-URL are URL List EDLs — SSL decryption bypass for these is handled by URL category exception in the decryption profile, or relies on the FortiGate perimeter ISDB rules which use certificate-inspection (not deep-inspection).

**Why**: Microsoft services use certificate pinning. SSL/MITM inspection replaces Microsoft certificates with the proxy cert, causing:
- Intune enrollment failures
- Defender cloud protection failures
- Authentication token rejection
- Graph API errors

---

## SECTION 4: FortiGate Configuration (Perimeter Firewall)

### 4.1 ISDB Objects (Built-In — No Configuration Required)

FortiGate's Internet Service Database contains pre-built, auto-updated Microsoft service definitions. These are maintained by FortiGuard and available by default.

| ISDB Object | Covers | Used For |
|-------------|--------|----------|
| Microsoft-Office365 | Auth, Graph, Entra ID, M365 core | Allow (shared infrastructure) |
| Microsoft-Office365.Exchange | Exchange Online / Outlook | **DENY** |
| Microsoft-Office365.SharePoint | SharePoint Online / OneDrive | **DENY** |
| Microsoft-Teams | Microsoft Teams | **DENY** |
| Microsoft-Intune | Intune MDM, enrollment, device reg | Allow |
| Microsoft-Defender | Defender ATP, cloud protection, SmartScreen | Allow |
| Microsoft-Microsoft.Update | Windows Update, delivery optimization | Allow |
| Microsoft-Azure | Azure management, portal, blob storage | Allow |
| Microsoft-Azure.Bastion | Azure Bastion service | Allow |

**Verify ISDB availability** (FortiOS CLI):
```
diagnose internet-service match Microsoft-Office365
diagnose internet-service match Microsoft-Office365.Exchange
diagnose internet-service match Microsoft-Office365.SharePoint
diagnose internet-service match Microsoft-Teams
diagnose internet-service match Microsoft-Intune
diagnose internet-service match Microsoft-Defender
diagnose internet-service match Microsoft-Microsoft.Update
diagnose internet-service match Microsoft-Azure
```

### 4.2 FQDN Address Objects (CRL/OCSP + App-Specific Only)

```
config firewall address
    edit "CRL-crl.microsoft.com"
        set type fqdn
        set fqdn "crl.microsoft.com"
    next
    edit "CRL-mscrl.microsoft.com"
        set type fqdn
        set fqdn "mscrl.microsoft.com"
    next
    edit "CRL-crl3.digicert.com"
        set type fqdn
        set fqdn "crl3.digicert.com"
    next
    edit "CRL-crl4.digicert.com"
        set type fqdn
        set fqdn "crl4.digicert.com"
    next
    edit "CRL-ocsp.digicert.com"
        set type fqdn
        set fqdn "ocsp.digicert.com"
    next
    edit "CRL-ocsp.msocsp.com"
        set type fqdn
        set fqdn "ocsp.msocsp.com"
    next
    edit "CRL-ctldl.windowsupdate.com"
        set type fqdn
        set fqdn "ctldl.windowsupdate.com"
    next
    edit "CRL-www.microsoft.com"
        set type fqdn
        set fqdn "www.microsoft.com"
    next
    edit "ShareFile-wildcard"
        set type fqdn
        set fqdn "*.sharefile.com"
    next
    edit "ShareFile-API"
        set type fqdn
        set fqdn "*.sf-api.com"
    next
    edit "ShareFile-Storage"
        set type fqdn
        set fqdn "*.citrixdata.com"
    next
    edit "Azure-ServiceBus"
        set type fqdn
        set fqdn "*.servicebus.windows.net"
    next
end

config firewall addrgrp
    edit "CRL-OCSP-Group"
        set member "CRL-crl.microsoft.com" "CRL-mscrl.microsoft.com" \
            "CRL-crl3.digicert.com" "CRL-crl4.digicert.com" \
            "CRL-ocsp.digicert.com" "CRL-ocsp.msocsp.com" \
            "CRL-ctldl.windowsupdate.com" "CRL-www.microsoft.com"
    next
    edit "ShareFile-Group"
        set member "ShareFile-wildcard" "ShareFile-API" "ShareFile-Storage"
    next
end

config firewall service custom
    edit "AMQP-5671"
        set tcp-portrange 5671
    next
end
```

### 4.3 Firewall Policies — Block M365 Productivity Apps (ISDB Deny)

**These deny rules MUST be placed BEFORE all allow rules.**

FortiGate has granular ISDB objects that can explicitly block Outlook, Teams, and OneDrive at the perimeter.

```
# DENY RULES — Block M365 productivity apps for all NWR devices
# These MUST be first in the policy order

config firewall policy
    edit 0
        set name "Block-M365-Exchange"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers" "Field-Devices"
        set internet-service enable
        set internet-service-name "Microsoft-Office365.Exchange"
        set action deny
        set logtraffic all
        set comments "NWR v2.1: Block Outlook/Exchange for OT devices"
    next
end

config firewall policy
    edit 0
        set name "Block-M365-SharePoint"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers" "Field-Devices"
        set internet-service enable
        set internet-service-name "Microsoft-Office365.SharePoint"
        set action deny
        set logtraffic all
        set comments "NWR v2.1: Block OneDrive/SharePoint for OT devices"
    next
end

config firewall policy
    edit 0
        set name "Block-M365-Teams"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers" "Field-Devices"
        set internet-service enable
        set internet-service-name "Microsoft-Teams"
        set action deny
        set logtraffic all
        set comments "NWR v2.1: Block Teams for OT devices"
    next
end
```

### 4.4 Firewall Policies — Entra Connect Servers (Allow)

```
# ALLOW RULES — After deny rules

# Policy: Microsoft Auth & Core Services
config firewall policy
    edit 0
        set name "Allow-EC-MS-Auth-Core"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers"
        set internet-service enable
        set internet-service-name "Microsoft-Office365"
        set action accept
        set ssl-ssh-profile "certificate-inspection"
        set logtraffic all
        set comments "NWR v2.1: Entra ID auth, Graph API (Exchange/SPO/Teams blocked above)"
    next
end

# Policy: Microsoft Azure (Management APIs)
config firewall policy
    edit 0
        set name "Allow-EC-MS-Azure"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers"
        set internet-service enable
        set internet-service-name "Microsoft-Azure"
        set action accept
        set ssl-ssh-profile "certificate-inspection"
        set logtraffic all
        set comments "NWR v2.1: Azure management, blob storage"
    next
end

# Policy: Windows Update
config firewall policy
    edit 0
        set name "Allow-EC-MS-Updates"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers"
        set internet-service enable
        set internet-service-name "Microsoft-Microsoft.Update"
        set action accept
        set ssl-ssh-profile "certificate-inspection"
        set logtraffic all
        set comments "NWR v2.1: Windows Update, security patches"
    next
end

# Policy: CRL/OCSP (FQDN — no ISDB exists)
config firewall policy
    edit 0
        set name "Allow-EC-CRL-OCSP"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers"
        set dstaddr "CRL-OCSP-Group"
        set action accept
        set service "HTTP"
        set logtraffic all
        set comments "NWR v2.1: Certificate validation - Port 80 HTTP"
    next
end

# Policy: Service Bus (Password Writeback)
config firewall policy
    edit 0
        set name "Allow-EC-ServiceBus"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers"
        set dstaddr "Azure-ServiceBus"
        set action accept
        set service "HTTPS" "AMQP-5671"
        set logtraffic all
        set comments "NWR v2.1: Entra Connect password writeback"
    next
end

# Policy: AD Internal Communication
config firewall policy
    edit 0
        set name "Allow-EC-AD-Internal"
        set srcintf "internal-zone"
        set dstintf "dc-zone"
        set srcaddr "EC-Servers"
        set dstaddr "DomainControllers"
        set action accept
        set service "DNS" "KERBEROS" "LDAP" "LDAPS" "SMB" "DCE-RPC"
        set logtraffic all
        set comments "NWR v2.1: AD sync - DNS, Kerberos, LDAP, RPC"
    next
end

# Policy: Default Deny
config firewall policy
    edit 0
        set name "Deny-EC-All"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "EC-Servers"
        set dstaddr "all"
        set action deny
        set logtraffic all
        set comments "NWR v2.1: Default deny"
    next
end
```

### 4.5 Firewall Policies — Field Devices (Allow)

```
# ALLOW RULES — After deny rules (Section 4.3)

# Policy: Microsoft Auth & Core Services
config firewall policy
    edit 0
        set name "Allow-FD-MS-Auth-Core"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "Field-Devices"
        set internet-service enable
        set internet-service-name "Microsoft-Office365"
        set action accept
        set ssl-ssh-profile "certificate-inspection"
        set logtraffic all
        set comments "NWR v2.1: Entra ID auth, Graph API (Exchange/SPO/Teams blocked above)"
    next
end

# Policy: Intune Management
config firewall policy
    edit 0
        set name "Allow-FD-MS-Intune"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "Field-Devices"
        set internet-service enable
        set internet-service-name "Microsoft-Intune"
        set action accept
        set ssl-ssh-profile "certificate-inspection"
        set logtraffic all
        set comments "NWR v2.1: Intune MDM, enrollment, device management"
    next
end

# Policy: Defender
config firewall policy
    edit 0
        set name "Allow-FD-MS-Defender"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "Field-Devices"
        set internet-service enable
        set internet-service-name "Microsoft-Defender"
        set action accept
        set ssl-ssh-profile "certificate-inspection"
        set logtraffic all
        set comments "NWR v2.1: Defender cloud protection, definitions"
    next
end

# Policy: Windows Update
config firewall policy
    edit 0
        set name "Allow-FD-MS-Updates"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "Field-Devices"
        set internet-service enable
        set internet-service-name "Microsoft-Microsoft.Update"
        set action accept
        set ssl-ssh-profile "certificate-inspection"
        set logtraffic all
        set comments "NWR v2.1: Windows Update, delivery optimization"
    next
end

# Policy: Azure Services (Bastion, Portal)
config firewall policy
    edit 0
        set name "Allow-FD-MS-Azure"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "Field-Devices"
        set internet-service enable
        set internet-service-name "Microsoft-Azure" "Microsoft-Azure.Bastion"
        set action accept
        set ssl-ssh-profile "certificate-inspection"
        set logtraffic all
        set comments "NWR v2.1: Azure Portal, Bastion"
    next
end

# Policy: CRL/OCSP (FQDN — no ISDB exists)
config firewall policy
    edit 0
        set name "Allow-FD-CRL-OCSP"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "Field-Devices"
        set dstaddr "CRL-OCSP-Group"
        set action accept
        set service "HTTP"
        set logtraffic all
        set comments "NWR v2.1: Certificate validation - Port 80 HTTP"
    next
end

# Policy: ShareFile (FQDN — not in ISDB)
config firewall policy
    edit 0
        set name "Allow-FD-ShareFile"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "Field-Devices"
        set dstaddr "ShareFile-Group"
        set action accept
        set service "HTTPS"
        set logtraffic all
        set comments "NWR v2.1: ShareFile access for field devices"
    next
end

# Policy: Default Deny
config firewall policy
    edit 0
        set name "Deny-FD-All"
        set srcintf "internal-zone"
        set dstintf "wan-zone"
        set srcaddr "Field-Devices"
        set dstaddr "all"
        set action deny
        set logtraffic all
        set comments "NWR v2.1: Default deny"
    next
end
```

### 4.6 SSL Inspection Configuration

Use `certificate-inspection` (not `deep-inspection`) for all Microsoft ISDB-based policies. This is already set in the policies above.

**Why**: Microsoft services use certificate pinning. Deep inspection (MITM) replaces Microsoft certificates with the FortiGate's CA cert, breaking:
- Intune MDM enrollment and sync
- Defender cloud protection
- Entra ID authentication tokens
- Graph API calls

---

## SECTION 5: Internal Rules — Active Directory Communication

**Applies to**: Entra Connect servers only (both Palo Alto and FortiGate)

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 1 | Domain Controllers | 53 | TCP/UDP | DNS | **CRITICAL** |
| 2 | Domain Controllers | 88 | TCP/UDP | Kerberos | **CRITICAL** |
| 3 | Domain Controllers | 135 | TCP | RPC Endpoint Mapper | **CRITICAL** |
| 4 | Domain Controllers | 389 | TCP/UDP | LDAP | **CRITICAL** |
| 5 | Domain Controllers | 636 | TCP | LDAPS | Required |
| 6 | Domain Controllers | 445 | TCP | SMB | Required |
| 7 | Domain Controllers | 3268 | TCP | Global Catalog | Required |
| 8 | Domain Controllers | 3269 | TCP | Global Catalog SSL | Required |
| 9 | Domain Controllers | 49152-65535 | TCP | RPC Dynamic Ports | **CRITICAL** |

---

## SECTION 6: M365 Productivity App Blocking — Defense in Depth

Three independent layers ensure Outlook, Teams, and OneDrive are blocked:

### Layer 1: FortiGate ISDB Deny Rules (Perimeter) — PRIMARY CONTROL
FortiGate ISDB deny rules block at the IP level using FortiGuard-maintained service definitions. **No SSL decryption needed.** This is the most effective network-level blocking mechanism.
- Blocks: `Microsoft-Office365.Exchange`, `Microsoft-Office365.SharePoint`, `Microsoft-Teams` (Section 4.3)

### Layer 2: Palo Alto App-ID (Internal) — BEST-EFFORT
App-ID deny rules block at L7 by identifying application patterns. **Limitation**: Full M365 sub-application identification requires SSL decryption, which conflicts with the SSL bypass for Microsoft services (certificate pinning). Without decryption, App-ID catches base `ms-office365-base` patterns but may not distinguish all individual M365 apps.
- Blocks: `ms-teams`, `ms-teams-audio-video`, `ms-onedrive`, `sharepoint-online`, `outlook-web-online` (Section 3.3)

### Layer 3: Identity Level — Conditional Access (Recommended Addition)
Configure in Entra ID for token-level enforcement:

```
Entra ID > Security > Conditional Access > New Policy

Name: "Block M365 Apps - NWR Devices"
Assignments:
  Users/Groups: All users
  Target resources:
    Cloud apps — Include:
      - Office 365 Exchange Online
      - Office 365 SharePoint Online (includes OneDrive)
      - Microsoft Teams
  Conditions:
    Filter for devices: device.displayName -startsWith "NWR-" OR
                        device.enrollmentProfileName -eq "Field-Devices-OT"
Grant: Block access
Enable policy: On
```

This is the strongest control — even if network-level access exists, Entra ID refuses the authentication token.

---

## SECTION 7: FortiGate Policy Order Summary (Perimeter)

**Critical: Policy order determines behavior. Deny rules MUST come first.**

| Order | Policy Name | Type | Action |
|-------|------------|------|--------|
| 1 | Block-M365-Exchange | ISDB deny | Deny |
| 2 | Block-M365-SharePoint | ISDB deny | Deny |
| 3 | Block-M365-Teams | ISDB deny | Deny |
| 4 | Allow-EC-MS-Auth-Core | ISDB allow | Allow |
| 5 | Allow-EC-MS-Azure | ISDB allow | Allow |
| 6 | Allow-EC-MS-Updates | ISDB allow | Allow |
| 7 | Allow-EC-CRL-OCSP | FQDN allow | Allow |
| 8 | Allow-EC-ServiceBus | FQDN allow | Allow |
| 9 | Allow-EC-AD-Internal | IP allow | Allow |
| 10 | Allow-FD-MS-Auth-Core | ISDB allow | Allow |
| 11 | Allow-FD-MS-Intune | ISDB allow | Allow |
| 12 | Allow-FD-MS-Defender | ISDB allow | Allow |
| 13 | Allow-FD-MS-Updates | ISDB allow | Allow |
| 14 | Allow-FD-MS-Azure | ISDB allow | Allow |
| 15 | Allow-FD-CRL-OCSP | FQDN allow | Allow |
| 16 | Allow-FD-ShareFile | FQDN allow | Allow |
| 17 | Deny-EC-All | Default deny | Deny |
| 18 | Deny-FD-All | Default deny | Deny |

## SECTION 8: Palo Alto Policy Order Summary (Internal)

| Order | Policy Name | Type | Action |
|-------|------------|------|--------|
| 1 | Block-M365-Productivity | App-ID deny | Deny |
| 2 | Allow-EC-MS-Auth | EDL (IP List) allow | Allow |
| 3 | Allow-EC-MS-Services | EDL (IP List) allow | Allow |
| 4 | Allow-EC-MS-Updates | EDL (URL List) + URL Filter | Allow |
| 5 | Allow-EC-CRL-OCSP | FQDN allow | Allow |
| 6 | Allow-EC-ServiceBus | FQDN allow | Allow |
| 7 | Allow-EC-AD-Internal | IP allow | Allow |
| 8 | Block-EC-All | Default deny | Deny |
| 9 | Allow-FD-MS-Auth | EDL (IP List) allow | Allow |
| 10 | Allow-FD-MS-Intune | EDL (IP List) allow | Allow |
| 11 | Allow-FD-MS-Defender | EDL (URL List) + URL Filter | Allow |
| 12 | Allow-FD-MS-Services | EDL (IP List) allow | Allow |
| 13 | Allow-FD-MS-Updates | EDL (URL List) + URL Filter | Allow |
| 14 | Allow-FD-CRL-OCSP | FQDN allow | Allow |
| 15 | Allow-FD-Apps | FQDN allow | Allow |
| 16 | Block-FD-All | Default deny | Deny |

---

## SECTION 9: Verification & Testing

### 9.1 FortiGate ISDB Verification (Perimeter)

```
# Verify ISDB objects are available and populated
diagnose internet-service match Microsoft-Office365
diagnose internet-service match Microsoft-Office365.Exchange
diagnose internet-service match Microsoft-Office365.SharePoint
diagnose internet-service match Microsoft-Teams
diagnose internet-service match Microsoft-Intune
diagnose internet-service match Microsoft-Defender
diagnose internet-service match Microsoft-Microsoft.Update
diagnose internet-service match Microsoft-Azure

# Check FortiGuard update status
diagnose autoupdate status
diagnose autoupdate versions | grep -i internet-service

# Verify deny rules are matching traffic
diagnose firewall iprope lookup <exchange-IP> 443
get firewall policy <deny-rule-id>
```

### 9.2 Palo Alto EDL Verification (Internal)

```
# Verify EDL objects are populated (PAN-OS CLI)
# IP List EDLs (should show IP addresses in CIDR notation)
request system external-list show name MS365-Optimize-IPv4
request system external-list show name MS365-Allow-IPv4
request system external-list show name MS-Intune-IPv4

# URL List EDLs (should show FQDNs/domains)
request system external-list show name MS365-Default-URL
request system external-list show name MS-Defender-URL

# Check last refresh time
show system external-list

# Verify App-ID deny rule is matching
show rule-hit-count vsys vsys1 security rules Block-M365-Productivity
```

### 9.3 Entra Connect Server Connectivity Test

```powershell
# Run on Entra Connect servers (M7EC-EC1-CYB-01, PH-EC2-CYB-01)
# Requires: PowerShell 5.1+, Run as Administrator

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "=== ENTRA CONNECT FIREWALL VERIFICATION (v2.1) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Cyan
Write-Host ""

$Endpoints = @(
    # P1: Authentication (EDL: MS365-Optimize-IPv4 / ISDB: Microsoft-Office365)
    @{ Name = "Entra ID Login"; Host = "login.microsoftonline.com"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "MS Login"; Host = "login.microsoft.com"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "Graph API"; Host = "graph.microsoft.com"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "Azure AD Graph"; Host = "graph.windows.net"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "Admin Service"; Host = "adminwebservice.microsoftonline.com"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "Provisioning"; Host = "provisioningapi.microsoftonline.com"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "Azure Management"; Host = "management.azure.com"; Port = 443; Priority = "P1"; Expect = "PASS" },

    # P1: CRL/OCSP (FQDN rules — no EDL/ISDB coverage)
    @{ Name = "MS CRL"; Host = "crl.microsoft.com"; Port = 80; Priority = "P1"; Expect = "PASS" },
    @{ Name = "DigiCert CRL3"; Host = "crl3.digicert.com"; Port = 80; Priority = "P1"; Expect = "PASS" },
    @{ Name = "DigiCert OCSP"; Host = "ocsp.digicert.com"; Port = 80; Priority = "P1"; Expect = "PASS" },
    @{ Name = "MS OCSP"; Host = "ocsp.msocsp.com"; Port = 80; Priority = "P1"; Expect = "PASS" },
    @{ Name = "CTL Download"; Host = "ctldl.windowsupdate.com"; Port = 80; Priority = "P1"; Expect = "PASS" },

    # P2: Entra Connect Specific
    @{ Name = "Hybrid Health"; Host = "s1.adhybridhealth.azure.com"; Port = 443; Priority = "P2"; Expect = "PASS" },
    @{ Name = "Policy Key"; Host = "policykeyservice.dc.ad.msft.net"; Port = 443; Priority = "P2"; Expect = "PASS" },

    # P3: Windows Update
    @{ Name = "Windows Update"; Host = "dl.delivery.mp.microsoft.com"; Port = 443; Priority = "P3"; Expect = "PASS" },

    # BLOCKED: M365 productivity apps (should FAIL)
    @{ Name = "Outlook Web"; Host = "outlook.office365.com"; Port = 443; Priority = "DENY"; Expect = "FAIL" },
    @{ Name = "Teams"; Host = "teams.microsoft.com"; Port = 443; Priority = "DENY"; Expect = "FAIL" },
    @{ Name = "OneDrive"; Host = "onedrive.live.com"; Port = 443; Priority = "DENY"; Expect = "FAIL" }
)

$results = @()
$issues = 0

foreach ($EP in $Endpoints) {
    Write-Host "  [$($EP.Priority)] $($EP.Name.PadRight(20)) $($EP.Host):$($EP.Port) " -NoNewline
    $Result = Test-NetConnection -ComputerName $EP.Host -Port $EP.Port -WarningAction SilentlyContinue
    $reached = $Result.TcpTestSucceeded

    if ($EP.Expect -eq "PASS" -and $reached) {
        Write-Host "PASS" -ForegroundColor Green; $status = "PASS"
    } elseif ($EP.Expect -eq "FAIL" -and -not $reached) {
        Write-Host "BLOCKED (expected)" -ForegroundColor Green; $status = "BLOCKED-OK"
    } elseif ($EP.Expect -eq "PASS" -and -not $reached) {
        Write-Host "FAIL - should be allowed!" -ForegroundColor Red; $status = "FAIL"; $issues++
    } elseif ($EP.Expect -eq "FAIL" -and $reached) {
        Write-Host "REACHABLE - should be blocked!" -ForegroundColor Red; $status = "LEAK"; $issues++
    }

    $results += [PSCustomObject]@{
        Priority = $EP.Priority; Name = $EP.Name
        Host = $EP.Host; Port = $EP.Port; Status = $status; Expected = $EP.Expect
    }
}

Write-Host ""
if ($issues -eq 0) {
    Write-Host "All checks passed — allowed services reachable, blocked services denied" -ForegroundColor Green
} else {
    Write-Host "$issues ISSUES FOUND:" -ForegroundColor Red
    $results | Where-Object { $_.Status -in "FAIL","LEAK" } | Format-Table Priority, Name, Host, Status -AutoSize
}

$results | Export-Csv -Path "$env:TEMP\nwr_ec_connectivity_v2.1.csv" -NoTypeInformation
Write-Host "Results exported to: $env:TEMP\nwr_ec_connectivity_v2.1.csv"
```

### 9.4 Field Device Connectivity Test

```powershell
# Run on managed field devices
# Requires: PowerShell 5.1+, Run as Administrator

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "=== FIELD DEVICE FIREWALL VERIFICATION (v2.1) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Cyan
Write-Host ""

$Endpoints = @(
    # P1: Authentication (EDL: MS365-Optimize-IPv4 / ISDB: Microsoft-Office365)
    @{ Name = "Entra ID Login"; Host = "login.microsoftonline.com"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "MS Login"; Host = "login.microsoft.com"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "Device Login"; Host = "device.login.microsoftonline.com"; Port = 443; Priority = "P1"; Expect = "PASS" },
    @{ Name = "Graph API"; Host = "graph.microsoft.com"; Port = 443; Priority = "P1"; Expect = "PASS" },

    # P1: CRL/OCSP (FQDN rules)
    @{ Name = "MS CRL"; Host = "crl.microsoft.com"; Port = 80; Priority = "P1"; Expect = "PASS" },
    @{ Name = "DigiCert CRL3"; Host = "crl3.digicert.com"; Port = 80; Priority = "P1"; Expect = "PASS" },
    @{ Name = "DigiCert OCSP"; Host = "ocsp.digicert.com"; Port = 80; Priority = "P1"; Expect = "PASS" },
    @{ Name = "MS OCSP"; Host = "ocsp.msocsp.com"; Port = 80; Priority = "P1"; Expect = "PASS" },

    # P2: Intune (EDL: MS-Intune / ISDB: Microsoft-Intune)
    @{ Name = "Intune Manage"; Host = "manage.microsoft.com"; Port = 443; Priority = "P2"; Expect = "PASS" },
    @{ Name = "Intune Enroll"; Host = "enrollment.manage.microsoft.com"; Port = 443; Priority = "P2"; Expect = "PASS" },
    @{ Name = "Enterprise Reg"; Host = "enterpriseregistration.windows.net"; Port = 443; Priority = "P2"; Expect = "PASS" },

    # P3: Defender (EDL: MS-Defender / ISDB: Microsoft-Defender)
    @{ Name = "Defender Defs"; Host = "definitionupdates.microsoft.com"; Port = 443; Priority = "P3"; Expect = "PASS" },
    @{ Name = "SmartScreen"; Host = "smartscreen-prod.microsoft.com"; Port = 443; Priority = "P3"; Expect = "PASS" },

    # P4: Windows Update (EDL: MS365-Default-URL / ISDB: Microsoft-Microsoft.Update)
    @{ Name = "Windows Update"; Host = "dl.delivery.mp.microsoft.com"; Port = 443; Priority = "P4"; Expect = "PASS" },

    # P5: Applications (FQDN rules)
    @{ Name = "Azure Portal"; Host = "portal.azure.com"; Port = 443; Priority = "P5"; Expect = "PASS" },
    @{ Name = "ShareFile"; Host = "www.sharefile.com"; Port = 443; Priority = "P5"; Expect = "PASS" },

    # BLOCKED: M365 productivity apps (should FAIL)
    @{ Name = "Outlook Web"; Host = "outlook.office365.com"; Port = 443; Priority = "DENY"; Expect = "FAIL" },
    @{ Name = "Teams"; Host = "teams.microsoft.com"; Port = 443; Priority = "DENY"; Expect = "FAIL" },
    @{ Name = "OneDrive"; Host = "onedrive.live.com"; Port = 443; Priority = "DENY"; Expect = "FAIL" },
    @{ Name = "SharePoint"; Host = "contoso.sharepoint.com"; Port = 443; Priority = "DENY"; Expect = "FAIL" }
)

$results = @()
$issues = 0

foreach ($EP in $Endpoints) {
    Write-Host "  [$($EP.Priority)] $($EP.Name.PadRight(20)) $($EP.Host):$($EP.Port) " -NoNewline
    $Result = Test-NetConnection -ComputerName $EP.Host -Port $EP.Port -WarningAction SilentlyContinue
    $reached = $Result.TcpTestSucceeded

    if ($EP.Expect -eq "PASS" -and $reached) {
        Write-Host "PASS" -ForegroundColor Green; $status = "PASS"
    } elseif ($EP.Expect -eq "FAIL" -and -not $reached) {
        Write-Host "BLOCKED (expected)" -ForegroundColor Green; $status = "BLOCKED-OK"
    } elseif ($EP.Expect -eq "PASS" -and -not $reached) {
        Write-Host "FAIL - should be allowed!" -ForegroundColor Red; $status = "FAIL"; $issues++
    } elseif ($EP.Expect -eq "FAIL" -and $reached) {
        Write-Host "REACHABLE - should be blocked!" -ForegroundColor Red; $status = "LEAK"; $issues++
    }

    $results += [PSCustomObject]@{
        Priority = $EP.Priority; Name = $EP.Name
        Host = $EP.Host; Port = $EP.Port; Status = $status; Expected = $EP.Expect
    }
}

Write-Host ""
if ($issues -eq 0) {
    Write-Host "All checks passed — allowed services reachable, blocked services denied" -ForegroundColor Green
} else {
    Write-Host "$issues ISSUES FOUND:" -ForegroundColor Red
    $results | Where-Object { $_.Status -in "FAIL","LEAK" } | Format-Table Priority, Name, Host, Status -AutoSize
}

$results | Export-Csv -Path "$env:TEMP\nwr_fd_connectivity_v2.1.csv" -NoTypeInformation
Write-Host "Results exported to: $env:TEMP\nwr_fd_connectivity_v2.1.csv"
```

---

## SECTION 10: Important Notes

### 10.1 SSL/TLS Inspection

**Use `certificate-inspection` (NOT `deep-inspection`)** for all Microsoft service policies on both firewalls:
- **FortiGate (perimeter)**: `ssl-ssh-profile "certificate-inspection"` on each ISDB policy
- **Palo Alto (internal)**: Decryption policy with "No Decrypt" action (Section 3.6)

### 10.2 Port 80 Is Required

CRL/OCSP uses HTTP (port 80), not HTTPS. This is the #1 most commonly missed requirement in restrictive environments. Blocking port 80 causes TLS handshake timeouts as clients cannot validate Microsoft certificates.

### 10.3 Feed Update Monitoring

| Platform | Role | Feed | Update Frequency | Monitor Command |
|----------|------|------|-----------------|-----------------|
| FortiGate | Perimeter | ISDB | Automatic (FortiGuard) | `diagnose autoupdate versions` |
| Palo Alto | Internal | EDL | Daily (hourly refresh) | `show system external-list` |

### 10.4 Azure Front Door Coverage

The EDL/ISDB approach automatically handles Microsoft's ongoing Azure Front Door migration. As Microsoft adds new IPs behind Azure Front Door, both FortiGate ISDB objects and Palo Alto EDL feeds are updated automatically. No manual intervention required.

### 10.5 Proxy Requirements

If a proxy server exists between devices and the firewalls:
- **Unauthenticated proxy access required** for Intune endpoints
- **Byte Range request support required** for Delivery Optimization

### 10.6 DNS Requirements

Entra Connect servers require DNS resolution for:
- On-premises Active Directory (internal DNS)
- Microsoft cloud endpoints (external DNS via corporate resolver)
- CRL/OCSP endpoints (FQDN rules require DNS — this is the only DNS-dependent path)

---

## SECTION 11: Approval & Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Requestor | Principal Endpoint Engineer | Feb 2025 | __________ |
| SICE Network Team | __________ | __________ | __________ |
| Cyber Security | __________ | __________ | __________ |
| Change Manager | __________ | __________ | __________ |

---

## References

### Microsoft Official
- [Microsoft Entra Connect Ports & Protocols](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/reference-connect-ports)
- [Microsoft Intune Network Endpoints](https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints)
- [Microsoft 365 URLs and IP Ranges](https://learn.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges)
- [Defender for Endpoint Network Requirements](https://learn.microsoft.com/en-us/defender-endpoint/configure-proxy-internet)
- [Azure Service Tags Overview](https://learn.microsoft.com/en-us/azure/virtual-network/service-tags-overview)

### Palo Alto EDL
- [Palo Alto EDL Hosting Service — Microsoft Feeds](https://saasedl.paloaltonetworks.com/feeds.html)
- [Palo Alto App-ID — Microsoft Applications](https://applipedia.paloaltonetworks.com/)

### FortiGate ISDB
- [FortiGuard ISDB — Microsoft-Intune](https://www.fortiguard.com/encyclopedia/isdb/327886)
- [FortiGuard ISDB — Microsoft-Office365](https://www.fortiguard.com/encyclopedia/isdb/327782)

### Other
- [Azure Bastion NSG Configuration](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg)
- [ShareFile Firewall Configuration](https://support.citrix.com/article/CTX208318)

---

**Document End**
