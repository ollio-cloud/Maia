# NWR Project - Firewall Request for SICE

**Document Version**: 1.0
**Date**: January 2025
**Project**: NWR Field Device Network Restriction
**Requested By**: Principal Endpoint Engineer
**Priority**: **CRITICAL** - Blocking Entra ID Connect deployment

---

## Executive Summary

This document contains all required firewall rules for:
1. **Entra ID Connect Servers** (M7EC-EC1-CYB-01, PH-EC2-CYB-01) - Tier 0 infrastructure
2. **Intune-Managed Field Devices** - Windows endpoints with restricted network access

**Current Blocker**: Global Admin cannot authenticate to Azure AD from Entra Connect servers due to firewall restrictions on `login.microsoftonline.com`.

---

## SECTION 1: Entra ID Connect Server Requirements

### 1.1 Server Details

| Server | Site | IP Address | Purpose |
|--------|------|------------|---------|
| M7EC-EC1-CYB-01 | M7EC | TBD (SICE to provide) | Primary Entra Connect |
| PH-EC2-CYB-01 | PH | TBD (SICE to provide) | Standby Entra Connect |

### 1.2 Outbound Rules - Azure AD / Entra ID (CRITICAL)

**Priority: P1 - Required for initial login and sync**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 1 | `login.microsoftonline.com` | 443 | TCP | **Primary Azure AD authentication** | **CRITICAL** |
| 2 | `login.microsoft.com` | 443 | TCP | Microsoft authentication | **CRITICAL** |
| 3 | `login.windows.net` | 443 | TCP | Legacy Azure AD authentication | **CRITICAL** |
| 4 | `*.login.microsoftonline.com` | 443 | TCP | Regional authentication endpoints | **CRITICAL** |
| 5 | `device.login.microsoftonline.com` | 443 | TCP | Device authentication | Required |
| 6 | `autologon.microsoftazuread-sso.com` | 443 | TCP | Seamless SSO | Required |
| 7 | `secure.aadcdn.microsoftonline-p.com` | 443 | TCP | Azure AD CDN | Required |

### 1.3 Outbound Rules - Microsoft Graph & Management APIs

**Priority: P1 - Required for sync operations**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 8 | `graph.microsoft.com` | 443 | TCP | Microsoft Graph API | **CRITICAL** |
| 9 | `graph.windows.net` | 443 | TCP | Azure AD Graph (legacy) | **CRITICAL** |
| 10 | `management.azure.com` | 443 | TCP | Azure Resource Management | Required |
| 11 | `adminwebservice.microsoftonline.com` | 443 | TCP | Admin web service | Required |
| 12 | `provisioningapi.microsoftonline.com` | 443 | TCP | Provisioning API | Required |
| 13 | `policykeyservice.dc.ad.msft.net` | 443 | TCP | Policy key service | Required |

### 1.4 Outbound Rules - Entra Connect Sync Service

**Priority: P1 - Required for synchronization**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 14 | `*.msappproxy.net` | 443 | TCP | Azure AD Connect service | Required |
| 15 | `*.servicebus.windows.net` | 443, 5671 | TCP | Service Bus (password writeback) | Required |
| 16 | `*.adhybridhealth.azure.com` | 443 | TCP | Azure AD Connect Health | Required |
| 17 | `*.aadconnecthealth.azure.com` | 443 | TCP | Connect Health monitoring | Required |
| 18 | `*.blob.core.windows.net` | 443 | TCP | Azure Blob storage | Required |

### 1.5 Outbound Rules - Certificate Validation (CRL/OCSP)

**Priority: P1 - Required for TLS certificate validation**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 19 | `crl.microsoft.com` | 80 | TCP | Microsoft CRL | **CRITICAL** |
| 20 | `mscrl.microsoft.com` | 80 | TCP | Microsoft CRL | **CRITICAL** |
| 21 | `crl3.digicert.com` | 80 | TCP | DigiCert CRL | **CRITICAL** |
| 22 | `crl4.digicert.com` | 80 | TCP | DigiCert CRL | **CRITICAL** |
| 23 | `ocsp.digicert.com` | 80 | TCP | DigiCert OCSP | **CRITICAL** |
| 24 | `ocsp.msocsp.com` | 80 | TCP | Microsoft OCSP | **CRITICAL** |
| 25 | `www.microsoft.com` | 80 | TCP | CRL distribution | Required |
| 26 | `ctldl.windowsupdate.com` | 80 | TCP | Certificate Trust List | Required |

