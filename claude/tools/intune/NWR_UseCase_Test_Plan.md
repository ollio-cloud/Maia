# NWR Field Device Network Restriction - Test Plan

**Document Version**: 1.0
**Date**: January 2025
**Project**: NWR Field Device Network Restriction
**Author**: Principal Endpoint Engineer

---

## Test Plan Overview

This document provides a comprehensive test plan for validating all use case implementation scripts in two phases:

1. **Phase 1: Local Testing** - Manual script execution before Intune deployment
2. **Phase 2: Intune Deployment Testing** - Validation after Intune policy deployment

---

## Test Environment Requirements

### Test Devices

| Device ID | Model | OS Version | Purpose | Intune Enrolled |
|-----------|-------|------------|---------|-----------------|
| TEST-01 | Surface Pro 9 | Windows 11 23H2 | Primary test device | No (Phase 1) / Yes (Phase 2) |
| TEST-02 | Dell Latitude 5540 | Windows 11 23H2 | Secondary test device | No (Phase 1) / Yes (Phase 2) |
| TEST-03 | HP EliteBook 840 G9 | Windows 11 22H2 | Compatibility test | No (Phase 1) / Yes (Phase 2) |

### Prerequisites Checklist

| Requirement | Verification | Status |
|-------------|--------------|--------|
| Windows 11 21H2+ (Build 19044+) | `winver` | [ ] |
| Local Administrator access | Run as Admin | [ ] |
| Network connectivity (pre-restriction) | `Test-NetConnection google.com -Port 443` | [ ] |
| Defender Antivirus 4.18.2209.7+ | `(Get-MpComputerStatus).AMProductVersion` | [ ] |
| PowerShell 5.0+ | `$PSVersionTable.PSVersion` | [ ] |
| Test Azure AD account | User with Bastion/ShareFile access | [ ] |

---

## Phase 1: Local Script Testing (Pre-Intune)

### Test 1.1: Wi-Fi Disable Script

**Script**: `Disable-WiFi-Allow-LAN-5G.ps1`
**Use Case**: UC1 - Disable Wi-Fi

#### Pre-Test State

```powershell
# Document current state before testing
Write-Host "=== PRE-TEST STATE ===" -ForegroundColor Cyan
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MacAddress | Format-Table
```

| Check | Expected | Actual | Pass/Fail |
|-------|----------|--------|-----------|
| Wi-Fi adapter present | Enabled | | |
| Ethernet adapter present | Enabled | | |
| Cellular adapter (if present) | Enabled | | |

#### Test Execution

```powershell
# Run script as Administrator
.\Disable-WiFi-Allow-LAN-5G.ps1
```

#### Post-Test Validation

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.1.1: Wi-Fi Disabled | `Get-NetAdapter \| Where-Object { $_.InterfaceDescription -match 'Wi-Fi' }` | Status = "Disabled" | | |
| TC-1.1.2: Ethernet Enabled | `Get-NetAdapter \| Where-Object { $_.InterfaceDescription -match 'Ethernet' }` | Status = "Up" | | |
| TC-1.1.3: Cellular Enabled | `Get-NetAdapter \| Where-Object { $_.InterfaceDescription -match 'Cellular\|WWAN' }` | Status = "Up" (if present) | | |
| TC-1.1.4: Scheduled Task Created | `Get-ScheduledTask -TaskName "Intune-WiFiDisableEnforcement"` | Task exists | | |
| TC-1.1.5: Log File Created | `Test-Path "$env:ProgramData\Intune\Logs\NetworkRestriction_*.log"` | True | | |
| TC-1.1.6: Wi-Fi Re-enable Blocked | Enable Wi-Fi via Settings, wait 15 min | Wi-Fi auto-disables | | |

#### Rollback Test

```powershell
# Test rollback capability
Unregister-ScheduledTask -TaskName "Intune-WiFiDisableEnforcement" -Confirm:$false
Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi' } | Enable-NetAdapter -Confirm:$false
```

| Test Case | Expected Result | Actual Result | Pass/Fail |
|-----------|-----------------|---------------|-----------|
| TC-1.1.7: Rollback Success | Wi-Fi re-enabled, task removed | | |

---

### Test 1.2: Dynamic Keyword Firewall Script

**Script**: `Configure-DynamicKeyword-Firewall.ps1`
**Use Case**: UC2 - Restrict Internet Access

#### Pre-Test State

