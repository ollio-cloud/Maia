# VeloCloud Virtual Edge Azure Deployment Plan

## Document Information

| Field | Value |
|-------|-------|
| **Document Type** | Implementation Plan & Change Request |
| **Version** | 1.0 |
| **Date** | 2025-12-16 |
| **Template** | velocloud-edge-azure-template.json |
| **Target Environment** | Production - Australia East |

---

## 1. Executive Summary

This document outlines the deployment of a VMware VeloCloud SD-WAN Virtual Edge in Azure to provide optimized connectivity between the Azure hub network (AER-hub-australiaeast) and branch locations via the SD-WAN overlay.

### Deployment Overview

| Component | Value |
|-----------|-------|
| **Edge Name** | AERVAVC01 |
| **Location** | Australia East |
| **VNet** | AER-hub-australiaeast (10.139.0.0/18) |
| **VM Size** | Standard_D2d_v4 (2 vCPU, 8GB RAM) |
| **Edge Version** | Virtual Edge 4.5.2 |
| **VCO** | vco312-syd1.velocloud.net |

---

## 2. Architecture Diagram

```
                                    ┌─────────────────────────────────┐
                                    │         INTERNET                │
                                    └────────────┬────────────────────┘
                                                 │
                                    ┌────────────┴────────────────────┐
                                    │      VeloCloud Gateways         │
                                    │   (VCMP/VCSP - UDP 2426)        │
                                    └────────────┬────────────────────┘
                                                 │
┌────────────────────────────────────────────────┼────────────────────────────────────────────────┐
│  Azure - Australia East                        │                                                │
│                                                │                                                │
│  ┌─────────────────────────────────────────────┼─────────────────────────────────────────────┐  │
│  │  VNet: AER-hub-australiaeast (10.139.0.0/18)│                                             │  │
│  │                                             │                                             │  │
│  │  ┌──────────────────────────────────────────┴──────────────────────────────────────────┐ │  │
│  │  │                                                                                      │ │  │
│  │  │  ┌─────────────────────────────┐       ┌─────────────────────────────┐              │ │  │
│  │  │  │  Public Subnet              │       │  Private Subnet             │              │ │  │
│  │  │  │  velocloud-public-subnet    │       │  velocloud-private-subnet   │              │ │  │
│  │  │  │  10.139.2.0/24              │       │  10.139.3.0/24              │              │ │  │
│  │  │  │                             │       │                             │              │ │  │
│  │  │  │  ┌───────────────────────┐  │       │  ┌───────────────────────┐  │              │ │  │
│  │  │  │  │ NIC: AERVAVC01-nic-wan│  │       │  │ NIC: AERVAVC01-nic-lan│  │              │ │  │
│  │  │  │  │ GE1 (WAN)             │  │       │  │ GE2 (LAN)             │  │              │ │  │
│  │  │  │  │ Dynamic IP + PIP      │◄─┼───────┼─►│ Static: 10.139.3.4    │  │              │ │  │
│  │  │  │  └───────────┬───────────┘  │       │  └───────────┬───────────┘  │              │ │  │
│  │  │  │              │              │       │              │              │              │ │  │
│  │  │  └──────────────┼──────────────┘       └──────────────┼──────────────┘              │ │  │
│  │  │                 │                                     │                             │ │  │
│  │  │                 └──────────────┬──────────────────────┘                             │ │  │
│  │  │                                │                                                    │ │  │
│  │  │                    ┌───────────┴───────────┐                                        │ │  │
│  │  │                    │      AERVAVC01        │                                        │ │  │
│  │  │                    │  VeloCloud Virtual    │                                        │ │  │
│  │  │                    │       Edge            │                                        │ │  │
│  │  │                    │  Standard_D2d_v4      │                                        │ │  │
│  │  │                    │  Zone: 1              │                                        │ │  │
│  │  │                    └───────────────────────┘                                        │ │  │
│  │  │                                                                                      │ │  │
│  │  └──────────────────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                             │                                             │  │
│  │                                             │ UDR: Routes to Branch Networks              │  │
│  │                                             ▼                                             │  │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │  Other Subnets / Spoke VNets (via VNet Peering)                                      │ │  │
│  │  │  - Application workloads                                                              │ │  │
│  │  │  - Databases                                                                          │ │  │
│  │  │  - Management resources                                                               │ │  │
│  │  └──────────────────────────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                 │
                                                 │ SD-WAN Overlay (DMPO)
                                                 ▼
                                    ┌─────────────────────────────────┐
                                    │       Branch Locations          │
                                    │   (Physical VeloCloud Edges)    │
                                    └─────────────────────────────────┘
```

