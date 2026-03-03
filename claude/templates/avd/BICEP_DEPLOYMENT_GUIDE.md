# AVD Bicep Deployment Guide - Complete Reference

## Overview

This guide covers deploying Azure Virtual Desktop session hosts using Bicep, including:
- **New session host VM creation** (pauseisavd-1, Standard_E8s_v5)
- **AVD host pool registration**
- **FSLogix profile container configuration**

---

## Environment Summary

| Parameter | Value |
|-----------|-------|
| **Resource Group** | `p-ause-mb-rg-avd` |
| **Location** | `australiasoutheast` |
| **Host Pool** | `pauseisavdpool01` |
| **New Session Host** | `pauseisavd-1` |
| **VM Size** | `Standard_E8s_v5` (8 vCPU, 64 GB RAM) |
| **Storage Account** | `pauseisfslogix001` |
| **File Share** | `fslogix-profiles` |

### Standard_E8s_v5 Specifications

| Spec | Value |
|------|-------|
| vCPUs | 8 |
| Memory | 64 GB |
| Temp Storage | 128 GB |
| Max Data Disks | 16 |
| Max NICs | 4 |
| Expected Cost | ~$280/month (Australia East, Pay-As-You-Go) |

---

## File Structure

```
claude/templates/avd/bicep/
├── avd-session-host-deploy.bicep       # Main orchestrator (NEW)
├── avd-session-host-deploy.bicepparam  # Parameters file (NEW)
├── main.bicep                          # FSLogix-only deployment
├── main.bicepparam                     # FSLogix parameters
└── modules/
    ├── session-host.bicep              # VM + AVD registration (NEW)
    ├── storage-account.bicep           # Premium FileStorage
    ├── file-share.bicep                # Azure Files share
    ├── rbac-assignment.bicep           # File share RBAC
    └── fslogix-extension.bicep         # FSLogix VM extension
```

---

## Pre-Deployment Checklist

### Step 1: Gather Required Information

Run these Azure CLI commands to collect necessary values:

```bash
# Login to Azure
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# 1. Get Subscription ID
SUB_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUB_ID"

# 2. Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"

# 3. Get existing VNet and Subnet (from existing session host)
NIC_ID=$(az vm show \
    --resource-group "p-ause-mb-rg-avd" \
    --name "pauseisavd-0" \
    --query "networkProfile.networkInterfaces[0].id" -o tsv)

SUBNET_ID=$(az network nic show \
    --ids "$NIC_ID" \
    --query "ipConfigurations[0].subnet.id" -o tsv)
echo "Subnet ID: $SUBNET_ID"

# 4. Generate Host Pool Registration Token (valid for 24 hours)
# Note: Date format varies by OS - use appropriate format for your system
# Linux/WSL:
EXPIRATION=$(date -d '+24 hours' --iso-8601=seconds)
# macOS:
# EXPIRATION=$(date -v+24H +%Y-%m-%dT%H:%M:%SZ)

TOKEN=$(az desktopvirtualization hostpool registration-info create \
    --resource-group "p-ause-mb-rg-avd" \
    --host-pool-name "pauseisavdpool01" \
    --expiration-time "$EXPIRATION" \
    --query token -o tsv)
echo "Token generated (length: ${#TOKEN} chars)"
```

### Step 2: Update Parameter File

Edit `bicep/avd-session-host-deploy.bicepparam`:

```bicep
// Network Configuration - UPDATE THIS
param subnetId = '/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Network/virtualNetworks/YOUR_VNET_NAME/subnets/YOUR_SUBNET_NAME'
```

### Step 3: Verify Prerequisites

```bash
# Verify resource group exists
az group show --name "p-ause-mb-rg-avd" --output table

# Verify host pool exists
az desktopvirtualization hostpool show \
    --resource-group "p-ause-mb-rg-avd" \
    --name "pauseisavdpool01" \
    --output table

# Verify FSLogix storage exists (if using FSLogix)
az storage account show \
    --resource-group "p-ause-mb-rg-avd" \
    --name "pauseisfslogix001" \
    --query "{Name:name, Location:location, Kind:kind}" \
    --output table

# Verify subnet exists (using the SUBNET_ID from Step 1)
az network vnet subnet show --ids "$SUBNET_ID" --output table
```