```powershell
# Document current firewall state
Write-Host "=== PRE-TEST FIREWALL STATE ===" -ForegroundColor Cyan
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table
(Get-NetFirewallDynamicKeywordAddress).Count
```

| Check | Expected | Actual | Pass/Fail |
|-------|----------|--------|-----------|
| Firewall profiles enabled | All enabled | | |
| Default outbound | Allow | | |
| Dynamic Keywords count | 0 | | |

#### Test Execution

```powershell
# Run script as Administrator
.\Configure-DynamicKeyword-Firewall.ps1
```

#### Post-Test Validation

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.2.1: Default Outbound Blocked | `(Get-NetFirewallProfile).DefaultOutboundAction` | All profiles = "Block" | | |
| TC-1.2.2: Dynamic Keywords Created | `(Get-NetFirewallDynamicKeywordAddress).Count` | ≥15 keywords | | |
| TC-1.2.3: Firewall Rules Created | `(Get-NetFirewallRule -DisplayName "DynKeyword-*").Count` | ≥10 rules | | |
| TC-1.2.4: Azure Bastion Accessible | `Test-NetConnection portal.azure.com -Port 443` | TcpTestSucceeded = True | | |
| TC-1.2.5: ShareFile Accessible | `Test-NetConnection www.sharefile.com -Port 443` | TcpTestSucceeded = True | | |
| TC-1.2.6: Microsoft Auth Accessible | `Test-NetConnection login.microsoftonline.com -Port 443` | TcpTestSucceeded = True | | |
| TC-1.2.7: Intune Accessible | `Test-NetConnection manage.microsoft.com -Port 443` | TcpTestSucceeded = True | | |
| TC-1.2.8: Google Blocked | `Test-NetConnection www.google.com -Port 443` | TcpTestSucceeded = False | | |
| TC-1.2.9: Facebook Blocked | `Test-NetConnection www.facebook.com -Port 443` | TcpTestSucceeded = False | | |
| TC-1.2.10: Local Network Accessible | `Test-NetConnection 192.168.1.1 -Port 443` (adjust IP) | TcpTestSucceeded = True | | |
| TC-1.2.11: DNS Resolution Works | `Resolve-DnsName portal.azure.com` | Returns IP addresses | | |
| TC-1.2.12: Log File Created | `Test-Path "$env:ProgramData\Intune\Logs\FirewallConfig_*.log"` | True | | |

#### Application Testing

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.2.13: Azure Portal Login | Open https://portal.azure.com in browser | Login page loads | | |
| TC-1.2.14: Azure Bastion Connection | Connect to VM via Bastion | RDP/SSH session establishes | | |
| TC-1.2.15: ShareFile Access | Open https://yourcompany.sharefile.com | Login page loads | | |
| TC-1.2.16: ShareFile Upload/Download | Upload and download test file | Both operations succeed | | |
| TC-1.2.17: Blocked Site - Browser | Open https://www.google.com | Connection refused/timeout | | |

#### Rollback Test

```powershell
# Test rollback capability
Get-NetFirewallRule -DisplayName "DynKeyword-*" | Remove-NetFirewallRule
Get-NetFirewallDynamicKeywordAddress | ForEach-Object { Remove-NetFirewallDynamicKeywordAddress -Id $_.Id }
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Allow
```

| Test Case | Expected Result | Actual Result | Pass/Fail |
|-----------|-----------------|---------------|-----------|
| TC-1.2.18: Rollback Success | All sites accessible, default outbound = Allow | | |

---

### Test 1.3: Proactive Remediation Scripts

**Scripts**: Detection + Remediation scripts
**Use Case**: UC1/UC2 - Continuous Enforcement

#### Detection Script Test

```powershell
# Run detection script manually
.\Detect-NetworkRestrictions.ps1
$LASTEXITCODE  # Should be 0 (compliant) or 1 (non-compliant)
```

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.3.1: Detection - Compliant | Run after UC1/UC2 scripts | Exit code = 0, Output = "COMPLIANT" | | |
| TC-1.3.2: Detection - Wi-Fi Enabled | Enable Wi-Fi, run detection | Exit code = 1, Output contains "Wi-Fi enabled" | | |
| TC-1.3.3: Detection - FW Wrong | Set outbound to Allow, run detection | Exit code = 1, Output contains "Firewall" | | |

#### Remediation Script Test

```powershell
# Intentionally break compliance, then run remediation
Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false
Set-NetFirewallProfile -Profile Domain -DefaultOutboundAction Allow

# Run remediation
.\Remediate-NetworkRestrictions.ps1

# Verify fix
.\Detect-NetworkRestrictions.ps1
```

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.3.4: Remediation Success | Run remediation after breaking compliance | Detection returns compliant | | |