---

## 3. Template Analysis & Review

### 3.1 Security Assessment

| Category | Finding | Severity | Recommendation |
|----------|---------|----------|----------------|
| **SSH Key** | Hardcoded public key in template | ⚠️ Medium | Parameterize or use Azure Key Vault |
| **SSH Access** | Restricted to 52.62.158.44/32 | ✅ Good | Verify this is your management IP |
| **SNMP Access** | Open to entire VNet (10.139.0.0/18) | ⚠️ Low | Restrict to monitoring subnet only |
| **Activation Key** | Default value exposed | ⚠️ Medium | Remove default, require at deploy |
| **Admin Password** | SecureString (no default) | ✅ Good | Properly secured |
| **NSG Deny Rule** | Explicit deny-all at priority 4096 | ✅ Good | Defense in depth |
| **VCMP Port** | UDP 2426 open to * | ✅ Required | Necessary for SD-WAN operation |

### 3.2 Best Practices Assessment

| Category | Finding | Status |
|----------|---------|--------|
| **Accelerated Networking** | Enabled on both NICs | ✅ Optimal |
| **IP Forwarding** | Enabled for routing | ✅ Required |
| **Availability Zones** | Configurable (Zone 1 default) | ✅ Good |
| **Premium SSD** | Premium_LRS for OS disk | ✅ Recommended |
| **Boot Diagnostics** | Enabled | ✅ Good |
| **Delete Options** | NICs/Disks delete with VM | ✅ Clean |
| **Cloud-init** | management_interface: false | ✅ Correct for 2-NIC |
| **Tags** | Application, Environment, EdgeName, VCO | ✅ Good |

### 3.3 Recommended Template Modifications

#### 3.3.1 Remove Hardcoded SSH Key (Critical)

```json
// BEFORE (Line 166)
"sshPubKey": "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEArIHAy1DcnJpElcf3lqjjjQ5qRP0tpMGRsvFsJjLbg0TopkCZDuBAyOfNXcL9oPEna6tJG5ez+..."

// AFTER - Add parameter
"parameters": {
    "sshPublicKey": {
        "type": "securestring",
        "metadata": {
            "description": "SSH public key for vcadmin user"
        }
    }
}
// And reference: "[parameters('sshPublicKey')]"
```

#### 3.3.2 Remove Default Activation Key

```json
// BEFORE (Line 34)
"ActivationKey": {
    "defaultValue": "8RA7-F8UU-QWNZ-RS8D",  // REMOVE THIS
    "type": "string"
}

// AFTER
"ActivationKey": {
    "type": "securestring",  // Change to securestring
    "metadata": {
        "description": "Activation Key from VeloCloud Orchestrator"
    }
}
```

#### 3.3.3 Restrict SNMP Source (Optional)

```json
// BEFORE (Line 140)
"snmpSourceAddressPrefix": {
    "defaultValue": "10.139.0.0/18"  // Entire VNet
}

// AFTER - Restrict to monitoring subnet
"snmpSourceAddressPrefix": {
    "defaultValue": "10.139.10.0/24"  // Monitoring subnet only
}
```

---

## 4. Prerequisites Checklist

