# FSLogix Bicep Templates for Azure Virtual Desktop

## Overview

Bicep templates for automated deployment of FSLogix profile containers for Azure AD joined AVD environments. These provide the same functionality as the ARM templates but with cleaner, more maintainable syntax.

## Environment Configuration

| Parameter | Value |
|-----------|-------|
| Resource Group | `p-ause-mb-rg-avd` |
| Location | `australiasoutheast` |
| Storage Account | `pauseisfslogix001` |
| File Share | `fslogix-profiles` |
| Host Pool | `pauseisavdpool01` |
| Session Hosts | `pauseisavd-0`, `pauseisavd-1` |

## Files

```
bicep/
├── Monolithic Templates
│   ├── fslogix-storage.bicep           # Storage only
│   ├── fslogix-storage.bicepparam
│   ├── fslogix-vm-extension.bicep      # VM extension only
│   ├── fslogix-vm-extension.bicepparam
│   ├── fslogix-complete.bicep          # Combined
│   └── fslogix-complete.bicepparam
│
├── Modular Architecture ⭐ RECOMMENDED
│   ├── main.bicep                      # Orchestrator
│   ├── main.bicepparam
│   └── modules/
│       ├── storage-account.bicep       # Reusable modules
│       ├── file-share.bicep
│       ├── rbac-assignment.bicep
│       └── fslogix-extension.bicep
│
├── Scripts
│   ├── Deploy-FSLogix-Bicep.ps1
│   └── Test-FSLogixDeployment.ps1      # What-If testing
│
└── Documentation
    ├── README.md
    └── MODULES.md                       # Module documentation
```

## Quick Start

### Modular Deployment (Recommended)

```powershell
# Test first with What-If
.\Test-FSLogixDeployment.ps1 -ResourceGroupName "p-ause-mb-rg-avd"

# Deploy
New-AzResourceGroupDeployment `
    -ResourceGroupName "p-ause-mb-rg-avd" `
    -TemplateFile "main.bicep" `
    -TemplateParameterFile "main.bicepparam"
```

### Option 1: PowerShell Script

```powershell
# Complete deployment (storage + VMs)
.\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName "p-ause-mb-rg-avd"

# Storage only
.\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -DeploymentMode "StorageOnly"

# VM configuration only
.\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -DeploymentMode "VMOnly"

# What-If analysis (preview changes)
.\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -WhatIf
```

### Option 2: Azure CLI

```bash
# Deploy complete template
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file fslogix-complete.bicep \
    --parameters fslogix-complete.bicepparam

# With inline parameters
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file fslogix-complete.bicep \
    --parameters storageAccountName='pauseisfslogix001' \
                 vmNames='["pauseisavd-0","pauseisavd-1"]'
```

### Option 3: Azure PowerShell

```powershell
New-AzResourceGroupDeployment `
    -ResourceGroupName "p-ause-mb-rg-avd" `
    -TemplateFile "fslogix-complete.bicep" `
    -TemplateParameterFile "fslogix-complete.bicepparam"
```

## Pre-Deployment: Update Parameters

Edit `fslogix-complete.bicepparam` with your values:

```bicep
// Get these values before deployment:

// 1. Tenant ID
param azureADTenantId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
// PowerShell: (Get-AzContext).Tenant.Id

// 2. Tenant Name
param azureADTenantName = 'contoso.onmicrosoft.com'
// PowerShell: (Get-AzTenant).DefaultDomain

// 3. AVD Users Group Object ID
param avdUsersGroupObjectId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
// PowerShell: (Get-AzADGroup -DisplayName "AVD-Users").Id

// 4. AVD Admins Group Object ID
param avdAdminsGroupObjectId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
// PowerShell: (Get-AzADGroup -DisplayName "AVD-Admins").Id
```

## Template Details

### fslogix-storage.bicep

Creates:
- ✅ Premium FileStorage account
- ✅ Azure Files share (256 GB)
- ✅ Azure AD Kerberos authentication
- ✅ RBAC role assignments
- ✅ Soft delete enabled (7 days)

### fslogix-vm-extension.bicep

Configures:
- ✅ Downloads FSLogix agent
- ✅ Installs FSLogix silently
- ✅ Configures Profile Container
- ✅ Configures Office Container
- ✅ Sets all registry keys

### fslogix-complete.bicep

Combined template that deploys everything in sequence:
1. Storage account
2. File share with RBAC
3. VM extensions for FSLogix

## FSLogix Settings Applied

| Setting | Value | Purpose |
|---------|-------|---------|
| `Enabled` | 1 | Enable FSLogix |
| `VHDLocations` | `\\pauseisfslogix001.file.core.windows.net\fslogix-profiles` | Profile storage |
| `SizeInMBs` | 30720 | 30 GB max profile |
| `IsDynamic` | 1 | Dynamic VHD |
| `VolumeType` | VHDX | VHDX format |
| `FlipFlopProfileDirectoryName` | 1 | SID_Username format |
| `DeleteLocalProfileWhenVHDShouldApply` | 1 | Remove local profile |
| `PreventLoginWithTempProfile` | 1 | Block temp profiles |
| `PreventLoginWithFailure` | 0 | Allow login if fails |
| `AccessNetworkAsComputerObject` | 1 | Azure AD Kerberos support |

## Bicep vs ARM Comparison

| Feature | ARM JSON | Bicep |
|---------|----------|-------|
| File size | ~500 lines | ~200 lines |
| Readability | Complex | Clean |
| Type safety | Limited | Strong |
| IntelliSense | Basic | Full |
| Modules | Linked templates | Native modules |
| Parameters | Separate JSON | .bicepparam |

## Compile to ARM (Optional)

If you need ARM JSON output:

```bash
# Compile Bicep to ARM
az bicep build --file fslogix-complete.bicep

# Output: fslogix-complete.json
```

## Troubleshooting

### Bicep CLI Not Found

```powershell
# Install Bicep CLI
az bicep install

# Or via winget
winget install Microsoft.Bicep
```

### Parameter File Errors

Ensure `.bicepparam` file references correct template:
```bicep
using 'fslogix-complete.bicep'  // Must match template name
```

### Deployment Failures

```powershell
# Check deployment status
Get-AzResourceGroupDeployment -ResourceGroupName "p-ause-mb-rg-avd" |
    Select-Object DeploymentName, ProvisioningState, Timestamp

# Get detailed error
Get-AzResourceGroupDeploymentOperation -ResourceGroupName "p-ause-mb-rg-avd" -DeploymentName "fslogix-xxx" |
    Where-Object { $_.Properties.ProvisioningState -eq "Failed" }
```

## Validation

After deployment:

```powershell
# From parent directory
..\Validate-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd"
```

## Cost Estimate

| Resource | SKU | Est. Monthly Cost |
|----------|-----|-------------------|
| Storage Account | Premium_LRS FileStorage | ~$0.16/GB/month |
| File Share (256 GB) | Premium | ~$41/month |