---

### Test 1.4: USB Device Control (If testing locally)

**Use Case**: UC3 - USB Whitelisting

> **Note**: Full USB device control requires Defender for Endpoint. Local testing validates driver installation and device enumeration only.

#### Test Execution

```powershell
# Enumerate USB devices
Get-PnpDevice -Class USB | ForEach-Object {
    if ($_.InstanceId -match 'VID_([0-9A-F]{4})&PID_([0-9A-F]{4})') {
        [PSCustomObject]@{
            Name = $_.FriendlyName
            VID = $Matches[1]
            PID = $Matches[2]
            Status = $_.Status
        }
    }
} | Format-Table
```

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.4.1: USB Enumeration | Run enumeration script | All USB devices listed with VID/PID | | |
| TC-1.4.2: Approved Device Identified | Connect approved USB-Serial adapter | VID/PID matches approved list | | |

---

### Test 1.5: USB-Serial Driver Installation

**Script**: `Install-USBSerialDrivers.ps1`
**Use Case**: UC4 - USB-Serial Support

#### Pre-Test State

```powershell
# Check for existing drivers
Test-Path "C:\Windows\System32\drivers\ftdibus.sys"
Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DeviceName -match 'USB.*Serial\|FTDI\|Prolific\|CP210' }
```

#### Test Execution

```powershell
# Run driver installation
.\Install-USBSerialDrivers.ps1
```

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.5.1: FTDI Driver Installed | `Test-Path "C:\Windows\System32\drivers\ftdibus.sys"` | True | | |
| TC-1.5.2: Driver in Device Manager | Device Manager > Ports | USB-Serial adapters listed | | |
| TC-1.5.3: COM Port Created | Connect USB-Serial device | COM port appears | | |
| TC-1.5.4: Serial Communication | Open PuTTY/terminal to COM port | Connection succeeds | | |
| TC-1.5.5: Log File Created | `Test-Path "$env:ProgramData\Intune\Logs\USBSerialInstall_*.log"` | True | | |

---

### Test 1.6: Offline Access Configuration

**Script**: `Configure-OfflineAccess.ps1`
**Use Case**: UC5 - Secure Offline Access

#### Test Execution

```powershell
# Run configuration
.\Configure-OfflineAccess.ps1
```

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.6.1: Cached Logons Set | `(Get-ItemProperty "HKLM:\...\Winlogon").CachedLogonsCount` | "10" | | |
| TC-1.6.2: BitLocker Status | `(Get-BitLockerVolume -MountPoint C:).ProtectionStatus` | "On" | | |
| TC-1.6.3: Defender Catch-up Enabled | `(Get-MpPreference).DisableCatchupQuickScan` | False | | |
| TC-1.6.4: Firewall Enabled | `(Get-NetFirewallProfile).Enabled` | All True | | |

#### Offline Login Test

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-1.6.5: Offline Login | Disconnect network, reboot, login with cached creds | Login succeeds | | |
| TC-1.6.6: Offline Login Count | Repeat login 5 times offline | All logins succeed | | |

---

## Phase 2: Intune Deployment Testing

### Test 2.1: Intune Policy Deployment

#### Pre-Deployment Checklist

| Check | Verification | Status |
|-------|--------------|--------|
| Test device enrolled in Intune | Intune Portal > Devices | [ ] |
| Test device in correct group | `Field-Devices-Restricted-Network` | [ ] |
| Policies assigned to group | Check policy assignments | [ ] |
| Device synced recently | Last sync < 1 hour | [ ] |

#### Policy Deployment Verification

```powershell
# Force Intune sync
Start-Process "ms-device-enrollment:?mode=mdm"
# Or via Company Portal
```

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-2.1.1: Policy Sync | Sync device via Company Portal | Sync completes successfully | | |
| TC-2.1.2: Script Deployment | Check Intune Portal > Monitor | Scripts show "Succeeded" | | |
| TC-2.1.3: Config Profile Applied | Intune > Device > Configuration | Profiles show "Succeeded" | | |

---

