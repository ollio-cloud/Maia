# AVD Sandbox Deployment Guide - Complete Environment

## Overview

This guide deploys a **complete AVD environment from scratch** for testing/sandbox purposes. Everything is created fresh - no existing resources required.

---

## What Gets Deployed

| Resource | Name Pattern | Description |
|----------|--------------|-------------|
| **Virtual Network** | `test-avd-vnet` | VNet with AVD subnet + NSG |
| **Host Pool** | `test-avd-hp` | Pooled host pool with validation mode |
| **Application Group** | `test-avd-dag` | Desktop application group |
| **Workspace** | `test-avd-ws` | AVD workspace |
| **Storage Account** | `testavdfslogix` | Premium FileStorage for FSLogix |
| **File Share** | `fslogix-profiles` | Profile container share |
| **Session Host** | `testavd-0` | Windows 11 AVD VM (Standard_E8s_v5) |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Resource Group: sandbox-avd-rg                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    test-avd-vnet (10.100.0.0/16)             │   │
│  │  ┌────────────────────────────────────────────────────────┐  │   │
│  │  │              snet-avd (10.100.1.0/24)                  │  │   │
│  │  │                                                        │  │   │
│  │  │   ┌─────────────┐                                      │  │   │
│  │  │   │  testavd-0  │◄──── Standard_E8s_v5                 │  │   │
│  │  │   │  (Win 11)   │      Azure AD Joined                 │  │   │
│  │  │   └──────┬──────┘      Intune Enrolled                 │  │   │
│  │  │          │                                             │  │   │
│  │  └──────────┼─────────────────────────────────────────────┘  │   │
│  └─────────────┼────────────────────────────────────────────────┘   │
│                │                                                     │
│                ▼                                                     │
│  ┌─────────────────────────┐    ┌──────────────────────────────┐   │
│  │    testavdfslogix       │    │        test-avd-hp           │   │
│  │    (Premium Storage)    │    │        (Host Pool)           │   │
│  │  ┌───────────────────┐  │    │                              │   │
│  │  │  fslogix-profiles │  │    │  ┌────────────────────────┐  │   │
│  │  │     (256 GB)      │  │    │  │    test-avd-dag        │  │   │
│  │  └───────────────────┘  │    │  │  (Desktop App Group)   │  │   │
│  └─────────────────────────┘    │  └────────────────────────┘  │   │
│                                  │                              │   │
│                                  │  ┌────────────────────────┐  │   │
│                                  │  │    test-avd-ws         │  │   │
│                                  │  │    (Workspace)         │  │   │
│                                  │  └────────────────────────┘  │   │
│                                  └──────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Pre-Deployment Requirements

### 1. Azure CLI Login

```bash
# Login to Azure
az login

# Set subscription (update with your sandbox subscription ID)
az account set --subscription "YOUR_SANDBOX_SUBSCRIPTION_ID"

# Verify current context
az account show --output table
```

### 2. Create Resource Group

```bash
# Create resource group for sandbox
az group create \
    --name "sandbox-avd-rg" \
    --location "australiasoutheast"
```

### 3. (Optional) Get Azure AD Information

If you want Azure AD Kerberos for FSLogix and RBAC assignments:

```bash
# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"

# Get Tenant Name (default domain)
TENANT_NAME=$(az rest --method get --url "https://graph.microsoft.com/v1.0/organization" \
    --query "value[0].verifiedDomains[?isDefault].name" -o tsv)
echo "Tenant Name: $TENANT_NAME"

# Get AVD Users group Object ID (if exists)
AVD_USERS_ID=$(az ad group show --group "AVD-Users" --query id -o tsv 2>/dev/null)
echo "AVD Users Group ID: $AVD_USERS_ID"

# Get AVD Admins group Object ID (if exists)
AVD_ADMINS_ID=$(az ad group show --group "AVD-Admins" --query id -o tsv 2>/dev/null)
echo "AVD Admins Group ID: $AVD_ADMINS_ID"
```

---

## Deployment Options

### Option A: Minimal Deployment (Fastest)

Deploy with defaults - no Azure AD groups required, uses storage account key for FSLogix:

```bash
cd c:/Users/olli.ojala/maia/claude/templates/avd/bicep

# Deploy complete sandbox environment
az deployment group create \
    --resource-group "sandbox-avd-rg" \
    --template-file "avd-sandbox-complete.bicep" \
    --parameters @avd-sandbox-complete.bicepparam \
    --parameters adminPassword="YourSecureP@ssw0rd!" \
    --verbose
```