### 1.6 Outbound Rules - Windows Update (Security Patches)

**Priority: P2 - Required for server maintenance**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 27 | `*.windowsupdate.com` | 443, 80 | TCP | Windows Update | Required |
| 28 | `*.update.microsoft.com` | 443, 80 | TCP | Microsoft Update | Required |
| 29 | `*.delivery.mp.microsoft.com` | 443 | TCP | Delivery optimization | Required |

### 1.7 Internal Rules - Active Directory Communication

**Priority: P1 - Required for AD sync**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 30 | Domain Controllers | 53 | TCP/UDP | DNS | **CRITICAL** |
| 31 | Domain Controllers | 88 | TCP/UDP | Kerberos | **CRITICAL** |
| 32 | Domain Controllers | 135 | TCP | RPC Endpoint Mapper | **CRITICAL** |
| 33 | Domain Controllers | 389 | TCP/UDP | LDAP | **CRITICAL** |
| 34 | Domain Controllers | 636 | TCP | LDAPS | Required |
| 35 | Domain Controllers | 445 | TCP | SMB | Required |
| 36 | Domain Controllers | 3268 | TCP | Global Catalog | Required |
| 37 | Domain Controllers | 3269 | TCP | Global Catalog SSL | Required |
| 38 | Domain Controllers | 49152-65535 | TCP | RPC Dynamic Ports | **CRITICAL** |

---

## SECTION 2: Intune-Managed Endpoint Requirements

### 2.1 Device Groups

These rules apply to all field devices in the `Field-Devices-Restricted-Network` group.

### 2.2 Outbound Rules - Intune Core Services

**Priority: P1 - Required for device management**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 1 | `*.manage.microsoft.com` | 443 | TCP | Intune management | **CRITICAL** |
| 2 | `manage.microsoft.com` | 443 | TCP | Intune management | **CRITICAL** |
| 3 | `enrollment.manage.microsoft.com` | 443 | TCP | Device enrollment | **CRITICAL** |
| 4 | `enterpriseregistration.windows.net` | 443 | TCP | Device registration | **CRITICAL** |
| 5 | `enterpriseenrollment.manage.microsoft.com` | 443 | TCP | MDM enrollment | **CRITICAL** |
| 6 | `enterpriseenrollment-s.manage.microsoft.com` | 443 | TCP | MDM enrollment | **CRITICAL** |
| 7 | `*.dm.microsoft.com` | 443 | TCP | Delivery/Defender | **CRITICAL** |

### 2.3 Outbound Rules - Authentication (Same as Entra Connect)

**Priority: P1 - Required for user/device authentication**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 8 | `login.microsoftonline.com` | 443 | TCP | Azure AD authentication | **CRITICAL** |
| 9 | `login.microsoft.com` | 443 | TCP | Microsoft authentication | **CRITICAL** |
| 10 | `*.login.microsoftonline.com` | 443 | TCP | Regional auth endpoints | **CRITICAL** |
| 11 | `login.windows.net` | 443 | TCP | Legacy authentication | Required |
| 12 | `device.login.microsoftonline.com` | 443 | TCP | Device authentication | Required |
| 13 | `graph.microsoft.com` | 443 | TCP | Microsoft Graph | Required |
| 14 | `graph.windows.net` | 443 | TCP | Azure AD Graph | Required |

### 2.4 Outbound Rules - Windows Update & Defender

**Priority: P1 - Required for security**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 15 | `*.windowsupdate.com` | 443, 80 | TCP | Windows Update | **CRITICAL** |
| 16 | `*.update.microsoft.com` | 443, 80 | TCP | Microsoft Update | **CRITICAL** |
| 17 | `*.delivery.mp.microsoft.com` | 443 | TCP | Delivery optimization | Required |
| 18 | `*.dl.delivery.mp.microsoft.com` | 443 | TCP | Download delivery | Required |
| 19 | `*.do.dsp.mp.microsoft.com` | 443 | TCP | Delivery optimization | Required |
| 20 | `tsfe.trafficshaping.dsp.mp.microsoft.com` | 443 | TCP | Traffic shaping | Required |