### Test 2.2: UC1/UC2 - Network Restrictions via Intune

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-2.2.1: Wi-Fi Disabled | Check adapter status post-sync | Wi-Fi disabled | | |
| TC-2.2.2: Wi-Fi UI Blocked | Settings > Network > Wi-Fi | Option grayed out or hidden | | |
| TC-2.2.3: Firewall Configured | Check firewall profiles | Default outbound = Block | | |
| TC-2.2.4: Dynamic Keywords | `Get-NetFirewallDynamicKeywordAddress` | ≥15 keywords | | |
| TC-2.2.5: Azure Bastion Works | Connect via Bastion | Connection succeeds | | |
| TC-2.2.6: ShareFile Works | Access ShareFile portal | Access succeeds | | |
| TC-2.2.7: Blocked Sites | Browse to google.com | Blocked | | |
| TC-2.2.8: Compliance Status | Intune > Device > Compliance | Compliant | | |

---

### Test 2.3: UC3/UC4 - USB Control via Intune

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-2.3.1: USB Storage Blocked | Connect USB flash drive | Access denied notification | | |
| TC-2.3.2: Approved USB Works | Connect approved IP config tool | Device functions normally | | |
| TC-2.3.3: USB-Serial Works | Connect USB-Serial adapter | COM port created, communication works | | |
| TC-2.3.4: Audit Events | Check Defender > Device Control | Block events logged | | |

---

### Test 2.4: UC5 - Offline Access via Intune

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-2.4.1: BitLocker Enforced | Check BitLocker status | Protection = On, Key escrowed | | |
| TC-2.4.2: Cached Creds | Check registry | CachedLogonsCount = 10 | | |
| TC-2.4.3: Offline Login | Disconnect, reboot, login | Login succeeds | | |
| TC-2.4.4: Defender Offline | Check Defender status offline | Real-time protection active | | |
| TC-2.4.5: Compliance Grace | Stay offline 5 days, reconnect | Device still compliant (7-day grace) | | |

---

### Test 2.5: UC6 - SICE/MSP Access via Intune

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-2.5.1: SICE Agent Installed | Check Programs & Features | SICE Agent present | | |
| TC-2.5.2: SICE Service Running | `Get-Service SICEAgent` | Status = Running | | |
| TC-2.5.3: SICE Connectivity | `Test-NetConnection patch.msp-sice.com -Port 443` | Success | | |
| TC-2.5.4: Patch Download | Trigger patch check | Patches download successfully | | |

---

### Test 2.6: Proactive Remediation via Intune

| Test Case | Test Steps | Expected Result | Actual Result | Pass/Fail |
|-----------|------------|-----------------|---------------|-----------|
| TC-2.6.1: Remediation Assigned | Intune > Remediations | Shows assigned to device | | |
| TC-2.6.2: Detection Runs | Check remediation status | Detection ran, result = Compliant | | |
| TC-2.6.3: Auto-Remediation | Enable Wi-Fi manually, wait 1hr | Wi-Fi auto-disabled | | |
| TC-2.6.4: Remediation Logged | Check remediation results | Shows "With issues" then "Without issues" | | |

---

## Test 2.7: End-to-End User Scenario Testing

### Scenario A: New Device Deployment

| Step | Action | Expected Result | Actual Result | Pass/Fail |
|------|--------|-----------------|---------------|-----------|
| 1 | Unbox new device | Device boots to OOBE | | |
| 2 | Complete Autopilot enrollment | Device joins Azure AD, enrolls in Intune | | |
| 3 | ESP completes | All apps/policies applied | | |
| 4 | User signs in | Desktop appears, restrictions active | | |
| 5 | Verify Wi-Fi disabled | Wi-Fi adapter disabled | | |
| 6 | Verify firewall | Blocked sites inaccessible | | |
| 7 | Test Azure Bastion | Can connect to infrastructure | | |
| 8 | Test ShareFile | Can access files | | |
| 9 | Test USB | Approved devices work, storage blocked | | |
| **Total Time** | | Target: <30 minutes | | |

### Scenario B: Field Worker Daily Use

| Step | Action | Expected Result | Actual Result | Pass/Fail |
|------|--------|-----------------|---------------|-----------|
| 1 | Boot device (5G connected) | Device connects via cellular | | |
| 2 | Login (online) | Login succeeds | | |
| 3 | Access ShareFile | Download work documents | | |
| 4 | Connect USB-Serial device | COM port created | | |
| 5 | Configure field equipment | Serial communication works | | |
| 6 | Upload results to ShareFile | Upload succeeds | | |
| 7 | Go offline (remote location) | Device continues operating | | |
| 8 | Login offline (next day) | Cached credentials work | | |
| 9 | Return online | Device syncs, stays compliant | | |