### Option B: Full Deployment with Azure AD Integration

Update the parameter file first with your Azure AD values, then deploy:

```bash
# Edit avd-sandbox-complete.bicepparam:
# param azureADTenantId = 'YOUR_TENANT_ID'
# param azureADTenantName = 'yourtenant.onmicrosoft.com'
# param avdUsersGroupObjectId = 'YOUR_AVD_USERS_GROUP_ID'
# param avdAdminsGroupObjectId = 'YOUR_AVD_ADMINS_GROUP_ID'

# Then deploy
az deployment group create \
    --resource-group "sandbox-avd-rg" \
    --template-file "avd-sandbox-complete.bicep" \
    --parameters @avd-sandbox-complete.bicepparam \
    --parameters adminPassword="YourSecureP@ssw0rd!" \
    --verbose
```

### Option C: What-If Preview First

```bash
# Preview what will be created
az deployment group what-if \
    --resource-group "sandbox-avd-rg" \
    --template-file "avd-sandbox-complete.bicep" \
    --parameters @avd-sandbox-complete.bicepparam \
    --parameters adminPassword="TempPassword123!"
```

### Option D: Deploy Multiple Session Hosts

```bash
# Deploy with 2 session hosts
az deployment group create \
    --resource-group "sandbox-avd-rg" \
    --template-file "avd-sandbox-complete.bicep" \
    --parameters @avd-sandbox-complete.bicepparam \
    --parameters adminPassword="YourSecureP@ssw0rd!" \
    --parameters sessionHostCount=2 \
    --verbose
```

### Option E: Deploy with Inline Parameters (No Parameter File)

```bash
# Deploy with all parameters inline
az deployment group create \
    --resource-group "sandbox-avd-rg" \
    --template-file "avd-sandbox-complete.bicep" \
    --parameters \
        environmentPrefix="test" \
        projectName="avd" \
        location="australiasoutheast" \
        vmSize="Standard_E8s_v5" \
        adminUsername="avdadmin" \
        adminPassword="YourSecureP@ssw0rd!" \
        sessionHostCount=1 \
        enableFSLogix=true \
    --verbose
```

---

## Deployment Timeline

| Phase | Duration | Resources Created |
|-------|----------|-------------------|
| **VNet + NSG** | 1-2 min | Virtual network, subnet, NSG |
| **Host Pool** | 30 sec | Host pool with registration token |
| **App Group** | 30 sec | Desktop application group |
| **Workspace** | 30 sec | AVD workspace |
| **Storage** | 2-3 min | Storage account + file share |
| **Session Host** | 8-12 min | VM, NIC, extensions |
| **FSLogix** | 5-8 min | Download, install, configure |
| **Total** | **~20-30 min** | Complete environment |

---

## Post-Deployment Validation

### Step 1: Check Deployment Outputs

The deployment will output key information:

```bash
# Get deployment outputs
az deployment group show \
    --resource-group "sandbox-avd-rg" \
    --name "avd-sandbox-complete" \
    --query properties.outputs
```

### Step 2: Verify All Resources

```bash
# List all resources in sandbox
az resource list \
    --resource-group "sandbox-avd-rg" \
    --output table

# Expected resources:
# - test-avd-vnet (VNet)
# - snet-avd-nsg (NSG)
# - test-avd-hp (Host Pool)
# - test-avd-dag (Application Group)
# - test-avd-ws (Workspace)
# - testavdfslogix (Storage Account)
# - testavd-0 (VM)
# - testavd-0-nic (NIC)
# - testavd-0-osdisk (Disk)
```

### Step 3: Verify Host Pool Registration

```bash
# Check session host is registered
az desktopvirtualization hostpool session-host list \
    --resource-group "sandbox-avd-rg" \
    --host-pool-name "test-avd-hp" \
    --output table

# Expected: Status = Available
```

### Step 4: Verify VM Extensions

```bash
# Check all extensions succeeded
az vm extension list \
    --resource-group "sandbox-avd-rg" \
    --vm-name "testavd-0" \
    --output table

# Expected:
# - AADLoginForWindows: Succeeded
# - Microsoft.PowerShell.DSC: Succeeded
# - FSLogixConfig: Succeeded
```