---

## Deployment Options

### Option A: Deploy Session Host with FSLogix (Recommended)

This deploys the complete solution: VM + AVD registration + FSLogix.

```bash
# Navigate to bicep directory
cd c:/Users/olli.ojala/maia/claude/templates/avd/bicep

# Generate host pool token (Linux/WSL date format)
EXPIRATION=$(date -d '+24 hours' --iso-8601=seconds)
# macOS: EXPIRATION=$(date -v+24H +%Y-%m-%dT%H:%M:%SZ)

TOKEN=$(az desktopvirtualization hostpool registration-info create \
    --resource-group "p-ause-mb-rg-avd" \
    --host-pool-name "pauseisavdpool01" \
    --expiration-time "$EXPIRATION" \
    --query token -o tsv)

# Deploy with What-If first (preview changes)
az deployment group what-if \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file "avd-session-host-deploy.bicep" \
    --parameters @avd-session-host-deploy.bicepparam \
    --parameters adminPassword="YourSecureP@ssw0rd!" \
    --parameters hostPoolToken="$TOKEN"

# If What-If looks good, deploy
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file "avd-session-host-deploy.bicep" \
    --parameters @avd-session-host-deploy.bicepparam \
    --parameters adminPassword="YourSecureP@ssw0rd!" \
    --parameters hostPoolToken="$TOKEN" \
    --verbose
```

### Option B: Deploy Session Host Only (No FSLogix)

If FSLogix is already configured or you don't need it:

```bash
# Generate host pool token
TOKEN=$(az desktopvirtualization hostpool registration-info create \
    --resource-group "p-ause-mb-rg-avd" \
    --host-pool-name "pauseisavdpool01" \
    --expiration-time "$EXPIRATION" \
    --query token -o tsv)

# Deploy without FSLogix
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file "avd-session-host-deploy.bicep" \
    --parameters @avd-session-host-deploy.bicepparam \
    --parameters adminPassword="YourSecureP@ssw0rd!" \
    --parameters hostPoolToken="$TOKEN" \
    --parameters enableFSLogix=false \
    --verbose
```

### Option C: Configure FSLogix Only (VM Already Exists)

If the VM exists and you just need FSLogix:

```bash
# Deploy FSLogix configuration only
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file "main.bicep" \
    --parameters @main.bicepparam \
    --verbose
```

### Option D: Interactive Password Prompt (More Secure)

For security, you can prompt for the password instead of passing it inline:

```bash
# Prompt for password (won't show on screen)
echo -n "Enter admin password: " && read -s ADMIN_PASS && echo

# Generate token
TOKEN=$(az desktopvirtualization hostpool registration-info create \
    --resource-group "p-ause-mb-rg-avd" \
    --host-pool-name "pauseisavdpool01" \
    --expiration-time "$EXPIRATION" \
    --query token -o tsv)

# Deploy with prompted password
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file "avd-session-host-deploy.bicep" \
    --parameters @avd-session-host-deploy.bicepparam \
    --parameters adminPassword="$ADMIN_PASS" \
    --parameters hostPoolToken="$TOKEN" \
    --verbose
```

---

## Deployment Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| **What-If** | 30-60 sec | Preview changes |
| **NIC Creation** | 30 sec | Network interface |
| **VM Deployment** | 5-8 min | VM provisioning |
| **Azure AD Join** | 2-3 min | AADLoginForWindows extension |
| **AVD Agent** | 3-5 min | DSC extension for host pool registration |
| **FSLogix** | 5-8 min | Download, install, configure |
| **Total** | **15-25 min** | Complete deployment |

---

## Post-Deployment Validation

### Step 1: Verify VM Deployment

```bash
# Check VM status
az vm get-instance-view \
    --resource-group "p-ause-mb-rg-avd" \
    --name "pauseisavd-1" \
    --query "{Name:name, PowerState:instanceView.statuses[1].displayStatus}" \
    --output table

# Expected: PowerState = VM running
```

### Step 2: Verify AVD Registration

