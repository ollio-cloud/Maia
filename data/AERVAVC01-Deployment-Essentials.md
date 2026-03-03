# VeloCloud Virtual Edge Deployment - Essentials Checklist

## AERVAVC01 - Azure Australia East

---

## Deployment Summary

| Parameter | Value |
|-----------|-------|
| Edge Name | AERVAVC01 |
| Azure Region | Australia East |
| Target VNet | AER-hub-australiaeast (10.139.0.0/18) |
| VM Size | Standard_D2d_v4 |
| LAN IP | 10.139.3.4 |
| VCO | vco312-syd1.velocloud.net |
| Estimated Monthly Cost | ~$215 AUD |

---

## Information Required from Customer

### VeloCloud Orchestrator (VCO)

| Item | Required | Customer Response |
|------|----------|-------------------|
| VCO admin credentials available? | Yes | |
| Virtual Edge license available? | Yes | |
| Edge profile name to use | Yes | |
| Business policies to apply | Yes | |
| **Activation Key** | Yes - generated in VCO | |

### Azure Environment

| Item | Required | Customer Response |
|------|----------|-------------------|
| Target subscription name/ID | Yes | |
| Existing VNet resource group name | Yes | rg-network-aue (confirm) |
| VNet name | Yes | AER-hub-australiaeast (confirm) |
| Public subnet exists? | Yes | velocloud-public-subnet (10.139.2.0/24) |
| Private subnet exists? | Yes | velocloud-private-subnet (10.139.3.0/24) |
| IP 10.139.3.4 available? | Yes | |
| Azure Marketplace terms accepted? | Yes | |

### Network & Security

| Item | Required | Customer Response |
|------|----------|-------------------|
| Management IP(s) for SSH access | Yes | 52.62.158.44/32 (confirm) |
| SNMP monitoring subnet | Optional | 10.139.10.0/24 (confirm) |
| Branch networks to route via Edge | Yes | 192.168.10.0/24, 192.168.20.0/24 (confirm) |
| Workload subnet(s) needing branch access | Yes | |

### Scheduling

| Item | Required | Customer Response |
|------|----------|-------------------|
| Preferred deployment date | Yes | |
| Maintenance window (if required) | Yes | |
| Stakeholder notification list | Yes | |

---

## Pre-Deployment Actions

### Customer Actions
- [ ] Confirm VCO access and license availability
- [ ] Confirm Azure subscription and permissions
- [ ] Confirm VNet and subnet details
- [ ] Confirm IP address availability (10.139.3.4)
- [ ] Confirm management IP addresses for SSH access
- [ ] Provide list of branch networks to route
- [ ] Provide list of workload subnets needing routes
- [ ] Confirm preferred deployment date

### Our Actions (after customer confirmation)
- [ ] Create Edge record in VCO
- [ ] Generate activation key
- [ ] Configure Edge profile in VCO
- [ ] Accept Azure Marketplace terms (if not done)
- [ ] Prepare parameter file with confirmed values
- [ ] Validate ARM template
- [ ] Schedule deployment

---

## Deployment Day Checklist

| Step | Task | Duration | Owner |
|------|------|----------|-------|
| 1 | Open maintenance window | 15 min | Change Manager |
| 2 | Deploy ARM template | 15 min | Cloud Engineer |
| 3 | Verify VM provisioning | 5 min | Cloud Engineer |
| 4 | Verify Edge activation in VCO | 10 min | Network Engineer |
| 5 | Configure UDRs | 30 min | Cloud Engineer |
| 6 | Test connectivity | 30 min | Network Engineer |
| 7 | Close maintenance window | 15 min | Change Manager |

**Total estimated duration: ~2 hours**

---

## Key Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Edge doesn't activate | Verify VCO connectivity and activation key beforehand |
| Routing disruption | Gradual route migration, test non-critical traffic first |
| VM deployment failure | Template pre-validated, rollback = delete resource group |

**Rollback time: 15 minutes** (remove UDRs + delete resources)

---

## Post-Deployment

- [ ] Update network diagrams
- [ ] Update IPAM
- [ ] Update runbooks
- [ ] Close change request

---

## Contact Points

| Role | Contact |
|------|---------|
| Cloud Engineer | TBD |
| Network Engineer | TBD |
| Change Manager | TBD |
| Customer Contact | TBD |

---

## Documents Provided

- [ ] Change Request (CR-AERVAVC01-VeloCloud-Edge-Deployment.docx)
- [ ] Deployment Instructions (AERVAVC01-Deployment-Instructions.docx)
- [ ] ARM Template (velocloud-edge-azure-template.json)
- [ ] Parameter File Template (velocloud-edge-azure-parameters.json)

---

*Please review and provide the missing information highlighted above.*