### 4.1 Azure Prerequisites

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | Azure Subscription with Contributor role | ☐ | Required for resource creation |
| 2 | Resource Group exists or create permissions | ☐ | Target RG for deployment |
| 3 | VNet exists: AER-hub-australiaeast | ☐ | Or template creates new |
| 4 | Subnets exist (if using existing VNet) | ☐ | velocloud-public-subnet, velocloud-private-subnet |
| 5 | IP address 10.139.3.4 available | ☐ | For LAN interface |
| 6 | Azure Marketplace terms accepted | ☐ | VMware SD-WAN image |
| 7 | Sufficient quota for Standard_D2d_v4 | ☐ | Check regional quota |

### 4.2 VeloCloud Orchestrator Prerequisites

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | VCO access: vco312-syd1.velocloud.net | ☐ | Admin credentials |
| 2 | Edge license available | ☐ | Virtual Edge license |
| 3 | Edge profile created | ☐ | Configure before deployment |
| 4 | Activation key generated | ☐ | From Configure > Edges > New Edge |
| 5 | Business policies configured | ☐ | Traffic steering rules |

### 4.3 Network Prerequisites

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | Outbound internet access from public subnet | ☐ | For VCO connectivity |
| 2 | UDP 2426 outbound allowed | ☐ | VCMP protocol |
| 3 | DNS resolution working | ☐ | Resolve vco312-syd1.velocloud.net |
| 4 | UDR planned for branch routes | ☐ | Point to 10.139.3.4 |

---

## 5. Implementation Plan

### Phase 1: Preparation (Day -3 to Day -1)

| Step | Task | Owner | Duration | Notes |
|------|------|-------|----------|-------|
| 1.1 | Obtain Change Approval | Change Manager | 1 day | CAB approval |
| 1.2 | Verify Azure prerequisites | Cloud Engineer | 2 hours | Quota, VNet, subnets |
| 1.3 | Accept Marketplace terms | Cloud Engineer | 15 min | `az vm image terms accept` |
| 1.4 | Create Edge in VCO | Network Engineer | 30 min | Get activation key |
| 1.5 | Configure Edge profile in VCO | Network Engineer | 1 hour | Interface settings, policies |
| 1.6 | Prepare parameter file | Cloud Engineer | 30 min | Secure values |
| 1.7 | Validate template | Cloud Engineer | 15 min | `az deployment group validate` |

### Phase 2: Deployment (Day 0)

| Step | Task | Owner | Duration | Notes |
|------|------|-------|----------|-------|
| 2.1 | Create maintenance window | Change Manager | 15 min | Notify stakeholders |
| 2.2 | Deploy ARM template | Cloud Engineer | 15 min | See deployment commands |
| 2.3 | Verify VM provisioning | Cloud Engineer | 5 min | Check Azure portal |
| 2.4 | Verify Edge activation | Network Engineer | 10 min | Check VCO status |
| 2.5 | Configure BGP (if required) | Network Engineer | 30 min | Route Server peering |
| 2.6 | Configure UDRs for branch routes | Cloud Engineer | 30 min | Point to Edge LAN IP |

### Phase 3: Validation (Day 0)

| Step | Task | Owner | Duration | Notes |
|------|------|-------|----------|-------|
| 3.1 | Verify Edge CONNECTED in VCO | Network Engineer | 5 min | Monitor > Edges |
| 3.2 | Verify tunnel establishment | Network Engineer | 10 min | VPN test in VCO |
| 3.3 | Test connectivity to branches | Network Engineer | 15 min | Ping/traceroute |
| 3.4 | Verify application access | App Owner | 30 min | Business apps |
| 3.5 | Review DMPO link quality | Network Engineer | 10 min | QoE metrics |

### Phase 4: Documentation (Day +1)

| Step | Task | Owner | Duration | Notes |
|------|------|-------|----------|-------|
| 4.1 | Update network diagrams | Network Engineer | 1 hour | Visio/Lucidchart |
| 4.2 | Document IP addresses | Cloud Engineer | 30 min | IPAM update |
| 4.3 | Update runbooks | Network Engineer | 1 hour | Troubleshooting procedures |
| 4.4 | Close change request | Change Manager | 15 min | Document outcomes |

