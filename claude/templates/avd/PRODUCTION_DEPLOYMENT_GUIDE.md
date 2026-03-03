# AVD Production Deployment Guide
## FSLogix Migration with Azure AD Kerberos Authentication

**Environment**: Production - pauseisavdpool01
**Resource Group**: p-ause-mb-rg-avd
**Date**: January 2026
**Authentication**: Azure AD Kerberos

---

## Overview

This guide covers the phased deployment of:
1. **Phase 1**: Deploy new session host `pauseisavd-1` (without FSLogix) - *Can be done anytime*
2. **Phase 2**: Deploy FSLogix storage with Azure AD Kerberos - *Maintenance window recommended*
3. **Phase 3**: Configure FSLogix on both hosts and migrate profiles - *Maintenance window required*

### Current State
| Resource | Status |
|----------|--------|
| `pauseisavd-0` | Running, Azure AD joined, no FSLogix |
| `pauseisavd-1` | Not deployed |
| FSLogix Storage | Not deployed |
| Users | 18 users, profiles 1-22GB each |

### Target State
| Resource | Status |
|----------|--------|
| `pauseisavd-0` | Running with FSLogix (Azure AD Kerberos) |
| `pauseisavd-1` | Running with FSLogix (Azure AD Kerberos) |
| FSLogix Storage | `pauseisfslogix001` with Kerberos auth |

### Authentication Method: Azure AD Kerberos

**Benefits over Storage Account Key:**
- No credentials stored on VMs
- Uses Azure AD identity for authentication
- Automatic Kerberos ticket management
- More secure - no key rotation required
- Supports Conditional Access policies

**Requirements:**
- Azure AD joined VMs (already in place)
- Users synced to Azure AD
- RBAC roles on file share

---

## Phase 1: Deploy New Session Host (No Downtime)

**Impact**: None - existing users unaffected
**Duration**: ~20-25 minutes
**Can be done**: Anytime (business hours OK)

### Prerequisites
- Azure CLI logged into Production subscription
- Admin password for new VM
- Host pool registration token

### Step 1.0: Create Snapshot of pauseisavd-0 (Backup)

Before making any changes, create a snapshot of the existing session host for rollback purposes:

```bash
# Get the OS disk name for pauseisavd-0
OS_DISK=$(az vm show --resource-group p-ause-mb-rg-avd --name pauseisavd-0 --query "storageProfile.osDisk.name" -o tsv)

# Create a snapshot
az snapshot create \
  --resource-group p-ause-mb-rg-avd \
  --name "pauseisavd-0-snapshot-$(date +%Y%m%d)" \
  --source "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Compute/disks/$OS_DISK" \
  --tags Environment=Production Purpose=Pre-Migration-Backup CreatedDate=$(date +%Y-%m-%d)
```

**Windows PowerShell alternative:**
```powershell
$osDisk = az vm show --resource-group p-ause-mb-rg-avd --name pauseisavd-0 --query "storageProfile.osDisk.name" -o tsv
$snapshotName = "pauseisavd-0-snapshot-$(Get-Date -Format 'yyyyMMdd')"
az snapshot create `
  --resource-group p-ause-mb-rg-avd `
  --name $snapshotName `
  --source "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Compute/disks/$osDisk" `
  --tags Environment=Production Purpose=Pre-Migration-Backup CreatedDate=$(Get-Date -Format 'yyyy-MM-dd')
```

> **Note**: Keep this snapshot until migration is verified successful (recommend 7-14 days).

### Step 1.1: Generate Host Pool Registration Token

```bash
# Generate a new registration token (valid for 24 hours)
az rest --method POST \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/registrationTokens?api-version=2024-04-03" \
  --body '{"properties":{"expirationTime":"'$(date -u -d "+24 hours" +%Y-%m-%dT%H:%M:%SZ)'"}}' \
  --query "properties.token" -o tsv
```

**Windows PowerShell alternative:**
```powershell
$expiry = (Get-Date).AddHours(24).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
az rest --method POST `
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/registrationTokens?api-version=2024-04-03" `
  --body "{`"properties`":{`"expirationTime`":`"$expiry`"}}" `
  --query "properties.token" -o tsv
```

Save the token output - you'll need it for deployment.

### Step 1.2: Deploy Session Host VM

> **Availability Zone Strategy**: Deploy `pauseisavd-1` in **Zone 2** for high availability. The existing host `pauseisavd-0` is in Zone 1. This provides resilience against single-zone failures.

