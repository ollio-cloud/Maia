# VeloCloud Virtual Edge Deployment Instructions

## AERVAVC01 - Azure Australia East

---

## Quick Reference

| Parameter | Value |
|-----------|-------|
| **Edge Name** | AERVAVC01 |
| **Region** | Australia East |
| **VNet** | AER-hub-australiaeast |
| **VM Size** | Standard_D2d_v4 |
| **LAN IP** | 10.139.3.4 |
| **VCO** | vco312-syd1.velocloud.net |

---

## Deployment Steps Summary

| Step | Task |
|------|------|
| **1** | Create Edge in VCO & get activation key |
| **2** | Connect to Azure subscription |
| **3** | Accept Azure Marketplace terms |
| **4** | Create resource group |
| **5** | Create parameter file (with activation key & password) |
| **6** | Validate ARM template |
| **7** | Deploy Virtual Edge (~10-15 min) |
| **8** | Verify Azure resources |
| **9** | Verify Edge activation in VCO |
| **10** | Configure UDRs for branch routing |
| **11** | Validate end-to-end connectivity |

---

## Prerequisites

Before starting, ensure the following are completed:

### Azure
- [ ] Contributor access to target subscription
- [ ] Resource group `rg-velocloud-aue` exists (or permissions to create)
- [ ] VNet `AER-hub-australiaeast` exists
- [ ] IP address `10.139.3.4` is available
- [ ] Quota available for Standard_D2d_v4 in Australia East

### VeloCloud Orchestrator
- [ ] Admin access to vco312-syd1.velocloud.net
- [ ] Virtual Edge license available
- [ ] Activation key generated (Step 1 below)

---

## Step 1: Create Edge in VeloCloud Orchestrator

1. **Login to VCO**: https://vco312-syd1.velocloud.net

2. **Create Edge Profile** (if not exists):
   ```
   Navigate: Configure > Profiles > New Profile

   Settings:
   - Name: Azure-Virtual-Edge-Profile
   - Model: Virtual Edge
   - Segment: Global (or your segment)

   Device Settings:
   - GE1: WAN, Overlay Enabled, DHCP
   - GE2: Routed/LAN, Static IP
   - GE3-GE8: Disabled
   ```

3. **Create Edge Record**:
   ```
   Navigate: Configure > Edges > New Edge

   Settings:
   - Name: AERVAVC01
   - Model: Virtual Edge
   - Profile: Azure-Virtual-Edge-Profile
   - Contact Name/Email: [Your details]

   Click "Create"
   ```

4. **Copy Activation Key**:
   ```
   After creation, copy the Activation Key displayed
   Example format: XXXX-XXXX-XXXX-XXXX

   ⚠️ SAVE THIS KEY - Required for Azure deployment
   ```

5. **Configure Edge Firewall Access** (for Azure management):
   ```
   Navigate: Configure > Edges > AERVAVC01 > Firewall > Edge Access

   Add Allow Rule:
   - Source IP: 168.63.129.16/32
   - Description: Azure Fabric IP (required for Azure health probes)
   ```

---

## Step 2: Connect to Azure Subscription

### Login to Azure

```powershell
# PowerShell / Bash
az login
```

This opens a browser for authentication. After login, you'll see your available subscriptions.

### List Available Subscriptions

```powershell
# PowerShell / Bash
az account list --output table
```

### Set Target Subscription

```powershell
# PowerShell / Bash
az account set --subscription "YOUR-SUBSCRIPTION-NAME-OR-ID"
```

### Verify Active Subscription

```powershell
# PowerShell / Bash
az account show --output table
```

**Expected Output:**
```
EnvironmentName    IsDefault    Name                    State    TenantId
-----------------  -----------  ----------------------  -------  ------------------------------------
AzureCloud         True         Your-Subscription-Name  Enabled  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## Step 3: Accept Azure Marketplace Terms

Run this command once per subscription:

```powershell
# PowerShell
az vm image terms accept `
  --publisher vmware-inc `
  --offer sol-42222-bbj `
  --plan vmware_sdwan_452
```

```bash
# Bash
az vm image terms accept \
  --publisher vmware-inc \
  --offer sol-42222-bbj \
  --plan vmware_sdwan_452
```

**Expected Output:**
```json
{
  "accepted": true,
  "marketplace": "vmware-inc:sol-42222-bbj:vmware_sdwan_452"
}
```

---

## Step 4: Create Resource Group

```powershell
# PowerShell
az group create `
  --name rg-velocloud-aue `
  --location australiaeast `
  --tags Application=SD-WAN Environment=Production
```

```bash
# Bash
az group create \
  --name rg-velocloud-aue \
  --location australiaeast \
  --tags Application=SD-WAN Environment=Production