### 2.5 Outbound Rules - Microsoft Defender

**Priority: P1 - Required for endpoint protection**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 21 | `*.wdcp.microsoft.com` | 443 | TCP | Defender cloud protection | **CRITICAL** |
| 22 | `*.wdcpalt.microsoft.com` | 443 | TCP | Defender cloud (alt) | Required |
| 23 | `*.smartscreen.microsoft.com` | 443 | TCP | SmartScreen | Required |
| 24 | `*.smartscreen-prod.microsoft.com` | 443 | TCP | SmartScreen | Required |
| 25 | `definitionupdates.microsoft.com` | 443 | TCP | Defender definitions | **CRITICAL** |
| 26 | `*.mp.microsoft.com` | 443 | TCP | Malware protection | Required |

### 2.6 Outbound Rules - Win32 App & Script Deployment

**Priority: P2 - Required for app deployment**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 27 | `*.blob.core.windows.net` | 443 | TCP | Azure blob storage | Required |
| 28 | `swda01-mscdn.manage.microsoft.com` | 443 | TCP | Win32 app CDN | Required |
| 29 | `swda02-mscdn.manage.microsoft.com` | 443 | TCP | Win32 app CDN | Required |
| 30 | `swdb01-mscdn.manage.microsoft.com` | 443 | TCP | Win32 app CDN (EU) | Required |
| 31 | `swdb02-mscdn.manage.microsoft.com` | 443 | TCP | Win32 app CDN (EU) | Required |
| 32 | `naprodimedatapri.azureedge.net` | 443 | TCP | Script deployment | Required |
| 33 | `naprodimedatasec.azureedge.net` | 443 | TCP | Script deployment | Required |

### 2.7 Outbound Rules - Windows Push Notifications (WNS)

**Priority: P2 - Required for real-time device actions**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 34 | `*.notify.windows.com` | 443 | TCP | Push notifications | Required |
| 35 | `*.wns.windows.com` | 443 | TCP | WNS service | Required |

### 2.8 Outbound Rules - Certificate Validation (Same as Entra Connect)

**Priority: P1 - Required for TLS**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 36 | `crl.microsoft.com` | 80 | TCP | Microsoft CRL | **CRITICAL** |
| 37 | `mscrl.microsoft.com` | 80 | TCP | Microsoft CRL | Required |
| 38 | `crl3.digicert.com` | 80 | TCP | DigiCert CRL | Required |
| 39 | `ocsp.digicert.com` | 80 | TCP | DigiCert OCSP | Required |
| 40 | `ocsp.msocsp.com` | 80 | TCP | Microsoft OCSP | Required |
| 41 | `ctldl.windowsupdate.com` | 80 | TCP | CTL download | Required |

---

## SECTION 3: Field Device Application-Specific Requirements

### 3.1 Azure Bastion Access (Use Case 1 & 2)

**Priority: P1 - Required for remote access to infrastructure**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 1 | `*.bastion.azure.com` | 443 | TCP | Azure Bastion service | **CRITICAL** |
| 2 | `*.portal.azure.com` | 443 | TCP | Azure Portal | **CRITICAL** |
| 3 | `portal.azure.com` | 443 | TCP | Azure Portal | **CRITICAL** |

### 3.2 ShareFile Access (Use Case 1 & 2)

**Priority: P1 - Required for file access**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 4 | `*.sharefile.com` | 443 | TCP | ShareFile service | **CRITICAL** |
| 5 | `*.sf-api.com` | 443 | TCP | ShareFile API | **CRITICAL** |
| 6 | `*.citrixdata.com` | 443 | TCP | ShareFile storage | Required |
| 7 | `*.sf-cdn.net` | 443 | TCP | ShareFile CDN | Required |

### 3.3 SICE/MSP Patch Access (Use Case 6)

**Priority: P2 - Required for patching (TBD - confirm with MSP)**