```bash
cd claude/templates/avd/bicep

az deployment group create \
  --resource-group p-ause-mb-rg-avd \
  --template-file avd-session-host-deploy.bicep \
  --parameters vmName='pauseisavd-1' \
               location='australiasoutheast' \
               vmSize='Standard_E8s_v5' \
               availabilityZone='2' \
               adminUsername='avdadmin' \
               adminPassword='<YOUR_SECURE_PASSWORD>' \
               subnetId='/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-workloads/providers/Microsoft.Network/virtualNetworks/p-ause-mb-vn-workloads/subnets/App' \
               hostPoolName='pauseisavdpool01' \
               hostPoolToken='<TOKEN_FROM_STEP_1>' \
               enableFSLogix=false \
  --name "deploy-pauseisavd-1-$(date +%Y%m%d%H%M)"
```

| Session Host | Availability Zone | Purpose |
|--------------|-------------------|---------|
| pauseisavd-0 | Zone 1 | Existing host |
| pauseisavd-1 | Zone 2 | New host (HA) |

### Step 1.3: Disable New Sessions on pauseisavd-1

Immediately after deployment completes, disable new sessions so users can't connect until FSLogix is ready:

```bash
# Disable new sessions on the new host
az rest --method PATCH \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts/pauseisavd-1?api-version=2024-04-03" \
  --body '{"properties":{"allowNewSession":false}}'
```

### Step 1.4: Verify Deployment

```bash
# Check both session hosts
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts?api-version=2024-04-03" \
  --query "value[].{name:name, status:properties.status, allowNewSession:properties.allowNewSession}" -o table
```

**Expected output:**
```
Name                            Status     AllowNewSession
------------------------------  ---------  ---------------
pauseisavdpool01/pauseisavd-0   Available  True
pauseisavdpool01/pauseisavd-1   Available  False
```

### Step 1.5: Add Virtual Machine User Login Role

```bash
# Assign Virtual Machine User Login role to AVD users (replace with your user/group)
az role assignment create \
  --assignee "<YOUR_USER_OR_GROUP_OBJECT_ID>" \
  --role "Virtual Machine User Login" \
  --scope "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Compute/virtualMachines/pauseisavd-1"
```

---

## Phase 2: Deploy FSLogix Storage with Azure AD Kerberos

**Impact**: None yet - storage only
**Duration**: ~15-20 minutes
**Maintenance Window**: Recommended before Phase 3

### Step 2.0: Enable Service Endpoint on Subnet (Prerequisites)

Before deploying the storage account with network restrictions, ensure the subnet has the `Microsoft.Storage` service endpoint enabled:

```bash
# Check current service endpoints on the subnet
az network vnet subnet show \
  --resource-group p-ause-mb-rg-workloads \
  --vnet-name p-ause-mb-vn-workloads \
  --name App \
  --query "serviceEndpoints[].service" -o table

# If Microsoft.Storage is not listed, add it
az network vnet subnet update \
  --resource-group p-ause-mb-rg-workloads \
  --vnet-name p-ause-mb-vn-workloads \
  --name App \
  --service-endpoints Microsoft.Storage
```

> **Note**: Adding a service endpoint may cause a brief connectivity interruption to VMs in the subnet (typically a few seconds).

### Step 2.1: Deploy FSLogix Storage Account with Kerberos

```bash
cd claude/templates/avd/bicep

az deployment group create \
  --resource-group p-ause-mb-rg-avd \
  --template-file modules/storage-account.bicep \
  --parameters storageAccountName='pauseisfslogix001' \
               location='australiasoutheast' \
               sku='Premium_LRS' \
               enableAzureADKerberos=true \
               tenantId='713ee28e-f3d7-4395-ae77-687d5014c757' \
               tenantName='albiimports.onmicrosoft.com' \
               enableNetworkRestrictions=true \
               allowedSubnetId='/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-workloads/providers/Microsoft.Network/virtualNetworks/p-ause-mb-vn-workloads/subnets/App' \
               tags='{"Environment":"Production","Application":"AVD","Component":"FSLogix","Authentication":"AzureADKerberos"}' \
  --name "deploy-fslogix-storage-$(date +%Y%m%d%H%M)"
```

> **Security**: The storage account is now restricted to only allow access from the AVD subnet. Public internet access is denied.

