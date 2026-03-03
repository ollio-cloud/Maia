# [CR-4404660] Azure Public IP Migration - SonicWall to FortiGate

**Change Request & Implementation Plan - Public IP Reassignment**

| Field | Value | Field | Value |
|---|---|---|---|
| **CR Number** | CR-4404660 | **Request Date** | 2026-02-12 |
| **Requested By** | Olli Ojala | **Environment** | Azure - KD-Prod-RG |
| **Total IPs** | 21 public IPs (2 primary outbound + 19 service) | **Change Type** | Infrastructure / NIC Reassignment |
| **Risk Level** | MEDIUM | **Rollback Time** | < 2 minutes per IP (reverse reassignment) |
| **Related CRs** | CR-2026-002 (VPN Migration) | **Expected Downtime** | ~5-10 seconds per IP during reassignment |

---

**Table of Contents**

- [1. Overview & Objective](#1-overview--objective)
- [2. Scope - Public IP Inventory](#2-scope---public-ip-inventory)
- [3. Architecture & Approach](#3-architecture--approach)
- [4. Prerequisites](#4-prerequisites)
- [5. Implementation Steps](#5-implementation-steps)
- [6. FortiGate Configuration](#6-fortigate-configuration)
- [7. Validation & Testing](#7-validation--testing)
- [8. Rollback Procedure](#8-rollback-procedure)
- [9. Approvals](#9-approvals)

---

## 1. Overview & Objective

This change request covers the migration of **21 Azure public IPs** from the decommissioning SonicWall to the FortiGate firewalls:

- **2 Primary outbound IPs** (East: `52.237.241.132`, SE: `23.101.226.122`) -- These are the outbound NAT IPs used for general internet access. External services have **whitelisted these addresses**. Migrating these to FortiGate and updating the default route (0.0.0.0/0) is the **primary goal** and first stage of this CR.
- **19 Service IPs** (15 Prod + 4 UAT) -- Inbound service VIPs for TIMS, Austrics, ConnX, ATESMA, KDBMEX, and RDG services across KD Bus and KAB organisations.

> **Note:** Context: This CR is a follow-on task from CR-2026-002 (KD Bus VPN Migration). Once all site VPN tunnels are migrated to FortiGate, the SonicWall will be decommissioned. Before that, the public IPs currently associated with the SonicWall must be moved to the FortiGate NICs. The primary outbound IPs must be migrated **first** to ensure whitelisted external services continue to see the correct source IP, followed by updating the default route to direct internet-bound traffic through FortiGate.

### 1.1 Why Standard SKU Static IPs Can Be Reassigned

- **Standard SKU**: Zone-redundant, supports reassignment between NICs
- **Static allocation**: IP address is retained when dissociated - no risk of losing the address
- **Process**: Dissociate from source NIC --> Associate to target NIC (brief ~5s gap)

---

## 2. Scope - Public IP Inventory

### 2.1 Primary Outbound IPs (2 IPs)

> **DANGER:** These are the most critical IPs. They provide outbound SNAT for all internet-bound traffic. External services (APIs, SaaS, partners) have whitelisted these addresses. They must be migrated first.

| Public IP Address | Azure Resource Name | Region | Currently On | Target NIC | Replaces | Purpose |
|---|---|---|---|---|---|---|
| **52.237.241.132** | `KD-UTM-PublicIP` | East | `ATEUTM05-interface-X1` (SonicWall, KD-Prod-RG) | `ATE-AE-fgt-nic1` (primary) | `68.218.113.249` | Outbound NAT - East production |
| **23.101.226.122** | `Sophos-PublicIP` | South East | `ATEUTM04-interface-X1` (Sophos/ATEUTM04, KD-Mel-Temp) | `ATE-ASE-fgt-nic1` (primary) | `4.200.139.87` | Outbound NAT - SE (DR) |

> **Note:** The existing FortiGate primary public IPs (`68.218.113.249` / `ATE-AE-FGT-PIP2` on East, `4.200.139.87` / `ATE-ASE-fgt-pip2` on SE) will be replaced by the SonicWall/Sophos outbound IPs. These PIP resources will become unassociated after the swap and can be deleted or repurposed later.

### 2.2 KD Service IPs (7 IPs)

| Public IP Name | Public IP Address | East Private IP | SE Mapped IP | Group | Environment | Status |
|---|---|---|---|---|---|---|
| KD-QLD-TIMS-PublicIP | 52.187.240.188 | 10.200.1.6 | 10.200.10.88 | KD-TIMS | Prod | - [ ] |
| KD-SA-TIMS-PublicIP | 52.187.246.55 | 10.200.1.7 | 10.200.10.125 | KD-TIMS | Prod | - [ ] |
| KD-WA-TIMS-PublicIP | 52.187.244.82 | 10.200.1.8 | 10.200.10.153 | KD-TIMS | Prod | - [ ] |
| KD-NSW-TIMS-PublicIP | 13.75.135.21 | 10.200.1.9 | 10.200.10.56 | KD-TIMS | Prod | - [ ] |
| KD-ATESMA01-PublicIP | 40.126.228.221 | 10.200.1.12 | 10.200.10.7 | KD-Other | Prod | - [ ] |
| KD-ConnX-PublicIP | 13.75.229.11 | 10.200.1.13 | - | KD-Other | Prod | - [ ] |
| KD-KDBMEX01-PublicIP | 52.156.166.57 | 10.200.1.14 | 10.200.10.54 | KD-Other | Prod | - [ ] |

### 2.3 KAB Service IPs - Production (8 IPs)

| Public IP Name | Public IP Address | East Private IP | SE Mapped IP | Group | Environment | Status |
|---|---|---|---|---|---|---|
| KAB-Az-Austrics-WA-pip | 13.75.136.76 | 10.200.1.5 | 10.200.10.6 | KAB-Austrics | Prod | - [ ] |
| KAB-Az-Austrics-NSW | 52.156.182.48 | 10.200.1.10 | 10.200.10.9 | KAB-Austrics | Prod | - [ ] |
| KAB-Az-Austrics-SA | 20.191.198.18 | 10.200.1.15 | 10.200.10.11 | KAB-Austrics | Prod | - [ ] |
| KAB-AZ-TIMS-NSW | 52.237.233.233 | 10.200.1.11 | 10.200.10.10 | KAB-TIMS | Prod | - [ ] |
| KAB-AZ-TIMS-QLD | 40.126.224.167 | 10.200.1.16 | 10.200.10.12 | KAB-TIMS | Prod | - [ ] |
| KAB-AZ-TIMS-SA | 20.188.250.100 | 10.200.1.17 | 10.200.10.13 | KAB-TIMS | Prod | - [ ] |
| KAB-AZ-TIMS-WA | 20.188.255.96 | 10.200.1.18 | 10.200.10.14 | KAB-TIMS | Prod | - [ ] |
| KAB-AZ-RDG01 | 4.254.88.95 | 10.200.1.23 | 10.200.10.20 | KAB-RDG | Prod | - [ ] |

### 2.4 KAB Service IPs - UAT (4 IPs)

| Public IP Name | Public IP Address | East Private IP | SE Mapped IP | Group | Environment | Status |
|---|---|---|---|---|---|---|
| KAB-AZ-TIMS-NSW-UAT | 20.188.255.62 | 10.200.1.19 | 10.200.10.15 | KAB-TIMS-UAT | UAT | - [ ] |
| KAB-AZ-TIMS-QLD-UAT | 20.191.207.10 | 10.200.1.20 | 10.200.10.16 | KAB-TIMS-UAT | UAT | - [ ] |
| KAB-AZ-TIMS-WA-UAT | 20.191.201.167 | 10.200.1.21 | 10.200.10.18 | KAB-TIMS-UAT | UAT | - [ ] |
| KAB-AZ-TIMS-SA-UAT | 52.156.180.207 | 10.200.1.22 | 10.200.10.19 | KAB-TIMS-UAT | UAT | - [ ] |

### 2.5 Summary

| Group | Count | Environment | Services |
|---|---|---|---|
| **Primary-Outbound** | **2** | **Prod** | **Outbound NAT / whitelisted internet access (CRITICAL)** |
| KD-TIMS | 4 | Prod | TIMS state-based endpoints (QLD, SA, WA, NSW) |
| KD-Other | 3 | Prod | ATESMA01, ConnX, KDBMEX01 |
| KAB-Austrics | 3 | Prod | Austrics state-based endpoints (WA, NSW, SA) |
| KAB-TIMS | 4 | Prod | TIMS state-based endpoints (NSW, QLD, SA, WA) |
| KAB-TIMS-UAT | 4 | UAT | TIMS UAT state-based endpoints |
| KAB-RDG | 1 | Prod | Remote Desktop Gateway |
| **TOTAL** | **21** | **2 Primary + 15 Prod + 4 UAT** | |

---

## 3. Architecture & Approach

### 3.1 NIC Inventory

| Device | VM Name | NIC Name | Private IP | Current Public IP | Role | Resource Group |
|---|---|---|---|---|---|---|
| **FortiGate East** | ATE-AE-fgt | `ATE-AE-fgt-nic1` | `10.200.1.4` | `68.218.113.249` (`ATE-AE-FGT-PIP2`) *(to be replaced by `52.237.241.132`)* | External (public IPs --> here) | KD-Prod-RG |
| **FortiGate East** | ATE-AE-fgt | `ATE-AE-fgt-nic2` | `10.200.1.68` | - | Internal (route next-hop) | KD-Prod-RG |
| **FortiGate SE** | ATE-ASE-fgt | `ATE-ASE-fgt-nic1` | `10.201.1.4` | `4.200.139.87` (`ATE-ASE-fgt-pip2`) *(to be replaced by `23.101.226.122`)* | External | KD-Prod-RG-asr |
| **FortiGate SE** | ATE-ASE-fgt | `ATE-ASE-fgt-nic2` | `10.201.1.68` | - | Internal (route next-hop) | KD-Prod-RG-asr |
| **SonicWall** | ATEUTM05 | `ATEUTM05-interface-X0` | `10.200.10.4` | - | LAN / Internal | KD-Prod-RG |
| **SonicWall** | ATEUTM05 | `ATEUTM05-interface-X1` | `10.200.254.4` | `52.237.241.132` (primary) + 19 secondary | WAN / External (public IPs currently here) | KD-Prod-RG |

> **Note:** Migration path:
> 1. **Primary outbound IPs first:** `52.237.241.132` --> `ATE-AE-fgt-nic1` (replacing `68.218.113.249`), `23.101.226.122` --> `ATE-ASE-fgt-nic1` (replacing `4.200.139.87`)
> 2. **Default route (0.0.0.0/0):** Update route tables to point to FortiGate as internet gateway
> 3. **Service IPs:** 19 secondary IPs move from `ATEUTM05-interface-X1` (10.200.254.x) --> `ATE-AE-fgt-nic1` (10.200.1.x)

### 3.2 Current State

| Component | Details |
|---|---|
| **Primary Outbound (East)** | `52.237.241.132` (`KD-UTM-PublicIP`) on `ATEUTM05-interface-X1` (SonicWall, KD-Prod-RG) -- used for outbound SNAT, whitelisted by external services |
| **Primary Outbound (SE)** | `23.101.226.122` (`Sophos-PublicIP`) on `ATEUTM04-interface-X1` (Sophos VM, KD-Mel-Temp) -- used for outbound SNAT (DR) |
| **FortiGate East Primary** | `68.218.113.249` (`ATE-AE-FGT-PIP2`) on `ATE-AE-fgt-nic1` -- current FortiGate primary (to be replaced) |
| **FortiGate SE Primary** | `4.200.139.87` (`ATE-ASE-fgt-pip2`) on `ATE-ASE-fgt-nic1` -- current FortiGate primary (to be replaced) |
| **Default Route (0.0.0.0/0)** | Currently points to SonicWall -- internet traffic routes via SonicWall |
| **Service Source NIC** | `ATEUTM05-interface-X1` (SonicWall WAN, 10.200.254.4) in KD-Prod-RG with 19 secondary IP configurations |
| **Service Private IP Range** | 10.200.254.5 - 10.200.254.23 (secondary IPs on SonicWall X1) |
| **Public IPs** | All Standard SKU, Static allocation, IPv4 |
| **NAT/VIP** | SonicWall performs destination NAT from public IP --> internal service |

### 3.3 Target State

| Component | FortiGate East (Production) | FortiGate South East (DR) |
|---|---|---|
| **Primary Outbound IP** | `52.237.241.132` (replaces `68.218.113.249`) | `23.101.226.122` (replaces `4.200.139.87`) |
| **Default Route (0.0.0.0/0)** | Via `10.200.1.68` (FortiGate East nic2) | Via `10.201.1.68` (FortiGate SE nic2) |
| **Target NIC** | `ATE-AE-fgt-nic1` (10.200.1.4, KD-Prod-RG) | `ATE-ASE-fgt-nic1` (10.201.1.4, KD-Prod-RG-asr) |
| **Service Private IP Range** | 10.200.1.5 - 10.200.1.23 | 10.200.10.x (SE mapped IPs) |
| **Service Public IPs** | 19 public IPs reassigned from SonicWall NIC | N/A (internal VIP testing only) |
| **NAT/VIP** | FortiGate VIP objects (extip --> mappedip) | FortiGate VIP objects (same config, SE IPs) |

### 3.4 Migration Approach

> **Note:** Strategy: South East first, then East. Primary outbound IP first, then service VIPs.
>
> **Stage 1 (SE):** Move the primary outbound IP to FortiGate SE, update the default route (0.0.0.0/0) to point to FortiGate, then configure and test service VIPs. SE carries no production traffic, so this is zero-risk validation.
>
> **Stage 2 (East):** Repeat for East (production) -- primary IP first, then default route, then service VIPs group-by-group.

| Phase | Region | Action | IPs | Environment | Risk |
|---|---|---|---|---|---|
| **Phase 1A - SE Primary IP** | South East (DR) | Move `23.101.226.122` to FortiGate SE (replacing `4.200.139.87`) | 1 | DR only | LOW |
| **Phase 1B - SE Default Route** | South East (DR) | Update 0.0.0.0/0 on SE route table --> FortiGate SE (`10.201.1.68`) | - | DR only | LOW |
| **Phase 1C - SE VIP Testing** | South East (DR) | Configure and test all 19 VIPs on SE FortiGate | 19 | DR only | LOW |
| **Phase 2A - East Primary IP** | East (Prod) | Move `52.237.241.132` to FortiGate East (replacing `68.218.113.249`) | 1 | Prod | HIGH |
| **Phase 2B - East Default Route** | East (Prod) | Update 0.0.0.0/0 on East route table --> FortiGate East (`10.200.1.68`) | - | Prod | HIGH |
| **Phase 3 - East UAT Pilot** | East (Prod) | KAB-TIMS-UAT service IPs | 4 | UAT | LOW |
| **Phase 4 - East KD TIMS** | East (Prod) | KD-TIMS service IPs | 4 | Prod | MEDIUM |
| **Phase 5 - East KD Other** | East (Prod) | KD-Other service IPs | 3 | Prod | MEDIUM |
| **Phase 6 - East KAB Austrics** | East (Prod) | KAB-Austrics service IPs | 3 | Prod | MEDIUM |
| **Phase 7 - East KAB TIMS** | East (Prod) | KAB-TIMS service IPs | 4 | Prod | MEDIUM |
| **Phase 8 - East KAB RDG** | East (Prod) | KAB-RDG service IP | 1 | Prod | MEDIUM |

---

## 4. Prerequisites

> **Warning:** All prerequisites must be verified before starting migration.

#### 4.1 Azure Prerequisites

- [ ] Azure CLI installed and logged in (`az login`)
- [ ] Permissions to modify NICs, Public IPs, and Route Tables in KD-Prod-RG and KD-Prod-RG-asr
- [ ] **Primary outbound IP names identified:** Azure resource names for `52.237.241.132` (East) and `23.101.226.122` (SE)
- [ ] **Current FortiGate primary IP names confirmed:** `ATE-AE-FGT-PIP2` (`68.218.113.249`, East) and `ATE-ASE-fgt-pip2` (`4.200.139.87`, SE)
- [ ] **Current 0.0.0.0/0 route recorded** for both `KD-Prod-RouteTable` (East) and `KD-Mel-RouteTable` (SE)
- [ ] Target NIC confirmed: `ATE-AE-fgt-nic1` (FortiGate East external, 10.200.1.4)
- [ ] Source NIC confirmed: `ATEUTM05-interface-X1` (SonicWall WAN, 10.200.254.4)
- [ ] NSG on `ATE-AE-fgt-nic1` allows required inbound traffic -- **currently allows all traffic (no NSG restrictions)**. SonicWall NIC has `ATEUTM03Syd-NSG` with management restrictions (see Section 8.4 post-migration hardening)
- [ ] Script NIC names configured (`$TargetNicName = "ATE-AE-fgt-nic1"`, `$SourceNicName = "ATEUTM05-interface-X1"`)

#### 4.2 FortiGate Prerequisites

- [ ] FortiGate South East (`ATE-ASE-fgt`) accessible and healthy (for Phase 1 - SE proof of concept)
- [ ] FortiGate East (`ATE-AE-fgt`) accessible and healthy (for Phase 2+ - production migration)
- [ ] VIP objects pre-configured on SE FortiGate first (Section 6)
- [ ] VIP objects pre-configured on East FortiGate (after SE validation)
- [ ] Firewall policies created to permit traffic through VIPs (both FortiGates)

#### 4.3 Verify NIC Configuration

```powershell
# Verify FortiGate East external NIC
az network nic show --resource-group KD-Prod-RG --name ATE-AE-fgt-nic1 --query "{Name:name, PrimaryIP:ipConfigurations[0].privateIpAddress}" --output table

# Verify SonicWall WAN NIC (source - public IPs currently here)
az network nic show --resource-group KD-Prod-RG --name ATEUTM05-interface-X1 --query "{Name:name, PrimaryIP:ipConfigurations[0].privateIpAddress, IPConfigs:length(ipConfigurations)}" --output table

# Confirm public IP is on SonicWall NIC
az network public-ip show --resource-group KD-Prod-RG --name KD-QLD-TIMS-PublicIP --query "ipConfiguration.id" --output tsv
```

---

## 5. Implementation Steps

### Step 1: Discovery - Verify Current State

| Step | Action | Command | Verified |
|---|---|---|---|
| 1.1 | Verify FortiGate East primary public IP (`ATE-AE-FGT-PIP2` = `68.218.113.249`) | `az network public-ip show --resource-group KD-Prod-RG --name ATE-AE-FGT-PIP2 --query ipAddress` | - [ ] |
| 1.2 | Verify FortiGate SE primary public IP (`ATE-ASE-fgt-pip2` = `4.200.139.87`) | `az network public-ip show --resource-group KD-Prod-RG-asr --name ATE-ASE-fgt-pip2 --query ipAddress` | - [ ] |
| 1.3 | Verify outbound IP `52.237.241.132` is currently on SonicWall | Check NIC association | - [ ] |
| 1.4 | Verify outbound IP `23.101.226.122` location (SE) | Check NIC association | - [ ] |
| 1.5 | Run service IP discovery | `.\azure-pip-migration-script.ps1 -Discover` | - [ ] |
| 1.6 | Confirm all 19 service IPs are on `ATEUTM05-interface-X1` | Review discovery output | - [ ] |
| 1.7 | Record current 0.0.0.0/0 route on both route tables | `az network route-table route list` for both RGs | - [ ] |
| 1.8 | Document current SonicWall NAT/VIP rules for each IP | Screenshot SonicWall config | - [ ] |

### Phase 1: South East - Primary IP + Default Route + VIP Testing (DR - Zero Risk)

> **Note:** Why SE first: The SE FortiGate handles DR traffic only. Testing the primary IP swap, default route change, and VIP configuration here validates the entire approach with zero risk to production services.

#### Step 2: Phase 1A - Move SE Primary Outbound IP

> **DANGER:** This is the most critical step. Moving the primary outbound IP ensures FortiGate SE uses `23.101.226.122` for outbound NAT -- the IP whitelisted by external services.

| Step | Action | Command | Verified |
|---|---|---|---|
| 2.1 | Dissociate `Sophos-PublicIP` (23.101.226.122) from `ATEUTM04-interface-X1` | `az network nic ip-config update --resource-group KD-Mel-Temp --nic-name ATEUTM04-interface-X1 --name ipconfig1 --remove publicIpAddress` | - [ ] |
| 2.2 | Swap FortiGate SE primary public IP: replace `4.200.139.87` with `Sophos-PublicIP` on `ATE-ASE-fgt-nic1` primary IP config | `az network nic ip-config update --resource-group KD-Prod-RG-asr --nic-name ATE-ASE-fgt-nic1 --name ipconfig1 --public-ip-address Sophos-PublicIP` | - [ ] |
| 2.3 | Verify SE FortiGate primary IP is now `23.101.226.122` | FortiGate CLI: `diagnose sys waninfo ipify port1` | - [ ] |

#### Step 3: Phase 1B - Update SE Default Route (0.0.0.0/0)

| Step | Action | Command | Verified |
|---|---|---|---|
| 3.1 | Create/update 0.0.0.0/0 route on SE route table to point to FortiGate SE | `az network route-table route create --resource-group KD-Prod-RG-asr --route-table-name KD-Mel-RouteTable --name Default-Internet --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.201.1.68` | - [ ] |
| 3.2 | Verify route is active | `az network route-table route show --resource-group KD-Prod-RG-asr --route-table-name KD-Mel-RouteTable --name Default-Internet` | - [ ] |

#### Step 4: Validate SE Outbound Connectivity

| Step | Action | Verified |
|---|---|---|
| 4.1 | From SE VM: verify outbound internet works (`curl ifconfig.me` should show `23.101.226.122`) | - [ ] |
| 4.2 | Test connectivity to known whitelisted external services from SE | - [ ] |
| 4.3 | Verify FortiGate SE session table shows outbound NAT traffic | - [ ] |
| 4.4 | **GATE CHECK:** SE outbound via FortiGate validated - proceed to VIP testing | - [ ] |

> **DANGER:** Rollback (SE Primary IP): If outbound fails -- revert the 0.0.0.0/0 route to previous next-hop, then swap the public IP back to `4.200.139.87` on FortiGate SE nic1. See Section 8.

#### Step 5: Phase 1C - Configure and Test SE VIPs

| Step | Action | Verified |
|---|---|---|
| 5.1 | Create all 19 VIP objects on **SE FortiGate** using SE mapped IPs (Section 6) | - [ ] |
| 5.2 | Create firewall policies permitting inbound traffic through VIPs on SE FortiGate | - [ ] |
| 5.3 | Verify SE FortiGate accepts 10.200.10.x secondary IPs on external interface | - [ ] |
| 5.4 | From Azure SE VM (10.201.10.61): test connectivity to each VIP mapped IP (10.200.10.x) | - [ ] |
| 5.5 | Verify SE FortiGate VIP sessions: `diagnose sys session list` | - [ ] |
| 5.6 | Verify traffic logs show correct VIP NAT translation on SE FortiGate | - [ ] |
| 5.7 | Test at least one service end-to-end through SE FortiGate VIP | - [ ] |
| 5.8 | **GATE CHECK:** Full SE proof of concept validated (outbound + VIPs) - proceed to East only after sign-off | - [ ] |

> **DANGER:** Rollback (SE VIPs): If SE VIP testing fails, remove VIP objects and firewall policies from SE FortiGate. No public IPs are affected - this is config-only rollback.

### Phase 2: East - Primary IP + Default Route (Production)

> **Warning:** Only proceed after full SE proof of concept is validated (Step 5.8 above).

> **DANGER:** CRITICAL: This changes outbound connectivity for all production services. External services whitelisted on `52.237.241.132` must work immediately after swap. Schedule during maintenance window.

#### Step 6: Phase 2A - Move East Primary Outbound IP

| Step | Action | Command | Verified |
|---|---|---|---|
| 6.1 | Dissociate `KD-UTM-PublicIP` (52.237.241.132) from `ATEUTM05-interface-X1` | `az network nic ip-config update --resource-group KD-Prod-RG --nic-name ATEUTM05-interface-X1 --name ipconfig1 --remove publicIpAddress` | - [ ] |
| 6.2 | Swap FortiGate East primary public IP: replace `68.218.113.249` with `KD-UTM-PublicIP` on `ATE-AE-fgt-nic1` primary IP config | `az network nic ip-config update --resource-group KD-Prod-RG --nic-name ATE-AE-fgt-nic1 --name ipconfig1 --public-ip-address KD-UTM-PublicIP` | - [ ] |
| 6.3 | Verify East FortiGate primary IP is now `52.237.241.132` | FortiGate CLI: `diagnose sys waninfo ipify port1` | - [ ] |

#### Step 7: Phase 2B - Update East Default Route (0.0.0.0/0)

| Step | Action | Command | Verified |
|---|---|---|---|
| 7.1 | Create/update 0.0.0.0/0 route on East route table to point to FortiGate East | `az network route-table route create --resource-group KD-Prod-RG --route-table-name KD-Prod-RouteTable --name Default-Internet --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.200.1.68` | - [ ] |
| 7.2 | Verify route is active | `az network route-table route show --resource-group KD-Prod-RG --route-table-name KD-Prod-RouteTable --name Default-Internet` | - [ ] |

#### Step 8: Validate East Outbound Connectivity

| Step | Action | Verified |
|---|---|---|
| 8.1 | From East VM: verify outbound internet works (`curl ifconfig.me` should show `52.237.241.132`) | - [ ] |
| 8.2 | Test connectivity to known whitelisted external services from East | - [ ] |
| 8.3 | Verify FortiGate East session table shows outbound NAT traffic | - [ ] |
| 8.4 | Monitor for 15 minutes for any outbound service degradation | - [ ] |
| 8.5 | **GATE CHECK:** East outbound via FortiGate validated - proceed to service IP migration | - [ ] |

> **DANGER:** Rollback (East Primary IP): If outbound fails -- **immediately** revert the 0.0.0.0/0 route to previous next-hop, then swap the public IP back to `68.218.113.249` on FortiGate East nic1. See Section 8.

### Phase 3-8: East - Service IP Migration

> **Warning:** Only proceed after East outbound is validated (Step 8.5 above).

#### Step 9: Pre-stage East FortiGate VIPs

| Step | Action | Verified |
|---|---|---|
| 9.1 | Create all 19 VIP objects on **East FortiGate** using East IPs (Section 6) | - [ ] |
| 9.2 | Create firewall policies permitting inbound traffic through VIPs on East FortiGate | - [ ] |

#### Step 10: Phase 3 - East UAT Pilot (4 IPs)

> **Note:** Start with UAT on East to validate the public IP reassignment process before touching production.

| Step | Action | Command | Verified |
|---|---|---|---|
| 10.1 | Dry run UAT group | `.\azure-pip-migration-script.ps1 -Migrate -Group "KAB-TIMS-UAT" -WhatIf` | - [ ] |
| 10.2 | Migrate UAT group | `.\azure-pip-migration-script.ps1 -Migrate -Group "KAB-TIMS-UAT"` | - [ ] |
| 10.3 | Verify UAT associations moved to East FortiGate NIC | `.\azure-pip-migration-script.ps1 -Discover` | - [ ] |
| 10.4 | Test UAT TIMS connectivity from each state endpoint | Access UAT TIMS URLs via browser/curl | - [ ] |
| 10.5 | If UAT fails: `.\azure-pip-migration-script.ps1 -Rollback -Group "KAB-TIMS-UAT"` | Rollback command (use only if needed) | - [ ] |

#### Step 11: Phase 4-8 - East Production IPs (15 IPs)

> **Warning:** Production migration should be performed during a maintenance window (outside business hours).

Repeat for each production group in order:

| Phase | Group | Dry Run Command | Migrate Command | Rollback Command | Verified |
|---|---|---|---|---|---|
| Phase 4 | KD-TIMS (4 IPs) | `-Migrate -Group "KD-TIMS" -WhatIf` | `-Migrate -Group "KD-TIMS"` | `-Rollback -Group "KD-TIMS"` | - [ ] |
| Phase 5 | KD-Other (3 IPs) | `-Migrate -Group "KD-Other" -WhatIf` | `-Migrate -Group "KD-Other"` | `-Rollback -Group "KD-Other"` | - [ ] |
| Phase 6 | KAB-Austrics (3 IPs) | `-Migrate -Group "KAB-Austrics" -WhatIf` | `-Migrate -Group "KAB-Austrics"` | `-Rollback -Group "KAB-Austrics"` | - [ ] |
| Phase 7 | KAB-TIMS (4 IPs) | `-Migrate -Group "KAB-TIMS" -WhatIf` | `-Migrate -Group "KAB-TIMS"` | `-Rollback -Group "KAB-TIMS"` | - [ ] |
| Phase 8 | KAB-RDG (1 IP) | `-Migrate -Group "KAB-RDG" -WhatIf` | `-Migrate -Group "KAB-RDG"` | `-Rollback -Group "KAB-RDG"` | - [ ] |

**Per-group process:**

1. Run dry run (`-WhatIf`) and review output
2. Execute migration
3. Run `-Discover` to verify new associations
4. Test service connectivity through each migrated IP
5. If any IP fails, rollback that group immediately: `-Rollback -Group "GROUP-NAME"`
6. For single IP rollback: `-Rollback -Name "IP-NAME"`
7. Proceed to next group only after validation passes

### Step 12: Final Validation

| Step | Action | Verified |
|---|---|---|
| 12.1 | Verify outbound: East VMs show `52.237.241.132` as public IP | - [ ] |
| 12.2 | Verify outbound: SE VMs show `23.101.226.122` as public IP | - [ ] |
| 12.3 | Test all whitelisted external services from both regions | - [ ] |
| 12.4 | Run full discovery - all 19 service IPs on East FortiGate NIC | - [ ] |
| 12.5 | Test all production TIMS endpoints (KD + KAB, all states) | - [ ] |
| 12.6 | Test all Austrics endpoints (WA, NSW, SA) | - [ ] |
| 12.7 | Test ATESMA01, ConnX, KDBMEX01 connectivity | - [ ] |
| 12.8 | Test RDG01 Remote Desktop Gateway access | - [ ] |
| 12.9 | Test all UAT TIMS endpoints | - [ ] |
| 12.10 | Verify SE FortiGate VIPs still operational (DR readiness) | - [ ] |
| 12.11 | Monitor for 30 minutes for any service degradation | - [ ] |

---

## 6. FortiGate Configuration

> **Note:** Pre-stage: These VIP and policy configurations can be created on FortiGate **before** the public IP migration. They only become active once the public IPs are associated with the FortiGate NIC and Azure routes the traffic.

### 6.1 Deployment Order

> **Note:** Deploy to SE FortiGate FIRST (Phase 1 proof of concept), then East FortiGate (Phase 2+). Both FortiGates get the same VIP structure but with different IPs.

### 6.2 VIP Objects - East FortiGate (68.218.113.249)

The `extip` is the FortiGate East NIC secondary IP (10.200.1.x) that Azure maps to the public IP. The `mappedip` is the backend service IP (10.200.10.x).

```
config firewall vip
    # --- KD TIMS (extip = FortiGate East NIC IP, mappedip = backend service) ---
    edit "KD-QLD-TIMS-VIP"
        set extip 10.200.1.6
        set mappedip "10.200.10.88"
        set extintf "port1"
    next
    edit "KD-SA-TIMS-VIP"
        set extip 10.200.1.7
        set mappedip "10.200.10.125"
        set extintf "port1"
    next
    edit "KD-WA-TIMS-VIP"
        set extip 10.200.1.8
        set mappedip "10.200.10.153"
        set extintf "port1"
    next
    edit "KD-NSW-TIMS-VIP"
        set extip 10.200.1.9
        set mappedip "10.200.10.56"
        set extintf "port1"
    next

    # --- KD Other ---
    edit "KD-ATESMA01-VIP"
        set extip 10.200.1.12
        set mappedip "10.200.10.7"
        set extintf "port1"
    next
    edit "KD-ConnX-VIP"
        set extip 10.200.1.13
        set mappedip "TBD"
        set extintf "port1"
    next
    edit "KD-KDBMEX01-VIP"
        set extip 10.200.1.14
        set mappedip "10.200.10.54"
        set extintf "port1"
    next

    # --- KAB Austrics ---
    edit "KAB-Austrics-WA-VIP"
        set extip 10.200.1.5
        set mappedip "10.200.10.6"
        set extintf "port1"
    next
    edit "KAB-Austrics-NSW-VIP"
        set extip 10.200.1.10
        set mappedip "10.200.10.9"
        set extintf "port1"
    next
    edit "KAB-Austrics-SA-VIP"
        set extip 10.200.1.15
        set mappedip "10.200.10.11"
        set extintf "port1"
    next

    # --- KAB TIMS ---
    edit "KAB-TIMS-NSW-VIP"
        set extip 10.200.1.11
        set mappedip "10.200.10.10"
        set extintf "port1"
    next
    edit "KAB-TIMS-QLD-VIP"
        set extip 10.200.1.16
        set mappedip "10.200.10.12"
        set extintf "port1"
    next
    edit "KAB-TIMS-SA-VIP"
        set extip 10.200.1.17
        set mappedip "10.200.10.13"
        set extintf "port1"
    next
    edit "KAB-TIMS-WA-VIP"
        set extip 10.200.1.18
        set mappedip "10.200.10.14"
        set extintf "port1"
    next

    # --- KAB TIMS UAT ---
    edit "KAB-TIMS-NSW-UAT-VIP"
        set extip 10.200.1.19
        set mappedip "10.200.10.15"
        set extintf "port1"
    next
    edit "KAB-TIMS-QLD-UAT-VIP"
        set extip 10.200.1.20
        set mappedip "10.200.10.16"
        set extintf "port1"
    next
    edit "KAB-TIMS-WA-UAT-VIP"
        set extip 10.200.1.21
        set mappedip "10.200.10.18"
        set extintf "port1"
    next
    edit "KAB-TIMS-SA-UAT-VIP"
        set extip 10.200.1.22
        set mappedip "10.200.10.19"
        set extintf "port1"
    next

    # --- KAB RDG ---
    edit "KAB-RDG01-VIP"
        set extip 10.200.1.23
        set mappedip "10.200.10.20"
        set extintf "port1"
    next
end

# Firewall policy for VIP traffic
config firewall policy
    edit 0
        set name "Inbound-VIP-Services"
        set srcintf "port1"
        set dstintf "port2"
        set srcaddr "all"
        set dstaddr "KD-QLD-TIMS-VIP" "KD-SA-TIMS-VIP" "KD-WA-TIMS-VIP" "KD-NSW-TIMS-VIP"
                     "KD-ATESMA01-VIP" "KD-ConnX-VIP" "KD-KDBMEX01-VIP"
                     "KAB-Austrics-WA-VIP" "KAB-Austrics-NSW-VIP" "KAB-Austrics-SA-VIP"
                     "KAB-TIMS-NSW-VIP" "KAB-TIMS-QLD-VIP" "KAB-TIMS-SA-VIP" "KAB-TIMS-WA-VIP"
                     "KAB-TIMS-NSW-UAT-VIP" "KAB-TIMS-QLD-UAT-VIP" "KAB-TIMS-WA-UAT-VIP" "KAB-TIMS-SA-UAT-VIP"
                     "KAB-RDG01-VIP"
        set action accept
        set schedule "always"
        set service "ALL"
        set logtraffic all
    next
end
```

> **Note:** SE FortiGate VIP objects are out of scope for this CR. The current SonicWall does not have equivalent NAT/VIP rules for SE either. SE VIP configuration will be a follow-up task after the project. This CR only covers adding the public IPs to the SE FortiGate NIC.

> **Note:** SE FortiGate VIP objects are out of scope for this CR. The current SonicWall does not have equivalent NAT/VIP rules for SE either. SE VIP configuration will be a follow-up task after the project. This CR only covers adding the public IPs to the SE FortiGate NIC.

---

## 7. Validation & Testing

> **Note:** Test methodology: The public IP address does not change -- only the backend NIC changes (SonicWall --> FortiGate). Most services are source-IP restricted or have no inbound FW rules, so external port tests (Test-NetConnection) are **not possible** from a standard workstation. Instead we verify:
> **Pre-cutover:** PIP is associated to SonicWall NIC (`az network public-ip show`)
> **Post-cutover:** PIP is associated to FortiGate NIC (`az network public-ip show`) + FortiGate session/log verification
> **DNS services:** Additionally verified with `nslookup` + `curl.exe` (works from anywhere)
> **KD Bus testing:** Business confirms application-level functionality after cutover

### 7.1 Test Tools

| Test | Command (PowerShell) | What it proves |
|---|---|---|
| PIP Association | `az network public-ip show -g KD-Prod-RG -n <PIP-NAME> --query "ipConfiguration.id" -o tsv` | PIP is on correct NIC (SonicWall pre / FortiGate post) |
| HTTPS Response | `curl.exe -sk https://<FQDN> -o NUL -w "%{http_code}"` | Web service responds via DNS (services with FQDN only) |
| DNS Resolution | `nslookup <FQDN>` | DNS resolves to correct public IP |
| FortiGate Session | `diagnose sys session filter dip <PRIVATE_IP>` / `diagnose sys session list` | Traffic is flowing through FortiGate VIP (post-cutover only) |

### 7.2 Azure East -- Service IP Tests

#### KD TIMS (4 IPs)

| Name | Public IP | Old Private | New Private | DNS | Access | Pre-Cutover Test | Pre Pass | Post-Cutover Test | Post Pass | KD Bus Test |
|---|---|---|---|---|---|---|---|---|---|---|
| KD-QLD-TIMS-PublicIP | `52.187.240.188` | `10.200.254.6` | `10.200.1.6` | -- | No ext. test | `az network public-ip show -g KD-Prod-RG -n KD-QLD-TIMS-PublicIP --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KD-QLD-TIMS-PublicIP --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KD-SA-TIMS-PublicIP | `52.187.246.55` | `10.200.254.7` | `10.200.1.7` | -- | No ext. test | `az network public-ip show -g KD-Prod-RG -n KD-SA-TIMS-PublicIP --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KD-SA-TIMS-PublicIP --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KD-WA-TIMS-PublicIP | `52.187.244.82` | `10.200.254.8` | `10.200.1.8` | -- | No ext. test | `az network public-ip show -g KD-Prod-RG -n KD-WA-TIMS-PublicIP --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KD-WA-TIMS-PublicIP --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KD-NSW-TIMS-PublicIP | `13.75.135.21` | `10.200.254.9` | `10.200.1.9` | -- | No ext. test | `az network public-ip show -g KD-Prod-RG -n KD-NSW-TIMS-PublicIP --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KD-NSW-TIMS-PublicIP --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |

#### KD Other Services (3 IPs)

| Name | Public IP | Old Private | New Private | DNS | Access | Pre-Cutover Test | Pre Pass | Post-Cutover Test | Post Pass | KD Bus Test |
|---|---|---|---|---|---|---|---|---|---|---|
| KD-ATESMA01-PublicIP | `40.126.228.221` | `10.200.254.12` | `10.200.1.12` | `tims-qld.hornibrook.com.au` | Public + DNS | `nslookup tims-qld.hornibrook.com.au` / `curl.exe -sk https://tims-qld.hornibrook.com.au -o NUL -w "%{http_code}"` | - [ ] | `nslookup tims-qld.hornibrook.com.au` / `curl.exe -sk https://tims-qld.hornibrook.com.au -o NUL -w "%{http_code}"` / `az network public-ip show -g KD-Prod-RG -n KD-ATESMA01-PublicIP --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KD-ConnX-PublicIP | `13.75.229.11` | `10.200.254.13` | `10.200.1.13` | `kdb-connx.keolisdowner.com.au` / `kdb-connx-sandbox.keolisdowner.com.au` | No FW rules | `nslookup kdb-connx.keolisdowner.com.au` | - [ ] | `nslookup kdb-connx.keolisdowner.com.au` / `az network public-ip show -g KD-Prod-RG -n KD-ConnX-PublicIP --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KD-KDBMEX01-PublicIP | `52.156.166.57` | `10.200.254.14` | `10.200.1.14` | `kdb-mex.keolisdowner.com.au` | Restricted | `nslookup kdb-mex.keolisdowner.com.au` | - [ ] | `nslookup kdb-mex.keolisdowner.com.au` / `az network public-ip show -g KD-Prod-RG -n KD-KDBMEX01-PublicIP --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |

#### KAB Austrics (3 IPs -- TrapezeeGroup restricted)

| Name | Public IP | Old Private | New Private | DNS | Access | Pre-Cutover Test | Pre Pass | Post-Cutover Test | Post Pass | KD Bus Test |
|---|---|---|---|---|---|---|---|---|---|---|
| KAB-Az-Austrics-WA-pip | `13.75.136.76` | `10.200.254.5` | `10.200.1.5` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-Az-Austrics-WA-pip --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-Az-Austrics-WA-pip --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KAB-Az-Austrics-NSW | `52.156.182.48` | `10.200.254.10` | `10.200.1.10` | -- | No FW rules | `az network public-ip show -g KD-Prod-RG -n KAB-Az-Austrics-NSW --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-Az-Austrics-NSW --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KAB-Az-Austrics-SA | `20.191.198.18` | `10.200.254.15` | `10.200.1.15` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-Az-Austrics-SA --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-Az-Austrics-SA --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |

#### KAB TIMS Production (4 IPs -- TrapezeeGroup restricted)

| Name | Public IP | Old Private | New Private | DNS | Access | Pre-Cutover Test | Pre Pass | Post-Cutover Test | Post Pass | KD Bus Test |
|---|---|---|---|---|---|---|---|---|---|---|
| KAB-AZ-TIMS-NSW | `52.237.233.233` | `10.200.254.11` | `10.200.1.11` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-NSW --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-NSW --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KAB-AZ-TIMS-QLD | `40.126.224.167` | `10.200.254.16` | `10.200.1.16` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-QLD --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-QLD --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KAB-AZ-TIMS-SA | `20.188.250.100` | `10.200.254.17` | `10.200.1.17` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-SA --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-SA --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KAB-AZ-TIMS-WA | `20.188.255.96` | `10.200.254.18` | `10.200.1.18` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-WA --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-WA --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |

#### KAB TIMS UAT (4 IPs -- TrapezeeGroup restricted)

| Name | Public IP | Old Private | New Private | DNS | Access | Pre-Cutover Test | Pre Pass | Post-Cutover Test | Post Pass | KD Bus Test |
|---|---|---|---|---|---|---|---|---|---|---|
| KAB-AZ-TIMS-NSW-UAT | `20.188.255.62` | `10.200.254.19` | `10.200.1.19` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-NSW-UAT --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-NSW-UAT --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KAB-AZ-TIMS-QLD-UAT | `20.191.207.10` | `10.200.254.20` | `10.200.1.20` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-QLD-UAT --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-QLD-UAT --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KAB-AZ-TIMS-WA-UAT | `20.191.201.167` | `10.200.254.21` | `10.200.1.21` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-WA-UAT --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-WA-UAT --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |
| KAB-AZ-TIMS-SA-UAT | `52.156.180.207` | `10.200.254.22` | `10.200.1.22` | -- | TrapezeeGroup | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-SA-UAT --query "ipConfiguration.id" -o tsv` | - [ ] | `az network public-ip show -g KD-Prod-RG -n KAB-AZ-TIMS-SA-UAT --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |

#### KAB RDG (1 IP)

| Name | Public IP | Old Private | New Private | DNS | Access | Pre-Cutover Test | Pre Pass | Post-Cutover Test | Post Pass | KD Bus Test |
|---|---|---|---|---|---|---|---|---|---|---|
| KAB-AZ-RDG01 | `4.254.88.95` | `10.200.254.23` | `10.200.1.23` | `rdg.keolisdowner.com.au` | Public + DNS | `nslookup rdg.keolisdowner.com.au` / `curl.exe -sk https://rdg.keolisdowner.com.au -o NUL -w "%{http_code}"` | - [ ] | `nslookup rdg.keolisdowner.com.au` / `curl.exe -sk https://rdg.keolisdowner.com.au -o NUL -w "%{http_code}"` / `az network public-ip show -g KD-Prod-RG -n KAB-AZ-RDG01 --query "ipConfiguration.id" -o tsv` *Expect: ATE-AE-fgt-nic1* | - [ ] | - [ ] |

### 7.3 Azure South East -- DR IPs (Not Implemented)

> **Warning:** No testing required. These SE/DR IPs do not have firewall rules on the current SonicWall either. They are out of scope for this CR and will be configured as a follow-up task. Listing for reference only.

| Name | Public IP | Old Private | New Private | Status |
|---|---|---|---|---|
| KD-NSW-TIMS-PublicIP-DR | `40.115.65.170` | `10.201.254.6` | `10.201.1.6` | Not implemented |
| KD-SA-TIMS-PublicIP-DR | `23.101.232.239` | `10.201.254.8` | `10.201.1.8` | Not implemented |
| KD-QLD-TIMS-PublicIP-DR | `40.115.66.153` | `10.201.254.7` | `10.201.1.7` | Not implemented |
| KD-WA-TIMS-PublicIP-DR | `40.115.67.47` | `10.201.254.9` | `10.201.1.9` | Not implemented |
| KD-ConnX-PublicIP-DR | `52.243.67.225` | `10.201.254.13` | `10.201.1.13` | Not implemented |
| KD-SMA-PublicIP-DR | `13.70.158.180` | `10.201.254.12` | `10.201.1.12` | Not implemented |
| KD-KDBMEX01-PublicIP-DR | `13.77.2.8` | `10.201.254.14` | `10.201.1.14` | Not implemented |
| KAB-Az-Austrics-WA-PIP | -- | `10.201.254.5` | `10.201.1.5` | Not implemented |

### 7.4 Post-Cutover FortiGate Verification (Per IP)

After each service IP is migrated, run these on the **FortiGate East CLI**:

| Check | Command | Expected | Pass |
|---|---|---|---|
| PIP associated to FortiGate NIC | `az network public-ip show -g KD-Prod-RG -n <PIP-NAME> --query "ipConfiguration.id" -o tsv` | Path contains `ATE-AE-fgt-nic1` | - [ ] |
| VIP session visible | `diagnose sys session filter dip <NEW-PRIVATE-IP>` / `diagnose sys session list` | Active sessions to backend IP | - [ ] |
| Traffic log | `execute log filter field dstip <NEW-PRIVATE-IP>` / `execute log display` | action=accept entries | - [ ] |

### 7.5 Test Legend

| Colour | Meaning |
|---|---|
| **Green** | Public + DNS -- testable from anywhere via `nslookup` + `curl.exe` |
| **Yellow** | Restricted / no DNS -- verify via `az network public-ip show` (PIP association check) |
| **Red** | No firewall rules -- verify via `az network public-ip show` only |
| **Grey** | DR / Not implemented -- no testing needed for this CR |

> **Note:** Key point: The public IP address does not change during migration. **Pre-cutover:** `az network public-ip show` should return `ATEUTM05-interface-X1` (SonicWall NIC). **Post-cutover:** same command should return `ATE-AE-fgt-nic1` (FortiGate NIC). DNS services additionally verified with `curl.exe`. **KD Bus Test** column is for business to confirm application-level functionality post-cutover.

---

## 8. Rollback Procedure

> **DANGER:** Trigger: Execute rollback if service is unreachable after migration and cannot be resolved within 10 minutes.

### 8.1 Primary IP + Default Route Rollback

> **DANGER:** If outbound connectivity fails after primary IP swap or default route change, execute immediately.

```bash
# --- ROLLBACK: SE Default Route ---
# Revert 0.0.0.0/0 to previous next-hop (replace PREVIOUS-NEXT-HOP with original value from Step 1.7)
az network route-table route update --resource-group KD-Prod-RG-asr --route-table-name KD-Mel-RouteTable --name Default-Internet --next-hop-ip-address PREVIOUS-NEXT-HOP

# --- ROLLBACK: SE Primary IP ---
# Swap back to original FortiGate SE public IP
az network nic ip-config update --resource-group KD-Prod-RG-asr --nic-name ATE-ASE-fgt-nic1 --name ipconfig1 --public-ip-address ATE-ASE-fgt-pip2
# Re-associate Sophos-PublicIP (23.101.226.122) to ATEUTM04-interface-X1

# --- ROLLBACK: East Default Route ---
az network route-table route update --resource-group KD-Prod-RG --route-table-name KD-Prod-RouteTable --name Default-Internet --next-hop-ip-address PREVIOUS-NEXT-HOP

# --- ROLLBACK: East Primary IP ---
az network nic ip-config update --resource-group KD-Prod-RG --nic-name ATE-AE-fgt-nic1 --name ipconfig1 --public-ip-address ATE-AE-FGT-PIP2
# Re-associate KD-UTM-PublicIP (52.237.241.132) to ATEUTM05-interface-X1
```

> **Warning:** Record the original 0.0.0.0/0 next-hop values in Step 1.7 before making any changes. You will need these for rollback.

> **Note:** FortiGate PIP names: `ATE-ASE-fgt-pip2` (SE, `4.200.139.87`) and `ATE-AE-FGT-PIP2` (East, `68.218.113.249`).

### 8.2 Per-Service-IP Rollback

```powershell
# Rollback single IP (moves back to SonicWall NIC)
.\azure-pip-migration-script.ps1 -Rollback -Name "KD-QLD-TIMS-PublicIP"

# Rollback entire group
.\azure-pip-migration-script.ps1 -Rollback -Group "KD-TIMS"
```

### 8.3 Manual Service IP Rollback (if script fails)

```bash
# 1. Remove public IP from FortiGate East NIC
az network nic ip-config delete --resource-group KD-Prod-RG --nic-name ATE-AE-fgt-nic1 --name ipconfig1

# 2. Re-create IP config on SonicWall WAN NIC with public IP
az network nic ip-config create --resource-group KD-Prod-RG --nic-name ATEUTM05-interface-X1 --name ipconfig1 --private-ip-address 10.200.254.X --public-ip-address PUBLIC-IP-NAME
```

> **Note:** Rollback is fast: Since these are Standard SKU Static IPs, the IP address is retained throughout. Rollback is simply reassigning back to the original NIC (~5 seconds per IP).

### 8.4 Post-Migration Hardening (Optional)

> **Note:** Not a migration blocker. The FortiGate NIC NSG currently allows all traffic. The SonicWall NIC has `ATEUTM03Syd-NSG` with management access restrictions. Consider applying similar NSG rules to the FortiGate NIC after migration is complete and validated.

**Current SonicWall NSG rules (ATEUTM03Syd-NSG on ATEUTM05-interface-X1):**

| Priority | Name | Port | Protocol | Source | Action |
|---|---|---|---|---|---|
| 100 | Allow-HTTPS-management-from-IP | 1341 | TCP | Specific admin IPs | Allow |
| 101 | Allow-SSH-management-from-IP | 22 | TCP | Specific admin IPs | Allow |
| 102 | Allow-HTTP-management-from-IP | 80 | TCP | 116.255.21.61 | Allow |
| 103 | Allow-AzureLoadBalancer | Any | TCP | 168.63.129.16 | Allow |
| 200 | Deny-HTTPS-management | 1341 | TCP | Any | Deny |
| 201 | Deny-SSH-management | 22 | TCP | Any | Deny |
| 300 | Default-Allow | Any | Any | Any | Allow |

**Recommended FortiGate NIC NSG hardening:**

- Restrict FortiGate management ports (HTTPS 443/8443, SSH 22) to admin IPs only
- Allow Azure Load Balancer health probes (168.63.129.16)
- Allow all other inbound traffic (FortiGate handles firewall filtering)

---

## 9. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Requestor | Olli Ojala | __________ | __________ |
| Network Engineer | __________ | __________ | __________ |
| Azure Admin | __________ | __________ | __________ |
| Change Manager | __________ | __________ | __________ |

### Migration Tracking

| Phase | Region | Action | IPs | Env | Scheduled | Completed | Notes |
|---|---|---|---|---|---|---|---|
| Phase 1A | South East | SE primary IP swap (`23.101.226.122`) | 1 | DR | | - [ ] | Replace `4.200.139.87` |
| Phase 1B | South East | SE default route (0.0.0.0/0) --> FortiGate | - | DR | | - [ ] | Next-hop `10.201.1.68` |
| Phase 1C | South East | SE VIP config + outbound + inbound test | 19 | DR | | - [ ] | Full SE proof of concept |
| Phase 2A | East | East primary IP swap (`52.237.241.132`) | 1 | Prod | | - [ ] | Replace `68.218.113.249` |
| Phase 2B | East | East default route (0.0.0.0/0) --> FortiGate | - | Prod | | - [ ] | Next-hop `10.200.1.68` |
| Phase 3 | East | KAB-TIMS-UAT | 4 | UAT | | - [ ] | East UAT pilot - validate PIP reassignment |
| Phase 4 | East | KD-TIMS | 4 | Prod | | - [ ] | |
| Phase 5 | East | KD-Other | 3 | Prod | | - [ ] | |
| Phase 6 | East | KAB-Austrics | 3 | Prod | | - [ ] | |
| Phase 7 | East | KAB-TIMS | 4 | Prod | | - [ ] | |
| Phase 8 | East | KAB-RDG | 1 | Prod | | - [ ] | |

---

### Revision History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-02-12 | Olli Ojala / Maia | Initial CR - 19 service IPs migration from SonicWall to FortiGate |
| 1.1 | 2026-02-13 | Olli Ojala / Maia | Added primary outbound IP migration (52.237.241.132 + 23.101.226.122), default route (0.0.0.0/0) changes, restructured phases to prioritise outbound IP migration. Added Azure PIP resource names (KD-UTM-PublicIP, Sophos-PublicIP) and corrected SE source NIC (ATEUTM04-interface-X1) |

---

*Generated by Maia - Azure Specialist Agent | CR-4404660 | 2026-02-12*
*Public IP Migration - SonicWall to FortiGate*