| # | Destination | Port | Protocol | Purpose | Required |
|---|-------------|------|----------|---------|----------|
| 8 | `*.msp-sice.com` | 443 | TCP | SICE patch server (TBD) | Required |
| 9 | (MSP to provide) | 443 | TCP | MSP endpoints | Required |

---

## SECTION 4: Summary - Consolidated Wildcard Rules

### 4.1 Minimum Required Wildcards (Simplified)

For environments that support wildcard rules, use these consolidated entries:

**TCP 443 (HTTPS):**
```
# Authentication
login.microsoftonline.com
login.microsoft.com
login.windows.net
*.login.microsoftonline.com
device.login.microsoftonline.com
secure.aadcdn.microsoftonline-p.com

# Microsoft Graph & APIs
graph.microsoft.com
graph.windows.net
management.azure.com
adminwebservice.microsoftonline.com
provisioningapi.microsoftonline.com

# Entra Connect Specific
*.msappproxy.net
*.servicebus.windows.net
*.adhybridhealth.azure.com
*.aadconnecthealth.azure.com

# Intune Core
*.manage.microsoft.com
manage.microsoft.com
enterpriseregistration.windows.net
enterpriseenrollment.manage.microsoft.com
enterpriseenrollment-s.manage.microsoft.com
*.dm.microsoft.com

# Windows Update
*.windowsupdate.com
*.update.microsoft.com
*.delivery.mp.microsoft.com
*.dl.delivery.mp.microsoft.com
*.do.dsp.mp.microsoft.com

# Defender
*.wdcp.microsoft.com
*.wdcpalt.microsoft.com
*.smartscreen.microsoft.com
definitionupdates.microsoft.com

# Content Delivery
*.blob.core.windows.net
*.azureedge.net

# Push Notifications
*.notify.windows.com
*.wns.windows.com

# Application Access (Field Devices)
*.bastion.azure.com
*.portal.azure.com
*.sharefile.com
*.sf-api.com
*.citrixdata.com
```

**TCP 80 (HTTP - CRL/OCSP):**
```
crl.microsoft.com
mscrl.microsoft.com
crl3.digicert.com
crl4.digicert.com
ocsp.digicert.com
ocsp.msocsp.com
www.microsoft.com
ctldl.windowsupdate.com
```

**TCP 5671 (Optional - Password Writeback):**
```
*.servicebus.windows.net
```

---

## SECTION 5: Verification & Testing

### 5.1 Entra Connect Server Verification Script

