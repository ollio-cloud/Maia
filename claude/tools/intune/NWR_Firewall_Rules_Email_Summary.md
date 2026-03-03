# NWR Project - Firewall Rules Request

**Priority: CRITICAL** - Blocking Entra ID Connect deployment
**Date**: January 2025

---

## Current Issue

Global Admin cannot authenticate to Azure AD from Entra Connect servers. Firewall rules required to proceed with deployment.

---

## Servers Requiring Access

| Server | Site | Role |
|--------|------|------|
| M7EC-EC1-CYB-01 | M7EC | Primary Entra Connect |
| PH-EC2-CYB-01 | PH | Standby Entra Connect |
| Field Devices | All | Intune-managed endpoints |

---

## OPTION 1: Consolidated Wildcard Rules (Recommended)

### TCP 443 (HTTPS)

```
# Authentication (CRITICAL)
login.microsoftonline.com
login.microsoft.com
login.windows.net
*.login.microsoftonline.com
device.login.microsoftonline.com

# Microsoft APIs (CRITICAL)
graph.microsoft.com
graph.windows.net
management.azure.com
adminwebservice.microsoftonline.com
provisioningapi.microsoftonline.com

# Entra Connect
*.msappproxy.net
*.servicebus.windows.net
*.adhybridhealth.azure.com

# Intune
*.manage.microsoft.com
enterpriseregistration.windows.net
enterpriseenrollment.manage.microsoft.com
*.dm.microsoft.com

# Windows Update & Defender
*.windowsupdate.com
*.update.microsoft.com
*.delivery.mp.microsoft.com
*.wdcp.microsoft.com
*.smartscreen.microsoft.com
definitionupdates.microsoft.com

# Content Delivery
*.blob.core.windows.net
*.azureedge.net
*.notify.windows.com

# Field Device Applications
*.bastion.azure.com
*.portal.azure.com
*.sharefile.com
*.sf-api.com
*.citrixdata.com
```

### TCP 80 (HTTP) - Certificate Validation

```
crl.microsoft.com
mscrl.microsoft.com
crl3.digicert.com
crl4.digicert.com
ocsp.digicert.com
ocsp.msocsp.com
ctldl.windowsupdate.com
```

### TCP 5671 (Optional - Password Writeback)

```
*.servicebus.windows.net
```

---

## OPTION 2: Critical Endpoints Only (Minimum to Unblock)

If full list cannot be implemented immediately, these are the **minimum required** to unblock Entra Connect login:

| # | Destination | Port | Purpose |
|---|-------------|------|---------|
| 1 | `login.microsoftonline.com` | 443 | Azure AD login |
| 2 | `login.microsoft.com` | 443 | MS authentication |
| 3 | `graph.microsoft.com` | 443 | Graph API |
| 4 | `graph.windows.net` | 443 | Azure AD Graph |
| 5 | `adminwebservice.microsoftonline.com` | 443 | Admin service |
| 6 | `crl.microsoft.com` | 80 | Certificate validation |
| 7 | `crl3.digicert.com` | 80 | Certificate validation |
| 8 | `ocsp.msocsp.com` | 80 | OCSP validation |

---

## Summary

| Category | Port | Rule Count |
|----------|------|------------|
| HTTPS endpoints | TCP 443 | ~35 wildcards |
| HTTP (CRL/OCSP) | TCP 80 | 7 endpoints |
| Optional (writeback) | TCP 5671 | 1 wildcard |

---

## Important Notes

1. **SSL Inspection**: Must be **bypassed** for `*.manage.microsoft.com` and `*.dm.microsoft.com`
2. **HTTP Required**: Port 80 is required for certificate validation - will cause TLS failures if blocked
3. **December 2025**: Add Azure Front Door service tag `AzureFrontDoor.MicrosoftSecurity`

---

## Verification

After firewall changes, run this on Entra Connect servers:

```powershell
Test-NetConnection login.microsoftonline.com -Port 443
Test-NetConnection graph.microsoft.com -Port 443
Test-NetConnection crl.microsoft.com -Port 80
```

All should return `TcpTestSucceeded: True`

---

## Attachments

- Full firewall request document: `NWR_Firewall_Request_SICE.pdf`
- Implementation guide: `Field_Device_Network_Restriction_Implementation_Guide.pdf`

---

**Contact**: Principal Endpoint Engineer
**Urgency**: CRITICAL - Blocking project deployment