```bash
# Check session host in host pool
az desktopvirtualization hostpool session-host list \
    --resource-group "p-ause-mb-rg-avd" \
    --host-pool-name "pauseisavdpool01" \
    --query "[?contains(name, 'pauseisavd-1')].{Name:name, Status:status, AllowNewSession:allowNewSession}" \
    --output table

# Expected: Status = Available, AllowNewSession = true
```

### Step 3: Verify VM Extensions

```bash
# List all extensions
az vm extension list \
    --resource-group "p-ause-mb-rg-avd" \
    --vm-name "pauseisavd-1" \
    --query "[].{Name:name, Status:provisioningState, Publisher:publisher}" \
    --output table

# Expected extensions:
# - AADLoginForWindows (Succeeded)
# - Microsoft.PowerShell.DSC (Succeeded)
# - FSLogixConfig (Succeeded) - if enabled
```

### Step 4: Verify FSLogix (if enabled)

Connect to VM via Azure Bastion or RDP, then run on the VM:

```powershell
# Check FSLogix services
Get-Service -Name "frxsvc", "frxccds" | Format-Table Name, Status

# Check registry settings
Get-ItemProperty "HKLM:\SOFTWARE\FSLogix\Profiles"

# Check FSLogix logs
Get-Content "C:\ProgramData\FSLogix\Logs\Profile*.log" -Tail 50
```

### Step 5: Test User Login

1. Open Azure Virtual Desktop web client: https://client.wvd.microsoft.com
2. Sign in with a test user
3. Connect to `pauseisavdpool01`
4. Verify session connects to `pauseisavd-1`
5. Check FSLogix profile is created (on session host):

```powershell
# On session host via RDP
Get-ChildItem "\\pauseisfslogix001.file.core.windows.net\fslogix-profiles"
# Expected: Folder named {SID}_{Username}
```

---

## Troubleshooting

### Issue 1: VM Extension Failed

**Symptom**: Azure AD Join or DSC extension shows "Failed"

**Solution**:
```bash
# Get extension details
az vm extension show \
    --resource-group "p-ause-mb-rg-avd" \
    --vm-name "pauseisavd-1" \
    --name "AADLoginForWindows" \
    --query "{Status:provisioningState, Message:instanceView.statuses[0].message}"

# Remove failed extension
az vm extension delete \
    --resource-group "p-ause-mb-rg-avd" \
    --vm-name "pauseisavd-1" \
    --name "AADLoginForWindows"

# Redeploy extension manually if needed
```

### Issue 2: Session Host Not Appearing in Host Pool

**Symptom**: VM deployed but not visible in AVD portal

**Causes**:
1. Expired registration token (regenerate)
2. DSC extension failed
3. Network connectivity issue

**Solution**:
```bash
# Check DSC extension
az vm extension show \
    --resource-group "p-ause-mb-rg-avd" \
    --vm-name "pauseisavd-1" \
    --name "Microsoft.PowerShell.DSC" \
    --query "{Status:provisioningState, Message:instanceView.statuses[0].message}"

# Regenerate token
NEW_TOKEN=$(az desktopvirtualization hostpool registration-info create \
    --resource-group "p-ause-mb-rg-avd" \
    --host-pool-name "pauseisavdpool01" \
    --expiration-time "$EXPIRATION" \
    --query token -o tsv)

echo "New token generated. Re-run DSC extension manually on VM if needed."
```

### Issue 3: FSLogix Profile Not Created

**Checklist** (run on the VM via RDP):
1. FSLogix service running: `Get-Service frxsvc`
2. Registry correct: `Get-ItemProperty HKLM:\SOFTWARE\FSLogix\Profiles`
3. Network connectivity: `Test-NetConnection pauseisfslogix001.file.core.windows.net -Port 445`
4. RBAC permissions: User in AVD-Users group with SMB Contributor role

```bash
# Check RBAC on storage account from CLI
az role assignment list \
    --scope "/subscriptions/$SUB_ID/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Storage/storageAccounts/pauseisfslogix001" \
    --output table
```

### Issue 4: Azure AD Join Failed

**Symptom**: VM not appearing in Azure AD / Intune