```powershell
# Run on Entra Connect servers to verify connectivity
$Endpoints = @(
    # Critical Authentication
    @{ Name = "Azure AD Login"; Host = "login.microsoftonline.com"; Port = 443 },
    @{ Name = "MS Login"; Host = "login.microsoft.com"; Port = 443 },
    @{ Name = "Graph API"; Host = "graph.microsoft.com"; Port = 443 },
    @{ Name = "Azure AD Graph"; Host = "graph.windows.net"; Port = 443 },
    @{ Name = "Admin Service"; Host = "adminwebservice.microsoftonline.com"; Port = 443 },
    @{ Name = "Provisioning"; Host = "provisioningapi.microsoftonline.com"; Port = 443 },
    @{ Name = "Azure Management"; Host = "management.azure.com"; Port = 443 },

    # CRL (HTTP)
    @{ Name = "MS CRL"; Host = "crl.microsoft.com"; Port = 80 },
    @{ Name = "DigiCert CRL"; Host = "crl3.digicert.com"; Port = 80 },
    @{ Name = "MS OCSP"; Host = "ocsp.msocsp.com"; Port = 80 }
)

Write-Host "=== ENTRA CONNECT FIREWALL VERIFICATION ===" -ForegroundColor Cyan
$Failed = 0

foreach ($EP in $Endpoints) {
    $Result = Test-NetConnection -ComputerName $EP.Host -Port $EP.Port -WarningAction SilentlyContinue -InformationLevel Quiet
    $Status = if ($Result) { "OK" } else { "BLOCKED"; $Failed++ }
    $Color = if ($Result) { "Green" } else { "Red" }
    Write-Host "  $($EP.Name.PadRight(25)) $($EP.Host):$($EP.Port) - $Status" -ForegroundColor $Color
}

if ($Failed -gt 0) {
    Write-Host "`nBLOCKED: $Failed endpoints - Contact SICE to update firewall rules" -ForegroundColor Red
} else {
    Write-Host "`nAll endpoints accessible - Ready for Entra Connect installation" -ForegroundColor Green
}
```

### 5.2 Field Device Verification Script

```powershell
# Run on managed endpoints to verify Intune connectivity
$Endpoints = @(
    # Intune
    @{ Name = "Intune Manage"; Host = "manage.microsoft.com"; Port = 443 },
    @{ Name = "Intune Enrollment"; Host = "enrollment.manage.microsoft.com"; Port = 443 },
    @{ Name = "Enterprise Reg"; Host = "enterpriseregistration.windows.net"; Port = 443 },

    # Authentication
    @{ Name = "Azure AD Login"; Host = "login.microsoftonline.com"; Port = 443 },
    @{ Name = "Graph API"; Host = "graph.microsoft.com"; Port = 443 },

    # Defender
    @{ Name = "Defender"; Host = "wdcp.microsoft.com"; Port = 443 },
    @{ Name = "SmartScreen"; Host = "smartscreen.microsoft.com"; Port = 443 },

    # Windows Update
    @{ Name = "Windows Update"; Host = "windowsupdate.com"; Port = 443 },

    # Field Device Apps
    @{ Name = "Azure Bastion"; Host = "portal.azure.com"; Port = 443 },
    @{ Name = "ShareFile"; Host = "www.sharefile.com"; Port = 443 }
)

Write-Host "=== INTUNE ENDPOINT FIREWALL VERIFICATION ===" -ForegroundColor Cyan
$Failed = 0

foreach ($EP in $Endpoints) {
    $Result = Test-NetConnection -ComputerName $EP.Host -Port $EP.Port -WarningAction SilentlyContinue -InformationLevel Quiet
    $Status = if ($Result) { "OK" } else { "BLOCKED"; $Failed++ }
    $Color = if ($Result) { "Green" } else { "Red" }
    Write-Host "  $($EP.Name.PadRight(20)) $($EP.Host):$($EP.Port) - $Status" -ForegroundColor $Color
}

if ($Failed -gt 0) {
    Write-Host "`nBLOCKED: $Failed endpoints - Intune management may fail" -ForegroundColor Red
} else {
    Write-Host "`nAll endpoints accessible - Ready for Intune enrollment" -ForegroundColor Green
}
```

---

## SECTION 6: Important Notes

### 6.1 SSL/TLS Inspection

**SSL inspection is NOT supported** for the following endpoints (bypass required):
- `*.manage.microsoft.com`
- `*.dm.microsoft.com`
- `*.wdcp.microsoft.com`
- `*.smartscreen.microsoft.com`
- `*.blob.core.windows.net`

### 6.2 Proxy Requirements

If using a proxy server:
- **Unauthenticated proxy access required** for Intune endpoints
- **Byte Range request support required** for Delivery Optimization

### 6.3 Upcoming Change (December 2025)

Microsoft is migrating Intune to Azure Front Door. By December 2, 2025, add:
- **Service Tag**: `AzureFrontDoor.MicrosoftSecurity` (outbound port 443)

### 6.4 DNS Requirements

Entra Connect servers require DNS resolution for:
- On-premises Active Directory (internal DNS)
- Microsoft cloud endpoints (external DNS via corporate resolver)

---

## SECTION 7: Approval & Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Requestor | Principal Endpoint Engineer | Jan 2025 | __________ |
| SICE Network Team | __________ | __________ | __________ |
| Cyber Security | __________ | __________ | __________ |
| Change Manager | __________ | __________ | __________ |

---

## References

- [Microsoft Entra Connect Ports & Protocols](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/reference-connect-ports)
- [Microsoft Intune Network Endpoints](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/intune-endpoints)
- [Azure Bastion NSG Configuration](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg)
- [ShareFile Firewall Configuration](https://support.citrix.com/article/CTX208318)

---

**Document End**