### Step 2.2: Create File Share

```bash
az deployment group create \
  --resource-group p-ause-mb-rg-avd \
  --template-file modules/file-share.bicep \
  --parameters storageAccountName='pauseisfslogix001' \
               fileShareName='fslogix-profiles' \
               shareQuotaGB=256 \
               accessTier='Premium' \
               enableSoftDelete=true \
               softDeleteRetentionDays=7 \
  --name "deploy-fslogix-share-$(date +%Y%m%d%H%M)"
```

### Step 2.3: Configure RBAC for Azure AD Kerberos (REQUIRED)

For Azure AD Kerberos, RBAC permissions are **mandatory**.

**Security Groups:**
| Group | Purpose |
|-------|---------|
| `Security - AVD Pool 01 Users` | Standard AVD users |
| `Security - AVD Pool 01 Admins` | AVD administrators |

First, get the Object IDs for these groups:

```bash
# Get Object ID for Security - AVD Pool 01 Users
az ad group show --group "Security - AVD Pool 01 Users" --query "id" -o tsv

# Get Object ID for Security - AVD Pool 01 Admins
az ad group show --group "Security - AVD Pool 01 Admins" --query "id" -o tsv
```

Then assign the RBAC roles:

```bash
# ============================================================================
# Storage Account RBAC (for FSLogix/Kerberos)
# ============================================================================

# For "Security - AVD Pool 01 Users" - Storage File Data SMB Share Contributor
az role assignment create \
  --assignee "<AVD_POOL_01_USERS_OBJECT_ID>" \
  --role "Storage File Data SMB Share Contributor" \
  --scope "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Storage/storageAccounts/pauseisfslogix001"

# For "Security - AVD Pool 01 Admins" - Storage File Data SMB Share Elevated Contributor
az role assignment create \
  --assignee "<AVD_POOL_01_ADMINS_OBJECT_ID>" \
  --role "Storage File Data SMB Share Elevated Contributor" \
  --scope "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Storage/storageAccounts/pauseisfslogix001"

# ============================================================================
# VM RBAC (for Azure AD login to session hosts)
# ============================================================================

# For "Security - AVD Pool 01 Users" - Virtual Machine User Login (on both VMs)
az role assignment create \
  --assignee "<AVD_POOL_01_USERS_OBJECT_ID>" \
  --role "Virtual Machine User Login" \
  --scope "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Compute/virtualMachines/pauseisavd-0"

az role assignment create \
  --assignee "<AVD_POOL_01_USERS_OBJECT_ID>" \
  --role "Virtual Machine User Login" \
  --scope "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Compute/virtualMachines/pauseisavd-1"

# For "Security - AVD Pool 01 Admins" - Virtual Machine Administrator Login (on both VMs)
az role assignment create \
  --assignee "<AVD_POOL_01_ADMINS_OBJECT_ID>" \
  --role "Virtual Machine Administrator Login" \
  --scope "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Compute/virtualMachines/pauseisavd-0"

az role assignment create \
  --assignee "<AVD_POOL_01_ADMINS_OBJECT_ID>" \
  --role "Virtual Machine Administrator Login" \
  --scope "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Compute/virtualMachines/pauseisavd-1"
```

**Summary of RBAC Assignments:**

| Group | Storage Account Role | VM Role |
|-------|---------------------|---------|
| Security - AVD Pool 01 Users | Storage File Data SMB Share Contributor | Virtual Machine User Login |
| Security - AVD Pool 01 Admins | Storage File Data SMB Share Elevated Contributor | Virtual Machine Administrator Login |

### Step 2.4: Configure NTFS Permissions on File Share

After RBAC is configured, set the NTFS permissions on the file share. This must be done from a session host that has access to the share.

**Connect to pauseisavd-0 and run:**