**Solution** (on the VM via RDP):
```powershell
# Check join status
dsregcmd /status

# Look for:
# AzureAdJoined: YES
# DomainJoined: NO (for cloud-only)
```

---

## Cost Summary

| Resource | SKU | Est. Monthly Cost |
|----------|-----|-------------------|
| VM (pauseisavd-1) | Standard_E8s_v5 | ~$280 |
| OS Disk | Premium_LRS 128GB | ~$20 |
| NIC | Standard | Included |
| FSLogix Storage | Premium FileStorage 256GB | ~$41 |
| **Total** | | **~$341/month** |

### Cost Optimization Recommendations

1. **Reserved Instance**: 40% savings with 1-year RI (~$170/month for VM)
2. **Auto-shutdown**: Schedule for non-business hours (50% savings if 12hr/day)
3. **Right-sizing**: Monitor CPU/memory, downsize if <40% utilization

---

## Security Considerations

### Network Security
- VM deployed in private subnet (no public IP)
- Access via Azure Bastion recommended
- NSG rules should allow:
  - Outbound 443 (Azure services)
  - Outbound 445 (Azure Files)
  - RDP only from Bastion subnet

### Identity Security
- Azure AD joined (no traditional AD required)
- Managed identity enabled for Azure RBAC
- Intune enrolled for device compliance

### Data Security
- FSLogix profiles in Azure Files with Azure AD Kerberos
- Encryption at rest (default)
- TLS 1.2 minimum for storage

---

## Quick Reference Commands

```bash
# === Pre-Deployment ===
# Get subnet ID from existing VM
NIC_ID=$(az vm show --resource-group "p-ause-mb-rg-avd" --name "pauseisavd-0" \
    --query "networkProfile.networkInterfaces[0].id" -o tsv)
SUBNET_ID=$(az network nic show --ids "$NIC_ID" \
    --query "ipConfigurations[0].subnet.id" -o tsv)
echo "Subnet ID: $SUBNET_ID"

# Generate host pool token
# Linux/WSL:
EXPIRATION=$(date -d '+24 hours' --iso-8601=seconds)
# macOS:
# EXPIRATION=$(date -v+24H +%Y-%m-%dT%H:%M:%SZ)

TOKEN=$(az desktopvirtualization hostpool registration-info create \
    --resource-group "p-ause-mb-rg-avd" \
    --host-pool-name "pauseisavdpool01" \
    --expiration-time "$EXPIRATION" \
    --query token -o tsv)

# === Deployment ===
# What-If (preview)
az deployment group what-if \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file "avd-session-host-deploy.bicep" \
    --parameters @avd-session-host-deploy.bicepparam \
    --parameters adminPassword="YourPassword" hostPoolToken="$TOKEN"

# Deploy
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file "avd-session-host-deploy.bicep" \
    --parameters @avd-session-host-deploy.bicepparam \
    --parameters adminPassword="YourPassword" hostPoolToken="$TOKEN" \
    --verbose

# === Post-Deployment ===
# Verify VM
az vm get-instance-view \
    --resource-group "p-ause-mb-rg-avd" \
    --name "pauseisavd-1" \
    --query "{Name:name, PowerState:instanceView.statuses[1].displayStatus}" -o table

# Verify session host
az desktopvirtualization hostpool session-host list \
    --resource-group "p-ause-mb-rg-avd" \
    --host-pool-name "pauseisavdpool01" \
    --output table

# Check extensions
az vm extension list \
    --resource-group "p-ause-mb-rg-avd" \
    --vm-name "pauseisavd-1" \
    --output table
```

---

## Next Steps After Deployment

1. **Test user login** via AVD web client
2. **Verify FSLogix profile** creation
3. **Configure scaling plan** if using auto-scaling
4. **Set up monitoring** (Azure Monitor, Log Analytics)
5. **Enable backup** for VM and storage
6. **Document** in team runbook

---

## Support Resources

| Resource | Location |
|----------|----------|
| Bicep Templates | `claude/templates/avd/bicep/` |
| ARM Templates | `claude/templates/avd/` |
| FSLogix Guide | `claude/templates/avd/DEPLOYMENT_GUIDE.md` |
| Module Documentation | `claude/templates/avd/bicep/MODULES.md` |