### Scenario C: Security Incident Response

| Step | Action | Expected Result | Actual Result | Pass/Fail |
|------|--------|-----------------|---------------|-----------|
| 1 | User attempts to enable Wi-Fi | Cannot enable (blocked) | | |
| 2 | User connects unauthorized USB | Access denied | | |
| 3 | User browses to blocked site | Connection blocked | | |
| 4 | Admin checks compliance | Device shows compliant | | |
| 5 | Admin reviews audit logs | All blocked attempts logged | | |

---

## Test Results Summary

### Phase 1 Summary (Local Testing)

| Use Case | Total Tests | Passed | Failed | Notes |
|----------|-------------|--------|--------|-------|
| UC1: Wi-Fi Disable | 7 | | | |
| UC2: Firewall | 18 | | | |
| UC3: USB Whitelist | 2 | | | |
| UC4: USB-Serial | 5 | | | |
| UC5: Offline Access | 6 | | | |
| UC1/2: Remediation | 4 | | | |
| **TOTAL** | **42** | | | |

### Phase 2 Summary (Intune Deployment)

| Use Case | Total Tests | Passed | Failed | Notes |
|----------|-------------|--------|--------|-------|
| UC1/2: Network | 8 | | | |
| UC3/4: USB | 4 | | | |
| UC5: Offline | 5 | | | |
| UC6: SICE | 4 | | | |
| Remediation | 4 | | | |
| E2E Scenarios | 3 | | | |
| **TOTAL** | **28** | | | |

---

## Issue Tracking

| Issue ID | Description | Severity | Status | Resolution |
|----------|-------------|----------|--------|------------|
| | | | | |
| | | | | |
| | | | | |

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Tester | | | |
| Principal Endpoint Engineer | | | |
| Project Manager | | | |
| Security Reviewer | | | |

---

## Appendix A: Quick Validation Script

Run this comprehensive script to validate all use cases at once:

```powershell
<#
.SYNOPSIS
    NWR Field Device - Complete Validation Script
.DESCRIPTION
    Validates all use cases in a single execution
#>

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     NWR FIELD DEVICE - COMPLETE VALIDATION                    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$Results = @()

# UC1: Wi-Fi Disabled
Write-Host "`n[UC1] Wi-Fi Status" -ForegroundColor Yellow
$WiFi = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|Wireless' }
$WiFiDisabled = ($WiFi | Where-Object { $_.Status -eq 'Disabled' }).Count -eq $WiFi.Count
$Results += [PSCustomObject]@{ UC = "UC1"; Test = "Wi-Fi Disabled"; Pass = $WiFiDisabled }
Write-Host "  Wi-Fi: $(if ($WiFiDisabled -or -not $WiFi) { 'PASS - Disabled' } else { 'FAIL - Enabled' })" -ForegroundColor $(if ($WiFiDisabled -or -not $WiFi) { 'Green' } else { 'Red' })

# UC2: Firewall
Write-Host "`n[UC2] Firewall Configuration" -ForegroundColor Yellow
$FWBlock = (Get-NetFirewallProfile | Where-Object { $_.DefaultOutboundAction -eq 'Block' }).Count -eq 3
$Results += [PSCustomObject]@{ UC = "UC2"; Test = "Outbound Blocked"; Pass = $FWBlock }
Write-Host "  Default Outbound: $(if ($FWBlock) { 'PASS - Block' } else { 'FAIL - Allow' })" -ForegroundColor $(if ($FWBlock) { 'Green' } else { 'Red' })

$Keywords = (Get-NetFirewallDynamicKeywordAddress).Count
$KeywordsOK = $Keywords -ge 15
$Results += [PSCustomObject]@{ UC = "UC2"; Test = "Dynamic Keywords"; Pass = $KeywordsOK }
Write-Host "  Dynamic Keywords: $(if ($KeywordsOK) { "PASS - $Keywords" } else { "FAIL - $Keywords (need 15+)" })" -ForegroundColor $(if ($KeywordsOK) { 'Green' } else { 'Red' })

# Connectivity Tests
Write-Host "`n[UC2] Connectivity Tests" -ForegroundColor Yellow
$AllowedHosts = @("portal.azure.com", "www.sharefile.com", "login.microsoftonline.com", "manage.microsoft.com")
$BlockedHosts = @("www.google.com", "www.facebook.com")