```powershell
# ============================================================================
# Configure NTFS Permissions for FSLogix File Share
# Run as Administrator on a session host
# ============================================================================

$StorageAccount = "pauseisfslogix001"
$FileShare = "fslogix-profiles"
$SharePath = "\\$StorageAccount.file.core.windows.net\$FileShare"

# Mount the share (should work via Kerberos without credentials)
Write-Host "Mounting file share..." -ForegroundColor Cyan
if (!(Test-Path $SharePath)) {
    Write-Host "ERROR: Cannot access file share. Verify RBAC permissions." -ForegroundColor Red
    exit 1
}

# Get the current ACL
$acl = Get-Acl $SharePath

# Define the recommended FSLogix NTFS permissions
# Reference: https://learn.microsoft.com/en-us/fslogix/how-to-configure-storage-permissions

Write-Host "Configuring NTFS permissions..." -ForegroundColor Cyan

# 1. CREATOR OWNER - Full Control (Subfolders and Files only)
$creatorOwner = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "CREATOR OWNER",
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "InheritOnly",
    "Allow"
)
$acl.AddAccessRule($creatorOwner)

# 2. Security - AVD Pool 01 Admins - Full Control (This folder, subfolders, and files)
# Replace with your actual admin group name or SID
$adminsGroup = "Security - AVD Pool 01 Admins"
try {
    $admins = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $adminsGroup,
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $acl.AddAccessRule($admins)
    Write-Host "  Added: $adminsGroup - Full Control" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: Could not add $adminsGroup - may need to use SID" -ForegroundColor Yellow
}

# 3. Security - AVD Pool 01 Users - Modify (This folder only)
# This allows users to create their profile folder
$usersGroup = "Security - AVD Pool 01 Users"
try {
    $users = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $usersGroup,
        "Modify",
        "None",
        "None",
        "Allow"
    )
    $acl.AddAccessRule($users)
    Write-Host "  Added: $usersGroup - Modify (This folder only)" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: Could not add $usersGroup - may need to use SID" -ForegroundColor Yellow
}

# Apply the ACL
Set-Acl -Path $SharePath -AclObject $acl
Write-Host "NTFS permissions configured successfully!" -ForegroundColor Green

# Verify permissions
Write-Host "`nCurrent permissions:" -ForegroundColor Cyan
(Get-Acl $SharePath).Access | Format-Table IdentityReference, FileSystemRights, InheritanceFlags -AutoSize
```

**Expected NTFS Permission Structure:**

| Principal | Permission | Applies To |
|-----------|------------|------------|
| CREATOR OWNER | Full Control | Subfolders and Files |
| Security - AVD Pool 01 Admins | Full Control | This folder, Subfolders, Files |
| Security - AVD Pool 01 Users | Modify | This folder only |

> **Why these permissions?**
> - Users can create their profile folder (Modify on root)
> - CREATOR OWNER ensures users have full control of their own profile
> - Admins can manage all profiles for troubleshooting

### Step 2.5: Verify Azure AD Kerberos Configuration

```bash
# Check storage account authentication settings
az storage account show \
  --resource-group p-ause-mb-rg-avd \
  --name pauseisfslogix001 \
  --query "azureFilesIdentityBasedAuthentication" -o json
```

**Expected output:**
```json
{
  "activeDirectoryProperties": {
    "domainGuid": "713ee28e-f3d7-4395-ae77-687d5014c757",
    "domainName": "albiimports.onmicrosoft.com"
  },
  "directoryServiceOptions": "AADKERB"
}
```

### Step 2.5: Test Kerberos Authentication (Optional)

You can test from an existing Azure AD joined VM:

```powershell
# On pauseisavd-0, test connectivity
$StorageAccount = "pauseisfslogix001"
$FileShare = "fslogix-profiles"

# This should work WITHOUT providing credentials (uses Kerberos)
Test-Path "\\$StorageAccount.file.core.windows.net\$FileShare"

# If it fails, check Kerberos ticket
klist
```

---

## Phase 3: Configure FSLogix & Migrate Profiles (Maintenance Window)

**Impact**: Users disconnected during migration
**Duration**: 45-90 minutes (depending on profile sizes)
**Maintenance Window**: REQUIRED - schedule with users

### Pre-Maintenance Checklist
- [ ] Notify users of maintenance window
- [ ] RBAC permissions configured (Step 2.3)
- [ ] Profile migration script prepared
- [ ] Test user identified for post-migration validation
- [ ] Rollback commands documented and ready

### Step 3.1: Disconnect All Users and Disable Sessions

```bash
# Disable new sessions on pauseisavd-0
az rest --method PATCH \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts/pauseisavd-0.albi.local?api-version=2024-04-03" \
  --body '{"properties":{"allowNewSession":false}}'

# Check for active sessions
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts?api-version=2024-04-03" \
  --query "value[].{name:name, sessions:properties.sessions}" -o table
