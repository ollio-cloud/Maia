# FSLogix Bicep Modules Documentation

## Overview

Modular Bicep architecture for FSLogix deployment with reusable components. This structure allows you to mix and match modules for different scenarios.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   main.bicep                         │
│              (Orchestrator Template)                 │
└──────────────────┬──────────────────────────────────┘
                   │
        ┌──────────┼──────────┬─────────┬─────────────┐
        │          │          │         │             │
        ▼          ▼          ▼         ▼             ▼
  ┌─────────┐ ┌──────────┐ ┌─────┐ ┌─────┐  ┌──────────────┐
  │Storage  │ │   File   │ │RBAC │ │RBAC │  │   FSLogix    │
  │Account  │ │  Share   │ │Users│ │Admns│  │  Extension   │
  │Module   │ │  Module  │ │ Mod │ │ Mod │  │    Module    │
  └─────────┘ └──────────┘ └─────┘ └─────┘  └──────────────┘
                                                  (Loop)
```

## Modules

### 1. storage-account.bicep

**Purpose**: Creates Premium FileStorage account with Azure AD Kerberos

**Parameters**:
| Name | Type | Default | Description |
|------|------|---------|-------------|
| storageAccountName | string | - | Storage account name |
| location | string | - | Azure region |
| sku | string | Premium_LRS | Storage SKU |
| enableAzureADKerberos | bool | true | Enable AD Kerberos |
| tenantId | string | '' | Azure AD tenant ID |
| tenantName | string | '' | Azure AD tenant name |
| tags | object | {} | Resource tags |

**Outputs**:
- `storageAccountId` - Resource ID
- `storageAccountName` - Account name
- `primaryFileEndpoint` - File endpoint URL
- `storageAccountKey` - Account key (secure)

**Example**:
```bicep
module storage 'modules/storage-account.bicep' = {
  name: 'deploy-storage'
  params: {
    storageAccountName: 'mystorageacct'
    location: 'australiasoutheast'
    sku: 'Premium_LRS'
    enableAzureADKerberos: true
    tenantId: 'xxxx-xxxx-xxxx-xxxx'
    tenantName: 'contoso.onmicrosoft.com'
  }
}
```

---

### 2. file-share.bicep

**Purpose**: Creates Azure Files share with soft delete

**Parameters**:
| Name | Type | Default | Description |
|------|------|---------|-------------|
| storageAccountName | string | - | Existing storage account |
| fileShareName | string | - | Share name |
| shareQuotaGB | int | - | Quota in GB (100-102400) |
| accessTier | string | Premium | Access tier |
| enableSoftDelete | bool | true | Enable soft delete |
| softDeleteRetentionDays | int | 7 | Retention days (1-365) |

**Outputs**:
- `fileShareId` - Resource ID
- `fileShareName` - Share name
- `fileShareUNC` - UNC path

**Example**:
```bicep
module share 'modules/file-share.bicep' = {
  name: 'deploy-share'
  params: {
    storageAccountName: storage.outputs.storageAccountName
    fileShareName: 'fslogix-profiles'
    shareQuotaGB: 256
    accessTier: 'Premium'
  }
  dependsOn: [storage]
}
```

---

### 3. rbac-assignment.bicep

**Purpose**: Assigns RBAC roles on file shares

**Parameters**:
| Name | Type | Default | Description |
|------|------|---------|-------------|
| storageAccountName | string | - | Storage account name |
| fileShareName | string | - | File share name |
| principalId | string | - | User/Group object ID |
| principalType | string | Group | Principal type |
| role | string | - | Role to assign |

**Allowed Roles**:
- `StorageFileDataSMBShareContributor` - Read/write access
- `StorageFileDataSMBShareElevatedContributor` - Full control
- `StorageFileDataSMBShareReader` - Read-only

**Outputs**:
- `roleAssignmentId` - Assignment ID
- `assignedRole` - Role name

**Example**:
```bicep
module rbac 'modules/rbac-assignment.bicep' = {
  name: 'assign-rbac'
  params: {
    storageAccountName: 'mystorageaccount'
    fileShareName: 'fslogix-profiles'
    principalId: 'xxxx-xxxx-xxxx-xxxx'
    principalType: 'Group'
    role: 'StorageFileDataSMBShareContributor'
  }
  dependsOn: [share]
}
```

---

### 4. fslogix-extension.bicep

**Purpose**: Installs and configures FSLogix on a single VM

**Parameters**:
| Name | Type | Default | Description |
|------|------|---------|-------------|
| vmName | string | - | VM to configure |
| location | string | - | Azure region |
| storageAccountName | string | - | FSLogix storage account |
| fileShareName | string | - | FSLogix file share |
| profileSizeMB | int | 30720 | Profile size (30GB) |
| enableOfficeContainer | bool | true | Office container |
| deleteLocalProfile | bool | true | Delete local profiles |
| preventTempProfile | bool | true | Block temp profiles |
| preventLoginOnFailure | bool | false | Block login if fails |
| useStorageKey | bool | false | Use storage key auth |
| storageAccountKey | securestring | '' | Storage key (if needed) |
| tags | object | {} | Resource tags |

**Outputs**:
- `provisioningState` - Extension state
- `vmName` - VM name

**Example**:
```bicep
module fslogix 'modules/fslogix-extension.bicep' = {
  name: 'config-vm-fslogix'
  params: {
    vmName: 'pauseisavd-0'
    location: 'australiasoutheast'
    storageAccountName: storage.outputs.storageAccountName
    fileShareName: share.outputs.fileShareName
    profileSizeMB: 30720
    enableOfficeContainer: true
  }
  dependsOn: [share, rbac]
}
```

---

## Orchestrator Template (main.bicep)

The main template orchestrates all modules in the correct order:

1. **Storage Account** (Module 1)
2. **File Share** (Module 2) - depends on storage
3. **RBAC Users** (Module 3) - depends on share
4. **RBAC Admins** (Module 4) - depends on share
5. **FSLogix Extensions** (Module 5) - loop for each VM, depends on all above

## Usage Patterns

### Pattern 1: Complete Deployment (Recommended)

Deploy everything at once:

```powershell
# Deploy with main.bicep
.\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName "p-ause-mb-rg-avd"
```

### Pattern 2: Incremental Deployment

Deploy modules separately:

```powershell
# 1. Deploy storage only
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file modules/storage-account.bicep \
    --parameters storageAccountName='pauseisfslogix001' location='australiasoutheast'