foreach ($Host in $AllowedHosts) {
    $Test = Test-NetConnection -ComputerName $Host -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
    $Results += [PSCustomObject]@{ UC = "UC2"; Test = "Allow $Host"; Pass = $Test }
    Write-Host "  Allow $Host : $(if ($Test) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if ($Test) { 'Green' } else { 'Red' })
}

foreach ($Host in $BlockedHosts) {
    $Test = Test-NetConnection -ComputerName $Host -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
    $Blocked = -not $Test
    $Results += [PSCustomObject]@{ UC = "UC2"; Test = "Block $Host"; Pass = $Blocked }
    Write-Host "  Block $Host : $(if ($Blocked) { 'PASS - Blocked' } else { 'FAIL - Accessible' })" -ForegroundColor $(if ($Blocked) { 'Green' } else { 'Red' })
}

# UC3/UC4: USB
Write-Host "`n[UC3/4] USB Configuration" -ForegroundColor Yellow
$MDE = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
$MDERunning = $MDE -and $MDE.Status -eq 'Running'
$Results += [PSCustomObject]@{ UC = "UC3"; Test = "Defender for Endpoint"; Pass = $MDERunning }
Write-Host "  Defender for Endpoint: $(if ($MDERunning) { 'PASS - Running' } else { 'WARN - Not running (USB control limited)' })" -ForegroundColor $(if ($MDERunning) { 'Green' } else { 'Yellow' })

$SerialDriver = Test-Path "C:\Windows\System32\drivers\ftdibus.sys"
$Results += [PSCustomObject]@{ UC = "UC4"; Test = "USB-Serial Driver"; Pass = $SerialDriver }
Write-Host "  USB-Serial Driver: $(if ($SerialDriver) { 'PASS - Installed' } else { 'WARN - Not found' })" -ForegroundColor $(if ($SerialDriver) { 'Green' } else { 'Yellow' })

# UC5: Offline Access
Write-Host "`n[UC5] Offline Access Configuration" -ForegroundColor Yellow
$CachedLogons = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "CachedLogonsCount" -ErrorAction SilentlyContinue).CachedLogonsCount
$CachedOK = [int]$CachedLogons -ge 5
$Results += [PSCustomObject]@{ UC = "UC5"; Test = "Cached Logons"; Pass = $CachedOK }
Write-Host "  Cached Logons: $(if ($CachedOK) { "PASS - $CachedLogons" } else { "FAIL - $CachedLogons" })" -ForegroundColor $(if ($CachedOK) { 'Green' } else { 'Red' })

$BitLocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
$BitLockerOK = $BitLocker -and $BitLocker.ProtectionStatus -eq 'On'
$Results += [PSCustomObject]@{ UC = "UC5"; Test = "BitLocker"; Pass = $BitLockerOK }
Write-Host "  BitLocker: $(if ($BitLockerOK) { 'PASS - Enabled' } else { 'FAIL - Not enabled' })" -ForegroundColor $(if ($BitLockerOK) { 'Green' } else { 'Red' })

$Defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
$DefenderOK = $Defender -and $Defender.RealTimeProtectionEnabled
$Results += [PSCustomObject]@{ UC = "UC5"; Test = "Defender Real-Time"; Pass = $DefenderOK }
Write-Host "  Defender Real-Time: $(if ($DefenderOK) { 'PASS - Enabled' } else { 'FAIL - Disabled' })" -ForegroundColor $(if ($DefenderOK) { 'Green' } else { 'Red' })

# Summary
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         SUMMARY                               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$PassCount = ($Results | Where-Object { $_.Pass -eq $true }).Count
$FailCount = ($Results | Where-Object { $_.Pass -eq $false }).Count

Write-Host "  TOTAL TESTS: $($Results.Count)" -ForegroundColor Cyan
Write-Host "  PASSED: $PassCount" -ForegroundColor Green
Write-Host "  FAILED: $FailCount" -ForegroundColor $(if ($FailCount -eq 0) { 'Green' } else { 'Red' })

if ($FailCount -eq 0) {
    Write-Host "`n  ✓ ALL USE CASES VALIDATED SUCCESSFULLY" -ForegroundColor Green
} else {
    Write-Host "`n  ✗ $FailCount TEST(S) FAILED - Review results above" -ForegroundColor Red
    Write-Host "`n  Failed Tests:" -ForegroundColor Red
    $Results | Where-Object { $_.Pass -eq $false } | ForEach-Object {
        Write-Host "    - [$($_.UC)] $($_.Test)" -ForegroundColor Red
    }
}
```

---

**Document End**