```

If sessions > 0, send logout message or wait for users to disconnect.

### Step 3.2: Deploy FSLogix Extension to pauseisavd-0 (Kerberos)

**Note**: With Azure AD Kerberos, no storage account key is needed!

```bash
az deployment group create \
  --resource-group p-ause-mb-rg-avd \
  --template-file modules/fslogix-extension.bicep \
  --parameters vmName='pauseisavd-0' \
               location='australiasoutheast' \
               storageAccountName='pauseisfslogix001' \
               fileShareName='fslogix-profiles' \
               profileSizeMB=30720 \
               enableOfficeContainer=true \
               deleteLocalProfile=false \
               preventTempProfile=true \
               preventLoginOnFailure=false \
               useStorageKey=false \
               tags='{"Environment":"Production","Application":"AVD","Authentication":"AzureADKerberos"}' \
  --name "deploy-fslogix-host0-$(date +%Y%m%d%H%M)"
```

**Note**: `deleteLocalProfile=false` preserves local profiles during migration.

### Step 3.3: Deploy FSLogix Extension to pauseisavd-1 (Kerberos)

```bash
az deployment group create \
  --resource-group p-ause-mb-rg-avd \
  --template-file modules/fslogix-extension.bicep \
  --parameters vmName='pauseisavd-1' \
               location='australiasoutheast' \
               storageAccountName='pauseisfslogix001' \
               fileShareName='fslogix-profiles' \
               profileSizeMB=30720 \
               enableOfficeContainer=true \
               deleteLocalProfile=true \
               preventTempProfile=true \
               preventLoginOnFailure=false \
               useStorageKey=false \
               tags='{"Environment":"Production","Application":"AVD","Authentication":"AzureADKerberos"}' \
  --name "deploy-fslogix-host1-$(date +%Y%m%d%H%M)"
```

### Step 3.4: Migrate Local Profiles to FSLogix

Connect to `pauseisavd-0` via Azure Bastion or RDP and run the profile migration script.

**Important for Kerberos**: The file share should be accessible without credentials if you're logged in as an Azure AD user with RBAC permissions.

```powershell
# ============================================================================
# FSLogix Profile Migration Script (Azure AD Kerberos)
# Run on: pauseisavd-0
# ============================================================================

$StorageAccount = "pauseisfslogix001"
$FileShare = "fslogix-profiles"
$SharePath = "\\$StorageAccount.file.core.windows.net\$FileShare"

# Test Kerberos connectivity (no credentials needed!)
Write-Host "Testing Kerberos authentication to file share..." -ForegroundColor Cyan
if (Test-Path $SharePath) {
    Write-Host "SUCCESS: Connected via Azure AD Kerberos" -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot connect to file share. Check RBAC permissions." -ForegroundColor Red
    Write-Host "Ensure user has 'Storage File Data SMB Share Contributor' role" -ForegroundColor Yellow
    exit 1
}

# Get local user profiles (exclude system accounts)
$ExcludedUsers = @('Public', 'Default', 'Default User', 'avdadmin', 'Administrator', 'SYSTEM', 'nwadmin-wa', 'nwadmin-wa.old', 'nwadmin-wa.old1', 'local_nwadmin-wa', 'vmadmin')
$UserProfiles = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin $ExcludedUsers }

Write-Host "`nFound $($UserProfiles.Count) user profiles to migrate:" -ForegroundColor Cyan
$UserProfiles | ForEach-Object { Write-Host "  - $($_.Name)" }

