# [CR-4432419] Azure East FortiGate Firmware Upgrade

**Change Request & Implementation Plan - FortiGate FortiOS Upgrade (SAML Fix)**

| Field | Value | Field | Value |
|-------|-------|-------|-------|
| **CR Number** | CR-4432419 | **Request Date** | 2026-02-24 |
| **Requested By** | Olli Ojala | **Environment** | Azure - KD-Prod-RG (Australia East) |
| **Device** | ATE-AE-fgt (East FortiGate) | **Change Type** | Firmware Upgrade |
| **Risk Level** | **MEDIUM** | **Maintenance Window** | 25 Feb 2026, 20:00 AEST |
| **Current Firmware** | *TBD* | **Target Firmware** | *TBD* |
| **FortiGate Model** | *TBD* | **Expected Downtime** | 5-10 minutes (reboot cycle) |
| **Related CRs** | CR-4404660 (Public IP Migration) | **Rollback Method** | Revert to previous firmware image |

---

## Table of Contents

1. [Change Summary](#1-change-summary)
2. [Justification & Business Impact](#2-justification--business-impact)
3. [Device Details](#3-device-details)
4. [Pre-Change Checklist](#4-pre-change-checklist)
5. [Implementation Steps](#5-implementation-steps)
6. [Post-Upgrade Validation](#6-post-upgrade-validation)
7. [Rollback Plan](#7-rollback-plan)
8. [Risk Assessment](#8-risk-assessment)
9. [Approval](#9-approval)

---

## 1. Change Summary

Upgrade the FortiOS firmware on the **Azure East FortiGate** (ATE-AE-fgt) to resolve a **SAML authentication issue**. The Azure South East FortiGate (ATE-ASE-fgt) is already running the target firmware version, having been deployed from the updated Azure Marketplace image. This change brings the East FortiGate to the same firmware version to ensure consistency and resolve the SAML bug.

> **Note:** The SE FortiGate (ATE-ASE-fgt) was deployed with the target firmware from the Azure image and does not require this upgrade.

---

## 2. Justification & Business Impact

### 2.1 Reason for Change

| | Detail |
|---|---|
| **Issue** | SAML authentication bug in current FortiOS version affecting user authentication workflows |
| **Fix** | Target firmware version includes the SAML fix |
| **Alignment** | SE FortiGate already running target version - this brings East into parity |

### 2.2 Impact Assessment

| Impact Area | Description | Duration |
|---|---|---|
| VPN Tunnels | All IPsec/SSL VPN tunnels on East FortiGate will drop during reboot and auto-reconnect | 5-10 min |
| Internet Access | Outbound internet traffic via East FortiGate will be interrupted during reboot | 5-10 min |
| Service IPs | All 19 service public IPs (TIMS, Austrics, RDG, etc.) will be unreachable during reboot | 5-10 min |
| SAML Auth | SAML authentication will be fixed after upgrade | Permanent fix |

> **Scheduling Note:** Change is scheduled for **after 20:00 AEST** on **25 Feb 2026** to minimise impact on business users.

---

## 3. Device Details

| Property | East FortiGate (Target) | SE FortiGate (Reference) |
|---|---|---|
| Hostname | ATE-AE-fgt | ATE-ASE-fgt |
| Model | *TBD* | *TBD* |
| Resource Group | KD-Prod-RG | KD-Prod-RG-asr |
| Region | Australia East | Australia Southeast |
| External NIC | ATE-AE-fgt-nic1 (10.200.1.4) | ATE-ASE-fgt-nic1 |
| Current Firmware | *TBD* | *TBD (target version)* |
| Target Firmware | *TBD* | N/A (already at target) |
| Primary Public IP | 52.237.241.132 (KD-UTM-PublicIP) | 23.101.226.122 (Sophos-PublicIP) |
| Service IPs | 19 service public IPs | VIPs mapped via East |

---

## 4. Pre-Change Checklist

### Phase 0: Pre-Change Preparation

- [ ] Confirm current firmware version on East FortiGate
- [ ] Confirm target firmware version (match SE FortiGate)
- [ ] Download firmware image from Fortinet support / Azure Marketplace
- [ ] Take full configuration backup of East FortiGate
- [ ] Export current configuration (CLI: `execute backup full-config`)
- [ ] Take Azure VM snapshot of OS disk
- [ ] Verify FortiGate upgrade path compatibility (Fortinet upgrade path tool)
- [ ] Notify stakeholders of maintenance window
- [ ] Confirm rollback procedure is understood
- [ ] Verify Azure Serial Console access (fallback management)

---

## 5. Implementation Steps

### Step 1: Pre-Upgrade Backup & Baseline (10 min)

#### 1.1 Configuration Backup

```
# FortiGate CLI - Take full config backup
execute backup full-config ftp <backup-server> <filename>

# OR via GUI: System > Backup > Backup Configuration
```

#### 1.2 Azure VM Snapshot

```powershell
# Take snapshot of the East FortiGate OS disk before upgrade
az snapshot create `
  --resource-group KD-Prod-RG `
  --name ATE-AE-fgt-pre-upgrade-snapshot-20260225 `
  --source "/subscriptions/<SUB_ID>/resourceGroups/KD-Prod-RG/providers/Microsoft.Compute/disks/<OS_DISK_NAME>"
```

> **Tip:** Get the OS disk name with:
> ```powershell
> az vm show --resource-group KD-Prod-RG --name ATE-AE-fgt --query "storageProfile.osDisk.name" -o tsv
> ```

#### 1.3 Record Baseline State

```
get system status                    # Firmware version, uptime, serial
get system interface physical        # Interface status
get router info routing-table all    # Routing table
get vpn ipsec tunnel summary         # VPN tunnel status
get system ha status                 # HA status (if applicable)
diagnose sys session stat            # Session count
```

### Step 2: Firmware Upgrade (5-10 min)

#### 2.1 Upload and Install Firmware

> **Warning:** The FortiGate will reboot automatically after firmware installation. All active sessions, VPN tunnels, and traffic will be interrupted.

```
# Option A: CLI upgrade (upload firmware via TFTP/FTP)
execute restore image ftp <firmware-file> <ftp-server>

# Option B: GUI upgrade
# System > Firmware > Upload firmware file > Confirm upgrade

# Option C: FortiGuard upgrade (if available)
execute upgrade image <firmware-url>
```

#### 2.2 Monitor Reboot

```
# Monitor via Azure Serial Console (if GUI/SSH unavailable during reboot)
# Azure Portal > Virtual Machines > ATE-AE-fgt > Serial Console

# After reboot, verify connectivity:
# 1. Wait for FortiGate to come back online (typically 3-5 min)
# 2. SSH or HTTPS to management IP
# 3. Verify firmware version
```

### Step 3: Post-Upgrade Validation (10 min)

#### 3.1 Verify Firmware Version

```
# Confirm new firmware version
get system status

# Expected output should show target firmware version
# Compare with SE FortiGate version for parity
```

#### 3.2 Verify Core Services

```
# Check interfaces are up
get system interface physical

# Check routing table restored
get router info routing-table all

# Check VPN tunnels re-established
get vpn ipsec tunnel summary

# Check session count recovering
diagnose sys session stat

# Check SAML configuration intact
diagnose debug application saml -1
diagnose debug enable
```

#### 3.3 Verify Public IP Connectivity

```powershell
# Verify primary public IP is reachable (from external machine)
curl.exe -sk https://<east-fortigate-mgmt> -w "%{http_code}"

# Verify service IPs are responding (spot check)
nslookup atesma01.kdbusgroup.com.au
curl.exe -sk https://tims-qld.hornibrook.com.au -w "%{http_code}"

# Verify PIP associations unchanged
az network public-ip show --resource-group KD-Prod-RG --name KD-UTM-PublicIP --query "{ip:ipAddress, nic:ipConfiguration.id}" -o table
```

#### 3.4 Test SAML Authentication

- [ ] Attempt SAML login through FortiGate
- [ ] Verify SAML assertion is processed correctly
- [ ] Confirm user authentication completes successfully
- [ ] Test from multiple browsers/clients if applicable

---

## 6. Post-Upgrade Validation Checklist

- [ ] Firmware version matches target
- [ ] Firmware version matches SE FortiGate
- [ ] All physical interfaces are UP
- [ ] Default route (0.0.0.0/0) present and correct
- [ ] IPsec VPN tunnels re-established
- [ ] SSL VPN portal accessible
- [ ] Outbound internet connectivity working
- [ ] Service public IPs responding (TIMS, Austrics, RDG)
- [ ] SAML authentication working (primary fix validation)
- [ ] No unexpected errors in FortiGate event logs
- [ ] Azure VM health status: Healthy

---

## 7. Rollback Plan

> **Rollback triggers:** FortiGate fails to come online after 15 min, critical services not restoring, SAML worse than before, or configuration corruption detected.

### Option A: FortiGate Secondary Partition (Preferred)

```
# FortiGate keeps previous firmware on secondary partition
# Boot into secondary partition with previous firmware:

# Via Azure Serial Console during boot:
# 1. Access Serial Console: Azure Portal > ATE-AE-fgt > Serial Console
# 2. During boot menu, select secondary partition
# 3. FortiGate boots with previous firmware + config

# Via CLI (if accessible):
execute set-next-reboot secondary
execute reboot
```

### Option B: Restore from Azure Snapshot

```powershell
# If FortiGate is unrecoverable, restore from pre-upgrade snapshot

# 1. Stop the VM
az vm stop --resource-group KD-Prod-RG --name ATE-AE-fgt

# 2. Deallocate
az vm deallocate --resource-group KD-Prod-RG --name ATE-AE-fgt

# 3. Create managed disk from snapshot and swap
az disk create --resource-group KD-Prod-RG `
  --name ATE-AE-fgt-rollback-disk `
  --source ATE-AE-fgt-pre-upgrade-snapshot-20260225

az vm update --resource-group KD-Prod-RG --name ATE-AE-fgt `
  --os-disk ATE-AE-fgt-rollback-disk

# 4. Start VM
az vm start --resource-group KD-Prod-RG --name ATE-AE-fgt
```

### Option C: Configuration Restore

```
# If firmware upgrade succeeds but config is corrupted:
execute restore config ftp <backup-file> <ftp-server>
```

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| FortiGate fails to boot after upgrade | Low | High | Azure disk snapshot taken before upgrade; secondary partition rollback available |
| Configuration lost or corrupted | Low | High | Full config backup exported before upgrade; can restore from backup |
| VPN tunnels fail to re-establish | Low | Medium | Tunnels auto-negotiate; manual bring-up if needed; rollback if persistent |
| SAML fix not effective | Low | Low | SE FortiGate already confirmed working on target version; same fix applies |
| Extended downtime beyond 10 min | Low | Medium | Scheduled after business hours (20:00 AEST); Azure Serial Console for recovery |
| Firmware upgrade path incompatibility | Low | High | Verify upgrade path via Fortinet tool before starting; may need intermediate version |

---

## 9. Approval

| Role | Name | Signature | Date |
|---|---|---|---|
| Requestor | Olli Ojala | | |
| Technical Approver | | | |
| Change Manager | | | |

---

**Post-Change:** Once upgrade is confirmed successful and SAML is verified working, update this CR with completion status and close.