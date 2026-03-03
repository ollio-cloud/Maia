# NWR Field Device - Test Plan

**Project**: NWR Field Device Network Restriction
**Version**: 1.0 | **Date**: January 2025

---

## Overview

This test plan validates all use cases before production deployment in two phases:
- **Phase 1**: Local testing (before Intune)
- **Phase 2**: Intune deployment testing

---

## Test Devices Required

| Device | OS | Purpose |
|--------|-----|---------|
| TEST-01 | Windows 11 23H2 | Primary testing |
| TEST-02 | Windows 11 23H2 | Secondary testing |

---

## Phase 1: Local Testing

### UC1 - Wi-Fi Disable

| # | Test | Expected Result | Pass/Fail |
|---|------|-----------------|-----------|
| 1 | Wi-Fi adapter status | Disabled | |
| 2 | Ethernet adapter status | Enabled | |
| 3 | Scheduled task exists | Task created | |
| 4 | Wi-Fi re-enable blocked | Auto-disables after 15 min | |

### UC2 - Firewall Restrictions

| # | Test | Expected Result | Pass/Fail |
|---|------|-----------------|-----------|
| 1 | Default outbound action | Block | |
| 2 | Dynamic keywords count | 15+ keywords | |
| 3 | Azure Bastion access | Accessible | |
| 4 | ShareFile access | Accessible | |
| 5 | Microsoft login | Accessible | |
| 6 | Google.com | Blocked | |
| 7 | Facebook.com | Blocked | |

### UC3/UC4 - USB Control

| # | Test | Expected Result | Pass/Fail |
|---|------|-----------------|-----------|
| 1 | USB storage blocked | Access denied | |
| 2 | Approved USB-Serial works | COM port created | |
| 3 | Serial communication | Data transfer works | |

### UC5 - Offline Access

| # | Test | Expected Result | Pass/Fail |
|---|------|-----------------|-----------|
| 1 | Cached logons configured | 10 logons | |
| 2 | BitLocker enabled | Protection On | |
| 3 | Offline login | Login succeeds | |
| 4 | Defender active | Real-time protection enabled | |

---

## Phase 2: Intune Testing

### Policy Deployment

| # | Test | Expected Result | Pass/Fail |
|---|------|-----------------|-----------|
| 1 | Device enrolled | Shows in Intune portal | |
| 2 | Policies assigned | All policies show "Succeeded" | |
| 3 | Scripts deployed | Scripts show "Succeeded" | |

### Use Case Validation

| # | Test | Expected Result | Pass/Fail |
|---|------|-----------------|-----------|
| 1 | Wi-Fi disabled via Intune | Adapter disabled | |
| 2 | Wi-Fi UI blocked | Option hidden/grayed | |
| 3 | Firewall configured | Outbound blocked | |
| 4 | Azure Bastion works | Connection succeeds | |
| 5 | ShareFile works | Files accessible | |
| 6 | Blocked sites | Cannot access | |
| 7 | USB storage blocked | Access denied | |
| 8 | USB-Serial works | COM port functional | |
| 9 | Offline login works | Cached creds work | |
| 10 | Compliance status | Shows "Compliant" | |

### Proactive Remediation

| # | Test | Expected Result | Pass/Fail |
|---|------|-----------------|-----------|
| 1 | Enable Wi-Fi manually | Auto-disables within 1 hour | |
| 2 | Remediation logged | Shows in Intune reports | |

---

## End-to-End Scenario

### Scenario: Field Worker Daily Use

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | Boot device with 5G SIM | Connects via cellular | |
| 2 | Login to device | Login succeeds | |
| 3 | Access ShareFile | Can download files | |
| 4 | Connect USB-Serial adapter | COM port created | |
| 5 | Use serial configuration tool | Communication works | |
| 6 | Upload files to ShareFile | Upload succeeds | |
| 7 | Go offline | Device continues working | |
| 8 | Login offline (next day) | Cached login works | |
| 9 | Return online | Syncs, stays compliant | |

---

## Quick Validation Script

Run on test device to validate all use cases:

```powershell
# Quick validation - Run as Administrator
$Tests = @()

# Wi-Fi
$WiFi = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi' }
$Tests += @{ Test = "Wi-Fi Disabled"; Pass = ($WiFi.Status -eq 'Disabled' -or -not $WiFi) }

# Firewall
$FW = (Get-NetFirewallProfile | Where-Object { $_.DefaultOutboundAction -eq 'Block' }).Count -eq 3
$Tests += @{ Test = "Firewall Blocked"; Pass = $FW }

# Connectivity
$Bastion = Test-NetConnection portal.azure.com -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
$Tests += @{ Test = "Azure Bastion"; Pass = $Bastion }

$Google = Test-NetConnection www.google.com -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
$Tests += @{ Test = "Google Blocked"; Pass = (-not $Google) }

# BitLocker
$BL = (Get-BitLockerVolume -MountPoint C: -ErrorAction SilentlyContinue).ProtectionStatus -eq 'On'
$Tests += @{ Test = "BitLocker On"; Pass = $BL }

# Results
$Tests | ForEach-Object {
    $Status = if ($_.Pass) { "PASS" } else { "FAIL" }
    Write-Host "$($_.Test): $Status" -ForegroundColor $(if ($_.Pass) { 'Green' } else { 'Red' })
}
```

---

## Results Summary

| Phase | Total Tests | Passed | Failed |
|-------|-------------|--------|--------|
| Phase 1: Local | 15 | | |
| Phase 2: Intune | 12 | | |
| **TOTAL** | **27** | | |

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Tester | | | |
| Technical Lead | | | |
| Customer Representative | | | |

---

## Issues Found

| # | Description | Severity | Status |
|---|-------------|----------|--------|
| | | | |
| | | | |