# Migrate each profile
foreach ($Profile in $UserProfiles) {
    $UserName = $Profile.Name
    $SourcePath = $Profile.FullName

    Write-Host "`nMigrating profile: $UserName" -ForegroundColor Yellow

    # Get user SID from Win32_UserProfile (works for Entra ID users)
    $UserSID = $null
    $WmiProfile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath -eq $SourcePath }
    if ($WmiProfile) {
        $UserSID = $WmiProfile.SID
    }

    if (-not $UserSID) {
        # Fallback: try NTAccount resolution
        try {
            $UserSID = (New-Object System.Security.Principal.NTAccount($UserName)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        } catch {
            Write-Host "  Skipping $UserName - cannot resolve SID" -ForegroundColor Red
            continue
        }
    }

    Write-Host "  SID: $UserSID" -ForegroundColor Gray

    # Create FSLogix folder structure (FlipFlop format: username_SID)
    $FSLogixFolder = "$SharePath\${UserName}_${UserSID}"
    $ProfileVHDPath = "$FSLogixFolder\Profile_$UserName.vhdx"

    if (!(Test-Path $FSLogixFolder)) {
        New-Item -Path $FSLogixFolder -ItemType Directory -Force | Out-Null
    }

    # Calculate required size (profile size + 20% buffer, minimum 1GB)
    $ProfileSize = (Get-ChildItem $SourcePath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $ProfileSizeGB = [math]::Ceiling($ProfileSize / 1GB)
    $VHDSizeGB = [math]::Max(1, [math]::Ceiling($ProfileSizeGB * 1.2))
    $VHDSizeMB = $VHDSizeGB * 1024

    Write-Host "  Profile size: $([math]::Round($ProfileSize/1GB, 2)) GB"
    Write-Host "  VHD size: $VHDSizeGB GB"

    # Create VHDX
    if (!(Test-Path $ProfileVHDPath)) {
        Write-Host "  Creating VHDX..."
        $diskpartScript = @"
create vdisk file="$ProfileVHDPath" maximum=$VHDSizeMB type=expandable
select vdisk file="$ProfileVHDPath"
attach vdisk
create partition primary
format fs=ntfs quick label="Profile-$UserName"
assign letter=P
"@
        $diskpartScript | diskpart

        # Copy profile data
        Write-Host "  Copying profile data..."
        robocopy $SourcePath "P:\Profile" /E /COPY:DATSO /R:1 /W:1 /MT:8 /XD "AppData\Local\Temp" /XF "*.tmp" /NFL /NDL /NJH /NJS

        # Detach VHD
        $detachScript = @"
select vdisk file="$ProfileVHDPath"
detach vdisk
"@
        $detachScript | diskpart

        Write-Host "  Completed: $UserName" -ForegroundColor Green
    } else {
        Write-Host "  VHDX already exists - skipping" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Migration complete!" -ForegroundColor Green
Write-Host "Migrated profiles are in: $SharePath" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
```

### Step 3.5: Verify Migration

```powershell
# On the VM, check the file share contents (Kerberos - no credentials needed)
Get-ChildItem "\\pauseisfslogix001.file.core.windows.net\fslogix-profiles" -Directory
```

You should see folders named `SID_username` for each migrated user.

### Step 3.6: Restart Both Session Hosts

```bash
# Restart both VMs to apply FSLogix changes
az vm restart --resource-group p-ause-mb-rg-avd --name pauseisavd-0 --no-wait
az vm restart --resource-group p-ause-mb-rg-avd --name pauseisavd-1 --no-wait

# Wait for VMs to come back online (~3-5 minutes)
sleep 180

# Check session host status
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts?api-version=2024-04-03" \
  --query "value[].{name:name, status:properties.status}" -o table
```

### Step 3.7: Enable Sessions on Both Hosts

```bash
# Enable sessions on pauseisavd-0
az rest --method PATCH \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts/pauseisavd-0.albi.local?api-version=2024-04-03" \
  --body '{"properties":{"allowNewSession":true}}'

# Enable sessions on pauseisavd-1
az rest --method PATCH \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts/pauseisavd-1?api-version=2024-04-03" \
  --body '{"properties":{"allowNewSession":true}}'
```

### Step 3.8: Test User Login with Kerberos

1. Have a test user log in via https://client.wvd.microsoft.com
2. Verify FSLogix profile is created/loaded:
   - Check Event Viewer > Applications and Services Logs > FSLogix > Profile
   - Look for "Profile was successfully loaded" event
3. Verify user settings are preserved from migration
4. Verify Kerberos authentication (no credential prompts for file share)

---

## Phase 4: Local Profile Cleanup (Post-Migration)

**Impact**: None - maintenance task
**Duration**: ~30 minutes
**When**: After 7-14 days of successful FSLogix operation

> **IMPORTANT**: Do NOT delete local profiles immediately after migration. Wait until:
> - All users have logged in at least once with FSLogix
> - No issues reported for 7-14 days
> - Snapshot of pauseisavd-0 is still available for emergency rollback

### Step 4.1: Verify All Users Migrated Successfully

Before cleanup, verify all users are using FSLogix profiles:

```powershell
# On pauseisavd-0 - Check FSLogix profile containers exist for all users
$StorageAccount = "pauseisfslogix001"
$FileShare = "fslogix-profiles"
$SharePath = "\\$StorageAccount.file.core.windows.net\$FileShare"

# List all FSLogix profile containers
Write-Host "FSLogix Profile Containers:" -ForegroundColor Cyan
Get-ChildItem $SharePath -Directory | ForEach-Object {
    $vhdx = Get-ChildItem $_.FullName -Filter "*.vhdx" -ErrorAction SilentlyContinue
    Write-Host "  $($_.Name) - VHDX: $(if($vhdx){'YES'}else{'NO'})" -ForegroundColor $(if($vhdx){'Green'}else{'Yellow'})
}

# Compare with local profiles
Write-Host "`nLocal Profiles on this host:" -ForegroundColor Cyan
$ExcludedUsers = @('Public', 'Default', 'Default User', 'avdadmin', 'Administrator')
Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin $ExcludedUsers } | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "  $($_.Name) - Size: $([math]::Round($size, 2)) GB" -ForegroundColor Yellow
}
```

### Step 4.2: Local Profile Cleanup Options

Choose one of the following approaches:

#### Option A: Archive Local Profiles (Recommended)

Keep a backup of local profiles before deletion:

```powershell
# Create archive folder
$ArchivePath = "C:\ProfileArchive_$(Get-Date -Format 'yyyyMMdd')"
New-Item -Path $ArchivePath -ItemType Directory -Force

# Archive local profiles (excluding system accounts)
$ExcludedUsers = @('Public', 'Default', 'Default User', 'avdadmin', 'Administrator')
$UserProfiles = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin $ExcludedUsers }