---

## 6. Change Request Information

### 6.1 Change Request Summary

| Field | Value |
|-------|-------|
| **Change Title** | Deploy VeloCloud Virtual Edge in Azure Australia East |
| **Change Type** | Normal (Pre-approved pattern available) |
| **Risk Level** | Medium |
| **Impact** | Low - New deployment, no existing services affected |
| **Urgency** | Planned |
| **Category** | Network Infrastructure |
| **Service** | SD-WAN / Azure Networking |

### 6.2 Change Description

**Summary:**
Deploy a VMware VeloCloud SD-WAN Virtual Edge in Azure Australia East region to extend SD-WAN connectivity to Azure-hosted workloads. This enables optimized, policy-based routing between branch locations and Azure resources.

**Business Justification:**
- Extend SD-WAN overlay to Azure for consistent network policies
- Enable DMPO (Dynamic Multipath Optimization) for Azure traffic
- Provide failover capability for branch-to-Azure connectivity
- Centralized management via VeloCloud Orchestrator

**Technical Details:**
- Deploy Virtual Edge VM (Standard_D2d_v4) in existing hub VNet
- Configure 2-NIC deployment (WAN + LAN interfaces)
- Activate against VCO: vco312-syd1.velocloud.net
- Configure UDRs to route branch traffic through Edge

### 6.3 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| VM deployment failure | Low | Low | Template validated, rollback = delete RG |
| Edge activation failure | Low | Medium | Verify VCO connectivity, activation key |
| Network connectivity issues | Medium | Medium | Test in isolation first, gradual route migration |
| Performance impact | Low | Low | Start with non-critical traffic |
| Cost overrun | Low | Low | Known VM size, predictable costs |

### 6.4 Rollback Plan

**Trigger Conditions:**
- Edge fails to activate after 30 minutes
- Critical application connectivity broken
- Unacceptable latency/packet loss (>5% loss, >100ms latency)

**Rollback Steps:**
1. Remove UDRs pointing to Edge LAN IP (immediate traffic restoration)
2. Deactivate Edge in VCO (Configure > Edges > Actions > Deactivate)
3. Delete Azure resources:
   ```bash
   az group delete --name rg-velocloud-aue --yes --no-wait
   ```
4. Document rollback reason
5. Schedule post-incident review

**Rollback Duration:** 15 minutes

### 6.5 Test Plan

| Test Case | Expected Result | Pass/Fail |
|-----------|-----------------|-----------|
| VM deploys successfully | VM running in Azure portal | ☐ |
| Edge shows CONNECTED in VCO | Status = CONNECTED | ☐ |
| WAN link UP | Link status healthy in VCO | ☐ |
| Tunnels established | VPN test shows all tunnels UP | ☐ |
| Ping from branch to Azure VM | <50ms latency, 0% loss | ☐ |
| Ping from Azure VM to branch | <50ms latency, 0% loss | ☐ |
| Application access | Business app accessible | ☐ |
| DMPO active | Link steering functional | ☐ |

### 6.6 Communication Plan

| When | Who | What | Method |
|------|-----|------|--------|
| Day -3 | Stakeholders | Change notification | Email |
| Day -1 | Network Team | Final preparation | Teams |
| Day 0 - Start | Ops Team | Maintenance window start | Teams/Slack |
| Day 0 - Complete | Stakeholders | Deployment complete | Email |
| Day 0 - Issue | Stakeholders | Rollback initiated | Email + Phone |

---

## 7. Deployment Commands

### 7.1 Accept Marketplace Terms (One-time)

```bash
# Accept VMware SD-WAN marketplace terms
az vm image terms accept \
  --publisher vmware-inc \
  --offer sol-42222-bbj \
  --plan vmware_sdwan_452
```

### 7.2 Validate Template

