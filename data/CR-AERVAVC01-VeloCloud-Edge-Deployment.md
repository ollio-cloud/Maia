# Change Request: CR-2025-XXXX

## Deploy VeloCloud Virtual Edge in Azure Australia East

---

## 1. Change Request Details

| Field | Value |
|-------|-------|
| **CR Number** | CR-2025-XXXX (Assign on submission) |
| **Title** | Deploy VeloCloud SD-WAN Virtual Edge AERVAVC01 in Azure Australia East |
| **Requestor** | TBD |
| **Date Submitted** | 2025-XX-XX |
| **Target Implementation Date** | TBD |
| **Change Type** | Normal |
| **Priority** | Medium |
| **Risk Level** | Medium |
| **Impact Level** | Low |
| **Category** | Network Infrastructure |
| **Service** | SD-WAN / Azure Networking |
| **CI Affected** | AER-hub-australiaeast VNet, SD-WAN Overlay |

---

## 2. Change Description

### 2.1 Summary

Deploy a VMware VeloCloud SD-WAN Virtual Edge (AERVAVC01) in Azure Australia East region to extend SD-WAN connectivity to Azure-hosted workloads. This deployment enables optimized, policy-based routing between branch locations and Azure resources via the SD-WAN overlay.

### 2.2 Business Justification

| Benefit | Description |
|---------|-------------|
| **SD-WAN Extension** | Extend SD-WAN overlay to Azure for consistent network policies across all locations |
| **DMPO Optimization** | Enable Dynamic Multipath Optimization for Azure traffic, improving application performance |
| **Failover Capability** | Provide resilient branch-to-Azure connectivity with automatic failover |
| **Centralized Management** | Single pane of glass management via VeloCloud Orchestrator |
| **Cost Optimization** | Optimize bandwidth usage through intelligent path selection |

### 2.3 Technical Scope

| Component | Details |
|-----------|---------|
| **Edge Name** | AERVAVC01 |
| **Location** | Azure Australia East |
| **Target VNet** | AER-hub-australiaeast (10.139.0.0/18) |
| **VM Size** | Standard_D2d_v4 (2 vCPU, 8GB RAM) |
| **Edge Version** | Virtual Edge 4.5.2 |
| **Orchestrator** | vco312-syd1.velocloud.net |
| **Availability Zone** | Zone 1 |
| **Public Subnet** | velocloud-public-subnet (10.139.2.0/24) |
| **Private Subnet** | velocloud-private-subnet (10.139.3.0/24) |
| **LAN IP Address** | 10.139.3.4 |

### 2.4 Resources Created

| Resource | Name | Resource Group |
|----------|------|----------------|
| Virtual Machine | AERVAVC01 | rg-velocloud-aue |
| OS Disk | AERVAVC01-osdisk | rg-velocloud-aue |
| WAN NIC | AERVAVC01-nic-wan | rg-velocloud-aue |
| LAN NIC | AERVAVC01-nic-lan | rg-velocloud-aue |
| Public IP | AERVAVC01-pip | rg-velocloud-aue |
| NSG | AERVAVC01-nsg | rg-velocloud-aue |
| Subnets (if new) | velocloud-public-subnet, velocloud-private-subnet | rg-network-aue |

---

## 3. Risk Assessment

### 3.1 Risk Matrix

| Risk ID | Risk Description | Likelihood | Impact | Risk Score | Mitigation |
|---------|------------------|------------|--------|------------|------------|
| R1 | VM deployment failure | Low | Low | Low | Template pre-validated; rollback = delete resource group |
| R2 | Edge activation failure | Low | Medium | Low | Verify VCO connectivity and activation key before deployment |
| R3 | Network connectivity disruption | Medium | Medium | Medium | Test in isolation first; gradual route migration |
| R4 | Performance degradation | Low | Low | Low | Start with non-critical traffic; monitor DMPO metrics |
| R5 | Cost overrun | Low | Low | Low | Known VM size with predictable monthly costs (~$215 AUD) |
| R6 | Security vulnerability | Low | High | Medium | Template security reviewed; NSG deny-all default |

### 3.2 Overall Risk Assessment

| Criteria | Assessment |
|----------|------------|
| **Overall Risk Level** | Medium |
| **Rationale** | New deployment with no impact to existing services. Template validated and security reviewed. Rollback plan tested and documented. |

---

## 4. Implementation Plan

### 4.1 Phase 1: Preparation (Day -3 to Day -1)