foreach ($Profile in $UserProfiles) {
    Write-Host "Archiving: $($Profile.Name)" -ForegroundColor Yellow

    # Compress profile to archive
    $ZipPath = "$ArchivePath\$($Profile.Name).zip"
    Compress-Archive -Path $Profile.FullName -DestinationPath $ZipPath -Force

    Write-Host "  Archived to: $ZipPath" -ForegroundColor Green
}

Write-Host "`nArchive complete. Files saved to: $ArchivePath" -ForegroundColor Cyan
Write-Host "Total archive size: $([math]::Round((Get-ChildItem $ArchivePath | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB"
```

#### Option B: Delete Local Profiles (After Archive)

Once archived, remove local profiles to free disk space:

```powershell
# CAUTION: Only run after verifying FSLogix is working for ALL users
# and archive is complete

$ExcludedUsers = @('Public', 'Default', 'Default User', 'avdadmin', 'Administrator')
$UserProfiles = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin $ExcludedUsers }

Write-Host "WARNING: About to delete $($UserProfiles.Count) local profiles" -ForegroundColor Red
Write-Host "Press Ctrl+C to cancel, or any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

foreach ($Profile in $UserProfiles) {
    Write-Host "Deleting: $($Profile.Name)" -ForegroundColor Yellow

    # Use CIM to properly delete user profile (handles registry cleanup)
    $UserProfile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath -eq $Profile.FullName }
    if ($UserProfile) {
        Remove-CimInstance -InputObject $UserProfile
        Write-Host "  Deleted via CIM" -ForegroundColor Green
    } else {
        # Fallback to folder deletion
        Remove-Item -Path $Profile.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Deleted folder" -ForegroundColor Green
    }
}

Write-Host "`nLocal profile cleanup complete!" -ForegroundColor Cyan
```

### Step 4.3: Delete VM Snapshot (After Stabilization)

Once migration is confirmed successful (7-14 days), delete the pre-migration snapshot:

```bash
# List snapshots
az snapshot list --resource-group p-ause-mb-rg-avd --query "[].{name:name, timeCreated:timeCreated}" -o table

# Delete the pre-migration snapshot (replace with actual snapshot name)
az snapshot delete --resource-group p-ause-mb-rg-avd --name pauseisavd-0-snapshot-YYYYMMDD
```

### Local Profile Cleanup Summary

| Step | Timing | Action |
|------|--------|--------|
| Migration Complete | Day 0 | Keep local profiles, monitor FSLogix |
| Validation Period | Days 1-7 | All users test login, report issues |
| Stabilization | Days 7-14 | No issues reported, FSLogix stable |
| Archive Profiles | Day 14+ | Compress local profiles to archive |
| Delete Profiles | Day 14+ | Remove local profiles from C:\Users |
| Delete Snapshot | Day 14+ | Remove VM snapshot to save storage costs |

---

## Post-Deployment Validation

### Check FSLogix Status on VMs

Run on each session host:
```powershell
# Check FSLogix service
Get-Service -Name frxsvc

