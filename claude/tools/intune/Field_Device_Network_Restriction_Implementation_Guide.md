# Field Device Network Restriction Implementation Guide

## Microsoft Intune + GPO Configuration for Secure Field Devices

**Version**: 1.0
**Last Updated**: December 2024
**Author**: Principal Endpoint Engineer

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Use Case 1 & 2: Disable Wi-Fi, Allow LAN/5G, Restrict to Azure Bastion + ShareFile](#use-case-1--2)
5. [Use Case 3: Allow USB-Based IP Configuration Tools](#use-case-3)
6. [Use Case 4: Support Serial Communication via USB-to-Serial](#use-case-4)
7. [Use Case 5: Secure Offline Access](#use-case-5)
8. [Use Case 6: SICE (MSP) Patch Access Validation](#use-case-6)
9. [Entra ID Connect Infrastructure Setup](#entra-id-connect-setup)
10. [Deployment Sequence](#deployment-sequence)
11. [Testing and Validation](#testing-and-validation)
12. [Rollback Procedures](#rollback-procedures)
13. [Appendix](#appendix)

---

## Executive Summary

This document provides step-by-step implementation guidance for configuring secure field devices using Microsoft Intune and Group Policy. The solution addresses six use cases focused on network restriction, USB control, and secure access patterns.

### Key Outcomes

| Objective | Solution |
|-----------|----------|
| Disable Wi-Fi | Intune PowerShell + Scheduled Task |
| Allow LAN/5G only | Network adapter management |
| Restrict internet to Azure Bastion + ShareFile | Windows Firewall Dynamic Keywords |
| USB device whitelisting | Defender for Endpoint Device Control |
| USB-to-Serial support | Driver deployment + whitelisting |
| Secure offline access | BitLocker + Defender + cached credentials |
| MSP patch access | VPN + firewall rules |

### Technology Stack

- Microsoft Intune (MDM)
- Windows Firewall with Dynamic Keywords
- Microsoft Defender for Endpoint
- Group Policy (supplemental)
- PowerShell automation

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FIELD DEVICE ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        NETWORK LAYER                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Wi-Fi Adapter        │ DISABLED (Intune Script + Scheduled Task)   │   │
│  │  Ethernet (LAN)       │ ENABLED  (Corporate network access)         │   │
│  │  Cellular (5G SIM)    │ ENABLED  (Field connectivity)               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      FIREWALL LAYER (Dynamic Keywords)               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  DEFAULT OUTBOUND     │ BLOCK ALL                                    │   │
│  │  ────────────────────────────────────────────────────────────────── │   │
│  │  ALLOWED (FQDNs):                                                    │   │
│  │  ├── *.bastion.azure.com      (Azure Bastion)                       │   │
│  │  ├── *.portal.azure.com       (Azure Portal)                        │   │
│  │  ├── *.sharefile.com          (ShareFile)                           │   │
│  │  ├── *.sf-api.com             (ShareFile API)                       │   │
│  │  ├── login.microsoftonline.com (Authentication)                     │   │
│  │  ├── *.manage.microsoft.com   (Intune)                              │   │
│  │  ├── *.windowsupdate.com      (Security Updates)                    │   │
│  │  └── Local Network (RFC1918)  (LAN access)                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         USB LAYER                                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Mass Storage          │ BLOCKED (Defender Device Control)          │   │
│  │  Approved IP Tools     │ ALLOWED (VID/PID whitelist)                │   │
│  │  USB-Serial Adapters   │ ALLOWED (VID/PID whitelist + drivers)      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       SECURITY LAYER                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  BitLocker             │ ENABLED (TPM + PIN)                        │   │
│  │  Windows Defender      │ ENABLED (Real-time + Network Protection)   │   │
│  │  Cached Credentials    │ 10 logons (offline access)                 │   │
│  │  Windows Hello         │ ENABLED (biometric authentication)         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Licensing Requirements

| Feature | License Required |
|---------|------------------|
| Intune device management | Microsoft Intune (M365 E3/E5 or standalone) |
| Dynamic Keywords (FQDN) | Windows 10 21H2+ / Windows 11 |
| USB VID/PID control | Defender for Endpoint P2 (M365 E5) |
| BitLocker management | Intune (any tier) |
| Proactive Remediations | Intune (any tier) |

### Technical Requirements

| Requirement | Minimum Version | Verification Command |
|-------------|-----------------|---------------------|
| Windows OS | Windows 10 21H2 (Build 19044) | `winver` |
| Defender Antivirus | 4.18.2209.7 | `(Get-MpComputerStatus).AMProductVersion` |
| Network Protection | Enabled | `(Get-MpPreference).EnableNetworkProtection` |
| DNS over HTTPS | Disabled | Registry check (see below) |

### Pre-Implementation Checklist

```powershell
# Run this script to verify prerequisites
Write-Host "=== Prerequisite Check ===" -ForegroundColor Cyan

# 1. Windows Version
$OS = Get-CimInstance Win32_OperatingSystem
$Build = [int]$OS.BuildNumber
Write-Host "Windows Build: $Build" -ForegroundColor $(if ($Build -ge 19044) { 'Green' } else { 'Red' })

# 2. Defender Version
$Defender = Get-MpComputerStatus
Write-Host "Defender Version: $($Defender.AMProductVersion)" -ForegroundColor Green

# 3. Network Protection
$NP = (Get-MpPreference).EnableNetworkProtection
$NPStatus = switch ($NP) { 1 { "Enabled" } 2 { "Audit" } default { "Disabled" } }
Write-Host "Network Protection: $NPStatus" -ForegroundColor $(if ($NP -ge 1) { 'Green' } else { 'Yellow' })

# 4. DoH Status
$DoH = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "EnableAutoDoh" -ErrorAction SilentlyContinue).EnableAutoDoh
Write-Host "DNS over HTTPS: $(if ($DoH -eq 2) { 'Enabled (needs disable)' } else { 'Disabled (OK)' })" -ForegroundColor $(if ($DoH -ne 2) { 'Green' } else { 'Yellow' })

# 5. Intune Enrollment
$MDM = Get-CimInstance -Namespace root/cimv2/mdm/dmmap -ClassName MDM_DevDetail -ErrorAction SilentlyContinue
Write-Host "Intune Enrolled: $(if ($MDM) { 'Yes' } else { 'No' })" -ForegroundColor $(if ($MDM) { 'Green' } else { 'Red' })

Write-Host "`n=== Check Complete ===" -ForegroundColor Cyan
```

---

## Use Case 1 & 2: Disable Wi-Fi, Allow LAN/5G, Restrict to Azure Bastion + ShareFile {#use-case-1--2}

### Overview

| Requirement | Implementation |
|-------------|----------------|
| Disable Wi-Fi | PowerShell script + scheduled task |
| Allow Ethernet (LAN) | No action (enabled by default) |
| Allow Cellular (5G SIM) | No action (enabled by default) |
| Restrict internet | Windows Firewall Dynamic Keywords |
| Allowed destinations | Azure Bastion, ShareFile, Microsoft Auth, Intune |

### Step 1.1: Create Device Group

**Location**: Microsoft Entra admin center → Groups → New Group

| Setting | Value |
|---------|-------|
| Group type | Security |
| Group name | `Field-Devices-Restricted-Network` |
| Membership type | Dynamic Device (recommended) or Assigned |

**Dynamic Membership Rule** (if using Autopilot group tag):
```
(device.devicePhysicalIds -any (_ -contains "[OrderID]:Field-Restricted"))
```

---

### Step 1.2: Enable Network Protection (Required for Dynamic Keywords)

**Location**: Intune Admin Center → Endpoint Security → Attack Surface Reduction → Create Policy

| Setting | Value |
|---------|-------|
| Platform | Windows 10, Windows 11, Windows Server |
| Profile | Attack Surface Reduction Rules |
| Name | `Field-Devices-Enable-Network-Protection` |

**Configuration**:

| Setting | Value |
|---------|-------|
| Enable network protection | Enable (block mode) |

**Assignment**: `Field-Devices-Restricted-Network` group

---

### Step 1.3: Disable DNS over HTTPS

**Location**: Intune → Devices → Configuration → Create → Settings Catalog

| Setting | Value |
|---------|-------|
| Platform | Windows 10 and later |
| Profile type | Settings catalog |
| Name | `Field-Devices-Disable-DoH` |

**Settings to configure**:

| Category | Setting | Value |
|----------|---------|-------|
| DNS Client | Configure DNS over HTTPS (DoH) name resolution | Disabled |

**Assignment**: `Field-Devices-Restricted-Network` group

---

### Step 1.4: Deploy Wi-Fi Disable Script

**Location**: Intune → Devices → Scripts and remediations → Platform scripts → Add

**Script Name**: `Disable-WiFi-Allow-LAN-5G.ps1`

```powershell
<#
.SYNOPSIS
    Disables Wi-Fi adapter, allows LAN and Cellular (5G SIM)
.DESCRIPTION
    - Disables all Wi-Fi/Wireless adapters
    - Leaves Ethernet (LAN) enabled
    - Leaves Cellular/WWAN (5G SIM) enabled
    - Creates scheduled task for persistent enforcement
.VERSION
    2.0
#>

#Requires -RunAsAdministrator

$LogPath = "$env:ProgramData\Intune\Logs"
$LogFile = "$LogPath\NetworkRestriction_$(Get-Date -Format 'yyyyMMdd').log"
$TaskName = "Intune-WiFiDisableEnforcement"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
    Add-Content -Path $LogFile -Value "[$Timestamp] [$Level] $Message"
    Write-Output "[$Level] $Message"
}

try {
    Write-Log "=== Starting Network Restriction Configuration ==="

    # Get all network adapters
    $AllAdapters = Get-NetAdapter

    # Wi-Fi adapters to DISABLE
    $WifiAdapters = $AllAdapters | Where-Object {
        $_.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN|802\.11|WiFi' -or
        $_.Name -match 'Wi-Fi|Wireless|WiFi' -or
        $_.PhysicalMediaType -eq 'Native 802.11'
    }

    # Ethernet adapters to KEEP ENABLED
    $EthernetAdapters = $AllAdapters | Where-Object {
        $_.InterfaceDescription -match 'Ethernet|Realtek|Intel.*Ethernet|Killer.*E' -and
        $_.InterfaceDescription -notmatch 'Virtual|Hyper-V|VPN|Cellular|WWAN'
    }

    # Cellular adapters to KEEP ENABLED
    $CellularAdapters = $AllAdapters | Where-Object {
        $_.InterfaceDescription -match 'Cellular|Mobile|WWAN|5G|LTE|Sierra|Qualcomm|Intel.*XMM'
    }

    Write-Log "Found: Wi-Fi=$($WifiAdapters.Count), Ethernet=$($EthernetAdapters.Count), Cellular=$($CellularAdapters.Count)"

    # Disable Wi-Fi adapters
    foreach ($Adapter in $WifiAdapters) {
        Write-Log "Disabling Wi-Fi: $($Adapter.Name)"
        Disable-NetAdapter -Name $Adapter.Name -Confirm:$false -ErrorAction Stop
        Write-Log "  -> Disabled successfully" "SUCCESS"
    }

    # Verify Ethernet is enabled
    foreach ($Adapter in $EthernetAdapters) {
        if ($Adapter.Status -eq 'Disabled') {
            Enable-NetAdapter -Name $Adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Enabled Ethernet: $($Adapter.Name)"
        }
    }

    # Verify Cellular is enabled
    foreach ($Adapter in $CellularAdapters) {
        if ($Adapter.Status -eq 'Disabled') {
            Enable-NetAdapter -Name $Adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Enabled Cellular: $($Adapter.Name)"
        }
    }

    # Create enforcement scheduled task
    Write-Log "Creating enforcement scheduled task..."

    $EnforcementScript = @'
Get-NetAdapter | Where-Object {
    ($_.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN|802\.11' -or $_.Name -match 'Wi-Fi') -and
    $_.Status -ne 'Disabled'
} | ForEach-Object {
    Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue
}
'@

    $ScriptPath = "$env:ProgramData\Intune\Scripts"
    if (-not (Test-Path $ScriptPath)) { New-Item -Path $ScriptPath -ItemType Directory -Force | Out-Null }
    $EnforcementScript | Out-File -FilePath "$ScriptPath\Enforce-WiFiDisabled.ps1" -Encoding UTF8 -Force

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath\Enforce-WiFiDisabled.ps1`""
    $Triggers = @(
        $(New-ScheduledTaskTrigger -AtStartup),
        $(New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 9999)),
        $(New-ScheduledTaskTrigger -AtLogOn)
    )
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    $Task = New-ScheduledTask -Action $Action -Trigger $Triggers -Principal $Principal -Settings $Settings
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force | Out-Null

    Write-Log "=== Configuration Complete ==="
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)" "ERROR"
    exit 1
}
```

**Script Settings**:

| Setting | Value |
|---------|-------|
| Run this script using the logged on credentials | No |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell Host | Yes |

**Assignment**: `Field-Devices-Restricted-Network` group

---

### Step 1.5: Block Wi-Fi UI Access

**Location**: Intune → Devices → Configuration → Create → Settings Catalog

| Setting | Value |
|---------|-------|
| Name | `Field-Devices-Block-WiFi-UI` |
| Platform | Windows 10 and later |

**Settings**:

| Category | Setting | Value |
|----------|---------|-------|
| Connectivity | Allow Wi-Fi | Block |

---

### Step 1.6: Configure Windows Firewall with Dynamic Keywords

**Location**: Intune → Devices → Scripts and remediations → Platform scripts → Add

**Script Name**: `Configure-DynamicKeyword-Firewall.ps1`

```powershell
<#
.SYNOPSIS
    Configures Windows Firewall using Dynamic Keywords (FQDNs)
.DESCRIPTION
    - Creates Dynamic Keyword Addresses for Azure Bastion and ShareFile
    - Sets default outbound to BLOCK
    - Creates allow rules for whitelisted destinations only
.REQUIREMENTS
    - Windows 10 21H2+ or Windows 11
    - Defender Antivirus 4.18.2209.7+
    - Network Protection enabled
    - DoH disabled
.VERSION
    1.0
#>

#Requires -RunAsAdministrator

$LogPath = "$env:ProgramData\Intune\Logs"
$LogFile = "$LogPath\FirewallConfig_$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
    Add-Content -Path $LogFile -Value "[$Timestamp] [$Level] $Message"
    Write-Output "[$Level] $Message"
}

function New-DynamicKeyword {
    param([string]$Id, [string]$Keyword, [bool]$AutoResolve = $true)

    try {
        $Existing = Get-NetFirewallDynamicKeywordAddress -Id $Id -ErrorAction SilentlyContinue
        if ($Existing) {
            Remove-NetFirewallDynamicKeywordAddress -Id $Id -ErrorAction SilentlyContinue
        }
        New-NetFirewallDynamicKeywordAddress -Id $Id -Keyword $Keyword -AutoResolve $AutoResolve
        Write-Log "  Created: $Keyword" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "  ERROR: $Keyword - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ============================================
# DYNAMIC KEYWORD DEFINITIONS
# ============================================

$Keywords = @{
    # Azure Bastion
    AzureBastion = @{ Id = "{11111111-1111-1111-1111-111111111111}"; Keyword = "*.bastion.azure.com" }
    AzurePortal = @{ Id = "{11111111-1111-1111-1111-111111111112}"; Keyword = "*.portal.azure.com" }
    AzureAuth = @{ Id = "{11111111-1111-1111-1111-111111111113}"; Keyword = "login.microsoftonline.com" }
    AzureGraph = @{ Id = "{11111111-1111-1111-1111-111111111114}"; Keyword = "graph.microsoft.com" }
    AzureLogin = @{ Id = "{11111111-1111-1111-1111-111111111115}"; Keyword = "login.microsoft.com" }
    AzureAD = @{ Id = "{11111111-1111-1111-1111-111111111116}"; Keyword = "*.login.microsoftonline.com" }

    # ShareFile
    ShareFile1 = @{ Id = "{22222222-2222-2222-2222-222222222221}"; Keyword = "*.sharefile.com" }
    ShareFile2 = @{ Id = "{22222222-2222-2222-2222-222222222222}"; Keyword = "*.sf-api.com" }
    ShareFile3 = @{ Id = "{22222222-2222-2222-2222-222222222223}"; Keyword = "*.citrixdata.com" }

    # Intune Management
    IntuneMgmt = @{ Id = "{33333333-3333-3333-3333-333333333331}"; Keyword = "*.manage.microsoft.com" }
    IntuneEnroll = @{ Id = "{33333333-3333-3333-3333-333333333332}"; Keyword = "enrollment.manage.microsoft.com" }
    IntuneDM = @{ Id = "{33333333-3333-3333-3333-333333333333}"; Keyword = "*.dm.microsoft.com" }

    # Windows Update (security patches)
    WU1 = @{ Id = "{44444444-4444-4444-4444-444444444441}"; Keyword = "*.windowsupdate.com" }
    WU2 = @{ Id = "{44444444-4444-4444-4444-444444444442}"; Keyword = "*.update.microsoft.com" }
    WU3 = @{ Id = "{44444444-4444-4444-4444-444444444443}"; Keyword = "*.delivery.mp.microsoft.com" }

    # Defender Updates
    Defender1 = @{ Id = "{55555555-5555-5555-5555-555555555551}"; Keyword = "*.wdcp.microsoft.com" }
    Defender2 = @{ Id = "{55555555-5555-5555-5555-555555555552}"; Keyword = "*.smartscreen.microsoft.com" }
}

try {
    Write-Log "=== Starting Dynamic Keyword Firewall Configuration ==="

    # Verify Network Protection is enabled
    $NP = (Get-MpPreference).EnableNetworkProtection
    if ($NP -ne 1) {
        Write-Log "Enabling Network Protection..."
        Set-MpPreference -EnableNetworkProtection Enabled
    }

    # Clean up existing rules
    Write-Log "Removing existing rules..."
    Get-NetFirewallRule -DisplayName "DynKeyword-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

    # Create Dynamic Keywords
    Write-Log "Creating Dynamic Keywords..."
    foreach ($Key in $Keywords.Keys) {
        $KW = $Keywords[$Key]
        New-DynamicKeyword -Id $KW.Id -Keyword $KW.Keyword -AutoResolve $true
    }

    # Set default outbound to BLOCK
    Write-Log "Setting default outbound to BLOCK..."
    Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Block -DefaultInboundAction Block -Enabled True

    # Create firewall rules
    Write-Log "Creating firewall rules..."

    # DNS (required for FQDN resolution)
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-DNS" -Direction Outbound -Action Allow -Protocol UDP -RemotePort 53 -Profile Any -Enabled True | Out-Null
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-DNS-TCP" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 53 -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: DNS rules"

    # DHCP
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-DHCP" -Direction Outbound -Action Allow -Protocol UDP -RemotePort 67,68 -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: DHCP rule"

    # Azure Bastion (HTTPS/RDP/SSH)
    $AzureKeywords = @($Keywords.AzureBastion.Id, $Keywords.AzurePortal.Id, $Keywords.AzureAuth.Id, $Keywords.AzureGraph.Id, $Keywords.AzureLogin.Id, $Keywords.AzureAD.Id)
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-Azure-HTTPS" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 443 -RemoteDynamicKeywordAddresses $AzureKeywords -Profile Any -Enabled True | Out-Null
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-Azure-RDP" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 3389 -RemoteDynamicKeywordAddresses $Keywords.AzureBastion.Id -Profile Any -Enabled True | Out-Null
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-Azure-SSH" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 22 -RemoteDynamicKeywordAddresses $Keywords.AzureBastion.Id -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: Azure Bastion rules"

    # ShareFile
    $ShareFileKeywords = @($Keywords.ShareFile1.Id, $Keywords.ShareFile2.Id, $Keywords.ShareFile3.Id)
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-ShareFile" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 443 -RemoteDynamicKeywordAddresses $ShareFileKeywords -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: ShareFile rule"

    # Intune
    $IntuneKeywords = @($Keywords.IntuneMgmt.Id, $Keywords.IntuneEnroll.Id, $Keywords.IntuneDM.Id)
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-Intune" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 443 -RemoteDynamicKeywordAddresses $IntuneKeywords -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: Intune rule"

    # Windows Update
    $WUKeywords = @($Keywords.WU1.Id, $Keywords.WU2.Id, $Keywords.WU3.Id)
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-WindowsUpdate" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 443,80 -RemoteDynamicKeywordAddresses $WUKeywords -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: Windows Update rule"

    # Defender
    $DefenderKeywords = @($Keywords.Defender1.Id, $Keywords.Defender2.Id)
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-Defender" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 443 -RemoteDynamicKeywordAddresses $DefenderKeywords -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: Defender rule"

    # Local Network (LAN)
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-LocalNetwork" -Direction Outbound -Action Allow -Protocol Any -RemoteAddress "10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","169.254.0.0/16" -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: Local Network rule"

    # Loopback
    New-NetFirewallRule -DisplayName "DynKeyword-Allow-Loopback" -Direction Outbound -Action Allow -Protocol Any -RemoteAddress "127.0.0.0/8" -Profile Any -Enabled True | Out-Null
    Write-Log "  Created: Loopback rule"

    Write-Log "=== Firewall Configuration Complete ==="
    Write-Log "Dynamic Keywords: $($Keywords.Count)"
    Write-Log "Firewall Rules: $((Get-NetFirewallRule -DisplayName 'DynKeyword-*').Count)"

    exit 0
}
catch {
    Write-Log "FATAL: $($_.Exception.Message)" "ERROR"
    exit 1
}
```

**Script Settings**: Same as above (Run as SYSTEM, 64-bit)

**Assignment**: `Field-Devices-Restricted-Network` group

---

### Step 1.7: Create Proactive Remediation

**Location**: Intune → Devices → Scripts and remediations → Remediations → Create

**Name**: `Detect-Remediate-NetworkRestrictions`

**Detection Script**:

```powershell
<#
.SYNOPSIS
    Detects if network restrictions are properly configured
#>

$Issues = @()

# Check Wi-Fi disabled
$WiFi = Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN' -and $_.Status -ne 'Disabled'
}
if ($WiFi) { $Issues += "Wi-Fi enabled" }

# Check firewall default outbound
$Profiles = Get-NetFirewallProfile | Where-Object { $_.DefaultOutboundAction -ne 'Block' }
if ($Profiles) { $Issues += "Firewall outbound not blocked" }

# Check dynamic keywords exist
$Keywords = Get-NetFirewallDynamicKeywordAddress
if ($Keywords.Count -lt 15) { $Issues += "Missing dynamic keywords" }

# Check blocked destination
$Blocked = Test-NetConnection -ComputerName "www.google.com" -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
if ($Blocked) { $Issues += "SECURITY: Blocked destination reachable" }

if ($Issues.Count -gt 0) {
    Write-Output "NON-COMPLIANT: $($Issues -join '; ')"
    exit 1
} else {
    Write-Output "COMPLIANT"
    exit 0
}
```

**Remediation Script**:

```powershell
<#
.SYNOPSIS
    Remediates network restriction issues
#>

# Disable Wi-Fi
Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN' -and $_.Status -ne 'Disabled'
} | Disable-NetAdapter -Confirm:$false

# Set firewall default
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Block

Write-Output "Remediation completed"
exit 0
```

**Schedule**: Every 1 hour

---

## Use Case 3: Allow USB-Based IP Configuration Tools {#use-case-3}

### Overview

| Requirement | Implementation |
|-------------|----------------|
| Block mass storage | Defender for Endpoint Device Control |
| Allow specific USB tools | VID/PID whitelist |
| Audit USB events | Defender for Endpoint logging |

### Step 3.1: Collect Approved Device VID/PIDs

Run this on a device with approved USB tools connected:

```powershell
Write-Host "=== Approved USB Device Inventory ===" -ForegroundColor Cyan

Get-PnpDevice -Class USB | ForEach-Object {
    if ($_.InstanceId -match 'VID_([0-9A-F]{4})&PID_([0-9A-F]{4})') {
        [PSCustomObject]@{
            Name = $_.FriendlyName
            VID = $Matches[1]
            PID = $Matches[2]
            Status = $_.Status
            ForPolicy = "VID_$($Matches[1])&PID_$($Matches[2])"
        }
    }
} | Where-Object { $_.Name } | Format-Table -AutoSize
```

**Example Approved Devices**:

| Device | VID | PID | Purpose |
|--------|-----|-----|---------|
| FTDI USB-Serial | 0403 | 6001 | IP Configuration |
| Lantronix | 0403 | 6010 | Network Config |
| Prolific USB-Serial | 067B | 2303 | Legacy Serial |
| Silicon Labs CP210x | 10C4 | EA60 | Serial Adapter |

---

### Step 3.2: Create Device Control Policy

**Location**: Intune → Endpoint Security → Attack Surface Reduction → Device Control

#### Create Reusable Settings - Approved Devices

**Location**: Endpoint Security → Attack Surface Reduction → Reusable Settings → Add

**Name**: `Approved-USB-IP-Tools`
**Type**: Device

```xml
<Group Id="{approved-usb-tools}" Type="Device">
    <Name>Approved USB IP Configuration Tools</Name>
    <MatchType>MatchAny</MatchType>
    <DescriptorIdList>
        <VID_PID>0403_6001</VID_PID>
        <VID_PID>0403_6010</VID_PID>
        <VID_PID>067B_2303</VID_PID>
        <VID_PID>10C4_EA60</VID_PID>
        <!-- Add your approved devices -->
    </DescriptorIdList>
</Group>
```

#### Create Reusable Settings - All Removable Storage

**Name**: `All-Removable-Storage`
**Type**: Device

```xml
<Group Id="{all-removable-storage}" Type="Device">
    <Name>All Removable Storage</Name>
    <MatchType>MatchAny</MatchType>
    <DescriptorIdList>
        <PrimaryId>RemovableMediaDevices</PrimaryId>
        <PrimaryId>CdRomDevices</PrimaryId>
        <PrimaryId>WpdDevices</PrimaryId>
    </DescriptorIdList>
</Group>
```

#### Create Device Control Policy

**Name**: `Field-Devices-USB-Whitelist`

**Rule 1: Allow Approved Devices**

```xml
<PolicyRule Id="{allow-approved}">
    <Name>Allow Approved USB Tools</Name>
    <IncludedIdList>
        <GroupId>{approved-usb-tools}</GroupId>
    </IncludedIdList>
    <Entry>
        <Type>Allow</Type>
        <AccessMask>63</AccessMask>
    </Entry>
</PolicyRule>
```

**Rule 2: Block All Other Storage**

```xml
<PolicyRule Id="{block-storage}">
    <Name>Block Removable Storage</Name>
    <IncludedIdList>
        <GroupId>{all-removable-storage}</GroupId>
    </IncludedIdList>
    <ExcludedIdList>
        <GroupId>{approved-usb-tools}</GroupId>
    </ExcludedIdList>
    <Entry>
        <Type>Deny</Type>
        <AccessMask>7</AccessMask>
        <Options>3</Options>
    </Entry>
    <Entry>
        <Type>AuditDenied</Type>
        <AccessMask>7</AccessMask>
        <Options>3</Options>
    </Entry>
</PolicyRule>
```

---

### Step 3.3: Alternative - Settings Catalog (Basic Block)

If you don't have Defender for Endpoint E5:

**Location**: Devices → Configuration → Settings Catalog

| Category | Setting | Value |
|----------|---------|-------|
| Administrative Templates > System > Removable Storage Access | All Removable Storage classes: Deny all access | Enabled |

> ⚠️ This blocks ALL removable storage including approved devices. VID/PID filtering requires Defender E5.

---

## Use Case 4: Support Serial Communication via USB-to-Serial {#use-case-4}

### Overview

| Requirement | Implementation |
|-------------|----------------|
| Install USB-Serial drivers | Win32 app deployment |
| Whitelist serial adapters | Included in UC3 VID/PID list |
| COM port availability | Driver + device control integration |

### Step 4.1: Package USB-Serial Drivers

**Create installation script**: `Install-USBSerialDrivers.ps1`

```powershell
<#
.SYNOPSIS
    Installs USB-Serial drivers for approved adapters
#>

param([string]$DriverPath = $PSScriptRoot)

$LogFile = "$env:ProgramData\Intune\Logs\USBSerialInstall_$(Get-Date -Format 'yyyyMMdd').log"

try {
    # Install FTDI Driver
    $FTDI = Get-ChildItem -Path $DriverPath -Filter "*FTDI*.exe" -Recurse | Select-Object -First 1
    if ($FTDI) {
        Start-Process -FilePath $FTDI.FullName -ArgumentList "/S" -Wait
        Add-Content -Path $LogFile -Value "$(Get-Date): Installed FTDI driver"
    }

    # Install Prolific Driver
    $Prolific = Get-ChildItem -Path $DriverPath -Filter "*PL2303*.exe" -Recurse | Select-Object -First 1
    if ($Prolific) {
        Start-Process -FilePath $Prolific.FullName -ArgumentList "/S /V/qn" -Wait
        Add-Content -Path $LogFile -Value "$(Get-Date): Installed Prolific driver"
    }

    # Install CP210x Driver
    $CP210x = Get-ChildItem -Path $DriverPath -Filter "*CP210x*.exe" -Recurse | Select-Object -First 1
    if ($CP210x) {
        Start-Process -FilePath $CP210x.FullName -ArgumentList "/S" -Wait
        Add-Content -Path $LogFile -Value "$(Get-Date): Installed CP210x driver"
    }

    # Install INF drivers
    Get-ChildItem -Path $DriverPath -Filter "*.inf" -Recurse | ForEach-Object {
        pnputil /add-driver $_.FullName /install
        Add-Content -Path $LogFile -Value "$(Get-Date): Installed INF: $($_.Name)"
    }

    exit 0
}
catch {
    Add-Content -Path $LogFile -Value "$(Get-Date): ERROR - $($_.Exception.Message)"
    exit 1
}
```

### Step 4.2: Deploy as Win32 App

**Location**: Intune → Apps → Windows → Add → Windows app (Win32)

| Field | Value |
|-------|-------|
| Name | USB-Serial Drivers Package |
| Install command | `powershell.exe -ExecutionPolicy Bypass -File Install-USBSerialDrivers.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -File Uninstall-USBSerialDrivers.ps1` |
| Install behavior | System |

**Detection Rule**:

| Type | Path | File |
|------|------|------|
| File | `C:\Windows\System32\drivers` | ftdibus.sys |

---

## Use Case 5: Secure Offline Access {#use-case-5}

### Overview

| Requirement | Implementation |
|-------------|----------------|
| Offline login | Cached credentials (10 logons) |
| Disk encryption | BitLocker with TPM |
| Antivirus protection | Defender with cached signatures |
| Firewall | Persists offline |

### Step 5.1: Configure Cached Credentials

**Location**: Intune → Devices → Configuration → Settings Catalog

**Policy Name**: `Field-Devices-Offline-Login`

| Category | Setting | Value |
|----------|---------|-------|
| Administrative Templates > System > Logon | Number of previous logons to cache | 10 |
| Windows Hello for Business | Use Windows Hello for Business | Enabled |
| Windows Hello for Business | Require security device | Enabled |

---

### Step 5.2: Configure BitLocker

**Location**: Intune → Endpoint Security → Disk Encryption → Create Policy

**Policy Name**: `Field-Devices-BitLocker`

| Setting | Value |
|---------|-------|
| Encrypt devices | Required |
| Startup authentication | Require TPM + PIN |
| Minimum PIN length | 6 |
| Fixed data drive encryption | Enable |
| Recovery key escrow | Azure AD |

---

### Step 5.3: Configure Windows Defender

**Location**: Intune → Endpoint Security → Antivirus → Create Policy

**Policy Name**: `Field-Devices-Defender-Offline`

| Setting | Value |
|---------|-------|
| Real-time protection | Enable |
| Cloud-delivered protection | Enable |
| Signature update interval (hours) | 4 |
| Catch-up quick scan | Allow |
| Catch-up full scan | Allow |

---

### Step 5.4: Deploy Offline Configuration Script

**Location**: Devices → Scripts → Platform scripts

**Script Name**: `Configure-OfflineAccess.ps1`

```powershell
<#
.SYNOPSIS
    Configures device for optimal offline operation
#>

$LogFile = "$env:ProgramData\Intune\Logs\OfflineConfig_$(Get-Date -Format 'yyyyMMdd').log"

try {
    # Set cached logon count
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "CachedLogonsCount" -Value "10" -Type String
    Add-Content -Path $LogFile -Value "$(Get-Date): Set cached logons to 10"

    # Verify BitLocker
    $BitLocker = Get-BitLockerVolume -MountPoint "C:"
    Add-Content -Path $LogFile -Value "$(Get-Date): BitLocker status: $($BitLocker.ProtectionStatus)"

    # Enable Defender catch-up scans
    Set-MpPreference -DisableCatchupQuickScan $false
    Set-MpPreference -DisableCatchupFullScan $false
    Add-Content -Path $LogFile -Value "$(Get-Date): Enabled Defender catch-up scans"

    # Verify firewall
    Get-NetFirewallProfile | Where-Object { -not $_.Enabled } | ForEach-Object {
        Enable-NetFirewallProfile -Name $_.Name
        Add-Content -Path $LogFile -Value "$(Get-Date): Enabled $($_.Name) firewall profile"
    }

    exit 0
}
catch {
    Add-Content -Path $LogFile -Value "$(Get-Date): ERROR - $($_.Exception.Message)"
    exit 1
}
```

---

### Step 5.5: Compliance Policy with Grace Period

**Location**: Intune → Devices → Compliance → Create Policy

**Policy Name**: `Field-Devices-Offline-Compliance`

| Setting | Value |
|---------|-------|
| BitLocker | Require |
| Firewall | Require |
| Antivirus | Require |
| **Mark non-compliant** | **After 7 days** |

> Extended grace period allows offline devices time to reconnect.

---

## Use Case 6: SICE (MSP) Patch Access Validation {#use-case-6}

### Overview

| Requirement | Implementation |
|-------------|----------------|
| VPN connectivity | Always-On or App-Triggered VPN |
| Firewall access | Add SICE endpoints to Dynamic Keywords |
| Agent deployment | Win32 app |
| Monitoring | Proactive remediation |

### Step 6.1: Document SICE Requirements

Contact your MSP to obtain:

| Information | Example | Your Value |
|-------------|---------|------------|
| SICE Server FQDN | patch.msp-sice.com | __________ |
| SICE Portal FQDN | portal.msp-sice.com | __________ |
| Communication Port | TCP 443 | __________ |
| Agent Installer | SICEAgent.msi | __________ |

---

### Step 6.2: Add SICE to Dynamic Keywords

Add to the firewall script from UC1/UC2:

```powershell
# Add SICE endpoints to Keywords hashtable
$Keywords += @{
    SICE1 = @{ Id = "{66666666-6666-6666-6666-666666666661}"; Keyword = "*.msp-sice.com" }
    SICE2 = @{ Id = "{66666666-6666-6666-6666-666666666662}"; Keyword = "patch.msp-provider.com" }
}

# Create SICE firewall rule
$SICEKeywords = @($Keywords.SICE1.Id, $Keywords.SICE2.Id)
New-NetFirewallRule -DisplayName "DynKeyword-Allow-SICE" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 443,8443 -RemoteDynamicKeywordAddresses $SICEKeywords -Profile Any -Enabled True
```

---

### Step 6.3: Configure VPN Profile

**Location**: Intune → Devices → Configuration → Create → VPN

| Setting | Value |
|---------|-------|
| Connection type | IKEv2 |
| Connection name | Corporate VPN - SICE |
| Server address | vpn.company.com |
| Authentication | Certificate |
| Always On | Enable |
| Split tunneling | Disable |

---

### Step 6.4: Deploy SICE Agent

**Location**: Intune → Apps → Windows → Add → Win32

| Field | Value |
|-------|-------|
| Name | SICE Patch Agent |
| Install command | `msiexec /i SICEAgent.msi /qn SERVERURL=https://patch.msp-sice.com` |
| Detection | File exists: `C:\Program Files\SICE\SICEAgent.exe` |

---

### Step 6.5: SICE Connectivity Remediation

**Detection Script**:

```powershell
# Check SICE connectivity
$SICEServer = "patch.msp-sice.com"  # Adjust to your MSP

$Service = Get-Service -Name "SICEAgent" -ErrorAction SilentlyContinue
if (-not $Service -or $Service.Status -ne 'Running') {
    Write-Output "SICE service not running"
    exit 1
}

$Test = Test-NetConnection -ComputerName $SICEServer -Port 443 -WarningAction SilentlyContinue
if (-not $Test.TcpTestSucceeded) {
    Write-Output "Cannot reach SICE server"
    exit 1
}

Write-Output "SICE connectivity OK"
exit 0
```

**Remediation Script**:

```powershell
# Restart SICE service
Restart-Service -Name "SICEAgent" -Force -ErrorAction SilentlyContinue

# Flush DNS
Clear-DnsClientCache

# Trigger VPN if not connected
$VPN = Get-VpnConnection | Where-Object { $_.Name -match 'SICE|Corporate' }
if ($VPN -and $VPN.ConnectionStatus -ne 'Connected') {
    rasdial $VPN.Name
}

exit 0
```

---

## Entra ID Connect Infrastructure Setup {#entra-id-connect-setup}

### Overview

Two virtual machines are required to support Entra ID Connect (Azure AD Connect) deployment for MDM Intune configuration management. These servers synchronize on-premises Active Directory with Microsoft Entra ID, enabling hybrid identity for device management.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ENTRA ID CONNECT ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌────────────────────┐                    ┌────────────────────┐         │
│    │    M7EC Site       │                    │      PH Site       │         │
│    │  M7EC-EC1-CYB-01   │                    │   PH-EC2-CYB-01    │         │
│    │  (Primary)         │◄──── Replication ──►│   (Standby)        │         │
│    └─────────┬──────────┘                    └─────────┬──────────┘         │
│              │                                         │                     │
│              │ LDAPS                                   │ LDAPS               │
│              ▼                                         ▼                     │
│    ┌────────────────────┐                    ┌────────────────────┐         │
│    │ On-Premises AD     │                    │ On-Premises AD     │         │
│    │ Domain Controllers │                    │ Domain Controllers │         │
│    └────────────────────┘                    └────────────────────┘         │
│              │                                         │                     │
│              └─────────────────┬───────────────────────┘                     │
│                                │                                             │
│                                ▼                                             │
│                    ┌────────────────────────┐                               │
│                    │   Microsoft Entra ID   │                               │
│                    │    (Azure AD Cloud)    │                               │
│                    └────────────────────────┘                               │
│                                │                                             │
│                                ▼                                             │
│                    ┌────────────────────────┐                               │
│                    │   Microsoft Intune     │                               │
│                    │   (Device Management)  │                               │
│                    └────────────────────────┘                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### VM Specifications

| Specification | Requirement | Notes |
|---------------|-------------|-------|
| **Operating System** | Windows Server 2022 Standard (or higher) | GUI installation required (Core NOT supported) |
| **CPU** | Dual core, 1.6 GHz minimum | Recommended: 4 cores for production |
| **Memory** | 6 GB RAM | Minimum requirement |
| **Storage** | 70 GB SSD | System + application + logs |
| **Server Type** | Full GUI (Desktop Experience) | Windows Server Core is NOT supported |

### Software & Framework Requirements

| Component | Requirement | Verification Command |
|-----------|-------------|---------------------|
| PowerShell | Version 5.0 or later | `$PSVersionTable.PSVersion` |
| .NET Framework | Version 4.8 or later | `(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -ge 528040` |
| PowerShell Execution Policy | RemoteSigned (recommended) | `Get-ExecutionPolicy` |
| TLS | TLS 1.2 must be enabled | See verification script below |

### Security & Endpoint Protection

| Agent | Requirement | Verification |
|-------|-------------|--------------|
| Rapid7 | Must be installed and running | Check services for Rapid7 agent |
| SentinelOne (S1) | Must be installed and running | Check services for SentinelOne agent |

### VM Naming Convention

| Site | VM Name | Role |
|------|---------|------|
| M7EC | M7EC-EC1-CYB-01 | Primary Entra ID Connect Server |
| PH | PH-EC2-CYB-01 | Standby Entra ID Connect Server |

> **Note**: Final naming to be confirmed by NWR as these are customer-owned assets.

### Network & Security Requirements

| Requirement | Details |
|-------------|---------|
| Domain Join | Servers must be domain joined to on-premises Active Directory |
| AD Connectivity | Entra ID Connect uses LDAPS to connect to Active Directory (signed and encrypted by default) |
| Network Zone | **Tier 0 asset** – must be placed in same zone as Domain Controllers |
| Firewall | Network zones managed via Palo Alto firewall |
| IP Addressing | IP address allocations provided by SICE |

### Security Classification

These VMs are classified as **Tier 0 assets**, equivalent to Domain Controllers. They require:

- Placement in the same network zone as Domain Controllers
- Equivalent security controls and monitoring
- Restricted administrative access following least privilege principles
- Continuous monitoring and logging
- Backup included in disaster recovery schedule

---

### Step 9.1: Pre-Installation Verification Script

Run this script on each VM before installing Entra ID Connect:

```powershell
<#
.SYNOPSIS
    Verifies prerequisites for Entra ID Connect installation
.DESCRIPTION
    Checks OS version, .NET Framework, TLS settings, domain join status,
    and security agent installation
.VERSION
    1.0
#>

#Requires -RunAsAdministrator

$LogPath = "$env:ProgramData\EntraConnect\Logs"
$LogFile = "$LogPath\PreReqCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
    Add-Content -Path $LogFile -Value "[$Timestamp] [$Level] $Message"
    $Color = switch ($Level) { "PASS" { "Green" } "FAIL" { "Red" } "WARN" { "Yellow" } default { "White" } }
    Write-Host "[$Level] $Message" -ForegroundColor $Color
}

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    ENTRA ID CONNECT - PRE-INSTALLATION VERIFICATION          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$Results = @()

# ============================================
# 1. Operating System Check
# ============================================
Write-Host "[1] Operating System" -ForegroundColor Yellow

$OS = Get-CimInstance Win32_OperatingSystem
$OSVersion = $OS.Caption
$Build = [int]$OS.BuildNumber
$ServerCore = -not (Get-WindowsFeature Server-Gui-Shell -ErrorAction SilentlyContinue).Installed

# Check for Windows Server 2022+
$OSValid = $OS.Caption -match "Windows Server 202[2-9]|Windows Server 203"
$Results += [PSCustomObject]@{ Check = "Windows Server 2022+"; Status = $(if ($OSValid) { "PASS" } else { "FAIL" }) }
Write-Log "OS Version: $OSVersion (Build $Build)" $(if ($OSValid) { "PASS" } else { "FAIL" })

# Check GUI installation
$GUIValid = -not $ServerCore
$Results += [PSCustomObject]@{ Check = "GUI Installation"; Status = $(if ($GUIValid) { "PASS" } else { "FAIL" }) }
Write-Log "GUI Installation: $(if ($GUIValid) { 'Desktop Experience installed' } else { 'Server Core detected - NOT SUPPORTED' })" $(if ($GUIValid) { "PASS" } else { "FAIL" })

# ============================================
# 2. Hardware Resources
# ============================================
Write-Host "`n[2] Hardware Resources" -ForegroundColor Yellow

$CPU = Get-CimInstance Win32_Processor
$Memory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object @{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}}

$CPUValid = $CPU.NumberOfCores -ge 2
$Results += [PSCustomObject]@{ Check = "CPU Cores (2+ required)"; Status = $(if ($CPUValid) { "PASS" } else { "FAIL" }) }
Write-Log "CPU: $($CPU.NumberOfCores) cores @ $([math]::Round($CPU.MaxClockSpeed/1000,2)) GHz" $(if ($CPUValid) { "PASS" } else { "FAIL" })

$MemoryValid = $Memory -ge 6
$Results += [PSCustomObject]@{ Check = "RAM (6GB+ required)"; Status = $(if ($MemoryValid) { "PASS" } else { "FAIL" }) }
Write-Log "Memory: ${Memory}GB RAM" $(if ($MemoryValid) { "PASS" } else { "FAIL" })

$DiskValid = $Disk.FreeGB -ge 70
$Results += [PSCustomObject]@{ Check = "Disk Space (70GB+ required)"; Status = $(if ($DiskValid) { "PASS" } else { "WARN" }) }
Write-Log "Disk Free: $($Disk.FreeGB)GB" $(if ($DiskValid) { "PASS" } else { "WARN" })

# ============================================
# 3. .NET Framework
# ============================================
Write-Host "`n[3] .NET Framework" -ForegroundColor Yellow

$DotNet = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue
$DotNetRelease = $DotNet.Release
$DotNetVersion = switch ($DotNetRelease) {
    { $_ -ge 533320 } { "4.8.1+" }
    { $_ -ge 528040 } { "4.8" }
    { $_ -ge 461808 } { "4.7.2" }
    { $_ -ge 461308 } { "4.7.1" }
    { $_ -ge 460798 } { "4.7" }
    default { "Below 4.7" }
}

$DotNetValid = $DotNetRelease -ge 528040  # .NET 4.8+
$Results += [PSCustomObject]@{ Check = ".NET Framework 4.8+"; Status = $(if ($DotNetValid) { "PASS" } else { "FAIL" }) }
Write-Log ".NET Framework: $DotNetVersion (Release $DotNetRelease)" $(if ($DotNetValid) { "PASS" } else { "FAIL" })

# ============================================
# 4. PowerShell Version
# ============================================
Write-Host "`n[4] PowerShell" -ForegroundColor Yellow

$PSVer = $PSVersionTable.PSVersion
$PSValid = $PSVer.Major -ge 5
$Results += [PSCustomObject]@{ Check = "PowerShell 5.0+"; Status = $(if ($PSValid) { "PASS" } else { "FAIL" }) }
Write-Log "PowerShell: $($PSVer.ToString())" $(if ($PSValid) { "PASS" } else { "FAIL" })

$ExecPolicy = Get-ExecutionPolicy
$ExecValid = $ExecPolicy -in @('RemoteSigned', 'Unrestricted', 'Bypass')
$Results += [PSCustomObject]@{ Check = "Execution Policy (RemoteSigned+)"; Status = $(if ($ExecValid) { "PASS" } else { "WARN" }) }
Write-Log "Execution Policy: $ExecPolicy" $(if ($ExecValid) { "PASS" } else { "WARN" })

# ============================================
# 5. TLS 1.2 Configuration
# ============================================
Write-Host "`n[5] TLS 1.2 Configuration" -ForegroundColor Yellow

# Check TLS 1.2 client enabled
$TLS12Client = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -ErrorAction SilentlyContinue
$TLS12Server = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -ErrorAction SilentlyContinue

# TLS 1.2 is enabled by default on Server 2022, check if explicitly disabled
$TLS12Disabled = ($TLS12Client.Enabled -eq 0) -or ($TLS12Server.Enabled -eq 0)
$TLS12DisabledByDefault = ($TLS12Client.DisabledByDefault -eq 1) -or ($TLS12Server.DisabledByDefault -eq 1)

$TLSValid = (-not $TLS12Disabled) -and (-not $TLS12DisabledByDefault)
$Results += [PSCustomObject]@{ Check = "TLS 1.2 Enabled"; Status = $(if ($TLSValid) { "PASS" } else { "FAIL" }) }
Write-Log "TLS 1.2: $(if ($TLSValid) { 'Enabled' } else { 'Disabled or misconfigured' })" $(if ($TLSValid) { "PASS" } else { "FAIL" })

# Check .NET strong crypto
$DotNetCrypto64 = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -ErrorAction SilentlyContinue
$DotNetCrypto32 = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -ErrorAction SilentlyContinue

$StrongCryptoEnabled = ($DotNetCrypto64.SchUseStrongCrypto -eq 1) -or ($DotNetCrypto32.SchUseStrongCrypto -eq 1)
$Results += [PSCustomObject]@{ Check = ".NET Strong Crypto"; Status = $(if ($StrongCryptoEnabled) { "PASS" } else { "WARN" }) }
Write-Log ".NET Strong Crypto: $(if ($StrongCryptoEnabled) { 'Enabled' } else { 'Not explicitly enabled (may use default)' })" $(if ($StrongCryptoEnabled) { "PASS" } else { "WARN" })

# ============================================
# 6. Domain Membership
# ============================================
Write-Host "`n[6] Domain Membership" -ForegroundColor Yellow

$CS = Get-CimInstance Win32_ComputerSystem
$DomainJoined = $CS.PartOfDomain
$Domain = $CS.Domain
$Results += [PSCustomObject]@{ Check = "Domain Joined"; Status = $(if ($DomainJoined) { "PASS" } else { "FAIL" }) }
Write-Log "Domain: $(if ($DomainJoined) { $Domain } else { 'NOT JOINED - REQUIRED' })" $(if ($DomainJoined) { "PASS" } else { "FAIL" })

# Test AD connectivity
if ($DomainJoined) {
    try {
        $DC = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers | Select-Object -First 1
        $ADConnected = $null -ne $DC
        $Results += [PSCustomObject]@{ Check = "AD Connectivity"; Status = $(if ($ADConnected) { "PASS" } else { "FAIL" }) }
        Write-Log "AD Connectivity: Connected to $($DC.Name)" "PASS"
    }
    catch {
        $Results += [PSCustomObject]@{ Check = "AD Connectivity"; Status = "FAIL" }
        Write-Log "AD Connectivity: Unable to contact domain controller" "FAIL"
    }
}

# ============================================
# 7. Security Agents
# ============================================
Write-Host "`n[7] Security Agents" -ForegroundColor Yellow

# Rapid7 Check
$R7Service = Get-Service -Name "ir_agent" -ErrorAction SilentlyContinue
$R7Installed = $null -ne $R7Service
$R7Running = $R7Service.Status -eq 'Running'
$Results += [PSCustomObject]@{ Check = "Rapid7 Agent"; Status = $(if ($R7Running) { "PASS" } elseif ($R7Installed) { "WARN" } else { "FAIL" }) }
Write-Log "Rapid7: $(if ($R7Running) { 'Installed and Running' } elseif ($R7Installed) { 'Installed but NOT Running' } else { 'NOT INSTALLED - REQUIRED' })" $(if ($R7Running) { "PASS" } elseif ($R7Installed) { "WARN" } else { "FAIL" })

# SentinelOne Check
$S1Service = Get-Service -Name "SentinelAgent" -ErrorAction SilentlyContinue
$S1Installed = $null -ne $S1Service
$S1Running = $S1Service.Status -eq 'Running'
$Results += [PSCustomObject]@{ Check = "SentinelOne Agent"; Status = $(if ($S1Running) { "PASS" } elseif ($S1Installed) { "WARN" } else { "FAIL" }) }
Write-Log "SentinelOne: $(if ($S1Running) { 'Installed and Running' } elseif ($S1Installed) { 'Installed but NOT Running' } else { 'NOT INSTALLED - REQUIRED' })" $(if ($S1Running) { "PASS" } elseif ($S1Installed) { "WARN" } else { "FAIL" })

# ============================================
# 8. Required Ports
# ============================================
Write-Host "`n[8] Network Connectivity" -ForegroundColor Yellow

$RequiredEndpoints = @(
    @{ Name = "Azure AD"; Host = "login.microsoftonline.com"; Port = 443 },
    @{ Name = "Azure AD Graph"; Host = "graph.windows.net"; Port = 443 },
    @{ Name = "MS Graph"; Host = "graph.microsoft.com"; Port = 443 },
    @{ Name = "Azure AD Connect Health"; Host = "management.azure.com"; Port = 443 }
)

foreach ($Endpoint in $RequiredEndpoints) {
    $Test = Test-NetConnection -ComputerName $Endpoint.Host -Port $Endpoint.Port -WarningAction SilentlyContinue -InformationLevel Quiet
    $Status = if ($Test) { "PASS" } else { "WARN" }
    $Results += [PSCustomObject]@{ Check = "Connectivity to $($Endpoint.Name)"; Status = $Status }
    Write-Log "  $($Endpoint.Name) ($($Endpoint.Host):$($Endpoint.Port)): $(if ($Test) { 'Reachable' } else { 'Unreachable' })" $Status
}

# ============================================
# Summary
# ============================================
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         SUMMARY                               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$PassCount = ($Results | Where-Object { $_.Status -eq "PASS" }).Count
$FailCount = ($Results | Where-Object { $_.Status -eq "FAIL" }).Count
$WarnCount = ($Results | Where-Object { $_.Status -eq "WARN" }).Count

Write-Host "  PASS: $PassCount  |  FAIL: $FailCount  |  WARN: $WarnCount" -ForegroundColor $(if ($FailCount -eq 0) { 'Green' } else { 'Red' })

if ($FailCount -eq 0) {
    Write-Host "`n  ✓ Server is READY for Entra ID Connect installation" -ForegroundColor Green
} else {
    Write-Host "`n  ✗ Server has $FailCount FAILED checks - remediation required before installation" -ForegroundColor Red
}

Write-Host "`nLog file: $LogFile" -ForegroundColor Gray
```

---

### Step 9.2: Configure TLS 1.2 (If Required)

If TLS 1.2 is not properly configured, run this script:

```powershell
<#
.SYNOPSIS
    Enables TLS 1.2 for Entra ID Connect
.DESCRIPTION
    Configures registry settings for TLS 1.2 and .NET strong cryptography
.WARNING
    Requires reboot after execution
#>

#Requires -RunAsAdministrator

Write-Host "Configuring TLS 1.2 for Entra ID Connect..." -ForegroundColor Cyan

# Enable TLS 1.2 - Server
$TLS12ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
if (-not (Test-Path $TLS12ServerPath)) { New-Item -Path $TLS12ServerPath -Force | Out-Null }
Set-ItemProperty -Path $TLS12ServerPath -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $TLS12ServerPath -Name "DisabledByDefault" -Value 0 -Type DWord
Write-Host "  TLS 1.2 Server: Enabled" -ForegroundColor Green

# Enable TLS 1.2 - Client
$TLS12ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"
if (-not (Test-Path $TLS12ClientPath)) { New-Item -Path $TLS12ClientPath -Force | Out-Null }
Set-ItemProperty -Path $TLS12ClientPath -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $TLS12ClientPath -Name "DisabledByDefault" -Value 0 -Type DWord
Write-Host "  TLS 1.2 Client: Enabled" -ForegroundColor Green

# Configure .NET Framework to use strong crypto (64-bit)
$DotNet64Path = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319"
Set-ItemProperty -Path $DotNet64Path -Name "SchUseStrongCrypto" -Value 1 -Type DWord
Write-Host "  .NET 4.x (64-bit) Strong Crypto: Enabled" -ForegroundColor Green

# Configure .NET Framework to use strong crypto (32-bit)
$DotNet32Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319"
if (Test-Path $DotNet32Path) {
    Set-ItemProperty -Path $DotNet32Path -Name "SchUseStrongCrypto" -Value 1 -Type DWord
    Write-Host "  .NET 4.x (32-bit) Strong Crypto: Enabled" -ForegroundColor Green
}

Write-Host "`nTLS 1.2 configuration complete. A REBOOT IS REQUIRED." -ForegroundColor Yellow
Write-Host "Run: Restart-Computer -Force" -ForegroundColor Yellow
```

---

### Step 9.3: Install Entra ID Connect

#### Download Location

Download Entra ID Connect from the Microsoft Download Center:
- **URL**: https://www.microsoft.com/en-us/download/details.aspx?id=47594
- **File**: `AzureADConnect.msi`

#### Installation Steps

1. **Launch Installation**
   - Run `AzureADConnect.msi` as Administrator
   - Accept license terms

2. **Choose Installation Type**
   - Select **Customize** for enterprise deployments
   - This allows granular control over sync options

3. **Install Required Components**
   - Install location: `C:\Program Files\Microsoft Azure AD Sync`
   - Check: **Use an existing SQL Server** (if using remote SQL)
   - Check: **Use an existing service account** (recommended for Tier 0)

4. **User Sign-In Configuration**
   - Select **Password Hash Synchronization** (recommended for simplicity)
   - Alternative: **Pass-through Authentication** or **Federation with AD FS**

5. **Connect to Azure AD**
   - Enter Global Administrator or Hybrid Identity Administrator credentials
   - This account should be a dedicated sync service account

6. **Connect to AD DS**
   - Enter Enterprise Admin credentials (for initial setup only)
   - Or use a dedicated service account with required permissions

7. **Azure AD Sign-In Configuration**
   - Select the UPN suffix that matches your Azure AD tenant
   - Configure UPN routing if required

8. **Domain and OU Filtering**
   - Select specific OUs to synchronize (recommended)
   - Avoid syncing service accounts or system OUs

9. **Uniquely Identifying Users**
   - Default: `objectGUID` (recommended)
   - Alternative: `mS-DS-ConsistencyGuid` for migrations

10. **Filter Users and Devices**
    - Optional: Filter by group membership for pilot deployments

11. **Optional Features**
    - **Exchange Hybrid Deployment**: Enable if using Exchange
    - **Password Writeback**: Enable for self-service password reset
    - **Group Writeback**: Enable for M365 Groups
    - **Device Writeback**: Enable for Hybrid Azure AD Join

12. **Service Account Configuration**
    - **ADSync Service Account**: Use managed service account or dedicated domain account
    - **AD DS Connector Account**: Dedicated service account with minimal permissions

13. **Complete Installation**
    - Review configuration summary
    - Start synchronization after installation

---

### Step 9.4: Configure Service Connection Point (SCP) for Hybrid Azure AD Join

The Service Connection Point enables Windows devices to discover the Entra ID tenant for Hybrid Azure AD Join.

#### Option A: Configure SCP via Entra ID Connect (Recommended)

During Entra ID Connect installation:
1. On the **Device options** page, select **Configure Hybrid Azure AD join**
2. Select the forest(s) to configure
3. Enter Enterprise Admin credentials
4. The wizard will create the SCP in AD

#### Option B: Configure SCP via PowerShell (Manual)

```powershell
<#
.SYNOPSIS
    Manually configures Service Connection Point for Hybrid Azure AD Join
.DESCRIPTION
    Creates SCP in Active Directory Configuration partition
.NOTES
    Run on Domain Controller or with Enterprise Admin credentials
#>

#Requires -Modules ActiveDirectory

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantID,  # Azure AD Tenant ID (GUID)

    [Parameter(Mandatory=$true)]
    [string]$TenantName  # e.g., contoso.onmicrosoft.com
)

Import-Module ActiveDirectory

# Get the configuration naming context
$ConfigNC = (Get-ADRootDSE).configurationNamingContext
$ServicesCN = "CN=Services,$ConfigNC"
$DRSPath = "CN=Device Registration Configuration,$ServicesCN"

# Create Device Registration Configuration container if it doesn't exist
if (-not (Get-ADObject -Filter { distinguishedName -eq $DRSPath } -ErrorAction SilentlyContinue)) {
    New-ADObject -Name "Device Registration Configuration" -Type container -Path $ServicesCN
    Write-Host "Created Device Registration Configuration container" -ForegroundColor Green
}

# Create Service Connection Point
$SCPPath = "CN=62a0ff2e-97b9-4513-943f-0d221bd30080,$DRSPath"

$Keywords = @(
    "azureADId:$TenantID",
    "azureADName:$TenantName"
)

if (Get-ADObject -Filter { distinguishedName -eq $SCPPath } -ErrorAction SilentlyContinue) {
    # Update existing SCP
    Set-ADObject -Identity $SCPPath -Replace @{ keywords = $Keywords }
    Write-Host "Updated existing Service Connection Point" -ForegroundColor Yellow
} else {
    # Create new SCP
    New-ADObject -Name "62a0ff2e-97b9-4513-943f-0d221bd30080" -Type serviceConnectionPoint -Path $DRSPath -OtherAttributes @{
        keywords = $Keywords
    }
    Write-Host "Created new Service Connection Point" -ForegroundColor Green
}

Write-Host "`nService Connection Point configured successfully" -ForegroundColor Green
Write-Host "Tenant ID: $TenantID" -ForegroundColor Cyan
Write-Host "Tenant Name: $TenantName" -ForegroundColor Cyan
```

#### Option C: Configure SCP via GPO (Controlled Rollout)

For staged rollouts, use GPO instead of SCP:

**GPO Path**: Computer Configuration → Policies → Administrative Templates → Windows Components → Device Registration

| Setting | Value |
|---------|-------|
| Register domain-joined computers as devices | Enabled |
| Tenant ID | `{your-tenant-id-guid}` |
| Tenant Name | `contoso.onmicrosoft.com` |

---

### Step 9.5: Verify Entra ID Connect Synchronization

```powershell
<#
.SYNOPSIS
    Verifies Entra ID Connect synchronization status
#>

# Import ADSync module
Import-Module ADSync

# Check sync scheduler
$Scheduler = Get-ADSyncScheduler
Write-Host "Sync Scheduler Status:" -ForegroundColor Yellow
Write-Host "  Sync Cycle Enabled: $($Scheduler.SyncCycleEnabled)" -ForegroundColor $(if ($Scheduler.SyncCycleEnabled) { 'Green' } else { 'Red' })
Write-Host "  Sync Interval: $($Scheduler.CurrentlyEffectiveSyncCycleInterval)" -ForegroundColor Cyan
Write-Host "  Next Sync Time: $($Scheduler.NextSyncCycleStartTimeInUTC) UTC" -ForegroundColor Cyan

# Check last sync
$LastSync = Get-ADSyncConnectorRunStatus
Write-Host "`nLast Sync Status:" -ForegroundColor Yellow
$LastSync | Format-Table ConnectorName, RunState, StartTime, EndTime -AutoSize

# Check for sync errors
$SyncErrors = Get-ADSyncCSObject -ConnectorName "your-ad-connector" -ObjectType user | Where-Object { $_.Error }
if ($SyncErrors) {
    Write-Host "`nSync Errors Found: $($SyncErrors.Count)" -ForegroundColor Red
} else {
    Write-Host "`nNo sync errors detected" -ForegroundColor Green
}

# Trigger manual sync (Delta)
# Start-ADSyncSyncCycle -PolicyType Delta

# Trigger manual sync (Full)
# Start-ADSyncSyncCycle -PolicyType Initial
```

---

### Step 9.6: Configure Backup

Entra ID Connect servers must be included in backup schedules:

| Backup Component | Path/Method | Frequency |
|-----------------|-------------|-----------|
| SQL Database | `C:\Program Files\Microsoft Azure AD Sync\Data` | Daily |
| Configuration | Export via `Get-ADSyncServerConfiguration` | After changes |
| Certificates | Certificate store backup | Weekly |
| Full Server | Windows Server Backup or enterprise backup | Daily |

**Export Configuration Script**:

```powershell
# Export Entra ID Connect configuration for disaster recovery
$ExportPath = "C:\EntraConnectBackup\$(Get-Date -Format 'yyyyMMdd')"
New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null

# Export server configuration
Get-ADSyncServerConfiguration -Path $ExportPath

Write-Host "Configuration exported to: $ExportPath" -ForegroundColor Green
```

---

### Approval Status

| Approval Type | Status | Approver | Date |
|--------------|--------|----------|------|
| Cyber Security Approval | Approved with conditions | Avi Lipa | 04/Nov/25 |
| Configuration Confirmation | Confirmed | ORRO | 10/Nov/25 |

**Cyber Security Conditions**:
- Rapid7 and SentinelOne agents must be installed
- ORRO to provide hardening guidance
- Confirm if SICE GPOs can be used or if ORRO will supply own hardening configuration

### Pending Action Items

| Action | Responsible Party | Status |
|--------|-------------------|--------|
| Provide IP address allocations | SICE | Pending |
| Confirm network zone configuration (Palo Alto) | SICE | Pending |
| Confirm hardening requirements/GPOs | ORRO | Pending |
| Configure backup schedule | SICE | Pending |
| Install R7 and S1 agents | SICE | Pending |
| **Configure firewall rules** | **SICE** | **CRITICAL - Blocking** |

---

## Firewall Requirements {#firewall-requirements}

> **CRITICAL**: Firewall configuration is required before Entra Connect installation can proceed. See the complete firewall request document: `NWR_Firewall_Request_SICE.md`

### Quick Reference - Critical Endpoints

The following endpoints must be accessible from Entra Connect servers **before** installation:

#### Authentication (TCP 443) - CRITICAL

| Endpoint | Purpose |
|----------|---------|
| `login.microsoftonline.com` | **Primary Azure AD authentication** |
| `login.microsoft.com` | Microsoft authentication |
| `login.windows.net` | Legacy authentication |
| `graph.microsoft.com` | Microsoft Graph API |
| `graph.windows.net` | Azure AD Graph API |
| `adminwebservice.microsoftonline.com` | Admin services |

#### Certificate Validation (TCP 80) - CRITICAL

| Endpoint | Purpose |
|----------|---------|
| `crl.microsoft.com` | Microsoft CRL |
| `crl3.digicert.com` | DigiCert CRL |
| `ocsp.digicert.com` | DigiCert OCSP |
| `ocsp.msocsp.com` | Microsoft OCSP |

### Verification Script

Run this on Entra Connect servers to verify connectivity:

```powershell
$Critical = @(
    @{ Host = "login.microsoftonline.com"; Port = 443 },
    @{ Host = "graph.microsoft.com"; Port = 443 },
    @{ Host = "adminwebservice.microsoftonline.com"; Port = 443 },
    @{ Host = "crl.microsoft.com"; Port = 80 }
)

foreach ($EP in $Critical) {
    $Result = Test-NetConnection -ComputerName $EP.Host -Port $EP.Port -WarningAction SilentlyContinue -InformationLevel Quiet
    Write-Host "$($EP.Host):$($EP.Port) - $(if ($Result) { 'OK' } else { 'BLOCKED' })" -ForegroundColor $(if ($Result) { 'Green' } else { 'Red' })
}
```

### Complete Firewall Documentation

For the complete list of all required endpoints for:
- Entra Connect servers (38 rules)
- Intune-managed endpoints (41 rules)
- Field device application access (Azure Bastion, ShareFile, SICE)

See: **[NWR_Firewall_Request_SICE.md](NWR_Firewall_Request_SICE.md)**

---

## Deployment Sequence {#deployment-sequence}

### Recommended Rollout Order

```
Week 1-2: Foundation
├── Create device groups
├── UC5: Secure Offline Access (BitLocker, Defender, cached creds)
└── Deploy prerequisite policies (Network Protection, DoH disable)

Week 3-4: Network Restrictions
├── UC1/UC2: Disable Wi-Fi + Dynamic Keyword Firewall
├── Test connectivity to Azure Bastion and ShareFile
└── Validate blocked destinations

Week 5-6: USB Controls
├── UC3: USB Device Whitelisting
├── UC4: USB-Serial Driver Deployment
└── Test approved devices work, others blocked

Week 7-8: MSP Integration
├── UC6: SICE VPN and Agent
├── Validate patch delivery
└── Monitor compliance

Week 9+: Monitoring & Tuning
├── Review proactive remediation results
├── Adjust firewall rules as needed
└── Document exceptions
```

### Pilot Group Strategy

| Phase | Size | Duration | Success Criteria |
|-------|------|----------|------------------|
| Pilot 1 | 5-10 IT staff | 1 week | All use cases functional |
| Pilot 2 | 25-50 early adopters | 2 weeks | <5% support tickets |
| Production | All field devices | Rolling | <2% issues |

---

## Testing and Validation {#testing-and-validation}

### Master Validation Script

```powershell
<#
.SYNOPSIS
    Comprehensive validation of all use cases
#>

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     FIELD DEVICE NETWORK RESTRICTION - VALIDATION            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$Results = @()

# ============================================
# UC1/UC2: Network Restrictions
# ============================================
Write-Host "`n[UC1/UC2] Network Restrictions" -ForegroundColor Yellow

# Wi-Fi Status
$WiFi = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|Wireless' }
$WiFiDisabled = ($WiFi | Where-Object { $_.Status -eq 'Disabled' }).Count -eq $WiFi.Count
$Results += [PSCustomObject]@{ Test = "Wi-Fi Disabled"; Status = $(if ($WiFiDisabled -or -not $WiFi) { "PASS" } else { "FAIL" }) }
Write-Host "  Wi-Fi: $(if ($WiFiDisabled -or -not $WiFi) { 'Disabled ✓' } else { 'ENABLED ✗' })" -ForegroundColor $(if ($WiFiDisabled -or -not $WiFi) { 'Green' } else { 'Red' })

# Ethernet Status
$Ethernet = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Ethernet' -and $_.InterfaceDescription -notmatch 'Virtual' }
$EthernetOK = $Ethernet -and ($Ethernet.Status -ne 'Disabled')
$Results += [PSCustomObject]@{ Test = "Ethernet Enabled"; Status = $(if ($EthernetOK) { "PASS" } else { "WARN" }) }
Write-Host "  Ethernet: $(if ($EthernetOK) { 'Enabled ✓' } else { 'Check status' })" -ForegroundColor $(if ($EthernetOK) { 'Green' } else { 'Yellow' })

# Cellular Status
$Cellular = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Cellular|WWAN|5G|LTE' }
if ($Cellular) {
    $CellularOK = $Cellular.Status -ne 'Disabled'
    $Results += [PSCustomObject]@{ Test = "Cellular Enabled"; Status = $(if ($CellularOK) { "PASS" } else { "WARN" }) }
    Write-Host "  Cellular: $(if ($CellularOK) { 'Enabled ✓' } else { 'Disabled' })" -ForegroundColor $(if ($CellularOK) { 'Green' } else { 'Yellow' })
} else {
    Write-Host "  Cellular: Not present" -ForegroundColor Gray
}

# Firewall Default
$FWBlock = (Get-NetFirewallProfile | Where-Object { $_.DefaultOutboundAction -eq 'Block' }).Count -eq 3
$Results += [PSCustomObject]@{ Test = "Firewall Outbound Block"; Status = $(if ($FWBlock) { "PASS" } else { "FAIL" }) }
Write-Host "  Firewall Default Outbound: $(if ($FWBlock) { 'BLOCK ✓' } else { 'ALLOW ✗' })" -ForegroundColor $(if ($FWBlock) { 'Green' } else { 'Red' })

# Dynamic Keywords
$Keywords = (Get-NetFirewallDynamicKeywordAddress).Count
$KeywordsOK = $Keywords -ge 15
$Results += [PSCustomObject]@{ Test = "Dynamic Keywords"; Status = $(if ($KeywordsOK) { "PASS" } else { "FAIL" }) }
Write-Host "  Dynamic Keywords: $Keywords $(if ($KeywordsOK) { '✓' } else { '✗ (need 15+)' })" -ForegroundColor $(if ($KeywordsOK) { 'Green' } else { 'Red' })

# Connectivity Tests
Write-Host "`n  Connectivity Tests:" -ForegroundColor Cyan

$AllowedHosts = @(
    @{ Name = "Azure Bastion"; Host = "portal.azure.com" },
    @{ Name = "ShareFile"; Host = "www.sharefile.com" },
    @{ Name = "Microsoft Auth"; Host = "login.microsoftonline.com" }
)

foreach ($Test in $AllowedHosts) {
    $Result = Test-NetConnection -ComputerName $Test.Host -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
    $Status = if ($Result) { "PASS" } else { "FAIL" }
    $Results += [PSCustomObject]@{ Test = "Allow $($Test.Name)"; Status = $Status }
    Write-Host "    $($Test.Name): $(if ($Result) { 'Reachable ✓' } else { 'BLOCKED ✗' })" -ForegroundColor $(if ($Result) { 'Green' } else { 'Red' })
}

$BlockedHosts = @("www.google.com", "www.facebook.com")
foreach ($Host in $BlockedHosts) {
    $Result = Test-NetConnection -ComputerName $Host -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
    $Status = if (-not $Result) { "PASS" } else { "FAIL" }
    $Results += [PSCustomObject]@{ Test = "Block $Host"; Status = $Status }
    Write-Host "    $Host : $(if (-not $Result) { 'Blocked ✓' } else { 'REACHABLE ✗' })" -ForegroundColor $(if (-not $Result) { 'Green' } else { 'Red' })
}

# ============================================
# UC3/UC4: USB Controls
# ============================================
Write-Host "`n[UC3/UC4] USB Controls" -ForegroundColor Yellow

# Check Defender Device Control
$MDE = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
$MDERunning = $MDE -and $MDE.Status -eq 'Running'
$Results += [PSCustomObject]@{ Test = "Defender for Endpoint"; Status = $(if ($MDERunning) { "PASS" } else { "WARN" }) }
Write-Host "  Defender for Endpoint: $(if ($MDERunning) { 'Running ✓' } else { 'Not running' })" -ForegroundColor $(if ($MDERunning) { 'Green' } else { 'Yellow' })

# Check USB-Serial drivers
$SerialDrivers = Test-Path "C:\Windows\System32\drivers\ftdibus.sys"
$Results += [PSCustomObject]@{ Test = "USB-Serial Drivers"; Status = $(if ($SerialDrivers) { "PASS" } else { "WARN" }) }
Write-Host "  USB-Serial Drivers: $(if ($SerialDrivers) { 'Installed ✓' } else { 'Not found' })" -ForegroundColor $(if ($SerialDrivers) { 'Green' } else { 'Yellow' })

# ============================================
# UC5: Offline Access
# ============================================
Write-Host "`n[UC5] Secure Offline Access" -ForegroundColor Yellow

# Cached logons
$CachedLogons = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "CachedLogonsCount" -ErrorAction SilentlyContinue).CachedLogonsCount
$CachedOK = [int]$CachedLogons -ge 5
$Results += [PSCustomObject]@{ Test = "Cached Logons"; Status = $(if ($CachedOK) { "PASS" } else { "FAIL" }) }
Write-Host "  Cached Logons: $CachedLogons $(if ($CachedOK) { '✓' } else { '✗' })" -ForegroundColor $(if ($CachedOK) { 'Green' } else { 'Red' })

# BitLocker
$BitLocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
$BitLockerOK = $BitLocker -and $BitLocker.ProtectionStatus -eq 'On'
$Results += [PSCustomObject]@{ Test = "BitLocker"; Status = $(if ($BitLockerOK) { "PASS" } else { "FAIL" }) }
Write-Host "  BitLocker: $(if ($BitLockerOK) { 'Enabled ✓' } else { 'NOT ENABLED ✗' })" -ForegroundColor $(if ($BitLockerOK) { 'Green' } else { 'Red' })

# Defender
$Defender = Get-MpComputerStatus
$DefenderOK = $Defender.RealTimeProtectionEnabled
$Results += [PSCustomObject]@{ Test = "Defender Real-Time"; Status = $(if ($DefenderOK) { "PASS" } else { "FAIL" }) }
Write-Host "  Defender Real-Time: $(if ($DefenderOK) { 'Enabled ✓' } else { 'DISABLED ✗' })" -ForegroundColor $(if ($DefenderOK) { 'Green' } else { 'Red' })

$SignatureAge = ((Get-Date) - $Defender.AntivirusSignatureLastUpdated).Days
$SigOK = $SignatureAge -lt 7
$Results += [PSCustomObject]@{ Test = "Defender Signatures"; Status = $(if ($SigOK) { "PASS" } else { "WARN" }) }
Write-Host "  Defender Signatures: $SignatureAge days old $(if ($SigOK) { '✓' } else { '(stale)' })" -ForegroundColor $(if ($SigOK) { 'Green' } else { 'Yellow' })

# ============================================
# UC6: SICE Access (if applicable)
# ============================================
Write-Host "`n[UC6] SICE/MSP Access" -ForegroundColor Yellow

$SICEService = Get-Service -Name "SICEAgent" -ErrorAction SilentlyContinue
if ($SICEService) {
    $SICERunning = $SICEService.Status -eq 'Running'
    $Results += [PSCustomObject]@{ Test = "SICE Agent"; Status = $(if ($SICERunning) { "PASS" } else { "FAIL" }) }
    Write-Host "  SICE Agent: $(if ($SICERunning) { 'Running ✓' } else { 'NOT RUNNING ✗' })" -ForegroundColor $(if ($SICERunning) { 'Green' } else { 'Red' })
} else {
    Write-Host "  SICE Agent: Not installed" -ForegroundColor Gray
}

# ============================================
# Summary
# ============================================
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         SUMMARY                               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$PassCount = ($Results | Where-Object { $_.Status -eq "PASS" }).Count
$FailCount = ($Results | Where-Object { $_.Status -eq "FAIL" }).Count
$WarnCount = ($Results | Where-Object { $_.Status -eq "WARN" }).Count

Write-Host "  PASS: $PassCount  |  FAIL: $FailCount  |  WARN: $WarnCount" -ForegroundColor $(if ($FailCount -eq 0) { 'Green' } else { 'Red' })

if ($FailCount -eq 0) {
    Write-Host "`n  ✓ Device is COMPLIANT with all use cases" -ForegroundColor Green
} else {
    Write-Host "`n  ✗ Device has $FailCount FAILED checks - remediation required" -ForegroundColor Red
}
```

---

## Rollback Procedures {#rollback-procedures}

### Master Rollback Script

```powershell
<#
.SYNOPSIS
    Complete rollback of all field device restrictions
.WARNING
    This will remove ALL security restrictions - use only in emergency
#>

param([switch]$Confirm)

if (-not $Confirm) {
    Write-Host "WARNING: This will remove all network and security restrictions!" -ForegroundColor Red
    Write-Host "Run with -Confirm switch to proceed" -ForegroundColor Yellow
    exit 1
}

$LogFile = "$env:ProgramData\Intune\Logs\FullRollback_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Output $Message
}

Write-Log "=== Starting Full Rollback ==="

try {
    # UC1/UC2: Network Restrictions
    Write-Log "Rolling back network restrictions..."

    # Remove scheduled task
    Unregister-ScheduledTask -TaskName "Intune-WiFiDisableEnforcement" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "  Removed enforcement task"

    # Enable Wi-Fi
    Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|Wireless' } | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "  Enabled Wi-Fi adapters"

    # Remove firewall rules
    Get-NetFirewallRule -DisplayName "DynKeyword-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Write-Log "  Removed firewall rules"

    # Remove dynamic keywords
    Get-NetFirewallDynamicKeywordAddress | ForEach-Object {
        Remove-NetFirewallDynamicKeywordAddress -Id $_.Id -ErrorAction SilentlyContinue
    }
    Write-Log "  Removed dynamic keywords"

    # Reset firewall default
    Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Allow
    Write-Log "  Reset firewall default to ALLOW"

    # UC3/UC4: USB (no persistent local changes to rollback - handled by Intune policy removal)
    Write-Log "USB policies: Remove via Intune console"

    # UC5: Offline Access (no rollback needed - keep security features)
    Write-Log "Offline access: No rollback (security features retained)"

    # UC6: SICE
    $SICE = Get-Service -Name "SICEAgent" -ErrorAction SilentlyContinue
    if ($SICE) {
        Stop-Service -Name "SICEAgent" -Force -ErrorAction SilentlyContinue
        Write-Log "  Stopped SICE agent"
    }

    # Clean up scripts
    Remove-Item -Path "$env:ProgramData\Intune\Scripts\Enforce-*.ps1" -Force -ErrorAction SilentlyContinue
    Write-Log "  Removed enforcement scripts"

    Write-Log "=== Rollback Complete ==="
    Write-Log ""
    Write-Log "IMPORTANT: Also remove the following from Intune:"
    Write-Log "  - Network restriction configuration profiles"
    Write-Log "  - Wi-Fi block settings catalog policies"
    Write-Log "  - Device Control policies"
    Write-Log "  - Proactive remediation assignments"

    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
```

---

## Appendix {#appendix}

### A. Complete Dynamic Keywords Reference

| Keyword | FQDN Pattern | Purpose |
|---------|--------------|---------|
| Azure Bastion | `*.bastion.azure.com` | Bastion host access |
| Azure Portal | `*.portal.azure.com` | Azure management |
| Azure Auth | `login.microsoftonline.com` | Authentication |
| Azure Graph | `graph.microsoft.com` | Graph API |
| ShareFile | `*.sharefile.com` | File sharing |
| ShareFile API | `*.sf-api.com` | ShareFile API |
| Citrix Data | `*.citrixdata.com` | ShareFile storage |
| Intune | `*.manage.microsoft.com` | Device management |
| Intune Enroll | `enrollment.manage.microsoft.com` | Enrollment |
| Windows Update | `*.windowsupdate.com` | OS updates |
| MS Update | `*.update.microsoft.com` | MS updates |
| Delivery | `*.delivery.mp.microsoft.com` | Content delivery |
| Defender | `*.wdcp.microsoft.com` | Defender updates |
| SmartScreen | `*.smartscreen.microsoft.com` | URL filtering |

### B. Approved USB Devices Template

| Device Name | Manufacturer | VID | PID | Purpose |
|-------------|--------------|-----|-----|---------|
| | | | | |
| | | | | |
| | | | | |

### C. Support Contacts

| Issue | Contact | SLA |
|-------|---------|-----|
| Network restrictions | IT Security | 4 hours |
| USB device approval | IT Security | 1 business day |
| BitLocker recovery | IT Helpdesk | 30 minutes |
| SICE/Patching | MSP Name | Per contract |

### D. Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Dec 2024 | Principal Endpoint Engineer | Initial release |

---

**Document End**
