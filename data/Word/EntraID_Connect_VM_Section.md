# Section to Add to NWR-Microsoft Intune + Windows Device Management – Solution Design v1.4

**Suggested location:** After Section 7.2 (Directory Integration Details Table), before Section 8 (Device Management)

---

## 7.3 Entra ID Connect Virtual Machine Infrastructure

### Overview

Two new virtual machines are required to support the Entra ID Connect (Azure AD Connect) deployment for MDM Intune configuration management. These servers will synchronize the on-premises Active Directory with Microsoft Entra ID, enabling hybrid identity for device management.

### VM Specifications

| Specification | Requirement |
|---------------|-------------|
| **Operating System** | Windows Server 2022 Standard (or higher edition) |
| **CPU** | Dual core, 1.6 GHz minimum |
| **Memory** | 6 GB RAM |
| **Storage** | 70 GB SSD |
| **Server Type** | GUI installation required (Windows Server Core is NOT supported) |

### Software & Framework Requirements

| Component | Requirement |
|-----------|-------------|
| PowerShell | Version 5.0 or later |
| .NET Framework | Version 4.8 or later |
| PowerShell Execution Policy | RemoteSigned (recommended during installation) |
| TLS | TLS 1.2 must be enabled |

### Security & Endpoint Protection

| Agent | Requirement |
|-------|-------------|
| Rapid7 | Must be installed |
| SentinelOne (S1) | Must be installed |

### Domain & Network Requirements

| Requirement | Details |
|-------------|---------|
| Domain Join | Servers must be domain joined to on-premises Active Directory |
| AD Connectivity | Entra ID Connect application uses LDAPS to connect to Active Directory (by default, uses LDAP connections that are signed and encrypted) |
| Network Zone | Tier 0 asset – should be placed in the same zone as Domain Controllers |
| Firewall | Zones managed via Palo Alto firewall |
| IP Addressing | IP address allocations to be provided by SICE |

### VM Naming Convention

| Site | VM Name |
|------|---------|
| M7EC | M7EC-EC1-CYB-01 |
| PH | PH-EC2-CYB-01 |

*Note: Final naming to be confirmed by NWR as these are customer-owned assets.*

### Backup Requirements

| Requirement | Configuration |
|-------------|---------------|
| Backup | Servers must be included in the backup schedule |

### Security Classification

These VMs are classified as **Tier 0 assets**, equivalent to Domain Controllers, due to their role in identity synchronization. They require:

- Placement in the same network zone as Domain Controllers
- Equivalent security controls and monitoring
- Restricted administrative access following least privilege principles
- Continuous monitoring and logging

### Approval Status

| Approval Type | Status | Approver | Date |
|--------------|--------|----------|------|
| Cyber Security Approval | Approved with conditions | Avi Lipa | 04/Nov/25 |
| Configuration Confirmation | Confirmed | ORRO | 10/Nov/25 |

**Cyber Security Conditions:**
- R7 and S1 agents must be installed
- ORRO to provide hardening guidance and confirm if SICE GPOs can be used or if ORRO will supply their own hardening configuration

### Action Items

| Action | Responsible Party | Status |
|--------|-------------------|--------|
| Provide IP address allocations | SICE | Pending |
| Confirm network zone configuration (Palo Alto) | SICE | Pending |
| Confirm hardening requirements/GPOs | ORRO | Pending |
| Configure backup schedule | SICE | Pending |
| Install R7 and S1 agents | SICE | Pending |

---

**End of Section 7.3**