### Step 5: Assign Users (if not done via RBAC)

If you didn't provide Azure AD group IDs, manually assign users:

```bash
# Get your user's Object ID
USER_ID=$(az ad user show --id "user@yourdomain.com" --query id -o tsv)

# Get application group resource ID
APP_GROUP_ID=$(az desktopvirtualization applicationgroup show \
    --resource-group "sandbox-avd-rg" \
    --name "test-avd-dag" \
    --query id -o tsv)

# Assign Desktop Virtualization User role
az role assignment create \
    --assignee "$USER_ID" \
    --role "Desktop Virtualization User" \
    --scope "$APP_GROUP_ID"
```

### Step 6: Test User Connection

1. Open: https://client.wvd.microsoft.com
2. Sign in with an assigned user
3. Click on the "test Desktop" icon
4. Verify connection to `testavd-0`

---

## Customization Options

### Change Environment Prefix

Edit parameter file or override at deployment:

```bash
# Create dev resource group
az group create --name "dev-avd-rg" --location "australiasoutheast"

# Deploy as "dev" environment
az deployment group create \
    --resource-group "dev-avd-rg" \
    --template-file "avd-sandbox-complete.bicep" \
    --parameters @avd-sandbox-complete.bicepparam \
    --parameters environmentPrefix="dev" \
    --parameters adminPassword="YourSecureP@ssw0rd!"

# Creates: dev-avd-vnet, dev-avd-hp, devavd-0, etc.
```

### Change VM Size

```bash
# Use smaller VM for cost savings
--parameters vmSize="Standard_D4s_v5"

# Available sizes:
# Standard_D2s_v5  (2 vCPU, 8 GB)   ~$70/month
# Standard_D4s_v5  (4 vCPU, 16 GB)  ~$140/month
# Standard_D8s_v5  (8 vCPU, 32 GB)  ~$280/month
# Standard_E2s_v5  (2 vCPU, 16 GB)  ~$90/month
# Standard_E4s_v5  (4 vCPU, 32 GB)  ~$180/month
# Standard_E8s_v5  (8 vCPU, 64 GB)  ~$360/month
```

### Disable FSLogix (Simpler Test)

```bash
# Deploy without FSLogix
--parameters enableFSLogix=false
```

### Change Network Configuration

```bash
# Use different IP ranges
--parameters vnetAddressPrefix="10.200.0.0/16" \
--parameters avdSubnetPrefix="10.200.1.0/24"
```

---

## Cost Estimate (Sandbox)

| Resource | SKU | Est. Monthly Cost |
|----------|-----|-------------------|
| VM (1x Standard_E8s_v5) | E8s_v5 | ~$360 |
| OS Disk (Premium 128GB) | P10 | ~$20 |
| Storage Account | Premium FileStorage | ~$5 (base) |
| File Share (256 GB) | Premium | ~$41 |
| VNet/NSG | - | Free |
| Host Pool/Workspace | - | Free |
| **Total** | | **~$426/month** |

### Cost Savings Tips

1. **Auto-shutdown**: Enable auto-shutdown for non-business hours
2. **Smaller VM**: Use `Standard_D4s_v5` for testing (~$140/month savings)
3. **Deallocate when not in use**: Stop VM when not testing
4. **Delete after testing**: Remove entire resource group when done

```bash
# Get VM resource ID
VM_ID=$(az vm show \
    --resource-group "sandbox-avd-rg" \
    --name "testavd-0" \
    --query id -o tsv)

# Get subscription ID
SUB_ID=$(az account show --query id -o tsv)

# Schedule auto-shutdown (8 PM daily)
az resource create \
    --resource-group "sandbox-avd-rg" \
    --resource-type "microsoft.devtestlab/schedules" \
    --name "shutdown-computevm-testavd-0" \
    --location "australiasoutheast" \
    --properties "{
        \"status\": \"Enabled\",
        \"taskType\": \"ComputeVmShutdownTask\",
        \"dailyRecurrence\": { \"time\": \"2000\" },
        \"timeZoneId\": \"AUS Eastern Standard Time\",
        \"targetResourceId\": \"$VM_ID\"
    }"

# Manually stop VM when not in use
az vm deallocate --resource-group "sandbox-avd-rg" --name "testavd-0"

# Start VM when needed
az vm start --resource-group "sandbox-avd-rg" --name "testavd-0"
```

---