| Step | Task | Owner | Duration | Status |
|------|------|-------|----------|--------|
| 1.1 | Obtain Change Approval (CAB) | Change Manager | 1 day | ☐ Pending |
| 1.2 | Verify Azure prerequisites (quota, VNet, subnets) | Cloud Engineer | 2 hours | ☐ Pending |
| 1.3 | Accept Azure Marketplace terms for VMware SD-WAN | Cloud Engineer | 15 min | ☐ Pending |
| 1.4 | Create Edge record in VCO, obtain activation key | Network Engineer | 30 min | ☐ Pending |
| 1.5 | Configure Edge profile in VCO (interfaces, policies) | Network Engineer | 1 hour | ☐ Pending |
| 1.6 | Prepare secure parameter file | Cloud Engineer | 30 min | ☐ Pending |
| 1.7 | Validate ARM template deployment | Cloud Engineer | 15 min | ☐ Pending |

### 4.2 Phase 2: Deployment (Day 0)

| Step | Task | Owner | Duration | Status |
|------|------|-------|----------|--------|
| 2.1 | Open maintenance window, notify stakeholders | Change Manager | 15 min | ☐ Pending |
| 2.2 | Deploy ARM template to Azure | Cloud Engineer | 15 min | ☐ Pending |
| 2.3 | Verify VM provisioning in Azure Portal | Cloud Engineer | 5 min | ☐ Pending |
| 2.4 | Verify Edge activation in VCO | Network Engineer | 10 min | ☐ Pending |
| 2.5 | Configure BGP peering (if required) | Network Engineer | 30 min | ☐ Pending |
| 2.6 | Configure UDRs for branch route steering | Cloud Engineer | 30 min | ☐ Pending |

### 4.3 Phase 3: Validation (Day 0)

| Step | Task | Owner | Duration | Status |
|------|------|-------|----------|--------|
| 3.1 | Verify Edge status = CONNECTED in VCO | Network Engineer | 5 min | ☐ Pending |
| 3.2 | Verify tunnel establishment (VPN test) | Network Engineer | 10 min | ☐ Pending |
| 3.3 | Test connectivity to branch networks | Network Engineer | 15 min | ☐ Pending |
| 3.4 | Verify business application access | App Owner | 30 min | ☐ Pending |
| 3.5 | Review DMPO link quality metrics | Network Engineer | 10 min | ☐ Pending |

### 4.4 Phase 4: Documentation (Day +1)

| Step | Task | Owner | Duration | Status |
|------|------|-------|----------|--------|
| 4.1 | Update network diagrams | Network Engineer | 1 hour | ☐ Pending |
| 4.2 | Update IPAM with new IP allocations | Cloud Engineer | 30 min | ☐ Pending |
| 4.3 | Update operational runbooks | Network Engineer | 1 hour | ☐ Pending |
| 4.4 | Close change request | Change Manager | 15 min | ☐ Pending |

---

## 5. Test Plan

### 5.1 Validation Tests

| Test ID | Test Case | Expected Result | Actual Result | Pass/Fail |
|---------|-----------|-----------------|---------------|-----------|
| T1 | VM deploys successfully | VM status = Running in Azure Portal | | ☐ |
| T2 | Edge activates in VCO | Edge status = CONNECTED | | ☐ |
| T3 | WAN link UP | Link status healthy, metrics normal | | ☐ |
| T4 | SD-WAN tunnels established | VPN test shows all peer tunnels UP | | ☐ |
| T5 | Ping from branch to Azure VM | <50ms latency, 0% packet loss | | ☐ |
| T6 | Ping from Azure VM to branch | <50ms latency, 0% packet loss | | ☐ |
| T7 | Business application access | Application accessible from branch | | ☐ |
| T8 | DMPO path optimization active | Link steering functional | | ☐ |

### 5.2 Test Commands

```bash
# Azure validation
az vm show -g rg-velocloud-aue -n AERVAVC01 --query powerState -o tsv
az network public-ip show -g rg-velocloud-aue -n AERVAVC01-pip --query ipAddress -o tsv

# Connectivity tests (from Azure VM)
ping 192.168.10.1    # Branch A gateway
traceroute 192.168.10.1  # Verify path via 10.139.3.4
```

---

## 6. Rollback Plan

### 6.1 Rollback Triggers

| Trigger | Threshold |
|---------|-----------|
| Edge fails to activate | After 30 minutes of troubleshooting |
| Critical application connectivity broken | Any production impact |
| Unacceptable network performance | >5% packet loss OR >100ms latency |
| Security incident detected | Any severity |

### 6.2 Rollback Procedure

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| R1 | Remove UDRs pointing to Edge LAN IP (10.139.3.4) | Cloud Engineer | 5 min |
| R2 | Deactivate Edge in VCO (Configure > Edges > Deactivate) | Network Engineer | 2 min |
| R3 | Delete Azure resource group | Cloud Engineer | 5 min |
| R4 | Verify original routing restored | Network Engineer | 3 min |
| R5 | Document rollback reason | Change Manager | - |
| R6 | Schedule post-incident review | Change Manager | - |

### 6.3 Rollback Commands

