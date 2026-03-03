# FSLogix Deployment Guide - Complete Reference

## 📋 Table of Contents

1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Testing with What-If](#testing-with-what-if)
5. [Deployment Options](#deployment-options)
6. [Post-Deployment Validation](#post-deployment-validation)
7. [Troubleshooting](#troubleshooting)

---

## Overview

This deployment package provides **both ARM and Bicep templates** for FSLogix on Azure Virtual Desktop:

- **ARM Templates** (JSON) - Traditional approach
- **Bicep Templates** - Modern, cleaner syntax
  - Monolithic templates (all-in-one)
  - **Modular templates** (reusable components) ⭐ **RECOMMENDED**

### Your Environment

| Parameter | Value |
|-----------|-------|
| Resource Group | `p-ause-mb-rg-avd` |
| Location | `australiasoutheast` |
| Storage Account | `pauseisfslogix001` |
| File Share | `fslogix-profiles` (256 GB) |
| Host Pool | `pauseisavdpool01` |
| Session Hosts | `pauseisavd-0`, `pauseisavd-1` |
| Profile Count | 12 users (2-25 GB each) |

---

## File Structure

```
claude/templates/avd/
│
├── ARM Templates (JSON)
│   ├── fslogix-storage.json
│   ├── fslogix-vm-extension.json
│   ├── fslogix-complete.json
│   ├── Deploy-FSLogix.ps1
│   ├── Validate-FSLogix.ps1
│   ├── README.md
│   └── parameters/
│       ├── fslogix-storage.parameters.json
│       ├── fslogix-vm-extension.parameters.json
│       └── fslogix-complete.parameters.json
│
├── Bicep Templates
│   └── bicep/
│       ├── Monolithic
│       │   ├── fslogix-storage.bicep
│       │   ├── fslogix-vm-extension.bicep
│       │   └── fslogix-complete.bicep
│       │
│       ├── Modular ⭐ RECOMMENDED
│       │   ├── main.bicep
│       │   ├── main.bicepparam
│       │   └── modules/
│       │       ├── storage-account.bicep
│       │       ├── file-share.bicep
│       │       ├── rbac-assignment.bicep
│       │       └── fslogix-extension.bicep
│       │
│       ├── Scripts
│       │   ├── Deploy-FSLogix-Bicep.ps1
│       │   └── Test-FSLogixDeployment.ps1
│       │
│       └── Documentation
│           ├── README.md
│           └── MODULES.md
│
└── DEPLOYMENT_GUIDE.md (this file)
```

---

## Pre-Deployment Checklist

### Step 1: Gather Required Information

Run these PowerShell commands to get the values you need:

```powershell
# Connect to Azure
Connect-AzAccount

# 1. Tenant ID
$tenantId = (Get-AzContext).Tenant.Id
Write-Host "Tenant ID: $tenantId"

# 2. Tenant Name
$tenantName = (Get-AzTenant -TenantId $tenantId).DefaultDomain
Write-Host "Tenant Name: $tenantName"

# 3. AVD Users Group Object ID
$avdUsersGroup = Get-AzADGroup -DisplayName "AVD-Users"
Write-Host "AVD Users Group ID: $($avdUsersGroup.Id)"

# 4. AVD Admins Group Object ID
$avdAdminsGroup = Get-AzADGroup -DisplayName "AVD-Admins"
Write-Host "AVD Admins Group ID: $($avdAdminsGroup.Id)"
```

### Step 2: Update Parameter File

**For Bicep** (edit `bicep/main.bicepparam`):

```bicep
param azureADTenantId = 'PASTE_TENANT_ID_HERE'
param azureADTenantName = 'PASTE_TENANT_NAME_HERE'
param avdUsersGroupObjectId = 'PASTE_AVD_USERS_GROUP_ID'
param avdAdminsGroupObjectId = 'PASTE_AVD_ADMINS_GROUP_ID'
```

**For ARM** (edit `parameters/fslogix-complete.parameters.json`):

```json
"azureADTenantId": {
  "value": "PASTE_TENANT_ID_HERE"
},
"azureADTenantName": {
  "value": "PASTE_TENANT_NAME_HERE"
}
```

### Step 3: Verify Resource Group Exists

```powershell
Get-AzResourceGroup -Name "p-ause-mb-rg-avd"
```

If not exists, create it:
```powershell
New-AzResourceGroup -Name "p-ause-mb-rg-avd" -Location "australiasoutheast"
```

---

## Testing with What-If

⚠️ **ALWAYS test before deploying to production!**

### Bicep What-If (Recommended)

```powershell
cd c:\Users\olli.ojala\maia\claude\templates\avd\bicep

# Run What-If test
.\Test-FSLogixDeployment.ps1 -ResourceGroupName "p-ause-mb-rg-avd"

# Detailed analysis
.\Test-FSLogixDeployment.ps1 -ResourceGroupName "p-ause-mb-rg-avd" -Detailed
```

### ARM What-If

```powershell
cd c:\Users\olli.ojala\maia\claude\templates\avd

New-AzResourceGroupDeployment `
    -ResourceGroupName "p-ause-mb-rg-avd" `
    -TemplateFile "fslogix-complete.json" `
    -TemplateParameterFile "parameters/fslogix-complete.parameters.json" `
    -WhatIf
```

### What to Look For

The What-If output will show:
- ✅ **Resources to CREATE** (green) - New resources
- ⚠️ **Resources to MODIFY** (yellow) - Existing resources that will change
- 🚨 **Resources to DELETE** (red) - Resources that will be removed

**Expected output for new deployment**:
- **CREATE** (6 resources):
  - Storage account
  - File services
  - File share
  - 2x RBAC role assignments
  - 2x VM extensions

---

## Deployment Options

### Option A: Modular Bicep (Recommended) ⭐

**Advantages**:
- Reusable modules
- Easier to maintain
- Can deploy components separately
- Best practice architecture

```powershell
cd c:\Users\olli.ojala\maia\claude\templates\avd\bicep

# Deploy
New-AzResourceGroupDeployment `
    -ResourceGroupName "p-ause-mb-rg-avd" `
    -TemplateFile "main.bicep" `
    -TemplateParameterFile "main.bicepparam" `
    -Verbose
```

### Option B: Monolithic Bicep

```powershell
cd c:\Users\olli.ojala\maia\claude\templates\avd\bicep

.\Deploy-FSLogix-Bicep.ps1 -ResourceGroupName "p-ause-mb-rg-avd"
```

### Option C: ARM Templates

```powershell
cd c:\Users\olli.ojala\maia\claude\templates\avd

.\Deploy-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd" `
                     -VMNames @("pauseisavd-0", "pauseisavd-1")
```

### Deployment Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| **What-If** | 30-60 sec | Preview changes |
| **Storage** | 2-3 min | Create storage account + share |
| **RBAC** | 1 min | Assign permissions |
| **VM Extensions** | 5-10 min per VM | Install FSLogix |
| **Total** | ~15-20 min | For 2 VMs |

---

## Post-Deployment Validation

### Step 1: Run Validation Script

```powershell
cd c:\Users\olli.ojala\maia\claude\templates\avd

.\Validate-FSLogix.ps1 -ResourceGroupName "p-ause-mb-rg-avd" `
                       -StorageAccountName "pauseisfslogix001" `
                       -VMNames @("pauseisavd-0", "pauseisavd-1")
```

### Step 2: Manual Checks

**Check Storage Account**:
```powershell
Get-AzStorageAccount -ResourceGroupName "p-ause-mb-rg-avd" -Name "pauseisfslogix001"
```

**Check File Share**:
```powershell
$ctx = (Get-AzStorageAccount -ResourceGroupName "p-ause-mb-rg-avd" -Name "pauseisfslogix001").Context
Get-AzStorageShare -Name "fslogix-profiles" -Context $ctx
```

**Check VM Extensions**:
```powershell
Get-AzVMExtension -ResourceGroupName "p-ause-mb-rg-avd" -VMName "pauseisavd-0" -Name "FSLogixConfig"
```

### Step 3: Test User Login

1. Have a test user log into AVD
2. Verify FSLogix profile is created:
   ```powershell
   # Check from Azure Cloud Shell or VM
   Get-ChildItem "\\pauseisfslogix001.file.core.windows.net\fslogix-profiles"
   ```
3. Expected: Folder named `{SID}_{Username}`
4. Inside folder: `Profile_{Username}.vhdx`

### Step 4: Check FSLogix Logs on VM

RDP to a session host and check:
```powershell
Get-Content "C:\ProgramData\FSLogix\Logs\Profile*.log" -Tail 50
```

Look for:
- ✅ "Profile loaded successfully"
- ✅ "VHD mounted"
- ❌ Any errors or warnings

---

## Troubleshooting

### Issue 1: Storage Account Key Error

**Symptom**: "Access denied to file share"

**Solution**: Verify Azure AD Kerberos is enabled OR add storage key:

```powershell
# Check Kerberos status
$storage = Get-AzStorageAccount -ResourceGroupName "p-ause-mb-rg-avd" -Name "pauseisfslogix001"
$storage.AzureFilesIdentityBasedAuthentication.DirectoryServiceOptions

# If not "AADKERB", redeploy with useStorageKey = true
```

### Issue 2: VM Extension Failed

**Symptom**: Extension shows "Failed" status

**Solution**: Check extension logs:

```powershell
# Get extension details
$ext = Get-AzVMExtension -ResourceGroupName "p-ause-mb-rg-avd" -VMName "pauseisavd-0" -Name "FSLogixConfig"
$ext.SubstatusMessage

# Re-run extension
Remove-AzVMExtension -ResourceGroupName "p-ause-mb-rg-avd" -VMName "pauseisavd-0" -Name "FSLogixConfig" -Force

# Then redeploy
```

### Issue 3: Profile Not Created

**Symptom**: User logs in but no VHDX created

**Checklist**:
1. FSLogix service running? `Get-Service frxsvc`
2. Registry settings correct? `Get-ItemProperty HKLM:\SOFTWARE\FSLogix\Profiles`
3. User in RBAC group? `Get-AzRoleAssignment -Scope <FileShareId>`
4. Network connectivity? `Test-NetConnection pauseisfslogix001.file.core.windows.net -Port 445`

### Issue 4: Temp Profile Warning

**Symptom**: User gets temp profile message

**Solution**:
```powershell
# On VM, check FSLogix logs
Get-Content "C:\ProgramData\FSLogix\Logs\Profile*.log" | Select-String "ERROR"

# Common causes:
# - Share not accessible (firewall/NSG)
# - RBAC permissions missing
# - Storage account key incorrect (if using keys)
```

### Getting Help

1. Review logs: `C:\ProgramData\FSLogix\Logs\`
2. Check What-If output for unexpected changes
3. Verify all parameters are correct
4. Check RBAC assignments on file share
5. Validate network connectivity to storage account

---

## Next Steps After Deployment

### 1. Migrate Existing Profiles

See [Profile Migration Guide](../README.md#phase-5-migrate-12-local-profiles-to-fslogix)

### 2. Monitor FSLogix Health

Set up alerts for:
- Storage capacity (alert at 80%)
- FSLogix service failures
- Failed profile loads

### 3. Configure Backup

```powershell
# Enable Azure Backup for file share
# (Manual step - not in template)
```

### 4. Document Configuration

- File share UNC path
- Storage account key location (if using)
- RBAC group memberships
- VM configuration details

---

## Cost Summary

| Resource | Quantity | Unit Cost | Monthly Cost |
|----------|----------|-----------|--------------|
| Storage Account | 1 | - | Base cost |
| Premium File Share | 256 GB | ~$0.16/GB | ~$41 |
| **Total** | | | **~$41/month** |

*Plus VM costs (VMs already exist)*

---

## Support Resources

- **ARM Templates**: `claude/templates/avd/README.md`
- **Bicep Templates**: `claude/templates/avd/bicep/README.md`
- **Module Documentation**: `claude/templates/avd/bicep/MODULES.md`
- **Validation Script**: `claude/templates/avd/Validate-FSLogix.ps1`