## Cleanup - Delete Sandbox

When finished testing, remove everything:

```bash
# Delete entire resource group (all resources)
az group delete --name "sandbox-avd-rg" --yes --no-wait

# Check deletion status
az group show --name "sandbox-avd-rg" --query properties.provisioningState 2>/dev/null || echo "Resource group deleted"
```

---

## Troubleshooting

### Issue 1: Host Pool Token Expired

If deployment takes too long and token expires:

```bash
# Regenerate token (valid for 24 hours)
az desktopvirtualization hostpool registration-info create \
    --resource-group "sandbox-avd-rg" \
    --host-pool-name "test-avd-hp" \
    --expiration-time "$(date -d '+24 hours' --iso-8601=seconds 2>/dev/null || date -v+24H +%Y-%m-%dT%H:%M:%SZ)"

# Then re-run DSC extension on VM to re-register
```

### Issue 2: VM Extension Failed

```bash
# Check extension status
az vm extension list \
    --resource-group "sandbox-avd-rg" \
    --vm-name "testavd-0" \
    --query "[].{Name:name, Status:provisioningState}" \
    --output table

# Remove failed extension
az vm extension delete \
    --resource-group "sandbox-avd-rg" \
    --vm-name "testavd-0" \
    --name "FSLogixConfig"

# Redeploy just FSLogix extension if needed
```

### Issue 3: Cannot Connect to AVD

```bash
# Check user is assigned to application group
az role assignment list \
    --scope "$(az desktopvirtualization applicationgroup show \
        --resource-group sandbox-avd-rg \
        --name test-avd-dag --query id -o tsv)" \
    --output table

# Check session host status
az desktopvirtualization hostpool session-host list \
    --resource-group "sandbox-avd-rg" \
    --host-pool-name "test-avd-hp" \
    --query "[].{Name:name, Status:status, AllowNewSession:allowNewSession}" \
    --output table

# Check VM is running
az vm get-instance-view \
    --resource-group "sandbox-avd-rg" \
    --name "testavd-0" \
    --query instanceView.statuses[1].displayStatus -o tsv
```

### Issue 4: FSLogix Profile Not Created

1. Verify storage account firewall allows VNet access
2. Check FSLogix service running (RDP to VM): `Get-Service frxsvc`
3. Review logs (on VM): `C:\ProgramData\FSLogix\Logs\Profile*.log`

```bash
# Check storage account network rules
az storage account show \
    --resource-group "sandbox-avd-rg" \
    --name "testavdfslogix" \
    --query networkRuleSet
```

---

## File Structure

```
claude/templates/avd/bicep/
├── avd-sandbox-complete.bicep          # Complete sandbox orchestrator
├── avd-sandbox-complete.bicepparam     # Sandbox parameters
├── avd-session-host-deploy.bicep       # Production session host
├── avd-session-host-deploy.bicepparam  # Production parameters
├── main.bicep                          # FSLogix-only deployment
└── modules/
    ├── virtual-network.bicep           # VNet + NSG
    ├── host-pool.bicep                 # AVD Host Pool
    ├── application-group.bicep         # Desktop/RemoteApp group
    ├── workspace.bicep                 # AVD Workspace
    ├── session-host.bicep              # VM + AVD registration
    ├── storage-account.bicep           # Premium FileStorage
    ├── file-share.bicep                # Azure Files share
    ├── rbac-assignment.bicep           # File share RBAC
    └── fslogix-extension.bicep         # FSLogix VM extension
```

---

## Quick Reference

```bash
# === DEPLOY SANDBOX ===
cd c:/Users/olli.ojala/maia/claude/templates/avd/bicep

# Create resource group
az group create --name "sandbox-avd-rg" --location "australiasoutheast"

# Deploy everything
az deployment group create \
    --resource-group "sandbox-avd-rg" \
    --template-file "avd-sandbox-complete.bicep" \
    --parameters @avd-sandbox-complete.bicepparam \
    --parameters adminPassword="YourSecureP@ssw0rd!" \
    --verbose

# === VERIFY ===
az desktopvirtualization hostpool session-host list \
    --resource-group "sandbox-avd-rg" \
    --host-pool-name "test-avd-hp" \
    --output table

# === CONNECT ===
# Open: https://client.wvd.microsoft.com

# === CLEANUP ===
az group delete --name "sandbox-avd-rg" --yes --no-wait
```