# Check FSLogix configuration
Get-ItemProperty "HKLM:\SOFTWARE\FSLogix\Profiles"

# Verify Kerberos connectivity (should work without credentials)
Test-Path "\\pauseisfslogix001.file.core.windows.net\fslogix-profiles"

# Check for profile containers
Get-ChildItem "\\pauseisfslogix001.file.core.windows.net\fslogix-profiles" -Directory
```

### Check Session Hosts Status

```bash
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts?api-version=2024-04-03" \
  --query "value[].{name:name, status:properties.status, allowNewSession:properties.allowNewSession, sessions:properties.sessions}" -o table
```

### Verify Kerberos Authentication

```powershell
# On a session host, check Kerberos tickets
klist

# Look for a ticket to: cifs/pauseisfslogix001.file.core.windows.net
```

---

## Troubleshooting Azure AD Kerberos

### Error: Access Denied to File Share

1. **Check RBAC permissions:**
   ```bash
   az role assignment list --scope "/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.Storage/storageAccounts/pauseisfslogix001" -o table
   ```

2. **Verify user has correct role:**
   - `Storage File Data SMB Share Contributor` for normal users
   - `Storage File Data SMB Share Elevated Contributor` for admins

### Error: Kerberos Ticket Not Found

1. **Ensure VM is Azure AD joined:**
   ```powershell
   dsregcmd /status
   # Look for: AzureAdJoined: YES
   ```

2. **Check user is Azure AD authenticated:**
   ```powershell
   whoami /upn
   # Should show: user@albiimports.onmicrosoft.com
   ```

3. **Request new Kerberos ticket:**
   ```powershell
   klist purge
   # Log out and log back in
   ```

### Error: Storage Account Kerberos Not Configured

```bash
# Verify Kerberos is enabled
az storage account show --name pauseisfslogix001 --resource-group p-ause-mb-rg-avd \
  --query "azureFilesIdentityBasedAuthentication.directoryServiceOptions" -o tsv

# Should return: AADKERB
```

---

## Rollback Procedures

### If Phase 1 Fails
```bash
# Delete the new VM
az vm delete --resource-group p-ause-mb-rg-avd --name pauseisavd-1 --yes
az network nic delete --resource-group p-ause-mb-rg-avd --name pauseisavd-1-nic
```

### If Phase 3 FSLogix/Kerberos Fails
```powershell
# On each VM, disable FSLogix
Set-ItemProperty "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "Enabled" -Value 0
```

```bash
# Re-enable sessions on pauseisavd-0
az rest --method PATCH \
  --uri "https://management.azure.com/subscriptions/86602705-1029-43e3-99a8-3fee6ca0c1e0/resourceGroups/p-ause-mb-rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/pauseisavdpool01/sessionHosts/pauseisavd-0.albi.local?api-version=2024-04-03" \
  --body '{"properties":{"allowNewSession":true}}'

# Users will use local profiles (existing behavior)
```

---

## Appendix A: File Locations

| Item | Path |
|------|------|
| Bicep Templates | `claude/templates/avd/bicep/` |
| Session Host Template | `avd-session-host-deploy.bicep` |
| FSLogix Extension | `modules/fslogix-extension.bicep` |
| Storage Module | `modules/storage-account.bicep` |
| File Share Module | `modules/file-share.bicep` |
| RBAC Module | `modules/rbac-assignment.bicep` |

## Appendix B: Resource IDs

| Resource | ID |
|----------|-----|
| Subscription | `86602705-1029-43e3-99a8-3fee6ca0c1e0` |
| Resource Group | `p-ause-mb-rg-avd` |
| VNet | `/subscriptions/.../virtualNetworks/p-ause-mb-vn-workloads` |
| Subnet | `.../subnets/App` |
| Host Pool | `pauseisavdpool01` |
| Tenant ID | `713ee28e-f3d7-4395-ae77-687d5014c757` |
| Tenant Name | `albiimports.onmicrosoft.com` |

## Appendix C: Azure AD Kerberos Requirements

| Requirement | Status |
|-------------|--------|
| Azure AD joined VMs | ✅ Required |
| Users in Azure AD | ✅ Required |
| RBAC on file share | ✅ Required |
| Storage account key | ❌ Not needed |
| Credential Manager entries | ❌ Not needed |
