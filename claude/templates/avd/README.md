# FSLogix ARM Templates for Azure Virtual Desktop

## Overview

ARM templates for automated deployment of FSLogix profile containers for Azure AD joined AVD environments.

## Environment Configuration

| Parameter | Value |
|-----------|-------|
| Resource Group | `p-ause-mb-rg-avd` |
| Location | `australiasoutheast` |
| Storage Account | `pauseisfslogix001` |
| File Share | `fslogix-profiles` |
| Host Pool | `pauseisavdpool01` |
| Session Hosts | `pauseisavd-0`, `pauseisavd-1` |
| VM Size | `Standard_E8s_v5` |

## Files

```
claude/templates/avd/
├── fslogix-storage.json              # Storage account template
├── fslogix-vm-extension.json         # VM extension template (FSLogix config)
├── fslogix-complete.json             # Combined template (recommended)
├── Deploy-FSLogix.ps1                # Deployment script
├── Validate-FSLogix.ps1              # Validation script
├── README.md                         # This file
└── parameters/
    ├── fslogix-storage.parameters.json
    ├── fslogix-vm-extension.parameters.json
    └── fslogix-complete.parameters.json
```

## Quick Start

### Option 1: PowerShell Deployment Script (Recommended)

```powershell
# Connect to Azure
Connect-AzAccount

# Deploy FSLogix infrastructure
.\Deploy-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd" `
                     -StorageAccountName "pauseisfslogix001" `
                     -VMNames @("pauseisavd-0", "pauseisavd-1")
```

### Option 2: Direct ARM Deployment (Combined Template)

```powershell
# Update parameters file first
# Edit: parameters/fslogix-complete.parameters.json

# Deploy
New-AzResourceGroupDeployment `
    -ResourceGroupName "p-ause-mb-rg-avd" `
    -TemplateFile "fslogix-complete.json" `
    -TemplateParameterFile "parameters/fslogix-complete.parameters.json"
```

### Option 3: Azure CLI

```bash
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file "fslogix-complete.json" \
    --parameters @parameters/fslogix-complete.parameters.json
```

## Pre-Deployment Checklist

Before deploying, update the parameter files with your values:

1. **Azure AD Tenant ID**
   ```json
   "azureADTenantId": {
     "value": "YOUR_TENANT_ID_HERE"  // Get from: (Get-AzContext).Tenant.Id
   }
   ```

2. **Azure AD Tenant Name**
   ```json
   "azureADTenantName": {
     "value": "YOUR_TENANT.onmicrosoft.com"
   }
   ```

3. **AVD Users Group Object ID** (for RBAC)
   ```powershell
   # Get group Object ID
   (Get-AzADGroup -DisplayName "AVD-Users").Id
   ```

4. **AVD Admins Group Object ID** (for elevated access)
   ```powershell
   (Get-AzADGroup -DisplayName "AVD-Admins").Id
   ```

## Validation

After deployment, run the validation script:

```powershell
.\Validate-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd" `
                       -StorageAccountName "pauseisfslogix001" `
                       -VMNames @("pauseisavd-0", "pauseisavd-1")
```

## Template Details

### fslogix-storage.json

Creates:
- Premium FileStorage account
- Azure Files share (256 GB quota)
- Azure AD Kerberos authentication
- RBAC role assignments

### fslogix-vm-extension.json

Configures:
- Downloads and installs FSLogix agent
- Configures Profile Container settings
- Configures Office Container (optional)
- Sets VHD location to Azure Files share

### FSLogix Registry Settings Applied

| Setting | Value | Description |
|---------|-------|-------------|
| Enabled | 1 | Enable FSLogix |
| VHDLocations | `\\pauseisfslogix001.file.core.windows.net\fslogix-profiles` | Profile storage |
| SizeInMBs | 30720 | 30 GB max profile size |
| IsDynamic | 1 | Dynamic VHD (grows as needed) |
| VolumeType | VHDX | Use VHDX format |
| FlipFlopProfileDirectoryName | 1 | SID_Username format |
| DeleteLocalProfileWhenVHDShouldApply | 1 | Delete local profile |
| PreventLoginWithTempProfile | 1 | Block temp profiles |
| PreventLoginWithFailure | 0 | Allow login if FSLogix fails |

## Troubleshooting

### Check FSLogix Logs

```powershell
# On AVD session host
Get-Content "C:\ProgramData\FSLogix\Logs\Profile*.log" -Tail 50
```

### Verify FSLogix Services

```powershell
Get-Service -Name "frxsvc", "frxccds" | Format-Table Name, Status
```

### Test Storage Connectivity

```powershell
Test-NetConnection -ComputerName "pauseisfslogix001.file.core.windows.net" -Port 445
```

### Check Profile Container

```powershell
# After user login
Get-ChildItem "\\pauseisfslogix001.file.core.windows.net\fslogix-profiles"
```

## Authentication Options

### Azure AD Kerberos (Default - Recommended)

- No storage account key needed
- Users authenticated via Azure AD
- Requires RBAC assignment on file share

### Storage Account Key (Fallback)

If Azure AD Kerberos doesn't work:

```powershell
.\Deploy-FSLogix.ps1 -UseStorageKey
```

This stores the storage key in Windows Credential Manager.

## Cost Estimate

| Resource | SKU | Est. Monthly Cost |
|----------|-----|-------------------|
| Storage Account | Premium_LRS FileStorage | ~$0.16/GB/month |
| File Share (256 GB) | Premium | ~$41/month |

*Costs vary by region and usage*

## Support

For issues:
1. Check FSLogix logs on session hosts
2. Run validation script
3. Verify Azure AD group memberships
4. Check storage account firewall rules