```bash
# Validate before deployment
az deployment group validate \
  --resource-group rg-velocloud-aue \
  --template-file velocloud-edge-azure-template.json \
  --parameters \
    EdgeName="AERVAVC01" \
    ActivationKey="<ACTIVATION-KEY-FROM-VCO>" \
    adminPassword="<SECURE-PASSWORD>" \
    VCO="vco312-syd1.velocloud.net" \
    virtualNetworkNewOrExisting="existing" \
    virtualNetworkResourceGroup="rg-network-aue" \
    zone="1"
```

### 7.3 Deploy Template

```bash
# Deploy the Virtual Edge
az deployment group create \
  --name "velocloud-edge-deployment-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-velocloud-aue \
  --template-file velocloud-edge-azure-template.json \
  --parameters \
    EdgeName="AERVAVC01" \
    ActivationKey="<ACTIVATION-KEY-FROM-VCO>" \
    adminPassword="<SECURE-PASSWORD>" \
    VCO="vco312-syd1.velocloud.net" \
    virtualNetworkNewOrExisting="existing" \
    virtualNetworkResourceGroup="rg-network-aue" \
    vNetName="AER-hub-australiaeast" \
    PublicSubnetName="velocloud-public-subnet" \
    PrivateSubnetName="velocloud-private-subnet" \
    EdgeGE2LANIP="10.139.3.4" \
    zone="1" \
    sshSourceAddressPrefix="52.62.158.44/32"
```

### 7.4 Using Parameter File (Recommended)

Create `velocloud-edge-azure-parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "EdgeName": { "value": "AERVAVC01" },
    "EdgeVersion": { "value": "Virtual Edge 4.5.2" },
    "VCO": { "value": "vco312-syd1.velocloud.net" },
    "ActivationKey": { "value": "<GET-FROM-VCO>" },
    "adminPassword": { "value": "<SECURE-PASSWORD>" },
    "virtualMachineSize": { "value": "Standard_D2d_v4" },
    "zone": { "value": "1" },
    "virtualNetworkNewOrExisting": { "value": "existing" },
    "virtualNetworkResourceGroup": { "value": "rg-network-aue" },
    "vNetName": { "value": "AER-hub-australiaeast" },
    "vNetPrefix": { "value": "10.139.0.0/18" },
    "PublicSubnetName": { "value": "velocloud-public-subnet" },
    "PublicSubnet": { "value": "10.139.2.0/24" },
    "PrivateSubnetName": { "value": "velocloud-private-subnet" },
    "PrivateSubnet": { "value": "10.139.3.0/24" },
    "EdgeGE2LANIP": { "value": "10.139.3.4" },
    "sshSourceAddressPrefix": { "value": "52.62.158.44/32" },
    "snmpSourceAddressPrefix": { "value": "10.139.10.0/24" }
  }
}
```

Deploy with parameter file:

```bash
az deployment group create \
  --name "velocloud-edge-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-velocloud-aue \
  --template-file velocloud-edge-azure-template.json \
  --parameters @velocloud-edge-azure-parameters.json
```

---

## 8. Post-Deployment Configuration

### 8.1 VeloCloud Orchestrator Configuration

After Edge activates, configure in VCO:

```
1. Verify Edge Status:
   Monitor > Edges > AERVAVC01
   - Status: CONNECTED ✓
   - Software Version: 4.5.2

2. Configure Interface Settings (if not via profile):
   Configure > Edges > AERVAVC01 > Device
   - GE1: WAN, Overlay Enabled
   - GE2: LAN/Routed, IP: 10.139.3.4/24

3. Configure Business Policies:
   Configure > Edges > AERVAVC01 > Business Policy
   - Add rules for Azure-bound traffic
   - Configure application steering

4. Allow Azure Fabric IP (Required):
   Configure > Edges > AERVAVC01 > Firewall > Edge Access
   - Allow IP: 168.63.129.16
```

### 8.2 Azure UDR Configuration

Create UDRs to route branch traffic through the Edge:

```bash
# Create route table for workload subnets
az network route-table create \
  --name rt-workloads-via-velocloud \
  --resource-group rg-network-aue \
  --location australiaeast

# Add routes for branch networks
az network route-table route create \
  --name route-to-branch-a \
  --route-table-name rt-workloads-via-velocloud \
  --resource-group rg-network-aue \
  --address-prefix 192.168.10.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.139.3.4

az network route-table route create \
  --name route-to-branch-b \
  --route-table-name rt-workloads-via-velocloud \
  --resource-group rg-network-aue \
  --address-prefix 192.168.20.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.139.3.4

# Associate with workload subnet
az network vnet subnet update \
  --name workload-subnet \
  --vnet-name AER-hub-australiaeast \
  --resource-group rg-network-aue \
  --route-table rt-workloads-via-velocloud
```

---

## 9. Validation Checklist

### 9.1 Azure Validation

| Check | Command | Expected |
|-------|---------|----------|
| VM Running | `az vm show -g rg-velocloud-aue -n AERVAVC01 --query powerState` | "VM running" |
| Public IP | `az network public-ip show -g rg-velocloud-aue -n AERVAVC01-pip --query ipAddress` | Valid IP |
| NIC Status | `az network nic show -g rg-velocloud-aue -n AERVAVC01-nic-wan --query provisioningState` | "Succeeded" |

### 9.2 VeloCloud Validation

| Check | Location | Expected |
|-------|----------|----------|
| Edge Status | Monitor > Edges | CONNECTED |
| WAN Link | Monitor > Edges > Links | UP, healthy metrics |
| Tunnels | Test & Troubleshoot > VPN Test | All tunnels UP |
| Routes | Test & Troubleshoot > Route Table Dump | Branch routes present |

### 9.3 Connectivity Validation

```bash
# From Azure VM in workload subnet
ping 192.168.10.1  # Branch A gateway
traceroute 192.168.10.1  # Verify path through 10.139.3.4

# From Branch Edge (via VCO Remote Diagnostics)
ping 10.139.x.x  # Azure workload IP
```

---

## 10. Cost Estimate

| Resource | SKU | Monthly Cost (AUD) |
|----------|-----|-------------------|
| Virtual Machine | Standard_D2d_v4 | ~$150 |
| Premium SSD (OS) | 64GB P6 | ~$15 |
| Public IP (Standard) | Static | ~$5 |
| Bandwidth (Egress) | Estimated 500GB | ~$45 |
| **Total Estimated** | | **~$215/month** |

*Note: VeloCloud license costs not included (separate VMware agreement)*

---

## 11. Support Contacts

| Role | Contact | Escalation |
|------|---------|------------|
| Cloud Engineer | TBD | Cloud Team Lead |
| Network Engineer | TBD | Network Team Lead |
| VeloCloud Support | support.velocloud.net | TAM |
| Azure Support | Azure Portal | Premier Support |

---

## 12. Approvals

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Change Manager | | | |
| Network Lead | | | |
| Cloud Lead | | | |
| Business Owner | | | |

---

## Appendix A: Troubleshooting Guide

### Edge Not Activating

1. **Check DNS resolution:**
   ```bash
   nslookup vco312-syd1.velocloud.net
   ```

2. **Check outbound connectivity:**
   - Verify NSG allows UDP 2426 outbound
   - Verify no Azure Firewall blocking

3. **Check activation key:**
   - Verify key matches VCO
   - Key not expired
   - Key not already used

4. **Check cloud-init:**
   ```bash
   # SSH to Edge (if accessible)
   cat /var/log/cloud-init-output.log
   ```

### Tunnel Not Establishing

1. **Check Edge events in VCO:**
   - Monitor > Events > Filter by Edge

2. **Run VPN test:**
   - Test & Troubleshoot > Remote Diagnostics > VPN Test

3. **Check Gateway reachability:**
   - Verify Edge can reach assigned Gateways

### Poor Performance

1. **Check DMPO metrics:**
   - Monitor > QoE > Select Edge
   - Review latency, jitter, packet loss

2. **Check link steering:**
   - Verify correct path selection
   - Review Business Policies

---

*Document generated by VeloCloud SD-WAN Agent v2.2*