# 2. Deploy file share
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file modules/file-share.bicep \
    --parameters storageAccountName='pauseisfslogix001' fileShareName='fslogix-profiles'

# 3. Configure VMs
az deployment group create \
    --resource-group "p-ause-mb-rg-avd" \
    --template-file modules/fslogix-extension.bicep \
    --parameters vmName='pauseisavd-0' storageAccountName='pauseisfslogix001'
```

### Pattern 3: Reuse Modules in Other Templates

Reference modules from your own templates:

```bicep
// your-template.bicep
module fslogixStorage '../path/to/modules/storage-account.bicep' = {
  name: 'my-fslogix-storage'
  params: {
    storageAccountName: 'myaccount'
    location: resourceGroup().location
    sku: 'Premium_ZRS'  // Zone-redundant
  }
}
```

## Testing

### What-If Analysis

Preview changes before deployment:

```powershell
# Run What-If test
.\Test-FSLogixDeployment.ps1 -ResourceGroupName "p-ause-mb-rg-avd"

# Detailed analysis
.\Test-FSLogixDeployment.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -Detailed
```

### Validation

After deployment, validate:

```powershell
# From parent directory
..\Validate-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd"
```

## Module Benefits

| Benefit | Description |
|---------|-------------|
| **Reusability** | Use modules in multiple projects |
| **Testability** | Test individual components |
| **Maintainability** | Update one module affects all consumers |
| **Composition** | Mix and match for different scenarios |
| **Single Responsibility** | Each module does one thing well |

## Customization Examples

### Add Additional VMs Later

```bicep
// add-vm.bicep
param existingStorageAccount string
param existingFileShare string
param newVMName string

module fslogix '../modules/fslogix-extension.bicep' = {
  name: 'add-${newVMName}'
  params: {
    vmName: newVMName
    storageAccountName: existingStorageAccount
    fileShareName: existingFileShare
    // ... other params
  }
}
```

### Create Multiple File Shares

```bicep
// multi-share.bicep
param storageAccountName string

module userProfiles '../modules/file-share.bicep' = {
  name: 'users-share'
  params: {
    storageAccountName: storageAccountName
    fileShareName: 'user-profiles'
    shareQuotaGB: 256
  }
}

module officeData '../modules/file-share.bicep' = {
  name: 'office-share'
  params: {
    storageAccountName: storageAccountName
    fileShareName: 'office-data'
    shareQuotaGB: 128
  }
}
```

### Zone-Redundant Storage

```bicep
// Use Premium_ZRS for zone redundancy
module storage '../modules/storage-account.bicep' = {
  name: 'zrs-storage'
  params: {
    storageAccountName: 'zrsstorage'
    location: 'australiasoutheast'
    sku: 'Premium_ZRS'  // Zone-redundant
  }
}
```

## Best Practices

1. **Version Your Modules** - Use git tags for module versions
2. **Document Parameters** - Use `@description` decorators
3. **Validate Inputs** - Use `@minValue`, `@maxValue`, `@allowed`
4. **Use Secure Params** - Mark sensitive data with `@secure()`
5. **Test Before Deploy** - Always run What-If first
6. **Tag Resources** - Include environment, owner, cost center
7. **Use Parameter Files** - Don't hardcode values in templates

## Troubleshooting

### Module Not Found Error

```
Error: Unable to load module from 'modules/storage-account.bicep'
```

**Solution**: Ensure relative paths are correct from the calling template.

### Circular Dependency

```
Error: Circular dependency detected
```

**Solution**: Check `dependsOn` declarations. Modules should form a DAG (directed acyclic graph).

### RBAC Scope Error

```
Error: Invalid scope for role assignment
```

**Solution**: Ensure file share is created before assigning RBAC. Use `dependsOn`.

## Support

For issues:
1. Check module documentation
2. Review test script output
3. Run What-If analysis
4. Validate parameter values