```bash
# Remove UDRs (immediate traffic restoration)
az network route-table route delete \
  --name route-to-branch-a \
  --route-table-name rt-workloads-via-velocloud \
  --resource-group rg-network-aue

# Delete all deployed resources
az group delete --name rg-velocloud-aue --yes --no-wait
```

### 6.4 Rollback Duration

| Phase | Duration |
|-------|----------|
| Traffic restoration (UDR removal) | 5 minutes |
| Complete rollback | 15 minutes |

---

## 7. Communication Plan

| Timing | Audience | Message | Channel |
|--------|----------|---------|---------|
| Day -3 | All Stakeholders | Change notification and schedule | Email |
| Day -1 | Network & Cloud Teams | Final preparation briefing | Teams Meeting |
| Day 0 (Start) | Operations Team | Maintenance window started | Teams/Slack |
| Day 0 (Complete) | All Stakeholders | Deployment successful | Email |
| Day 0 (Issue) | All Stakeholders | Rollback initiated | Email + Phone |
| Day +1 | All Stakeholders | Change closure notification | Email |

---

## 8. Resource Requirements

### 8.1 Personnel

| Role | Responsibility | Availability Required |
|------|----------------|----------------------|
| Change Manager | Approval, coordination, communication | Day -3 to Day +1 |
| Cloud Engineer | Azure deployment, UDR configuration | Day 0 (4 hours) |
| Network Engineer | VCO configuration, validation | Day 0 (4 hours) |
| App Owner | Application validation | Day 0 (1 hour) |

### 8.2 Azure Resources

| Resource | Specification | Monthly Cost (AUD) |
|----------|---------------|-------------------|
| Virtual Machine | Standard_D2d_v4 | ~$150 |
| Premium SSD (OS Disk) | 64GB P6 | ~$15 |
| Public IP (Standard) | Static | ~$5 |
| Bandwidth (Egress) | Est. 500GB | ~$45 |
| **Total** | | **~$215/month** |

*Note: VeloCloud license costs are covered under existing VMware agreement*

---

## 9. Prerequisites Checklist

### 9.1 Azure Prerequisites

| # | Requirement | Verified | Notes |
|---|-------------|----------|-------|
| 1 | Azure Subscription with Contributor role | ☐ | |
| 2 | Resource Group rg-velocloud-aue exists (or create permissions) | ☐ | |
| 3 | VNet AER-hub-australiaeast exists | ☐ | |
| 4 | Subnets available (or will be created) | ☐ | |
| 5 | IP address 10.139.3.4 available in private subnet | ☐ | |
| 6 | Azure Marketplace terms accepted for VMware SD-WAN | ☐ | |
| 7 | Sufficient quota for Standard_D2d_v4 in Australia East | ☐ | |

### 9.2 VeloCloud Orchestrator Prerequisites

| # | Requirement | Verified | Notes |
|---|-------------|----------|-------|
| 1 | VCO access: vco312-syd1.velocloud.net | ☐ | |
| 2 | Virtual Edge license available | ☐ | |
| 3 | Edge profile configured | ☐ | |
| 4 | Activation key generated | ☐ | |
| 5 | Business policies defined | ☐ | |

### 9.3 Network Prerequisites

| # | Requirement | Verified | Notes |
|---|-------------|----------|-------|
| 1 | Outbound internet access from public subnet | ☐ | |
| 2 | UDP 2426 outbound allowed (NSG/Firewall) | ☐ | |
| 3 | DNS resolution for vco312-syd1.velocloud.net | ☐ | |
| 4 | UDR plan for branch route steering | ☐ | |

---

## 10. Approvals

| Role | Name | Signature | Date | Decision |
|------|------|-----------|------|----------|
| Requestor | | | | |
| Change Manager | | | | ☐ Approved ☐ Rejected |
| Network Lead | | | | ☐ Approved ☐ Rejected |
| Cloud Lead | | | | ☐ Approved ☐ Rejected |
| Business Owner | | | | ☐ Approved ☐ Rejected |
| CAB Chair | | | | ☐ Approved ☐ Rejected |

---

## 11. Post-Implementation Review

*To be completed after change implementation*

| Criteria | Assessment |
|----------|------------|
| **Change Successful** | ☐ Yes ☐ No ☐ Partial |
| **Rollback Required** | ☐ Yes ☐ No |
| **Actual Duration** | |
| **Issues Encountered** | |
| **Lessons Learned** | |
| **Follow-up Actions** | |

---

## 12. Attachments

| Document | Location |
|----------|----------|
| Deployment Plan | [velocloud-edge-azure-deployment-plan.md](velocloud-edge-azure-deployment-plan.md) |
| ARM Template | velocloud-edge-azure-template.json |
| Parameter File | velocloud-edge-azure-parameters.json |
| Architecture Diagram | See Deployment Plan Section 2 |

---

## 13. Change History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-XX-XX | TBD | Initial CR created |

---

*Generated by VeloCloud SD-WAN Agent v2.2*