```

---

## Step 5: Create Parameter File

Create file `velocloud-edge-azure-parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "EdgeName": {
      "value": "AERVAVC01"
    },
    "EdgeVersion": {
      "value": "Virtual Edge 4.5.2"
    },
    "VCO": {
      "value": "vco312-syd1.velocloud.net"
    },
    "ActivationKey": {
      "value": "REPLACE-WITH-ACTIVATION-KEY"
    },
    "adminPassword": {
      "value": "REPLACE-WITH-SECURE-PASSWORD"
    },
    "virtualMachineSize": {
      "value": "Standard_D2d_v4"
    },
    "zone": {
      "value": "1"
    },
    "virtualNetworkNewOrExisting": {
      "value": "existing"
    },
    "virtualNetworkResourceGroup": {
      "value": "rg-network-aue"
    },
    "vNetName": {
      "value": "AER-hub-australiaeast"
    },
    "vNetPrefix": {
      "value": "10.139.0.0/18"
    },
    "PublicSubnetName": {
      "value": "velocloud-public-subnet"
    },
    "PublicSubnet": {
      "value": "10.139.2.0/24"
    },
    "PrivateSubnetName": {
      "value": "velocloud-private-subnet"
    },
    "PrivateSubnet": {
      "value": "10.139.3.0/24"
    },
    "EdgeGE2LANIP": {
      "value": "10.139.3.4"
    },
    "sshSourceAddressPrefix": {
      "value": "52.62.158.44/32"
    },
    "snmpSourceAddressPrefix": {
      "value": "10.139.10.0/24"
    }
  }
}
```

⚠️ **IMPORTANT**: Replace the following values:
- `REPLACE-WITH-ACTIVATION-KEY` → Activation key from Step 1
- `REPLACE-WITH-SECURE-PASSWORD` → Strong password (min 12 chars, complexity required)

---

## Step 6: Validate Template

Before deploying, validate the template:

```powershell
# PowerShell
az deployment group validate `
  --resource-group rg-velocloud-aue `
  --template-file velocloud-edge-azure-template.json `
  --parameters '@velocloud-edge-azure-parameters.json'
```

```bash
# Bash
az deployment group validate \
  --resource-group rg-velocloud-aue \
  --template-file velocloud-edge-azure-template.json \
  --parameters @velocloud-edge-azure-parameters.json
```

**Expected Output:**
```json
{
  "properties": {
    "provisioningState": "Succeeded"
  }
}
```

---

## Step 7: Deploy Virtual Edge

```powershell
# PowerShell
az deployment group create `
  --name "velocloud-edge-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
  --resource-group rg-velocloud-aue `
  --template-file velocloud-edge-azure-template.json `
  --parameters '@velocloud-edge-azure-parameters.json'
```

```bash
# Bash
az deployment group create \
  --name "velocloud-edge-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-velocloud-aue \
  --template-file velocloud-edge-azure-template.json \
  --parameters @velocloud-edge-azure-parameters.json
```

**Deployment Time**: ~10-15 minutes

---

## Step 8: Verify Azure Deployment

### Check VM Status

```powershell
# PowerShell
az vm show `
  --resource-group rg-velocloud-aue `
  --name AERVAVC01 `
  --query "powerState" `
  --output tsv
```

**Expected**: `VM running`

### Get Public IP

```powershell
# PowerShell
az network public-ip show `
  --resource-group rg-velocloud-aue `
  --name AERVAVC01-pip `
  --query "ipAddress" `
  --output tsv
```

### Check All Resources

```powershell
# PowerShell
az resource list `
  --resource-group rg-velocloud-aue `
  --output table
```

**Expected Resources:**
| Name | Type |
|------|------|
| AERVAVC01 | virtualMachines |
| AERVAVC01-nic-wan | networkInterfaces |
| AERVAVC01-nic-lan | networkInterfaces |
| AERVAVC01-pip | publicIPAddresses |
| AERVAVC01-nsg | networkSecurityGroups |
| AERVAVC01-osdisk | disks |

---

## Step 9: Verify Edge Activation in VCO

1. **Login to VCO**: https://vco312-syd1.velocloud.net

2. **Check Edge Status**:
   ```
   Navigate: Monitor > Edges

   Find: AERVAVC01
   Expected Status: CONNECTED (green)
   ```

3. **Verify WAN Link**:
   ```
   Navigate: Monitor > Edges > AERVAVC01 > Links

   Expected:
   - GE1 (WAN): UP
   - Link Quality: Healthy (green)
   ```

4. **Check Tunnels**:
   ```
   Navigate: Test & Troubleshoot > Remote Diagnostics
   Select Edge: AERVAVC01
   Run: VPN Test

   Expected: All Gateway tunnels UP
   ```

⚠️ **If Edge shows OFFLINE after 10 minutes**, see Troubleshooting section below.

---

## Step 10: Configure User-Defined Routes (UDRs)

Route branch network traffic through the VeloCloud Edge:

### Create Route Table

```powershell
# PowerShell
az network route-table create `
  --name rt-workloads-via-velocloud `
  --resource-group rg-network-aue `
  --location australiaeast
```

### Add Routes to Branch Networks

```powershell
# Route to Branch A
az network route-table route create `
  --name route-to-branch-a `
  --route-table-name rt-workloads-via-velocloud `
  --resource-group rg-network-aue `
  --address-prefix 192.168.10.0/24 `
  --next-hop-type VirtualAppliance `
  --next-hop-ip-address 10.139.3.4

# Route to Branch B
az network route-table route create `
  --name route-to-branch-b `
  --route-table-name rt-workloads-via-velocloud `
  --resource-group rg-network-aue `
  --address-prefix 192.168.20.0/24 `
  --next-hop-type VirtualAppliance `
  --next-hop-ip-address 10.139.3.4
```

### Associate Route Table with Workload Subnet

```powershell
# PowerShell
az network vnet subnet update `
  --name workload-subnet `
  --vnet-name AER-hub-australiaeast `
  --resource-group rg-network-aue `
  --route-table rt-workloads-via-velocloud
```

---

## Step 11: Validate End-to-End Connectivity

### From Azure VM (in workload subnet)

```bash
# Ping branch gateway
ping 192.168.10.1

# Trace route (should show 10.139.3.4 as hop)
traceroute 192.168.10.1
```

### From Branch Edge (via VCO Remote Diagnostics)

```
Navigate: Test & Troubleshoot > Remote Diagnostics
Select Edge: [Branch Edge]
Run: Ping Test
Target: [Azure workload IP]
```

### Expected Results

| Test | Expected |
|------|----------|
| Azure → Branch ping | <50ms, 0% loss |
| Branch → Azure ping | <50ms, 0% loss |
| Traceroute via Edge | Shows 10.139.3.4 as hop |

---

## Troubleshooting

### Edge Not Activating (OFFLINE in VCO)

1. **Check DNS Resolution**:
   ```bash
   # From Azure VM or Cloud Shell
   nslookup vco312-syd1.velocloud.net
   ```

2. **Check NSG Rules**:
   ```powershell
   az network nsg rule list `
     --resource-group rg-velocloud-aue `
     --nsg-name AERVAVC01-nsg `
     --output table
   ```

   Verify UDP 2426 outbound is allowed.

3. **Check Activation Key**:
   - Verify key matches VCO exactly
   - Key not expired
   - Key not already used by another Edge

4. **View Boot Diagnostics**:
   ```
   Azure Portal > AERVAVC01 > Boot diagnostics > Serial log
   ```

5. **SSH to Edge** (if accessible):
   ```bash
   ssh vcadmin@<public-ip>

   # Check cloud-init
   cat /var/log/cloud-init-output.log

   # Check Edge service
   sudo /etc/init.d/edged status
   ```

### Tunnels Not Establishing

1. **Check Edge Events in VCO**:
   ```
   Monitor > Events > Filter by Edge: AERVAVC01
   ```

2. **Run VPN Test**:
   ```
   Test & Troubleshoot > Remote Diagnostics > VPN Test
   ```

3. **Verify Gateway Reachability**:
   - Check if Edge can reach assigned Gateways
   - Verify no firewall blocking UDP 2426

### Poor Performance

1. **Check DMPO Metrics**:
   ```
   Monitor > QoE > AERVAVC01
   ```

   Review: Latency, Jitter, Packet Loss

2. **Verify Link Steering**:
   ```
   Monitor > Edges > AERVAVC01 > Transport
   ```

3. **Check Business Policies**:
   - Verify correct application steering rules
   - Check QoS policy assignments

---

## Rollback Procedure

If deployment fails or causes issues:

### 1. Remove UDRs (Immediate Traffic Restoration)

```powershell
# Remove route table association
az network vnet subnet update `
  --name workload-subnet `
  --vnet-name AER-hub-australiaeast `
  --resource-group rg-network-aue `
  --remove routeTable
```

### 2. Deactivate Edge in VCO

```
Navigate: Configure > Edges > AERVAVC01
Actions > Deactivate Edge
```

### 3. Delete Azure Resources

```powershell
az group delete --name rg-velocloud-aue --yes --no-wait
```

### 4. Document and Review

- Document rollback reason
- Schedule post-incident review

---

## Post-Deployment Checklist

| Task | Status |
|------|--------|
| VM running in Azure | ☐ |
| Edge CONNECTED in VCO | ☐ |
| WAN link UP and healthy | ☐ |
| All tunnels established | ☐ |
| UDRs configured | ☐ |
| Branch connectivity tested | ☐ |
| Application access verified | ☐ |
| Network diagrams updated | ☐ |
| IPAM updated | ☐ |
| Runbooks updated | ☐ |

---

## Support Contacts

| Issue | Contact |
|-------|---------|
| Azure deployment issues | Cloud Team / Azure Support |
| VeloCloud Edge issues | Network Team / VMware Support |
| VCO access issues | VeloCloud TAM |
| Application issues | Application Owner |

---

*Generated by VeloCloud SD-WAN Agent v2.2*